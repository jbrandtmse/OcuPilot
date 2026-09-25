/// <p>Test-only <class>OcuPilot.Area.Permissions.RoleSave</class> subclass with one replaced seam:
/// <method>PortClass</method> answers <class>OcuPilot.Test.DeviceRecordPort</class>, so
/// <method>Update</method> runs for real against the instance and the body it sends is recorded.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.RoleSaveFixture Extends OcuPilot.Area.Permissions.RoleSave
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.DeviceRecordPort"
}

}
