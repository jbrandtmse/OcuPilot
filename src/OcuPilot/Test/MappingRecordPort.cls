/// <p>Test-only <class>OcuPilot.Port.NamespacePort</class> subclass with one added seam, the
/// <class>OcuPilot.Test.DeviceRecordPort</class> seam on the mapping tools' own port: every mutating
/// call's request type, <code>name</code> query parameter, query parameter names and body are
/// recorded in a process-private global before the shipped port sends it, and every call of any
/// request type, reads included, is counted. Every call still reaches the instance through the
/// shipped port, which splits a mapping's composite id.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.MappingRecordPort Extends OcuPilot.Port.NamespacePort
{

ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set ^||OcuPilotMappingCalls($Increment(^||OcuPilotMappingCalls)) = pType
    If ..IsMutating(pEndpoint, pType) {
        Set tIndex = $Increment(^||OcuPilotMappingRecord)
        Set ^||OcuPilotMappingRecord(tIndex, "type") = pType
        Set ^||OcuPilotMappingRecord(tIndex, "name") = $Get(pQuery("name"))
        Set ^||OcuPilotMappingRecord(tIndex, "body") = $Select($IsObject(pBody): pBody.%ToJSON(), 1: "")
        Set tKeys = ""
        Set tKey = ""
        For {
            Set tKey = $Order(pQuery(tKey))
            If tKey = "" Quit
            Set tKeys = tKeys _ $Select(tKeys = "": "", 1: ",") _ tKey
        }
        Set ^||OcuPilotMappingRecord(tIndex, "query") = tKeys
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>Forget every recorded call.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotMappingRecord, ^||OcuPilotMappingCalls
}

/// <p>How many calls of any request type, reads included, were made since <method>Clear</method>.</p>
ClassMethod CallCount() As %Integer
{
    Quit +$Get(^||OcuPilotMappingCalls)
}

/// <p>The request types of every call since <method>Clear</method>, in order, comma-separated.</p>
ClassMethod CallTypes() As %String
{
    Set tTypes = ""
    For tI = 1:1:+$Get(^||OcuPilotMappingCalls) {
        Set tTypes = tTypes _ $Select(tI = 1: "", 1: ",") _ $Get(^||OcuPilotMappingCalls(tI))
    }
    Quit tTypes
}

/// <p>How many mutating calls were recorded since <method>Clear</method>.</p>
ClassMethod WriteCount() As %Integer
{
    Quit +$Get(^||OcuPilotMappingRecord)
}

/// <p>The last recorded body as JSON text, or <code>""</code>.</p>
ClassMethod LastWriteBody() As %String
{
    Quit $Get(^||OcuPilotMappingRecord(+$Get(^||OcuPilotMappingRecord), "body"))
}

/// <p>The last recorded request type, or <code>""</code>.</p>
ClassMethod LastType() As %String
{
    Quit $Get(^||OcuPilotMappingRecord(+$Get(^||OcuPilotMappingRecord), "type"))
}

/// <p>The query parameter names of the last recorded call, comma-separated in collation order.</p>
ClassMethod LastQueryKeys() As %String
{
    Quit $Get(^||OcuPilotMappingRecord(+$Get(^||OcuPilotMappingRecord), "query"))
}

/// <p>The last recorded <code>name</code> query parameter, or <code>""</code>.</p>
ClassMethod LastName() As %String
{
    Quit $Get(^||OcuPilotMappingRecord(+$Get(^||OcuPilotMappingRecord), "name"))
}

}
