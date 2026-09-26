/// <p>Test-only <class>OcuPilot.Port.ProviderPort</class> subclass whose <b>per-user</b> privilege
/// question answers from a declared table instead of from the instance, and which records which
/// account it was asked about.</p>
/// <p>It exists because <code>%UnitTest</code> runs as an account holding <code>%All</code>, for
/// which <code>$SYSTEM.Security.CheckUserPermission</code> answers yes to every resource name --
/// so a turn owner who has lost a grant cannot be driven in process any other way, and DW-1309 is
/// exactly about the difference between "this process" and "that account".</p>
/// <p><b>It replaces nothing else.</b> <method>GateClass</method> is the shipped gate, so
/// <method>OcuPilot.Port.ProviderPort.InvokeDraft</method> -- which still asks the calling process
/// -- is answered by the real check here, which is what lets one class assert that the two entries
/// ask different questions.</p>
/// <p><b>Not a <class>%UnitTest.TestCase</class></b>: it holds no assertions and runs no tests.</p>
Class OcuPilot.Test.ProviderOwnerProbe Extends OcuPilot.Port.ProviderPort
{

/// <p>Forget every grant and every recorded question.</p>
ClassMethod Reset()
{
    Kill ^||OcuPilotProviderOwnerProbe
}

/// <p>Answer yes for <var>pUser</var> on every pair. A user with no entry holds nothing, which is
/// what a revoked grant looks like to <code>CheckUserPermission</code>.</p>
ClassMethod Grant(pUser As %String)
{
    Set ^||OcuPilotProviderOwnerProbe("grant", pUser) = 1
}

/// <p>The accounts the port asked about since the last <method>Reset</method>, comma-joined in
/// name order. <b>This is the assertion DW-1309 turns on</b>: the port must have asked about the
/// turn owner, not about the process the job happens to run in.</p>
ClassMethod AskedUsers() As %String
{
    Set tOut = ""
    Set tUser = ""
    For {
        Set tUser = $Order(^||OcuPilotProviderOwnerProbe("asked", tUser))
        If tUser = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tUser
    }
    Quit tOut
}

/// <p>The switch, in place of the instance's own answer, with the account recorded.</p>
ClassMethod HoldsPairForUser(pUser As %String, pResource As %String, pPermission As %String) As %Boolean
{
    Set ^||OcuPilotProviderOwnerProbe("asked", pUser) = 1
    Quit ''$Get(^||OcuPilotProviderOwnerProbe("grant", pUser), 0)
}

}
