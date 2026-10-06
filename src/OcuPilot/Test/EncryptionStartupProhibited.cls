/// <p>Test-only <class>OcuPilot.Kernel.Proposal.Prohibited</class> subclass that reads every target through
/// <class>OcuPilot.Test.EncryptionSeamPort</class>, so AD-10's startup arm judges the seam-held settings a
/// test arranged rather than the instance's own. Every predicate is the shipped set's.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.EncryptionStartupProhibited Extends OcuPilot.Kernel.Proposal.Prohibited
{

ClassMethod PortClassOf(pToolClass As %String) As %String [ Private ]
{
    Quit "OcuPilot.Test.EncryptionSeamPort"
}

}
