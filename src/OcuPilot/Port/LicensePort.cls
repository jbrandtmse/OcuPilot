/// <p>The license key's port (AD-51, AD-52, Story 18.6): <class>OcuPilot.Port.AdminPort</class> with
/// the key check and the activation sequenced here, and every other call the admin port's own. It
/// names no vendor class.</p>
/// <p><b><method>Validate</method></b> refuses an empty text
/// (<parameter>OcuPilot.Api.LicenseError.KEYEMPTY</parameter>) and one longer than
/// <parameter>KEYMAXLENGTH</parameter> (<parameter>OcuPilot.Api.LicenseError.KEYINVALID</parameter>)
/// before any call, then sends <code>License.Key</code> <code>VALIDATE</code> and maps its answer to
/// <code>{valid, requiresRestart, reductions, features}</code>. An invalid text is 422
/// <parameter>OcuPilot.Api.LicenseError.KEYINVALID</parameter> on <code>Key</code>. The vendor's
/// <code>InvalidReason</code> and <code>RestartReason</code> are read by nobody: no answer, fault or
/// log line carries them.</p>
/// <p><b>A <code>License.Key</code> <code>PUT</code></b> runs <method>Validate</method> on the same text
/// first and sends the vendor's <code>PUT</code> only when it answered valid; its answer carries no
/// <code>Key</code>. A <code>License.Key</code> <code>GET</code> is the admin port's read without
/// <code>AuthorizationKey</code> (AD-36).</p>
/// <p><b>Caller contract:</b> the key text is a secret (AD-35): it is held in locals that are
/// cleared before return and is never put in a status, a fault or a log line. Every vendor call goes
/// through <method>Call</method>, so a test port overrides that one method.</p>
Class OcuPilot.Port.LicensePort Extends OcuPilot.Port.AdminPort
{

/// <p>The endpoint and the request type of the key check.</p>
Parameter KEYENDPOINT = "License.Key";

Parameter VALIDATETYPE = "VALIDATE";

/// <p>The body key the key text travels under, the vendor's own (<code>RequestBodySchema</code>).</p>
Parameter KEYFIELD = "Key";

/// <p>The longest key text the port sends: 16,384 characters, far above any key file (inference:
/// a license key file is a few kilobytes).</p>
Parameter KEYMAXLENGTH As INTEGER = 16384;

/// <p>The read member that is never answered (AD-36): with the other fields it completes the key
/// file.</p>
Parameter AUTHORIZATIONFIELD = "AuthorizationKey";

/// <p>The reduction kinds the check answers, in the classic dialog's order.</p>
Parameter REDUCTIONKINDS = "Cores,Users,Server,LicenseType,Product";

/// <p>One vendor call: <method>OcuPilot.Port.AdminPort.Invoke</method>.</p>
ClassMethod Call(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ##class(OcuPilot.Port.AdminPort).Invoke(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>The admin port's call, with this class's header's three branches for
/// <parameter>KEYENDPOINT</parameter>.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    If pEndpoint = ..#KEYENDPOINT {
        If pType = "PUT" Quit ..Activate(.pQuery, pBody, .pResult, .pHttpStatus, .pFault)
        If pType = ..#VALIDATETYPE Quit ..Validate(..KeyOf(pBody), .pResult, .pHttpStatus, .pFault)
        If pType = "GET" {
            Set tSC = ..Call(pEndpoint, pType, .pQuery, pBody, .tResult, .pHttpStatus, .pFault)
            If $IsObject($Get(tResult)) && tResult.%IsA("%Library.DynamicObject") Do tResult.%Remove(..#AUTHORIZATIONFIELD)
            Set pResult = $Get(tResult)
            Quit tSC
        }
    }
    Quit ..Call(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>Check the key text <var>pKey</var> without applying it: <var>pAnswer</var> is
/// <code>{valid: true, requiresRestart, reductions: [{kind, from, to}], features: [name]}</code> at 200,
/// or the status is an error carrying the 422 refusal (or the vendor call's own fault) in
/// <var>pHttpStatus</var> and <var>pFault</var>.</p>
ClassMethod Validate(pKey As %String, Output pAnswer As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pAnswer = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = $$$OK
    Try {
        If $ZStrip(pKey, "<>WC") = "" {
            Set tSC = ..Refused(##class(OcuPilot.Api.LicenseError).#KEYEMPTY, .pHttpStatus, .pFault)
            Quit
        }
        If $Length(pKey) > ..#KEYMAXLENGTH {
            Set tSC = ..Refused(##class(OcuPilot.Api.LicenseError).#KEYINVALID, .pHttpStatus, .pFault)
            Quit
        }
        Kill tQuery
        Set tBody = {}
        Do tBody.%Set(..#KEYFIELD, pKey, "string")
        Set tSC = ..Call(..#KEYENDPOINT, ..#VALIDATETYPE, .tQuery, tBody, .tChecked, .pHttpStatus, .pFault)
        Set tBody = ""
        If $$$ISERR(tSC) Quit
        If '$IsObject($Get(tChecked)) || 'tChecked.%IsA("%Library.DynamicObject") || (tChecked.%GetTypeOf("IsValid") '= "boolean") {
            Set pHttpStatus = 500
            Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
            Set tSC = $$$ERROR($$$GeneralError, "the license key check answered no verdict")
            Quit
        }
        If 'tChecked.%Get("IsValid") {
            Set tSC = ..Refused(##class(OcuPilot.Api.LicenseError).#KEYINVALID, .pHttpStatus, .pFault)
            Quit
        }
        Set pAnswer = ..Answer(tChecked)
        Set pHttpStatus = 200
    } Catch ex {
        Set pAnswer = ""
        Set pHttpStatus = 500
        Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON)
        Set tSC = $$$ERROR($$$GeneralError, "the license key check failed inside the port")
    }
    Set tChecked = ""
    Quit tSC
}

/// <p>The answer a valid check carries, from the vendor's own <var>pChecked</var>: whether a restart
/// is required, each reduction kind's <code>{kind, from, to}</code> as text, and the features the key
/// drops. No text of the vendor's is copied.</p>
ClassMethod Answer(pChecked As %DynamicObject) As %DynamicObject
{
    Set tAnswer = {}
    Do tAnswer.%Set("valid", 1, "boolean")
    Do tAnswer.%Set("requiresRestart", (pChecked.%GetTypeOf("RequiresRestart") = "boolean") && pChecked.%Get("RequiresRestart"), "boolean")
    Set tReductions = []
    Set tFeatures = []
    Set tGiven = pChecked.%Get("Reductions")
    If $IsObject(tGiven) && tGiven.%IsA("%Library.DynamicObject") {
        For tI = 1:1:$Length(..#REDUCTIONKINDS, ",") {
            Set tKind = $Piece(..#REDUCTIONKINDS, ",", tI)
            Set tPair = tGiven.%Get(tKind)
            If '$IsObject(tPair) || 'tPair.%IsA("%Library.DynamicObject") Continue
            Set tRow = {}
            Do tRow.%Set("kind", tKind, "string")
            Do tRow.%Set("from", ..Text(tPair, "From"), "string")
            Do tRow.%Set("to", ..Text(tPair, "To"), "string")
            Do tReductions.%Push(tRow)
        }
        Set tList = tGiven.%Get("Features")
        If $IsObject(tList) && tList.%IsA("%Library.DynamicArray") {
            Set tIterator = tList.%GetIterator()
            While tIterator.%GetNext(.tIndex, .tName) {
                If '$IsObject(tName) && (tName '= "") Do tFeatures.%Push(tName _ "", "string")
            }
        }
    }
    Do tAnswer.%Set("reductions", tReductions)
    Do tAnswer.%Set("features", tFeatures)
    Quit tAnswer
}

/// <p>The activation: <method>Validate</method> on the body's key text, then the vendor's
/// <code>PUT</code> of the same text only when it answered valid. <var>pResult</var> is
/// <code>{activated: true, requiresRestart}</code> and never the key.</p>
ClassMethod Activate(ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tKey = ..KeyOf(pBody)
    Set tSC = ..Validate(tKey, .tChecked, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) {
        Set tKey = ""
        Quit tSC
    }
    Set tBody = {}
    Do tBody.%Set(..#KEYFIELD, tKey, "string")
    Set tKey = ""
    Kill tQuery
    Set tSC = ..Call(..#KEYENDPOINT, "PUT", .tQuery, tBody, .tWritten, .pHttpStatus, .pFault)
    Set tBody = ""
    Set tWritten = ""
    If $$$ISERR(tSC) Quit tSC
    Set pResult = {}
    Do pResult.%Set("activated", 1, "boolean")
    Do pResult.%Set("requiresRestart", tChecked.%Get("requiresRestart"), "boolean")
    Quit tSC
}

/// <p>The key text <var>pBody</var> carries under <parameter>KEYFIELD</parameter>, or
/// <code>""</code>.</p>
ClassMethod KeyOf(pBody As %DynamicAbstractObject) As %String [ Private ]
{
    If '$IsObject(pBody) || 'pBody.%IsA("%Library.DynamicObject") Quit ""
    If pBody.%GetTypeOf(..#KEYFIELD) '= "string" Quit ""
    Quit pBody.%Get(..#KEYFIELD)
}

/// <p>The 422 refusal <var>pCode</var> on <parameter>KEYFIELD</parameter>, with nothing sent.</p>
ClassMethod Refused(pCode As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tReason = ##class(OcuPilot.Api.LicenseError).ReasonFor(pCode)
    Set pHttpStatus = 422
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#VALIDATIONFAILED, pCode, tReason)
    Set tViolation = {}
    Do tViolation.%Set("field", ..#KEYFIELD, "string")
    Do tViolation.%Set("code", pCode, "string")
    Do tViolation.%Set("reason", tReason, "string")
    Do pFault.%Set("detail", {"violations": [(tViolation)]})
    Quit $$$ERROR($$$GeneralError, pCode)
}

/// <p><var>pObject</var>'s <var>pField</var> as text: absent or null as <code>""</code>.</p>
ClassMethod Text(pObject As %DynamicObject, pField As %String) As %String [ Private ]
{
    Set tType = pObject.%GetTypeOf(pField)
    If (tType = "unassigned") || (tType = "null") || (tType = "object") || (tType = "array") Quit ""
    Quit pObject.%Get(pField) _ ""
}

/// <p>The admin port's answer: each branch is the vendor's own routes.</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    Quit ##super(pEndpoint, pType)
}

/// <p><method>Invoke</method>'s branches as a script (AD-59): a <code>License.Key</code>
/// <code>PUT</code> is the <code>VALIDATE</code> of the body's text and then the <code>PUT</code> of
/// the same text, each rendered with the body as it is handed here, whose key is a placeholder; every
/// other call is the admin port's script. The check's verdict is a guard a script cannot carry.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If (pEndpoint = ..#KEYENDPOINT) && (pType = "PUT") {
        Set tSteps = []
        Set tCheck = ..RestStep(..#KEYENDPOINT, ..#VALIDATETYPE, .pQuery, pBody, pContext)
        Set tPut = ..RestStep(..#KEYENDPOINT, "PUT", .pQuery, pBody, pContext)
        If '$IsObject(tCheck) || '$IsObject(tPut) Quit []
        Do tSteps.%Push(tCheck)
        Do tSteps.%Push(tPut)
        Quit tSteps
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, pContext)
}

}
