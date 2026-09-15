/// <p>The console-log page over the wire: <code>GET /api/ocupilot/logs/messages</code> through the
/// real <code>/api/ocupilot</code> application, as the configured test principal
/// (<class>OcuPilot.Test.Http</class>).</p>
/// <p><b>Read-only against the instance's real <file>messages.log</file>.</b> Nothing here writes
/// to it, rotates it, truncates it or removes it, and nothing changes the instance's logging
/// configuration. The one real rotation this story performs is
/// <class>OcuPilot.Test.LogSourceRotation</class>'s, on a throwaway container.</p>
/// <p>Needs the API application installed, the test principal's password, that principal holding
/// <code>%Admin_Operate:USE</code>, and a <file>messages.log</file> larger than
/// <parameter>MINIMUMSIZE</parameter> bytes -- which every leg that depends on it asserts for
/// itself rather than assuming.</p>
Class OcuPilot.Test.LogSourceWire Extends %UnitTest.TestCase
{

/// <p>The route, spelled once. It is literal, so
/// <method>scripts/check-objectscript.py</method>'s handler-wire-test rule keys the route by this
/// path and requires a test class naming it verbatim.</p>
Parameter LOGPATH = "/api/ocupilot/logs/messages";

/// <p>The default window the port serves a caller that names no <code>maxBytes</code>, as a
/// <b>literal</b>. Deliberately not read from
/// <parameter>OcuPilot.Port.LogSourcePort.DEFAULTMAXBYTES</parameter>: an expectation derived
/// from the subject moves with it, and lowering the parameter would then take the bound
/// assertions down with it instead of reddening them.</p>
Parameter DEFAULTWINDOW As INTEGER = 65536;

/// <p>The port's hard cap, as a literal, for the same reason.</p>
Parameter CAP As INTEGER = 1048576;

/// <p>The window the bound and continuation legs ask for. Small on purpose: a
/// <file>messages.log</file> that <class>OcuPilot.Test.LogSourceRotation</class> has just rotated
/// on a throwaway is a few kilobytes, and an assertion that needed a long-lived log would pass
/// there for the wrong reason -- by running out of file rather than by stopping at the bound.</p>
Parameter SMALLWINDOW As INTEGER = 512;

/// <p>How large the instance's <file>messages.log</file> must be for those legs to mean anything:
/// three <parameter>SMALLWINDOW</parameter>s, so a page bounded at one window provably left the
/// rest of the file unread and a second page has somewhere to continue to.</p>
Parameter MINIMUMSIZE As INTEGER = 1536;

/// <p>Request <var>pQuery</var> (a query string, or <code>""</code>) of the console-log route as
/// the configured test principal.</p>
Method Fetch(pQuery As %String, Output pStatus As %Integer, Output pBody As %String, Output pHeaders) As %Status
{
    Set tPath = ..#LOGPATH
    If pQuery '= "" Set tPath = tPath _ "?" _ pQuery
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .pBody, .pHeaders)
}

/// <p>How many <b>bytes</b> of the file a page carries: each line re-encoded as UTF-8, plus the
/// newline that ended it. Re-encoded rather than counted in characters because the page arrives
/// decoded and the live log is not pure ASCII -- an IRIS message carrying one two-byte character
/// counts one character and occupies two bytes, and a cursor is measured in bytes.</p>
ClassMethod ServedBytes(pPage As %DynamicObject) As %Integer
{
    Set tBytes = 0
    Set tIterator = pPage.lines.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLine) {
        Set tBytes = tBytes + $Length($ZConvert(tLine, "O", "UTF8")) + 1
    }
    Quit tBytes
}

/// <p>A page's lines as one JSON array, for a prefix comparison.</p>
ClassMethod LinesJson(pPage As %DynamicObject) As %String
{
    Quit pPage.lines.%ToJSON()
}

/// <p>AC1 -- no page ever carries more than the window it is bounded by, whatever the caller
/// sends: the default page is bounded at the literal 65536, and a page from byte 1 asked for
/// <parameter>SMALLWINDOW</parameter> bytes stops there and says so, leaving the rest of the file
/// unread.</p>
/// <p><b>The precondition is asserted first:</b> the file is larger than
/// <parameter>MINIMUMSIZE</parameter>, so a page that stopped at its bound cannot be a page that
/// ran out of file. Doubling the window is what shows the bound is <i>read</i> rather than
/// declared -- the wider page serves strictly more.</p>
/// <p>Mutation: remove the <code>maxBytes</code> bound from
/// <method>OcuPilot.Port.LogSourcePort.ReadWindow</method>'s read loop, so the window runs to the
/// end of the file -&gt; the bounded pages carry the whole file and both the byte-count and the
/// <code>truncated</code> assertions go red. The default page alone would not catch it, because
/// its start is already computed from <code>maxBytes</code>.</p>
Method TestAPageNeverExceedsTheCap()
{
    Set tSC = ..Fetch("", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the page answers")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    If tStatus '= 200 Quit
    Set tFirst = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertTrue(tFirst.size > ..#MINIMUMSIZE, "the instance's messages.log is large enough for a bound to mean something: " _ tFirst.size)
    If tFirst.size '> ..#MINIMUMSIZE Quit
    Do $$$AssertTrue(..ServedBytes(tFirst) <= ..#DEFAULTWINDOW, "the default page is bounded at 65536 bytes: " _ ..ServedBytes(tFirst))
    ; The default page is the file's tail, so it reaches the end by construction; the pages from
    ; byte 1 below are the ones whose bound leaves the file unfinished.
    Do $$$AssertEquals(tFirst.truncated, 0, "and reaches the end of the file, because it is the tail")
    Set tIdentity = $ZConvert(tFirst.identity, "O", "URL")

    ; A page from byte 1 of the same file: the bound here is the read loop's, not the tail
    ; arithmetic's, so this is the leg a missing clamp shows up in.
    Set tSC2 = ..Fetch("offset=1&maxBytes=" _ ..#SMALLWINDOW _ "&identity=" _ tIdentity, .tStatus2, .tBody2, .tHeaders2)
    Do $$$AssertStatusOK(tSC2, "the page from byte 1 completes")
    Do $$$AssertEquals(tStatus2, 200, "and answers")
    If tStatus2 '= 200 Quit
    Set tNarrow = ##class(%DynamicObject).%FromJSON(tBody2)
    Do $$$AssertEquals(tNarrow.restarted, 0, "the identity matched, so nothing restarted")
    Do $$$AssertTrue(..ServedBytes(tNarrow) > 0, "the narrow page served something: " _ ..ServedBytes(tNarrow))
    Do $$$AssertTrue(..ServedBytes(tNarrow) <= ..#SMALLWINDOW, "and stopped at the window it asked for rather than running to the end of the file: " _ ..ServedBytes(tNarrow))
    Do $$$AssertEquals(tNarrow.truncated, 1, "and says it did not reach the end")

    Set tWide = ..#SMALLWINDOW * 2
    Set tSC3 = ..Fetch("offset=1&maxBytes=" _ tWide _ "&identity=" _ tIdentity, .tStatus3, .tBody3, .tHeaders3)
    Do $$$AssertStatusOK(tSC3, "the page from byte 1 at twice the window completes")
    Do $$$AssertEquals(tStatus3, 200, "and answers")
    If tStatus3 '= 200 Quit
    Set tDoubled = ##class(%DynamicObject).%FromJSON(tBody3)
    Do $$$AssertTrue(..ServedBytes(tDoubled) <= tWide, "it too stops at the window it asked for: " _ ..ServedBytes(tDoubled))
    Do $$$AssertTrue(..ServedBytes(tDoubled) > ..ServedBytes(tNarrow), "and serves strictly more than the narrow page, so the bound is read rather than declared: " _ ..ServedBytes(tDoubled) _ " against " _ ..ServedBytes(tNarrow))
}

/// <p>AC1 -- a <code>maxBytes</code> outside the cap is <b>refused</b> 400
/// <code>LOG.MAXBYTES</code>, never clamped and served, and there is no parameter that raises the
/// cap: asking for one byte more than it is refused like any other bad value.</p>
/// <p>Mutation: clamp an over-cap <code>maxBytes</code> to the cap and serve it in
/// <method>OcuPilot.Port.LogSourcePort.Page</method> -&gt; every leg here goes red on the
/// status.</p>
Method TestAMaxBytesAboveTheCapIsRefused()
{
    Set tOverCap = ..#CAP + 1
    For tBad = tOverCap, 0, -1, "abc", "1e6" {
        Set tSC = ..Fetch("maxBytes=" _ $ZConvert(tBad, "O", "URL"), .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, "maxBytes '" _ tBad _ "': the request completes")
        Do $$$AssertEquals(tStatus, 400, "maxBytes '" _ tBad _ "': is refused")
        Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "maxBytes '" _ tBad _ "': as application/json")
        Do $$$AssertEquals((tBody [ "}{"), 0, "maxBytes '" _ tBad _ "': exactly one envelope")
        Set tFault = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tFault.code, "LOG.MAXBYTES", "maxBytes '" _ tBad _ "': on LOG.MAXBYTES")
        Do $$$AssertEquals(tFault.error, "bad_request", "maxBytes '" _ tBad _ "': on the bad_request slug")
        Do $$$AssertEquals(tFault.%IsDefined("lines"), 0, "maxBytes '" _ tBad _ "': and no page comes back with it")
    }
}

/// <p>AC2 -- an <code>offset</code> without its <code>identity</code>, and an
/// <code>identity</code> without its <code>offset</code>, are each one 400
/// <code>LOG.OFFSET</code> envelope.</p>
/// <p>Mutation: drop the paired check from
/// <method>OcuPilot.Port.LogSourcePort.Page</method> -&gt; an offset with no identity restarts and
/// answers 200, red on the status and the code.</p>
Method TestHalfACursorIsRefusedOverTheWire()
{
    For tQuery = "offset=1", "identity=nosuchidentity" {
        Set tSC = ..Fetch(tQuery, .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, tQuery _ ": the request completes")
        Do $$$AssertEquals(tStatus, 400, tQuery _ ": is refused")
        Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", tQuery _ ": as application/json")
        Do $$$AssertEquals((tBody [ "}{"), 0, tQuery _ ": exactly one envelope")
        Set tFault = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tFault.code, "LOG.OFFSET", tQuery _ ": on LOG.OFFSET")
    }
}

/// <p>AC5 -- a consumer that takes a bounded page and calls again with that page's returned
/// <code>offset</code> and <code>identity</code> is served the <b>next</b> window: its first line
/// is not the first page's first line, and its returned offset is the first's plus the bytes the
/// first served.</p>
/// <p>Both pages are asserted non-empty before either comparison, so two empty reads cannot pass
/// for a continuation. Two independent statements of "continues", neither true by construction:
/// the offset arithmetic, and a <b>third</b> page over the same region -- one window wide enough
/// to hold both -- whose lines must begin with the first page's followed by the second's. A
/// second page that repeated the first, or skipped a line, fails the prefix comparison whatever
/// the offsets say.</p>
/// <p>Mutation: answer the window's <b>start</b> offset instead of its end in
/// <method>OcuPilot.Port.LogSourcePort.ReadWindow</method> -&gt; the second page repeats the
/// first, and the first-line, offset and prefix assertions all go red.</p>
Method TestASecondCallContinuesWhereTheFirstStopped()
{
    Set tIdentity = $ZConvert(..CurrentIdentity(), "O", "URL")
    Set tSC = ..Fetch("offset=1&maxBytes=" _ ..#SMALLWINDOW _ "&identity=" _ tIdentity, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the first page completes")
    Do $$$AssertEquals(tStatus, 200, "and answers")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    If tStatus '= 200 Quit
    Set tFirst = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertTrue(tFirst.size > ..#MINIMUMSIZE, "the log is long enough for a second page to have somewhere to continue to: " _ tFirst.size)
    If tFirst.size '> ..#MINIMUMSIZE Quit
    Do $$$AssertEquals(tFirst.restarted, 0, "the identity matched, so the first page did not restart")
    Do $$$AssertTrue(tFirst.lines.%Size() > 0, "the first page carries lines: " _ tFirst.lines.%Size())
    If tFirst.lines.%Size() = 0 Quit

    Set tSC2 = ..Fetch("offset=" _ tFirst.offset _ "&maxBytes=" _ ..#SMALLWINDOW _ "&identity=" _ tIdentity, .tStatus2, .tBody2, .tHeaders2)
    Do $$$AssertStatusOK(tSC2, "the second call completes")
    Do $$$AssertEquals(tStatus2, 200, "and answers")
    If tStatus2 '= 200 Quit
    Set tSecond = ##class(%DynamicObject).%FromJSON(tBody2)
    Do $$$AssertEquals(tSecond.restarted, 0, "and did not restart either")
    Do $$$AssertTrue(tSecond.lines.%Size() > 0, "the second page carries lines too: " _ tSecond.lines.%Size())
    If tSecond.lines.%Size() = 0 Quit

    Do $$$AssertNotEquals(tSecond.lines.%Get(0), tFirst.lines.%Get(0), "the second page starts somewhere the first did not")
    Do $$$AssertEquals(tFirst.offset, 1 + ..ServedBytes(tFirst), "the first page's cursor is byte 1 plus the bytes it served: " _ tFirst.offset)
    Do $$$AssertEquals(tSecond.offset, tFirst.offset + ..ServedBytes(tSecond), "and the second's is the first's plus the bytes it served: " _ tSecond.offset)

    ; One window over the same region, wide enough to hold both pages: the two pages laid end to
    ; end must be its opening lines. This is the statement that holds whatever the byte accounting
    ; does, and it is what a repeated or a skipped line breaks.
    Set tSC3 = ..Fetch("offset=1&maxBytes=" _ ..#DEFAULTWINDOW _ "&identity=" _ tIdentity, .tStatus3, .tBody3, .tHeaders3)
    Do $$$AssertStatusOK(tSC3, "the covering page completes")
    Do $$$AssertEquals(tStatus3, 200, "and answers")
    If tStatus3 '= 200 Quit
    Set tWhole = ##class(%DynamicObject).%FromJSON(tBody3)
    Set tJoined = $Extract(..LinesJson(tFirst), 1, *-1) _ "," _ $Extract(..LinesJson(tSecond), 2, *)
    Do $$$AssertEquals($Extract(..LinesJson(tWhole), 1, $Length(tJoined) - 1), $Extract(tJoined, 1, *-1), "the two pages end to end are the opening lines of one window over the same region")
}

/// <p>AC1, AC5 -- the page's own shape over the wire: one JSON envelope carrying exactly the seven
/// declared keys, with <code>lines</code> an array of strings, <code>restarted</code> and
/// <code>truncated</code> booleans, and <code>offset</code>, <code>size</code> and
/// <code>identity</code> the cursor a second call hands back.</p>
/// <p>Mutation: drop <code>identity</code> from the payload
/// <method>OcuPilot.Port.LogSourcePort.Page</method> builds -&gt; the key-set assertion goes
/// red.</p>
Method TestThePageIsOneEnvelopeWithTheDeclaredKeys()
{
    Set tSC = ..Fetch("maxBytes=4096", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the page answers")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    If tStatus '= 200 Quit

    Set tPage = ##class(%DynamicObject).%FromJSON(tBody)
    Set tKeys = []
    Set tIterator = tPage.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Do tKeys.%Push(tKey)
    }
    Do $$$AssertEquals(tKeys.%ToJSON(), "[""source"",""lines"",""offset"",""identity"",""size"",""restarted"",""truncated""]", "the seven declared keys, in order: " _ tKeys.%ToJSON())
    Do $$$AssertEquals(tPage.source, "messages", "the source the route bound")
    Do $$$AssertEquals(tPage.%GetTypeOf("lines"), "array", "lines is an array")
    Do $$$AssertEquals(tPage.%GetTypeOf("restarted"), "boolean", "restarted is a boolean")
    Do $$$AssertEquals(tPage.%GetTypeOf("truncated"), "boolean", "truncated is a boolean")
    Do $$$AssertEquals($Length(tPage.identity), 44, "identity is a 44-character token: " _ tPage.identity)
    Do $$$AssertTrue(tPage.lines.%Size() > 0, "and the live log's lines come back: " _ tPage.lines.%Size())
    If tPage.lines.%Size() = 0 Quit
    Set tBad = ""
    Set tLineIterator = tPage.lines.%GetIterator()
    While tLineIterator.%GetNext(.tIndex, .tLine) {
        If tPage.lines.%GetTypeOf(tIndex) '= "string" Set tBad = "line " _ tIndex _ " is " _ tPage.lines.%GetTypeOf(tIndex)
        If tLine [ $Char(10) Set tBad = "line " _ tIndex _ " carries a newline, so it is not one line"
        If tBad '= "" Quit
    }
    Do $$$AssertEquals(tBad, "", "every line is a string and holds no newline of its own")
}

/// <p>A <code>POST</code> to the console-log path is the framework's 405 naming <code>GET</code>,
/// an answer only a mapped <code>GET /logs/messages</code> route produces; without the route the
/// path matches nothing and is a 404.</p>
/// <p>Mutation: delete the route from <class>OcuPilot.Api.Router</class>'s <code>UrlMap</code>
/// -&gt; the request answers 404 and every assertion here goes red.</p>
Method TestAPostToTheMessagesLogPathIsRefusedNamingGet()
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#LOGPATH, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 405, "a POST to the console-log route is refused")
    Do $$$AssertTrue($ListFind($ListFromString($Get(tHeaders("ALLOW"))), "GET"), "and Allow names GET: " _ $Get(tHeaders("ALLOW")))
    Set tFault = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tFault.code, "ROUTE.METHODNOTALLOWED", "through the one error writer")
}

/// <p>AC5 -- the cursor a page hands back is spendable <b>exactly as it was handed back</b>. A
/// caller that echoes <code>identity</code> into the next query string without percent-encoding
/// it is answered a continuation, not a restart.</p>
/// <p><b>This is the one leg that does not launder the token.</b> Every other continuation here
/// runs it through <code>$ZConvert(..., "O", "URL")</code> first, which is what a wire suite
/// naturally does and what makes a token carrying a <code>+</code> invisible to all of them: a
/// raw <code>+</code> in a query string decodes to a space, so the held identity would not match
/// and the page would silently restart at byte 1.</p>
/// <p>Mutation: drop the <code>$Translate</code> from
/// <method>OcuPilot.Port.LogSourcePort.Identity</method> -&gt; the token carries a <code>+</code>
/// or a <code>/</code> for most file contents, and the <code>restarted</code> and served-region
/// assertions here go red while every other leg in this class stays green.</p>
Method TestTheCursorIsSpendableWithoutEncoding()
{
    Set tRaw = ..CurrentIdentity()
    Do $$$AssertNotEquals(tRaw, "", "a first page answered with an identity")
    If tRaw = "" Quit
    ; The alphabet a query string leaves alone, not $ZConvert's allow-list -- that one also
    ; escapes the padding "=", which a query value carries literally.
    Do $$$AssertTrue($Match(tRaw, "^[A-Za-z0-9_-]+=*$"), "the token carries only characters a query string leaves alone: " _ tRaw)

    Set tSC = ..Fetch("offset=1&maxBytes=" _ ..#SMALLWINDOW _ "&identity=" _ tRaw, .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "and answers")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    If tStatus '= 200 Quit
    Set tPage = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tPage.identity, tRaw, "the file has not moved between the two calls, so the cursor is still the current one")
    If tPage.identity '= tRaw Quit
    Do $$$AssertEquals(tPage.restarted, 0, "the unencoded cursor was honoured rather than read as a different file")
    Do $$$AssertTrue(tPage.lines.%Size() > 0, "and the page carries lines: " _ tPage.lines.%Size())
}

/// <p>The identity the live file carries right now, taken from a first page, so a continuation
/// leg can name a cursor without hard-coding one. <code>""</code> when the page does not
/// answer.</p>
Method CurrentIdentity() As %String
{
    Set tSC = ..Fetch("maxBytes=1024", .tStatus, .tBody, .tHeaders)
    If $$$ISERR(tSC) || (tStatus '= 200) Quit ""
    Quit ##class(%DynamicObject).%FromJSON(tBody).identity
}

}
