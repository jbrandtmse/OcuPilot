/// <p>Fixture: a privilege gate holding exactly what a test granted it, so
/// <method>OcuPilot.Kernel.Audit.Ledger.ViewForUser</method>'s per-row evaluation can be driven in
/// process. The real check cannot be: <code>%UnitTest</code> runs as an account holding
/// <code>%All</code>, for which it answers yes to every resource name, including one the instance
/// does not define. The real check is exercised over the wire by
/// <class>OcuPilot.Test.LedgerWire</class>, as a throwaway principal.</p>
/// <p>The grants live in <code>^||OcuPilotLedgerGate</code>. The OcuPilot administrative pair is
/// held unless <method>DenyAdmin</method> was called, which is what makes the <b>row</b> gate
/// rather than the cross-user gate the thing under test by default.</p>
Class OcuPilot.Test.LedgerGate Extends OcuPilot.Screen.Gate
{

/// <p>Hold <var>pResource</var> at <var>pPermission</var> from now on.</p>
ClassMethod Grant(pResource As %String, pPermission As %String)
{
    Set ^||OcuPilotLedgerGate(pResource, pPermission) = 1
}

/// <p>Hold the OcuPilot administrative pair no longer, so the cross-user gate itself -- not the
/// per-row one -- is what a read is refused by. Its own node rather than a grant subscript, so no
/// resource name can collide with it.</p>
ClassMethod DenyAdmin()
{
    Set ^||OcuPilotLedgerGateDenyAdmin = 1
}

/// <p>Forget every grant, and the administrative denial.</p>
ClassMethod Clear()
{
    Kill ^||OcuPilotLedgerGate
    Kill ^||OcuPilotLedgerGateDenyAdmin
}

ClassMethod HoldsPrivilege(pResource As %String, pPermission As %String) As %Boolean
{
    If (pResource = ##class(OcuPilot.Kernel.State.Base).#ADMINRESOURCE) && (pPermission = "USE") Quit '$Get(^||OcuPilotLedgerGateDenyAdmin, 0)
    Quit ''$Get(^||OcuPilotLedgerGate(pResource, pPermission))
}

}
