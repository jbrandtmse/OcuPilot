/// <p>Test-only <class>OcuPilot.Area.Security.LdapSave</class> subclass whose
/// <method>PortClass</method> answers <class>OcuPilot.Test.HeldPutPort</class>: the fresh read reaches
/// the instance and the Save's <code>PUT</code> is recorded and never sent, so a leg can read the
/// complete body the Save composes.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.LdapSaveHeldFixture Extends OcuPilot.Area.Security.LdapSave
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.HeldPutPort"
}

}
