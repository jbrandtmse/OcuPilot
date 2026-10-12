/// <p>Test-only <class>OcuPilot.Area.WebApp.RestServiceSave</class> subclass with one replaced seam:
/// <method>PortClass</method> answers <class>OcuPilot.Test.RestServiceRecordPort</class>, so <method>Create</method> runs
/// for real against the instance and every call it makes through the port is recorded.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.RestServiceSaveFixture Extends OcuPilot.Area.WebApp.RestServiceSave
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.RestServiceRecordPort"
}

}
