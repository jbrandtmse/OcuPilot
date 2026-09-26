/// <p>Test-only <class>OcuPilot.Port.OAuthAuthorizationServerPort</class> subclass with two added seams:
/// every mutating call's request type and body are recorded in a process-private global before the
/// shipped port sends it, a <code>CHANGEPWD</code> body as its key names alone, never a value; and
/// <method>Arm</method> answers an <code>&lt;endpoint&gt;/&lt;type&gt;</code> as a vendor refusal at
/// that status without calling the vendor, counting each such answer -- a password refusal quoting the
/// password, logged with its body as the admin port logs a vendor refusal --, while <method>DenyPair</method>
/// makes <method>HoldsPair</method> answer no for one pair. Every other call reaches the instance
/// through the shipped port. The arming lasts until <method>Clear</method>.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.OAuthAuthorizationServerRecordPort Extends OcuPilot.Port.OAuthAuthorizationServerPort
{

ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If ..IsMutating(pEndpoint, pType) {
        Set tIndex = $Increment(^||OcuPilotOAuthAuthRecord)
        Set ^||OcuPilotOAuthAuthRecord(tIndex, "type") = pType
        Set tRecorded = ""
        If $IsObject(pBody) {
            If pType = "CHANGEPWD" {
                Set tIterator = pBody.%GetIterator()
                While tIterator.%GetNext(.tKey, .tValue) {
                    Set tRecorded = tRecorded _ $Select(tRecorded = "": "", 1: ",") _ tKey
                }
            } Else {
                Set tRecorded = pBody.%ToJSON()
            }
        }
        Set ^||OcuPilotOAuthAuthRecord(tIndex, "body") = tRecorded
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>Answer every later vendor call of <var>pEndpoint</var>'s <var>pType</var> as a refusal at HTTP
/// <var>pHttp</var>.</p>
ClassMethod Arm(pEndpoint As %String, pType As %String, pHttp As %Integer)
{
    Set ^||OcuPilotOAuthAuthFail(pEndpoint _ "/" _ pType) = pHttp
}

/// <p>Answer no for pair <var>pPair</var> until <method>Clear</method>, as for a caller without it.</p>
ClassMethod DenyPair(pPair As %String)
{
    Set ^||OcuPilotOAuthAuthDenied(pPair) = 1
}

/// <p>Forget every recorded call, armed type, denied pair and count.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotOAuthAuthRecord, ^||OcuPilotOAuthAuthFail, ^||OcuPilotOAuthAuthFailCount, ^||OcuPilotOAuthAuthDenied
}

ClassMethod HoldsPair(pPair As %String) As %Boolean
{
    If $Get(^||OcuPilotOAuthAuthDenied(pPair)) Quit 0
    Quit ##super(pPair)
}

/// <p>How many vendor calls of <var>pEndpoint</var>'s <var>pType</var> were answered as a refusal since
/// <method>Clear</method>.</p>
ClassMethod Reached(pEndpoint As %String, pType As %String) As %Integer
{
    Quit +$Get(^||OcuPilotOAuthAuthFailCount(pEndpoint _ "/" _ pType))
}

ClassMethod Vendor(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tKey = pEndpoint _ "/" _ pType
    Set tHttp = $Get(^||OcuPilotOAuthAuthFail(tKey))
    If tHttp = "" Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set ^||OcuPilotOAuthAuthFailCount(tKey) = $Get(^||OcuPilotOAuthAuthFailCount(tKey)) + 1
    Set pResult = ""
    ; A vendor refusal can quote the value it refused, so a canned password refusal quotes the password,
    ; and is logged as the admin port logs one: with the body whose secrets the log line masks.
    Set tQuoted = ""
    If (pType = "CHANGEPWD") && $IsObject(pBody) && (pBody.%GetTypeOf("ServerPassword") = "string") Set tQuoted = " of " _ pBody.%Get("ServerPassword")
    Quit ..Fail(pEndpoint, tHttp, $$$ERROR($$$GeneralError, "OcuPilot test: a canned vendor refusal" _ tQuoted), .pHttpStatus, .pFault, "", pBody)
}

/// <p>The request types of every mutating call since <method>Clear</method>, comma-separated.</p>
ClassMethod WriteTypes() As %String
{
    Set tTypes = ""
    For tI = 1:1:+$Get(^||OcuPilotOAuthAuthRecord) {
        Set tTypes = tTypes _ $Select(tI = 1: "", 1: ",") _ $Get(^||OcuPilotOAuthAuthRecord(tI, "type"))
    }
    Quit tTypes
}

/// <p>How many mutating calls of <var>pType</var>, or of any type when it is empty, were recorded.</p>
ClassMethod WriteCount(pType As %String = "") As %Integer
{
    Set tCount = 0
    For tI = 1:1:+$Get(^||OcuPilotOAuthAuthRecord) {
        If (pType = "") || ($Get(^||OcuPilotOAuthAuthRecord(tI, "type")) = pType) Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>The body of the last recorded call of <var>pType</var>: JSON text, a <code>CHANGEPWD</code>
/// body's key names, or <code>""</code>.</p>
ClassMethod LastBody(pType As %String) As %String
{
    Set tBody = ""
    For tI = 1:1:+$Get(^||OcuPilotOAuthAuthRecord) {
        If $Get(^||OcuPilotOAuthAuthRecord(tI, "type")) = pType Set tBody = $Get(^||OcuPilotOAuthAuthRecord(tI, "body"))
    }
    Quit tBody
}

}
