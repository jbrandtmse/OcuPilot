/// <p>Test-only <class>OcuPilot.Test.DeviceRecordPort</class> subclass: a <code>PUT</code> is
/// recorded as the parent records every write and answered 503 <code>PORT.UNAVAILABLE</code> without
/// reaching the vendor. Every other call -- reads and every other write type -- is recorded and sent
/// through the shipped port as the parent sends it.</p>
/// <p><b>No <code>PUT</code> this class receives changes the instance.</b></p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.HeldPutPort Extends OcuPilot.Test.DeviceRecordPort
{

/// <p>The HTTP status every held <code>PUT</code> answers.</p>
Parameter HELDSTATUS As %Integer = 503;

/// <p>The reason every held <code>PUT</code>'s fault carries.</p>
Parameter HELDREASON = "OcuPilot.Test.HeldPutPort holds every PUT.";

ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If pType '= "PUT" Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set ^||OcuPilotDeviceCalls($Increment(^||OcuPilotDeviceCalls)) = pType
    Set tIndex = $Increment(^||OcuPilotDeviceRecord)
    Set ^||OcuPilotDeviceRecord(tIndex, "type") = pType
    Set ^||OcuPilotDeviceRecord(tIndex, "name") = $Get(pQuery("name"))
    Set ^||OcuPilotDeviceRecord(tIndex, "body") = $Select($IsObject(pBody): pBody.%ToJSON(), 1: "")
    Set pResult = ""
    Set pHttpStatus = ..#HELDSTATUS
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#UNAVAILABLE, ##class(OcuPilot.Api.Error).#PORTUNAVAILABLE, ..#HELDREASON)
    Quit $$$ERROR($$$GeneralError, ..#HELDREASON)
}

}
