/// <p>Test-only <class>OcuPilot.Area.Permissions.RoleSave</class> subclass whose
/// <method>PortClass</method> answers <class>OcuPilot.Test.HeldPutPort</class> -- the fresh read
/// reaches the instance and the Save's <code>PUT</code> is recorded and never sent -- and whose
/// <method>ProhibitedClass</method> answers <class>OcuPilot.Test.ProhibitedFixture</class>, so a
/// census leg arms the set's input in this process.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.RoleSaveHeldFixture Extends OcuPilot.Area.Permissions.RoleSave
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.HeldPutPort"
}

ClassMethod ProhibitedClass() As %String
{
    Quit "OcuPilot.Test.ProhibitedFixture"
}

}
