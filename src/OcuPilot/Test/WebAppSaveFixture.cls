/// <p>Test-only <class>OcuPilot.Area.WebApp.WebAppSave</class> subclass with one replaced seam:
/// <method>PortClass</method> answers <class>OcuPilot.Test.DeviceRecordPort</class>, so
/// <method>Update</method> runs for real against the instance and the body it sends is recorded. The
/// prohibited set's target read is not this seam and reads through the tool's own port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.WebAppSaveFixture Extends OcuPilot.Area.WebApp.WebAppSave
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.DeviceRecordPort"
}

}
