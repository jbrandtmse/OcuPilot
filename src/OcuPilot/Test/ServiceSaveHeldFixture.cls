/// <p>Test-only <class>OcuPilot.Area.Permissions.ServiceSave</class> subclass whose
/// <method>PortClass</method> answers <class>OcuPilot.Test.HeldPutPort</class>: the fresh read reaches
/// the instance and the Save's <code>PUT</code> is recorded and never sent, so a leg over the service
/// OcuPilot is served through can reach the port without changing it.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.ServiceSaveHeldFixture Extends OcuPilot.Area.Permissions.ServiceSave
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.HeldPutPort"
}

}
