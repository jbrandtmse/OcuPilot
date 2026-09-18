/// <p>Fixture: the shipped ledger with <class>OcuPilot.Test.LedgerGate</class> in place of the real
/// privilege gate, so a cross-user read's per-row evaluation can be driven in process. Everything
/// else -- the bounded read, the withheld count, the audit emission -- is the shipped code.</p>
Class OcuPilot.Test.LedgerGateProbe Extends OcuPilot.Kernel.Audit.Ledger
{

ClassMethod GateClass() As %String
{
    Quit "OcuPilot.Test.LedgerGate"
}

}
