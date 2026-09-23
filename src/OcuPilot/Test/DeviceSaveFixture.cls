/// <p>Test-only <class>OcuPilot.Area.OsMgmt.DeviceSave</class> subclass with one replaced seam:
/// <method>PortClass</method> answers <class>OcuPilot.Test.DeviceRecordPort</class>, so
/// <method>Create</method> and <method>Update</method> run for real against the instance and the body
/// they send is recorded. The name look-up, the subtype and alias reads and the prohibited set's
/// target read are not this seam and read through the tools' own port.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.DeviceSaveFixture Extends OcuPilot.Area.OsMgmt.DeviceSave
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.DeviceRecordPort"
}

}
