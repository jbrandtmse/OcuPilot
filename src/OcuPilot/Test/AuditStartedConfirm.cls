/// <p>Test-only <class>OcuPilot.Kernel.Proposal.Confirm</class> subclass whose one replaced seam is
/// the port: <method>PortClassOf</method> answers <class>OcuPilot.Test.AuditStartedPort</class>, so
/// the confirm's re-read and write reach the instance through the audit port with a bound the
/// vendor's task never meets. Everything else is the shipped confirm.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.AuditStartedConfirm Extends OcuPilot.Kernel.Proposal.Confirm
{

ClassMethod PortClassOf(pToolClass As %String) As %String
{
    Quit "OcuPilot.Test.AuditStartedPort"
}

}
