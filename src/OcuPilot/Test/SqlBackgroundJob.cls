/// <p>Pins the background run's job (Story 19.15, AD-7, AD-9, AD-42, AD-61): a run reserved and spawned
/// in a process signed in as a purpose-built principal runs as that principal, reading its granted
/// table and refused SQLCODE -99 on its ungranted one, also while a <code>%All</code> account holds
/// that text prepared, read back over the wire as the principal; a job of another process refuses to
/// run; the job repeats the screen's gate; a query past the bound is stopped; the owner's cancel stops
/// the query within three seconds, also when it is sent before the job runs its statement; a job that
/// dies reads lost; a start whose job is not accepted answers lost and leaves no live run; the instance
/// cap refuses another owner's start; and the job's failure line carries nothing of the statement.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP, and a
/// <code>USER</code> namespace. It creates and removes <class>OcuPilot.Test.SqlBackgroundProbe</class>'s
/// objects, data included, and its principals, so it runs on a throwaway only:
/// <method>OnBeforeAllTests</method> refuses unless
/// <parameter>OcuPilot.Test.SqlConsoleProbe.ARMINGVARIABLE</parameter> reads <code>1</code>. Every job a
/// test starts has ended, and every run row it made is removed, before the test returns.</p>
Class OcuPilot.Test.SqlBackgroundJob Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.SqlBackgroundProbe";

Parameter FIXTURE = "OcuPilot.Test.SqlBackgroundFixture";

Parameter UNINDEXED = "OcuPilot.Test.SqlBackgroundUnindexed";

Parameter DELAYED = "OcuPilot.Test.SqlBackgroundDelayed";

Parameter UNSPAWNED = "OcuPilot.Test.SqlBackgroundUnspawned";

Parameter PRODUCTION = "OcuPilot.Area.Explorer.SqlBackground";

Parameter STORE = "OcuPilot.Kernel.State.SqlRun";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter POLL = "/api/ocupilot/explorer/sql/background/";

/// <p>A query over the granted table that runs for minutes, so only a cancel, the alarm or a killed job
/// ends it: a six-way cross join's count.</p>
Parameter LONGERQUERY = "SELECT COUNT(*) AS N FROM OcuProbe1915.Granted a, OcuProbe1915.Granted b, OcuProbe1915.Granted c, OcuProbe1915.Granted d, OcuProbe1915.Granted e, OcuProbe1915.Granted f";

/// <p>The principals' password for this run.</p>
Property PreparedPassword As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If '$ClassMethod(..#PROBE, "Armed") {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlBackgroundJob creates IRIS users and roles and runs on a throwaway container only. " _ $Parameter(..#PROBE, "ARMINGVARIABLE") _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuProbe1915" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "Make")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "EnsurePrincipals", ..PreparedPassword)
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
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemovePrincipals"))
}

/// <p>The owners this class's runs belong to: its three principals and the suite's own account.</p>
Method Owners() As %List
{
    Quit $ListBuild($Parameter(..#PROBE, "USER"), $Parameter(..#PROBE, "NODEVUSER"), $Parameter(..#PROBE, "NOUSERUSER"), $Username)
}

/// <p>Stop every live run of this class's owners -- its job's query canceled, as the suite's account
/// may -- wait up to 20 seconds for each to end, then remove every row of theirs; an error when a run
/// is still live.</p>
Method Settle() As %Status
{
    Set tOwners = ..Owners()
    Set tDeadline = $ZHorolog + 20
    For {
        Set tLive = 0
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT %EXACT(UserName), JobId, State FROM OcuPilot_Kernel_State.SqlRun WHERE State IN ('queued', 'running')")
        While tResult.%Next() {
            If '$ListFind(tOwners, tResult.%GetData(1)) Continue
            Set tLive = tLive + 1
            If (tResult.%GetData(3) = "running") && (tResult.%GetData(2) '= "") Do $SYSTEM.SQL.CancelQuery(tResult.%GetData(2), , 1)
        }
        If (tLive = 0) || ($ZHorolog > tDeadline) Quit
        Hang 0.5
        ; A reserve reconciles a run whose job is gone, which the poll below would also do.
        Do $ClassMethod(..#STORE, "GuardedSweep", ..#LIMITS)
    }
    For tI = 1:1:$ListLength(tOwners) {
        Do $ClassMethod(..#STORE, "GuardedForgetUser", $List(tOwners, tI))
    }
    If tLive Quit $$$ERROR($$$GeneralError, "a background run of this class was still live after 20 seconds")
    Quit $$$OK
}

/// <p>Start <var>pText</var> with <var>pValues</var> (a <class>%DynamicArray</class>) as
/// <var>pUser</var>, through <var>pClass</var>'s <code>Start</code> in a child process signed in as
/// that user, and answer what the child signalled: <code>{key, http, code, detail}</code>, or
/// <code>{error}</code>.</p>
ClassMethod StartAs(pUser As %String, pClass As %String, pText As %String, pValues As %DynamicArray = "", pMaxRows As %Integer = 10) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Set tValues = $Select($IsObject(pValues): pValues, 1: [])
        Job ##class(OcuPilot.Test.SqlBackgroundJob).StartChild($Job, pUser, pClass, pText, tValues.%ToJSON(), pMaxRows)::10
        If '$Test {
            Do tOut.%Set("error", "the child did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 30)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the child signalled nothing within 30 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>The child process <method>StartAs</method> starts: sign in as <var>pUser</var>, call
/// <var>pClass</var>'s <code>Start</code> in USER, and signal <var>pParent</var> what it answered.</p>
ClassMethod StartChild(pParent As %Integer, pUser As %String, pClass As %String, pText As %String, pValuesJson As %String, pMaxRows As %Integer)
{
    Set tOut = {}
    Try {
        Do tOut.%Set("loggedIn", ''$SYSTEM.Security.Login(pUser), "boolean")
        Do tOut.%Set("username", $Username, "string")
        Set tSC = $ClassMethod(pClass, "Start", "USER", pText, ##class(%DynamicArray).%FromJSON(pValuesJson), pMaxRows, .tKey, .tHttp, .tFault)
        Do tOut.%Set("key", $Get(tKey), "string")
        Do tOut.%Set("http", $Select($$$ISOK(tSC): 202, 1: +$Get(tHttp)), "number")
        Do tOut.%Set("code", $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "string")
        If $IsObject($Get(tFault)) && (tFault.%GetTypeOf("detail") = "object") Do tOut.%Set("detail", tFault.%Get("detail"))
    } Catch ex {
        Do tOut.%Set("error", ex.DisplayString())
    }
    Do $System.Event.Signal(pParent, tOut.%ToJSON())
}

/// <p>GET run <var>pKey</var> as <var>pUser</var> over the wire, answering the status, the parsed body
/// and the response's content type.</p>
Method Poll(pUser As %String, pKey As %String, Output pStatus As %Integer, Output pBody, Output pType As %String)
{
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", ..#POLL _ pKey _ "?ns=USER", pUser, ..PreparedPassword, .pStatus, .tText, .tHeaders)
    Set pType = $Piece($Get(tHeaders("CONTENT-TYPE")), ";", 1)
    Set pBody = ""
    Try {
        Set pBody = ##class(%DynamicObject).%FromJSON(tText)
    } Catch {
        Set pBody = $Get(tText)
    }
}

/// <p>Poll run <var>pKey</var> as the principal <var>pUser</var> over the wire every quarter second
/// until it no longer reads running, or for <var>pSeconds</var>; the last answer's body.</p>
Method AwaitOverTheWire(pUser As %String, pKey As %String, pSeconds As %Numeric = 20) As %DynamicObject
{
    Set tDeadline = $ZHorolog + pSeconds
    Set tBody = ""
    For {
        Do ..Poll(pUser, pKey, .tStatus, .tBody, .tType)
        If '$IsObject(tBody) || (tBody.%Get("status") '= "running") || ($ZHorolog > tDeadline) Quit
        Hang 0.25
    }
    Quit tBody
}

/// <p>Run <var>pKey</var> as <var>pUser</var> reads it through <class>OcuPilot.Area.Explorer.SqlBackground</class>'s
/// view, in this process, every quarter second until it no longer reads running, or for
/// <var>pSeconds</var>.</p>
ClassMethod AwaitInProcess(pUser As %String, pKey As %String, pSeconds As %Numeric = 20) As %DynamicObject
{
    Set tDeadline = $ZHorolog + pSeconds
    Set tView = ""
    For {
        Do ##class(OcuPilot.Area.Explorer.SqlBackground).View(pKey, pUser, .tFound, .tView)
        If '$Get(tFound) || (tView.%Get("status") '= "running") || ($ZHorolog > tDeadline) Quit
        Hang 0.25
    }
    Quit tView
}

/// <p>A run's answer as one line: its status, then its result or refusal as JSON.</p>
ClassMethod Said(pView) As %String
{
    If '$IsObject($Get(pView)) Quit "absent " _ $Get(pView)
    Set tLine = pView.%Get("status")
    If pView.%GetTypeOf("result") = "object" Set tLine = tLine _ " " _ pView.result.%ToJSON()
    If pView.%GetTypeOf("refusal") = "object" Set tLine = tLine _ " " _ pView.refusal.%ToJSON()
    Quit tLine
}

/// <p>AC3: a run reserved and spawned in a process signed in as the least-privileged principal runs as
/// that principal: its granted table answers rows, and its ungranted one ends with SQLCODE -99 and no
/// row, alone and while the suite's <code>%All</code> account holds that text prepared; each is read
/// back over the wire as the principal.</p>
Method TestThePrincipalsJobRunsAsThePrincipal()
{
    Set tUser = $Parameter(..#PROBE, "USER")
    Set tStart = ..StartAs(tUser, ..#FIXTURE, "SELECT Name FROM OcuProbe1915.Granted WHERE Num = 1")
    Do $$$AssertEquals(tStart.%Get("http") _ " " _ tStart.%Get("username"), "202 " _ tUser, "the principal's run is started in its own process: " _ tStart.%ToJSON())
    Set tView = ..AwaitOverTheWire(tUser, tStart.%Get("key"))
    Do $$$AssertEquals(..Said(tView), "ended {""kind"":""query"",""outcome"":""rows"",""columns"":[""Name""],""rows"":[[""n1""]],""truncated"":false}", "its granted table answers its row")
    Set tHidden = "SELECT Name FROM OcuProbe1915.Hidden"
    For tCase = "alone", "held" {
        If tCase = "held" {
            Set tHeld = $ClassMethod(..#PROBE, "Hold", $ListBuild(tHidden), .tStatements)
            Do $$$AssertEquals(tHeld, 1, "the suite's %All account holds the ungranted text prepared")
        }
        Set tStart = ..StartAs(tUser, ..#FIXTURE, tHidden)
        Set tView = ..AwaitOverTheWire(tUser, tStart.%Get("key"))
        Do $$$AssertEquals($Select($IsObject(tView) && (tView.%GetTypeOf("result") = "object"): tView.status _ " " _ tView.result.outcome _ " " _ tView.result.sqlcode _ " " _ tView.result.%IsDefined("rows"), 1: ..Said(tView)), "ended error -99 0", tCase _ ": the ungranted table ends with SQLCODE -99 and no row")
        If tCase = "held" Do $ClassMethod(..#PROBE, "Release", .tStatements)
    }
}

/// <p>AC3: a job spawned by a process of another user than the run's owner refuses to run, ending the
/// run failed with no answer.</p>
/// <p>Mutation (Rule 19): drop the <code>$Username</code> check from
/// <method>OcuPilot.Area.Explorer.SqlBackground.Run</method> -- the run executes and this goes red.</p>
Method TestAJobOfAnotherUsersProcessRefusesToRun()
{
    Set tOwner = $Parameter(..#PROBE, "USER")
    Do $$$AssertNotEquals($Username, tOwner, "this process runs as another user than the run's owner")
    Set tSC = $ClassMethod(..#STORE, "GuardedReserve", tOwner, "USER", 1000, ..#LIMITS, .tKey, .tBusy, .tFull, .tSweep)
    Do $$$AssertStatusOK(tSC, "a run of the principal is reserved")
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "Spawn", tKey, tOwner, "USER", $ListBuild("SELECT Name FROM OcuProbe1915.Granted", "", 5), .tChild), "and its job is spawned by this process")
    Set tView = ..AwaitInProcess(tOwner, tKey)
    Do $$$AssertEquals(..Said(tView), "failed {""code"":""EXPLORER.SQL.BACKGROUND.LOST"",""reason"":""" _ ##class(OcuPilot.Api.AtelierError).#REASONSQLBACKGROUNDLOST _ """}", "the job refuses to run: failed, with no answer of its own")
}

/// <p>The job checks its caller in its own process: a run of a principal holding no
/// <code>%Development:USE</code>, reserved and spawned past the start route, ends failed with
/// <code>AUTH.NOPRIVILEGE</code> naming that pair, and nothing runs.</p>
Method TestTheJobRefusesACallerWithoutTheScreensPair()
{
    Set tUser = $Parameter(..#PROBE, "NODEVUSER")
    Set tStart = ..StartAs(tUser, ..#FIXTURE, "SELECT Name FROM OcuProbe1915.Granted WHERE Num = 1")
    Do $$$AssertEquals(tStart.%Get("http"), 202, "the run is started past the route: " _ tStart.%ToJSON())
    Set tView = ..AwaitInProcess(tUser, tStart.%Get("key"))
    Do $$$AssertEquals(..Said(tView), "failed {""code"":""AUTH.NOPRIVILEGE"",""reason"":""" _ ##class(OcuPilot.Kernel.Denial).Reason() _ """,""detail"":{""failedPair"":""%Development:USE""}}", "the job's own gate refuses it, naming the pair")
}

/// <p>AC4: a query past the bound ends with the outcome <code>stopped</code> and the bound's seconds.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.SqlPort.Bounded</method> answer 0 for a query --
/// the count runs to its end and this goes red.</p>
Method TestAQueryPastTheBoundIsStopped()
{
    Set tUser = $Parameter(..#PROBE, "USER")
    Set tStart = ..StartAs(tUser, ..#FIXTURE, $Parameter(..#PROBE, "LONGQUERY"))
    Set tView = ..AwaitOverTheWire(tUser, tStart.%Get("key"), 30)
    Do $$$AssertEquals(..Said(tView), "ended {""outcome"":""stopped"",""kind"":""query"",""seconds"":" _ $Parameter("OcuPilot.Test.SqlPortFixture", "PROBESECONDS") _ "}", "the run ends stopped at the fixture's bound")
}

/// <p>AC5: the owner's cancel stops a running query and the run reads canceled within three seconds;
/// a cancel of the ended run answers it unchanged.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Explorer.SqlBackground.Cancel</method> set the
/// flag without <code>$SYSTEM.SQL.CancelQuery</code> -- the query runs on and this goes red.</p>
Method TestTheOwnersCancelStopsTheQuery()
{
    Set tUser = $Parameter(..#PROBE, "USER")
    Set tStart = ..StartAs(tUser, ..#PRODUCTION, ..#LONGERQUERY)
    Set tKey = tStart.%Get("key")
    Set tDeadline = $ZHorolog + 10
    For {
        Do ..Poll(tUser, tKey, .tStatus, .tBody, .tType)
        If ($IsObject(tBody) && (tBody.%Get("startedAt") '= "")) || ($ZHorolog > tDeadline) Quit
        Hang 0.1
    }
    Do $$$AssertTrue($IsObject(tBody) && (tBody.%Get("status") = "running") && (tBody.%Get("startedAt") '= ""), "the run has begun: " _ ..Said(tBody))
    Hang 0.5
    Set tAsked = $ZHorolog
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#POLL _ tKey _ "/cancel?ns=USER", tUser, ..PreparedPassword, .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the owner's cancel answers 200")
    Set tView = ..AwaitOverTheWire(tUser, tKey, 10)
    Set tTook = $ZHorolog - tAsked
    Do $$$AssertEquals(..Said(tView), "canceled", "the run reads canceled, with no answer")
    Do $$$AssertTrue(tTook < 3, "within three seconds of the cancel: " _ $FNumber(tTook, "", 2) _ " s")
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#POLL _ tKey _ "/cancel?ns=USER", tUser, ..PreparedPassword, .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ tText, "200 " _ tView.%ToJSON(), "a cancel of the ended run answers it unchanged")
}

/// <p>AC5: a cancel sent as soon as the run has begun, while its job runs no statement yet, is sent
/// again until the query runs, and the run reads canceled within three seconds.</p>
/// <p>Mutation (Rule 19): set <parameter>OcuPilot.Area.Explorer.SqlBackground.CANCELTRIES</parameter>
/// to 1 -- the one cancel finds no query, the count runs on and this goes red.</p>
Method TestAnEarlyCancelIsSentAgainUntilTheQueryRuns()
{
    Set tUser = $Parameter(..#PROBE, "USER")
    Set tStart = ..StartAs(tUser, ..#DELAYED, ..#LONGERQUERY)
    Set tKey = tStart.%Get("key")
    Set tDeadline = $ZHorolog + 10
    For {
        Do ..Poll(tUser, tKey, .tStatus, .tBody, .tType)
        If ($IsObject(tBody) && (tBody.%Get("startedAt") '= "")) || ($ZHorolog > tDeadline) Quit
        Hang 0.05
    }
    Set tAsked = $ZHorolog
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#POLL _ tKey _ "/cancel?ns=USER", tUser, ..PreparedPassword, .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the owner's cancel answers 200")
    Set tView = ..AwaitOverTheWire(tUser, tKey, 10)
    Set tTook = $ZHorolog - tAsked
    Do $$$AssertEquals(..Said(tView), "canceled", "the run reads canceled, with no answer")
    Do $$$AssertTrue(tTook < 3, "within three seconds of the cancel: " _ $FNumber(tTook, "", 2) _ " s")
}

/// <p>A start whose job is not accepted answers 503 <code>EXPLORER.SQL.BACKGROUND.LOST</code>, its run
/// reads failed with that refusal, and the owner's next start is not refused busy.</p>
/// <p>Mutation (Rule 19): drop the <method>OcuPilot.Kernel.State.SqlRun.GuardedFinish</method> call from
/// <method>OcuPilot.Area.Explorer.SqlBackground.Start</method>'s refused spawn -- the run stays queued,
/// the next start is refused busy and this goes red.</p>
Method TestAStartWhoseJobIsNotAcceptedAnswersLost()
{
    Set tSC = $ClassMethod(..#UNSPAWNED, "Start", "USER", "SELECT 1 AS One", [], 10, .tKey, .tHttp, .tFault)
    Do $$$AssertEquals($$$ISERR(tSC) _ " " _ $Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "") _ " " _ $Get(tKey), "1 503 EXPLORER.SQL.BACKGROUND.LOST ", "the start answers lost, with no run id")
    Set tRows = ##class(%SQL.Statement).%ExecDirect(, "SELECT RunKey, State FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(UserName) = ?", $Username)
    Set tRunKey = $Select(tRows.%Next(): tRows.%GetData(1), 1: "")
    Do ##class(OcuPilot.Area.Explorer.SqlBackground).View(tRunKey, $Username, .tFound, .tView)
    Do $$$AssertEquals($Select($Get(tFound) && $IsObject(tView) && (tView.%GetTypeOf("refusal") = "object"): tView.status _ " " _ tView.refusal.code, 1: ..Said($Get(tView))), "failed EXPLORER.SQL.BACKGROUND.LOST", "its run reads failed, lost")
    Set tSC = $ClassMethod(..#FIXTURE, "Start", "USER", "SELECT 1 AS One", [], 10, .tNext, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the owner's next start is not refused busy: " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""))
    Set tView = ..AwaitInProcess($Username, $Get(tNext))
    Do $$$AssertEquals($Select($IsObject(tView): tView.status, 1: ""), "ended", "and its run ends")
}

/// <p>AC8: a run whose job dies reads failed with <code>EXPLORER.SQL.BACKGROUND.LOST</code> at the
/// next poll.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.State.SqlRun.Reconcile</method> end nothing --
/// the run reads running and this goes red.</p>
Method TestARunWhoseJobDiedReadsLost()
{
    Set tUser = $Parameter(..#PROBE, "USER")
    Set tStart = ..StartAs(tUser, ..#PRODUCTION, ..#LONGERQUERY)
    Set tKey = tStart.%Get("key")
    Set tJob = ""
    Set tDeadline = $ZHorolog + 10
    For {
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT JobId FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = ? AND State = 'running'", tKey)
        If tResult.%Next() Set tJob = tResult.%GetData(1)
        If (tJob '= "") || ($ZHorolog > tDeadline) Quit
        Hang 0.1
    }
    Do $$$AssertNotEquals(tJob, "", "the run's job has begun")
    If tJob = "" Quit
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tProcess = ##class(SYS.Process).%OpenId(tJob)
        Set tSC = $Select($IsObject(tProcess): tProcess.Terminate(), 1: $$$ERROR($$$GeneralError, "no process " _ tJob))
        Set tProcess = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Do $$$AssertStatusOK(tSC, "the job is ended from outside")
    Hang 1
    Do ..Poll(tUser, tKey, .tStatus, .tBody, .tType)
    Do $$$AssertEquals(tStatus _ " " _ ..Said(tBody), "200 failed {""code"":""EXPLORER.SQL.BACKGROUND.LOST"",""reason"":""" _ ##class(OcuPilot.Api.AtelierError).#REASONSQLBACKGROUNDLOST _ """}", "the next poll reads it lost")
}

/// <p>AC7: the production cap is five; at the instance cap (the fixture's one run), another owner's
/// start is refused 503 <code>EXPLORER.SQL.BACKGROUND.FULL</code> and reserves and spawns nothing.</p>
/// <p>Mutation (Rule 19): skip the instance count in
/// <method>OcuPilot.Kernel.State.SqlRun.GuardedReserve</method> -- the second start is answered and
/// this goes red.</p>
Method TestTheInstanceCapRefusesAnotherOwnersStart()
{
    Do $$$AssertEquals(##class(OcuPilot.Area.Explorer.SqlBackground).MaxRunning(), 5, "the production instance cap is AD-41's five")
    Set tForeign = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.SqlRun WHERE State IN ('queued', 'running')")
    Do $$$AssertTrue(tForeign.%Next() && (tForeign.%GetData(1) = 0), "no run is live on this instance before the cap is filled")
    Set tSC = $ClassMethod(..#FIXTURE, "Start", "USER", $Parameter(..#PROBE, "LONGQUERY"), [], 10, .tKey, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "this account's run fills the fixture's cap of one")
    Set tUser = $Parameter(..#PROBE, "USER")
    Set tStart = ..StartAs(tUser, ..#FIXTURE, "SELECT Name FROM OcuProbe1915.Granted WHERE Num = 1")
    Do $$$AssertEquals(tStart.%Get("http") _ " " _ tStart.%Get("code") _ " " _ tStart.%Get("key"), "503 EXPLORER.SQL.BACKGROUND.FULL ", "another owner's start is refused at the cap")
    Set tRows = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(UserName) = ?", tUser)
    Do $$$AssertTrue(tRows.%Next() && (tRows.%GetData(1) = 0), "and reserves nothing")
    Set tView = ..AwaitInProcess($Username, tKey, 20)
    Do $$$AssertEquals($Select($IsObject(tView): tView.status, 1: ""), "ended", "this account's run ends by itself")
}

/// <p>AC9: the job's own failure line names its failure and carries nothing of the statement.</p>
/// <p>Mutation (Rule 19): hand the statement, as the status to log, from
/// <method>OcuPilot.Area.Explorer.SqlBackground.Run</method> to <code>FinishRefused</code> -- the log
/// leg goes red.</p>
Method TestTheJobsFailureLineCarriesNoStatement()
{
    Set tMark = "OcuProbe1915Log" _ $Translate($ZTimeStamp, ",.", "")
    Set tLog = ##class(%File).NormalizeFilename(##class(OcuPilot.Port.LogSourcePort).FileFor("messages"), ##class(OcuPilot.Port.LogSourcePort).ManagerDirectory())
    Set tFrom = ##class(%File).GetFileSize(tLog)
    Set tUser = $Parameter(..#PROBE, "USER")
    Set tStart = ..StartAs(tUser, ..#UNINDEXED, "SELECT Name FROM OcuProbe1915.Granted WHERE Name = '" _ tMark _ "'")
    Set tView = ..AwaitOverTheWire(tUser, tStart.%Get("key"))
    Do $$$AssertEquals($Select($IsObject(tView) && (tView.%GetTypeOf("refusal") = "object"): tView.status _ " " _ tView.refusal.code, 1: ..Said(tView)), "failed EXPLORER.SQL.BACKGROUND.LOST", "the run whose statement could not run reads lost")
    Hang 0.5
    Set (tLogged, tFound) = ""
    Set tStream = ##class(%Stream.FileCharacter).%New()
    If tStream.LinkToFile(tLog) && (tStream.Size > tFrom) && tStream.MoveTo(tFrom + 1) {
        While 'tStream.AtEnd {
            Set tLine = tStream.ReadLine()
            If tLine [ """subsystem"":""sqlbackground""" Set tLogged = tLine
            If $ZConvert(tLine, "U") [ $ZConvert(tMark, "U") Set tFound = tLine
        }
    }
    Set tStream = ""
    Do $$$AssertNotEquals(tLogged, "", "the job wrote its failure line")
    Do $$$AssertEquals(tFound, "", "and no line carries the statement")
}

}
