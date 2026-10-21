/// <p>Pins MDX query's three background routes over the wire (Story 20.33): <code>POST /analytics/mdx/background</code>,
/// <code>GET /analytics/mdx/background/:id</code> and <code>POST /analytics/mdx/background/:id/cancel</code>, each answering one JSON
/// envelope -- a run id at once and the run polled to its cells or its listing; a cell's drill-through and a typed one; every refusal by its
/// code before anything is spawned; a statement that runs server-side code or SQL, or that the detector cannot read, answered
/// <code>confirm</code> with nothing prepared, reserved or run until the same body carries <code>confirmed: true</code>; the screen's gate on
/// all three routes; the same 404 for another user's run, an unknown id and a malformed one; a busy owner named its run; an MDX run that
/// does not block the owner's SQL run, and the instance cap that counts both kinds.</p>
/// <p><b>What it needs from the environment:</b> <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it creates
/// and removes IRIS users and roles and, through <class>OcuPilot.Test.AnalyticsProbe</class>, turns analytics on for <code>USER</code>
/// and writes cubes there. Every run a test starts has ended, and every run row it made is removed, before the test returns.</p>
Class OcuPilot.Test.AnalyticsMdxRoutes Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AnalyticsProbe";

Parameter STORE = "OcuPilot.Kernel.State.SqlRun";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter START = "/api/ocupilot/analytics/mdx/background";

Parameter POLL = "/api/ocupilot/analytics/mdx/background/:id";

Parameter CANCEL = "/api/ocupilot/analytics/mdx/background/:id/cancel";

Parameter SQLSTART = "/api/ocupilot/explorer/sql/background";

/// <p>The principals, each <code>&lt;user&gt;:&lt;the pairs it holds beyond the code database's READ&gt;</code>: two that run MDX in
/// <code>USER</code> (the portal's pair is public) and one that holds only the interoperability floor.</p>
Parameter PRINCIPALS = "OcuP2033Owner:%Development:U,%DB_USER:RW;OcuP2033Other:%Development:U,%DB_USER:RW;OcuP2033NoDev:%Ens_Portal:U,%DB_USER:RW";

Parameter OWNER = "OcuP2033Owner";

Parameter OTHER = "OcuP2033Other";

Parameter NODEV = "OcuP2033NoDev";

/// <p>An id of the right shape that no run holds.</p>
Parameter ABSENTID = "0123456789abcdef0123456789abcdef";

Parameter CROSSJOIN = "SELECT {[Measures].[Amount]} ON 0, NON EMPTY CROSSJOIN({[Sub].[H1].[Sub].&[1],[Sub].[H1].[Sub].&[2]},{[Sub2].[H1].[Sub2].&[0],[Sub2].[H1].[Sub2].&[1]}) ON 1 FROM [OcuPilotProbeGrid]";

Parameter SLOW = "SELECT {[Measures].[Amount]} ON 0, NON EMPTY CROSSJOIN([Sub].[H1].[Sub].Members,[Sub2].[H1].[Sub2].Members) ON 1 FROM [OcuPilotProbeGrid]";

/// <p>A statement whose <code>%SEARCH</code> braces increment <code>^OcuPilotProbeMdxSplice(&lt;n&gt;)</code> in <code>USER</code> when
/// the vendor executes it, and nothing before.</p>
Parameter SPLICE = "SELECT {[Measures].[Amount]} ON 0 FROM [OcuPilotProbeGrid] WHERE %SEARCH.&[ID > {$Increment(^OcuPilotProbeMdxSplice(@@))}]";

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
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsMdxRoutes creates IRIS users and roles, turns analytics on in USER and writes cubes there, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuP2033Routes" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Enable")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "Create", ..#OWNER)
    If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Test.InteropTestGate).CreatePrincipals(..#PRINCIPALS, ..PreparedPassword, "OcuPilot.Test.AnalyticsMdxRoutes")
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
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(..#PRINCIPALS, ";") {
            Set tUser = $Piece($Piece(..#PRINCIPALS, ";", tI), ":", 1)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tUser _ "Role") Do ##class(Security.Roles).Delete(tUser _ "Role")
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsMdxRoutes left the principal or role of " _ tUser))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    If $$$ISOK(tSC) && '$ClassMethod(..#PROBE, "Gone") Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AnalyticsMdxRoutes left probe state in USER: " _ $ClassMethod(..#PROBE, "Left"))
    Quit tSC
}

/// <p>The owners this class's runs belong to: its principals, the suite's own account and the fill users of the cap test.</p>
ClassMethod Owners() As %List
{
    Quit $ListBuild(..#OWNER, ..#OTHER, ..#NODEV, ##class(OcuPilot.Test.Http).GetTestUsername(), "OcuP2033Fill1", "OcuP2033Fill2", "OcuP2033Fill3", "OcuP2033Fill4", "OcuP2033Fill5")
}

/// <p>Stop every live run of this class's owners (an MDX run by its owner's cancel, a fill row by ending it), wait up to 20 seconds for
/// each to end, then remove every row of theirs; an error when a run is still live.</p>
Method Settle() As %Status
{
    Set tOwners = ..Owners()
    Set tDeadline = $ZHorolog + 20
    For {
        Set tLive = 0
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT %EXACT(UserName), RunKey, State, COALESCE(Kind, 'sql'), JobId FROM OcuPilot_Kernel_State.SqlRun WHERE State IN ('queued', 'running')")
        While tResult.%Next() {
            If '$ListFind(tOwners, tResult.%GetData(1)) Continue
            Set tLive = tLive + 1
            If $Extract(tResult.%GetData(1), 1, 13) = "OcuP2033Fill" {
                Do $ClassMethod(..#STORE, "GuardedFinish", tResult.%GetData(2), "failed", "")
            } ElseIf tResult.%GetData(4) = "mdx" {
                Do ##class(OcuPilot.Area.Analytics.MdxQuery).Cancel(tResult.%GetData(2), tResult.%GetData(1), .tFound)
            } Else {
                Do ##class(OcuPilot.Area.Explorer.SqlBackground).Cancel(tResult.%GetData(2), tResult.%GetData(1), .tFound)
            }
        }
        If (tLive = 0) || ($ZHorolog > tDeadline) Quit
        Hang 0.5
        Do $ClassMethod(..#STORE, "GuardedSweep", ..#LIMITS)
    }
    For tI = 1:1:$ListLength(tOwners) {
        Do $ClassMethod(..#STORE, "GuardedForgetUser", $List(tOwners, tI))
    }
    Kill ^|"USER"|OcuPilotProbeMdxSplice
    If tLive Quit $$$ERROR($$$GeneralError, "a background run of this class was still live after 20 seconds")
    Quit $$$OK
}

/// <p>The password of <var>pUser</var>.</p>
Method PasswordOf(pUser As %String) As %String
{
    If pUser = ##class(OcuPilot.Test.Http).GetTestUsername() Quit ##class(OcuPilot.Test.Http).GetTestPassword()
    Quit ..PreparedPassword
}

/// <p>Send <var>pMethod</var> <var>pPath</var> (an absolute path, in namespace <var>pNamespace</var>) as <var>pUser</var>, with
/// <var>pBody</var> when it is given; answers the status, the parsed answer and the response's content type.</p>
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

/// <p><var>pRoute</var>, <parameter>POLL</parameter> or <parameter>CANCEL</parameter>, with <var>pKey</var> in its <code>:id</code>
/// segment.</p>
ClassMethod Path(pRoute As %String, pKey As %String) As %String
{
    Quit $Replace(pRoute, ":id", pKey)
}

/// <p>Start <var>pBody</var> as <var>pUser</var>, expect 202 and poll its run until it no longer reads running (or for
/// <var>pSeconds</var>); the last answer, or the start's own when it was not accepted.</p>
Method RunToEnd(pBody As %DynamicObject, pUser As %String, pSeconds As %Numeric = 30) As %DynamicObject
{
    Do ..Send("POST", ..#START, pUser, .tStatus, .tAnswer, .tType, pBody)
    If tStatus '= 202 Quit $Select($IsObject(tAnswer): tAnswer, 1: {"error": (tAnswer)})
    Set tKey = tAnswer.%Get("id")
    Set tDeadline = $ZHorolog + pSeconds
    For {
        Do ..Send("GET", ..Path(..#POLL, tKey), pUser, .tStatus, .tAnswer, .tType)
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

/// <p>The splice statement for node <var>pNode</var>, and whether that node is defined in <code>USER</code>.</p>
ClassMethod Splice(pNode As %Integer) As %String
{
    Quit $Replace(..#SPLICE, "@@", pNode)
}

ClassMethod NodeDefined(pNode As %Integer) As %Boolean
{
    Quit ''$Data(^|"USER"|OcuPilotProbeMdxSplice(pNode))
}

/// <p>AC1: the start answers 202 with a run id within a second, while the slow query runs on; the poll reads it running; the owner's
/// cancel answers 200 as JSON and the run reads canceled. A plain query is then polled to its cells; a drill-through, run as the suite's
/// account because a listing reads the source table, which the owner principal holds no SELECT on, to its listing.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Shell.BackgroundRun.HandleStart</method> wait for the run -- the within-a-second leg
/// goes red.</p>
Method TestTheStartAnswersARunIdAtOnceAndAPollReadsItsAnswer()
{
    Set tOwner = ..#OWNER
    Set tAsked = $ZHorolog
    Do ..Send("POST", ..#START, tOwner, .tStatus, .tAnswer, .tType, {"statement": (..#SLOW)})
    Set tTook = $ZHorolog - tAsked
    Do $$$AssertEquals(tStatus, 202, "the start answers 202")
    Do $$$AssertEquals(tType, "application/json", "with CONTENT-TYPE application/json")
    Do $$$AssertTrue(tTook < 1, "within a second, its query still running: " _ $FNumber(tTook, "", 3) _ " s")
    Set tKey = $Select($IsObject(tAnswer): tAnswer.%Get("id"), 1: "")
    Do $$$AssertEquals($Match(tKey, "^[0-9a-f]{32}$") _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("status"), 1: ""), "1 running", "its body is the run id and its status: " _ ..Line(tStatus, tAnswer))
    Do ..Send("GET", ..Path(..#POLL, tKey), tOwner, .tStatus, .tAnswer, .tType)
    Do $$$AssertEquals(tStatus _ " " _ tType _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("status"), 1: ""), "200 application/json running", "the poll reads it running")
    Hang 1
    Do ..Send("POST", ..Path(..#CANCEL, tKey), tOwner, .tStatus, .tAnswer, .tType)
    Do $$$AssertEquals(tStatus _ " " _ tType, "200 application/json", "the cancel answers 200 as JSON")
    Set tDeadline = $ZHorolog + 15
    For {
        Do ..Send("GET", ..Path(..#POLL, tKey), tOwner, .tStatus, .tAnswer, .tType)
        If (tAnswer.%Get("status") '= "running") || ($ZHorolog > tDeadline) Quit
        Hang 0.25
    }
    Do $$$AssertEquals(tAnswer.%Get("status"), "canceled", "and the run reads canceled")
    Set tView = ..RunToEnd({"statement": "SELECT {[Measures].[Amount]} ON 0, [Place].[H1].[Category].Members ON 1 FROM [OcuPilotProbeVisits]"}, tOwner)
    Do $$$AssertEquals($Select($IsObject(tView): tView.%Get("status") _ " " _ tView.result.outcome _ " " _ tView.result.columns.%Get(0) _ " " _ tView.result.rows.%Size() _ " " _ tView.result.rows.%Get(0).label, 1: ""), "ended cells Amount 5 Category 1", "a plain query polls to its cells")
    Set tSuite = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tView = ..RunToEnd({"statement": (..#CROSSJOIN), "drill": {"row": 2, "column": 1}}, tSuite)
    Do $$$AssertEquals($Select($IsObject(tView): tView.%Get("status") _ " " _ tView.result.outcome _ " " _ tView.result.rows.%ToJSON(), 1: ""), "ended rows [[""2"",""0"",""2""],[""2"",""0"",""2""],[""2"",""0"",""2""],[""2"",""0"",""2""]]", "a cell's drill-through polls to that cell's listing")
    Set tView = ..RunToEnd({"statement": "DRILLTHROUGH SELECT FROM [OcuPilotProbeGrid]"}, tSuite)
    Do $$$AssertEquals($Select($IsObject(tView): tView.%Get("status") _ " " _ tView.result.outcome _ " " _ tView.result.rows.%Size() _ " " _ tView.result.truncated, 1: ""), "ended rows 1000 1", "and a typed DRILLTHROUGH to its first 1,000 rows, the cut said")
}

/// <p>AC5, AC7: every refusal answers by its code before anything is prepared or spawned: a bad body, CREATE and DROP, three axes, a
/// namespace without analytics and one with a read-only cache; a statement the vendor will not prepare is answered with the vendor's text.
/// No answer reserves a run.</p>
/// <p>Mutation (Rule 19): accept a <code>confirmed</code> of any value in <method>OcuPilot.Area.Analytics.MdxQuery.Body</method> -- the
/// <code>confirmed: false</code> leg goes red.</p>
Method TestEveryRefusalIsAnsweredByItsCodeAndNothingIsSpawned()
{
    Set tOwner = ..#OWNER
    Set tTooLong = $Translate($Justify("", 100001), " ", "x")
    For tBody = {"statement": ""}, {"statement": "   "}, {"statement": (tTooLong)}, {"statement": 5}, {"statement": "SELECT 1", "extra": true}, {"statement": "SELECT 1", "drill": {"row": 0, "column": 1}}, {"statement": "SELECT 1", "drill": {"row": 1}}, {"statement": "SELECT 1", "drill": {"row": 1.5, "column": 1}}, {"statement": "SELECT 1", "drill": {"row": 1001, "column": 1}}, {"statement": "SELECT 1", "drill": {"row": 1, "column": 101}}, {"statement": "SELECT 1", "drill": {"row": 1, "column": 1, "x": 1}}, {"statement": "SELECT 1", "drill": 3}, {"statement": "SELECT 1", "confirmed": false}, {"statement": "SELECT 1", "confirmed": "true"}, {"statement": "SELECT 1", "confirmed": 1} {
        Do ..Send("POST", ..#START, tOwner, .tStatus, .tAnswer, .tType, tBody)
        Do $$$AssertEquals(..Code(tStatus, tAnswer), "400 ANALYTICS.MDX.INPUT", "bad input is refused: " _ $Extract(tBody.%ToJSON(), 1, 100))
    }
    Do ..Send("POST", ..#START, tOwner, .tStatus, .tAnswer, .tType, "not json")
    Do $$$AssertEquals(..Code(tStatus, tAnswer), "400 ANALYTICS.MDX.INPUT", "so is a body that is not JSON")
    For tCase = $ListBuild("CREATE MEMBER [OcuPilotProbeVisits].[Measures].[X] AS '1'", "422 ANALYTICS.MDX.KIND"), $ListBuild("DROP MEMBER [OcuPilotProbeVisits].[Measures].[X]", "422 ANALYTICS.MDX.KIND"), $ListBuild("SELECT {[Measures].[Amount]} ON 0, [Place].[H1].[Category].Members ON 1, [Seen].[H1].[Year].Members ON 2 FROM [OcuPilotProbeVisits]", "422 ANALYTICS.MDX.AXES") {
        Do ..Send("POST", ..#START, tOwner, .tStatus, .tAnswer, .tType, {"statement": ($List(tCase, 1))})
        Do $$$AssertEquals(..Code(tStatus, tAnswer), $List(tCase, 2), $Extract($List(tCase, 1), 1, 40) _ " is refused")
    }
    Do ..Send("POST", ..#START, tOwner, .tStatus, .tAnswer, .tType, {"statement": "SELEKT FROM [OcuPilotProbeVisits]"})
    Do $$$AssertTrue((tStatus = 200) && (tAnswer.outcome = "error") && (tAnswer.message [ "Unknown term at start of query: SELEKT"), "a syntax error is answered with the vendor's text, with no confirmation: " _ ..Line(tStatus, tAnswer))
    Do ..Send("POST", ..#START, tOwner, .tStatus, .tAnswer, .tType, {"statement": "SELECT FROM [OcuPilotProbeVisits]"}, "HSCUSTOM")
    Do $$$AssertEquals(..Code(tStatus, tAnswer), "409 ANALYTICS.NAMESPACE", "a namespace without analytics is refused before any vendor call")
    Do ..Send("POST", ..#START, ##class(OcuPilot.Test.Http).GetTestUsername(), .tStatus, .tAnswer, .tType, {"statement": "SELECT FROM [OcuPilotProbeVisits]"}, "HSLIB")
    Do $$$AssertEquals(..Code(tStatus, tAnswer), "409 ANALYTICS.MDX.READONLY", "and one whose cache database is read-only")
    Do $$$AssertEquals(..Rows(tOwner) _ " " _ ..Rows(##class(OcuPilot.Test.Http).GetTestUsername()), "0 0", "no answer reserved a run")
}

/// <p>AC10: text that runs server-side code or SQL is answered <code>confirm</code> and nothing runs until the body carries
/// <code>confirmed: true</code>. A <code>%SEARCH</code> whose braces increment node 1 is answered with the consequence, reserves no run
/// and leaves the node undefined; confirmed it answers 202, ends, and the node is defined. The comment-split <code>%SE/**/ARCH</code>
/// (node 3) asks the same way; the <code>%PARM</code> text (node 4) asks first and, confirmed, answers the vendor's prepare error with
/// its node still undefined.</p>
/// <p>Mutation (Rule 19): skip the confirmation check in <method>OcuPilot.Area.Analytics.MdxQuery.Check</method> -- the first start answers
/// 202 and the node is defined before any confirmation.</p>
Method TestTextThatRunsCodeOrSqlAsksBeforeItRuns()
{
    Set tOwner = ..#OWNER
    Set tConsequence = $Parameter("OcuPilot.Port.AnalyticsPort", "MDXCONSEQUENCE")
    Kill ^|"USER"|OcuPilotProbeMdxSplice
    Do ..Send("POST", ..#START, tOwner, .tStatus, .tAnswer, .tType, {"statement": (..Splice(1))})
    Do $$$AssertEquals(..Line(tStatus, tAnswer), "200 {""outcome"":""confirm"",""constructs"":[""%SEARCH""],""consequence"":""" _ tConsequence _ """}", "a %SEARCH is answered confirm, naming it and the consequence")
    Do $$$AssertEquals(..Rows(tOwner) _ " " _ ..NodeDefined(1), "0 0", "no run is reserved and the node is undefined")
    Set tView = ..RunToEnd({"statement": (..Splice(1)), "confirmed": true}, tOwner)
    Do $$$AssertEquals($Select($IsObject(tView): tView.%Get("status"), 1: ""), "ended", "confirmed, it runs to its end: " _ ..Line(0, tView))
    Do $$$AssertEquals(..NodeDefined(1), 1, "and its braces ran: the node is defined")
    Do $ClassMethod(..#STORE, "GuardedForgetUser", tOwner)
    Set tSplit = $Replace(..Splice(3), "%SEARCH", "%SE/**/ARCH")
    Do ..Send("POST", ..#START, tOwner, .tStatus, .tAnswer, .tType, {"statement": (tSplit)})
    Do $$$AssertEquals(..Code(tStatus, tAnswer) _ " " _ tAnswer.%Get("outcome") _ " " _ tAnswer.constructs.%ToJSON() _ " " _ ..NodeDefined(3), "200  confirm [""%SEARCH""] 0", "the comment-split spelling asks first too, its node undefined")
    Set tView = ..RunToEnd({"statement": (tSplit), "confirmed": true}, tOwner)
    Do $$$AssertEquals($Select($IsObject(tView): tView.%Get("status"), 1: "") _ " " _ ..NodeDefined(3), "ended 1", "and runs once confirmed")
    Do $ClassMethod(..#STORE, "GuardedForgetUser", tOwner)
    Set tParm = "WITH %PARM P AS 'VALUE:{$Increment(^OcuPilotProbeMdxSplice(4))}' SELECT {[Measures].[Amount]} ON 0 FROM [OcuPilotProbeGrid]"
    Do ..Send("POST", ..#START, tOwner, .tStatus, .tAnswer, .tType, {"statement": (tParm)})
    Do $$$AssertEquals(tStatus _ " " _ tAnswer.%Get("outcome") _ " " _ tAnswer.constructs.%ToJSON(), "200 confirm [""%PARM""]", "the %PARM text asks first")
    Do ..Send("POST", ..#START, tOwner, .tStatus, .tAnswer, .tType, {"statement": (tParm), "confirmed": true})
    Do $$$AssertEquals(tStatus _ " " _ tAnswer.%Get("outcome") _ " " _ ..NodeDefined(4), "200 error 0", "confirmed, it answers the vendor's prepare error and its node stays undefined: " _ ..Line(tStatus, tAnswer))
    Do $$$AssertEquals(..Rows(tOwner), 0, "and spawned nothing")
}

/// <p>AC10: a statement the detector cannot read is asked the same way, with no constructs named; confirmed, it answers the vendor's own
/// error and spawns nothing. A syntax error that tokenizes answers the vendor's error with no confirmation, and a plain SELECT with
/// <code>confirmed: true</code> runs as it would without it.</p>
/// <p>Mutation (Rule 19): answer 0 from <method>OcuPilot.Port.AnalyticsPort.MdxConstructs</method> when a tokenize fails -- the
/// unterminated-bracket leg answers the vendor's error instead of <code>confirm</code> and goes red.</p>
Method TestAStatementTheDetectorCannotReadAsksAndAPlainOneRunsWithAConfirmation()
{
    Set tOwner = ..#OWNER
    Do ..Send("POST", ..#START, tOwner, .tStatus, .tAnswer, .tType, {"statement": "SELECT FROM [OcuPilotProbeVisits"})
    Do $$$AssertEquals(..Line(tStatus, tAnswer), "200 {""outcome"":""confirm"",""constructs"":[],""consequence"":""" _ $Parameter("OcuPilot.Port.AnalyticsPort", "MDXCONSEQUENCE") _ """}", "an unterminated bracket asks first, naming no construct")
    Do ..Send("POST", ..#START, tOwner, .tStatus, .tAnswer, .tType, {"statement": "SELECT FROM [OcuPilotProbeVisits", "confirmed": true})
    Do $$$AssertTrue((tStatus = 200) && (tAnswer.%Get("outcome") = "error") && (tAnswer.%Get("message") [ "Unexpected end of statement"), "confirmed, it answers the vendor's error: " _ ..Line(tStatus, tAnswer))
    Do $$$AssertEquals(..Rows(tOwner), 0, "and spawns nothing")
    Set tPlain = {"statement": "SELECT {[Measures].[Amount]} ON 0 FROM [OcuPilotProbeGrid]", "confirmed": true}
    Set tView = ..RunToEnd(tPlain, tOwner)
    Do $$$AssertEquals($Select($IsObject(tView): tView.%Get("status") _ " " _ tView.result.outcome, 1: ""), "ended cells", "a plain SELECT with confirmed: true runs as it would without it")
}

/// <p>AC6: another user's poll and cancel of a run, an unknown id and a malformed one each answer the same 404 <code>ANALYTICS.MDX.NOTFOUND</code>,
/// and the owner's run is unaffected; a principal without <code>%Development:USE</code> is refused all three routes naming it.</p>
/// <p>Mutation (Rule 19): drop the owner from <method>OcuPilot.Kernel.State.SqlRun.IdForOwner</method>'s statement -- the other user's poll
/// is answered 200 and this goes red.</p>
Method TestAnotherUsersRunAnswersTheSameNotFoundAndTheGateRefusesBeforeAnything()
{
    Set tOwner = ..#OWNER
    Set tOther = ..#OTHER
    Do ..Send("POST", ..#START, tOwner, .tStatus, .tAnswer, .tType, {"statement": (..#SLOW)})
    Set tKey = $Select($IsObject(tAnswer): tAnswer.%Get("id"), 1: "")
    Do $$$AssertEquals(tStatus, 202, "the owner's run starts")
    Do ..Send("GET", ..Path(..#POLL, ..#ABSENTID), tOther, .tStatus, .tUnknown, .tType)
    Do $$$AssertEquals(..Code(tStatus, tUnknown), "404 ANALYTICS.MDX.NOTFOUND", "an unknown id is 404 ANALYTICS.MDX.NOTFOUND")
    For tCase = $ListBuild("GET", ..Path(..#POLL, tKey)), $ListBuild("POST", ..Path(..#CANCEL, tKey)), $ListBuild("GET", ..Path(..#POLL, "nothex")), $ListBuild("POST", ..Path(..#CANCEL, "NOTHEX")) {
        Do ..Send($List(tCase, 1), $List(tCase, 2), tOther, .tStatus, .tAnswer, .tType)
        Do $$$AssertEquals(..Line(tStatus, tAnswer), ..Line(404, tUnknown), "another user's " _ $List(tCase, 1) _ " " _ $List(tCase, 2) _ " answers the unknown id's 404")
    }
    Do ..Send("GET", ..Path(..#POLL, tKey), tOwner, .tStatus, .tAnswer, .tType)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tStatus _ " " _ tAnswer.%Get("status") _ " " _ tAnswer.%Get("cancelRequested"), 1: ""), "200 running 0", "the owner's run is unaffected")
    For tCase = $ListBuild("POST", ..#START, {"statement": "SELECT 1"}), $ListBuild("GET", ..Path(..#POLL, ..#ABSENTID), ""), $ListBuild("POST", ..Path(..#CANCEL, ..#ABSENTID), "") {
        Do ..Send($List(tCase, 1), $List(tCase, 2), ..#NODEV, .tStatus, .tAnswer, .tType, $List(tCase, 3))
        Do $$$AssertEquals(..Code(tStatus, tAnswer) _ " " _ $Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("detail")): tAnswer.detail.%Get("failedPair"), 1: ""), "403 AUTH.NOPRIVILEGE %Development:USE", $List(tCase, 1) _ " " _ $List(tCase, 2) _ " without %Development:USE")
    }
}

/// <p>AC6: an owner whose MDX run is live is refused a second start 409 <code>ANALYTICS.MDX.BUSY</code>, <code>detail.runId</code> naming the
/// run, and nothing else is reserved. Another kind is not blocked: the same owner's SQL background start is answered 202.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.State.SqlRun.GuardedReserve</method>'s busy check ignore the kind -- the SQL start is
/// refused busy and this goes red.</p>
Method TestAnOwnersSecondStartIsBusyAndAnMdxRunDoesNotBlockItsSqlRun()
{
    Set tOwner = ..#OWNER
    Do ..Send("POST", ..#START, tOwner, .tStatus, .tAnswer, .tType, {"statement": (..#SLOW)})
    Set tKey = $Select($IsObject(tAnswer): tAnswer.%Get("id"), 1: "")
    Do $$$AssertEquals(tStatus, 202, "the owner's run starts")
    Do ..Send("POST", ..#START, tOwner, .tStatus, .tAnswer, .tType, {"statement": (..#SLOW)})
    Do $$$AssertEquals(..Code(tStatus, tAnswer) _ " " _ $Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("detail")): tAnswer.detail.%Get("runId"), 1: ""), "409 ANALYTICS.MDX.BUSY " _ tKey, "a second start is refused busy, naming the running run")
    Do $$$AssertEquals(..Rows(tOwner), 1, "and reserved nothing")
    Do ..Send("POST", ..#SQLSTART, tOwner, .tStatus, .tAnswer, .tType, {"statement": "SELECT 1 AS One"})
    Do $$$AssertEquals(tStatus, 202, "the same owner's SQL background start is not blocked: " _ ..Line(tStatus, tAnswer))
    Set tSqlKey = $Select($IsObject(tAnswer): tAnswer.%Get("id"), 1: "")
    Do $$$AssertEquals(..Rows(tOwner), 2, "both runs are the owner's")
    Do ..Send("GET", ..Path(..#POLL, tSqlKey), tOwner, .tStatus, .tAnswer, .tType)
    Do $$$AssertEquals(..Code(tStatus, tAnswer), "404 ANALYTICS.MDX.NOTFOUND", "and an MDX poll of the SQL run's id is not found: the kinds are apart")
}

/// <p>AC6: the instance's five-run cap counts both kinds: with five live runs of mixed kinds, another start of either kind is refused 503
/// (<code>ANALYTICS.MDX.FULL</code> and <code>EXPLORER.SQL.BACKGROUND.FULL</code>) and reserves nothing.</p>
/// <p>Mutation (Rule 19): count only the requested kind's live rows against the cap in
/// <method>OcuPilot.Kernel.State.SqlRun.GuardedReserve</method> -- the MDX leg is answered 202 and goes red.</p>
Method TestTheInstanceCapCountsBothKinds()
{
    Set tOwner = ..#OWNER
    Set tKinds = $ListBuild("sql", "sql", "sql", "mdx", "mdx")
    For tI = 1:1:5 {
        Set tSC = $ClassMethod(..#STORE, "GuardedReserve", "OcuP2033Fill" _ tI, "USER", 1000, ..#LIMITS, .tKey, .tBusy, .tFull, .tSweep, $List(tKinds, tI))
        Do $$$AssertStatusOK(tSC, "fill run " _ tI _ " is reserved")
    }
    Do ..Send("POST", ..#START, tOwner, .tStatus, .tAnswer, .tType, {"statement": "SELECT {[Measures].[Amount]} ON 0 FROM [OcuPilotProbeGrid]"})
    Do $$$AssertEquals(..Code(tStatus, tAnswer), "503 ANALYTICS.MDX.FULL", "a sixth start is refused at the cap")
    Do ..Send("POST", ..#SQLSTART, tOwner, .tStatus, .tAnswer, .tType, {"statement": "SELECT 1 AS One"})
    Do $$$AssertEquals(..Code(tStatus, tAnswer), "503 EXPLORER.SQL.BACKGROUND.FULL", "whichever kind it is")
    Do $$$AssertEquals(..Rows(tOwner), 0, "and neither reserved a run")
}

}
