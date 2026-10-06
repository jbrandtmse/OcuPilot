/// <p>The wallet secret tools' port (AD-27's third case, AD-52): <class>OcuPilot.Port.AdminPort</class>
/// with one read completed. The admin API offers no <code>Wallet.Secret</code> <code>GET</code> (it
/// answers 405, and its <code>LIST</code> rows carry only <code>{Name, Type}</code>), so this port
/// answers that <code>GET</code> from the endpoint's own <code>LIST</code>, filtered to the exact name,
/// and, for a <code>%Wallet.KeyValue</code> secret, from <code>%Wallet.Secret.Exists</code> in
/// <code>%SYS</code>. Every other endpoint and request type is the admin port's own call,
/// unchanged.</p>
/// <p><b>It never reads a stored value.</b> The class read takes <code>Usage</code>,
/// <code>RequireTLS</code> and <code>AllowedHosts</code> off the opened secret and nothing else, and
/// the object is dropped before the answer is returned (AD-35). Because the value is never read, a
/// change to it between a proposal and its confirm is not something the fingerprint can detect
/// (AD-27).</p>
/// <p><b>An RSA or symmetric key's read is its metadata alone</b> (Story 18.24): an RSA key answers
/// <code>{Type, Length, HasPrivateKey, HasCertificate}</code> and a symmetric key
/// <code>{Type, Length, KeyId}</code>, taken property by property off the opened secret. No key
/// material, a public half included, is read.</p>
/// <p><b>A <code>PUT</code> of one of those two types is this port's own call</b>
/// (<method>PutKey</method>): it refuses what the vendor would answer with a logged 500, builds the
/// body from a length or from content, and sequences an imported symmetric key's create in two
/// <code>PUT</code>s, because the vendor stores no length for an imported key and stores a random key
/// when <code>Length</code> rides with <code>Secret64</code> (measured).</p>
/// <p><b>The vendor's gate still decides.</b> The <code>LIST</code> runs first, through the admin
/// port, so the endpoint's <code>%Admin_Wallet</code> check refuses a caller before the class is
/// asked anything; the class's own permission check then applies on the open.</p>
Class OcuPilot.Port.WalletPort Extends OcuPilot.Port.AdminPort
{

/// <p>The endpoint whose <code>GET</code> this port completes.</p>
Parameter WALLETENDPOINT = "Wallet.Secret";

/// <p>The request type completed, and the one it is completed from.</p>
Parameter COMPLETEDTYPE = "GET";

Parameter COMPLETINGTYPE = "LIST";

/// <p>The one secret type whose settings the class read answers. Any other type answers its
/// <code>Type</code> alone.</p>
Parameter KEYVALUETYPE = "%Wallet.KeyValue";

/// <p>The vendor class the settings are read through.</p>
Parameter SECRETCLASS = "%Wallet.Secret";

/// <p>The two key types (Story 18.24) and the body members that carry key material as content.</p>
Parameter RSATYPE = "%Wallet.RSA";

Parameter SYMMETRICTYPE = "%Wallet.SymmetricKey";

Parameter MATERIALFIELDS = "Certificate,PublicKey,PrivateKey,Secret64";

/// <p>The closed sets of lengths: RSA in bits, symmetric in bytes.</p>
Parameter RSALENGTHS = "2048,3072,4096";

Parameter SYMMETRICLENGTHS = "16,24,32";

/// <p>The admin port's call, with a <parameter>WALLETENDPOINT</parameter>
/// <parameter>COMPLETEDTYPE</parameter> answered from <parameter>COMPLETINGTYPE</parameter> and <method>Completed</method>.</p>
/// <p><b>Caller contract:</b> the arguments and outputs are
/// <method>OcuPilot.Port.AdminPort.Invoke</method>'s. The completed read takes the secret's full
/// name in <code>pQuery("name")</code> and answers <code>{Type, Usage, RequireTLS, AllowedHosts}</code>
/// for a key-value secret, <code>{Type, Length, HasPrivateKey, HasCertificate}</code> for an RSA key,
/// <code>{Type, Length, KeyId}</code> for a symmetric key or <code>{Type}</code> for any other, with the
/// name compared exactly, case included. An absent name is an error status at 404 with the fault
/// <parameter>OcuPilot.Api.Error.WALLETNAMEABSENT</parameter>, and an absent collection one at 404
/// with <parameter>OcuPilot.Api.Error.WALLETCOLLECTIONABSENT</parameter>.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If (pEndpoint = ..#WALLETENDPOINT) && (pType = "PUT") && (..KeyTypeOf(.pQuery, pBody) '= "") Quit ..PutKey(..KeyTypeOf(.pQuery, pBody), .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    If (pEndpoint '= ..#WALLETENDPOINT) || (pType '= ..#COMPLETEDTYPE) Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tName = $Get(pQuery("name"))
    Set tCollection = $Piece(tName, ".", 1)
    Set tPart = $Piece(tName, ".", 2, *)
    If (tCollection = "") || (tPart = "") Quit ..Absent(##class(OcuPilot.Api.Error).#WALLETNAMEABSENT, ##class(OcuPilot.Api.Error).#REASONWALLETNAMEABSENT, .pHttpStatus, .pFault)
    Kill tList
    Set tList("collection") = tCollection
    Set tList("names") = tPart
    Set tSC = ##super(..#WALLETENDPOINT, ..#COMPLETINGTYPE, .tList, "", .tRows, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) {
        If +pHttpStatus = 404 Quit ..Absent(##class(OcuPilot.Api.Error).#WALLETCOLLECTIONABSENT, ##class(OcuPilot.Api.Error).#REASONWALLETCOLLECTIONABSENT, .pHttpStatus, .pFault)
        Quit tSC
    }
    Quit ..Completed(tName, $Get(tRows), .pResult, .pHttpStatus, .pFault)
}

/// <p>The completed read of the secret <var>pName</var> from its collection's <code>LIST</code>
/// rows <var>pRows</var>, which the vendor narrowed to the part after the collection ignoring case:
/// the one row whose <code>Name</code> equals <var>pName</var> exactly, then the class read for a
/// key-value secret. A failed class read fails the whole read; nothing is answered half-read.</p>
ClassMethod Completed(pName As %String, pRows, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        Set tType = ""
        If $IsObject(pRows) && pRows.%IsA("%Library.DynamicArray") {
            Set tIterator = pRows.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tRow) {
                If '$IsObject(tRow) Continue
                If tRow.%Get("Name") '= pName Continue
                Set tType = tRow.%Get("Type")
                Quit
            }
        }
        If tType = "" {
            Set tSC = ..Absent(##class(OcuPilot.Api.Error).#WALLETNAMEABSENT, ##class(OcuPilot.Api.Error).#REASONWALLETNAMEABSENT, .pHttpStatus, .pFault)
            Quit
        }
        Set tAnswer = {}
        Do tAnswer.%Set("Type", tType, "string")
        If tType = ..#KEYVALUETYPE {
            Set tSC = ..KeyValueSettings(pName, tAnswer)
            If $$$ISERR(tSC) {
                Set tSC = ..Fail(..#WALLETENDPOINT, 500, tSC, .pHttpStatus, .pFault)
                Quit
            }
        }
        If (tType = ..#RSATYPE) || (tType = ..#SYMMETRICTYPE) {
            Set tSC = ..KeySettings(pName, tType, tAnswer)
            If $$$ISERR(tSC) {
                Set tSC = ..Fail(..#WALLETENDPOINT, 500, tSC, .pHttpStatus, .pFault)
                Quit
            }
        }
        Set pResult = tAnswer
        Set pHttpStatus = 200
    } Catch ex {
        Set pHttpStatus = 500
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
        Do ..LogFault(..#WALLETENDPOINT _ " read failed inside the port", ex.AsStatus(), pFault.code)
        Set tSC = $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
    }
    If $$$ISERR(tSC) Set pResult = ""
    Quit tSC
}

/// <p>Set <code>Usage</code>, <code>RequireTLS</code> and <code>AllowedHosts</code> of the key-value
/// secret <var>pName</var> on <var>pAnswer</var>, read through <parameter>SECRETCLASS</parameter>'s
/// <code>Exists</code> in <code>%SYS</code> (AD-16). <code>AllowedHosts</code> is a JSON array of
/// the stored list's members. The stored value is not read, and the opened object is dropped before
/// the method returns, on every path.</p>
ClassMethod KeyValueSettings(pName As %String, pAnswer As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set tSecret = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tExists = $ClassMethod(..#SECRETCLASS, "Exists", pName, .tSecret, .tOpenSC)
        If tExists && $IsObject(tSecret) {
            Set tUsage = tSecret.Usage
            Set tRequireTLS = tSecret.RequireTLS
            Set tHosts = tSecret.AllowedHosts
        }
        Set tSecret = ""
        Set $NAMESPACE = tOrigNS
        If 'tExists {
            Set tSC = $Select($$$ISERR($Get(tOpenSC, $$$OK)): tOpenSC, 1: $$$ERROR($$$GeneralError, "the wallet secret listed as present could not be opened"))
            Quit
        }
        Do pAnswer.%Set("Usage", +tUsage, "number")
        Do pAnswer.%Set("RequireTLS", ''tRequireTLS, "boolean")
        Set tArray = []
        If $ListValid(tHosts) {
            Set tPointer = 0
            While $ListNext(tHosts, tPointer, tHost) {
                If $Get(tHost) '= "" Do tArray.%Push(tHost, "string")
            }
        }
        Do pAnswer.%Set("AllowedHosts", tArray)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSecret = ""
        Set tSC = ex.AsStatus()
    }
    Set tSecret = ""
    Quit tSC
}

/// <p>Set the metadata of the RSA or symmetric key <var>pName</var>, of type <var>pType</var>, on
/// <var>pAnswer</var>, read through <parameter>SECRETCLASS</parameter>'s <code>Exists</code> in
/// <code>%SYS</code> (AD-16): an RSA key's <code>Length</code>, <code>HasPrivateKey</code> and
/// <code>HasCertificate</code>, a symmetric key's <code>Length</code> and <code>KeyId</code>. An unset
/// <code>Length</code> is JSON <code>null</code>. No key material is read, and the opened object is
/// dropped before the method returns, on every path.</p>
ClassMethod KeySettings(pName As %String, pType As %String, pAnswer As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set tSecret = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tExists = $ClassMethod(..#SECRETCLASS, "Exists", pName, .tSecret, .tOpenSC)
        If tExists && $IsObject(tSecret) {
            Set tLength = tSecret.Length
            If pType = ..#RSATYPE {
                Set tHasKey = tSecret.HasPrivateKey
                Set tHasCertificate = tSecret.HasCertificate
            } Else {
                Set tKeyId = tSecret.KeyId
            }
        }
        Set tSecret = ""
        Set $NAMESPACE = tOrigNS
        If 'tExists {
            Set tSC = $Select($$$ISERR($Get(tOpenSC, $$$OK)): tOpenSC, 1: $$$ERROR($$$GeneralError, "the wallet secret listed as present could not be opened"))
            Quit
        }
        If tLength = "" {
            Do pAnswer.%Set("Length", "", "null")
        } Else {
            Do pAnswer.%Set("Length", +tLength, "number")
        }
        If pType = ..#RSATYPE {
            Do pAnswer.%Set("HasPrivateKey", ''tHasKey, "boolean")
            Do pAnswer.%Set("HasCertificate", ''tHasCertificate, "boolean")
        } Else {
            Do pAnswer.%Set("KeyId", tKeyId, "string")
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSecret = ""
        Set tSC = ex.AsStatus()
    }
    Set tSecret = ""
    Quit tSC
}

/// <p>The key type a <code>PUT</code> to <code>Wallet.Secret</code> carries: the body's <code>Type</code>
/// or, where the body carries none, the query's, when it is one of the two key types; <code>""</code>
/// for any other.</p>
ClassMethod KeyTypeOf(ByRef pQuery, pBody As %DynamicAbstractObject = "") As %String
{
    Set tType = ""
    If $IsObject(pBody) && pBody.%IsA("%Library.DynamicObject") && (pBody.%GetTypeOf("Type") = "string") Set tType = pBody.%Get("Type")
    If tType = "" Set tType = $Get(pQuery("Type"))
    If (tType = ..#RSATYPE) || (tType = ..#SYMMETRICTYPE) Quit tType
    Quit ""
}

/// <p>One vendor call, through the admin port. The seam every vendor <code>PUT</code> of
/// <method>PutKey</method> goes through, so a fixture sees each one.</p>
ClassMethod Send(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ##class(OcuPilot.Port.AdminPort).Invoke(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>The <code>PUT</code> of one RSA or symmetric key (Story 18.24): <var>pKeyType</var> is
/// <method>KeyTypeOf</method>'s answer, <var>pBody</var> the flat body (<code>Length</code> to generate,
/// or key material as content) or <code>""</code> for a replace whose length rides in
/// <code>pQuery("Length")</code>.</p>
/// <p><b>Caller contract:</b> the outputs are <method>OcuPilot.Port.AdminPort.Invoke</method>'s. A body
/// naming a server file is the admin port's refusal, before any vendor call. This port refuses, with no
/// vendor call, a body that carries both a length and key material
/// (<parameter>OcuPilot.Api.WalletKeyError.SOURCEBOTH</parameter>) or neither
/// (<parameter>OcuPilot.Api.WalletKeyError.SOURCEREQUIRED</parameter>), a length outside its type's set
/// and a symmetric key that is not base64 of 16, 24 or 32 bytes. A symmetric key sent as
/// <code>Secret64</code> reads the name first: an absent name is created with one <code>PUT</code> of the
/// key and then one of the decoded byte count as <code>Length</code>; a present name is replaced by one
/// <code>PUT</code> carrying both. The decoded bytes are cleared before the method returns.</p>
ClassMethod PutKey(pKeyType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSend = ""
    Set tBytes = ""
    Try {
        Set tPathField = ..WalletPathField(..#WALLETENDPOINT, "PUT", pBody)
        If tPathField '= "" {
            Set tSC = ..RefuseWalletPath(tPathField, .pHttpStatus, .pFault)
            Quit
        }
        Set tSend = {}
        If $IsObject(pBody) && pBody.%IsA("%Library.DynamicObject") {
            Set tIterator = pBody.%GetIterator()
            While tIterator.%GetNext(.tKey, .tValue) {
                Set tType = pBody.%GetTypeOf(tKey)
                If (tType = "object") || (tType = "array") {
                    Do tSend.%Set(tKey, tValue)
                } Else {
                    Do tSend.%Set(tKey, tValue, tType)
                }
            }
        }
        Do tSend.%Set("Type", pKeyType, "string")
        If (tSend.%GetTypeOf("Length") = "unassigned") && ($Get(pQuery("Length")) '= "") Do tSend.%Set("Length", +pQuery("Length"), "number")

        Set tHasLength = (tSend.%GetTypeOf("Length") '= "unassigned")
        Set tHasMaterial = 0
        For tI = 1:1:$Length(..#MATERIALFIELDS, ",") {
            Set tField = $Piece(..#MATERIALFIELDS, ",", tI)
            If (tSend.%GetTypeOf(tField) = "string") && (tSend.%Get(tField) '= "") Set tHasMaterial = 1
        }
        Set tWalletKeyError = "OcuPilot.Api.WalletKeyError"
        If tHasLength && tHasMaterial Quit:..KeyRefusal($Parameter(tWalletKeyError, "SOURCEBOTH"), .tSC, .pHttpStatus, .pFault)
        If 'tHasLength && 'tHasMaterial Quit:..KeyRefusal($Parameter(tWalletKeyError, "SOURCEREQUIRED"), .tSC, .pHttpStatus, .pFault)
        If tHasLength {
            Set tLength = tSend.%Get("Length")
            Set tSet = $Select(pKeyType = ..#RSATYPE: ..#RSALENGTHS, 1: ..#SYMMETRICLENGTHS)
            If (tSend.%GetTypeOf("Length") '= "number") && (tSend.%GetTypeOf("Length") '= "string") || '$IsValidNum(tLength) || '$ListFind($ListFromString(tSet), +tLength) {
                Quit:..KeyRefusal($Parameter(tWalletKeyError, $Select(pKeyType = ..#RSATYPE: "LENGTHRSA", 1: "LENGTHSYMMETRIC")), .tSC, .pHttpStatus, .pFault)
            }
            Do tSend.%Set("Length", +tLength, "number")
        }
        If (pKeyType = ..#SYMMETRICTYPE) && (tSend.%GetTypeOf("Secret64") = "string") && (tSend.%Get("Secret64") '= "") {
            Set tBytes = ..DecodedKey(tSend.%Get("Secret64"))
            Set tCount = $Length(tBytes)
            Set tBytes = ""
            If '$ListFind($ListFromString(..#SYMMETRICLENGTHS), tCount) Quit:..KeyRefusal($Parameter(tWalletKeyError, "SECRET64SHAPE"), .tSC, .pHttpStatus, .pFault)
            Set tSC = ..PutSymmetricImport(.pQuery, tSend, tCount, .pResult, .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..Send(..#WALLETENDPOINT, "PUT", .pQuery, tSend, .pResult, .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set pHttpStatus = 500
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
        Do ..LogFault(..#WALLETENDPOINT _ " key write failed inside the port", ex.AsStatus(), pFault.code)
        Set tSC = $$$ERROR($$$GeneralError, pFault.code _ ": " _ pFault.reason)
    }
    Set tSend = ""
    Set tBytes = ""
    Quit tSC
}

/// <p>Refuse with the key code <var>pCode</var> and its sentence, on its field, 422, in <var>pSC</var>,
/// <var>pHttpStatus</var> and <var>pFault</var>; always answers 1, so a caller quits on it.</p>
ClassMethod KeyRefusal(pCode As %String, ByRef pSC As %Status, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Boolean [ Private ]
{
    Set tReason = ##class(OcuPilot.Api.WalletKeyError).ReasonFor(pCode)
    Set tDetail = {"violations": []}
    Do tDetail.%Get("violations").%Push({"field": (##class(OcuPilot.Api.WalletKeyError).FieldOf(pCode)), "code": (pCode), "reason": (tReason)})
    Set pSC = ..Refuse(422, ##class(OcuPilot.Api.Error).#VALIDATIONFAILED, pCode, tReason, .pHttpStatus, .pFault, tDetail)
    Quit 1
}

/// <p>The bytes <var>pText</var> decodes to as base64, or <code>""</code> when it is not base64.</p>
ClassMethod DecodedKey(pText As %String) As %String
{
    Set tBytes = ""
    Try {
        Set tText = $ZStrip(pText, "*W")
        If $Match(tText, "^[A-Za-z0-9+/]+={0,2}$") && ('($Length(tText) # 4)) Set tBytes = $System.Encryption.Base64Decode(tText)
    } Catch {
        Set tBytes = ""
    }
    Quit tBytes
}

/// <p>Create or replace the symmetric key <var>pSend</var> carries as <code>Secret64</code>, whose
/// decoded length is <var>pCount</var> bytes (see <method>PutKey</method>).</p>
ClassMethod PutSymmetricImport(ByRef pQuery, pSend As %DynamicObject, pCount As %Integer, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Kill tRead
    Set tRead("name") = $Get(pQuery("name"))
    Set tReadSC = ..Invoke(..#WALLETENDPOINT, ..#COMPLETEDTYPE, .tRead, "", .tPresent, .tReadHttp, .tReadFault)
    If $$$ISERR(tReadSC) && (+$Get(tReadHttp) '= 404) {
        Set pHttpStatus = tReadHttp
        Set pFault = tReadFault
        Quit tReadSC
    }
    Set tHeld = ($$$ISOK(tReadSC) && $IsObject($Get(tPresent)))
    If tHeld {
        Do pSend.%Set("Length", pCount, "number")
        Quit ..Send(..#WALLETENDPOINT, "PUT", .pQuery, pSend, .pResult, .pHttpStatus, .pFault)
    }
    Set tSC = ..Send(..#WALLETENDPOINT, "PUT", .pQuery, pSend, .pResult, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tCreatedHttp = pHttpStatus
    Set tLength = {}
    Do tLength.%Set("Type", ..#SYMMETRICTYPE, "string")
    Do tLength.%Set("Length", pCount, "number")
    Set tSC = ..Send(..#WALLETENDPOINT, "PUT", .pQuery, tLength, .pResult, .pHttpStatus, .pFault)
    ; The create is what the caller asked for, so its status is the answer: the second call only
    ; sets the length.
    If $$$ISOK(tSC) Set pHttpStatus = tCreatedHttp
    Quit tSC
}

/// <p>A 404 this port decided itself, carrying <var>pCode</var> and <var>pReason</var> on the
/// <code>not_found</code> slug.</p>
ClassMethod Absent(pCode As %String, pReason As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Refuse(404, ##class(OcuPilot.Api.Error).#NOTFOUND, pCode, pReason, .pHttpStatus, .pFault)
}

/// <p>The admin port's answer: this port carries out no write of its own.</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    Quit ##super(pEndpoint, pType)
}

/// <p>The script (AD-59): <method>Invoke</method>'s own branch is a read, and every write is the admin
/// port's call except an imported symmetric key's, which is two steps for a new name and one for a
/// replace -- the same sequence <method>PutKey</method> sends, with <code>&lt;Length&gt;</code> for the
/// byte count the key decodes to. An RSA replace by generation carries its length in the query and is
/// rendered as its body <code>{Type, Length}</code>, whatever secret members the card names. A body that
/// is a placeholder is rendered as it arrives; no key material is ever in a script.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    Set tKeyType = $Select((pEndpoint = ..#WALLETENDPOINT) && (pType = "PUT"): ..KeyTypeOf(.pQuery, pBody), 1: "")
    If tKeyType = "" Quit ##super(pEndpoint, pType, .pQuery, pBody, pContext)
    ; The type and the length of a replace travel in the port's query, and are the body's in the script.
    Kill tQuery
    Merge tQuery = pQuery
    Kill tQuery("Length"), tQuery("Type")
    Set tObject = ($IsObject(pBody) && pBody.%IsA("%Library.DynamicObject"))
    If (tKeyType = ..#RSATYPE) && ('tObject || ($Get(pQuery("Length")) '= "")) {
        Set tReplace = {}
        Do tReplace.%Set("Type", ..#RSATYPE, "string")
        If $Get(pQuery("Length")) '= "" Do tReplace.%Set("Length", +pQuery("Length"), "number")
        Quit ##super(pEndpoint, pType, .tQuery, tReplace, pContext)
    }
    If (tKeyType = ..#SYMMETRICTYPE) && tObject && (pBody.%GetTypeOf("Secret64") = "string") {
        Set tCreates = ($IsObject(pContext) && pContext.%Get("creates"))
        Set tFirst = ##class(%DynamicAbstractObject).%FromJSON(pBody.%ToJSON())
        Do tFirst.%Set("Type", ..#SYMMETRICTYPE, "string")
        If 'tCreates Do tFirst.%Set("Length", "<Length>", "string")
        Set tSteps = ##super(pEndpoint, pType, .tQuery, tFirst, pContext)
        If tCreates {
            Set tSecond = {}
            Do tSecond.%Set("Type", ..#SYMMETRICTYPE, "string")
            Do tSecond.%Set("Length", "<Length>", "string")
            Set tMore = ##super(pEndpoint, pType, .tQuery, tSecond, pContext)
            Set tIterator = tMore.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tStep) {
                Do tSteps.%Push(tStep)
            }
        }
        Quit tSteps
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, pContext)
}

}
