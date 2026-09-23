/// <p>Test-only <class>OcuPilot.Area.Permissions.ResourceSave</class> subclass with one replaced
/// seam: <method>PortClass</method> answers <class>OcuPilot.Test.ProposalFixture</class>, so
/// <method>Create</method> and <method>Update</method> run for real, the edit's fresh read answers the
/// fixture's armed object, and the write they would send is recorded instead of reaching the
/// instance. The name-taken read and the prohibited set's target read are not this seam and still
/// read the live instance.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.ResourceFixture Extends OcuPilot.Area.Permissions.ResourceSave
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.ProposalFixture"
}

}
