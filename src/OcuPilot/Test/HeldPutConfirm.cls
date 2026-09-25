/// <p>Test-only <class>OcuPilot.Kernel.Proposal.Confirm</class> subclass whose port is
/// <class>OcuPilot.Test.HeldPutPort</class>: the re-read and every write but a <code>PUT</code>
/// reach the instance, and a <code>PUT</code> is answered 503 without being sent. Everything else is
/// the shipped confirm, the ledger and the audit marker included.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.HeldPutConfirm Extends OcuPilot.Kernel.Proposal.Confirm
{

ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Test.HeldPutPort"
}

}
