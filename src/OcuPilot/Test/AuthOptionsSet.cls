/// <p>Test-only <class>OcuPilot.Kernel.Proposal.Prohibited</class> subclass that reads every target and every
/// application and service mask through <class>OcuPilot.Test.AuthOptionsSeamPort</class>, so AD-10's
/// authentication options arm judges what a test armed there. Every predicate is the shipped set's.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.AuthOptionsSet Extends OcuPilot.Kernel.Proposal.Prohibited
{

ClassMethod PortClassOf(pToolClass As %String) As %String [ Private ]
{
    Quit "OcuPilot.Test.AuthOptionsSeamPort"
}

}
