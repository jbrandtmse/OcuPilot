/// <p>Test-only <class>OcuPilot.Area.Permissions.UserCreate</class> subclass with one replaced
/// seam: <method>PortClass</method> answers <class>OcuPilot.Test.ProposalFixture</class>, so
/// <method>Perform</method> runs for real and the write it would send is recorded instead of
/// creating an account. The name-taken read is not this seam and still reads the live instance.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.UserCreateFixture Extends OcuPilot.Area.Permissions.UserCreate
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.ProposalFixture"
}

}
