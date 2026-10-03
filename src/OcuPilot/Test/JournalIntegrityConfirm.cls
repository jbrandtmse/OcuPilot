/// <p>Test-only <class>OcuPilot.Kernel.Proposal.Confirm</class> subclass whose one replaced seam is the
/// port a journal tool reaches its target through: <class>OcuPilot.Test.JournalIntegrityPort</class>,
/// so a confirmed integrity check is answered by the test's armed check. Everything else is the
/// shipped confirm.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.JournalIntegrityConfirm Extends OcuPilot.Kernel.Proposal.Confirm
{

ClassMethod PortClassOf(pToolClass As %String) As %String
{
    Quit "OcuPilot.Test.JournalIntegrityPort"
}

}
