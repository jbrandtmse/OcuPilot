/// <p>Test-only <class>OcuPilot.Kernel.Proposal.Prohibited</class> subclass for Story 18.7: every tool's
/// port is the one a test names in <code>^||OcuPilotDatabaseWritePort</code>, or
/// <class>OcuPilot.Test.EncryptionSeamPort</class>, so the key-removal arm reads through the seam. The
/// predicates are the shipped set's.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.EncryptionProhibited Extends OcuPilot.Kernel.Proposal.Prohibited
{

ClassMethod PortClassOf(pToolClass As %String) As %String [ Private ]
{
    Quit $Get(^||OcuPilotDatabaseWritePort, "OcuPilot.Test.EncryptionSeamPort")
}

}
