/// <p>Test-only <class>OcuPilot.Kernel.Proposal.Prohibited</class> subclass with one replaced seam:
/// the live read goes to <class>OcuPilot.Test.ProposalFixture</class>'s armed object instead of the
/// admin port, so the <b>shipped</b> predicates run against a target a test composed.</p>
/// <p>Everything else -- the covered-type refusal, the predicate order, the rendered comparison and
/// the serving-path read -- is the shipped code.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.ProhibitedFixture Extends OcuPilot.Kernel.Proposal.Prohibited
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.ProposalFixture"
}

}
