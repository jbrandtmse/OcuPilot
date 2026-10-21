/// <p>Pins the MDX run's job (Story 20.33, AD-7, AD-9, AD-41, AD-42, AD-65): the owner's cancel ends a running query <code>canceled</code>
/// within twelve seconds and leaves no job, no vendor query running and no process in <code>USER</code> running <code>%DeepSee</code>
/// code, for a query and for a drill-through's listing; the time bound stops a query or a listing the same way, a bound under a second
/// included; a run whose variable-resolved text holds a finding its start did not confirm is not
/// run, and runs, executing the finding, once the confirmation covers it; a cancel sent before the job begins ends it canceled with the
/// statement never run; and the job's failure line carries nothing of the statement.</p>
/// <p><b>What it needs from the environment:</b> <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because
/// <class>OcuPilot.Test.AnalyticsProbe</class> turns analytics on for <code>USER</code> and writes cubes there. Every run a test starts has
/// ended, and every run row it made is removed, before the test returns; the probe and the splice nodes are removed after the last
/// test.</p>
Class OcuPilot.Test.AnalyticsMdxJob Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter PRODUCTION = "OcuPilot.Area.Analytics.MdxQuery";

Parameter FIXTURE = "OcuPilot.Test.AnalyticsMdxFixture";

Parameter FAILING = "OcuPilot.Test.AnalyticsMdxFailing";

Parameter QUICK = "OcuPilot.Test.AnalyticsMdxQuick";

Parameter STORE = "OcuPilot.Kernel.State.SqlRun";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The grid's crossjoin of 2,000 by 2,000 positions: it runs for two minutes, so only a cancel, the bound or a killed job ends
/// it.</p>
Parameter SLOW = "SELECT {[Measures].[Amount]} ON 0, NON EMPTY CROSSJOIN([Sub].[H1].[Sub].Members,[Sub2].[H1].[Sub2].Members) ON 1 FROM [OcuPilotProbeGrid]";

/// <p>A statement of the same cost as <parameter>SLOW</parameter> that no other test runs, so the vendor holds nothing of it unless a job started it.</p>
Parameter NEVER = "SELECT {[Measures].[%COUNT]} ON 0, NON EMPTY CROSSJOIN([Sub].[H1].[Sub].Members,[Sub2].[H1].[Sub2].Members) ON 1 FROM [OcuPilotProbeGrid]";

/// <p>A statement whose resolved text holds a <code>%SEARCH</code> the fixture's variable supplies.</p>
Parameter RESOLVED = "SELECT {[Measures].[Amount]} ON 0 FROM [OcuPilotProbeGrid] WHERE $variable.v";

/// <p>A typed DRILLTHROUGH whose listing carries a pairwise count over the grid's 50,000 facts, which runs for minutes. The vendor runs a
/// listing inside the one call the run waits in, so only the run's alarm or a cancel reaching the listing's statement ends it. It names
/// <code>RETURN</code>, so its run is started confirmed.</p>
Parameter SLOWLISTING = "DRILLTHROUGH SELECT FROM [OcuPilotProbeGrid] RETURN Sub,(SELECT COUNT(*) FROM OcuPilotProbe_Analytics.Grid a, OcuPilotProbe_Analytics.Grid b WHERE a.Amount * b.Amount = 9999) AS N";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsMdxJob turns analytics on in USER and writes cubes there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Create", $Username)
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Quit ..Settle()
}

Method OnAfterAllTests() As %Status
{
    Set tSC = ..Settle()
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "Remove"))
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsMdxJob left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    Quit tSC
}

/// <p>Cancel every live run of this account, wait up to 20 seconds for each to end, then remove every row of the account's; an error when
/// a run is still live.</p>
Method Settle() As %Status
{
    Set tDeadline = $ZHorolog + 20
    For {
        Set tLive = 0
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT RunKey FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(UserName) = ? AND State IN ('queued', 'running')", $Username)
        While tResult.%Next() {
            Set tLive = tLive + 1
            Do $ClassMethod(..#PRODUCTION, "Cancel", tResult.%GetData(1), $Username, .tFound)
        }
        If (tLive = 0) || ($ZHorolog > tDeadline) Quit
        Hang 0.5
        Do $ClassMethod(..#STORE, "GuardedSweep", ..#LIMITS)
    }
    Do $ClassMethod(..#STORE, "GuardedForgetUser", $Username)
    If tLive Quit $$$ERROR($$$GeneralError, "an MDX run of this account was still live after 20 seconds")
    Quit $$$OK
}

/// <p>Reserve a run of <var>pStatement</var> for this account in <code>USER</code> and spawn its job through <var>pClass</var>, past the start
/// route; <var>pKey</var> is the run's id and <var>pChild</var> the job's process id.</p>
Method Begin(pClass As %String, pStatement As %String, Output pKey As %String, Output pChild As %Integer, pConfirmed As %Boolean = 0)
{
    Set tSC = $ClassMethod(..#STORE, "GuardedReserve", $Username, "USER", 1000, ..#LIMITS, .pKey, .tBusy, .tFull, .tSweep, "mdx")
    Do $$$AssertStatusOK(tSC, "a run is reserved")
    Do $$$AssertTrue($ClassMethod(pClass, "Spawn", pKey, $Username, "USER", $ListBuild(pStatement, "", "", pConfirmed), .pChild), "and its job is spawned")
}

/// <p>Run <var>pKey</var> as this account reads it, every quarter second until it no longer reads running, or for <var>pSeconds</var>.</p>
ClassMethod Await(pKey As %String, pSeconds As %Numeric = 20) As %DynamicObject
{
    Set tDeadline = $ZHorolog + pSeconds
    Set tView = ""
    For {
        Do $ClassMethod(..#PRODUCTION, "View", pKey, $Username, .tFound, .tView)
        If '$Get(tFound) || (tView.%Get("status") '= "running") || ($ZHorolog > tDeadline) Quit
        Hang 0.25
    }
    Quit tView
}

/// <p>Wait up to <var>pSeconds</var> for job <var>pChild</var> to exit: a run's row ends before its job closes its result sets.</p>
ClassMethod AwaitExit(pChild As %Integer, pSeconds As %Numeric = 10)
{
    Set tDeadline = $ZHorolog + pSeconds
    While $Data(^$JOB(pChild)) && ($ZHorolog < tDeadline) {
        Hang 0.1
    }
}

/// <p>A run's answer as one line: its status, then its result or refusal as JSON.</p>
ClassMethod Said(pView) As %String
{
    If '$IsObject($Get(pView)) Quit "absent"
    Set tLine = pView.%Get("status")
    If pView.%GetTypeOf("result") = "object" Set tLine = tLine _ " " _ pView.result.%ToJSON()
    If pView.%GetTypeOf("refusal") = "object" Set tLine = tLine _ " " _ pView.refusal.%ToJSON()
    Quit tLine
}

/// <p>The job id of run <var>pKey</var> once its row reads running, polled for up to <var>pSeconds</var>; <code>""</code> when it has not
/// begun by then.</p>
ClassMethod RunJob(pKey As %String, pSeconds As %Numeric = 10) As %String
{
    Set tJob = ""
    Set tDeadline = $ZHorolog + pSeconds
    For {
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT JobId FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = ? AND State = 'running'", pKey)
        If tResult.%Next() Set tJob = tResult.%GetData(1)
        If (tJob '= "") || ($ZHorolog > tDeadline) Quit
        Hang 0.05
    }
    Quit tJob
}

/// <p>The vendor's status for the query <var>pStatement</var> in <code>USER</code>: its result set prepared again names the same cube and
/// query key, and <code>%GetQueryStatus</code> reads that query's status; 100 means finished.</p>
ClassMethod VendorStatus(pStatement As %String) As %String
{
    Set tOut = "unread"
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "USER"
        Set tRS = ##class(%DeepSee.ResultSet).%New()
        Set tSC = tRS.%PrepareMDX(pStatement)
        If $$$ISOK(tSC) Set tOut = ##class(%DeepSee.ResultSet).%GetQueryStatus(tRS.%GetCubeName(), tRS.%GetQueryKey())
        Set tRS = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tOut = "raised " _ ex.Name
    }
    Quit tOut
}

/// <p>The processes of <code>USER</code> other than this one that run <code>%DeepSee</code> code, as <code>pid:routine</code>.</p>
ClassMethod DeepSeeProcesses() As %String
{
    Set tOut = ""
    Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT Pid, Routine FROM %SYS.ProcessQuery WHERE NameSpace = 'USER'")
    While tResult.%Next() {
        If (tResult.%GetData(1) '= $Job) && ($Extract(tResult.%GetData(2), 1, 8) = "%DeepSee") Set tOut = tOut _ tResult.%GetData(1) _ ":" _ tResult.%GetData(2) _ " "
    }
    Quit tOut
}

/// <p>That a stopped or canceled run left nothing running: its job <var>pChild</var> has exited, the vendor reports the query
/// <var>pStatement</var> finished (when <var>pRan</var>: a run canceled before its job began never started it), and no process in
/// <code>USER</code> runs <code>%DeepSee</code> code, each polled for up to five seconds because a worker exits just after the vendor
/// reports the cancel.</p>
Method AssertNothingRuns(pChild As %Integer, pStatement As %String, pRan As %Boolean = 1)
{
    Set tDeadline = $ZHorolog + 5
    For {
        Set tProcesses = ..DeepSeeProcesses()
        If ('$Data(^$JOB(pChild)) && (tProcesses = "")) || ($ZHorolog > tDeadline) Quit
        Hang 0.25
    }
    Do $$$AssertEquals($Data(^$JOB(pChild)), 0, "the run's job has exited")
    If pRan Do $$$AssertEquals(..VendorStatus(pStatement), 100, "the vendor reports its query finished")
    Do $$$AssertEquals(..DeepSeeProcesses(), "", "and no process in USER runs %DeepSee code")
}

/// <p>AC3: the owner's cancel of a running query ends the run <code>canceled</code> within twelve seconds with no answer, and leaves
/// nothing running.</p>
/// <p>Mutation (Rule 19): end the run <code>canceled</code> without calling <method>OcuPilot.Port.AnalyticsPort.MdxCancel</method> in
/// <method>OcuPilot.Area.Analytics.MdxQuery.Stop</method> -- the worker keeps running and the nothing-runs leg goes red.</p>
Method TestTheOwnersCancelEndsTheRunAndLeavesNothingRunning()
{
    Do ..Begin(..#PRODUCTION, ..#SLOW, .tKey, .tChild)
    Set tJob = ..RunJob(tKey, 10)
    Do $$$AssertNotEquals(tJob, "", "the run's job has begun")
    If tJob = "" Quit
    Hang 1
    Set tAsked = $ZHorolog
    Do $$$AssertStatusOK($ClassMethod(..#PRODUCTION, "Cancel", tKey, $Username, .tFound), "its owner cancels it")
    Do $$$AssertEquals(tFound, 1, "and the cancel finds it")
    Set tView = ..Await(tKey, 15)
    Set tTook = $ZHorolog - tAsked
    Do $$$AssertEquals(..Said(tView), "canceled", "the run reads canceled, with no answer")
    Do $$$AssertTrue(tTook < 12, "within twelve seconds of the cancel: " _ $FNumber(tTook, "", 2) _ " s")
    Do ..AssertNothingRuns(tChild, ..#SLOW)
}

/// <p>AC4: a query past the time bound is stopped: the run ends with the outcome <code>stopped</code> and the bound's seconds, and leaves
/// nothing running. The fixture's bound is two seconds.</p>
/// <p>Mutation (Rule 19): let <method>OcuPilot.Area.Analytics.MdxQuery.Execute</method> ignore its deadline -- the query runs on and this
/// goes red.</p>
Method TestAQueryPastTheBoundIsStoppedAndLeavesNothingRunning()
{
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "BoundSeconds"), 2, "the fixture's bound is two seconds")
    Do $$$AssertEquals($ClassMethod(..#PRODUCTION, "BoundSeconds"), 120, "and the production bound is AD-7's 120")
    Do ..Begin(..#FIXTURE, ..#SLOW, .tKey, .tChild)
    Set tView = ..Await(tKey, 40)
    Do $$$AssertEquals(..Said(tView), "ended {""outcome"":""stopped"",""seconds"":2}", "the run ends stopped at the bound")
    Do ..AssertNothingRuns(tChild, ..#SLOW)
}

/// <p>AC4: the time bound stops a listing as it stops a query: a typed DRILLTHROUGH whose listing outlasts the fixture's two seconds ends
/// <code>stopped</code> with the bound's seconds, and leaves nothing running.</p>
/// <p>Mutation (Rule 19): drop the alarm from <method>OcuPilot.Area.Analytics.MdxQuery.Execute</method>'s waiting branch -- the listing runs on
/// and this goes red.</p>
Method TestAListingPastTheBoundIsStoppedAndLeavesNothingRunning()
{
    Do ..Begin(..#FIXTURE, ..#SLOWLISTING, .tKey, .tChild, 1)
    Set tView = ..Await(tKey, 40)
    Do $$$AssertEquals(..Said(tView), "ended {""outcome"":""stopped"",""seconds"":2}", "the run ends stopped at the bound")
    Do ..AssertNothingRuns(tChild, ..#SLOWLISTING, 0)
}

/// <p>AC4: a bound under a second still stops a listing: the time left is rounded up to a whole second for the alarm, because an alarm of zero
/// seconds never fires. The quick fixture's bound is half a second.</p>
/// <p>Mutation (Rule 19): round the alarm down in <method>OcuPilot.Area.Analytics.MdxQuery.AlarmSeconds</method> -- the listing gets no alarm,
/// runs on and this goes red.</p>
Method TestABoundUnderASecondStillStopsAListing()
{
    Do ..Begin(..#QUICK, ..#SLOWLISTING, .tKey, .tChild, 1)
    Set tView = ..Await(tKey, 40)
    Do $$$AssertEquals(..Said(tView), "ended {""outcome"":""stopped"",""seconds"":0.5}", "the run ends stopped at the half-second bound")
    Do ..AssertNothingRuns(tChild, ..#SLOWLISTING, 0)
}

/// <p>AC3: the owner's cancel reaches a listing as it reaches a query: the run reads <code>canceled</code> within twelve seconds with no answer,
/// and leaves nothing running.</p>
/// <p>Mutation (Rule 19): send no <code>$SYSTEM.SQL.CancelQuery</code> from <method>OcuPilot.Area.Analytics.MdxQuery.CancelJob</method> -- the
/// listing runs on and this goes red.</p>
Method TestTheOwnersCancelEndsAListingRunCanceled()
{
    Do ..Begin(..#PRODUCTION, ..#SLOWLISTING, .tKey, .tChild, 1)
    Set tJob = ..RunJob(tKey, 10)
    Do $$$AssertNotEquals(tJob, "", "the run's job has begun")
    If tJob = "" Quit
    Hang 1
    Set tAsked = $ZHorolog
    Do $$$AssertStatusOK($ClassMethod(..#PRODUCTION, "Cancel", tKey, $Username, .tFound), "its owner cancels it")
    Set tView = ..Await(tKey, 15)
    Set tTook = $ZHorolog - tAsked
    Do $$$AssertEquals(..Said(tView), "canceled", "the run reads canceled, with no answer")
    Do $$$AssertTrue(tTook < 12, "within twelve seconds of the cancel: " _ $FNumber(tTook, "", 2) _ " s")
    Do ..AssertNothingRuns(tChild, ..#SLOWLISTING, 0)
}

/// <p>AC10: a statement whose variable-resolved text names <code>%SEARCH</code> is not run unconfirmed. The start's own check answers
/// <code>confirm</code> naming it, reserving nothing and leaving the node undefined; a job handed the same text without the confirmation
/// ends <code>failed</code> with <code>ANALYTICS.MDX.LOST</code> and the node still undefined; and once the confirmation covers it the run
/// executes it and the node is defined.</p>
/// <p>Mutation (Rule 19): skip the check on the resolved text in <method>OcuPilot.Port.AnalyticsPort.MdxPrepare</method> -- the start
/// answers no <code>confirm</code>, the unconfirmed job runs and this goes red.</p>
Method TestAResolvedTextWithAFindingIsNotRunUnlessConfirmed()
{
    Set tNode = $Parameter(..#FIXTURE, "SPLICENODE")
    Kill ^|"USER"|OcuPilotProbeMdxSplice(tNode)
    Set tBefore = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(UserName) = ?", $Username)
    Do tBefore.%Next()
    Set tCount = tBefore.%GetData(1)
    Set tSC = $ClassMethod(..#FIXTURE, "Check", "USER", ..#RESOLVED, 0, .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the start's check passes the gate")
    Do $$$AssertEquals($Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: "no answer"), "{""outcome"":""confirm"",""constructs"":[""%SEARCH""],""consequence"":""" _ $Parameter("OcuPilot.Port.AnalyticsPort", "MDXCONSEQUENCE") _ """}", "and answers confirm, naming %SEARCH")
    Do $$$AssertEquals($Data(^|"USER"|OcuPilotProbeMdxSplice(tNode)), 0, "its prepare executed nothing: the node is undefined")
    Set tAfter = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(UserName) = ?", $Username)
    Do tAfter.%Next()
    Do $$$AssertEquals(tAfter.%GetData(1), tCount, "and reserved no run")
    Do ..Begin(..#FIXTURE, ..#RESOLVED, .tKey, .tChild, 0)
    Set tView = ..Await(tKey, 20)
    Do $$$AssertEquals(..Said(tView), "failed {""code"":""ANALYTICS.MDX.LOST"",""reason"":""" _ ##class(OcuPilot.Api.AnalyticsError).#REASONMDXLOST _ """}", "a job handed the text without the confirmation ends failed, lost")
    Do $$$AssertEquals($Data(^|"USER"|OcuPilotProbeMdxSplice(tNode)), 0, "and executed nothing")
    Do $ClassMethod(..#STORE, "GuardedForgetUser", $Username)
    Do ..Begin(..#FIXTURE, ..#RESOLVED, .tKey, .tChild, 1)
    Set tView = ..Await(tKey, 20)
    Do $$$AssertEquals($Select($IsObject(tView): tView.status, 1: ""), "ended", "with the confirmation the run ends: " _ ..Said(tView))
    Do $$$AssertTrue($Data(^|"USER"|OcuPilotProbeMdxSplice(tNode)) > 0, "and the finding was executed: the node is defined")
}

/// <p>A finished run leaves no result set's local cache behind: the vendor clears it when the result set is closed, in the namespace it closes in, so the
/// job closes its result sets in the namespace they were made in. A plain run, a cell's drill-through, a typed DRILLTHROUGH, a prepare error and a
/// run held back for its confirmation each leave the count of <code>USER</code>'s local caches as it found it.</p>
/// <p>Mutation (Rule 19): drop <method>OcuPilot.Area.Analytics.MdxQuery.Release</method>'s calls -- the result sets close in the install namespace
/// and the count grows.</p>
Method TestAFinishedRunLeavesNoLocalCache()
{
    Set tBefore = $ClassMethod(..#PROBE, "LocalCaches")
    Set tGrid = "SELECT {[Measures].[Amount]} ON 0, NON EMPTY CROSSJOIN({[Sub].[H1].[Sub].&[1],[Sub].[H1].[Sub].&[2]},{[Sub2].[H1].[Sub2].&[0],[Sub2].[H1].[Sub2].&[1]}) ON 1 FROM [OcuPilotProbeGrid]"
    For tCase = $ListBuild(tGrid, "", ""), $ListBuild(tGrid, 2, 1), $ListBuild("DRILLTHROUGH SELECT FROM [OcuPilotProbeGrid]", "", ""), $ListBuild("SELEKT FROM [OcuPilotProbeGrid]", "", "") {
        Set tSC = $ClassMethod(..#STORE, "GuardedReserve", $Username, "USER", 1000, ..#LIMITS, .tKey, .tBusy, .tFull, .tSweep, "mdx")
        Do $ClassMethod(..#PRODUCTION, "Spawn", tKey, $Username, "USER", $ListBuild($List(tCase, 1), $List(tCase, 2), $List(tCase, 3), 0), .tChild)
        Set tView = ..Await(tKey, 30)
        Do $$$AssertEquals($Select($IsObject(tView): tView.status, 1: ""), "ended", "the run ends: " _ $Extract($List(tCase, 1), 1, 40))
        Do ..AwaitExit(tChild)
        Do $ClassMethod(..#STORE, "GuardedForgetUser", $Username)
    }
    Do ..Begin(..#FIXTURE, ..#RESOLVED, .tKey, .tChild, 0)
    Set tView = ..Await(tKey, 20)
    Do $$$AssertEquals($Select($IsObject(tView): tView.status, 1: ""), "failed", "a run held back for its confirmation ends failed")
    Do ..AwaitExit(tChild)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LocalCaches"), tBefore, "and none left a local result cache in USER")
}

/// <p>AC6: a cancel sent while the run is still queued ends it canceled once its job begins, its statement never run.</p>
/// <p>Mutation (Rule 19): drop the begin's cancel branch from <method>OcuPilot.Kernel.Shell.BackgroundRun.Run</method> -- the slow query
/// runs on and this goes red.</p>
Method TestACancelBeforeTheJobBeginsEndsTheRunCanceled()
{
    Set tSC = $ClassMethod(..#STORE, "GuardedReserve", $Username, "USER", 1000, ..#LIMITS, .tKey, .tBusy, .tFull, .tSweep, "mdx")
    Do $$$AssertStatusOK(tSC, "a run is reserved")
    Do $$$AssertStatusOK($ClassMethod(..#PRODUCTION, "Cancel", tKey, $Username, .tFound), "its owner cancels it while it is queued")
    Do $$$AssertEquals(tFound, 1, "and the cancel finds it")
    Set tAsked = $ZHorolog
    Do $$$AssertTrue($ClassMethod(..#PRODUCTION, "Spawn", tKey, $Username, "USER", $ListBuild(..#NEVER, "", "", 0), .tChild), "then its job is spawned")
    Set tView = ..Await(tKey, 10)
    Set tTook = $ZHorolog - tAsked
    Do $$$AssertEquals(..Said(tView), "canceled", "the run reads canceled, with no answer")
    Do $$$AssertTrue(tTook < 5, "within five seconds of its job's spawn: " _ $FNumber(tTook, "", 2) _ " s")
    Do ..AssertNothingRuns(tChild, ..#NEVER, 0)
    Do $$$AssertEquals(..VendorStatus(..#NEVER), 0, "and the vendor never started its statement")
}

/// <p>AC9: the job's own failure line names its failure and carries nothing of the statement. The failing fixture raises inside the job's
/// work, after the statement was handed over.</p>
/// <p>Mutation (Rule 19): hand the statement, as the status to log, from <method>OcuPilot.Kernel.Shell.BackgroundRun.Run</method> to its
/// log -- the log leg goes red.</p>
Method TestTheJobsFailureLineCarriesNoStatement()
{
    Set tMark = "OcuProbe2033Log" _ $Translate($ZTimeStamp, ",.", "")
    Set tLog = ##class(%File).NormalizeFilename(##class(OcuPilot.Port.LogSourcePort).FileFor("messages"), ##class(OcuPilot.Port.LogSourcePort).ManagerDirectory())
    Set tFrom = ##class(%File).GetFileSize(tLog)
    Do ..Begin(..#FAILING, "SELECT {[Measures].[Amount]} ON 0 FROM [OcuPilotProbeGrid] /* " _ tMark _ " */", .tKey, .tChild)
    Set tView = ..Await(tKey, 20)
    Do $$$AssertEquals($Select($IsObject(tView) && (tView.%GetTypeOf("refusal") = "object"): tView.status _ " " _ tView.refusal.code, 1: ..Said(tView)), "failed ANALYTICS.MDX.LOST", "the run whose job failed reads lost")
    Hang 0.5
    Set (tLogged, tFound) = ""
    Set tStream = ##class(%Stream.FileCharacter).%New()
    If tStream.LinkToFile(tLog) && (tStream.Size > tFrom) && tStream.MoveTo(tFrom + 1) {
        While 'tStream.AtEnd {
            Set tLine = tStream.ReadLine()
            If tLine [ """subsystem"":""mdxbackground""" Set tLogged = tLine
            If $ZConvert(tLine, "U") [ $ZConvert(tMark, "U") Set tFound = tLine
        }
    }
    Set tStream = ""
    Do $$$AssertNotEquals(tLogged, "", "the job wrote its failure line")
    Do $$$AssertEquals(tFound, "", "and no line carries the statement")
}

}
