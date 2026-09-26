/// <p>Test-only <class>OcuPilot.Port.OAuthClientPort</class> subclass with one added seam: every
/// mutating call's request type, <code>applicationName</code> query parameter and body are recorded in
/// a process-private global before the shipped port sends it, and every call of any request type is
/// counted. A <code>CHANGESECRET</code> body is recorded as its key names alone, never a value. Every
/// call still reaches the instance through the shipped port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.OAuthClientRecordPort Extends OcuPilot.Port.OAuthClientPort
{

ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set ^||OcuPilotOAuthClientCalls($Increment(^||OcuPilotOAuthClientCalls)) = pType
    If ..IsMutating(pEndpoint, pType) {
        Set tIndex = $Increment(^||OcuPilotOAuthClientRecord)
        Set ^||OcuPilotOAuthClientRecord(tIndex, "type") = pType
        Set ^||OcuPilotOAuthClientRecord(tIndex, "name") = $Get(pQuery("applicationName"))
        Set tRecorded = ""
        If $IsObject(pBody) {
            If pType = "CHANGESECRET" {
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

/// <p>Forget every recorded call.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotOAuthClientRecord, ^||OcuPilotOAuthClientCalls
}

/// <p>The request types of every call since <method>Clear</method>, in order, comma-separated.</p>
ClassMethod CallTypes() As %String
{
    Set tTypes = ""
    For tI = 1:1:+$Get(^||OcuPilotOAuthClientCalls) {
        Set tTypes = tTypes _ $Select(tI = 1: "", 1: ",") _ $Get(^||OcuPilotOAuthClientCalls(tI))
    }
    Quit tTypes
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

/// <p>How many mutating calls were recorded since <method>Clear</method>.</p>
ClassMethod WriteCount() As %Integer
{
    Quit +$Get(^||OcuPilotOAuthClientRecord)
}

/// <p>The last recorded body: JSON text, a <code>CHANGESECRET</code> body's key names, or
/// <code>""</code>.</p>
ClassMethod LastWriteBody() As %String
{
    Quit $Get(^||OcuPilotOAuthClientRecord(+$Get(^||OcuPilotOAuthClientRecord), "body"))
}

/// <p>The last recorded request type, or <code>""</code>.</p>
ClassMethod LastType() As %String
{
    Quit $Get(^||OcuPilotOAuthClientRecord(+$Get(^||OcuPilotOAuthClientRecord), "type"))
}

/// <p>The last recorded <code>applicationName</code> query parameter, or <code>""</code>.</p>
ClassMethod LastName() As %String
{
    Quit $Get(^||OcuPilotOAuthClientRecord(+$Get(^||OcuPilotOAuthClientRecord), "name"))
}

}
