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

/// <p>Wait <var>pSeconds</var>, then request a stop for <var>pUser</var>'s turn <var>pKey</var> (Story 20.35): the agent's MDX read polls the
/// turn's stop signal while a query runs, so a test starts this beside the read instead of waiting for a navigation directive as
/// <method>StopWhenPending</method> does. With <var>pStatement</var>, it then also waits, up to five seconds, until the vendor reports
/// that statement's query started in <code>USER</code> and not finished (status 10 to 99,
/// <method>OcuPilot.Test.AnalyticsMdxJob.VendorStatus</method>), so the stop reaches a query the read has started.</p>
ClassMethod StopAfter(pKey As %String, pUser As %String, pSeconds As %Numeric, pStatement As %String = "") [ ProcedureBlock = 1 ]
{
    Hang pSeconds
    If pStatement '= "" {
        Set tDeadline = $ZHorolog + 5
        For {
            Set tStatus = +##class(OcuPilot.Test.AnalyticsMdxJob).VendorStatus(pStatement)
            If ((tStatus >= 10) && (tStatus < 100)) || ($ZHorolog > tDeadline) Quit
            Hang 0.05
        }
    }
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedRequestStop(pKey, pUser, .tFound)
    Quit
}

}
