/// <p>Test-only <class>OcuPilot.Area.WebApp.WebAppSave</class> subclass whose
/// <method>PortClass</method> answers <class>OcuPilot.Test.HeldPutPort</class>: the fresh read
/// reaches the instance and the Save's <code>PUT</code> is recorded and never sent, so a leg that
/// expects a refusal cannot change the application it names.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.WebAppSaveHeldFixture Extends OcuPilot.Area.WebApp.WebAppSave
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.HeldPutPort"
}

}
