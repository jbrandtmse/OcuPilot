/// <p>Pins what the agent's MDX read leaves running (Story 20.35, AD-7, AD-31, AD-33, AD-65): a query past the time bound, and one the turn's Stop
/// reaches while the read polls, each answer <code>stopped</code> in the turn job's own process, the vendor reports the query finished
/// (<code>%GetQueryStatus</code> 100), and no process in <code>USER</code> runs <code>%DeepSee</code> code; the turn's stop, abandon and lease are
/// what <method>OcuPilot.Screen.Tool.AnalyticsMdxRead.MdxStopRequested</method> reads; and a run reserves no background run of this account.</p>
/// <p>The bound leg runs through <class>OcuPilot.Test.AnalyticsMdxReadFixture</class>, whose bound is two seconds, and the stop leg through the same
/// fixture, stopped after a second, so the seconds it answers (below the bound) show which of the two ended it.</p>
/// <p><b>What it needs from the environment:</b> <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because
/// <class>OcuPilot.Test.AnalyticsProbe</class> turns analytics on for <code>USER</code> and writes cubes there. Every turn a test begins is finished and
/// removed, and the probe is removed after the last test.</p>
Class OcuPilot.Test.AnalyticsMdxReadJob Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter FIXTURE = "OcuPilot.Test.AnalyticsMdxReadFixture";

Parameter MDXJOB = "OcuPilot.Test.AnalyticsMdxJob";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter TURN = "OcuPilot.Kernel.State.Turn";

/// <p>The grid's crossjoin of 2,000 by 2,000 positions: it runs for two minutes, so only the bound, a stop or a killed process ends it.</p>
Parameter SLOW = "SELECT {[Measures].[Amount]} ON 0, NON EMPTY CROSSJOIN([Sub].[H1].[Sub].Members,[Sub2].[H1].[Sub2].Members) ON 1 FROM [OcuPilotProbeGrid]";

/// <p>The same crossjoin with its dimensions swapped, so the stop leg's query is not the bound leg's: a run that finished would leave its answer in the
/// vendor's cache, and the same text would then be answered at once.</p>
Parameter SLOWSTOP = "SELECT {[Measures].[Amount]} ON 0, NON EMPTY CROSSJOIN([Sub2].[H1].[Sub2].Members,[Sub].[H1].[Sub].Members) ON 1 FROM [OcuPilotProbeGrid]";

/// <p>The definition id a probe turn is reserved under; the loop is not run, so nothing resolves it.</p>
Parameter DEFINITION = "OcuPilotProbeMdxReadJob";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsMdxReadJob turns analytics on in USER and writes cubes there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Create", $Username)
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsMdxReadJob left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

/// <p>That a stopped run left nothing running: the vendor reports the query <var>pStatement</var> finished and no process in <code>USER</code> runs
/// <code>%DeepSee</code> code, each polled for up to five seconds because a worker exits just after the vendor reports the cancel.</p>
Method AssertNothingRuns(pStatement As %String)
{
    Set tDeadline = $ZHorolog + 5
    For {
        Set tProcesses = $ClassMethod(..#MDXJOB, "DeepSeeProcesses")
        If (tProcesses = "") || ($ZHorolog > tDeadline) Quit
        Hang 0.25
    }
    Do $$$AssertEquals($ClassMethod(..#MDXJOB, "VendorStatus", pStatement), 100, "the vendor reports its query finished")
    Do $$$AssertEquals($ClassMethod(..#MDXJOB, "DeepSeeProcesses"), "", "and no process in USER runs %DeepSee code")
}

/// <p>Reserve and begin a probe turn of this account, holding its slot; its key. <method>Finish</method> ends and removes it.</p>
Method BeginTurn() As %String
{
    Set tLimits = ..#LIMITS
    Do $$$AssertStatusOK($ClassMethod(..#TURN, "GuardedReserve", $Username, ..#DEFINITION, "TURN.ABANDONED.JOBLOST", tLimits, .tKey, .tBusy, .tSweep), "a turn is reserved")
    If $Get(tKey) = "" Quit ""
    Do $$$AssertStatusOK($ClassMethod(..#TURN, "GuardedBegin", tKey, $Username, tLimits, .tBegun, .tStarted), "and begun")
    Quit tKey
}

/// <p>End turn <var>pKey</var> and remove it, its slot included.</p>
Method Finish(pKey As %String)
{
    Do $$$AssertStatusOK($ClassMethod(..#TURN, "GuardedFinish", pKey, $Username, $Parameter(..#TURN, "STATESTOPPED"), "TURN.STOPPED", "", "", 0, ..#LIMITS), "the turn is ended")
    Do $$$AssertStatusOK($ClassMethod(..#TURN, "GuardedDelete", pKey), "and removed")
    Do $$$AssertEquals($Data(^OcuPilotTurnSignal(pKey)), 0, "with its signals")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).SlotOwner($Username), "", "and no turn slot is left held")
}

/// <p>The read of <var>pStatement</var> through the fixture, scoped to <code>USER</code>: the result, with the seconds it took.</p>
Method Read(pStatement As %String, Output pResult, Output pTook As %Numeric) As %String
{
    Do ##class(OcuPilot.Kernel.Scope).Set("USER")
    Set tStart = $ZHorolog
    Set tSC = $ClassMethod(..#FIXTURE, "View", "", {"statement": (pStatement)}, 200, .pResult, .tHttp, .tFault)
    Set pTook = $ZHorolog - tStart
    Quit $Select($$$ISERR(tSC): tHttp _ " " _ tFault.%Get("code"), $IsObject(pResult): pResult.%ToJSON(), 1: "none")
}

/// <p>AC4: a query past the time bound is stopped in the turn job's own process: the read answers <code>stopped</code> with the bound's seconds,
/// and leaves nothing running. The fixture's bound is two seconds.</p>
/// <p>Mutation (Rule 19): let <method>OcuPilot.Port.AnalyticsPort.Waited</method> ignore its deadline -- the query runs on past the bound and this goes
/// red.</p>
Method TestAQueryPastTheBoundIsStoppedAndLeavesNothingRunning()
{
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "BoundSeconds"), 2, "the fixture's bound is two seconds")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Screen.Tool.AnalyticsMdxRead", "BoundSeconds"), 120, "and the production bound is AD-7's 120")
    Set tRuns = ##class(OcuPilot.Test.AnalyticsMdxRead).Runs()
    Set tSaid = ..Read(..#SLOW, .tResult, .tTook)
    Do $$$AssertEquals(tSaid, "{""namespace"":""USER"",""outcome"":""stopped"",""seconds"":2}", "the read is stopped at the bound")
    Do $$$AssertTrue(tTook < 14, "within the settle time of the bound: " _ $FNumber(tTook, "", 2) _ " s")
    Do ..AssertNothingRuns(..#SLOW)
    Do $$$AssertEquals(##class(OcuPilot.Test.AnalyticsMdxRead).Runs(), tRuns, "and no background run was reserved")
}

/// <p>AC4: the turn's Stop reaches a query the read is polling: with a turn begun and the read made on its behalf, a stop requested after a second,
/// once the vendor reports the query started, ends the read <code>stopped</code> within
/// <parameter>OcuPilot.Port.AnalyticsPort.MDXSETTLESECONDS</parameter> plus two seconds of it, with seconds below the bound, and leaves nothing
/// running.</p>
/// <p>Mutation (Rule 19): answer 0 from <method>OcuPilot.Screen.Tool.AnalyticsMdxRead.MdxStopRequested</method> -- the read runs to the bound, answers
/// two seconds and this goes red.</p>
Method TestTheTurnsStopEndsTheReadAndLeavesNothingRunning()
{
    Set tKey = ..BeginTurn()
    If tKey = "" Quit
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tKey)
    Job ##class(OcuPilot.Test.NavSettleJob).StopAfter(tKey, $Username, 1, ..#SLOWSTOP)::10
    Do $$$AssertTrue($Test, "the stop job starts")
    Set tChild = $ZChild
    Set tSaid = ..Read(..#SLOWSTOP, .tResult, .tTook)
    Do $$$AssertTrue($IsObject(tResult) && (tResult.%Get("outcome") = "stopped") && (tResult.%Get("seconds") < 2), "the read is stopped by the turn's stop, below the bound: " _ tSaid)
    Do $$$AssertTrue(tTook < (2 + $Parameter("OcuPilot.Port.AnalyticsPort", "MDXSETTLESECONDS")), "within the settle time of the stop: " _ $FNumber(tTook, "", 2) _ " s")
    Do ..AssertNothingRuns(..#SLOWSTOP)
    Set tDeadline = $ZHorolog + 5
    While $Data(^$JOB(tChild)) && ($ZHorolog < tDeadline) {
        Hang 0.1
    }
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ..Finish(tKey)
}

/// <p>The stop hook reads what <method>OcuPilot.Kernel.Agent.Loop.Boundary</method> reads between steps: a turn that is running and renewed is not
/// asked to stop, and one whose stop or abandon signal is set, whose lease is at least
/// <parameter>OcuPilot.Kernel.Agent.Limits.LEASESECONDS</parameter> old or which was never renewed is; a call outside a turn never is.</p>
/// <p>Mutation (Rule 19): drop the lease test from <method>OcuPilot.Screen.Tool.AnalyticsMdxRead.MdxStopRequested</method> -- the lapsed-lease leg goes
/// red; answer 0 there for a turn never renewed -- the never-renewed leg goes red.</p>
Method TestTheStopHookReadsTheTurnsStopAbandonAndLease()
{
    Set tTool = "OcuPilot.Screen.Tool.AnalyticsMdxRead"
    Do $$$AssertEquals($ClassMethod(tTool, "MdxStopRequested", ""), 0, "a call outside a turn is never asked to stop")
    Set tKey = ..BeginTurn()
    If tKey = "" Quit
    Do $$$AssertEquals($ClassMethod(tTool, "MdxStopRequested", tKey), 0, "a running, renewed turn is not")
    Set ^OcuPilotTurnSignal(tKey, "renewed") = $ClassMethod(..#TURN, "NowSeconds") - $Parameter(..#LIMITS, "LEASESECONDS")
    Do $$$AssertEquals($ClassMethod(tTool, "MdxStopRequested", tKey), 1, "a lapsed lease asks")
    Do $$$AssertStatusOK($ClassMethod(..#TURN, "GuardedRenew", tKey), "the lease is renewed")
    Do $$$AssertEquals($ClassMethod(tTool, "MdxStopRequested", tKey), 0, "and a renewed one does not")
    Set ^OcuPilotTurnSignal(tKey, "abandon") = 1
    Do $$$AssertEquals($ClassMethod(tTool, "MdxStopRequested", tKey), 1, "an abandon signal asks")
    Kill ^OcuPilotTurnSignal(tKey, "abandon")
    Do $$$AssertEquals($ClassMethod(tTool, "MdxStopRequested", tKey), 0, "which stops asking once it is gone")
    Kill ^OcuPilotTurnSignal(tKey, "renewed")
    Do $$$AssertEquals($ClassMethod(tTool, "MdxStopRequested", tKey), 1, "a turn that was never renewed asks")
    Do $$$AssertStatusOK($ClassMethod(..#TURN, "GuardedRenew", tKey), "the lease is renewed again")
    Do $$$AssertEquals($ClassMethod(tTool, "MdxStopRequested", tKey), 0, "and stops asking")
    Do $$$AssertStatusOK($ClassMethod(..#TURN, "GuardedRequestStop", tKey, $Username, .tFound), "the turn is asked to stop")
    Do $$$AssertEquals($ClassMethod(tTool, "MdxStopRequested", tKey), 1, "a stop signal asks")
    Do ..Finish(tKey)
}

}
