/// <p>Test-only: simulates the browser's own <code>POST /turn/:id/navigation</code> arriving from a
/// second process while the turn job's own wait loop
/// (<method>OcuPilot.Kernel.Agent.Loop.AnswerClientCall</method>) is running in the caller's process
/// (Story 4.7, AC4/AC7). Spawned with <code>JOB</code> from a test before it starts the loop that
/// will create the directive, so it polls for the directive to appear rather than being handed a
/// sequence number that does not exist yet.</p>
Class OcuPilot.Test.NavSettleJob Extends %RegisteredObject
{

/// <p>Poll turn <var>pKey</var>'s navigation directive until one is pending, then settle it with
/// <var>pOutcome</var>/<var>pCode</var>. Gives up silently after <var>pTimeoutSeconds</var> --
/// silently, because a job that never found a directive to settle is exactly the "browser never
/// answers" case a caller may be deliberately testing.</p>
ClassMethod SettleWhenPending(pKey As %String, pOutcome As %String, pCode As %String, pTimeoutSeconds As %Integer) [ ProcedureBlock = 1 ]
{
    Set tDeadline = $ZHorolog + pTimeoutSeconds
    Set tSeq = 0
    For {
        Do ##class(OcuPilot.Kernel.State.Nav).GuardedPending(pKey, .tSeq, .tRoute, .tEntityId, .tSettled, .tExistingOutcome, .tExistingCode)
        If (+tSeq > 0) && 'tSettled Quit
        If $ZHorolog > tDeadline Quit
        Hang 0.1
    }
    If (+tSeq > 0) && 'tSettled {
        Do ##class(OcuPilot.Kernel.State.Nav).GuardedSettle(pKey, tSeq, pOutcome, pCode, .tClaimed)
    }
    Quit
}

/// <p>Poll turn <var>pKey</var>'s navigation directive until one is pending, then request a stop
/// for <var>pUser</var> (Story 4.7, the I/O matrix's "Stop pressed during the wait" row) instead of
/// settling it -- the wait loop's own <method>OcuPilot.Kernel.Agent.Loop.Boundary</method> check is
/// what ends the turn, not this job. Gives up silently after <var>pTimeoutSeconds</var>, the same
/// as <method>SettleWhenPending</method>.</p>
ClassMethod StopWhenPending(pKey As %String, pUser As %String, pTimeoutSeconds As %Integer) [ ProcedureBlock = 1 ]
{
    Set tDeadline = $ZHorolog + pTimeoutSeconds
    Set tSeq = 0
    For {
        Do ##class(OcuPilot.Kernel.State.Nav).GuardedPending(pKey, .tSeq, .tRoute, .tEntityId, .tSettled, .tExistingOutcome, .tExistingCode)
        If (+tSeq > 0) && 'tSettled Quit
        If $ZHorolog > tDeadline Quit
        Hang 0.1
    }
    If (+tSeq > 0) && 'tSettled {
        Do ##class(OcuPilot.Kernel.State.Turn).GuardedRequestStop(pKey, pUser, .tFound)
    }
    Quit
}

}
