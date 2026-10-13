/// <p>The live log tail over the wire (Story 18.38): <code>GET /api/ocupilot/logs/messages/tail</code> and
/// <code>GET /api/ocupilot/logs/alerts/tail</code> through the real <code>/api/ocupilot</code>
/// application, as the configured test principal (<class>OcuPilot.Test.Http</class>), with the shipped
/// bound.</p>
/// <p>Refusals answer at once. A cursor one byte behind the instance's <file>messages.log</file> or
/// <file>alerts.log</file> answers <code>changed</code> true at once, naming its own source. The
/// <file>messages.log</file> cursor as it stands is held, and the answer arrives within the bound as one
/// heartbeat newline for each full beat interval held and one <code>{source, changed}</code> envelope.</p>
/// <p><b>Read-only against the instance's real logs</b>; nothing here writes, rotates or removes them. The
/// longest test holds one request for the bound, which is <parameter>BOUND</parameter> seconds. Needs the
/// API application installed, the test principal's password, that principal holding
/// <code>%Admin_Operate:USE</code>, and a <file>messages.log</file> and an <file>alerts.log</file>.</p>
Class OcuPilot.Test.LogTailWire Extends %UnitTest.TestCase
{

/// <p>The console log's tail route.</p>
Parameter MESSAGESTAIL = "/api/ocupilot/logs/messages/tail";

/// <p>The alert log's tail route.</p>
Parameter ALERTSTAIL = "/api/ocupilot/logs/alerts/tail";

/// <p>The console log's page route, which supplies the cursor a tail holds.</p>
Parameter MESSAGESPAGE = "/api/ocupilot/logs/messages";

/// <p>The alert log's page route, which supplies its cursor.</p>
Parameter ALERTSPAGE = "/api/ocupilot/logs/alerts";

/// <p>The seconds between two heartbeats on the shipped port, as a literal: not read from it, so a change to
/// the beat is a change to this test.</p>
Parameter BEAT As INTEGER = 10;

/// <p>The longest a tail is held on the shipped gateway timeout, as a literal: 60 s less the margin. Not read
/// from the port, so a change to the bound is a change to this test.</p>
Parameter BOUND As INTEGER = 50;

/// <p>How far past <parameter>BOUND</parameter> an answer may arrive, in seconds.</p>
Parameter SLACK As INTEGER = 5;

/// <p>How long a client waits for any answer: <parameter>BOUND</parameter> plus 15 seconds.</p>
Parameter CLIENTTIMEOUT As INTEGER = 65;

/// <p>Request <var>pPath</var> as the configured test principal, timing the call in <var>pElapsed</var>
/// seconds.</p>
Method Fetch(pPath As %String, Output pStatus As %Integer, Output pBody As %String, Output pHeaders, Output pElapsed As %Numeric) As %Status
{
    Set tStart = $ZHorolog
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", pPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pBody, .pHeaders, "", "", .tNoHeaders, ..#CLIENTTIMEOUT)
    Set pElapsed = $ZHorolog - tStart
    Quit tSC
}

/// <p>The cursor the page route <var>pPage</var> (the console log's when empty) hands back, as the query a
/// tail takes: <code>identity=&lt;token&gt;&amp;size=&lt;bytes&gt;</code> with <var>pBehind</var> bytes taken
/// off the size. <code>""</code> when the page does not answer or its size is smaller than
/// <var>pBehind</var>.</p>
Method CursorQuery(pBehind As %Integer = 0, pPage As %String = "") As %String
{
    If pPage = "" Set pPage = ..#MESSAGESPAGE
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", pPage _ "?maxBytes=1024", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tBody, .tHeaders)
    If $$$ISERR(tSC) || (tStatus '= 200) Quit ""
    Set tPage = ##class(%DynamicObject).%FromJSON(tBody)
    If tPage.size < pBehind Quit ""
    Quit "identity=" _ $ZConvert(tPage.identity, "O", "URL") _ "&size=" _ (tPage.size - pBehind)
}

/// <p>A refused tail is answered at once with one envelope, the matrix's status and code, on both routes:
/// no cursor, a half cursor, a malformed one, and a file name.</p>
/// <p>Mutation (Rule 19): refuse the cursor after the first heartbeat in
/// <method>OcuPilot.Port.LogSourcePort.Tail</method> -&gt; a refusal holds for seconds and the elapsed-time
/// assertion goes red.</p>
Method TestARefusalAnswersAtOnceOnBothRoutes()
{
    Set tRows = $ListBuild("|400|LOG.OFFSET", "identity=abc|400|LOG.OFFSET", "size=12|400|LOG.OFFSET", "identity=a%20b&size=1|400|LOG.OFFSET", "identity=abc&size=12x|400|LOG.OFFSET", "identity=abc&size=1&file=messages.log|400|LOG.FILE", "identity=abc&size=1&file=messages.old_20261013|400|LOG.FILE")
    For tRoute = ..#MESSAGESTAIL, ..#ALERTSTAIL {
        For tI = 1:1:$ListLength(tRows) {
            Set tRow = $List(tRows, tI)
            Set tQuery = $Piece(tRow, "|", 1)
            Set tPath = tRoute _ $Select(tQuery = "": "", 1: "?" _ tQuery)
            Set tLabel = tPath
            Set tSC = ..Fetch(tPath, .tStatus, .tBody, .tHeaders, .tElapsed)
            Do $$$AssertStatusOK(tSC, tLabel _ ": the request completes")
            Do $$$AssertEquals(tStatus, +$Piece(tRow, "|", 2), tLabel _ ": is refused")
            Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", tLabel _ ": as application/json")
            Do $$$AssertEquals((tBody [ "}{"), 0, tLabel _ ": exactly one envelope")
            Do $$$AssertEquals($Extract(tBody, 1), "{", tLabel _ ": with no heartbeat before it")
            Do $$$AssertTrue(tElapsed < 2, tLabel _ ": at once: " _ tElapsed)
            Set tFault = ##class(%DynamicObject).%FromJSON(tBody)
            Do $$$AssertEquals(tFault.code, $Piece(tRow, "|", 3), tLabel _ ": on the matrix's code")
        }
    }
}

/// <p>A cursor one byte behind <file>messages.log</file>, or behind <file>alerts.log</file>, is already
/// moved on its own route: the answer is <code>changed</code> true within two seconds, naming that route's
/// source, one envelope and no heartbeat.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.LogSourcePort.Tail</method> ignores <var>size</var> -&gt; the
/// tail is held to the bound and the elapsed-time and answer assertions go red; bind
/// <method>OcuPilot.Api.Router.LogAlertsTail</method> to the console log -&gt; the alerts leg names
/// <code>messages</code> and goes red.</p>
Method TestACursorABytebehindAnswersChangedAtOnce()
{
    Set tRows = $ListBuild(..#MESSAGESTAIL _ "|" _ ..#MESSAGESPAGE _ "|messages", ..#ALERTSTAIL _ "|" _ ..#ALERTSPAGE _ "|alerts")
    For tI = 1:1:$ListLength(tRows) {
        Set tRow = $List(tRows, tI)
        Set tRoute = $Piece(tRow, "|", 1)
        Set tSource = $Piece(tRow, "|", 3)
        Set tQuery = ..CursorQuery(1, $Piece(tRow, "|", 2))
        Do $$$AssertNotEquals(tQuery, "", tSource _ ": the page supplies a cursor")
        If tQuery = "" Continue
        Set tSC = ..Fetch(tRoute _ "?" _ tQuery, .tStatus, .tBody, .tHeaders, .tElapsed)
        Do $$$AssertStatusOK(tSC, tSource _ ": the request completes")
        Do $$$AssertEquals(tStatus, 200, tSource _ ": the tail answers")
        Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", tSource _ ": as application/json")
        Do $$$AssertEquals((tBody [ "}{"), 0, tSource _ ": exactly one envelope")
        Do $$$AssertTrue(tElapsed < 2, tSource _ ": within two seconds: " _ tElapsed)
        If tStatus '= 200 Continue
        Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tAnswer.source, tSource, tSource _ ": naming the source the route bound")
        Do $$$AssertEquals(tAnswer.changed, 1, tSource _ ": changed true")
    }
}

/// <p>Hold the console log's current cursor on its tail route, taking a fresh cursor and holding again, up
/// to three times, while the answer comes before one beat interval has passed: the instance itself writes
/// to <file>messages.log</file> now and then, which ends a hold early. <var>pHaveCursor</var> is 0 when the
/// page supplies no cursor.</p>
Method HoldCurrent(Output pHaveCursor As %Boolean, Output pStatus As %Integer, Output pBody As %String, Output pHeaders, Output pElapsed As %Numeric) As %Status
{
    Set tSC = $$$OK
    Set pHaveCursor = 0
    For tTry = 1:1:3 {
        Set tQuery = ..CursorQuery(0)
        If tQuery = "" Quit
        Set pHaveCursor = 1
        Set tSC = ..Fetch(..#MESSAGESTAIL _ "?" _ tQuery, .pStatus, .pBody, .pHeaders, .pElapsed)
        If $$$ISERR(tSC) || (pStatus '= 200) || (pElapsed >= (..#BEAT + 2)) Quit
    }
    Quit tSC
}

/// <p>The file's current cursor is held, and the answer arrives within the bound plus
/// <parameter>SLACK</parameter> seconds: status 200, JSON, one newline for each full
/// <parameter>BEAT</parameter> interval held and then one <code>{source, changed}</code> envelope with no
/// other key and no <code>}{</code>. The hold is one that ran past a beat interval
/// (<method>HoldCurrent</method>), and a tail still unchanged at the end was held to the bound.</p>
/// <p>Mutation (Rule 19): delete <code>Write $Char(10)</code> from
/// <method>OcuPilot.Api.Response.Heartbeat</method>, or pass an empty beat class in
/// <method>OcuPilot.Api.LogPage.HandleTail</method> -&gt; the held answer has no leading newline and the
/// newline assertion goes red; make <method>OcuPilot.Port.LogSourcePort.TailBoundSeconds</method> answer 15
/// -&gt; the held-to-the-bound assertion goes red.</p>
Method TestTheCurrentCursorIsHeldAndAnsweredWithOneEnvelope()
{
    Set tSC = ..HoldCurrent(.tHaveCursor, .tStatus, .tBody, .tHeaders, .tElapsed)
    Do $$$AssertTrue(tHaveCursor, "the console log's page supplies a cursor")
    If 'tHaveCursor Quit
    Do $$$AssertStatusOK(tSC, "the request completes within the client's wait")
    Do $$$AssertEquals(tStatus, 200, "the tail answers 200")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertTrue(tElapsed < (..#BOUND + ..#SLACK), "within the bound: " _ tElapsed)
    Do $$$AssertTrue(tElapsed >= (..#BEAT + 2), "held past a beat interval: " _ tElapsed)
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    If tStatus '= 200 Quit
    Set tEnvelope = $ZStrip(tBody, "<", $Char(10))
    Do $$$AssertEquals($Extract(tEnvelope, 1), "{", "only newlines come before the envelope")
    Do $$$AssertEquals($ZStrip(tEnvelope, "<>", $Char(10)), tEnvelope, "and nothing comes after it")
    Set tLeading = $Length(tBody) - $Length(tEnvelope)
    Set tExpected = (tElapsed - 2) \ ..#BEAT
    Do $$$AssertTrue(tLeading >= tExpected, "a newline for each full beat interval held (" _ tExpected _ " after " _ tElapsed _ " s): " _ tLeading)
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    If 'tAnswer.changed Do $$$AssertTrue(tElapsed >= (..#BOUND - 1), "an unchanged tail was held to the bound: " _ tElapsed)
    Set tKeys = []
    Set tIterator = tAnswer.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Do tKeys.%Push(tKey)
    }
    Do $$$AssertEquals(tKeys.%ToJSON(), "[""source"",""changed""]", "the two declared keys, in order: " _ tKeys.%ToJSON())
    Do $$$AssertEquals(tAnswer.source, "messages", "the source the route bound")
    Do $$$AssertEquals(tAnswer.%GetTypeOf("changed"), "boolean", "changed is a boolean")
}

/// <p>A <code>POST</code> to either tail path is the framework's 405 naming <code>GET</code>, an answer only
/// a mapped <code>GET</code> route produces.</p>
/// <p>Mutation (Rule 19): delete the route from <class>OcuPilot.Api.Router</class>'s <code>UrlMap</code> -&gt;
/// the request answers 404 and the status assertion goes red.</p>
Method TestAPostToEitherTailPathIsRefusedNamingGet()
{
    For tRoute = ..#MESSAGESTAIL, ..#ALERTSTAIL {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tRoute, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, tRoute _ ": the request completes")
        Do $$$AssertEquals(tStatus, 405, tRoute _ ": a POST is refused")
        Do $$$AssertTrue($ListFind($ListFromString($Get(tHeaders("ALLOW"))), "GET"), tRoute _ ": and Allow names GET: " _ $Get(tHeaders("ALLOW")))
        Set tFault = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tFault.code, "ROUTE.METHODNOTALLOWED", tRoute _ ": through the one error writer")
    }
}

}
