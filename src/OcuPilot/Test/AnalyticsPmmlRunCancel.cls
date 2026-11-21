/// <p>Pins Story 24.14's PMML test cancel at the moments a cancel can meet its supervisor (AD-7, AD-41, AD-42, AD-65), against <code>USER</code> and the definition of <class>OcuPilot.Test.PmmlProbe</class>: a cancel
/// sent before the supervisor has created its event, and one sent after it has created the event and before it waits, each ends the run <code>canceled</code> once the supervisor goes on; a second cancel of a
/// canceled run changes nothing; a run whose event can never be created still cancels; a poll reads a run <code>canceled</code> only after its result rows are gone, also when its child is slow to leave; and a run that is <code>ran</code>, <code>stopped</code>, <code>canceled</code> or <code>failed</code>
/// leaves no run record, no event resource and no held lock.</p>
/// <p><b>What it needs from the environment:</b> <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the probes turn analytics on for <code>USER</code> and write cubes and classes there. Every run a
/// test starts has ended, and every run row, result row, run record and event resource it made is removed, before the test returns.</p>
Class OcuPilot.Test.AnalyticsPmmlRunCancel Extends %UnitTest.TestCase [ DependsOn = (OcuPilot.Test.AnalyticsProbe, OcuPilot.Test.PmmlProbe, OcuPilot.Test.PmmlRunWatch, OcuPilot.Test.PmmlTestLate, OcuPilot.Test.PmmlTestStubborn, OcuPilot.Test.AnalyticsPmmlRunEdge) ]
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter PMML = "OcuPilot.Test.PmmlProbe";

Parameter WATCH = "OcuPilot.Test.PmmlRunWatch";

Parameter EDGE = "OcuPilot.Test.AnalyticsPmmlRunEdge";

Parameter STORE = "OcuPilot.Kernel.State.SqlRun";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter IDLE = "OcuPilot.Test.PmmlTestIdle";

Parameter HUNG = "OcuPilot.Test.PmmlTestHung";

Parameter LATE = "OcuPilot.Test.PmmlTestLate";

Parameter STUBBORN = "OcuPilot.Test.PmmlTestStubborn";

Parameter START = "/api/ocupilot/analytics/pmml/background";

Parameter POLL = "/api/ocupilot/analytics/pmml/background/:id";

Parameter CANCEL = "/api/ocupilot/analytics/pmml/background/:id/cancel";

Parameter NAMESPACE = "USER";

Parameter DEFINITION = {##class(OcuPilot.Test.PmmlProbe).#DEFINITIONCLASS};

Parameter SLOWSCAN = {##class(OcuPilot.Test.AnalyticsPmmlRunEdge).#SLOWSCAN};

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsPmmlRunCancel turns analytics on in USER and compiles classes there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh.")
    }
    Kill ^IRIS.Temp.OcuPilotPmmlLate, ^IRIS.Temp.OcuPilotPmmlIdle
    Set tSC = $ClassMethod(..#PMML, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Create", $Username)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PMML, "Create")
    If $$$ISERR(tSC) Set tSC = $$$ADDSC(tSC, ..OnAfterAllTests())
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit ..Settle()
}

Method OnAfterAllTests() As %Status
{
    Set tSC = ..Settle()
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PMML, "Remove"))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "Remove"))
    If $$$ISOK(tSC) && ('$ClassMethod(..#PMML, "Gone") || '$ClassMethod(..#PROBE, "Gone")) Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsPmmlRunCancel left probe state in USER: " _ $ClassMethod(..#PMML, "Left") _ " " _ $ClassMethod(..#PROBE, "Left"))
    Quit tSC
}

/// <p>Release every held supervisor, stop every live PMML run of the two accounts, wait up to 30 seconds for each to end, then remove every row of theirs and every node the tests set; an error when a run is
/// still live.</p>
Method Settle() As %Status
{
    Set ^IRIS.Temp.OcuPilotPmmlLate("go", "event") = 1
    Set ^IRIS.Temp.OcuPilotPmmlLate("go", "wait") = 1
    Set tOwners = $ListBuild(##class(OcuPilot.Test.Http).GetTestUsername(), $Username)
    Set tDeadline = $ZHorolog + 30
    For {
        Set tLive = 0
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT %EXACT(UserName), RunKey FROM OcuPilot_Kernel_State.SqlRun WHERE State IN ('queued', 'running') AND COALESCE(Kind, 'sql') = 'pmml'")
        While tResult.%Next() {
            If '$ListFind(tOwners, tResult.%GetData(1)) Continue
            Set tLive = tLive + 1
            Do ##class(OcuPilot.Area.Analytics.PmmlTest).Cancel(tResult.%GetData(2), tResult.%GetData(1), .tFound)
        }
        If (tLive = 0) || ($ZHorolog > tDeadline) Quit
        Hang 0.5
        Do $ClassMethod(..#STORE, "GuardedSweep", ..#LIMITS)
    }
    For tI = 1:1:$ListLength(tOwners) Do $ClassMethod(..#STORE, "GuardedForgetUser", $List(tOwners, tI))
    Do $ClassMethod(..#PMML, "DropRows")
    Kill ^IRIS.Temp.OcuPilotPmmlLate, ^IRIS.Temp.OcuPilotPmmlIdle
    If tLive Quit $$$ERROR($$$GeneralError, "a PMML run of this class was still live after 30 seconds")
    Quit $$$OK
}

/// <p>Send <var>pMethod</var> <var>pPath</var> (an absolute path, in <code>USER</code>) as the suite's account, with <var>pBody</var> when it is given; the status, the parsed answer.</p>
Method Send(pMethod As %String, pPath As %String, Output pStatus As %Integer, Output pAnswer, pBody = "")
{
    Set tText = $Select($IsObject(pBody): pBody.%ToJSON(), 1: pBody)
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, pPath _ $Select(pPath [ "?": "&", 1: "?") _ "ns=" _ ..#NAMESPACE, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tRaw, .tHeaders, tText, "application/json")
    Set pAnswer = ""
    Try {
        Set pAnswer = ##class(%DynamicObject).%FromJSON(tRaw)
    } Catch {
        Set pAnswer = $Get(tRaw)
    }
}

/// <p>Wait up to <var>pSeconds</var> for the node <var>pNode</var>, a global reference held as text, to exist; 1 when it does.</p>
ClassMethod AwaitNode(pNode As %String, pSeconds As %Numeric = 30) As %Boolean
{
    Set tDeadline = $ZHorolog + pSeconds
    While ('$Data(@pNode)) && ($ZHorolog < tDeadline) {
        Hang 0.05
    }
    Quit ''$Data(@pNode)
}

/// <p>The stored state, cancel flag, row version and end time of run <var>pKey</var>, as one line.</p>
ClassMethod Stored(pKey As %String) As %String
{
    Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT State, CancelRequested, RowVersion, EndedAt, JobId FROM OcuPilot_Kernel_State.SqlRun WHERE RunKey = ?", pKey)
    If 'tResult.%Next() Quit "absent"
    Quit tResult.%GetData(1) _ "|" _ tResult.%GetData(2) _ "|" _ tResult.%GetData(3) _ "|" _ tResult.%GetData(4) _ "|" _ tResult.%GetData(5)
}

/// <p>What run <var>pKey</var> leaves, as <method>OcuPilot.Test.PmmlRunWatch.Residue</method> reads it, then the run's record node, its event's node and its event resource, as
/// <code>record:&lt;data&gt; cancelNode:&lt;data&gt; resource:&lt;defined&gt;</code>; <code>CLEAN</code> and zeros are nothing.</p>
ClassMethod Left(pKey As %String, pTestId As %Integer, pChild As %String, pSup As %String) As %String
{
    Set tResidue = $ClassMethod(..#WATCH, "Residue", pKey, pTestId, pChild, pSup)
    Quit tResidue _ " record:" _ $Data(^IRIS.Temp.OcuPilotPmmlRun(pKey)) _ " cancelNode:" _ $Data(^IRIS.Temp.OcuPilotPmmlCancel(pKey)) _ " resource:" _ $ClassMethod(..#WATCH, "EventDefined", pKey)
}

/// <p>The value <method>Left</method> reads for a run that has left nothing.</p>
ClassMethod Clean() As %String
{
    Quit $Parameter(..#WATCH, "CLEAN") _ " record:0 cancelNode:0 resource:0"
}

/// <p>A cancel sent before the supervisor has created its event resource lands through the stop flag: the supervisor is held before it creates the event, the owner's cancel finds no event to signal and the run
/// still reads <code>running</code> with the flag set; once the supervisor goes on it reads the flag, spawns no child, and ends the run <code>canceled</code>, leaving nothing.</p>
/// <p>Mutation (Rule 19): drop the <code>StopRequested</code> branch from <method>OcuPilot.Area.Analytics.PmmlTest.Work</method> -- the run is not canceled and its child is started.</p>
Method TestACancelBeforeTheEventExistsLandsThroughTheFlag()
{
    Set ^IRIS.Temp.OcuPilotPmmlLate("hold", "event") = 1
    Set tSC = $ClassMethod(..#STORE, "GuardedReserve", $Username, ..#NAMESPACE, 1000, ..#LIMITS, .tKey, .tBusy, .tFull, .tSweep, "pmml")
    Do $$$AssertStatusOK(tSC, "a run is reserved")
    Do $$$AssertTrue($ClassMethod(..#LATE, "Spawn", tKey, $Username, ..#NAMESPACE, $ListBuild(..#DEFINITION _ "||Colors", "verification", "", ""), .tSpawned), "and its supervisor is spawned through the fixture")
    Do $$$AssertTrue(..AwaitNode("^IRIS.Temp.OcuPilotPmmlLate(""at"", ""event"")"), "the supervisor is held before it creates the event")
    Set tSup = $ClassMethod(..#WATCH, "JobOf", tKey)
    Do $$$AssertEquals($ClassMethod(..#WATCH, "EventDefined", tKey) _ $Data(^IRIS.Temp.OcuPilotPmmlIdle("entered")), "00", "there is no event resource to signal and no child")
    Set tSC = $ClassMethod(..#LATE, "Cancel", tKey, $Username, .tFound)
    Do $$$AssertTrue($$$ISOK(tSC) && tFound, "the cancel is accepted, and a signal that finds no event is not a fault")
    Do $$$AssertEquals($ClassMethod(..#EDGE, "ViewStatus", ..#LATE, tKey), "running", "the run still reads running: the flag is set and nothing has read it")
    Set ^IRIS.Temp.OcuPilotPmmlLate("go", "event") = 1
    Set tView = $ClassMethod(..#EDGE, "AwaitEnd", ..#LATE, tKey, 10)
    Do $$$AssertEquals($Select($IsObject(tView): tView.%Get("status"), 1: "absent"), "canceled", "once the supervisor goes on it reads the flag and ends the run canceled")
    Do $$$AssertEquals($Data(^IRIS.Temp.OcuPilotPmmlIdle("entered")), 0, "and no child was ever started")
    Do $$$AssertEquals(..Left(tKey, "", "", tSup), ..Clean(), "and nothing is left")
}

/// <p>A cancel sent after the supervisor has created its event and before it waits is kept: the signal is queued on the event, the supervisor's first wait returns at once, reads the flag, and ends the run
/// <code>canceled</code>, leaving nothing.</p>
/// <p>Mutation (Rule 19): clear the event's pending signals at the top of <method>OcuPilot.Area.Analytics.PmmlTest.Await</method> -- the run still reads running at ten seconds.</p>
Method TestACancelBeforeTheSupervisorWaitsIsKept()
{
    Set ^IRIS.Temp.OcuPilotPmmlLate("hold", "wait") = 1
    Do $$$AssertTrue($ClassMethod(..#EDGE, "StartIdle", ..#LATE, .tKey, .tSup, .tChild), "the idle child began its work: " _ $Get(tKey))
    Do $$$AssertTrue(..AwaitNode("^IRIS.Temp.OcuPilotPmmlLate(""at"", ""wait"")"), "the supervisor is held after it has created the event and spawned the child")
    Do $$$AssertEquals($ClassMethod(..#WATCH, "EventDefined", tKey), 1, "the event resource exists, with no one waiting on it")
    Set tSC = $ClassMethod(..#LATE, "Cancel", tKey, $Username, .tFound)
    Do $$$AssertTrue($$$ISOK(tSC) && tFound, "the cancel is accepted")
    Do $$$AssertEquals($ClassMethod(..#EDGE, "ViewStatus", ..#LATE, tKey), "running", "the run still reads running: no one has waited yet")
    Set ^IRIS.Temp.OcuPilotPmmlLate("go", "wait") = 1
    Set tView = $ClassMethod(..#EDGE, "AwaitEnd", ..#LATE, tKey, 10)
    Do $$$AssertEquals($Select($IsObject(tView): tView.%Get("status"), 1: "absent"), "canceled", "the queued signal ends the run canceled once the supervisor waits")
    Do $$$AssertEquals(..Left(tKey, "", tChild, tSup), ..Clean(), "and nothing is left")
}

/// <p>A second cancel of a canceled run answers as the run reads and changes nothing: the first cancel, over HTTP, answers <code>canceled</code> with nothing left; the second answers the same, and the stored
/// row (state, flag, row version, end time and job), the test-id counter and the run rows are as they were.</p>
/// <p>Mutation (Rule 19): drop the terminal and already-requested guard from <method>OcuPilot.Kernel.State.SqlRun.GuardedCancel</method> -- the row version moves.</p>
Method TestASecondCancelOfACanceledRunChangesNothing()
{
    Set tBefore = ..Counter()
    Do ..Send("POST", ..#START, .tStatus, .tAnswer, {"model": (..#DEFINITION _ "||Colors"), "source": "custom", "sql": (..#SLOWSCAN)})
    Do $$$AssertEquals(tStatus, 202, "the start is accepted")
    If tStatus '= 202 Quit
    Set tKey = tAnswer.%Get("id")
    Do $$$AssertTrue($ClassMethod(..#WATCH, "AwaitRows", tBefore + 1), "the child has written a result row")
    Set tSup = $ClassMethod(..#WATCH, "JobOf", tKey)
    Set tChild = $ClassMethod(..#WATCH, "ChildOf", tKey)
    Set tPath = $Replace(..#CANCEL, ":id", tKey)
    Do ..Send("POST", tPath, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("status") _ " " _ tAnswer.%Get("cancelRequested"), 1: ""), "200 canceled 1", "the first cancel answers canceled")
    Do $$$AssertEquals(..Left(tKey, tBefore + 1, tChild, tSup), ..Clean(), "and leaves nothing")
    Set tStored = ..Stored(tKey)
    Set tRuns = ..Footprint()
    Do $$$AssertEquals($Piece(tStored, "|", 1, 2), "canceled|1", "the row is canceled with the flag set: " _ tStored)
    Hang 0.2
    Do ..Send("POST", tPath, .tStatus, .tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("status") _ " " _ tAnswer.%Get("cancelRequested"), 1: ""), "200 canceled 1", "the second cancel answers canceled the same")
    Do ..Send("GET", $Replace(..#POLL, ":id", tKey), .tStatus, .tAnswer)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("status"), 1: ""), "canceled", "and a poll still reads canceled")
    Do $$$AssertEquals(..Stored(tKey) _ "|" _ ..Counter() _ "|" _ ..Footprint(), tStored _ "|" _ (tBefore + 1) _ "|" _ tRuns, "the stored row, the test-id counter and the run rows are unchanged")
    Do $$$AssertEquals(..Left(tKey, tBefore + 1, tChild, tSup), ..Clean(), "and nothing was left or started")
}

/// <p>The vendor's test-id counter.</p>
ClassMethod Counter() As %Integer
{
    Quit $ClassMethod(..#EDGE, "Counter")
}

/// <p>How many PMML run rows exist, as <method>OcuPilot.Test.AnalyticsPmmlRunEdge.Footprint</method> reads them.</p>
ClassMethod Footprint() As %String
{
    Quit $ClassMethod(..#EDGE, "Footprint")
}

/// <p>A run reads <code>canceled</code> only after its result rows are gone: the port's drop is held for 0.6 seconds (<class>OcuPilot.Test.PmmlPortSlowDrop</class>) over a record naming the idle child and four
/// rows seeded under a test id. While the drop is held the stored state is still <code>running</code> and all four rows are there; once the cancel returns the run reads <code>canceled</code> and no row is left.</p>
/// <p>Mutation (Rule 19): end the run <code>canceled</code> in <method>OcuPilot.Area.Analytics.PmmlTest.Work</method> before the call to <method>OcuPilot.Area.Analytics.PmmlTest.Reap</method> -- the state read
/// during the drop is <code>canceled</code>.</p>
Method TestACanceledRunReadsCanceledOnlyAfterItsRowsAreDropped()
{
    Set tSeeded = $ClassMethod(..#PMML, "Seed")
    Do $$$AssertTrue((tSeeded '= "") && ($ClassMethod(..#PMML, "RowsOf", tSeeded) = 4), "four rows are seeded under a test id: " _ tSeeded)
    Set ^IRIS.Temp.OcuPilotPmmlLate("slowDrop") = 1
    Do $$$AssertTrue($ClassMethod(..#EDGE, "StartIdle", ..#LATE, .tKey, .tSup, .tChild), "the idle child began its work: " _ $Get(tKey))
    Set ^IRIS.Temp.OcuPilotPmmlLate("key") = tKey
    Set ^IRIS.Temp.OcuPilotPmmlRun(tKey) = $ListBuild(tChild, tSeeded)
    Set tSC = $ClassMethod(..#LATE, "Cancel", tKey, $Username, .tFound)
    Do $$$AssertTrue($$$ISOK(tSC) && tFound, "the cancel is accepted")
    Do $$$AssertEquals($Get(^IRIS.Temp.OcuPilotPmmlLate("seen")), "running/4|running/4", "while the drop was held the run read running and every row was there")
    Do $$$AssertEquals($ClassMethod(..#EDGE, "ViewStatus", ..#LATE, tKey) _ "/" _ $ClassMethod(..#PMML, "RowsOf", tSeeded), "canceled/0", "once the run reads canceled no row is left")
    Do $$$AssertEquals(..Left(tKey, tSeeded, tChild, tSup), ..Clean(), "and nothing else is")
}

/// <p>Each way a run can end leaves no run record, no event resource, no event node and no held lock, once its supervisor has exited: a run that ends on its own over HTTP (<code>ran</code>), a hung child ended at
/// the bound plus the grace (<code>stopped</code>), a canceled run, and a child ended from outside (<code>failed</code>).</p>
/// <p>Mutation (Rule 19): skip the event's delete in <method>OcuPilot.Area.Analytics.PmmlTest.Work</method> for a child that has exited -- the <code>ran</code> and <code>failed</code> legs go red on the resource.</p>
Method TestEveryEndingLeavesNoRecordNodeOrResource()
{
    Set tBefore = ..Counter()
    Do ..Send("POST", ..#START, .tStatus, .tAnswer, {"model": (..#DEFINITION _ "||Colors"), "source": "verification"})
    Do $$$AssertEquals(tStatus, 202, "ran: the start is accepted")
    If tStatus = 202 {
        Set tKey = tAnswer.%Get("id")
        Set tDeadline = $ZHorolog + 30
        For {
            Do ..Send("GET", $Replace(..#POLL, ":id", tKey), .tStatus, .tAnswer)
            If '$IsObject(tAnswer) || (tAnswer.%Get("status") '= "running") || ($ZHorolog > tDeadline) Quit
            Hang 0.1
        }
        Do $$$AssertEquals($Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("result")): tAnswer.%Get("status") _ " " _ tAnswer.result.outcome, 1: "absent"), "ended ran", "ran: the run ends on its own")
        Do $$$AssertEquals(..Left(tKey, tBefore + 1, "", $ClassMethod(..#WATCH, "JobOf", tKey)), ..Clean(), "ran: nothing is left")
    }
    Do $$$AssertTrue($ClassMethod(..#EDGE, "StartIdle", ..#HUNG, .tKey, .tSup, .tChild), "stopped: the hung child began its work")
    Set tView = $ClassMethod(..#EDGE, "AwaitEnd", ..#HUNG, tKey, 15)
    Do $$$AssertEquals($Select($IsObject(tView) && $IsObject(tView.%Get("result")): tView.%Get("status") _ " " _ tView.result.outcome, 1: "absent"), "ended stopped", "stopped: the run ends at the bound plus the grace")
    Do $$$AssertEquals(..Left(tKey, "", tChild, tSup), ..Clean(), "stopped: nothing is left")
    Do $$$AssertTrue($ClassMethod(..#EDGE, "StartIdle", ..#IDLE, .tKey, .tSup, .tChild), "canceled: the idle child began its work")
    Set tSC = $ClassMethod(..#IDLE, "Cancel", tKey, $Username, .tFound)
    Do $$$AssertEquals($ClassMethod(..#EDGE, "ViewStatus", ..#IDLE, tKey), "canceled", "canceled: the run reads canceled")
    Do $$$AssertEquals(..Left(tKey, "", tChild, tSup), ..Clean(), "canceled: nothing is left")
    Do $$$AssertTrue($ClassMethod(..#EDGE, "StartIdle", ..#IDLE, .tKey, .tSup, .tChild), "failed: the idle child began its work")
    Do $$$AssertEquals($SYSTEM.Process.Terminate(tChild), 1, "failed: the child is ended from outside")
    Set tView = $ClassMethod(..#EDGE, "AwaitEnd", ..#IDLE, tKey, 10)
    Do $$$AssertEquals($Select($IsObject(tView): tView.%Get("status"), 1: "absent"), "failed", "failed: the run reads failed")
    Do $$$AssertEquals(..Left(tKey, "", tChild, tSup), ..Clean(), "failed: nothing is left")
}

/// <p>A run whose event resource can never be created, as when another process deletes it each time, still runs and still cancels: the supervisor spawns its child, keeps waiting, and ends the run
/// <code>canceled</code> on the owner's cancel within two seconds, leaving nothing.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Analytics.PmmlTest.Await</method> end the wait <code>failed</code> when a deleted event cannot be created again -- the run reads <code>failed</code>.</p>
Method TestARunWhoseEventCannotBeCreatedStillCancels()
{
    Set ^IRIS.Temp.OcuPilotPmmlLate("noEvent") = 1
    Do $$$AssertTrue($ClassMethod(..#EDGE, "StartIdle", ..#LATE, .tKey, .tSup, .tChild), "the idle child began its work without an event: " _ $Get(tKey))
    Hang 1
    Do $$$AssertEquals($ClassMethod(..#EDGE, "ViewStatus", ..#LATE, tKey) _ " " _ $ClassMethod(..#WATCH, "EventDefined", tKey), "running 0", "a second later the run still runs, with no event resource")
    Set tStart = $ZHorolog
    Set tSC = $ClassMethod(..#LATE, "Cancel", tKey, $Username, .tFound)
    Do $$$AssertTrue($$$ISOK(tSC) && tFound, "the cancel is accepted")
    Do $$$AssertEquals($ClassMethod(..#EDGE, "ViewStatus", ..#LATE, tKey), "canceled", "the run reads canceled within " _ ($ZHorolog - tStart) _ " seconds")
    Do $$$AssertEquals(..Left(tKey, "", tChild, tSup), ..Clean(), "and nothing is left")
    Kill ^IRIS.Temp.OcuPilotPmmlLate("noEvent")
}

/// <p>A canceled run whose child outlives the supervisor's first wait for it (<class>OcuPilot.Test.PmmlTestStubborn</class>, whose end of the child does nothing) still reads <code>canceled</code> only after its
/// rows are dropped: when the cancel returns, after its two-second wait, the run reads <code>running</code> with the four rows the record names; once the supervisor's second wait has passed, the rows and the
/// record are gone and the run reads <code>canceled</code>. The test then releases the child, and nothing is left.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Analytics.PmmlTest.Reap</method> answer at once, dropping nothing, for a child still there after <parameter>OcuPilot.Area.Analytics.PmmlTest.CHILDSECONDS</parameter>
/// -- the run reads <code>canceled</code> with its four rows when the cancel returns.</p>
Method TestACanceledRunWhoseChildIsSlowToLeaveReadsCanceledOnlyAfterTheDrop()
{
    Set tSeeded = $ClassMethod(..#PMML, "Seed")
    Do $$$AssertTrue((tSeeded '= "") && ($ClassMethod(..#PMML, "RowsOf", tSeeded) = 4), "four rows are seeded under a test id: " _ tSeeded)
    Do $$$AssertTrue($ClassMethod(..#EDGE, "StartIdle", ..#STUBBORN, .tKey, .tSup, .tChild), "the idle child began its work: " _ $Get(tKey) _ " child " _ $Get(tChild))
    Set ^IRIS.Temp.OcuPilotPmmlRun(tKey) = $ListBuild(tChild, tSeeded)
    Set tSC = $ClassMethod(..#STUBBORN, "Cancel", tKey, $Username, .tFound)
    Do $$$AssertTrue($$$ISOK(tSC) && tFound, "the cancel is accepted")
    Do $$$AssertEquals($Piece(..Stored(tKey), "|") _ "/" _ $ClassMethod(..#PMML, "RowsOf", tSeeded) _ "/" _ $ClassMethod(..#WATCH, "Alive", tChild), "running/4/1", "when the cancel returns the child is still there, and the run reads running with every row")
    Set tView = $ClassMethod(..#EDGE, "AwaitEnd", ..#STUBBORN, tKey, 15)
    Do $$$AssertEquals($Select($IsObject(tView): tView.%Get("status"), 1: "absent") _ "/" _ $ClassMethod(..#PMML, "RowsOf", tSeeded) _ "/" _ $Data(^IRIS.Temp.OcuPilotPmmlRun(tKey)), "canceled/0/0", "once the supervisor stops waiting, it drops the rows and removes the record before the run reads canceled")
    Set ^IRIS.Temp.OcuPilotPmmlIdle("release") = 1
    Do $$$AssertTrue($ClassMethod(..#WATCH, "WaitGone", tChild, 10), "the released child ends")
    Do $$$AssertEquals(..Left(tKey, tSeeded, tChild, tSup), ..Clean(), "and nothing is left")
    Kill ^IRIS.Temp.OcuPilotPmmlIdle
    Do $ClassMethod(..#PMML, "DropRows")
}

}
