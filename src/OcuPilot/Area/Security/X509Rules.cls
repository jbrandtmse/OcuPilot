/// <p>The X.509 form's rules (AD-39, AD-55): the one rule set every caller of
/// <class>OcuPilot.Screen.Tool.X509Import</class> and <class>OcuPilot.Screen.Tool.X509Update</class>
/// applies (<method>Validate</method>), the form's read (<method>HandleForm</method>) and the alias
/// look-up (<method>HandleName</method>, <method>Taken</method>).</p>
/// <p><b>Every sentence is <method>OcuPilot.Api.Error.ReasonForViolation</method>'s</b>, and the form
/// read serves the same sentences, so an inline blur refusal and a failed Save are one wording. No
/// sentence names or quotes a certificate, a key or a password, and the secret checks hold their text
/// in locals cleared before they return (AD-35).</p>
Class OcuPilot.Area.Security.X509Rules Extends %RegisteredObject
{

/// <p>The tools the callers resolve the writes through (AD-55): the import for an alias look-up,
/// the edit for a present credential's read and for the port whose PEM rule the secret checks
/// apply.</p>
Parameter IMPORTTOOL = "OcuPilot.Screen.Tool.X509Import";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.X509Update";

/// <p>The screen whose declared pairs gate these routes (AD-8).</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.X509Form";

/// <p>The fields an import must carry, comma-separated.</p>
Parameter REQUIREDFIELDS = "Alias,Certificate";

/// <p>The longest alias and key password <class>%SYS.X509Credentials</class> stores: the
/// <code>MAXLEN</code> of its <code>Alias</code> and <code>PrivateKeyPassword</code> properties on
/// this build.</p>
Parameter ALIASMAXLENGTH As INTEGER = 150;

Parameter PASSWORDMAXLENGTH As INTEGER = 128;

/// <p>The body fields the rules read, named once.</p>
Parameter FIELDALIAS = "Alias";

Parameter FIELDCERTIFICATE = "Certificate";

Parameter FIELDPRIVATEKEY = "PrivateKey";

Parameter FIELDPASSWORD = "PrivateKeyPassword";

/// <p>The two list fields, each an array of strings.</p>
Parameter LISTFIELDS = "OwnerList,PeerNames";

/// <p>Every rule an X.509 write applies, in <var>pViolations</var> as
/// <code>pViolations(n) = $ListBuild(field, code)</code> with the count in
/// <code>pViolations</code>.</p>
/// <p><var>pCheckAlias</var> 0 skips the alias's own rules, for an edit, whose alias is the present
/// credential's; <var>pCheckTaken</var> 0 skips the look-up, for an edit and for the agent's mint,
/// which has read the target itself; <var>pCheckSecrets</var> 0 skips the certificate, key and
/// password rules, for an edit, which carries none, and for the agent's mint, whose secrets arrive at
/// confirm. The secret checks follow the vendor's: one PEM block each
/// (<method>OcuPilot.Port.AdminPort.PemBlock</method>, through the edit tool's port), a certificate
/// whose validity has not ended, and a key that decrypts what the certificate encrypts with the
/// password given (<method>KeyMatches</method>) -- skipped, as the vendor skips it, for an encrypted
/// key sent with no password.</p>
ClassMethod Validate(pAlias As %String, pArgs As %DynamicObject, Output pViolations, pCheckAlias As %Boolean = 1, pCheckTaken As %Boolean = 1, pCheckSecrets As %Boolean = 1) As %Status
{
    Kill pViolations
    Set pViolations = 0
    Set tSC = $$$OK
    Set (tCert, tKey, tPassword, tCanonicalCert, tCanonicalKey, tBytes) = ""
    Try {
        If pCheckAlias Do ..AliasViolation(pAlias, .pViolations)
        If (pViolations = 0) && pCheckTaken {
            Set tTakenSC = ..Taken(pAlias, .tTaken)
            If $$$ISERR(tTakenSC) {
                Set tSC = tTakenSC
                Quit
            }
            If tTaken Do ..Add(.pViolations, ..#FIELDALIAS, ##class(OcuPilot.Api.Error).#X509ALIASTAKEN)
        }
        If '$IsObject(pArgs) Quit

        For tI = 1:1:$Length(..#LISTFIELDS, ",") {
            Set tField = $Piece(..#LISTFIELDS, ",", tI)
            Set tType = pArgs.%GetTypeOf(tField)
            If tType = "unassigned" Continue
            Set tShape = (tType = "array")
            If tShape {
                Set tItems = pArgs.%Get(tField).%GetIterator()
                While tItems.%GetNext(.tIndex, .tItem) {
                    If $IsObject(tItem) || (pArgs.%Get(tField).%GetTypeOf(tIndex) '= "string") Set tShape = 0 Quit
                }
            }
            If 'tShape Do ..Add(.pViolations, tField, ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE)
        }

        If 'pCheckSecrets Quit
        Set tPort = $ClassMethod(..#UPDATETOOL, "PortClass")
        If pArgs.%GetTypeOf(..#FIELDCERTIFICATE) = "string" Set tCert = pArgs.%Get(..#FIELDCERTIFICATE)
        If pArgs.%GetTypeOf(..#FIELDPRIVATEKEY) = "string" Set tKey = pArgs.%Get(..#FIELDPRIVATEKEY)
        If pArgs.%GetTypeOf(..#FIELDPASSWORD) = "string" Set tPassword = pArgs.%Get(..#FIELDPASSWORD)

        Set tCertOK = 0
        If $ZStrip(tCert, "<>WC") = "" {
            Do ..Add(.pViolations, ..#FIELDCERTIFICATE, ##class(OcuPilot.Api.Error).#X509CERTIFICATEREQUIRED)
        } ElseIf '$ClassMethod(tPort, "PemBlock", tCert, "cert", .tCanonicalCert) {
            Do ..Add(.pViolations, ..#FIELDCERTIFICATE, ##class(OcuPilot.Api.Error).#X509CERTIFICATESHAPE)
        } Else {
            Set tBytes = $ClassMethod(tPort, "PemBytes", tCanonicalCert)
            Set tNotAfter = ""
            Try {
                If tBytes '= "" Set tNotAfter = $System.Encryption.X509GetField(tBytes, "ValidityNotAfter")
            } Catch {
                Set tNotAfter = ""
            }
            If tNotAfter = "" {
                Do ..Add(.pViolations, ..#FIELDCERTIFICATE, ##class(OcuPilot.Api.Error).#X509CERTIFICATESHAPE)
            } ElseIf $ZDateTime($ZTimeStamp, 3) ] tNotAfter {
                Do ..Add(.pViolations, ..#FIELDCERTIFICATE, ##class(OcuPilot.Api.Error).#X509CERTIFICATEEXPIRED)
            } Else {
                Set tCertOK = 1
            }
        }

        Set tKeyOK = 0
        If $ZStrip(tKey, "<>WC") '= "" {
            If '$ClassMethod(tPort, "PemBlock", tKey, "key", .tCanonicalKey) {
                Do ..Add(.pViolations, ..#FIELDPRIVATEKEY, ##class(OcuPilot.Api.Error).#X509PRIVATEKEYSHAPE)
            } Else {
                Set tKeyOK = 1
            }
        }

        If $Length(tPassword) > ..#PASSWORDMAXLENGTH {
            Do ..Add(.pViolations, ..#FIELDPASSWORD, ##class(OcuPilot.Api.Error).#X509PRIVATEKEYPASSWORDLENGTH)
        } ElseIf (tPassword '= "") && ($ZStrip(tKey, "<>WC") = "") {
            Do ..Add(.pViolations, ..#FIELDPASSWORD, ##class(OcuPilot.Api.Error).#X509PRIVATEKEYPASSWORDWITHOUTKEY)
        } ElseIf tCertOK && tKeyOK && '((tCanonicalKey [ "ENCRYPTED") && (tPassword = "")) {
            Set tMatch = ..KeyMatches(tBytes, tCanonicalKey, tPassword)
            If tMatch = "wrong" Do ..Add(.pViolations, ..#FIELDPASSWORD, ##class(OcuPilot.Api.Error).#X509PRIVATEKEYPASSWORDWRONG)
            If tMatch = "mismatch" Do ..Add(.pViolations, ..#FIELDPRIVATEKEY, ##class(OcuPilot.Api.Error).#X509PRIVATEKEYMISMATCH)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set (tCert, tKey, tPassword, tCanonicalCert, tCanonicalKey, tBytes) = ""
    Quit tSC
}

/// <p>Whether the canonical key <var>pKey</var> belongs to the certificate <var>pCertificate</var>
/// (DER bytes) under <var>pPassword</var>: <code>ok</code>, <code>wrong</code> for a password that
/// does not decrypt the key, or <code>mismatch</code>. The test of
/// <code>%SYS.X509Credentials</code>'s <code>%OnValidateObject</code>: a fixed plaintext encrypted
/// with the certificate's public key must decrypt with the private key, and OpenSSL's decrypt errors
/// name the password. One addition: a wrong password can also decrypt an encrypted key to bytes that
/// do not decode as a key (about one wrong password in two hundred on this build), which OpenSSL
/// reports as a <code>DECODER</code> error and which is the password too. Every other failure --
/// a key of another certificate, another size or another algorithm -- is a mismatch.</p>
ClassMethod KeyMatches(pCertificate As %String, pKey As %String, pPassword As %String) As %String
{
    Set tAnswer = "mismatch"
    Try {
        Set tPlain = "InterSystems Corp."
        Set tCipher = $System.Encryption.RSAEncrypt(tPlain, pCertificate)
        If tCipher = "" Quit
        Set tBack = $System.Encryption.RSADecrypt(tCipher, pKey, pPassword)
        If tBack = tPlain {
            Set tAnswer = "ok"
            Quit
        }
        Set tError = $System.Encryption.RSAGetLastError()
        If (tError [ "pkcs12 cipherfinal error") || (tError [ "bad decrypt") Set tAnswer = "wrong"
        If (pKey [ "ENCRYPTED") && (tError [ "DECODER routines") Set tAnswer = "wrong"
    } Catch {
        Set tAnswer = "mismatch"
    }
    Set tBack = ""
    Quit tAnswer
}

/// <p>Add the alias's own violation to <var>pViolations</var>, or none: an absent alias, one longer
/// than <parameter>ALIASMAXLENGTH</parameter>, and one carrying a control character or a slash. An
/// alias is compared exactly, case included, so nothing here folds it.</p>
ClassMethod AliasViolation(pAlias As %String, Output pViolations)
{
    If pAlias = "" {
        Do ..Add(.pViolations, ..#FIELDALIAS, ##class(OcuPilot.Api.Error).#X509ALIASREQUIRED)
        Quit
    }
    If $Length(pAlias) > ..#ALIASMAXLENGTH {
        Do ..Add(.pViolations, ..#FIELDALIAS, ##class(OcuPilot.Api.Error).#X509ALIASLENGTH)
        Quit
    }
    Set tUsable = '(pAlias [ "/")
    For tI = 1:1:$Length(pAlias) {
        Set tCode = $Ascii(pAlias, tI)
        If (tCode < 32) || (tCode = 127) Set tUsable = 0 Quit
    }
    If 'tUsable Do ..Add(.pViolations, ..#FIELDALIAS, ##class(OcuPilot.Api.Error).#X509ALIASSHAPE)
}

/// <p>Answer <code>GET /x509/form[?alias=&lt;a&gt;]</code>: everything the form needs before it can
/// draw a field (AD-39): <code>{requiredFields, maxLengths, rules}</code>. With an alias it adds
/// <code>credential</code> holding exactly <code>Alias, OwnerList, PeerNames, CAFile, SubjectDN,
/// IssuerDN, SerialNumber, ValidityNotBefore, ValidityNotAfter, HasPrivateKey</code>, read through the
/// edit tool's own port from the vendor's <code>GET</code> and <code>CERTINFO</code>; no certificate,
/// key or password is ever read. An alias
/// this instance does not hold is 404 <parameter>OcuPilot.Api.Error.X509ALIASABSENT</parameter>.</p>
ClassMethod HandleForm() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tBody = {}
        Set tRequired = []
        For tI = 1:1:$Length(..#REQUIREDFIELDS, ",") Do tRequired.%Push($Piece(..#REQUIREDFIELDS, ",", tI))
        Do tBody.%Set("requiredFields", tRequired)
        Set tLengths = {}
        Do tLengths.%Set(..#FIELDALIAS, ..#ALIASMAXLENGTH, "number")
        Do tLengths.%Set(..#FIELDPASSWORD, ..#PASSWORDMAXLENGTH, "number")
        Do tBody.%Set("maxLengths", tLengths)
        Do tBody.%Set("rules", ..Rules())
        Set tAlias = $Get(%request.Data("alias", 1))
        If tAlias '= "" {
            Set tReadSC = ..Present(tAlias, .tFresh, .tHttp, .tFault)
            If $$$ISERR(tReadSC) {
                Set tSC = ..RenderRead(tReadSC, tHttp, tFault)
                Quit
            }
            Set tInfoSC = ..Read(..#UPDATETOOL, tAlias, "CERTINFO", .tInfo, .tHttp, .tFault)
            If $$$ISERR(tInfoSC) {
                Set tSC = ..RenderRead(tInfoSC, tHttp, tFault)
                Quit
            }
            Set tCredential = {}
            Do tCredential.%Set(..#FIELDALIAS, tAlias, "string")
            For tField = "OwnerList", "PeerNames" {
                Do tCredential.%Set(tField, $Select(tFresh.%GetTypeOf(tField) = "array": tFresh.%Get(tField), 1: []))
            }
            Do tCredential.%Set("CAFile", tFresh.%Get("CAFile"), "string")
            For tField = "SubjectDN", "IssuerDN", "SerialNumber", "ValidityNotBefore", "ValidityNotAfter" {
                Do tCredential.%Set(tField, $Select($IsObject(tInfo): tInfo.%Get(tField), 1: ""), "string")
            }
            Do tCredential.%Set("HasPrivateKey", $Select($IsObject(tInfo): ''tInfo.%Get("HasPrivateKey"), 1: 0), "boolean")
            Do tBody.%Set("credential", tCredential)
        }
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Answer <code>GET /x509/name?alias=&lt;a&gt;</code>: whether that alias is taken, in
/// <code>{alias, taken, reason}</code>. A look-up that cannot be made is a refusal envelope, never
/// an assertion that the alias is free.</p>
ClassMethod HandleName() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tGateSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tGateSC) {
            Set tSC = tGateSC
            Quit
        }
        Set tAlias = $Get(%request.Data("alias", 1))
        If tAlias = "" {
            Set tSC = ##class(OcuPilot.Area.Security.X509Save).RenderOne(..#FIELDALIAS, ##class(OcuPilot.Api.Error).#X509ALIASREQUIRED)
            Quit
        }
        Set tTakenSC = ..Taken(tAlias, .tTaken)
        If $$$ISERR(tTakenSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tTakenSC))
            Quit
        }
        Set tBody = {}
        Do tBody.%Set("alias", tAlias, "string")
        Do tBody.%Set("taken", tTaken, "boolean")
        Do tBody.%Set("reason", $Select(tTaken: ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#X509ALIASTAKEN), 1: ""), "string")
        Set tSC = ##class(OcuPilot.Api.Response).JSON(tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ex)
    }
    Quit tSC
}

/// <p>Whether a credential already carries <var>pAlias</var>, in <var>pTaken</var>, read through the
/// import tool's own port, endpoint and read type (AD-52). The vendor opens an alias exactly, case
/// included.</p>
/// <p><b>Caller contract:</b> an error status means the question was not answered; only a 404 is
/// "free".</p>
ClassMethod Taken(pAlias As %String, Output pTaken As %Boolean) As %Status
{
    Set pTaken = 0
    Set tSC = ..Read(..#IMPORTTOOL, pAlias, "", .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) {
        If +$Get(tHttp) = 404 Quit $$$OK
        Quit tSC
    }
    Set pTaken = ($IsObject(tFresh) && tFresh.%IsA("%Library.DynamicObject"))
    Quit $$$OK
}

/// <p>The present credential <var>pAlias</var>, read through the edit tool's own port, endpoint and
/// read type (AD-52), in <var>pFresh</var>. An absent one is an error status with
/// <var>pHttpStatus</var> 404.</p>
ClassMethod Present(pAlias As %String, Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tSC = ..Read(..#UPDATETOOL, pAlias, "", .pFresh, .pHttpStatus, .pFault)
    If $$$ISOK(tSC) && '($IsObject(pFresh) && pFresh.%IsA("%Library.DynamicObject")) {
        Set pHttpStatus = 404
        Set tSC = $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#X509ALIASABSENT)
    }
    Quit tSC
}

/// <p>Render a failed read: a 404 as <parameter>OcuPilot.Api.Error.X509ALIASABSENT</parameter>, any
/// other refusal as the port's own envelope, and an internal failure generically.</p>
ClassMethod RenderRead(pSC As %Status, pHttpStatus As %Integer, pFault As %DynamicObject) As %Status
{
    If +$Get(pHttpStatus) = 404 {
        Quit ##class(OcuPilot.Api.Error).Render(404, ##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.Error).#REASONX509ALIASABSENT, ##class(OcuPilot.Api.Error).#X509ALIASABSENT)
    }
    If '$IsObject($Get(pFault)) || (pFault.code = ##class(OcuPilot.Api.Error).#INTERNAL) {
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
    }
    Quit ##class(OcuPilot.Api.Error).Render($Select(+$Get(pHttpStatus): +pHttpStatus, 1: 500), pFault.error, pFault.reason, pFault.code, pFault.%Get("detail"))
}

/// <p>Read <var>pAlias</var> through tool <var>pToolClass</var>'s own port and endpoint, at
/// <var>pType</var> or, when that is empty, at the tool's own read type.</p>
ClassMethod Read(pToolClass As %String, pAlias As %String, pType As %String, Output pFresh As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pFresh = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        Kill tQuery
        Set tQuery($ClassMethod(pToolClass, "IdParam")) = pAlias
        Set tType = $Select(pType '= "": pType, 1: $ClassMethod(pToolClass, "ReadType"))
        Set tSC = $ClassMethod($ClassMethod(pToolClass, "PortClass"), "Invoke", $ClassMethod(pToolClass, "Endpoint"), tType, .tQuery, "", .pFresh, .pHttpStatus, .pFault)
    } Catch ex {
        Set pFresh = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Every rule this form applies, as <code>[{field, code, reason}]</code>. The sentences are
/// <method>OcuPilot.Api.Error.ReasonForViolation</method>'s; a code with no sentence is absent.</p>
ClassMethod Rules() As %DynamicArray
{
    Set tRows = []
    Set tCodes = ##class(OcuPilot.Api.Error).X509ViolationCodes()
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation(tCode)
        If tReason = "" Continue
        Set tRow = {}
        Do tRow.%Set("field", ..FieldOf(tCode), "string")
        Do tRow.%Set("code", tCode, "string")
        Do tRow.%Set("reason", tReason, "string")
        Do tRows.%Push(tRow)
    }
    Quit tRows
}

/// <p>The form field an <code>X509.&lt;FIELD&gt;.&lt;RULE&gt;</code> code refuses.</p>
ClassMethod FieldOf(pCode As %String) As %String [ Private ]
{
    Set tPart = $Piece(pCode, ".", 2)
    If tPart = "ALIAS" Quit ..#FIELDALIAS
    If tPart = "CERTIFICATE" Quit ..#FIELDCERTIFICATE
    If tPart = "PRIVATEKEY" Quit ..#FIELDPRIVATEKEY
    If tPart = "PRIVATEKEYPASSWORD" Quit ..#FIELDPASSWORD
    Quit ""
}

/// <p>Refuse a caller who does not hold the form's declared pairs (AD-8): <var>pRefused</var> 1
/// means the envelope is written and the caller writes nothing else.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If ##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

/// <p>Append one <code>(field, code)</code> violation.</p>
ClassMethod Add(Output pViolations, pField As %String, pCode As %String) [ Private ]
{
    Set pViolations($Increment(pViolations)) = $ListBuild(pField, pCode)
}

}
