/// <p>Pins SQL query's three background routes over the wire (Story 19.15): <code>POST
/// /explorer/sql/background</code>, <code>GET /explorer/sql/background/:id</code> and <code>POST
/// /explorer/sql/background/:id/cancel</code>, each answering one JSON envelope -- a run id at once,
/// the run polled to its end, every kind but a query refused and nothing spawned, the console's other
/// refusals, value count and error outcome answered as the run route answers them, the screen's gate on
/// all three routes, the same 404 for another user's run, an unknown id and a malformed one, a busy
/// owner named its running run, a swept and a replaced run gone, a query with values run with them,
/// and a <code>%Developer</code> running a background query in USER.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, and a <code>USER</code> namespace. It creates and
/// removes <class>OcuPilot.Test.SqlBackgroundProbe</class>'s objects, data included, its principals and
/// <class>OcuPilot.Test.DeveloperFloorFixture</class>'s developer principal, so it runs on a throwaway
/// only: <method>OnBeforeAllTests</method> refuses unless
/// <parameter>OcuPilot.Test.SqlConsoleProbe.ARMINGVARIABLE</parameter> reads <code>1</code>. Every run a
/// test starts has ended, and every run row it made is removed, before the test returns.</p>
Class OcuPilot.Test.SqlBackgroundRoutes Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.SqlBackgroundProbe";

Parameter DEVELOPER = "OcuPilot.Test.DeveloperFloorFixture";

Parameter STORE = "OcuPilot.Kernel.State.SqlRun";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter START = "/api/ocupilot/explorer/sql/background";

/// <p>The poll and cancel routes as the map declares them, under the API's base path; <method>Path</method>
/// puts a run id in <code>:id</code>.</p>
Parameter POLL = "/api/ocupilot/explorer/sql/background/:id";

Parameter CANCEL = "/api/ocupilot/explorer/sql/background/:id/cancel";

/// <p>A query that runs for minutes unless it is canceled: a six-way cross join's count.</p>
Parameter LONGERQUERY = "SELECT COUNT(*) AS N FROM OcuProbe1915.Granted a, OcuProbe1915.Granted b, OcuProbe1915.Granted c, OcuProbe1915.Granted d, OcuProbe1915.Granted e, OcuProbe1915.Granted f";

/// <p>An id of the right shape that no run holds.</p>
Parameter ABSENTID = "0123456789abcdef0123456789abcdef";

/// <p>The principals' password for this run.</p>
Property PreparedPassword As %String;

/// <p>The developer principal's password for this run.</p>
Property PreparedDeveloperPassword As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedDeveloperPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If '$ClassMethod(..#PROBE, "Armed") {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlBackgroundRoutes creates IRIS users and roles and runs on a throwaway container only. " _ $Parameter(..#PROBE, "ARMINGVARIABLE") _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuProbe1915" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set ..PreparedDeveloperPassword = $ClassMethod(..#DEVELOPER, "NewPassword")
    Set tSC = $ClassMethod(..#PROBE, "Make")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "EnsurePrincipals", ..PreparedPassword)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#DEVELOPER, "EnsurePrincipal", ..PreparedDeveloperPassword, "", .tUser)
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
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemovePrincipals"))
    Set tLeft = $ClassMethod(..#DEVELOPER, "RemovePrincipals")
    If tLeft '= "" Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the developer principal's teardown left:" _ tLeft))
    Quit tSC
}

/// <p>The owners this class's runs belong to: the probe's principals, the developer principal and
/// the suite's own account.</p>
ClassMethod Owners() As %List
{
    Quit $ListBuild($Parameter(..#PROBE, "USER"), $Parameter(..#PROBE, "NODEVUSER"), $Parameter(..#PROBE, "NOUSERUSER"), $Parameter(..#DEVELOPER, "DEVELOPERUSER"), ##class(OcuPilot.Test.Http).GetTestUsername())
}

/// <p>Stop every live run of this class's owners, wait up to 20 seconds for each to end, then remove
/// every row of theirs; an error when a run is still live.</p>
ClassMethod Settle() As %Status
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
        Do $ClassMethod(..#STORE, "GuardedSweep", ..#LIMITS)
    }
    For tI = 1:1:$ListLength(tOwners) {
        Do $ClassMethod(..#STORE, "GuardedForgetUser", $List(tOwners, tI))
    }
    If tLive Quit $$$ERROR($$$GeneralError, "a background run of this class was still live after 20 seconds")
    Quit $$$OK
}

/// <p>The password of <var>pUser</var>: the suite's own account's, the developer principal's, or the
/// probe principals'.</p>
Method PasswordOf(pUser As %String) As %String
{
    If pUser = ##class(OcuPilot.Test.Http).GetTestUsername() Quit ##class(OcuPilot.Test.Http).GetTestPassword()
    If pUser = $Parameter(..#DEVELOPER, "DEVELOPERUSER") Quit ..PreparedDeveloperPassword
    Quit ..PreparedPassword
}

/// <p>Send <var>pMethod</var> <var>pPath</var> (an absolute path, in namespace <var>pNamespace</var>)
/// as <var>pUser</var>, with <var>pBody</var> when it is given; answers the status, the parsed answer
/// and the response's content type.</p>
Method Send(pMethod As %String, pPath As %String, pUser As %String, Output pStatus As %Integer, Output pAnswer, Output pType As %String, pBody = "", pNamespace As %String = "USER")
{
    Set tText = $Select($IsObject(pBody): pBody.%ToJSON(), 1: pBody)
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, pPath _ "?ns=" _ pNamespace, pUser, ..PasswordOf(pUser), .pStatus, .tRaw, .tHeaders, tText, "application/json")
    Set pType = $Piece($Get(tHeaders("CONTENT-TYPE")), ";", 1)
    Set pAnswer = ""
    Try {
        Set pAnswer = ##class(%DynamicObject).%FromJSON(tRaw)
    } Catch {
        Set pAnswer = $Get(tRaw)
    }
}

/// <p><var>pRoute</var>, <parameter>POLL</parameter> or <parameter>CANCEL</parameter>, with
/// <var>pKey</var> in its <code>:id</code> segment.</p>
ClassMethod Path(pRoute As %String, pKey As %String) As %String
{
    Quit $Replace(pRoute, ":id", pKey)
}

/// <p>Poll run <var>pKey</var> as <var>pUser</var> every quarter second until it no longer reads
/// running, or for <var>pSeconds</var>; the last answer.</p>
Method Await(pUser As %String, pKey As %String, pSeconds As %Numeric = 20) As %DynamicObject
{
    Set tDeadline = $ZHorolog + pSeconds
    For {
        Do ..Send("GET", ..Path(..#POLL, pKey), pUser, .tStatus, .tAnswer, .tType)
        If '$IsObject(tAnswer) || (tAnswer.%Get("status") '= "running") || ($ZHorolog > tDeadline) Quit
        Hang 0.25
    }
    Quit tAnswer
}

/// <p>An answer as one line: the status, then the body as JSON.</p>
ClassMethod Line(pStatus As %Integer, pAnswer) As %String
{
    Quit $Get(pStatus) _ " " _ $Select($IsObject($Get(pAnswer)): pAnswer.%ToJSON(), 1: $Get(pAnswer))
}

/// <p>A refusal as one line: the status and the envelope's code.</p>
ClassMethod Code(pStatus As %Integer, pAnswer) As %String
{
    Quit $Get(pStatus) _ " " _ $Select($IsObject($Get(pAnswer)): pAnswer.%Get("code"), 1: $Get(pAnswer))
}

/// <p>How many run rows <var>pUser</var> has.</p>
ClassMethod Rows(pUser As %String) As %Integer
{
    Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(UserName) = ?", pUser)
    If (tResult.%SQLCODE < 0) || 'tResult.%Next() Quit -1
    Quit +tResult.%GetData(1)
}

/// <p>AC1: the start answers 202 with a run id within a second, while its query runs on; a query run
/// in the background is polled to its end, its rows cut at Max rows with the cut reported.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Explorer.SqlBackground.HandleStart</method> run the
/// query in the request before it answers -- the within-a-second leg goes red.</p>
Method TestTheStartAnswersARunIdAtOnce()
{
    Set tUser = $Parameter(..#PROBE, "USER")
    Set tAsked = $ZHorolog
    Do ..Send("POST", ..#START, tUser, .tStatus, .tAnswer, .tType, {"statement": (..#LONGERQUERY)})
    Set tTook = $ZHorolog - tAsked
    Do $$$AssertEquals(tStatus, 202, "the start answers 202")
    Do $$$AssertEquals(tType, "application/json", "with CONTENT-TYPE application/json")
    Do $$$AssertTrue(tTook < 1, "within a second, its query still running: " _ $FNumber(tTook, "", 3) _ " s")
    Set tKey = $Select($IsObject(tAnswer): tAnswer.%Get("id"), 1: "")
    Do $$$AssertEquals($Match(tKey, "^[0-9a-f]{32}$") _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("status"), 1: ""), "1 running", "its body is the run id and its status: " _ ..Line(tStatus, tAnswer))
    Do ..Send("GET", ..Path(..#POLL, tKey), tUser, .tStatus, .tAnswer, .tType)
    Do $$$AssertEquals(tStatus _ " " _ tType _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("status"), 1: ""), "200 application/json running", "the poll reads it running")
    Do ..Send("POST", ..Path(..#CANCEL, tKey), tUser, .tStatus, .tAnswer, .tType)
    Do $$$AssertEquals(tStatus _ " " _ tType, "200 application/json", "the cancel answers 200 as JSON")
    Do $$$AssertEquals($Select($IsObject(..Await(tUser, tKey)): ..Await(tUser, tKey).%Get("status"), 1: ""), "canceled", "and the run reads canceled")
    Do ..Send("POST", ..#START, tUser, .tStatus, .tAnswer, .tType, {"statement": "SELECT Name FROM OcuProbe1915.Granted ORDER BY Num", "maxRows": 5})
    Do $$$AssertEquals(tStatus, 202, "a second run starts once the first has ended")
    Set tView = ..Await(tUser, $Select($IsObject(tAnswer): tAnswer.%Get("id"), 1: ""))
    Do $$$AssertEquals($Select($IsObject(tView): tView.status _ " " _ tView.result.%ToJSON(), 1: ""), "ended {""kind"":""query"",""outcome"":""rows"",""columns"":[""Name""],""rows"":[[""n1""],[""n2""],[""n3""],[""n4""],[""n5""]],""truncated"":true}", "polled to its end: five rows, the cut reported")
}

/// <p>A background query with values runs with them, in their order: they reach the job in its one
/// argument and are bound to the statement's value positions.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Explorer.SqlBackground.Start</method> put no values in
/// the job's argument -- the run ends failed and this goes red.</p>
Method TestAQueryWithValuesRunsWithThemInOrder()
{
    Set tUser = $Parameter(..#PROBE, "USER")
    Do ..Send("POST", ..#START, tUser, .tStatus, .tAnswer, .tType, {"statement": "SELECT Name FROM OcuProbe1915.Granted WHERE Num = ? AND Name = ?", "parameters": ["2", "n2"]})
    Do $$$AssertEquals(tStatus, 202, "the start answers 202: " _ ..Line(tStatus, tAnswer))
    Set tView = ..Await(tUser, $Select($IsObject(tAnswer): tAnswer.%Get("id"), 1: ""))
    Do $$$AssertEquals($Select($IsObject(tView) && (tView.%GetTypeOf("result") = "object"): tView.status _ " " _ tView.result.%ToJSON(), 1: ..Line(0, tView)), "ended {""kind"":""query"",""outcome"":""rows"",""columns"":[""Name""],""rows"":[[""n2""]],""truncated"":false}", "it ends with the one row both values select")
}

/// <p>AC2: a DML, DDL or CALL statement the suite's account may prepare is refused 422
/// <code>EXPLORER.SQL.BACKGROUND.QUERYONLY</code> and nothing is spawned or changed; the console's other refusals, the value count and the error
/// outcome answer as the run route answers them, and none of them spawns a run.</p>
/// <p>Mutation (Rule 19): drop the query-only check from
/// <method>OcuPilot.Area.Explorer.SqlBackground.HandleStart</method> -- the UPDATE is answered 202 and
/// this goes red.</p>
Method TestEveryKindButAQueryIsRefusedAndNothingIsSpawned()
{
    Set tUser = $Parameter(..#PROBE, "USER")
    Set tSuite = ##class(OcuPilot.Test.Http).GetTestUsername()
    For tText = "UPDATE OcuProbe1915.Granted SET Num = 3", "DELETE FROM OcuProbe1915.Granted", "CREATE TABLE OcuProbe1915.Made (X INTEGER)", "CALL OcuProbe1915.LeaveOpen()" {
        Do ..Send("POST", ..#START, tSuite, .tStatus, .tAnswer, .tType, {"statement": (tText)})
        Do $$$AssertEquals(..Code(tStatus, tAnswer) _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("reason"), 1: ""), "422 EXPLORER.SQL.BACKGROUND.QUERYONLY " _ ##class(OcuPilot.Api.AtelierError).#REASONSQLBACKGROUNDQUERYONLY, tText _ " is refused")
    }
    For tCase = $ListBuild("START TRANSACTION", "422 EXPLORER.SQL.SESSION"), $ListBuild("GRANT SELECT ON OcuProbe1915.Granted TO _PUBLIC", "422 EXPLORER.SQL.ADMINISTRATION"), $ListBuild("LOAD DATA FROM FILE '/tmp/ocuprobe1915.csv' INTO OcuProbe1915.Granted", "422 EXPLORER.SQL.SERVERFILES"), $ListBuild("CREATE USER OcuProbe1915Nobody IDENTIFY BY 'OcuProbe1915NotACredential'", "422 EXPLORER.SQL.PASSWORD") {
        Do ..Send("POST", ..#START, tUser, .tStatus, .tAnswer, .tType, {"statement": ($List(tCase, 1))})
        Do $$$AssertEquals(..Code(tStatus, tAnswer), $List(tCase, 2), $List(tCase, 1) _ " is refused as the run route refuses it")
    }
    For tBody = {"statement": ""}, {"statement": "SELECT 1", "maxRows": 0}, {"statement": "SELECT 1", "parameters": [1]}, {"statement": "SELECT 1", "extra": true} {
        Do ..Send("POST", ..#START, tUser, .tStatus, .tAnswer, .tType, tBody)
        Do $$$AssertEquals(..Code(tStatus, tAnswer), "400 EXPLORER.SQL.INPUT", "bad input is refused: " _ tBody.%ToJSON())
    }
    Do ..Send("POST", ..#START, tUser, .tStatus, .tAnswer, .tType, {"statement": "SELECT Name FROM OcuProbe1915.Granted WHERE Num > ?"})
    Do $$$AssertEquals(..Line(tStatus, tAnswer), "200 {""outcome"":""parameters"",""count"":1}", "the value count is asked for")
    Do ..Send("POST", ..#START, tUser, .tStatus, .tAnswer, .tType, {"statement": "SELECT Name FROM OcuProbe1915.Hidden"})
    Do $$$AssertEquals($Select($IsObject(tAnswer): tStatus _ " " _ tAnswer.%Get("outcome") _ " " _ tAnswer.%Get("sqlcode"), 1: ""), "200 error -99", "an ungranted table is the error outcome")
    Do ..Send("POST", ..#START, tUser, .tStatus, .tAnswer, .tType, {"statement": "SELEC Name FROM OcuProbe1915.Granted"})
    Do $$$AssertEquals($Select($IsObject(tAnswer): tStatus _ " " _ tAnswer.%Get("outcome") _ " " _ (tAnswer.%Get("sqlcode") < 0), 1: ""), "200 error 1", "a syntax error is the error outcome")
    Do ..Send("POST", ..#START, ##class(OcuPilot.Test.Http).GetTestUsername(), .tStatus, .tAnswer, .tType, {"statement": "SELECT ID FROM OcuPilot_Kernel_State.Proposal"}, $NAMESPACE)
    Do $$$AssertEquals(..Code(tStatus, tAnswer), "403 PROHIBITED.OCUPILOTSQL", "OcuPilot's own table is refused in the install namespace")
    Do $$$AssertEquals(..Rows(tUser) _ " " _ ..Rows(tSuite), "0 0", "no answer spawned a run")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Granted"), "40 820", "the table is unchanged")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "HoldsTable", "OcuProbe1915.Made"), "and nothing was created")
}

/// <p>The screen's gate refuses all three routes 403 <code>AUTH.NOPRIVILEGE</code> naming
/// <code>%Development:USE</code>, before anything else; an id of any other shape, and one no run holds,
/// are each the same 404.</p>
Method TestTheGateAndTheIdShapeOnEveryRoute()
{
    Set tNoDev = $Parameter(..#PROBE, "NODEVUSER")
    For tCase = $ListBuild("POST", ..#START), $ListBuild("GET", ..Path(..#POLL, ..#ABSENTID)), $ListBuild("POST", ..Path(..#CANCEL, ..#ABSENTID)), $ListBuild("GET", ..Path(..#POLL, "nothex")) {
        Do ..Send($List(tCase, 1), $List(tCase, 2), tNoDev, .tStatus, .tAnswer, .tType, $Select($List(tCase, 2) = ..#START: {"statement": "SELECT 1 AS One"}, 1: ""))
        Do $$$AssertEquals(..Code(tStatus, tAnswer) _ " " _ $Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("detail")): tAnswer.detail.%Get("failedPair"), 1: ""), "403 AUTH.NOPRIVILEGE %Development:USE", $List(tCase, 1) _ " " _ $List(tCase, 2) _ " without %Development:USE")
    }
    Set tUser = $Parameter(..#PROBE, "USER")
    Set tSame = ""
    For tPath = ..Path(..#POLL, ..#ABSENTID), ..Path(..#CANCEL, ..#ABSENTID), ..Path(..#POLL, "nothex"), ..Path(..#CANCEL, "NOTHEX"), ..Path(..#POLL, $ZConvert(..#ABSENTID, "U")) {
        Do ..Send($Select($Extract(tPath, *-6, *) = "/cancel": "POST", 1: "GET"), tPath, tUser, .tStatus, .tAnswer, .tType)
        Do $$$AssertEquals(tStatus _ " " _ tType, "404 application/json", tPath _ " answers 404 as JSON")
        If tSame '= "" Do $$$AssertEquals(..Line(tStatus, tAnswer), tSame, tPath _ " answers the first path's body")
        If tSame = "" Set tSame = ..Line(tStatus, tAnswer)
    }
    Do $$$AssertEquals($Piece(tSame, " ", 1) _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "404 EXPLORER.SQL.BACKGROUND.NOTFOUND", "which is EXPLORER.SQL.BACKGROUND.NOTFOUND")
}

/// <p>AC6: another user's poll and cancel of a run each answer the same 404 as an unknown id, and the
/// owner's run is unaffected.</p>
/// <p>Mutation (Rule 19): drop the owner from
/// <method>OcuPilot.Kernel.State.SqlRun.IdForOwner</method>'s statement, which
/// <method>OcuPilot.Kernel.State.SqlRun.GuardedViewForOwner</method> reads -- the other user's poll is
/// answered 200 and this goes red.</p>
Method TestAnotherUsersRunAnswersTheSameNotFound()
{
    Set tOwner = $Parameter(..#PROBE, "USER")
    Set tOther = $Parameter(..#PROBE, "NOUSERUSER")
    Do ..Send("POST", ..#START, tOwner, .tStatus, .tAnswer, .tType, {"statement": (..#LONGERQUERY)})
    Set tKey = $Select($IsObject(tAnswer): tAnswer.%Get("id"), 1: "")
    Do $$$AssertEquals(tStatus, 202, "the owner's run starts")
    Do ..Send("GET", ..Path(..#POLL, ..#ABSENTID), tOther, .tStatus, .tUnknown, .tType, "", $NAMESPACE)
    For tCase = $ListBuild("GET", ..Path(..#POLL, tKey)), $ListBuild("POST", ..Path(..#CANCEL, tKey)) {
        Do ..Send($List(tCase, 1), $List(tCase, 2), tOther, .tStatus, .tAnswer, .tType, "", $NAMESPACE)
        Do $$$AssertEquals(..Line(tStatus, tAnswer), ..Line(404, tUnknown), "another user's " _ $List(tCase, 1) _ " answers the unknown id's 404")
    }
    Do ..Send("GET", ..Path(..#POLL, tKey), tOwner, .tStatus, .tAnswer, .tType)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tStatus _ " " _ tAnswer.%Get("status") _ " " _ tAnswer.%Get("cancelRequested"), 1: ""), "200 running 0", "the owner's run is unaffected")
}

/// <p>AC7: an owner whose run is running is refused a second start 409
/// <code>EXPLORER.SQL.BACKGROUND.BUSY</code>, its <code>detail.runId</code> naming the running run, and
/// nothing else is reserved.</p>
/// <p>Mutation (Rule 19): skip the per-owner check in
/// <method>OcuPilot.Kernel.State.SqlRun.GuardedReserve</method> -- the second start is answered 202 and
/// this goes red.</p>
Method TestABusyOwnerIsNamedItsRunningRun()
{
    Set tUser = $Parameter(..#PROBE, "USER")
    Do ..Send("POST", ..#START, tUser, .tStatus, .tAnswer, .tType, {"statement": (..#LONGERQUERY)})
    Set tKey = $Select($IsObject(tAnswer): tAnswer.%Get("id"), 1: "")
    Do $$$AssertEquals(tStatus, 202, "the first run starts")
    Do ..Send("POST", ..#START, tUser, .tStatus, .tAnswer, .tType, {"statement": "SELECT 1 AS One"})
    Do $$$AssertEquals(tStatus _ " " _ tType, "409 application/json", "a second start answers 409 as JSON")
    Do $$$AssertEquals(..Code(tStatus, tAnswer) _ " " _ $Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("detail")): tAnswer.detail.%Get("runId"), 1: ""), "409 EXPLORER.SQL.BACKGROUND.BUSY " _ tKey, "naming the running run")
    Do $$$AssertEquals(..Rows(tUser), 1, "and nothing else is reserved")
}

/// <p>AC8: an ended run kept past its retention is swept by the next start, of any user, and its poll
/// then answers 404; an owner's new run removes that owner's ended run.</p>
/// <p>Mutation (Rule 19): skip the delete in <method>OcuPilot.Kernel.State.SqlRun.GuardedSweep</method>
/// -- the swept run still answers 200 and this goes red.</p>
Method TestASweptOrReplacedRunIsGone()
{
    Set tUser = $Parameter(..#PROBE, "USER")
    Do ..Send("POST", ..#START, tUser, .tStatus, .tAnswer, .tType, {"statement": "SELECT 1 AS One"})
    Set tFirst = $Select($IsObject(tAnswer): tAnswer.%Get("id"), 1: "")
    Do $$$AssertEquals($Select($IsObject(..Await(tUser, tFirst)): ..Await(tUser, tFirst).%Get("status"), 1: ""), "ended", "a run ends")
    Do ..Send("POST", ..#START, tUser, .tStatus, .tAnswer, .tType, {"statement": "SELECT 2 AS Two"})
    Set tSecond = $Select($IsObject(tAnswer): tAnswer.%Get("id"), 1: "")
    Do $$$AssertEquals($Select($IsObject(..Await(tUser, tSecond)): ..Await(tUser, tSecond).%Get("status"), 1: ""), "ended", "the owner's next run ends")
    Do ..Send("GET", ..Path(..#POLL, tFirst), tUser, .tStatus, .tAnswer, .tType)
    Do $$$AssertEquals(..Code(tStatus, tAnswer), "404 EXPLORER.SQL.BACKGROUND.NOTFOUND", "the next run replaced the first")
    Set tEnded = ##class(OcuPilot.Kernel.State.Turn).IsoOfSeconds(##class(OcuPilot.Kernel.State.Turn).NowSeconds() - $Parameter(..#LIMITS, "RETENTIONSECONDS") - 60)
    Set tResult = ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuPilot_Kernel_State.SqlRun SET EndedAt = ? WHERE %EXACT(RunKey) = ?", tEnded, tSecond)
    Do $$$AssertEquals(tResult.%SQLCODE _ " " _ tResult.%ROWCOUNT, "0 1", "the second run ended before its retention")
    Do ..Send("GET", ..Path(..#POLL, tSecond), tUser, .tStatus, .tAnswer, .tType)
    Do $$$AssertEquals(tStatus, 200, "until a sweep, it is still answered")
    Set tOther = ##class(OcuPilot.Test.Http).GetTestUsername()
    Do ..Send("POST", ..#START, tOther, .tStatus, .tAnswer, .tType, {"statement": "SELECT 3 AS Three"})
    Do $$$AssertEquals(tStatus, 202, "another user's start sweeps")
    Do ..Send("GET", ..Path(..#POLL, tSecond), tUser, .tStatus, .tAnswer, .tType)
    Do $$$AssertEquals(..Code(tStatus, tAnswer), "404 EXPLORER.SQL.BACKGROUND.NOTFOUND", "and the run past its retention is gone")
}

/// <p>AC10: a <code>%Developer</code> runs a background query in USER and reads its answer.</p>
Method TestADeveloperRunsABackgroundQueryInUser()
{
    Set tDeveloper = $Parameter(..#DEVELOPER, "DEVELOPERUSER")
    Do ..Send("POST", ..#START, tDeveloper, .tStatus, .tAnswer, .tType, {"statement": "SELECT 1 AS One"})
    Do $$$AssertEquals(tStatus, 202, "the developer's start answers 202: " _ ..Line(tStatus, tAnswer))
    Set tView = ..Await(tDeveloper, $Select($IsObject(tAnswer): tAnswer.%Get("id"), 1: ""))
    Do $$$AssertEquals($Select($IsObject(tView) && (tView.%GetTypeOf("result") = "object"): tView.status _ " " _ tView.result.%ToJSON(), 1: ..Line(0, tView)), "ended {""kind"":""query"",""outcome"":""rows"",""columns"":[""One""],""rows"":[[""1""]],""truncated"":false}", "and reads its answer")
}

/// <p>AC5 (QA): a cancel of a run that ended with rows answers 200 with the run as it is, answer
/// included, and a later poll reads the same run: the cancel does not turn an ended run canceled.</p>
/// <p>Mutation (Rule 19): drop the terminal-state test from <method>OcuPilot.Kernel.State.SqlRun.GuardedCancel</method>
/// -- the ended run's cancel flag is set, its body changes and both unchanged-body legs go red.</p>
Method TestACancelOfAnEndedRunLeavesItUnchanged()
{
    Set tUser = $Parameter(..#PROBE, "USER")
    Do ..Send("POST", ..#START, tUser, .tStatus, .tAnswer, .tType, {"statement": "SELECT 1 AS One"})
    Do $$$AssertEquals(tStatus, 202, "the start answers 202: " _ ..Line(tStatus, tAnswer))
    Set tKey = $Select($IsObject(tAnswer): tAnswer.%Get("id"), 1: "")
    Set tEnded = ..Await(tUser, tKey)
    Do $$$AssertEquals($Select($IsObject(tEnded): tEnded.%Get("status"), 1: ""), "ended", "the run ended with its rows")
    Do ..Send("POST", ..Path(..#CANCEL, tKey), tUser, .tStatus, .tAnswer, .tType)
    Do $$$AssertEquals(..Line(tStatus, tAnswer), "200 " _ tEnded.%ToJSON(), "the cancel answers the ended run as it is")
    Do ..Send("GET", ..Path(..#POLL, tKey), tUser, .tStatus, .tAnswer, .tType)
    Do $$$AssertEquals(..Line(tStatus, tAnswer), "200 " _ tEnded.%ToJSON(), "and the next poll reads the same run")
}

}
