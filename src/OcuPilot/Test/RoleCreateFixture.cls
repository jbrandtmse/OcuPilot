/// <p>Test-only <class>OcuPilot.Area.Permissions.RoleCreate</class> subclass with one replaced
/// seam: <method>PortClass</method> answers <class>OcuPilot.Test.ProposalFixture</class>, so
/// <method>Perform</method> runs for real and the write it would send is recorded instead of
/// creating a role. The name-taken read is not this seam and still reads the live instance.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.RoleCreateFixture Extends OcuPilot.Area.Permissions.RoleCreate
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.ProposalFixture"
}

}
