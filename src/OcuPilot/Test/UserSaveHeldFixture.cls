/// <p>Test-only <class>OcuPilot.Area.Permissions.UserSave</class> subclass whose
/// <method>PortClass</method> answers <class>OcuPilot.Test.HeldPutPort</class>: the fresh read
/// reaches the instance and the Save's <code>PUT</code> is recorded and never sent, so a leg that
/// expects a refusal cannot change the account it names.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.UserSaveHeldFixture Extends OcuPilot.Area.Permissions.UserSave
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.HeldPutPort"
}

}
