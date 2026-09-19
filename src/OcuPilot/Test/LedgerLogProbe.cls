/// <p>Fixture: the shipped ledger with its one reporting seam
/// (<method>OcuPilot.Kernel.Audit.Ledger.LogFailure</method>) routed through
/// <class>OcuPilot.Test.FaultProbe</class>, so a test reads what a ledger failure reported -- or
/// reads that none was reported -- out of <class>OcuPilot.Test.LogProbe</class>'s capture rather
/// than out of <file>messages.log</file>. Everything else is the shipped code.</p>
Class OcuPilot.Test.LedgerLogProbe Extends OcuPilot.Kernel.Audit.Ledger
{

ClassMethod LogFailure(pMessage As %String, pStatus As %Status)
{
    Do ##class(OcuPilot.Test.FaultProbe).LogRaw(..#LOGSUBSYSTEM, pMessage, pStatus, ##class(OcuPilot.Api.Error).#LEDGERUNAVAILABLE)
}

}
