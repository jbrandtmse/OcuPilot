/// <p>Pins the background SQL run store (Story 19.15, AD-9, AD-41): a reserve inserts one
/// <code>queued</code> row, refuses a second for an owner whose run is live and a run past the
/// instance cap, ends the owner's lost run before it counts, replaces the owner's ended run and sweeps
/// even when it refuses; begin, finish and the cancel flag; the owner's view and nobody else's; a lost
/// run ended <code>failed</code> while a held one stays live; and the sweep, through its clock seam
/// and never ahead of the instance's clock, deleting only a run past retention.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed. It writes rows for three owner
/// names no account holds (<parameter>USERA</parameter>, <parameter>USERB</parameter>,
/// <parameter>USERC</parameter>) and removes every row of theirs after each test; one test starts a
/// child process that holds a run's lock and ends it before returning.</p>
Class OcuPilot.Test.SqlRunStore Extends %UnitTest.TestCase
{

Parameter STORE = "OcuPilot.Kernel.State.SqlRun";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter USERA = "OcuProbe1915StoreA";

Parameter USERB = "OcuProbe1915StoreB";

Parameter USERC = "OcuProbe1915StoreC";

/// <p>The prefix every owner name here starts with.</p>
Parameter OWNERPREFIX = "OcuProbe1915Store";

Method OnBeforeOneTest() As %Status
{
    Quit ..Clear()
}

Method OnAfterOneTest() As %Status
{
    Quit ..Clear()
}

/// <p>Delete every row of this class's owners.</p>
ClassMethod Clear() As %Status
{
    Set tResult = ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM OcuPilot_Kernel_State.SqlRun WHERE UserName %STARTSWITH ?", ..#OWNERPREFIX)
    If tResult.%SQLCODE < 0 Quit $$$ERROR($$$GeneralError, "the store's probe rows could not be cleared: SQLCODE " _ tResult.%SQLCODE)
    Quit $$$OK
}

/// <p>Run <var>pSql</var> with <var>pArgs</var>, answering its SQLCODE.</p>
ClassMethod Exec(pSql As %String, pArgs...) As %Integer
{
    Quit ##class(%SQL.Statement).%ExecDirect(, pSql, pArgs...).%SQLCODE
}

/// <p>How many rows <var>pUser</var> has.</p>
ClassMethod Rows(pUser As %String) As %Integer
{
    Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(UserName) = ?", pUser)
    If (tResult.%SQLCODE < 0) || 'tResult.%Next() Quit -1
    Quit +tResult.%GetData(1)
}

/// <p>How many queued or running rows the instance holds whose owner is none of this class's.</p>
ClassMethod ForeignLive() As %Integer
{
    Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.SqlRun WHERE State IN ('queued', 'running') AND NOT (UserName %STARTSWITH ?)", ..#OWNERPREFIX)
    If (tResult.%SQLCODE < 0) || 'tResult.%Next() Quit -1
    Quit +tResult.%GetData(1)
}

/// <p>Reserve a run of <var>pUser</var> in USER under the cap <var>pCap</var>.</p>
ClassMethod Reserve(pUser As %String, pCap As %Integer, Output pKey As %String, Output pBusy As %String, Output pFull As %Boolean) As %Status
{
    Quit $ClassMethod(..#STORE, "GuardedReserve", pUser, "USER", pCap, ..#LIMITS, .pKey, .pBusy, .pFull, .tSweep)
}

/// <p>Run <var>pKey</var> as <var>pUser</var> reads it, as one line: <code>found status
/// cancelRequested</code>, then the result or the refusal as JSON when one is present.</p>
ClassMethod Seen(pKey As %String, pUser As %String) As %String
{
    Set tSC = $ClassMethod(..#STORE, "GuardedViewForOwner", pKey, pUser, ..#LIMITS, .tFound, .tView)
    If $$$ISERR(tSC) Quit "error " _ $System.Status.GetErrorText(tSC)
    If 'tFound Quit "0"
    Set tLine = "1 " _ tView.status _ " " _ $Select(tView.cancelRequested: "true", 1: "false")
    If tView.%GetTypeOf("result") = "object" Set tLine = tLine _ " result " _ tView.result.%ToJSON()
    If tView.%GetTypeOf("refusal") = "object" Set tLine = tLine _ " refusal " _ tView.refusal.%ToJSON()
    Quit tLine
}

/// <p>A reserve inserts one queued row, and a second reserve of the same owner while the first is live
/// names it and inserts nothing.</p>
/// <p>Mutation (Rule 19): skip the per-owner check in
/// <method>OcuPilot.Kernel.State.SqlRun.GuardedReserve</method> -- the busy leg goes red.</p>
Method TestAReserveInsertsOneRowAndRefusesALiveOwner()
{
    Do $$$AssertStatusOK(..Reserve(..#USERA, 1000, .tKey, .tBusy, .tFull), "a run is reserved")
    Do $$$AssertTrue($Match(tKey, "^[0-9a-f]{32}$"), "its id is 32 lower-case hex characters: " _ tKey)
    Do $$$AssertEquals(tBusy _ "|" _ tFull, "|0", "and neither refusal answers")
    Do $$$AssertEquals(..Seen(tKey, ..#USERA), "1 running false", "the queued row reads running to its owner")
    Do $$$AssertStatusOK(..Reserve(..#USERA, 1000, .tKey2, .tBusy2, .tFull2), "a second reserve of that owner answers")
    Do $$$AssertEquals(tKey2 _ "|" _ tBusy2, "|" _ tKey, "naming the live run and reserving nothing")
    Do $$$AssertEquals(..Rows(..#USERA), 1, "so the owner keeps one row")
}

/// <p>A reserve past the instance cap is refused and inserts nothing, counting every owner's live
/// run.</p>
/// <p>Mutation (Rule 19): skip the instance count in
/// <method>OcuPilot.Kernel.State.SqlRun.GuardedReserve</method> -- the full leg goes red.</p>
Method TestTheInstanceCapRefusesAnotherOwner()
{
    Set tCap = ..ForeignLive() + 2
    Do $$$AssertStatusOK(..Reserve(..#USERA, tCap, .tA, .tBusy, .tFull), "the first owner reserves")
    Do $$$AssertStatusOK(..Reserve(..#USERB, tCap, .tB, .tBusy, .tFull), "and the second")
    Do $$$AssertTrue((tA '= "") && (tB '= ""), "both are reserved")
    Do $$$AssertStatusOK(..Reserve(..#USERC, tCap, .tC, .tBusy, .tFull), "a third owner's reserve answers")
    Do $$$AssertEquals(tC _ "|" _ tBusy _ "|" _ tFull, "||1", "refused at the cap")
    Do $$$AssertEquals(..Rows(..#USERC), 0, "with no row inserted")
}

/// <p>A reserve ends the owner's lost run before it counts the owner's live runs, so an owner whose job
/// died is not refused busy and keeps one row.</p>
/// <p>Mutation (Rule 19): read the row's state in <method>OcuPilot.Kernel.State.SqlRun.GuardedReserve</method>
/// in place of <method>OcuPilot.Kernel.State.SqlRun.Reconcile</method> -- the dead run is named busy and
/// this goes red.</p>
Method TestAReserveEndsTheOwnersLostRunFirst()
{
    Do ..Reserve(..#USERA, 1000, .tDead)
    Do $$$AssertEquals(..Exec("UPDATE OcuPilot_Kernel_State.SqlRun SET State = 'running', JobId = '1' WHERE %EXACT(RunKey) = ?", tDead), 0, "a run reads running with no job holding it")
    Do $$$AssertStatusOK(..Reserve(..#USERA, 1000, .tKey, .tBusy, .tFull), "the owner reserves again")
    Do $$$AssertEquals(($Match(tKey, "^[0-9a-f]{32}$") && (tKey '= tDead)) _ "|" _ tBusy _ "|" _ tFull, "1||0", "a new run, not refused busy")
    Do $$$AssertEquals(..Seen(tDead, ..#USERA) _ " " _ ..Rows(..#USERA), "0 1", "the lost run is gone and the owner keeps one row")
}

/// <p>A reserve refused busy still sweeps a run past its retention.</p>
/// <p>Mutation (Rule 19): sweep in <method>OcuPilot.Kernel.State.SqlRun.GuardedReserve</method> only
/// when it inserted a row -- the expired run stays and this goes red.</p>
Method TestARefusedReserveStillSweeps()
{
    Do ..Reserve(..#USERA, 1000, .tLive)
    Do ..Reserve(..#USERB, 1000, .tOld)
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedFinish", tOld, "ended", "{""outcome"":""done""}"), "another owner's run ends")
    Set tEnded = ##class(OcuPilot.Kernel.State.Turn).IsoOfSeconds(##class(OcuPilot.Kernel.State.Turn).NowSeconds() - $Parameter(..#LIMITS, "RETENTIONSECONDS") - 60)
    Do $$$AssertEquals(..Exec("UPDATE OcuPilot_Kernel_State.SqlRun SET EndedAt = ? WHERE %EXACT(RunKey) = ?", tEnded, tOld), 0, "and ended before its retention")
    Do $$$AssertStatusOK(..Reserve(..#USERA, 1000, .tKey, .tBusy, .tFull), "the first owner's second reserve answers")
    Do $$$AssertEquals(tKey _ "|" _ tBusy, "|" _ tLive, "refused busy")
    Do $$$AssertEquals(..Seen(tOld, ..#USERB), "0", "and the expired run is swept all the same")
}

/// <p>An owner's new run replaces that owner's ended run, and another owner's ended run stays.</p>
Method TestANewRunReplacesTheOwnersEndedRun()
{
    Do ..Reserve(..#USERA, 1000, .tOld)
    Do ..Reserve(..#USERB, 1000, .tOther)
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedFinish", tOld, "ended", "{""outcome"":""done""}"), "the first run ends")
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedFinish", tOther, "ended", "{""outcome"":""done""}"), "and another owner's")
    Do $$$AssertStatusOK(..Reserve(..#USERA, 1000, .tNew), "the owner reserves again")
    Do $$$AssertTrue((tNew '= "") && (tNew '= tOld), "a new run")
    Do $$$AssertEquals(..Seen(tOld, ..#USERA), "0", "the ended run is gone")
    Do $$$AssertEquals(..Rows(..#USERA), 1, "so the owner keeps one row")
    Do $$$AssertEquals($Piece(..Seen(tOther, ..#USERB), " ", 1, 2), "1 ended", "and another owner's ended run stays")
}

/// <p>Begin moves the owner's queued run to running once; finish ends it with its answer, read back
/// by its owner alone; a begin for another owner begins nothing.</p>
Method TestBeginFinishAndTheOwnersView()
{
    Do ..Reserve(..#USERA, 1000, .tKey)
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedBegin", tKey, ..#USERB, .tBegun, .tCancel), "a begin for another owner answers")
    Do $$$AssertEquals(tBegun, 0, "and begins nothing")
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedBegin", tKey, ..#USERA, .tBegun, .tCancel), "the owner's run begins")
    Do $$$AssertEquals(tBegun _ " " _ tCancel, "1 0", "once, with no cancel asked")
    Set tRow = ##class(%SQL.Statement).%ExecDirect(, "SELECT State, JobId, StartedAt FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = ?", tKey)
    Do $$$AssertTrue(tRow.%Next() && (tRow.%GetData(1) = "running") && (tRow.%GetData(2) = $Job) && (tRow.%GetData(3) '= ""), "it is running, stamped with this process and its start")
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedBegin", tKey, ..#USERA, .tBegun, .tCancel), "a second begin answers")
    Do $$$AssertEquals(tBegun, 0, "and begins nothing")
    Set tAnswer = "{""kind"":""query"",""outcome"":""rows"",""columns"":[""Name""],""rows"":[[""n1""]],""truncated"":false}"
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedFinish", tKey, "ended", tAnswer), "it ends")
    Do $$$AssertEquals(..Seen(tKey, ..#USERA), "1 ended false result " _ tAnswer, "and its owner reads its answer")
    Do $$$AssertEquals(..Seen(tKey, ..#USERB), "0", "which nobody else finds")
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedFinish", tKey, "failed", "{""code"":""X""}"), "a second finish answers")
    Do $$$AssertEquals($Piece(..Seen(tKey, ..#USERA), " ", 1, 2), "1 ended", "and leaves the ended run as it was")
}

/// <p>The owner's cancel flag ends a run canceled with no answer; nobody else's cancel finds it; and a
/// cancel of an ended run leaves it as it is.</p>
Method TestACancelFlagEndsTheRunCanceled()
{
    Do ..Reserve(..#USERA, 1000, .tKey)
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedCancel", tKey, ..#USERB, .tFound, .tJob, .tLive), "another owner's cancel answers")
    Do $$$AssertEquals(tFound, 0, "and finds nothing")
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedCancel", tKey, ..#USERA, .tFound, .tJob, .tLive), "the owner's cancel answers")
    Do $$$AssertEquals(tFound _ " " _ tLive _ " " _ tJob, "1 0 ", "found, not live while queued")
    Do $$$AssertEquals(..Seen(tKey, ..#USERA), "1 running true", "the run carries the flag")
    Do $ClassMethod(..#STORE, "GuardedBegin", tKey, ..#USERA, .tBegun, .tCancel)
    Do $$$AssertEquals(tBegun _ " " _ tCancel, "1 1", "its begin reports the cancel")
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedFinish", tKey, "ended", "{""outcome"":""done""}"), "it ends")
    Do $$$AssertEquals(..Seen(tKey, ..#USERA), "1 canceled true", "canceled, with no answer")
    Do ..Reserve(..#USERB, 1000, .tEnded)
    Do $ClassMethod(..#STORE, "GuardedFinish", tEnded, "ended", "{""outcome"":""done""}")
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedCancel", tEnded, ..#USERB, .tFound, .tJob, .tLive), "a cancel of an ended run answers")
    Do $$$AssertEquals(tFound _ " " _ tLive, "1 0", "found and not live")
    Do $$$AssertEquals(..Seen(tEnded, ..#USERB), "1 ended false result {""outcome"":""done""}", "and the run is as it was")
}

/// <p>A running row whose lock no process holds is lost, and so is a queued row past the queued limit;
/// a younger queued row is not, and neither is a running row whose job holds its lock, which the
/// owner's cancel then finds live, naming that job.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.State.SqlRun.Reconcile</method> end nothing --
/// the two lost legs go red.</p>
Method TestALostRunEndsFailedAndAHeldRunStaysLive()
{
    Do ..Reserve(..#USERA, 1000, .tLost)
    Do $$$AssertEquals(..Exec("UPDATE OcuPilot_Kernel_State.SqlRun SET State = 'running', JobId = '1' WHERE %EXACT(RunKey) = ?", tLost), 0, "a run reads running with no job holding it")
    Do $$$AssertEquals(..Seen(tLost, ..#USERA), "1 failed false", "the owner's view ends it failed, with no answer")
    Do ..Reserve(..#USERB, 1000, .tQueued)
    Do $$$AssertEquals(..Seen(tQueued, ..#USERB), "1 running false", "a young queued run stays live")
    Set tOld = ##class(OcuPilot.Kernel.State.Turn).IsoOfSeconds(##class(OcuPilot.Kernel.State.Turn).NowSeconds() - $Parameter(..#LIMITS, "QUEUEDSECONDS") - 5)
    Do $$$AssertEquals(..Exec("UPDATE OcuPilot_Kernel_State.SqlRun SET QueuedAt = ? WHERE %EXACT(RunKey) = ?", tOld, tQueued), 0, "until it is queued past the limit")
    Do $$$AssertEquals(..Seen(tQueued, ..#USERB), "1 failed false", "then it is lost")

    Do ..Reserve(..#USERC, 1000, .tHeld)
    Do $System.Event.Clear($Job)
    Job ##class(OcuPilot.Test.SqlRunStore).HoldRun($Job, tHeld, ..#USERC)::10
    Set tStarted = $Test
    Set tChild = $ZChild
    Do $$$AssertTrue(tStarted, "a child process starts")
    If 'tStarted Quit
    Set tMessage = $System.Event.WaitMsg("", 15)
    Do $$$AssertEquals($ListGet(tMessage, 2), "begun", "and begins the run, holding its lock")
    Do $$$AssertEquals(..Seen(tHeld, ..#USERC), "1 running false", "a held run stays live")
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedCancel", tHeld, ..#USERC, .tFound, .tJob, .tLive), "the owner's cancel answers")
    Do $$$AssertEquals(tFound _ " " _ tLive _ " " _ tJob, "1 1 " _ tChild, "live, naming the job that holds it")
    Do $System.Event.Signal(tChild, "finish")
    Set tMessage = $System.Event.WaitMsg("", 15)
    Do $$$AssertEquals($ListGet(tMessage, 2), "finished", "the child ends the run")
    Do $$$AssertEquals(..Seen(tHeld, ..#USERC), "1 canceled true", "canceled, as its owner asked")
}

/// <p>The child process <method>TestALostRunEndsFailedAndAHeldRunStaysLive</method> starts: begin
/// run <var>pKey</var> of <var>pUser</var>, signal <var>pParent</var>, wait for its word, then finish
/// the run and signal again.</p>
ClassMethod HoldRun(pParent As %Integer, pKey As %String, pUser As %String)
{
    Try {
        Do $System.Event.Clear($Job)
        Do ##class(OcuPilot.Kernel.State.SqlRun).GuardedBegin(pKey, pUser, .tBegun, .tCancel)
        Do $System.Event.Signal(pParent, $Select(tBegun: "begun", 1: "notbegun"))
        Do $System.Event.WaitMsg("", 20)
        Do ##class(OcuPilot.Kernel.State.SqlRun).GuardedFinish(pKey, "ended", "{""outcome"":""done""}")
        Do $System.Event.Signal(pParent, "finished")
    } Catch ex {
        Do $System.Event.Signal(pParent, "raised " _ ex.Name)
    }
}

/// <p>The sweep ends a lost run, keeps an ended run inside retention and deletes one past it, read
/// through its clock seam, which is never set ahead of the instance's clock, so no other owner's run
/// inside its retention is touched; the not-found sentence's minutes are the retention's.</p>
/// <p>Mutation (Rule 19): skip the delete in <method>OcuPilot.Kernel.State.SqlRun.GuardedSweep</method>
/// -- the swept leg goes red.</p>
Method TestTheSweepDeletesOnlyARunPastRetention()
{
    Do ..Reserve(..#USERB, 1000, .tLost)
    Do ..Exec("UPDATE OcuPilot_Kernel_State.SqlRun SET State = 'running' WHERE %EXACT(RunKey) = ?", tLost)
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedSweep", ..#LIMITS), "a sweep on the instance's clock runs")
    Set tRow = ##class(%SQL.Statement).%ExecDirect(, "SELECT State FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = ?", tLost)
    Do $$$AssertTrue(tRow.%Next() && (tRow.%GetData(1) = "failed"), "and ends the lost run")
    Do ..Reserve(..#USERA, 1000, .tKey)
    Do $ClassMethod(..#STORE, "GuardedFinish", tKey, "ended", "{""outcome"":""done""}")
    Set tNow = ##class(OcuPilot.Kernel.State.Turn).NowSeconds()
    Set tRetention = $Parameter(..#LIMITS, "RETENTIONSECONDS")
    Do $$$AssertTrue(##class(OcuPilot.Api.AtelierError).#REASONSQLBACKGROUNDNOTFOUND [ ((tRetention \ 60) _ " minutes"), "the not-found sentence names the retention, " _ (tRetention \ 60) _ " minutes")
    Set tEnded = ##class(OcuPilot.Kernel.State.Turn).IsoOfSeconds(tNow - tRetention - 60)
    Do $$$AssertEquals(..Exec("UPDATE OcuPilot_Kernel_State.SqlRun SET EndedAt = ? WHERE %EXACT(RunKey) = ?", tEnded, tKey), 0, "a run ended a minute past its retention")
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedSweep", ..#LIMITS, tNow - 120), "a sweep two minutes back, when it was inside retention, runs")
    Do $$$AssertEquals($Piece(..Seen(tKey, ..#USERA), " ", 1, 2), "1 ended", "and keeps the run")
    Do $$$AssertStatusOK($ClassMethod(..#STORE, "GuardedSweep", ..#LIMITS, tNow), "a sweep at the instance's clock runs")
    Do $$$AssertEquals(..Seen(tKey, ..#USERA), "0", "and deletes the run past retention")
}

}
