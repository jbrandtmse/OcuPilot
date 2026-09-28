/// <p>Story 16.9 -- the log hub's composed read (AD-36 as amended), over
/// <class>OcuPilot.Test.LogHubFixture</class>: the roster, a refused member read zero times, a
/// member 403 left out and a member 500 failing the read, the window, the two truncation rules and
/// the merged cut, <code>last</code>, the merge order, the audit and error projections under a fixed
/// clock offset, the audit member's begin criterion and its last-entry read, the production gate
/// and read seams, and a bad bound refused before any member is read. It seeds nothing; beyond
/// the compiled registry it reads messages.log and the audit database, and needs one audit event.</p>
Class OcuPilot.Test.LogHub Extends %UnitTest.TestCase
{

Parameter FIXTURE = "OcuPilot.Test.LogHubFixture";

Parameter HUB = "OcuPilot.Screen.Descriptor.LogHub";

Parameter ALERTS = "OcuPilot.Screen.Descriptor.LogAlertViewer";

Parameter MESSAGES = "OcuPilot.Screen.Descriptor.LogMessageViewer";

Parameter ERRORS = "OcuPilot.Screen.Descriptor.LogErrorList";

Parameter AUDIT = "OcuPilot.Screen.Descriptor.AuditList";

Parameter XDBC = "OcuPilot.Screen.Descriptor.LogXdbcViewer";

Parameter EVENTLOG = "OcuPilot.Screen.Descriptor.LogEventViewer";

/// <p>The window's bound every leg composes under.</p>
Parameter SINCE = "2026-09-27 10:00:00";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.LogHubFixture).Clear()
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Do ##class(OcuPilot.Test.LogHubFixture).Clear()
    Quit $$$OK
}

/// <p>A log member's row.</p>
ClassMethod Row(pTime As %String, pText As %String, pSeverity As %String = "0") As %DynamicObject
{
    Quit {"time": (pTime), "severity": (pSeverity), "text": (pText)}
}

/// <p>The fixture's composition of the logs area at <var>pMax</var> under <var>pSince</var>.</p>
ClassMethod Compose(pMax As %Integer, pSince As %String, Output pAnswer, Output pHttp, Output pFault) As %Status
{
    Quit $ClassMethod(..#FIXTURE, "Compose", pMax, pSince, .pAnswer, .pHttp, .pFault)
}

/// <p><var>pAnswer</var>'s summary for <var>pRoute</var>, or <code>""</code>.</p>
ClassMethod Source(pAnswer, pRoute As %String) As %DynamicObject
{
    Set tFound = ""
    If '$IsObject($Get(pAnswer)) Quit tFound
    Set tIterator = pAnswer.sources.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tSource) {
        If tSource.source = pRoute Set tFound = tSource
    }
    Quit tFound
}

/// <p>Each summary of <var>pAnswer</var> as <code>route=shown/requires/count/truncated</code>,
/// comma-separated in roster order.</p>
ClassMethod Summary(pAnswer) As %String
{
    Set tOut = ""
    If '$IsObject($Get(pAnswer)) Quit tOut
    Set tIterator = pAnswer.sources.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tSource) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ $Piece(tSource.source, "/", 2) _ "=" _ tSource.shown _ "/" _ tSource.requires _ "/" _ tSource.count _ "/" _ tSource.truncated
    }
    Quit tOut
}

/// <p><var>pAnswer</var>'s rows as <code>route:text</code>, <code>|</code>-separated.</p>
ClassMethod Texts(pAnswer) As %String
{
    Set tOut = ""
    If '$IsObject($Get(pAnswer)) Quit tOut
    Set tIterator = pAnswer.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: "|") _ tRow.source _ ":" _ tRow.text
    }
    Quit tOut
}

/// <p>The members are the ten listed Logs screens in side-bar order, the hub not among them, each
/// one this read can compose; and a timeline member that declares a timeline read itself is
/// refused, a lone one sound.</p>
/// <p>Mutation (Rule 19): drop the timeline exclusion from
/// <method>OcuPilot.Screen.Timeline.Members</method> -&gt; the hub joins its own roster and this
/// goes red.</p>
Method TestTheRosterIsTheTenListedLogsScreensInSideBarOrder()
{
    Set tSC = ##class(OcuPilot.Screen.Timeline).Members("logs", .tMembers)
    Do $$$AssertStatusOK(tSC, "the members list")
    Set tNames = ""
    For tI = 1:1:$ListLength(tMembers) {
        Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ $Piece($List(tMembers, tI), ".", $Length($List(tMembers, tI), "."))
        Do $$$AssertTrue(##class(OcuPilot.Screen.Timeline).MemberKind($List(tMembers, tI)) '= "", $List(tMembers, tI) _ " is a member this read can compose")
    }
    Do $$$AssertEquals(tNames, "LogAlertViewer,LogMessageViewer,LogErrorList,AuditList,LogSystemMonitorViewer,LogTaskErrorViewer,LogXdbcViewer,LogSqlDiagnosticsViewer,LogEventViewer,LogAnalyticsViewer", "the ten listed Logs screens, in side-bar order, the hub not its own member")

    Set tSC = $ClassMethod(..#HUB, "DeclarationJson", .tHub)
    Do $$$AssertStatusOK(tSC, "the hub's declaration parses")
    Set tSecond = ##class(%DynamicObject).%FromJSON(tHub.%ToJSON())
    Do tSecond.%Set("route", "logs/hub2")
    Do tSecond.%Set("sideBarPosition", 12, "number")
    Set tRoster = [{"descriptor": "Hub", "declaration": (tHub)}]
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).TimelineMemberProblem(tRoster), "", "a lone timeline is sound")
    Do tRoster.%Push({"descriptor": "Hub2", "declaration": (tSecond)})
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).TimelineMemberProblem(tRoster), "Hub: timeline member 'logs/hub2' declares a timeline read itself, and a timeline composes its members' own reads (AD-36)", "a second listed timeline is refused as the first one's member")
}

/// <p>AC5 -- a member refused at its own gate is read zero times, and its summary says so with the
/// pair it needs; every other member is read once, at the cap.</p>
/// <p>Mutation (Rule 19): read a member whose gate refused in
/// <method>OcuPilot.Screen.Timeline.Compose</method> -&gt; the zero-read assertion goes red.</p>
Method TestARefusedMemberIsReadZeroTimesAndNamedWithItsPair()
{
    Do ##class(OcuPilot.Test.LogHubFixture).Deny(..#EVENTLOG, "%Ens_EventLog:USE")
    Do ##class(OcuPilot.Test.LogHubFixture).Arm(..#EVENTLOG, [(..Row("2026-09-27T10:30:00.000", "never read", "2"))])
    Do ##class(OcuPilot.Test.LogHubFixture).Arm(..#ALERTS, [(..Row("2026-09-27T10:20:00.000", "an alert", "2"))])
    Set tSC = ..Compose(50, ..#SINCE, .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do $$$AssertEquals(tHttp, 200, "at 200")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogHubFixture).Reads(..#EVENTLOG), 0, "the refused member is read zero times")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogHubFixture).Reads(), 9, "every other member is read once")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogHubFixture).MaxFor(..#ALERTS), 50, "at the read's own cap")
    Set tEvent = ..Source(.tAnswer, "logs/eventlog")
    Do $$$AssertTrue($IsObject(tEvent), "the refused member keeps its summary")
    If $IsObject(tEvent) Do $$$AssertEquals(tEvent.shown _ "|" _ tEvent.requires _ "|" _ tEvent.count _ "|" _ tEvent.%GetTypeOf("last"), "0|%Ens_EventLog:USE|0|null", "not shown, naming its pair, with no rows and no last entry")
    Do $$$AssertEquals(..Texts(.tAnswer), "logs/alerts:an alert", "and none of its rows reach the timeline")
    Do $$$AssertEquals(tAnswer.sources.%Size(), 10, "one summary per member")
}

/// <p>A 403 from a member's own read is left out as a refusal is; any other member fault fails
/// the whole read with that member's envelope, never a partial answer.</p>
/// <p>Mutation (Rule 19): treat every member failure as a refusal -&gt; the 500 leg goes red.</p>
Method TestAMember403IsLeftOutAndA500FailsTheRead()
{
    Do ##class(OcuPilot.Test.LogHubFixture).Fault(..#AUDIT, 403, "AUTH.NOPRIVILEGE", "%Admin_Secure:USE")
    Do ##class(OcuPilot.Test.LogHubFixture).Arm(..#ALERTS, [(..Row("2026-09-27T10:20:00.000", "an alert", "2"))])
    Set tSC = ..Compose(50, ..#SINCE, .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a member 403 does not fail the read")
    Set tAudit = ..Source(.tAnswer, "logs/audit")
    Do $$$AssertTrue($IsObject(tAudit), "the refused member keeps its summary")
    If $IsObject(tAudit) Do $$$AssertEquals(tAudit.shown _ "|" _ tAudit.requires, "0|%Admin_Secure:USE", "the member is left out, naming the pair its read refused")

    Do ##class(OcuPilot.Test.LogHubFixture).Clear()
    Do ##class(OcuPilot.Test.LogHubFixture).Fault(..#XDBC, 500, "LOG.UNREADABLE")
    Do ##class(OcuPilot.Test.LogHubFixture).Arm(..#ALERTS, [(..Row("2026-09-27T10:20:00.000", "an alert", "2"))])
    Set tSC = ..Compose(50, ..#SINCE, .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a member 500 fails the read")
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.code, 1: ""), "500|LOG.UNREADABLE", "with that member's own status and code")
    Do $$$AssertEquals($Get(tAnswer), "", "and no partial answer")
}

/// <p>AC3 -- rows before the bound are dropped, a row at it is kept, a row with no time is left out,
/// and the count is the rows kept.</p>
/// <p>Mutation (Rule 19): skip the bound comparison in
/// <method>OcuPilot.Screen.Timeline.Compose</method> -&gt; the before-the-bound row stays and this
/// goes red.</p>
Method TestTheWindowDropsRowsBeforeTheBound()
{
    Do ##class(OcuPilot.Test.LogHubFixture).Arm(..#MESSAGES, [(..Row("2026-09-27T10:30:00.000", "after")), (..Row("2026-09-27T10:00:00.000", "at the bound")), (..Row("2026-09-27T09:59:59.999", "before")), (..Row("", "no time"))])
    Set tSC = ..Compose(50, ..#SINCE, .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do $$$AssertEquals(..Texts(.tAnswer), "logs/messages:after|logs/messages:at the bound", "only the rows at or after the bound, a row with no time left out")
    Set tMessages = ..Source(.tAnswer, "logs/messages")
    Do $$$AssertTrue($IsObject(tMessages), "messages.log keeps its summary")
    If $IsObject(tMessages) Do $$$AssertEquals(tMessages.count, 2, "and the count is the rows kept")
}

/// <p>AC5 -- a member cut while its oldest row is still inside the window is truncated; one cut
/// with its oldest row before the bound read the whole window and is not; the answer's flag is
/// their OR.</p>
/// <p>Mutation (Rule 19): ignore a member's own cut in
/// <method>OcuPilot.Screen.Timeline.Compose</method> -&gt; the inside-the-window leg goes red.</p>
Method TestTruncationInsideTheWindowAndOutsideIt()
{
    Do ##class(OcuPilot.Test.LogHubFixture).Arm(..#ALERTS, [(..Row("2026-09-27T10:30:00.000", "a1")), (..Row("2026-09-27T10:10:00.000", "a2"))], 1)
    Do ##class(OcuPilot.Test.LogHubFixture).Arm(..#MESSAGES, [(..Row("2026-09-27T10:20:00.000", "m1")), (..Row("2026-09-27T09:00:00.000", "m2"))], 1)
    Set tSC = ..Compose(50, ..#SINCE, .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do $$$AssertEquals($Piece(..Summary(.tAnswer), ",", 1, 2), "alerts=1//2/1,messages=1//1/0", "cut inside the window is truncated, cut outside it is not")
    Do $$$AssertEquals(tAnswer.truncated, 1, "and the answer is truncated")

    Do ##class(OcuPilot.Test.LogHubFixture).Clear()
    Do ##class(OcuPilot.Test.LogHubFixture).Arm(..#MESSAGES, [(..Row("2026-09-27T10:20:00.000", "m1")), (..Row("2026-09-27T09:00:00.000", "m2"))], 1)
    Set tSC = ..Compose(50, ..#SINCE, .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(tAnswer.truncated, 0, "a read cut only before the bound leaves the answer untruncated")
}

/// <p>The merged rows are cut to the cap, newest first, and every source that lost a row inside the
/// window is truncated.</p>
/// <p>Mutation (Rule 19): drop the merged cut's flag in
/// <method>OcuPilot.Screen.Timeline.Compose</method> -&gt; the messages summary goes red.</p>
Method TestTheMergedCutFlagsEverySourceThatLostARow()
{
    Do ##class(OcuPilot.Test.LogHubFixture).Arm(..#ALERTS, [(..Row("2026-09-27T10:50:00.000", "a1")), (..Row("2026-09-27T10:30:00.000", "a2"))])
    Do ##class(OcuPilot.Test.LogHubFixture).Arm(..#MESSAGES, [(..Row("2026-09-27T10:40:00.000", "m1")), (..Row("2026-09-27T10:20:00.000", "m2"))])
    Set tSC = ..Compose(3, ..#SINCE, .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do $$$AssertEquals(..Texts(.tAnswer), "logs/alerts:a1|logs/messages:m1|logs/alerts:a2", "the newest three")
    Do $$$AssertEquals($Piece(..Summary(.tAnswer), ",", 1, 2), "alerts=1//2/0,messages=1//1/1", "the source that lost a row is truncated, the other is not")
    Do $$$AssertEquals(tAnswer.truncated, 1, "and so is the answer")
}

/// <p>AC1 -- a source's last entry is its newest row whatever the window, its text cut at 1,000
/// characters ending U+2026; a source with no row has none.</p>
/// <p>Mutation (Rule 19): take <code>last</code> from the window's rows alone -&gt; the quiet
/// source's last entry goes red.</p>
Method TestLastIsTheNewestEntryWhateverTheWindow()
{
    Set tLong = ""
    For tI = 1:1:1500 Set tLong = tLong _ "a"
    Do ##class(OcuPilot.Test.LogHubFixture).Arm(..#ALERTS, [(..Row("2026-09-25T08:00:00.000", tLong, "2"))])
    Do ##class(OcuPilot.Test.LogHubFixture).Arm(..#MESSAGES, [(..Row("2026-09-27T09:00:00.000", "older")), (..Row("2026-09-27T11:00:00.000", "newest"))])
    Set tSC = ..Compose(50, ..#SINCE, .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Set tAlerts = ..Source(.tAnswer, "logs/alerts")
    Do $$$AssertTrue($IsObject(tAlerts) && $IsObject(tAlerts.last), "the quiet source carries a last entry")
    If $IsObject(tAlerts) && $IsObject(tAlerts.last) {
        Do $$$AssertEquals(tAlerts.count _ "|" _ tAlerts.last.time _ "|" _ tAlerts.last.source _ "|" _ tAlerts.last.severity, "0|2026-09-25T08:00:00.000|logs/alerts|2", "two days old, outside the window, with no row in the timeline")
        Do $$$AssertEquals($Length(tAlerts.last.text) _ "|" _ $Extract(tAlerts.last.text, *), "1000|" _ $Char(8230), "its text cut at 1,000 characters, the last U+2026")
    }
    Set tMessages = ..Source(.tAnswer, "logs/messages")
    Do $$$AssertTrue($IsObject(tMessages) && $IsObject(tMessages.last), "messages.log carries a last entry")
    If $IsObject(tMessages) && $IsObject(tMessages.last) Do $$$AssertEquals(tMessages.last.text, "newest", "the newest row, whatever order the member answered in")
    Set tXdbc = ..Source(.tAnswer, "logs/xdbc")
    Do $$$AssertTrue($IsObject(tXdbc), "the xDBC log keeps its summary")
    If $IsObject(tXdbc) Do $$$AssertEquals(tXdbc.%GetTypeOf("last"), "null", "a source with no rows has no last entry")
    Do $$$AssertEquals(..Texts(.tAnswer), "logs/messages:newest", "the timeline holds the one row inside the window")
}

/// <p>AC1 -- a member whose own read took the bound (the audit viewer's begin) and answered no row
/// is asked once for its newest row whatever the bound, so a quiet audit database still names its
/// last entry; a member with a row in the window, or one whose read takes no bound, is not asked.</p>
/// <p>Mutation (Rule 19): drop the last-entry read from
/// <method>OcuPilot.Screen.Timeline.Compose</method> -&gt; the audit last entry goes red.</p>
Method TestAQuietAuditDatabaseStillNamesItsLastEntry()
{
    Do ##class(OcuPilot.Test.LogHubFixture).Offset(0)
    Do ##class(OcuPilot.Test.LogHubFixture).ArmLast(..#AUDIT, {"UTCTimeStamp": "2026-09-25 08:00:00.000", "SystemID": "host:IRIS", "AuditIndex": 7, "EventSource": "%System", "EventType": "%Login", "Event": "Login", "Description": ""})
    Do ##class(OcuPilot.Test.LogHubFixture).ArmLast(..#MESSAGES, ..Row("2026-09-25T08:00:00.000", "never asked"))
    Set tSC = ..Compose(50, ..#SINCE, .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Set tAudit = ..Source(.tAnswer, "logs/audit")
    Do $$$AssertTrue($IsObject(tAudit) && $IsObject(tAudit.last), "the quiet audit database carries a last entry")
    If $IsObject(tAudit) && $IsObject(tAudit.last) Do $$$AssertEquals(tAudit.count _ "|" _ tAudit.last.time _ "|" _ tAudit.last.text, "0|2026-09-25T08:00:00.000|%System/%Login/Login", "count 0, and its newest event, two days before the window")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogHubFixture).LastReads(..#AUDIT) _ "|" _ ##class(OcuPilot.Test.LogHubFixture).LastReads(..#MESSAGES), "1|0", "asked once, and a member whose read takes no bound is not asked")
    Do $$$AssertEquals(..Texts(.tAnswer), "", "and nothing reaches the timeline")

    Do ##class(OcuPilot.Test.LogHubFixture).Clear()
    Do ##class(OcuPilot.Test.LogHubFixture).Arm(..#AUDIT, [{"UTCTimeStamp": "2026-09-27 10:15:00.000", "SystemID": "host:IRIS", "AuditIndex": 8, "EventSource": "%System", "EventType": "%Login", "Event": "Login", "Description": ""}])
    Set tSC = ..Compose(50, ..#SINCE, .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogHubFixture).LastReads(..#AUDIT), 0, "an audit read with a row in the window is not asked again")
}

/// <p>AC5 -- the production seams against this instance: a member's gate is its own screen's gate,
/// a name that is no screen refused; a member is read at the hub's cap, messages.log cut at two
/// lines; and the audit viewer's read takes the bound as its begin, so a bound at its newest event
/// answers that event and a bound in 2099 answers none, whichever side of the viewer's own
/// 24-hour default the newest event falls. Needs messages.log and one audit event.</p>
/// <p>Mutations (Rule 19): <method>OcuPilot.Screen.Timeline.GateMember</method> answers 1 -&gt; the
/// no-screen leg goes red; <method>OcuPilot.Screen.Timeline.ReadMember</method> reads at the
/// default cap -&gt; the messages leg goes red; it drops the criteria -&gt; one of the two audit
/// legs goes red.</p>
Method TestTheProductionSeamsGateAndReadAsEachScreenDoes()
{
    Set tSC = ##class(OcuPilot.Screen.Timeline).Members("logs", .tMembers)
    Do $$$AssertStatusOK(tSC, "the members list")
    For tI = 1:1:$ListLength(tMembers) {
        Set tMember = $List(tMembers, tI)
        Set tHub = ##class(OcuPilot.Screen.Timeline).GateMember(tMember, .tHubPair)
        Set tOwn = ##class(OcuPilot.Screen.Gate).Evaluate(tMember, .tOwnPair)
        Do $$$AssertEquals(tHub _ "|" _ tHubPair, tOwn _ "|" _ tOwnPair, tMember _ " is gated by its own screen's gate")
    }
    Do $$$AssertEquals(##class(OcuPilot.Screen.Timeline).GateMember("OcuPilot.Screen.Descriptor.NoSuchScreen", .tNone), 0, "a name that is no screen is refused")

    Set tSC = ##class(OcuPilot.Screen.Timeline).ReadMember(..#MESSAGES, "log", 2, "", .tRows, .tCut, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "messages.log reads")
    If $$$ISOK(tSC) Do $$$AssertEquals(tRows.%Size() _ "|" _ tCut, "2|1", "at the hub's cap of two, cut")

    Set tSC = ##class(OcuPilot.Screen.Timeline).LastMember(..#AUDIT, "audit", .tLast, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the audit database reads with the bound unset")
    Do $$$AssertTrue($IsObject(tLast) && (tLast.%Get("UTCTimeStamp") '= ""), "and answers its newest event")
    If $IsObject(tLast) && (tLast.%Get("UTCTimeStamp") '= "") {
        Set tAt = $Translate($Extract(##class(OcuPilot.Screen.Timeline).LocalTime(tLast.%Get("UTCTimeStamp")), 1, 19), "T", " ")
        Set tSC = ##class(OcuPilot.Screen.Timeline).ReadMember(..#AUDIT, "audit", 5, tAt, .tRows, .tCut, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, "the audit database reads from its newest event")
        If $$$ISOK(tSC) Do $$$AssertTrue(tRows.%Size() >= 1, "and answers it, the bound " _ tAt _ " being its begin")
    }
    Set tSC = ##class(OcuPilot.Screen.Timeline).ReadMember(..#AUDIT, "audit", 5, "2099-01-01 00:00:00", .tRows, .tCut, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the audit database reads from a bound in 2099")
    If $$$ISOK(tSC) Do $$$AssertEquals(tRows.%Size(), 0, "and answers no event")
}

/// <p>AC3 -- the merge is newest first, and equal times keep roster order, then each member's own
/// order.</p>
/// <p>Mutation (Rule 19): walk the merge ascending in
/// <method>OcuPilot.Screen.Timeline.Compose</method> -&gt; this goes red.</p>
Method TestTheMergeIsNewestFirstAndTiesKeepRosterOrder()
{
    Do ##class(OcuPilot.Test.LogHubFixture).Arm(..#ALERTS, [(..Row("2026-09-27T10:30:00.000", "a1")), (..Row("2026-09-27T10:30:00.000", "a2"))])
    Do ##class(OcuPilot.Test.LogHubFixture).Arm(..#MESSAGES, [(..Row("2026-09-27T10:45:00.000", "m0")), (..Row("2026-09-27T10:30:00.000", "m1"))])
    Set tSC = ..Compose(50, ..#SINCE, .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do $$$AssertEquals(..Texts(.tAnswer), "logs/messages:m0|logs/alerts:a1|logs/alerts:a2|logs/messages:m1", "newest first, ties in roster order then the member's own")
}

/// <p>AC4 -- an audit row's UTC stamp is converted to the instance's clock and merged on it, and its
/// text names its event, never its <code>EventData</code>; an application error keeps its time,
/// reads severity 2 and carries its composite id. The fixture's clock runs two hours ahead of UTC,
/// so the conversion shows on an instance kept in UTC: audit rows written at 10:14 and 10:15 UTC
/// merge above an error logged at 10:20 local.</p>
/// <p>Mutation (Rule 19): project the audit stamp without <method>OcuPilot.Screen.Timeline.LocalTime</method>
/// -&gt; the conversion and merge assertions go red.</p>
Method TestTheAuditAndErrorProjections()
{
    Do ##class(OcuPilot.Test.LogHubFixture).Offset(7200)
    Set tUtc = "2026-09-27 10:15:00.123"
    Do ##class(OcuPilot.Test.LogHubFixture).Arm(..#AUDIT, [{"UTCTimeStamp": (tUtc), "SystemID": "host:IRIS", "AuditIndex": 42, "EventSource": "%System", "EventType": "%Login", "Event": "Login", "Description": "User _SYSTEM", "EventData": "ocupilot-hub-eventdata"}, {"UTCTimeStamp": "2026-09-27 10:14:00.000", "SystemID": "host:IRIS", "AuditIndex": 41, "EventSource": "%System", "EventType": "%Login", "Event": "Logout", "Description": "", "EventData": ""}])
    Do ##class(OcuPilot.Test.LogHubFixture).Arm(..#ERRORS, [{"time": "2026-09-27T10:20:00.000", "severity": "2", "text": "[HSCUSTOM] <DIVIDE>x+1^y", "namespace": "HSCUSTOM", "date": "09/27/2026", "errorNumber": 3}])
    Set tSC = ..Compose(50, ..#SINCE, .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    If '$IsObject($Get(tAnswer)) Quit
    Do $$$AssertEquals(tAnswer.rows.%Size(), 3, "three rows")
    If tAnswer.rows.%Size() '= 3 Quit
    Set tAudit = tAnswer.rows.%Get(0)
    Do $$$AssertEquals(tAudit.%ToJSON(), {"time": "2026-09-27T12:15:00.123", "source": "logs/audit", "severity": "", "text": "%System/%Login/Login: User _SYSTEM", "id": (tUtc _ $Char(1) _ "host:IRIS" _ $Char(1) _ "42")}.%ToJSON(), "the audit row on the instance's clock, merged first, naming its event and description, with its UTC composite id")
    Do $$$AssertEquals(tAnswer.rows.%Get(1).time _ "|" _ tAnswer.rows.%Get(1).text, "2026-09-27T12:14:00.000|%System/%Login/Logout", "the older audit row next, an empty description adding nothing")
    Set tError = tAnswer.rows.%Get(2)
    Do $$$AssertEquals(tError.%ToJSON(), {"time": "2026-09-27T10:20:00.000", "source": "logs/errors", "severity": "2", "text": "[HSCUSTOM] <DIVIDE>x+1^y", "id": ("HSCUSTOM" _ $Char(1) _ "09/27/2026" _ $Char(1) _ "3")}.%ToJSON(), "the error keeps its local time, reads severity 2 and carries its composite id")
    Do $$$AssertEquals($Find(tAnswer.%ToJSON(), "ocupilot-hub-eventdata"), 0, "EventData is never projected")
}

/// <p>The audit viewer's own read is given the bound as its begin criterion, and a log viewer's
/// read, which declares no criterion, is given none.</p>
/// <p>Mutation (Rule 19): drop the begin criterion from
/// <method>OcuPilot.Screen.Timeline.MemberCriteria</method> -&gt; the audit assertion goes red.</p>
Method TestTheAuditMemberIsGivenTheBoundAsItsBegin()
{
    Do ##class(OcuPilot.Screen.Timeline).MemberCriteria(..#AUDIT, ..#SINCE, .tAudit)
    Do $$$AssertEquals($Get(tAudit("beginDateTime")) _ "|" _ $Order(tAudit("beginDateTime")) _ "|" _ $Order(tAudit("beginDateTime"), -1), ..#SINCE _ "||", "the audit viewer's read begins at the bound, and takes no other criterion")
    Do ##class(OcuPilot.Screen.Timeline).MemberCriteria(..#MESSAGES, ..#SINCE, .tLog)
    Do $$$AssertEquals($Data(tLog), 0, "a log viewer's read takes none")
}

/// <p>A bound the instance cannot read is refused 400 <code>READ.CRITERION</code> before any member
/// is gated or read; a sound one reaches every member, and the executor passes the composition's
/// rows, <code>criteria</code> and <code>sources</code> through.</p>
/// <p>Mutation (Rule 19): call the composition before seeding the criteria in
/// <method>OcuPilot.Screen.Read.Execute</method>'s timeline branch -&gt; the zero-read assertion
/// goes red.</p>
Method TestABadBoundIsRefusedBeforeAnyMemberIsRead()
{
    Kill tCriteria
    Set tCriteria("since") = "yesterday"
    Set tSC = ##class(OcuPilot.Test.LogHubReadFixture).Execute(..#HUB, 50, .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusNotOK(tSC, "the bound is refused")
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.code, 1: ""), "400|READ.CRITERION", "400 READ.CRITERION")
    Do $$$AssertTrue($Select($IsObject(tFault): tFault.reason, 1: "") [ "since", "naming since")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogHubFixture).Gates() + ##class(OcuPilot.Test.LogHubFixture).Reads(), 0, "before any member is gated or read")

    Do ##class(OcuPilot.Test.LogHubFixture).Arm(..#ALERTS, [(..Row("2026-09-27T10:20:00.000", "an alert", "2"))])
    Set tCriteria("since") = ..#SINCE
    Set tSC = ##class(OcuPilot.Test.LogHubReadFixture).Execute(..#HUB, 50, .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "a sound bound reads")
    If '$IsObject($Get(tResult)) Quit
    Do $$$AssertEquals(tResult.fields.%ToJSON() _ "|" _ tResult.criteria.since _ "|" _ tResult.sources.%Size() _ "|" _ tResult.rows.%Size(), "[""time"",""source"",""severity"",""text"",""id""]|" _ ..#SINCE _ "|10|1", "the declared fields, the applied bound, ten summaries and the one row")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogHubFixture).SinceFor(..#AUDIT), ..#SINCE, "every member is given the bound")

    Kill tCriteria
    Set tSC = ##class(OcuPilot.Test.LogHubReadFixture).Execute(..#HUB, 50, .tResult, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "an omitted bound reads")
    Do $$$AssertTrue($Match(tResult.criteria.since, "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$"), "taking its declared default, an hour back: " _ tResult.criteria.since)
    If $Match(tResult.criteria.since, "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$") {
        Set tBack = $ZDateTimeH(tResult.criteria.since, 3)
        Set tNow = $Horolog
        Set tGap = ((+tNow - +tBack) * 86400) + ($Piece(tNow, ",", 2) - $Piece(tBack, ",", 2))
        Do $$$AssertTrue((tGap >= 3590) && (tGap <= 3610), "which is an hour before the instance's now: " _ tGap _ " seconds")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.LogHubFixture).SinceFor(..#AUDIT), tResult.criteria.since, "which is what the members are given")
}

}
