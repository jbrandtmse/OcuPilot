/// <p>Pins Story 24.4's fourteen session and message tools as tools (AD-1, AD-8, AD-22, AD-24, AD-36, AD-62), over synthetic message
/// headers <class>OcuPilot.Test.InteropSessionRead</class> stores in the install namespace: each is listed once by the registry under
/// its canonical name with kind <code>read</code> and advertised under its wire name; a call through the dispatcher asks the governance
/// gate once, with kind <code>read</code>, before any pair check, and answers the port's rows; a missing pair is refused
/// <code>AUTH.NOPRIVILEGE</code> by name before the port is reached, the content pair on the detail and body reads in particular; an
/// argument the schema refuses is refused <code>TOOL.ARGUMENTS</code>; the cap reports <code>truncated</code>; and a body read records
/// one <code>ViewContents</code>.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropSessionRead</class> needs, and the vendor's audit event
/// <code>%Ensemble/%Message/ViewContents</code> enabled with auditing on (the throwaway's default). The headers and the one body it stores
/// are removed after each test.</p>
Class OcuPilot.Test.InteropSessionTools Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.InteropSessionProbe";

Parameter FIXTURE = "OcuPilot.Test.InteropSessionRead";

Parameter REGISTRY = "OcuPilot.Screen.Tool.Registry";

Parameter BASE = "OcuPilot.Screen.Tool.InteropInspect";

/// <p>The fourteen tools, comma-separated, as the registry names them.</p>
Parameter TOOLS = "interop.message.body,interop.message.detail,interop.session.headers,interop.session.summary,interop.session.timeline,interop.sessions.bybodyclass,interop.sessions.byclass,interop.sessions.byid,interop.sessions.bysource,interop.sessions.bystatus,interop.sessions.bysupersession,interop.sessions.bytarget,interop.sessions.bytime,interop.sessions.related";

/// <p>This test's marker, the ids of its five headers, the body it stores and the header that names it. The prefix must not begin with
/// "Test" (<file>.claude/rules/objectscript-testing.md</file>).</p>
Property PreparedMarker As %String;

Property PreparedIds As %List;

Property PreparedBodyId As %String;

Property PreparedBodyHeader As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedMarker = ""
    Set ..PreparedIds = ""
    Set ..PreparedBodyId = ""
    Set ..PreparedBodyHeader = ""
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PROBE, "Reset")
    Set ..PreparedMarker = $Parameter(..#FIXTURE, "PREFIX") _ "T" _ $Extract($Translate($System.Util.CreateGUID(), "-", ""), 1, 8)
    Set tSC = $ClassMethod(..#FIXTURE, "Plant", ..PreparedMarker, .tIds)
    Set ..PreparedIds = tIds
    If $$$ISERR(tSC) Quit tSC
    Set tBody = ##class(Ens.StringRequest).%New()
    Set tBody.StringValue = $Translate($Justify("", 400), " ", "x")
    Set tSC = tBody.%Save()
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedBodyId = tBody.%Id()
    Set tSC = ..StoreBodyHeader()
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#PROBE, "Reset")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Clear", ..PreparedMarker), 0, "no header of this test's marker is left")
    If ..PreparedBodyId '= "" Do ##class(Ens.StringRequest).%DeleteId(..PreparedBodyId)
    Quit $$$OK
}

/// <p>Store the header that names the body, sourced <code>&lt;m&gt;Body</code>, in its own session, and remember it.</p>
Method StoreBodyHeader() As %Status
{
    Set tId = $ClassMethod($Parameter(..#FIXTURE, "FIXTURE"), "StoreHeader", "", "Ens.StringRequest", ..PreparedBodyId, 1, 9, 20, "", "", 1, "", ..PreparedMarker _ "Body", ..PreparedMarker _ "Op")
    Set ..PreparedBodyHeader = tId
    Quit $Select(tId: $$$OK, 1: $$$ERROR($$$GeneralError, "the body header could not be stored"))
}

/// <p>The call <var>pWire</var> with <var>pInput</var> answered by the dispatcher, the block's <code>content</code> parsed as far as it
/// is JSON in <var>pContent</var> and its error flag in <var>pIsError</var>.</p>
Method Ask(pWire As %String, pInput As %DynamicObject, Output pContent, Output pIsError As %Boolean) As %String
{
    Set tSC = $ClassMethod(..#PROBE, "Ask", pWire, pInput, .tBlock)
    Do $$$AssertStatusOK(tSC, pWire _ ": the dispatcher answers")
    Set pIsError = +tBlock.%Get("is_error")
    Set pContent = ##class(%DynamicAbstractObject).%FromJSON(tBlock.%Get("content"))
    Quit tBlock.%Get("content")
}

/// <p>Fourteen tools are registered, once each under the canonical name, as kind <code>read</code> with a class of their own below the
/// shared base and no descriptor; each is advertised to the provider under its wire name with a description and a closed input schema.</p>
Method TestTheFourteenAreRegisteredAsReads()
{
    Do $$$AssertStatusOK($ClassMethod(..#REGISTRY, "ListTools", .tTools), "the tools list")
    If '$IsObject($Get(tTools)) Quit
    Kill tCounts
    Set tIterator = tTools.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTool) {
        Set tCounts(tTool.name) = $Get(tCounts(tTool.name)) + 1
    }
    Do $$$AssertStatusOK($ClassMethod(..#REGISTRY, "ProviderTools", .tAdvertised), "the provider list builds")
    Kill tWires
    For tI = 1:1:+$Get(tAdvertised) Set tWires(tAdvertised(tI, "name")) = tAdvertised(tI, "description")
    For tI = 1:1:$Length(..#TOOLS, ",") {
        Set tName = $Piece(..#TOOLS, ",", tI)
        Do $$$AssertEquals($Get(tCounts(tName)), 1, tName _ ": listed once")
        Do $$$AssertStatusOK($ClassMethod(..#REGISTRY, "Resolve", tName, .tTool), tName _ ": resolves")
        If '$IsObject($Get(tTool)) Continue
        Do $$$AssertEquals(tTool.kind _ "|" _ tTool.descriptor _ "|" _ tTool.fulfilment, "read||instance", tName _ ": a read with no descriptor, answered in process")
        Do $$$AssertTrue($ClassMethod(tTool.class, "%Extends", ..#BASE), tName _ ": extends the shared base: " _ tTool.class)
        Set tWire = $ClassMethod(..#REGISTRY, "WireName", tName)
        Do $$$AssertEquals($Translate(tName, ".", "_"), tWire, tName _ ": its wire name")
        Do $$$AssertTrue($Data(tWires(tWire)) && ($ZStrip(tWires(tWire), "<>W") '= ""), tName _ ": advertised under " _ tWire _ " with a description")
        Do $$$AssertStatusOK($ClassMethod(..#REGISTRY, "ResolveWire", tWire, .tViaWire), tName _ ": the wire name resolves")
        Do $$$AssertEquals($IsObject($Get(tViaWire)) && (tViaWire.name = tName), 1, tName _ ": to the same tool")
        Set tSchema = $ClassMethod(..#REGISTRY, "InputSchemaOf", tTool)
        Do $$$AssertEquals(tSchema.type _ "|" _ tSchema.additionalProperties, "object|0", tName _ ": a closed object schema")
    }
}

/// <p>The inputs that find this test's fixture, by tool: <code>tool|input JSON|text the answer holds</code>. The session ids are filled in
/// as <code>%S1</code>, <code>%S2</code> and <code>%B</code> (the header with a body), the marker as <code>%M</code>.</p>
ClassMethod Calls() As %List
{
    Quit $ListBuild(
        "interop.sessions.bytime|{""hours"":2,""maxRows"":500}|%M",
        "interop.sessions.bystatus|{""status"":[""Error""],""hours"":2,""maxRows"":500}|%S1",
        "interop.sessions.bysource|{""source"":""%MSvc"",""hours"":2}|%S1",
        "interop.sessions.bytarget|{""target"":""%MProc"",""hours"":2}|%S1",
        "interop.sessions.bybodyclass|{""bodyClass"":""Ens.StringRequest"",""hours"":2,""maxRows"":500}|%S1",
        "interop.sessions.byid|{""session"":""%S1""}|%S1",
        "interop.sessions.bysupersession|{""session"":""%S1""}|%S2",
        "interop.sessions.related|{""session"":""%S1""}|%S2",
        "interop.sessions.byclass|{""className"":""%MSvc"",""match"":""source""}|%S1",
        "interop.session.summary|{""session"":""%S1""}|""Messages"":2",
        "interop.session.timeline|{""session"":""%S1""}|""Step"":2",
        "interop.session.headers|{""session"":""%S1"",""errorsOnly"":true}|""Step"":1",
        "interop.message.detail|{""message"":""%B""}|""Name"":""Body""",
        "interop.message.body|{""message"":""%B""}|<StringRequest>")
}

/// <p>The fixture's text in <var>pText</var>: <code>%S1</code> to the first session, <code>%S2</code> to the second, <code>%B</code> to the
/// header with a body and <code>%M</code> to the marker.</p>
Method Filled(pText As %String) As %String
{
    Set tText = $Replace(pText, "%S1", $List(..PreparedIds, 1))
    Set tText = $Replace(tText, "%S2", $List(..PreparedIds, 3))
    Set tText = $Replace(tText, "%B", ..PreparedBodyHeader)
    Quit $Replace(tText, "%M", ..PreparedMarker)
}

/// <p>Each of the fourteen, called as a turn calls it, asks the governance gate exactly once, with its dotted name and kind
/// <code>read</code>, before any privilege pair, checks the pairs of its endpoints, and answers the port's rows: no error, the rows the
/// call's own criterion finds.</p>
Method TestEachToolAsksTheGateOnceThenReadsThePort()
{
    Set tCalls = ..Calls()
    Do $$$AssertEquals($ListLength(tCalls), $Length(..#TOOLS, ","), "a call is declared for each of the fourteen")
    For tI = 1:1:$ListLength(tCalls) {
        Set tEntry = $List(tCalls, tI)
        Set tName = $Piece(tEntry, "|", 1)
        Do $ClassMethod(..#PROBE, "Reset")
        Set tInput = ##class(%DynamicAbstractObject).%FromJSON(..Filled($Piece(tEntry, "|", 2)))
        Set tText = ..Ask($Translate(tName, ".", "_"), tInput, .tContent, .tIsError)
        Do $$$AssertEquals(tIsError, 0, tName _ ": answers, not an error: " _ $Extract(tText, 1, 200))
        Set tEvents = $ClassMethod(..#PROBE, "Events")
        Do $$$AssertEquals($Piece(tEvents, ",", 1), "gate:" _ tName _ ":read", tName _ ": the first thing asked is the gate, with kind read")
        Do $$$AssertEquals($Length(tEvents, "gate:") - 1, 1, tName _ ": the gate is asked once")
        Do $$$AssertTrue($Piece(tEvents, ",", 2) [ "pair:", tName _ ": the pairs are checked after it: " _ tEvents)
        Do $$$AssertTrue(tText [ ..Filled($Piece(tEntry, "|", 3)), tName _ ": the answer holds the port's rows: " _ $Extract(tText, 1, 300))
        Do $$$AssertEquals(tContent.%GetTypeOf("truncated") _ "|" _ tContent.%GetTypeOf("rowsSent"), "boolean|number", tName _ ": the result carries truncated and the dispatcher's counts")
    }
}

/// <p>A caller missing the viewer's pair is refused <code>AUTH.NOPRIVILEGE</code> naming it by every one of the fourteen, and the port is
/// not reached; one missing the content pair alone is refused by the detail and body reads naming that pair, while the twelve that need
/// no content pair answer. The refused body read records no view.</p>
Method TestAMissingPairIsRefusedByNameBeforeThePort()
{
    Set tCalls = ..Calls()
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tText = ..Ask("interop_message_body", {"message": (..PreparedBodyHeader)}, .tContent, .tIsError)
    Set tControl = ##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "ViewContents", "MessageHeaderId = " _ ..PreparedBodyHeader _ ",", .tData, "", "%Ensemble", "%Message")
    Do $$$AssertEquals(tIsError _ "|" _ tControl, "0|1", "control: a permitted body read records its view, so a count that does not move below means something")
    Do $ClassMethod(..#PROBE, "Deny", "%Ens_MessageHeader", "USE")
    For tI = 1:1:$ListLength(tCalls) {
        Set tName = $Piece($List(tCalls, tI), "|", 1)
        Set tInput = ##class(%DynamicAbstractObject).%FromJSON(..Filled($Piece($List(tCalls, tI), "|", 2)))
        Set tText = ..Ask($Translate(tName, ".", "_"), tInput, .tContent, .tIsError)
        Do $$$AssertEquals(tIsError _ "|" _ tText, "1|{""code"":""AUTH.NOPRIVILEGE"",""detail"":{""failedPair"":""%Ens_MessageHeader:USE""}}", tName _ ": refused, naming the viewer's pair")
    }
    Do $ClassMethod(..#PROBE, "Reset")
    Do $ClassMethod(..#PROBE, "Deny", "%Ens_MessageContent", "USE")
    For tI = 1:1:$ListLength(tCalls) {
        Set tName = $Piece($List(tCalls, tI), "|", 1)
        Set tInput = ##class(%DynamicAbstractObject).%FromJSON(..Filled($Piece($List(tCalls, tI), "|", 2)))
        Set tText = ..Ask($Translate(tName, ".", "_"), tInput, .tContent, .tIsError)
        If (tName = "interop.message.detail") || (tName = "interop.message.body") {
            Do $$$AssertEquals(tIsError _ "|" _ tText, "1|{""code"":""AUTH.NOPRIVILEGE"",""detail"":{""failedPair"":""%Ens_MessageContent:USE""}}", tName _ ": refused, naming the content pair")
        } Else {
            Do $$$AssertEquals(tIsError, 0, tName _ ": needs no content pair and answers")
        }
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "ViewContents", "MessageHeaderId = " _ ..PreparedBodyHeader _ ",", .tData, "", "%Ensemble", "%Message"), tControl, "the refused reads recorded no further view")
}

/// <p>An argument the schema refuses is refused <code>TOOL.ARGUMENTS</code> before the port: a window above the tool's maximum (721 hours,
/// and 169 for the class search), a missing required argument, an argument the tool does not declare, a status list of ten and a
/// <code>maxRows</code> above the tool's cap. A status word the schema cannot judge reaches the port and is refused
/// <code>PORT.VALIDATION</code>, as is a super-session read with neither key nor session.</p>
Method TestAnArgumentTheSchemaRefusesIsRefusedByName()
{
    For tCase = "interop_sessions_bytime|{""hours"":721}|hours", "interop_sessions_byclass|{""className"":""Ens.StringRequest"",""hours"":169}|hours", "interop_sessions_byid|{}|session", "interop_sessions_bytime|{""nope"":1}|nope", "interop_sessions_bystatus|{""status"":[""Error"",""Error"",""Error"",""Error"",""Error"",""Error"",""Error"",""Error"",""Error"",""Error""]}|status", "interop_sessions_bytime|{""maxRows"":501}|maxRows", "interop_sessions_byclass|{""className"":""Ens.StringRequest"",""maxRows"":101}|maxRows", "interop_session_summary|{""session"":""1"",""hours"":1}|hours" {
        Set tText = ..Ask($Piece(tCase, "|", 1), ##class(%DynamicAbstractObject).%FromJSON($Piece(tCase, "|", 2)), .tContent, .tIsError)
        Do $$$AssertEquals(tIsError _ "|" _ tContent.%Get("code"), "1|TOOL.ARGUMENTS", $Piece(tCase, "|", 1) _ " " _ $Piece(tCase, "|", 2) _ ": refused by the schema")
        Do $$$AssertTrue($IsObject(tContent.detail) && (tContent.detail.problem [ ("'" _ $Piece(tCase, "|", 3) _ "'")), $Piece(tCase, "|", 1) _ ": naming " _ $Piece(tCase, "|", 3) _ ": " _ tText)
    }
    Set tText = ..Ask("interop_sessions_bystatus", {"status": ["Nope"]}, .tContent, .tIsError)
    Do $$$AssertEquals(tIsError _ "|" _ tContent.%Get("code"), "1|PORT.VALIDATION", "a status word outside the nine reaches the port and is refused by it")
    Set tText = ..Ask("interop_sessions_bysupersession", {}, .tContent, .tIsError)
    Do $$$AssertEquals(tIsError _ "|" _ tContent.%Get("code"), "1|PORT.VALIDATION", "a super-session read with neither key nor session is refused by the port")
}

/// <p>Each argument a tool passes on beyond its first changes what the port reads: <code>errorsOnly</code> keeps the error header,
/// <code>beginDateTime</code> starts the timeline at the second header, <code>superSession</code> names the key without a seed session, a
/// status list of two finds both sessions, <code>match</code> <code>target</code> finds nothing for a name that is only a source, and
/// <code>hours</code> and <code>endDateTime</code> place the window.</p>
Method TestEachArgumentChangesWhatIsRead()
{
    Set tS1 = $List(..PreparedIds, 1)
    Set tS2 = $List(..PreparedIds, 3)
    Set tS3 = $List(..PreparedIds, 4)
    Set tFixture = $Parameter(..#FIXTURE, "FIXTURE")
    Set tSource = ..PreparedMarker _ "Svc"
    Set tText = ..Ask("interop_session_headers", {"session": (tS1)}, .tContent, .tIsError)
    Do $$$AssertEquals(tIsError _ "|" _ tContent.rows.%Size(), "0|2", "session.headers: both of the first session's headers")
    Set tText = ..Ask("interop_session_headers", {"session": (tS1), "errorsOnly": true}, .tContent, .tIsError)
    Do $$$AssertEquals(tIsError _ "|" _ tContent.rows.%Size() _ "|" _ tContent.rows.%Get(0).ID, "0|1|" _ $List(..PreparedIds, 2), "session.headers errorsOnly: the error header alone")
    Set tInput = {"session": (tS1)}
    Do tInput.%Set("beginDateTime", $ClassMethod(tFixture, "LocalSecond", $List(..PreparedIds, 2)), "string")
    Set tText = ..Ask("interop_session_timeline", tInput, .tContent, .tIsError)
    Do $$$AssertEquals(tIsError _ "|" _ tContent.rows.%Size() _ "|" _ tContent.rows.%Get(0).ID, "0|1|" _ $List(..PreparedIds, 2), "session.timeline beginDateTime: from the second header")
    Set tInput = {"superSession": (..PreparedMarker _ "K")}
    Set tText = ..Ask("interop_sessions_bysupersession", tInput, .tContent, .tIsError)
    Do $$$AssertEquals(tIsError _ "|" _ tContent.rows.%Size() _ "|" _ tContent.rows.%Get(0).SessionId _ "|" _ tContent.rows.%Get(1).SessionId, "0|2|" _ tS1 _ "|" _ tS2, "bysupersession superSession: the two sessions under the key, newest first")
    Set tText = ..Ask("interop_sessions_bystatus", {"status": ["Error", "Discarded"], "hours": 2, "maxRows": 500}, .tContent, .tIsError)
    Do $$$AssertTrue((tText [ ("""SessionId"":""" _ tS1 _ """")) && (tText [ ("""SessionId"":""" _ tS3 _ """")), "bystatus with two words: both the Error and the Discarded session: " _ $Extract(tText, 1, 300))
    Set tText = ..Ask("interop_sessions_byclass", {"className": (tSource), "match": "target"}, .tContent, .tIsError)
    Do $$$AssertEquals(tIsError _ "|" _ tContent.rows.%Size(), "0|0", "byclass match target: a name that is only a source finds nothing")
    Set tText = ..Ask("interop_sessions_bysource", {"source": (tSource), "hours": 2}, .tContent, .tIsError)
    Do $$$AssertEquals(tIsError _ "|" _ tContent.rows.%Size() _ "|" _ tContent.rows.%Get(0).SessionId, "0|1|" _ tS1, "bysource hours 2: the three-hour session is outside the window")
    Set tText = ..Ask("interop_sessions_bysource", {"source": (tSource)}, .tContent, .tIsError)
    Do $$$AssertEquals(tIsError _ "|" _ tContent.rows.%Size(), "0|2", "bysource with no hours: the default day holds both")
    Set tInput = {"source": (tSource), "hours": 1}
    Do tInput.%Set("endDateTime", $ClassMethod(tFixture, "LocalSecond", $List(..PreparedIds, 3)), "string")
    Set tText = ..Ask("interop_sessions_bysource", tInput, .tContent, .tIsError)
    Do $$$AssertEquals(tIsError _ "|" _ tContent.rows.%Size() _ "|" _ tContent.rows.%Get(0).SessionId, "0|1|" _ tS2, "bysource endDateTime: the window ends at the three-hour header")
}

/// <p>The cap reports itself: a search whose cap is one and that finds two sessions answers one row and <code>truncated</code> true, and
/// the same search with a cap of two answers both and <code>truncated</code> false; an absent session answers no rows and is no error.</p>
Method TestTheCapReportsTruncated()
{
    Set tInput = {"maxRows": 1}
    Do tInput.%Set("source", ..PreparedMarker _ "Svc")
    Do tInput.%Set("hours", 30, "number")
    Set tText = ..Ask("interop_sessions_bysource", tInput, .tContent, .tIsError)
    Do $$$AssertEquals(tIsError _ "|" _ tContent.rows.%Size() _ "|" _ tContent.truncated _ "|" _ tContent.rows.%Get(0).SessionId, "0|1|1|" _ $List(..PreparedIds, 1), "a cap of one answers the newest session and says it cut")
    Do tInput.%Set("maxRows", 2, "number")
    Set tText = ..Ask("interop_sessions_bysource", tInput, .tContent, .tIsError)
    Do $$$AssertEquals(tIsError _ "|" _ tContent.rows.%Size() _ "|" _ tContent.truncated, "0|2|0", "a cap of two answers both and cuts nothing")
    Set tText = ..Ask("interop_sessions_byid", {"session": "9223372036854775"}, .tContent, .tIsError)
    Do $$$AssertEquals(tIsError _ "|" _ tContent.rows.%Size() _ "|" _ tContent.truncated, "0|0|0", "an absent session answers no rows and is no error")
}

/// <p>A body read records one <code>%Ensemble/%Message/ViewContents</code> row for the header, and so does a detail read; a summary keeps the
/// first 256 characters of the text and says it cut; the detail's header rows come first, then the body's lines as <code>Body</code> rows
/// numbered after them, and its cap cuts the combined rows.</p>
Method TestABodyReadRecordsOneViewAndASummaryCuts()
{
    Set tHeader = ..PreparedBodyHeader
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tText = ..Ask("interop_message_body", {"message": (tHeader)}, .tContent, .tIsError)
    Do $$$AssertEquals(tIsError _ "|" _ tContent.rows.%Size() _ "|" _ tContent.truncated, "0|3|0", "the body is three lines of XML")
    Do $$$AssertEquals(tContent.rows.%Get(0).Text _ "|" _ tContent.rows.%Get(0).Line, "<StringRequest>|1", "the first line, numbered from 1")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "ViewContents", "MessageHeaderId = " _ tHeader _ ",", .tData, "", "%Ensemble", "%Message"), 1, "one view is recorded")
    Set tText = ..Ask("interop_message_body", {"message": (tHeader), "summary": true}, .tContent, .tIsError)
    Set tChars = 0
    Set tIterator = tContent.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tChars = tChars + $Length(tRow.Text)
    }
    Do $$$AssertEquals(tIsError _ "|" _ tChars _ "|" _ tContent.truncated, "0|256|1", "a summary keeps 256 characters and says it cut")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "ViewContents", "MessageHeaderId = " _ tHeader _ ",", .tData, "", "%Ensemble", "%Message"), 2, "and records its own view")
    Set tText = ..Ask("interop_message_detail", {"message": (tHeader), "maxRows": 100}, .tContent, .tIsError)
    Do $$$AssertEquals(tIsError _ "|" _ tContent.rows.%Size() _ "|" _ tContent.truncated, "0|26|0", "the detail is 23 header rows and three body rows")
    Do $$$AssertEquals(tContent.rows.%Get(0).Name _ "|" _ tContent.rows.%Get(0).Position _ "|" _ tContent.rows.%Get(0).Value, "ID|1|" _ tHeader, "the header's first property leads")
    Do $$$AssertEquals(tContent.rows.%Get(23).Name _ "|" _ tContent.rows.%Get(23).Position _ "|" _ tContent.rows.%Get(23).Value, "Body|24|<StringRequest>", "then the body's first line, numbered after the header's")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "ViewContents", "MessageHeaderId = " _ tHeader _ ",", .tData, "", "%Ensemble", "%Message"), 3, "the detail records a view too")
    Set tText = ..Ask("interop_message_detail", {"message": (tHeader), "maxRows": 25}, .tContent, .tIsError)
    Do $$$AssertEquals(tIsError _ "|" _ tContent.rows.%Size() _ "|" _ tContent.truncated, "0|25|1", "a cap of 25 cuts the combined rows")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tText = ..Ask("interop_message_detail", {"message": "9223372036854775"}, .tContent, .tIsError)
    Do $$$AssertEquals(tIsError _ "|" _ tContent.rows.%Size(), "0|0", "a header no row holds answers no rows")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, "ViewContents", "MessageHeaderId = 9223372036854775,", .tData, "", "%Ensemble", "%Message"), 0, "and records no view")
    Set tBinary = ##class(%Stream.GlobalBinary).%New()
    Do tBinary.Write("abc")
    Do $$$AssertStatusOK(tBinary.%Save(), "a binary stream is stored")
    Set tBinaryId = tBinary.%Id()
    Set tBinaryHeader = $ClassMethod($Parameter(..#FIXTURE, "FIXTURE"), "StoreHeader", "", "%Stream.GlobalBinary", tBinaryId, 1, 9, 10, "", "", 1, "", ..PreparedMarker _ "Bin", ..PreparedMarker _ "Op")
    Set tBinary = ""
    Set tText = ..Ask("interop_message_body", {"message": (tBinaryHeader)}, .tContent, .tIsError)
    Do $$$AssertEquals(tIsError _ "|" _ tContent.%Get("code"), "1|INTEROP.MESSAGE.CONTENTS", "a body the port cannot render as text is refused INTEROP.MESSAGE.CONTENTS")
    Do ##class(%Stream.GlobalBinary).%DeleteId(tBinaryId)
}

}
