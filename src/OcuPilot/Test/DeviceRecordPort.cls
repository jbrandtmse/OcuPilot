/// <p>Test-only <class>OcuPilot.Port.AdminPort</class> subclass with one added seam: every mutating
/// call's request type, <code>name</code> query parameter and body are recorded in a process-private
/// global before the shipped port sends it, so a test can compare what two callers sent, and every
/// call of any request type, reads included, is counted (<method>CallCount</method>). Every call
/// still reaches the instance through the shipped port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.DeviceRecordPort Extends OcuPilot.Port.AdminPort
{

ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set ^||OcuPilotDeviceCalls($Increment(^||OcuPilotDeviceCalls)) = pType
    If ..IsMutating(pEndpoint, pType) {
        Set tIndex = $Increment(^||OcuPilotDeviceRecord)
        Set ^||OcuPilotDeviceRecord(tIndex, "type") = pType
        Set ^||OcuPilotDeviceRecord(tIndex, "name") = $Get(pQuery("name"))
        Set ^||OcuPilotDeviceRecord(tIndex, "body") = $Select($IsObject(pBody): pBody.%ToJSON(), 1: "")
    }
    Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
}

/// <p>Forget every recorded call.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotDeviceRecord, ^||OcuPilotDeviceCalls
}

/// <p>How many calls of any request type, reads included, were made since <method>Clear</method>.</p>
ClassMethod CallCount() As %Integer
{
    Quit +$Get(^||OcuPilotDeviceCalls)
}

/// <p>The request types of every call since <method>Clear</method>, in order, comma-separated.</p>
ClassMethod CallTypes() As %String
{
    Set tTypes = ""
    For tI = 1:1:+$Get(^||OcuPilotDeviceCalls) {
        Set tTypes = tTypes _ $Select(tI = 1: "", 1: ",") _ $Get(^||OcuPilotDeviceCalls(tI))
    }
    Quit tTypes
}

/// <p>How many mutating calls were recorded since <method>Clear</method>.</p>
ClassMethod WriteCount() As %Integer
{
    Quit +$Get(^||OcuPilotDeviceRecord)
}

/// <p>The last recorded body as JSON text, or <code>""</code>.</p>
ClassMethod LastWriteBody() As %String
{
    Quit $Get(^||OcuPilotDeviceRecord(+$Get(^||OcuPilotDeviceRecord), "body"))
}

/// <p>The last recorded request type, or <code>""</code>.</p>
ClassMethod LastType() As %String
{
    Quit $Get(^||OcuPilotDeviceRecord(+$Get(^||OcuPilotDeviceRecord), "type"))
}

/// <p>The last recorded <code>name</code> query parameter, or <code>""</code>.</p>
ClassMethod LastName() As %String
{
    Quit $Get(^||OcuPilotDeviceRecord(+$Get(^||OcuPilotDeviceRecord), "name"))
}

}
