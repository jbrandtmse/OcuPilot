/// <p>Test-only <class>OcuPilot.Kernel.Proposal.Prohibited</class> subclass that reads every target through
/// <class>OcuPilot.Test.MftSeamPort</class>, so AD-10's sweep judges the state a test armed. Every predicate is
/// the shipped set's.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.MftSet Extends OcuPilot.Kernel.Proposal.Prohibited
{

ClassMethod PortClassOf(pToolClass As %String) As %String [ Private ]
{
    Quit "OcuPilot.Test.MftSeamPort"
}

}
