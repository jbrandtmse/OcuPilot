/// <p>The live log tail over the wire (Story 18.38): <code>GET /api/ocupilot/logs/messages/tail</code> and
/// <code>GET /api/ocupilot/logs/alerts/tail</code> through the real <code>/api/ocupilot</code>
/// application, as the configured test principal (<class>OcuPilot.Test.Http</class>), with the shipped
/// bound.</p>
/// <p>Refusals answer at once. A cursor one byte behind the instance's <file>messages.log</file> or
/// <file>alerts.log</file> answers <code>changed</code> true at once, naming its own source. The
/// <file>messages.log</file> cursor as it stands is held, and the answer arrives within the bound as one
/// heartbeat newline for each full beat interval held and one <code>{source, changed}</code> envelope.</p>
/// <p>Nothing here rotates a log or removes one that was already there. A fresh instance may not have
/// written <file>alerts.log</file> yet; when it has not, or the file is empty,
/// <method>EnsureAlertLine</method> gives it one informational line, only where
/// <parameter>ARMINGVARIABLE</parameter> reads 1, and <method>OnAfterAllTests</method> puts the file back as
/// it found it unless the instance has written to it since. The longest test holds one request for the
/// bound, which is <parameter>BOUND</parameter> seconds, and waits for <file>messages.log</file> to be quiet
/// first (<method>AwaitQuiet</method>). Needs the API application installed, the test principal's password,
/// that principal holding <code>%Admin_Operate:USE</code>, a <file>messages.log</file>, the gateway's default
/// 60-second response timeout, and a manager directory the instance can write.</p>
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

/// <p>How many one-second looks at <file>messages.log</file> must find its cursor unchanged before a hold
/// begins.</p>
Parameter QUIETSECONDS As INTEGER = 3;

/// <p>The most seconds <method>AwaitQuiet</method> waits for that quiet; a log still moving then is held
/// anyway.</p>
Parameter QUIETCAP As INTEGER = 20;

/// <p>How many holds <method>HoldCurrent</method> makes before it reports the last one.</p>
Parameter HOLDTRIES As INTEGER = 4;

/// <p>The environment variable that lets <method>EnsureAlertLine</method> write the instance's
/// <file>alerts.log</file>, and the one value that arms it: <code>1</code>. Only
/// <file>scripts/ci-throwaway.sh</file> sets it; it is the variable the classes that write the instance's own
/// log files read.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_LOG_ROTATION";

/// <p>The size of the <file>alerts.log</file> this class wrote its line into, or <code>""</code> when it
/// wrote none.</p>
Property PreparedAlertSize As %String;

/// <p>Whether this class created that <file>alerts.log</file>, rather than finding it empty.</p>
Property PreparedAlertCreated As %Boolean;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedAlertSize = ""
    Set ..PreparedAlertCreated = 0
    Quit $$$OK
}

/// <p>Put back the <file>alerts.log</file> this class wrote its line into -- removed when this class
/// created it, emptied when it was empty -- unless the instance has written to it since.</p>
Method OnAfterAllTests() As %Status
{
    Set tPath = ..AlertsPath()
    If (..PreparedAlertSize = "") || '##class(%File).Exists(tPath) || (##class(%File).GetFileSize(tPath) '= ..PreparedAlertSize) Quit $$$OK
    If '..PreparedAlertCreated Quit ##class(OcuPilot.Test.LogSource).WriteFile(tPath, "")
    If '##class(%File).Delete(tPath) Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LogTailWire could not remove the alerts.log it created: " _ tPath)
    Quit $$$OK
}

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

/// <p>The instance's <file>alerts.log</file>.</p>
ClassMethod AlertsPath() As %String
{
    Quit ##class(%File).NormalizeFilename("alerts.log", $System.Util.ManagerDirectory())
}

/// <p>Give the alert log a cursor to tail. A file with content is left alone. An absent or empty one gets
/// one informational line in the file's own head grammar
/// (<code>MM/DD/YY-HH:MM:SS:mmm (pid) severity [Category] text</code>), only where
/// <parameter>ARMINGVARIABLE</parameter> reads 1; elsewhere nothing is written and an error says so. What it
/// wrote is remembered for <method>OnAfterAllTests</method>.</p>
Method EnsureAlertLine() As %Status
{
    Set tPath = ..AlertsPath()
    If ##class(%File).Exists(tPath) && (##class(%File).GetFileSize(tPath) > 0) Quit $$$OK
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LogTailWire writes a line into this instance's alerts.log only on a throwaway container. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was written. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tCreated = '##class(%File).Exists(tPath)
    Set tDate = $ZDate(+$Horolog, 1)
    Set tStamp = $Extract(tDate, 1, 6) _ $Extract(tDate, 9, 10) _ "-" _ $ZTime($Piece($Horolog, ",", 2), 1) _ ":000"
    Set tLine = tStamp _ " (" _ $Job _ ") 0 [OcuPilot.LogTailWire] OcuPilot.Test.LogTailWire gives the alert log a line to tail" _ $Char(10)
    Set tSC = ##class(OcuPilot.Test.LogSource).WriteFile(tPath, tLine)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedAlertCreated = tCreated
    Set ..PreparedAlertSize = ##class(%File).GetFileSize(tPath)
    Quit $$$OK
}

/// <p>Wait until the console log's cursor has been found unchanged on <parameter>QUIETSECONDS</parameter>
/// looks one second apart, or <parameter>QUIETCAP</parameter> seconds have passed. The instance writes
/// <file>messages.log</file> in bursts (an install, an earlier test's leftovers), and a hold begun inside
/// one is ended early by it.</p>
Method AwaitQuiet()
{
    Set tLast = ""
    Set tStable = 0
    Set tDeadline = $ZHorolog + ..#QUIETCAP
    While ($ZHorolog < tDeadline) && (tStable < ..#QUIETSECONDS) {
        Set tNow = ..CursorQuery(0)
        Set tStable = $Select((tNow '= "") && (tNow = tLast): tStable + 1, 1: 0)
        Set tLast = tNow
        Hang 1
    }
}

/// <p>A refused tail is answered at once with one envelope, the matrix's status and code, on both routes:
/// no cursor, a half cursor, a malformed one, and a file name.</p>
/// <p>Mutation (Rule 19): disable the <code>LOG.FILE</code> refusal in
/// <method>OcuPilot.Port.LogSourcePort.Tail</method> -&gt; the rows naming a file are not refused and the
/// status assertion goes red.</p>
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
/// source, one envelope and no heartbeat. The alert log is given its line first
/// (<method>EnsureAlertLine</method>).</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.LogSourcePort.Tail</method> ignores <var>size</var> -&gt; the
/// tail is held to the bound and the elapsed-time and answer assertions go red; bind
/// <method>OcuPilot.Api.Router.LogAlertsTail</method> to the console log -&gt; the alerts leg names
/// <code>messages</code> and goes red; skip <method>EnsureAlertLine</method>, on an instance whose
/// <file>alerts.log</file> is absent -&gt; the alerts leg finds no cursor and goes red.</p>
Method TestACursorAByteBehindAnswersChangedAtOnce()
{
    Do $$$AssertStatusOK(..EnsureAlertLine(), "the alert log has a line to tail")
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

/// <p>Hold the console log's current cursor on its tail route, after <method>AwaitQuiet</method>, taking a
/// fresh cursor and holding again, up to <parameter>HOLDTRIES</parameter> times, while the answer comes before
/// one beat interval has passed: the instance itself writes to <file>messages.log</file> now and then, which
/// ends a hold early. <var>pHaveCursor</var> is 0 when the page supplies no cursor.</p>
Method HoldCurrent(Output pHaveCursor As %Boolean, Output pStatus As %Integer, Output pBody As %String, Output pHeaders, Output pElapsed As %Numeric) As %Status
{
    Set tSC = $$$OK
    Set pHaveCursor = 0
    For tTry = 1:1:..#HOLDTRIES {
        Do ..AwaitQuiet()
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
    ; No beat is written at or past the bound, so a hold answered late still carries at most this many.
    If tExpected > ((..#BOUND - 1) \ ..#BEAT) Set tExpected = (..#BOUND - 1) \ ..#BEAT
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
