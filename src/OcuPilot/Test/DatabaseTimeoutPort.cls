/// <p>Test-only <class>OcuPilot.Test.DatabaseRecordPort</class> whose queued disk operation is still
/// running at the port's bound (Story 18.4): a <parameter>OcuPilot.Port.AdminPort.QUEUEDWRITES</parameter>
/// call is recorded and answered 503 <code>PORT.TIMEOUT</code> without reaching the vendor, so
/// <class>OcuPilot.Port.DatabasePort</class>'s started conversion is what the caller sees. Every other
/// call is the record port's, sent to the instance.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.DatabaseTimeoutPort Extends OcuPilot.Test.DatabaseRecordPort
{

ClassMethod Call(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If '##class(OcuPilot.Port.AdminPort).IsQueuedWrite(pEndpoint, pType) Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set tIndex = $Increment(^||OcuPilotDatabaseCalls)
    Set ^||OcuPilotDatabaseCalls(tIndex) = $ListBuild(pEndpoint _ "/" _ pType, $Get(pQuery("name")) _ $Get(pQuery("dir")), $Select($IsObject(pBody): pBody.%ToJSON(), 1: ""), 1)
    Set pResult = ""
    Set pHttpStatus = 503
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#UNAVAILABLE, ##class(OcuPilot.Api.Error).#PORTTIMEOUT, "The instance did not finish that operation in time")
    Quit $$$ERROR($$$GeneralError, ##class(OcuPilot.Api.Error).#PORTTIMEOUT)
}

}
