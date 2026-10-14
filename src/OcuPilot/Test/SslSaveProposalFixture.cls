/// <p>Test-only <class>OcuPilot.Area.Security.SslSave</class> subclass whose <method>PortClass</method> answers
/// <class>OcuPilot.Test.ProposalFixture</class>: the Save's fresh reads answer the fixture's armed object and every write
/// is recorded there and never reaches the instance, a create included. The prohibited set is the shipped one, reading the
/// instance's own target.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.SslSaveProposalFixture Extends OcuPilot.Area.Security.SslSave
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.ProposalFixture"
}

}
