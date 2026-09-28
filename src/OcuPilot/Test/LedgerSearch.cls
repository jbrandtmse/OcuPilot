/// <p>The agent audit viewer's search over the ledger, in process (Story 16.16, AD-36, AD-41,
/// AD-46): the route, begin and end criteria and the applied <code>criteria</code> they echo, each
/// row's local <code>time</code> and <code>fields</code>, the local-to-UTC conversion, the
/// every-user read's release and its <code>*</code> audit event, a confirmed write's screen route,
/// a declared secret kept out of a tool row's target and arguments and a write row's fields, and
/// the <code>AgentLedger</code> descriptor's lack of a read.</p>
/// <p>The cross-user legs run through <class>OcuPilot.Test.LedgerGateProbe</class>, whose gate
/// holds only what a method grants. Every row names a user starting with
/// <parameter>PROBEPREFIX</parameter> or a turn this class seeded, and <method>OnAfterOneTest</method>
/// asserts none survives. It writes one agent-write audit marker and <code>LedgerRead</code>
/// events, and creates no principal.</p>
Class OcuPilot.Test.LedgerSearch Extends %UnitTest.TestCase
{

Parameter LEDGER = "OcuPilot.Kernel.Audit.Ledger";

Parameter PROBE = "OcuPilot.Test.LedgerGateProbe";

Parameter STORE = "OcuPilot.Kernel.State.Ledger";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter PROBEPREFIX = "OcuPilotProbeLedgerSearch";

/// <p>The two resources a row may record; the probe gate grants the first only when asked.</p>
Parameter HELDRESOURCE = "OcuPilotProbeLedgerHeld";

Parameter UNHELDRESOURCE = "OcuPilotProbeLedgerUnheld";

/// <p>The declared secret's value, which must reach no column and no view.</p>
Parameter SECRETVALUE = "OcuPilotProbeLedgerSecretV1";

/// <p>The write tool the confirmed-write leg confirms through the fixture port.</p>
Parameter TOOL = "webapp.list.update";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.WebAppList";

Parameter FIXTURETARGET = "/csp/ocupilotprobeledgersearch";

Parameter FIXTUREFRESH = "{""Name"":""/csp/ocupilotprobeledgersearch"",""Description"":""before"",""Enabled"":true}";

/// <p>The turns this method seeded through the proposal fixture, for their ledger rows.</p>
Property SeededTurns As %String [ MultiDimensional ];

Method OnBeforeOneTest() As %Status
{
    Do ..Clear()
    Kill ..SeededTurns
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..Clear()
    Set tKey = ""
    For {
        Set tKey = $Order(..SeededTurns(tKey))
        If tKey = "" Quit
        Do $ClassMethod(..#STORE, "GuardedDeleteForTurn", tKey)
        Do $$$AssertEquals(..TurnRowCount(tKey), 0, "no ledger row of seeded turn " _ tKey _ " survives")
    }
    Kill ..SeededTurns
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the seeded proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Do $$$AssertEquals(##class(OcuPilot.Test.Ledger).RowCountFor(..#PROBEPREFIX), 0, "no probe ledger row survives the method")
    Quit $$$OK
}

Method Clear()
{
    Do ##class(OcuPilot.Test.LedgerGate).Clear()
    For tSuffix = "A", "U1", "U2" {
        Do $ClassMethod(..#STORE, "GuardedDeleteForUser", ..#PROBEPREFIX _ tSuffix)
    }
}

ClassMethod User(pSuffix As %String) As %String
{
    Quit ..#PROBEPREFIX _ pSuffix
}

/// <p>A route no other test's row carries, in the shape the route takes.</p>
ClassMethod ProbeRoute() As %String
{
    Quit "probe-ledger-search/" _ $ZConvert($Translate($System.Util.CreateGUID(), "-", ""), "L")
}

ClassMethod NewTurnKey() As %String
{
    Quit "ocupilotprobeledgersearch" _ $ZConvert($Translate($System.Util.CreateGUID(), "-", ""), "L")
}

/// <p>Record one tool row for <var>pUser</var> on <var>pRoute</var>, requiring <var>pResource</var>
/// at USE, under a turn key of its own, and answer that key.</p>
ClassMethod Seed(pUser As %String, pRoute As %String, pResource As %String, pName As %String = "probe.ledger.read") As %String
{
    Set tKey = ..NewTurnKey()
    Do $ClassMethod(..#LEDGER, "RecordToolCall", tKey, pUser, pRoute, pName, "target-" _ pName, {}, $ListBuild($ListBuild(pResource, "USE")), "", "", "ok", "", ..#LIMITS, 1, "checked")
    Quit tKey
}

/// <p>Move turn <var>pKey</var>'s rows to <var>pHoursAgo</var> hours before now, by direct SQL.</p>
ClassMethod Age(pKey As %String, pHoursAgo As %Numeric) As %Integer
{
    Set tNow = $ZTimeStamp
    Set tSeconds = ((+$Piece(tNow, ",", 1)) * 86400) + ($Piece(tNow, ",", 2) \ 1) - (pHoursAgo * 3600)
    Set tIso = ##class(OcuPilot.Kernel.State.Turn).Timestamp((tSeconds \ 86400) _ "," _ (tSeconds # 86400))
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuPilot_Kernel_State.Ledger SET LoggedAt = ? WHERE %EXACT(TurnKey) = ?", tIso, pKey)
    If tRS.%SQLCODE < 0 Quit -1
    Quit +tRS.%ROWCOUNT
}

/// <p>The instance's local time <var>pHoursAgo</var> hours before now, as the viewer's form takes it.</p>
ClassMethod LocalHoursAgo(pHoursAgo As %Numeric) As %String
{
    Set tNow = $Horolog
    Set tSeconds = ((+$Piece(tNow, ",", 1)) * 86400) + ($Piece(tNow, ",", 2) \ 1) - (pHoursAgo * 3600)
    Quit $ZDateTime((tSeconds \ 86400) _ "," _ (tSeconds # 86400), 3, 1)
}

ClassMethod TurnRowCount(pKey As %String) As %Integer
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = ?", pKey)
    If (tRS.%SQLCODE < 0) || 'tRS.%Next() Quit -1
    Quit +tRS.%GetData(1)
}

/// <p>The turn keys <var>pView</var>'s rows carry, as a sorted comma-joined string.</p>
ClassMethod Keys(pView As %DynamicObject) As %String
{
    If '$IsObject(pView) Quit "(no view)"
    Kill tKeys
    Set tIterator = pView.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tKeys(tRow.turnKey) = ""
    }
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tKeys(tKey))
        If tKey = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tKey
    }
    Quit tOut
}

ClassMethod Sorted(pList As %List) As %String
{
    Kill tSeen
    For tI = 1:1:$ListLength(pList) {
        Set tSeen($List(pList, tI)) = ""
    }
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tSeen(tKey))
        If tKey = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tKey
    }
    Quit tOut
}

/// <p>AC1 -- a route criterion lists only that screen's rows, a begin and an end list only the
/// rows between them, no begin applies the default window, the view echoes what it applied in
/// local time, and each row carries its local <code>time</code>. The begin sits half an hour past
/// a whole hour, so a row between the window's whole-hour cutoff and the begin is listed only if
/// the begin predicate is missing, and the window reads a steady 40 hours.</p>
/// <p>Mutation (Rule 19): drop the route predicate from
/// <method>OcuPilot.Kernel.State.Ledger.WindowWhere</method> -- the other screen's row is listed
/// and this goes red; drop its begin predicate -- the row inside the cutoff's slack is listed.</p>
Method TestTheCriteriaSelectRowsAndEchoWhatTheyApplied()
{
    Set tUser = ..User("U1")
    Set tRoute = ..ProbeRoute()
    Set tOther = ..ProbeRoute()
    Set tRecent = ..Seed(tUser, tRoute, ..#HELDRESOURCE)
    Set tDayOld = ..Seed(tUser, tRoute, ..#HELDRESOURCE)
    Set tOlder = ..Seed(tUser, tRoute, ..#HELDRESOURCE)
    Set tSlack = ..Seed(tUser, tRoute, ..#HELDRESOURCE)
    Set tElsewhere = ..Seed(tUser, tOther, ..#HELDRESOURCE)
    Do $$$AssertEquals(..Age(tRecent, 2) _ "|" _ ..Age(tDayOld, 30) _ "|" _ ..Age(tOlder, 50) _ "|" _ ..Age(tSlack, 39.75), "1|1|1|1", "four rows are aged 2, 30, 50 and 39.75 hours")

    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", tUser, "", 0, "", 200, .tDefault, .tFault, 0, tRoute), "the default window reads")
    Do $$$AssertEquals(..Keys(tDefault), tRecent, "the default window lists the recent row on that screen and nothing else")
    Do $$$AssertEquals(tDefault.windowHours, 24, "over the default 24 hours")
    Do $$$AssertTrue($Match(tDefault.criteria.begin, "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$"), "the applied begin is echoed in local time: " _ tDefault.criteria.begin)
    Set tEchoUtc = $ClassMethod(..#LEDGER, "LocalToUtc", tDefault.criteria.begin)
    Set tEchoAgo = ##class(OcuPilot.Kernel.State.Turn).NowSeconds() - ##class(OcuPilot.Kernel.State.Turn).NowSeconds($ZDateTimeH($Translate($Extract(tEchoUtc, 1, 19), "T", " "), 3))
    Do $$$AssertTrue((tEchoAgo >= 86400) && (tEchoAgo < 86460), "and it is the window's own start, 24 hours before now: " _ tEchoAgo _ " s ago")
    Do $$$AssertEquals(tDefault.criteria.route _ "|" _ tDefault.criteria.end _ "|" _ tDefault.criteria.user _ "|" _ tDefault.criteria.allUsers, tRoute _ "||" _ tUser _ "|0", "with the route, no end, the user and no every-user read")
    If tDefault.rows.%Size() = 1 {
        Set tRow = tDefault.rows.%Get(0)
        Do $$$AssertTrue($Match(tRow.time, "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$"), "the row's time is local YYYY-MM-DD HH:MM:SS: " _ tRow.time)
        Do $$$AssertEquals(tRow.time, $ClassMethod(..#LEDGER, "LocalFromUtc", tRow.loggedAt), "and is its loggedAt, which stays ISO UTC, converted")
        Do $$$AssertEquals(tRow.%IsDefined("fields") && tRow.%IsDefined("fieldsTruncated"), 1, "and carries fields and fieldsTruncated")
    }

    Set tBegin = ..LocalHoursAgo(39.5)
    Set tEnd = ..LocalHoursAgo(10)
    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", tUser, "", 0, "", 200, .tBetween, .tFault, 0, tRoute, tBegin, tEnd), "a begin and an end read")
    Do $$$AssertEquals(..Keys(tBetween), tDayOld, "only the row between them is listed, not the one before the begin inside the window's whole-hour cutoff")
    Do $$$AssertEquals(tBetween.criteria.begin _ "|" _ tBetween.criteria.end, tBegin _ "|" _ tEnd, "and both are echoed as applied")
    Do $$$AssertEquals(tBetween.windowHours, 40, "over the hours since begin")

    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", tUser, "", 0, "", 200, .tWide, .tFault, 0, tRoute, ..LocalHoursAgo(60)), "a begin 60 hours ago reads")
    Do $$$AssertEquals(..Keys(tWide), ..Sorted($ListBuild(tRecent, tDayOld, tOlder, tSlack)), "every row on that screen since then, and none from another")

    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", tUser, "", 0, "", 200, .tAny, .tFault), "no route reads")
    Do $$$AssertTrue(..Keys(tAny) [ tElsewhere, "and lists the other screen's row too")

    Do $$$AssertStatusNotOK($ClassMethod(..#LEDGER, "ViewForUser", tUser, "", 0, "", 200, .tTooOld, .tFault, 0, tRoute, ..LocalHoursAgo(721)), "a begin more than 720 hours ago is refused")
    Do $$$AssertEquals($IsObject(tTooOld), 0, "with no view")
}

/// <p>A keyed read ignores all four criteria: the turn's rows are answered whatever route, begin,
/// end or every-user flag rides along.</p>
Method TestAKeyedReadIgnoresTheCriteria()
{
    Set tUser = ..User("U1")
    Set tKey = ..Seed(tUser, ..ProbeRoute(), ..#HELDRESOURCE)
    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", tUser, "", 0, tKey, 200, .tView, .tFault, 1, ..ProbeRoute(), ..LocalHoursAgo(5), ..LocalHoursAgo(4)), "a keyed read with criteria reads")
    Do $$$AssertEquals(..Keys(tView), tKey, "and answers the turn's row")
    Do $$$AssertEquals(tView.criteria.allUsers _ "|" _ tView.criteria.route _ "|" _ tView.criteria.begin, "0||", "applying none of the criteria")
}

/// <p>Conventions, Dates -- the local-to-UTC conversion round-trips, runs the right way against the
/// instance's own two clocks, and refuses a value that is not a calendar instant.</p>
/// <p>Mutation (Rule 19): drop the <parameter>OcuPilot.Screen.Read.DATETIMEFORM</parameter> match
/// from <method>OcuPilot.Kernel.Audit.Ledger.LocalToUtc</method> -- a bare date converts and this
/// goes red.</p>
Method TestTheLocalConversionRoundTripsAndRefusesANonInstant()
{
    Set tIso = ##class(OcuPilot.Kernel.State.Turn).Timestamp()
    Set tLocal = $ClassMethod(..#LEDGER, "LocalFromUtc", tIso)
    Do $$$AssertEquals($ClassMethod(..#LEDGER, "LocalToUtc", tLocal), tIso, "UTC to local and back is the same instant: " _ tIso _ " / " _ tLocal)
    Set tNowLocal = $ZDateTime($Horolog, 3, 1)
    Set tNowUtc = $ClassMethod(..#LEDGER, "LocalToUtc", tNowLocal)
    Set tDrift = ##class(OcuPilot.Kernel.State.Turn).NowSeconds() - ##class(OcuPilot.Kernel.State.Turn).NowSeconds($ZDateTimeH($Translate($Extract(tNowUtc, 1, 19), "T", " "), 3))
    Do $$$AssertTrue((tDrift >= 0) && (tDrift < 5), "the instance's local now converts to its UTC now: drift " _ tDrift _ " s")
    Do $$$AssertEquals($ClassMethod(..#LEDGER, "LocalToUtc", "2026-09-28 10:15:30.25"), $ClassMethod(..#LEDGER, "LocalToUtc", "2026-09-28 10:15:30"), "a fractional second is dropped")
    For tBad = "2026-02-30 00:00:00", "2026-09-28", "2026-09-28 25:00:00", "2026-09-28T10:00:00", "yesterday", "" {
        Do $$$AssertEquals($ClassMethod(..#LEDGER, "LocalToUtc", tBad), "", "'" _ tBad _ "' is refused")
    }
    Do $$$AssertEquals($ClassMethod(..#LEDGER, "WindowFromBegin", ##class(OcuPilot.Kernel.State.Turn).Timestamp(), .tHours), 1, "a begin of now is inside the bound")
    Do $$$AssertEquals(tHours, 1, "and reads over one hour")
}

/// <p>AC3 -- an administrator's every-user read releases their own rows whatever those record,
/// releases another user's row they hold the pair for, withholds and counts one they do not, and
/// records one <code>LedgerRead</code> event naming <code>*</code>; a named user reads as it always
/// has.</p>
/// <p>Mutation (Rule 19): in <method>OcuPilot.Kernel.Audit.Ledger.ViewForUser</method>, release
/// every row of an every-user read without <method>ReleasesRow</method> -- the unheld row is listed
/// and this goes red.</p>
Method TestAnEveryUserReadReleasesOwnRowsAndGatesTheRest()
{
    Set tRoute = ..ProbeRoute()
    Set tOwn = ..Seed(..User("A"), tRoute, ..#UNHELDRESOURCE)
    Set tHeld = ..Seed(..User("U2"), tRoute, ..#HELDRESOURCE)
    Set tUnheld = ..Seed(..User("U2"), tRoute, ..#UNHELDRESOURCE)
    Set tOther = ..Seed(..User("U1"), tRoute, ..#HELDRESOURCE)
    Do ##class(OcuPilot.Test.LedgerGate).Grant(..#HELDRESOURCE, "USE")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()

    ; The caller named in another case is still reading their own rows.
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "ViewForUser", $ZConvert(..User("A"), "L"), "", 0, "", 200, .tView, .tFault, 1, tRoute), "the every-user read runs")
    Do $$$AssertEquals($IsObject(tFault), 0, "with no fault")
    Do $$$AssertEquals(..Keys(tView), ..Sorted($ListBuild(tOwn, tHeld, tOther)), "listing the caller's own row, and each other user's row whose pair is held")
    Do $$$AssertEquals(tView.rowsWithheld, 1, "withholding and counting the one whose pair is not")
    Do $$$AssertEquals(tView.criteria.allUsers _ "|" _ tView.criteria.user, "1|", "and echoing an every-user read")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, $Parameter("OcuPilot.Kernel.Audit.Event", "EVENTLEDGERREAD"), """id"":""*""", .tData), 1, "one LedgerRead event names the subject *")

    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "ViewForUser", ..User("A"), ..User("U2"), 0, "", 200, .tNamed, .tNamedFault, 0, tRoute), "the administrator names U2")
    Do $$$AssertEquals(..Keys(tNamed) _ "|" _ tNamed.rowsWithheld, tHeld _ "|1", "the held row listed and the unheld one withheld, as before")
    Do $$$AssertEquals(tNamed.criteria.allUsers _ "|" _ tNamed.criteria.user, "0|" _ ..User("U2"), "echoing the named user")
    Do $$$AssertEquals(..TurnRowCount(tUnheld), 1, "the unheld row was seeded")
}

/// <p>AC2 -- a caller without the administrative pair who asks for every user is answered their own
/// rows and is not refused; naming another user is refused with the pair.</p>
/// <p>Mutation (Rule 19): skip the privilege check in the every-user branch of
/// <method>OcuPilot.Kernel.Audit.Ledger.ViewForUser</method> -- another user's row is listed and
/// this goes red.</p>
Method TestAnOrdinaryUserAskingForEveryUserReadsTheirOwnRows()
{
    Set tRoute = ..ProbeRoute()
    Set tMine = ..Seed(..User("U1"), tRoute, ..#UNHELDRESOURCE)
    Set tTheirs = ..Seed(..User("U2"), tRoute, ..#HELDRESOURCE)
    Do ##class(OcuPilot.Test.LedgerGate).Grant(..#HELDRESOURCE, "USE")
    Do ##class(OcuPilot.Test.LedgerGate).DenyAdmin()

    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "ViewForUser", ..User("U1"), "", 0, "", 200, .tView, .tFault, 1, tRoute), "the every-user read runs")
    Do $$$AssertEquals($IsObject(tFault), 0, "and is not refused")
    Do $$$AssertEquals(..Keys(tView), tMine, "answering the caller's own row only")
    Do $$$AssertEquals(tView.criteria.allUsers _ "|" _ tView.criteria.user, "0|" _ ..User("U1"), "and echoing a read of their own rows")

    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "ViewForUser", ..User("U1"), ..User("U2"), 0, "", 200, .tNamed, .tNamedFault, 0, tRoute), "naming another user runs")
    Do $$$AssertTrue($IsObject(tNamedFault), "and is refused")
    If $IsObject(tNamedFault) Do $$$AssertEquals(tNamedFault.code _ "|" _ tNamedFault.detail.failedPair, ##class(OcuPilot.Api.Error).#AUTHNOPRIVILEGE _ "|" _ $ClassMethod(..#LEDGER, "AdminPair"), "with the no-privilege code naming the pair")
    Do $$$AssertEquals(..TurnRowCount(tTheirs), 1, "the other user's row was seeded")
}

/// <p>AC1b -- a proposal minted in a turn begun on a screen and then confirmed writes a ledger row
/// recording that screen, so a search by it lists the write. Confirmed through
/// <class>OcuPilot.Test.ConfirmFixture</class>, whose port is the fixture.</p>
/// <p>Mutation (Rule 19): pass <code>""</code> for the route in
/// <method>OcuPilot.Kernel.Proposal.Confirm.Transition</method>'s
/// <method>OcuPilot.Kernel.Audit.Ledger.OpenConfirmedWrite</method> call -- no row is listed and
/// this goes red.</p>
Method TestAConfirmedWriteRecordsTheScreenItsTurnRanFrom()
{
    Set tRoute = ..ProbeRoute()
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FIXTUREFRESH)
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a turn is seeded")
    If $$$ISERR(tSC) Quit
    Set ..SeededTurns(tTurnKey) = ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuPilot_Kernel_State.Turn SET ContextRoute = ? WHERE %EXACT(TurnKey) = ?", tRoute, tTurnKey)
    Do $$$AssertEquals(tRS.%ROWCOUNT, 1, "begun on the probe screen")

    Set tArgs = {"Description": "after"}
    Do tArgs.%Set("Name", ..#FIXTURETARGET, "string")
    Set tSC = ##class(OcuPilot.Test.ProposalMint).Mint(..#SCREEN, ..#TOOL, $Username, "", tTurnKey, tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, "WebApp.App", "name", ..#FIXTURETARGET, "Name", ##class(OcuPilot.Screen.Tool.WebAppUpdate).SettableFields())
    Do $$$AssertStatusOK(tSC, "a proposal is minted in that turn")
    If '$IsObject($Get(tProposal)) Quit
    Set tSC = ##class(OcuPilot.Test.ConfirmFixture).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "and confirmed: " _ $Get(tCode))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 1, "the fixture port took the write")

    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", $Username, "", 0, "", 200, .tView, .tViewFault, 0, tRoute), "the ledger filtered to that screen reads")
    Do $$$AssertEquals(tView.rows.%Size(), 1, "and lists the confirmed write: " _ tView.%ToJSON())
    If tView.rows.%Size() '= 1 Quit
    Set tRow = tView.rows.%Get(0)
    Do $$$AssertEquals(tRow.kind _ "|" _ tRow.name _ "|" _ tRow.route _ "|" _ tRow.turnKey, "write|" _ ..#TOOL _ "|" _ tRoute _ "|" _ tTurnKey, "the write row of that turn, recording the screen")
    Do $$$AssertTrue(tRow.fields [ "Description", "carrying the field names it sent: " _ tRow.fields)
}

/// <p>AC4 -- a tool call carrying a declared secret value, also sent as its id, stores the mark in
/// both its target and its arguments; a confirmed write's field names exclude the declared name;
/// and the value is nowhere in any column or in the view. The declaration is
/// <code>permissions.users.password</code>'s own, read through the registry.</p>
/// <p>Mutation (Rule 19): remove the target check from
/// <method>OcuPilot.Kernel.Audit.Ledger.RecordToolCall</method> -- the value reaches the target and
/// this goes red; compare with <code>=</code> instead of <code>[</code> in
/// <method>OcuPilot.Kernel.Audit.Ledger.CarriesSecretValue</method> -- the longer id keeps it.</p>
Method TestADeclaredSecretReachesNoTargetNoArgumentsAndNoFields()
{
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("permissions.users.password", .tTool)
    Do $$$AssertStatusOK(tSC, "the password tool resolves")
    If '$IsObject($Get(tTool)) Quit
    Set tSecrets = ##class(OcuPilot.Screen.Tool.Registry).SecretArguments(tTool, .tDeclared)
    Do $$$AssertTrue($ListFind(tSecrets, "Password") > 0, "and declares Password secret: " _ $ListToString(tSecrets))

    Set tUser = ..User("U1")
    Set tRoute = ..ProbeRoute()
    Set tKey = ..NewTurnKey()
    Set tInput = {}
    Do tInput.%Set("id", ..#SECRETVALUE, "string")
    Do tInput.%Set("Password", ..#SECRETVALUE, "string")
    Set tTarget = ##class(OcuPilot.Kernel.Agent.Dispatch).TargetOf(tInput)
    Do $$$AssertEquals(tTarget, ..#SECRETVALUE, "the dispatcher would record the id as the target")
    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "RecordToolCall", tKey, tUser, tRoute, "permissions.users.password", tTarget, tInput, $ListBuild($ListBuild("%Admin_Secure", "USE")), "", tSecrets, "error", "ADMIN.NOTFOUND", ..#LIMITS, 1, "checked"), "the tool row is recorded")

    Set tWriteKey = ..NewTurnKey()
    Set tBody = {"Name": "probe"}
    Do tBody.%Set("Password", ..#SECRETVALUE, "string")
    Set tFields = ##class(OcuPilot.Test.MarkerConfirm).FieldNamesFor(tBody, tSecrets)
    Do $ClassMethod(..#LEDGER, "OpenConfirmedWrite", tWriteKey, tUser, "permissions.users.update", "user" _ $Char(2) _ "instance" _ $Char(2) _ "probe", ..#LIMITS, .tLedgerKey, $ListBuild($ListBuild("%Admin_Secure", "USE")), tRoute)
    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "FinalizeConfirmedWrite", tLedgerKey, "ok", "", "user" _ $Char(2) _ "instance" _ $Char(2) _ "probe", tFields, $ListBuild($ListBuild("%Admin_Secure", "USE")), "marked"), "a secret-bearing write is finalized")

    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", tUser, "", 0, "", 200, .tView, .tFault, 0, tRoute), "the view reads")
    Do $$$AssertEquals(tView.rows.%Size(), 2, "both rows are listed")
    Set tMark = ##class(OcuPilot.Kernel.Audit.Log).#REDACTED
    Set tIterator = tView.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.kind = "tool" {
            Do $$$AssertEquals(tRow.target, tMark, "the tool row's target is the mark")
            Do $$$AssertEquals(tRow.arguments, tMark, "and so are its arguments, withheld whole")
        } Else {
            Do $$$AssertEquals(tRow.fields, "Name", "the write row's fields name no declared secret: " _ tRow.fields)
        }
    }
    Do $$$AssertEquals(tView.%ToJSON() [ ..#SECRETVALUE, 0, "the value is nowhere in the view")
    Do $$$AssertEquals(##class(OcuPilot.Test.Ledger).RowText(tKey) [ ..#SECRETVALUE, 0, "nor in any column of the tool row")
    Do $$$AssertEquals(##class(OcuPilot.Test.Ledger).RowText(tWriteKey) [ ..#SECRETVALUE, 0, "nor of the write row")

    ; A target that carries no declared value is stored as sent, so the column still names the
    ; account the call was about.
    Set tPlainRoute = ..ProbeRoute()
    Set tPlain = {}
    Do tPlain.%Set("id", "ocupilotprobeaccount", "string")
    Do tPlain.%Set("Password", ..#SECRETVALUE, "string")
    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "RecordToolCall", ..NewTurnKey(), tUser, tPlainRoute, "permissions.users.password", "ocupilotprobeaccount", tPlain, $ListBuild($ListBuild("%Admin_Secure", "USE")), "", tSecrets, "error", "ADMIN.NOTFOUND", ..#LIMITS, 1, "checked"), "a call about another account is recorded")
    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", tUser, "", 0, "", 200, .tPlainView, .tFault, 0, tPlainRoute), "and reads")
    Do $$$AssertEquals(tPlainView.rows.%Size(), 1, "as one row")
    If tPlainView.rows.%Size() = 1 Do $$$AssertEquals(tPlainView.rows.%Get(0).target, "ocupilotprobeaccount", "whose target is the account, not the mark")

    ; A target holding the value inside a longer id, and one holding a declared value sent as a
    ; number, both store the mark.
    Set tMoreRoute = ..ProbeRoute()
    Set tInside = {}
    Do tInside.%Set("id", "account/" _ ..#SECRETVALUE, "string")
    Do tInside.%Set("Password", ..#SECRETVALUE, "string")
    Set tNumber = {}
    Do tNumber.%Set("id", "8675309", "string")
    Do tNumber.%Set("Password", 8675309, "number")
    For tMore = tInside, tNumber {
        Set tMoreTarget = ##class(OcuPilot.Kernel.Agent.Dispatch).TargetOf(tMore)
        Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "RecordToolCall", ..NewTurnKey(), tUser, tMoreRoute, "permissions.users.password", tMoreTarget, tMore, $ListBuild($ListBuild("%Admin_Secure", "USE")), "", tSecrets, "error", "ADMIN.NOTFOUND", ..#LIMITS, 1, "checked"), "a call whose target is " _ tMoreTarget _ " is recorded")
    }
    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", tUser, "", 0, "", 200, .tMoreView, .tFault, 0, tMoreRoute), "and reads")
    Do $$$AssertEquals(tMoreView.rows.%Size(), 2, "as two rows")
    Set tIterator = tMoreView.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Do $$$AssertEquals(tRow.target, tMark, "each target is the mark: " _ tRow.target)
    }
}

/// <p>The wire row's <code>fieldsTruncated</code>: a confirmed write whose field names run past
/// <parameter>OcuPilot.Kernel.State.Ledger.FIELDSMAXLENGTH</parameter> reads 1, and one within it
/// reads 0 with its names whole.</p>
/// <p>Mutation (Rule 19): set <code>fieldsTruncated</code> to a constant false in
/// <method>OcuPilot.Kernel.Audit.Ledger.RowObject</method> -- this goes red.</p>
Method TestAWriteRowSaysWhenItsFieldListWasCut()
{
    Set tUser = ..User("U1")
    Set tRoute = ..ProbeRoute()
    Set tRef = "user" _ $Char(2) _ "instance" _ $Char(2) _ "probe"
    Set tPairs = $ListBuild($ListBuild("%Admin_Secure", "USE"))
    Set tNames = ""
    For tI = 1:1:40 {
        Set tNames = tNames _ $ListBuild("OcuPilotProbeLedgerField" _ tI)
    }
    Set tLong = ..NewTurnKey()
    Do $ClassMethod(..#LEDGER, "OpenConfirmedWrite", tLong, tUser, "permissions.users.update", tRef, ..#LIMITS, .tLongKey, tPairs, tRoute)
    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "FinalizeConfirmedWrite", tLongKey, "ok", "", tRef, tNames, tPairs, "marked"), "a write sending forty field names is finalized")
    Set tShort = ..NewTurnKey()
    Do $ClassMethod(..#LEDGER, "OpenConfirmedWrite", tShort, tUser, "permissions.users.update", tRef, ..#LIMITS, .tShortKey, tPairs, tRoute)
    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "FinalizeConfirmedWrite", tShortKey, "ok", "", tRef, $ListBuild("Name"), tPairs, "marked"), "and one sending one")

    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", tUser, "", 0, "", 200, .tView, .tFault, 0, tRoute), "the view reads")
    Do $$$AssertEquals(tView.rows.%Size(), 2, "listing both writes")
    Set tIterator = tView.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.turnKey = tLong {
            Do $$$AssertEquals(tRow.fieldsTruncated, 1, "the long list reads cut, " _ $Length(tRow.fields) _ " characters kept")
        } Else {
            Do $$$AssertEquals(tRow.fieldsTruncated _ "|" _ tRow.fields, "0|Name", "the short one reads whole")
        }
    }
}

/// <p>The Matrix's overflow row under the criteria -- <code>rowsDropped</code> sums the overflow
/// rows the same selection lists: a route read counts that screen's alone, and an every-user read
/// counts every user's on it.</p>
/// <p>Mutation (Rule 19): pass <method>OcuPilot.Kernel.State.Ledger.GuardedDroppedFor</method> only
/// its four leading arguments in <method>OcuPilot.Kernel.Audit.Ledger.ViewForUser</method> -- the
/// route read counts the other screen's call and the every-user read only the caller's own, and
/// this goes red.</p>
Method TestTheDroppedCountFollowsTheCriteria()
{
    Set tRoute = ..ProbeRoute()
    Set tOther = ..ProbeRoute()
    Set tStore = ..#STORE
    Set tSC = $ClassMethod(tStore, "GuardedCountOverflow", ..NewTurnKey(), ..User("U1"), tRoute, .tCount)
    Set tKey = ..NewTurnKey()
    If $$$ISOK(tSC) Set tSC = $ClassMethod(tStore, "GuardedCountOverflow", tKey, ..User("U1"), tRoute, .tCount)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(tStore, "GuardedCountOverflow", tKey, ..User("U1"), tRoute, .tCount)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(tStore, "GuardedCountOverflow", ..NewTurnKey(), ..User("U1"), tOther, .tCount)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(tStore, "GuardedCountOverflow", ..NewTurnKey(), ..User("U2"), tRoute, .tCount)
    Do $$$AssertStatusOK(tSC, "U1 drops three calls on the screen and one elsewhere, U2 one on the screen")

    Do $$$AssertStatusOK($ClassMethod(..#LEDGER, "ViewForUser", ..User("U1"), "", 0, "", 200, .tOwn, .tFault, 0, tRoute), "U1's read of the screen runs")
    Do $$$AssertEquals(tOwn.rowsDropped, 3, "counting U1's drops on that screen only")

    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "ViewForUser", ..User("A"), "", 0, "", 200, .tEvery, .tFault, 1, tRoute), "an administrator's every-user read of the screen runs")
    Do $$$AssertEquals(tEvery.criteria.allUsers, 1, "as an every-user read")
    Do $$$AssertEquals(tEvery.rowsDropped, 4, "counting every user's drops on that screen")
}

/// <p>AC5 -- the Agent audit ledger declares no read and no table, so no read tool reads the
/// ledger, and its context declares no field, so no ledger row enters screen context. It is built,
/// listed fifth in the Agent co-pilot area, open to every user, and keyed by
/// <code>ledgerId</code>.</p>
/// <p>Mutation (Rule 19): give <class>OcuPilot.Screen.Descriptor.AgentLedger</class> a
/// <code>read</code> -- the declaration assertion goes red, and so does
/// <class>OcuPilot.Test.ReadTool</class>'s roster.</p>
Method TestTheLedgerScreenDeclaresNoReadAndNoContextFields()
{
    Set tClass = "OcuPilot.Screen.Descriptor.AgentLedger"
    Set tSC = ##class(OcuPilot.Screen.Registry).Validate(.tProblem)
    Do $$$AssertStatusOK(tSC, "the registry validates")
    Do $$$AssertEquals(tProblem, "", "with no problem")
    Do $$$AssertStatusOK($ClassMethod(tClass, "DeclarationJson", .tDeclaration), "the descriptor declares")
    If '$IsObject(tDeclaration) Quit
    Do $$$AssertEquals(tDeclaration.%GetTypeOf("read") _ "|" _ tDeclaration.%GetTypeOf("table"), "unassigned|unassigned", "no read and no table")
    Do $$$AssertEquals(tDeclaration.context.fields.%Size() _ "|" _ tDeclaration.context.secretFields.%Size(), "0|0", "and no context field")
    Do $$$AssertEquals(tDeclaration.route _ "|" _ tDeclaration.sideBarPosition _ "|" _ tDeclaration.archetype _ "|" _ tDeclaration.built, "agent/ledger|5|list (server criteria)|1", "built at agent/ledger, fifth in the side bar, a server-criteria list")
    Do $$$AssertEquals(tDeclaration.privileges.%Size() _ "|" _ tDeclaration.id.kind _ "|" _ tDeclaration.id.parts.%Get(0), "0|composite|ledgerId", "open to every user and keyed by ledgerId")
    Do $$$AssertEquals($ClassMethod("OcuPilot.Screen.Descriptor.AgentTranscripts", "SideBarPosition"), 6, "with Transcripts after it")

    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tTools)
    Do $$$AssertStatusOK(tSC, "the tool registry lists")
    Set tFound = ""
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        If (tTool.descriptor = tClass) || ($Extract(tTool.name, 1, 13) = "agent.ledger.") Set tFound = tFound _ " " _ tTool.name
    }
    Do $$$AssertEquals(tFound, "", "and no tool reads the ledger")
}

}
