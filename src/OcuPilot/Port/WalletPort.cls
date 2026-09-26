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

/// <p>The admin port's call, with a <parameter>WALLETENDPOINT</parameter>
/// <parameter>COMPLETEDTYPE</parameter> answered from <parameter>COMPLETINGTYPE</parameter> and <method>Completed</method>.</p>
/// <p><b>Caller contract:</b> the arguments and outputs are
/// <method>OcuPilot.Port.AdminPort.Invoke</method>'s. The completed read takes the secret's full
/// name in <code>pQuery("name")</code> and answers <code>{Type, Usage, RequireTLS, AllowedHosts}</code>
/// for a key-value secret or <code>{Type}</code> for any other, with the name compared exactly, case
/// included. An absent name is an error status at 404 with the fault
/// <parameter>OcuPilot.Api.Error.WALLETNAMEABSENT</parameter>, and an absent collection one at 404
/// with <parameter>OcuPilot.Api.Error.WALLETCOLLECTIONABSENT</parameter>.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
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

/// <p>The admin port's script (AD-59): <method>Invoke</method>'s own branch is a read, and every
/// write is the admin port's call.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    Quit ##super(pEndpoint, pType, .pQuery, pBody, pContext)
}

}
