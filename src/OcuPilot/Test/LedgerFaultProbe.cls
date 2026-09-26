/// <p>Fixture: the shipped ledger reading a store whose windowed read always fails, so the
/// unreadable-store path can be driven without breaking the real store. It is its own store: the one
/// method <method>OcuPilot.Kernel.Audit.Ledger.ViewForUser</method> calls first answers an error
/// status, and everything after it -- the fault, its slug, its code and what reaches the log -- is
/// the shipped code.</p>
Class OcuPilot.Test.LedgerFaultProbe Extends OcuPilot.Kernel.Audit.Ledger
{

ClassMethod StoreClass() As %String
{
    Quit "OcuPilot.Test.LedgerFaultProbe"
}

/// <p>The failure a store that cannot be read answers. Its text carries a marker no wire envelope
/// may repeat, so a test can assert the raw status reached the log alone (AD-39).</p>
ClassMethod GuardedIdsForWindow(pUser As %String, pWindowHours As %String, pTurnKey As %String, pMaxRows As %Integer, Output pIds, Output pProblem As %String) As %Status
{
    Kill pIds
    Set pProblem = ""
    Quit $$$ERROR($$$GeneralError, "ledgerprobestorefault: the probe store refuses every read")
}

}
