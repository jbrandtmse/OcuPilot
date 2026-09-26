/// <p>Test-only <class>OcuPilot.Port.OAuthRegisteredClientPort</class> subclass with added seams: every
/// mutating call's request type and body are recorded in a process-private global before the shipped
/// port sends it, a secret body as its key names alone, never a value; <method>Arm</method> answers an
/// <code>&lt;endpoint&gt;/&lt;type&gt;</code> as a vendor refusal at that status without calling the
/// vendor, counting each such answer -- a secret refusal quoting the secret, logged with its body as the
/// admin port logs a vendor refusal --; <method>DenyPair</method> makes <method>HoldsPair</method> answer
/// no for one pair; and every key-set fetch records the SSL/TLS configuration it was given, counted. Every
/// other call reaches the instance through the shipped port. The arming lasts until
/// <method>Clear</method>.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.OAuthRegisteredClientRecordPort Extends OcuPilot.Port.OAuthRegisteredClientPort
{

ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If ..IsMutating(pEndpoint, pType) {
        Set tIndex = $Increment(^||OcuPilotOAuthClientRecord)
        Set ^||OcuPilotOAuthClientRecord(tIndex, "type") = pType
        Set tRecorded = ""
        If $IsObject(pBody) {
            If pType = "SECRET" {
                Set tIterator = pBody.%GetIterator()
                While tIterator.%GetNext(.tKey, .tValue) {
                    Set tRecorded = tRecorded _ $Select(tRecorded = "": "", 1: ",") _ tKey
                }
            } Else {
                Set tRecorded = pBody.%ToJSON()
            }
        }
        Set ^||OcuPilotOAuthClientRecord(tIndex, "body") = tRecorded
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>Answer every later vendor call of <var>pEndpoint</var>'s <var>pType</var> as a refusal at HTTP
/// <var>pHttp</var>.</p>
ClassMethod Arm(pEndpoint As %String, pType As %String, pHttp As %Integer)
{
    Set ^||OcuPilotOAuthClientFail(pEndpoint _ "/" _ pType) = pHttp
}

/// <p>Answer no for pair <var>pPair</var> until <method>Clear</method>, as for a caller without it.</p>
ClassMethod DenyPair(pPair As %String)
{
    Set ^||OcuPilotOAuthClientDenied(pPair) = 1
}

/// <p>Forget every recorded call, armed type, denied pair, fetch and count.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotOAuthClientRecord, ^||OcuPilotOAuthClientFail, ^||OcuPilotOAuthClientFailCount, ^||OcuPilotOAuthClientDenied, ^||OcuPilotOAuthClientFetch
}

ClassMethod HoldsPair(pPair As %String) As %Boolean
{
    If $Get(^||OcuPilotOAuthClientDenied(pPair)) Quit 0
    Quit ##super(pPair)
}

/// <p>How many vendor calls of <var>pEndpoint</var>'s <var>pType</var> were answered as a refusal since
/// <method>Clear</method>.</p>
ClassMethod Reached(pEndpoint As %String, pType As %String) As %Integer
{
    Quit +$Get(^||OcuPilotOAuthClientFailCount(pEndpoint _ "/" _ pType))
}

ClassMethod Vendor(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    If ..Armed(pEndpoint, pType, pBody, .pResult, .pHttpStatus, .pFault, .tSC) Quit tSC
    Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

ClassMethod VendorLocated(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pLocation As %String) As %Status [ Private ]
{
    Set pLocation = ""
    If ..Armed(pEndpoint, pType, pBody, .pResult, .pHttpStatus, .pFault, .tSC) Quit tSC
    Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault, .pLocation)
}

/// <p>Whether <var>pEndpoint</var>'s <var>pType</var> is armed, answering the canned refusal in
/// <var>pSC</var> when it is.</p>
ClassMethod Armed(pEndpoint As %String, pType As %String, pBody, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pSC As %Status) As %Boolean [ Private ]
{
    Set pSC = $$$OK
    Set tKey = pEndpoint _ "/" _ pType
    Set tHttp = $Get(^||OcuPilotOAuthClientFail(tKey))
    If tHttp = "" Quit 0
    Set ^||OcuPilotOAuthClientFailCount(tKey) = $Get(^||OcuPilotOAuthClientFailCount(tKey)) + 1
    Set pResult = ""
    ; A vendor refusal can quote the value it refused, so a canned secret refusal quotes the secret,
    ; and is logged as the admin port logs one: with the body whose secrets the log line masks.
    Set tQuoted = ""
    If (pType = "SECRET") && $IsObject(pBody) && (pBody.%GetTypeOf("ClientSecret") = "string") Set tQuoted = " of " _ pBody.%Get("ClientSecret")
    Set pSC = ..Fail(pEndpoint, tHttp, $$$ERROR($$$GeneralError, "OcuPilot test: a canned vendor refusal" _ tQuoted), .pHttpStatus, .pFault, "", pBody)
    Quit 1
}

/// <p>Record the SSL/TLS configuration a key-set fetch is given, then fetch through the shipped
/// port.</p>
ClassMethod Fetch(pClient As %RegisteredObject, pSsl As %String, Output pSC As %Status)
{
    Set tIndex = $Increment(^||OcuPilotOAuthClientFetch)
    Set ^||OcuPilotOAuthClientFetch(tIndex) = pSsl
    Do ##super(pClient, pSsl, .pSC)
}

/// <p>How many key-set fetches were made since <method>Clear</method>, with the last one's SSL/TLS
/// configuration in <var>pSsl</var>.</p>
ClassMethod Fetches(Output pSsl As %String) As %Integer
{
    Set tCount = +$Get(^||OcuPilotOAuthClientFetch)
    Set pSsl = $Get(^||OcuPilotOAuthClientFetch(tCount))
    Quit tCount
}

/// <p>The request types of every mutating call since <method>Clear</method>, comma-separated.</p>
ClassMethod WriteTypes() As %String
{
    Set tTypes = ""
    For tI = 1:1:+$Get(^||OcuPilotOAuthClientRecord) {
        Set tTypes = tTypes _ $Select(tI = 1: "", 1: ",") _ $Get(^||OcuPilotOAuthClientRecord(tI, "type"))
    }
    Quit tTypes
}

/// <p>How many mutating calls of <var>pType</var>, or of any type when it is empty, were recorded.</p>
ClassMethod WriteCount(pType As %String = "") As %Integer
{
    Set tCount = 0
    For tI = 1:1:+$Get(^||OcuPilotOAuthClientRecord) {
        If (pType = "") || ($Get(^||OcuPilotOAuthClientRecord(tI, "type")) = pType) Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>The body of the last recorded call of <var>pType</var>: JSON text, a secret body's key names, or
/// <code>""</code>.</p>
ClassMethod LastBody(pType As %String) As %String
{
    Set tBody = ""
    For tI = 1:1:+$Get(^||OcuPilotOAuthClientRecord) {
        If $Get(^||OcuPilotOAuthClientRecord(tI, "type")) = pType Set tBody = $Get(^||OcuPilotOAuthClientRecord(tI, "body"))
    }
    Quit tBody
}

}
