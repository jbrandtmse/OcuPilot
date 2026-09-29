/// <p>The agent audit viewer's search over HTTP (Story 16.16, AD-8, AD-21, AD-46), driven by real
/// principals: an ordinary user, and an administrator holding <code>OcuPilotAdmin:USE</code> and
/// <code>%Admin_Secure:USE</code> but not <code>%Admin_Manage:USE</code>. It pins
/// <code>GET /agent/ledger</code>'s every-user read, its per-row gate over the real
/// <code>$System.Security.Check</code>, its refusal of another user's rows to a non-administrator,
/// and the refusal of each malformed criterion by name.</p>
/// <p><b>It creates IRIS users and roles, so <method>OnBeforeAllTests</method> refuses to run unless
/// <parameter>ARMINGVARIABLE</parameter> reads 1.</b> Rows are written in process under the
/// principals' names and a third name no account holds, on a route no other test uses, and every
/// one is deleted after each method.</p>
Class OcuPilot.Test.LedgerSearchWire Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.TurnWireFixture";

Parameter APIBASE = "/api/ocupilot";

Parameter LEDGERROUTE = "/agent/ledger";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter STORE = "OcuPilot.Kernel.State.Ledger";

/// <p>The user whose rows are read across users; no account holds the name (AD-37).</p>
Parameter SUBJECT = "OcuPilotProbeLedgerSearchWireU2";

/// <p>The pair the administrator holds, and the one it does not.</p>
Parameter HELDPAIR = "%Admin_Secure:USE";

Parameter UNHELDPAIR = "%Admin_Manage:USE";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LedgerSearchWire creates IRIS users and roles, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Set ..PreparedPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", ..Ordinary(), ..PreparedPassword, $ClassMethod(..#FIXTURE, "Resources"))
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", ..Administrator(), ..PreparedPassword, $ClassMethod(..#FIXTURE, "Resources"), "OcuPilotAdmin:U," _ $Piece(..#HELDPAIR, ":", 1) _ ":U")
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 Quit $$$OK
    Do ..ClearRows()
    Set tLeft = ##class(OcuPilot.Test.TurnWireFixture).RemovePrincipals()
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LedgerSearchWire teardown left:" _ tLeft)
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..ClearRows()
    Quit $$$OK
}

ClassMethod Ordinary() As %String
{
    Quit $Parameter(..#FIXTURE, "USERA")
}

ClassMethod Administrator() As %String
{
    Quit $Parameter(..#FIXTURE, "USERB")
}

ClassMethod ClearRows()
{
    For tUser = ..Ordinary(), ..Administrator(), ..#SUBJECT {
        Do $ClassMethod(..#STORE, "GuardedDeleteForUser", tUser)
    }
}

ClassMethod ProbeRoute() As %String
{
    Quit "probe-ledger-search-wire/" _ $ZConvert($Translate($System.Util.CreateGUID(), "-", ""), "L")
}

/// <p>Record one tool row for <var>pUser</var> on <var>pRoute</var> requiring <var>pPair</var>,
/// under a turn key of its own, and answer that key.</p>
ClassMethod Seed(pUser As %String, pRoute As %String, pPair As %String) As %String
{
    Set tKey = "ocupilotprobeledgersearchwire" _ $ZConvert($Translate($System.Util.CreateGUID(), "-", ""), "L")
    Do ##class(OcuPilot.Kernel.Audit.Ledger).RecordToolCall(tKey, pUser, pRoute, "probe.ledger.read", "", {}, $ListBuild($ListBuild($Piece(pPair, ":", 1), $Piece(pPair, ":", 2))), "", "", "ok", "", ..#LIMITS, 1, "checked")
    Quit tKey
}

Method CallAs(pUser As %String, pQuery As %String, Output pStatus As %Integer, Output pAnswer As %DynamicObject, Output pText As %String) As %Status
{
    Set pAnswer = ""
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", ..#APIBASE _ ..#LEDGERROUTE _ "?" _ pQuery, pUser, ..PreparedPassword, .pStatus, .pText, .tHeaders)
    Try {
        Set pAnswer = ##class(%DynamicObject).%FromJSON(pText)
    } Catch {
        Set pAnswer = ""
    }
    Quit tSC
}

/// <p>The turn keys <var>pAnswer</var>'s rows carry, sorted and comma-joined.</p>
ClassMethod Keys(pAnswer As %DynamicObject) As %String
{
    Quit ##class(OcuPilot.Test.LedgerSearch).Keys(pAnswer)
}

/// <p>AC2 -- an ordinary user asking for every user is answered their own rows, not refused, and
/// naming another user is refused 403 naming <code>OcuPilotAdmin:USE</code>, with no rows.</p>
/// <p>Mutation (Rule 19): skip the privilege check in the every-user branch of
/// <method>OcuPilot.Kernel.Audit.Ledger.ViewForUser</method> -- the read becomes an every-user read
/// and this goes red.</p>
Method TestAnOrdinaryUserReadsTheirOwnRowsAndIsRefusedAnothers()
{
    Set tRoute = ..ProbeRoute()
    Set tMine = ..Seed(..Ordinary(), tRoute, ..#UNHELDPAIR)
    Set tTheirs = ..Seed(..#SUBJECT, tRoute, ..#HELDPAIR)
    Do ..CallAs(..Ordinary(), "all=1&route=" _ tRoute, .tStatus, .tAnswer, .tText)
    Do $$$AssertEquals(tStatus, 200, "the every-user search answers 200: " _ $Extract(tText, 1, 300))
    If '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(..Keys(tAnswer), tMine, "with the caller's own row only")
    Do $$$AssertEquals(tAnswer.rowsWithheld _ "|" _ tAnswer.criteria.allUsers _ "|" _ tAnswer.criteria.user, "0|0|" _ ..Ordinary(), "withholding nothing and echoing a read of their own rows")

    Do ..CallAs(..Ordinary(), "user=" _ ..#SUBJECT, .tDenied, .tDeniedAnswer, .tDeniedText)
    Do $$$AssertEquals(tDenied, 403, "naming another user answers 403: " _ $Extract(tDeniedText, 1, 300))
    If '$IsObject(tDeniedAnswer) Quit
    Do $$$AssertEquals(tDeniedAnswer.code _ "|" _ tDeniedAnswer.detail.failedPair, "AUTH.NOPRIVILEGE|OcuPilotAdmin:USE", "naming the administrative pair")
    Do $$$AssertEquals(tDeniedAnswer.%IsDefined("rows"), 0, "with no rows")
    Do $$$AssertEquals(##class(OcuPilot.Test.LedgerSearch).TurnRowCount(tTheirs), 1, "the other user's row was seeded")
}

/// <p>AC3 -- over the real gate, an administrator's every-user read lists their own row whatever it
/// records, another user's row whose pair they hold, and withholds and counts the one whose pair
/// they lack; naming that user answers the same two rows the same way. Every row carries its local
/// <code>time</code>.</p>
/// <p>Mutation (Rule 19): in <method>OcuPilot.Kernel.Audit.Ledger.ViewForUser</method>, release
/// every row of an every-user read without <method>OcuPilot.Kernel.Audit.Ledger.ReleasesRow</method>
/// -- the unheld row is listed and this goes red.</p>
Method TestAnAdministratorReadsEveryUserThroughThePerRowGate()
{
    Set tRoute = ..ProbeRoute()
    Set tOwn = ..Seed(..Administrator(), tRoute, ..#UNHELDPAIR)
    Set tHeld = ..Seed(..#SUBJECT, tRoute, ..#HELDPAIR)
    Set tUnheld = ..Seed(..#SUBJECT, tRoute, ..#UNHELDPAIR)
    Set tOrdinary = ..Seed(..Ordinary(), tRoute, ..#HELDPAIR)
    Do ..CallAs(..Administrator(), "all=1&route=" _ tRoute, .tStatus, .tAnswer, .tText)
    Do $$$AssertEquals(tStatus, 200, "the every-user search answers 200: " _ $Extract(tText, 1, 300))
    If '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(..Keys(tAnswer), ##class(OcuPilot.Test.LedgerSearch).Sorted($ListBuild(tOwn, tHeld, tOrdinary)), "listing the administrator's own row and each row whose pair is held")
    Do $$$AssertEquals(tAnswer.rowsWithheld, 1, "withholding and counting the unheld one")
    Do $$$AssertEquals(tAnswer.criteria.allUsers _ "|" _ tAnswer.criteria.user _ "|" _ tAnswer.criteria.route, "1||" _ tRoute, "and echoing an every-user read on that screen")
    Set tIterator = tAnswer.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Do $$$AssertTrue($Match(tRow.time, "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$"), "each row's time is local: " _ tRow.time)
    }

    Do ..CallAs(..Administrator(), "user=" _ ..#SUBJECT _ "&route=" _ tRoute, .tNamed, .tNamedAnswer, .tNamedText)
    Do $$$AssertEquals(tNamed, 200, "naming the subject answers 200: " _ $Extract(tNamedText, 1, 300))
    If '$IsObject(tNamedAnswer) Quit
    Do $$$AssertEquals(..Keys(tNamedAnswer) _ "|" _ tNamedAnswer.rowsWithheld, tHeld _ "|1", "the held row listed and the unheld one withheld")
    Do $$$AssertEquals(##class(OcuPilot.Test.LedgerSearch).TurnRowCount(tUnheld), 1, "the unheld row was seeded")
}

/// <p>The Matrix's bad-criterion and old-begin rows -- each malformed criterion is refused 400
/// <code>LEDGER.CRITERION.INVALID</code> naming it in <code>detail.criterion</code>, and a begin
/// past the bounded window is refused <code>LEDGER.WINDOW.INVALID</code> with its bound.</p>
/// <p>Mutation (Rule 19): drop the route shape check from
/// <method>OcuPilot.Api.Ledger.Handle</method> -- <code>route=../x</code> answers 200 and this goes
/// red; drop its length bound -- a well-shaped 513-character route answers 200.</p>
Method TestEachMalformedCriterionIsRefusedByName()
{
    Set tOld = ##class(OcuPilot.Test.LedgerSearch).LocalHoursAgo(721)
    Set tBegin = ##class(OcuPilot.Test.LedgerSearch).LocalHoursAgo(2)
    Set tEnd = ##class(OcuPilot.Test.LedgerSearch).LocalHoursAgo(3)
    Set tCases = $ListBuild($ListBuild("route=../x", "route"), $ListBuild("route=Agent/Ledger", "route"), $ListBuild("route=" _ $Translate($Justify("", 513), " ", "a"), "route"), $ListBuild("all=2", "all"), $ListBuild("all=1&user=" _ ..#SUBJECT, "all"))
    Set tCases = tCases _ $ListBuild($ListBuild("begin=" _ $ZConvert("2026-02-30 00:00:00", "O", "URL"), "begin"), $ListBuild("begin=" _ $ZConvert(tBegin, "O", "URL") _ "&windowHours=5", "begin"))
    Set tCases = tCases _ $ListBuild($ListBuild("end=yesterday", "end"), $ListBuild("begin=" _ $ZConvert(tBegin, "O", "URL") _ "&end=" _ $ZConvert(tEnd, "O", "URL"), "end"))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Do ..CallAs(..Ordinary(), $List(tCase, 1), .tStatus, .tAnswer, .tText)
        Do $$$AssertEquals(tStatus, 400, $List(tCase, 1) _ " answers 400: " _ $Extract(tText, 1, 300))
        If '$IsObject(tAnswer) Continue
        Do $$$AssertEquals(tAnswer.code _ "|" _ tAnswer.detail.criterion, "LEDGER.CRITERION.INVALID|" _ $List(tCase, 2), $List(tCase, 1) _ " names the criterion")
        Do $$$AssertEquals(tText [ "}{", 0, "in one envelope")
    }
    Do ..CallAs(..Ordinary(), "begin=" _ $ZConvert(tOld, "O", "URL"), .tStatus, .tAnswer, .tText)
    Do $$$AssertEquals(tStatus, 400, "a begin more than 720 hours ago answers 400: " _ $Extract(tText, 1, 300))
    If '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.code, "LEDGER.WINDOW.INVALID", "on the window code")
    Do $$$AssertTrue(tAnswer.reason [ "720", "with its bound: " _ tAnswer.reason)

    Do ..CallAs(..Ordinary(), "all=1&begin=" _ $ZConvert(tEnd, "O", "URL") _ "&end=" _ $ZConvert(tBegin, "O", "URL"), .tGood, .tGoodAnswer, .tGoodText)
    Do $$$AssertEquals(tGood, 200, "a well-formed search answers 200: " _ $Extract(tGoodText, 1, 300))
    If $IsObject(tGoodAnswer) Do $$$AssertEquals(tGoodAnswer.criteria.begin _ "|" _ tGoodAnswer.criteria.end, tEnd _ "|" _ tBegin, "echoing its begin and end")
}

}
