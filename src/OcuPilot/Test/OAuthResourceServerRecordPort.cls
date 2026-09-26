/// <p>Test-only <class>OcuPilot.Port.OAuthResourceServerPort</class> subclass with one added seam: every
/// mutating call's request type, <code>name</code>, <code>service</code> and <code>key</code> query
/// parameters and body are recorded in a process-private global before the shipped port sends it. A
/// <code>CHANGESECRET</code> body is recorded as its key names alone, never a value. Every call still
/// reaches the instance through the shipped port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.OAuthResourceServerRecordPort Extends OcuPilot.Port.OAuthResourceServerPort
{

ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If ..IsMutating(pEndpoint, pType) {
        Set tIndex = $Increment(^||OcuPilotOAuthResourceRecord)
        Set ^||OcuPilotOAuthResourceRecord(tIndex, "type") = pType
        Set ^||OcuPilotOAuthResourceRecord(tIndex, "name") = $Get(pQuery("name"))
        Set ^||OcuPilotOAuthResourceRecord(tIndex, "mapping") = $Get(pQuery("service")) _ "/" _ $Get(pQuery("key"))
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
        Set ^||OcuPilotOAuthResourceRecord(tIndex, "body") = tRecorded
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>Forget every recorded call.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotOAuthResourceRecord
}

/// <p>The request types of every mutating call since <method>Clear</method>, comma-separated.</p>
ClassMethod WriteTypes() As %String
{
    Set tTypes = ""
    For tI = 1:1:+$Get(^||OcuPilotOAuthResourceRecord) {
        Set tTypes = tTypes _ $Select(tI = 1: "", 1: ",") _ $Get(^||OcuPilotOAuthResourceRecord(tI, "type"))
    }
    Quit tTypes
}

/// <p>How many mutating calls of <var>pType</var>, or of any type when it is empty, were recorded
/// since <method>Clear</method>.</p>
ClassMethod WriteCount(pType As %String = "") As %Integer
{
    Set tCount = 0
    For tI = 1:1:+$Get(^||OcuPilotOAuthResourceRecord) {
        If (pType = "") || ($Get(^||OcuPilotOAuthResourceRecord(tI, "type")) = pType) Set tCount = tCount + 1
    }
    Quit tCount
}

/// <p>The body of the last recorded call of <var>pType</var>: JSON text, a <code>CHANGESECRET</code>
/// body's key names, or <code>""</code>.</p>
ClassMethod LastBody(pType As %String) As %String
{
    Set tBody = ""
    For tI = 1:1:+$Get(^||OcuPilotOAuthResourceRecord) {
        If $Get(^||OcuPilotOAuthResourceRecord(tI, "type")) = pType Set tBody = $Get(^||OcuPilotOAuthResourceRecord(tI, "body"))
    }
    Quit tBody
}

/// <p>The <code>service/key</code> of every recorded call of <var>pType</var>, comma-separated.</p>
ClassMethod RecordedMappings(pType As %String) As %String
{
    Set tMappings = ""
    For tI = 1:1:+$Get(^||OcuPilotOAuthResourceRecord) {
        If $Get(^||OcuPilotOAuthResourceRecord(tI, "type")) '= pType Continue
        Set tMappings = tMappings _ $Select(tMappings = "": "", 1: ",") _ $Get(^||OcuPilotOAuthResourceRecord(tI, "mapping"))
    }
    Quit tMappings
}

}
