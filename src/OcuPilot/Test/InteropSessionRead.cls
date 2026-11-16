/// <p>Pins Story 24.4's session reads on <class>OcuPilot.Port.InteropPort</class> (AD-21, AD-29, AD-36, AD-37, AD-62) on synthetic message
/// headers it stores in the install namespace: each kind of <code>Sessions</code> search answers one row per session, newest first,
/// from its own criterion; a window is the last <code>hours</code> (at most 720) ending at <code>endDateTime</code> and a header one
/// second outside it is absent; a keyed read takes no window; the cap cuts; a session or key no header holds reads as no rows; each
/// malformed criterion is refused by name; <code>SessionSummary</code> and <code>SessionMessages</code> answer one session; and the
/// message viewer's pair is refused to a holder of the Interoperability menu's pair alone.</p>
/// <p><b>What it needs from the environment:</b> the install namespace running interoperability, and the account running it holding the
/// pairs the gate asks. It needs no production and no armed variable: the headers are stored directly, found by a marker in their
/// source, and removed after each test (a header's super-session index row goes with it), and the gate is the test seam's.</p>
Class OcuPilot.Test.InteropSessionRead Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.InteropPort";

Parameter FIXTURE = "OcuPilot.Test.InteropMessageRead";

/// <p>What every marker begins with; a run's marker is this and a token of letters and digits.</p>
Parameter PREFIX = "OcuPilotProbe2404";

/// <p>The columns of a session search row, in order.</p>
Parameter SESSIONFIELDS = "SessionId,FirstTime,Source,Target,BodyClass,Status,Messages,Errors";

/// <p>This test's marker. The prefix must not begin with "Test" (<file>.claude/rules/objectscript-testing.md</file>).</p>
Property PreparedMarker As %String;

/// <p>The ids of the fixture's headers, in order (<method>Plant</method>).</p>
Property PreparedIds As %List;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedMarker = ""
    Set ..PreparedIds = ""
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedMarker = ..#PREFIX _ $Extract($Translate($System.Util.CreateGUID(), "-", ""), 1, 8)
    Set tSC = ..Plant(..PreparedMarker, .tIds)
    Set ..PreparedIds = tIds
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $$$AssertEquals(..Clear(..PreparedMarker), 0, "no header of this test's marker is left")
    Quit $$$OK
}

/// <p>Store one fixture header and answer its id (0 when it could not be stored): <var>pSource</var> to <var>pTarget</var> naming the body
/// class <var>pBodyClass</var> and no body, in status <var>pStatus</var>, made <var>pAgo</var> seconds ago. <var>pSession</var>, when
/// given, is its session, and <var>pOwn</var> makes its own id its session; <var>pSuper</var>, when given, is its super-session key,
/// which the vendor's save indexes; <var>pError</var>, when given, marks it as an error with that text.</p>
ClassMethod Store(pSource As %String, pTarget As %String, pBodyClass As %String, pStatus As %Integer, pAgo As %Integer, pSession As %String = "", pOwn As %Boolean = 0, pSuper As %String = "", pError As %String = "") As %Integer
{
    Set tId = $ClassMethod(..#FIXTURE, "StoreHeader", "", pBodyClass, "", 1, pStatus, pAgo, pSession, pError, pOwn, "", pSource, pTarget)
    If 'tId || (pSuper = "") Quit tId
    Set tHeader = ##class(Ens.MessageHeader).%OpenId(tId)
    Set tHeader.SuperSession = pSuper
    If $$$ISERR(tHeader.%Save()) Quit 0
    Quit tId
}

/// <p>Store the fixture for <var>pMarker</var> and answer its ids in <var>pIds</var>, in the order H1 to H5 below, though it stores H3 first so
/// the ids rise with the times a window is cut by; <code>&lt;m&gt;</code> is <var>pMarker</var>,
/// <code>K</code> its super-session key. H1: <code>&lt;m&gt;Svc</code> to <code>&lt;m&gt;Proc</code>, <code>Ens.StringRequest</code>, Completed, an
/// hour ago, its own session (S1), under <code>K</code>. H2: <code>&lt;m&gt;Proc</code> to <code>&lt;m&gt;Op</code>,
/// <code>Ens.StringResponse</code>, Error and marked as an error, 3,500 seconds ago, in S1, under no key. H3: <code>&lt;m&gt;Svc</code> to
/// <code>&lt;m&gt;Op</code>, <code>Ens.StringResponse</code>, Completed, three hours ago, its own session (S2), under <code>K</code>. H4:
/// <code>&lt;m&gt;Other</code> to <code>&lt;m&gt;Op</code>, <code>Ens.StringRequest</code>, Discarded, ten minutes ago, its own session (S3), under no key.
/// H5: <code>&lt;m&gt;Bare</code> to <code>&lt;m&gt;Op</code>, no body class, thirty seconds ago, in no session.</p>
/// <p>Two more headers in no session bound the window <method>WindowEnd</method> names: <code>&lt;m&gt;Low</code>, stored after H3 and
/// before H1, made at that window's first second, and <code>&lt;m&gt;High</code>, stored last, made at its last millisecond. A two-hour
/// window ending at <method>WindowEnd</method> is therefore cut, by ID, at those two whatever else the namespace holds, so H3 is outside
/// it and H1, H2 and H4 inside.</p>
ClassMethod Plant(pMarker As %String, Output pIds As %List) As %Status
{
    Set pIds = ""
    Set tSC = $$$OK
    Try {
        If '$Match(pMarker, "^" _ ..#PREFIX _ "[A-Za-z0-9]{1,24}$") {
            Set tSC = $$$ERROR($$$GeneralError, "the marker is " _ ..#PREFIX _ " and a token of letters and digits")
            Quit
        }
        Set tKey = pMarker _ "K"
        Set tH3 = ..Store(pMarker _ "Svc", pMarker _ "Op", "Ens.StringResponse", 9, 10800, "", 1, tKey)
        Set tLow = ..Store(pMarker _ "Low", pMarker _ "Op", "", 9, 7800)
        Set tH1 = ..Store(pMarker _ "Svc", pMarker _ "Proc", "Ens.StringRequest", 9, 3600, "", 1, tKey)
        Set tH2 = ..Store(pMarker _ "Proc", pMarker _ "Op", "Ens.StringResponse", 8, 3500, tH1, 0, "", "OcuPilot probe error " _ pMarker)
        Set tH4 = ..Store(pMarker _ "Other", pMarker _ "Op", "Ens.StringRequest", 4, 600, "", 1)
        Set tH5 = ..Store(pMarker _ "Bare", pMarker _ "Op", "", 9, 30)
        Set tHigh = ..Store(pMarker _ "High", pMarker _ "Op", "", 9, 600)
        If '(tH1 && tH2 && tH3 && tH4 && tH5 && tLow && tHigh) Set tSC = $$$ERROR($$$GeneralError, "a fixture header could not be stored")
        Set pIds = $ListBuild(tH1, tH2, tH3, tH4, tH5)
        If $$$ISERR(tSC) Quit
        Set tEnd = $Extract($ClassMethod(..#FIXTURE, "StoredCreated", tH4), 1, 19)
        If '..Restamp(tLow, ..Shift(tEnd, -7200) _ ".000") || '..Restamp(tHigh, tEnd _ ".999") Set tSC = $$$ERROR($$$GeneralError, "a window bound could not be stamped")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Set header <var>pId</var>'s creation and processing time to the UTC stamp <var>pUtc</var> (<code>YYYY-MM-DD HH:MM:SS.mmm</code>);
/// 1 when it is saved.</p>
ClassMethod Restamp(pId As %Integer, pUtc As %String) As %Boolean
{
    Set tHeader = ##class(Ens.MessageHeader).%OpenId(pId)
    If '$IsObject(tHeader) Quit 0
    Set tHeader.TimeCreated = pUtc
    Set tHeader.TimeProcessed = pUtc
    Quit $$$ISOK(tHeader.%Save())
}

/// <p>The local second the fixture's two-hour window ends at: H4's, given the fixture's ids <var>pIds</var> (<method>Plant</method>).</p>
ClassMethod WindowEnd(pIds As %List) As %String
{
    Quit $ClassMethod(..#FIXTURE, "LocalSecond", $List(pIds, 4))
}

/// <p>How many headers whose source begins with <var>pMarker</var> are stored.</p>
ClassMethod Left(pMarker As %String) As %Integer
{
    Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(, "SELECT COUNT(*) FROM Ens.MessageHeader WHERE SourceConfigName %STARTSWITH ?", pMarker)
    If tResult.%Next() Quit tResult.%GetData(1)
    Quit -1
}

/// <p>Remove every header whose source begins with <var>pMarker</var> and answer how many are left, <code>-1</code> for a marker that
/// does not begin with <parameter>PREFIX</parameter>.</p>
ClassMethod Clear(pMarker As %String) As %Integer
{
    If $Extract(pMarker, 1, $Length(..#PREFIX)) '= ..#PREFIX Quit -1
    Try {
        Set tResult = ##class(%SQL.Statement).%ExecDirectNoPriv(, "SELECT ID FROM Ens.MessageHeader WHERE SourceConfigName %STARTSWITH ?", pMarker)
        Kill tFound
        While tResult.%Next() {
            Set tFound($Increment(tFound)) = tResult.%GetData(1)
        }
        For tI = 1:1:+$Get(tFound) {
            Do ##class(Ens.MessageHeader).%DeleteId(tFound(tI))
        }
    } Catch {
    }
    Quit ..Left(pMarker)
}

/// <p>The session of fixture header <var>pIndex</var> (1 to 5).</p>
Method Session(pIndex As %Integer) As %String
{
    Quit $List(..PreparedIds, pIndex)
}

/// <p>The rows the port's <var>pEndpoint</var> answers for <var>pQuery</var>, or <code>""</code> when it refuses; the HTTP status in
/// <var>pHttp</var> and the fault in <var>pFault</var>.</p>
ClassMethod Rows(pEndpoint As %String, ByRef pQuery, Output pHttp As %Integer, Output pFault) As %DynamicArray
{
    Quit $ClassMethod(..#FIXTURE, "Rows", pEndpoint, .pQuery, .pHttp, .pFault)
}

/// <p>The sessions of the search <var>pQuery</var> this test's marker names, as <code>SessionId</code>s in the order answered,
/// comma-separated, and those rows in <var>pRows</var> (a session another process stored is left out); <code>refused</code> when the
/// port refuses, with <var>pRows</var> empty.</p>
Method Found(ByRef pQuery, Output pHttp As %Integer, Output pFault, Output pRows) As %String
{
    Set tAll = ..Rows("Sessions", .pQuery, .pHttp, .pFault)
    Set pRows = ""
    If '$IsObject(tAll) Quit "refused"
    Set pRows = []
    Set tText = ""
    Set tIterator = tAll.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("Source") '[ ..PreparedMarker Continue
        Do pRows.%Push(tRow)
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ tRow.%Get("SessionId")
    }
    Quit $Select(tText = "": "none", 1: tText)
}

/// <p>The code and the first word of the reason of a refusal, <code>status|code|reason</code>.</p>
ClassMethod Refusal(pHttp As %Integer, pFault) As %String
{
    Quit pHttp _ "|" _ $Select($IsObject(pFault): pFault.%Get("code") _ "|" _ pFault.%Get("reason"), 1: "")
}

/// <p>Each kind of search answers one row per session, newest first, from its own criterion: a source over a two-hour window finds the
/// hour-old session and not the three-hour-old one; a status list finds the sessions holding a header in any of its words; a body class
/// and a host name each find theirs; and a row carries the session, the first time as local time, the names, the status word and the
/// two counts (the counts as JSON numbers).</p>
Method TestEachKindAnswersItsSessions()
{
    Set tM = ..PreparedMarker
    Set tS1 = ..Session(1), tS2 = ..Session(3), tS3 = ..Session(4)
    Kill tQ
    Set tQ("kind") = "source", tQ("source") = tM _ "Svc", tQ("hours") = 2, tQ("endDateTime") = ..WindowEnd(..PreparedIds)
    Do $$$AssertEquals(..Found(.tQ, .tHttp, , .tRows), tS1, "a source over two hours finds the hour-old session alone")
    Do $$$AssertEquals(tHttp, 200, "and answers 200")
    Kill tQ
    Set tQ("kind") = "source", tQ("source") = tM _ "Svc"
    Do $$$AssertEquals(..Found(.tQ), tS1 _ "," _ tS2, "over the default day it finds both, newest first")
    Kill tQ
    Set tQ("kind") = "target", tQ("target") = tM _ "Proc"
    Do $$$AssertEquals(..Found(.tQ), tS1, "a target finds its session")
    Kill tQ
    Set tQ("kind") = "bodyclass", tQ("bodyClass") = "Ens.StringResponse"
    Do $$$AssertEquals(..Found(.tQ), tS1 _ "," _ tS2, "a body class finds exactly the sessions that carry it, newest first")
    Kill tQ
    Set tQ("kind") = "status", tQ("status") = "Error,Discarded", tQ("hours") = 2, tQ("endDateTime") = ..WindowEnd(..PreparedIds)
    Do $$$AssertEquals(..Found(.tQ, , , .tStatusRows), tS3 _ "," _ tS1, "a status list finds the sessions holding a header in either word, newest first")
    Set tFirst = tStatusRows.%Get(0)
    Do $$$AssertEquals(tFirst.SessionId _ "|" _ tFirst.Source _ "|" _ tFirst.Target _ "|" _ tFirst.BodyClass _ "|" _ tFirst.Status, tS3 _ "|" _ tM _ "Other|" _ tM _ "Op|Ens.StringRequest|Discarded", "the row carries the session, the names and the status word")
    Set tSecond = tStatusRows.%Get(1)
    Do $$$AssertEquals(tSecond.Status _ "|" _ tSecond.Messages _ "|" _ tSecond.Errors, "Error|1|1", "S1's row counts the one Error header it holds in the search")
    Do $$$AssertEquals(tFirst.%GetTypeOf("Messages") _ "|" _ tFirst.%GetTypeOf("Errors") _ "|" _ tFirst.%GetTypeOf("SessionId") _ "|" _ tFirst.%GetTypeOf("FirstTime"), "number|number|string|string", "the counts are JSON numbers and the rest strings")
    Set tStored = $ClassMethod(..#FIXTURE, "StoredCreated", ..Session(4))
    Do $$$AssertEquals(tFirst.FirstTime, ##class(OcuPilot.Test.InteropHostRead).LocalForm(tStored), "the first time is the instance's local time, from " _ tStored)
    Kill tQ
    Set tQ("kind") = "session", tQ("session") = tS1
    Set tFound = ..Found(.tQ, , , .tKeyed)
    Do $$$AssertEquals(tFound, tS1, "a keyed read finds the session with no window")
    Set tRow = tKeyed.%Get(0)
    Do $$$AssertEquals(tRow.Messages _ "|" _ tRow.Errors _ "|" _ tRow.Status _ "|" _ tRow.BodyClass, "2|1|Error|Ens.StringRequest", "and counts both of its headers, its lowest status and its first body class")
}

/// <p>A body class, a source, a target or any of the three finds the sessions that carry the class name there, and a class name's
/// shape and the <code>match</code> word are refused by name.</p>
Method TestAClassNameIsMatchedWhereItIsAsked()
{
    Set tM = ..PreparedMarker
    Set tS1 = ..Session(1), tS2 = ..Session(3), tS3 = ..Session(4)
    Kill tQ
    Set tQ("kind") = "class", tQ("className") = tM _ "Svc"
    Do $$$AssertEquals(..Found(.tQ), tS1 _ "," _ tS2, "any finds the two sessions a source of that name began")
    Set tQ("match") = "target"
    Do $$$AssertEquals(..Found(.tQ), "none", "target finds none, since nothing is targeted at it")
    Kill tQ
    Set tQ("kind") = "class", tQ("className") = tM _ "Op", tQ("match") = "target", tQ("hours") = 2, tQ("endDateTime") = ..WindowEnd(..PreparedIds)
    Do $$$AssertEquals(..Found(.tQ), tS3 _ "," _ tS1, "target finds the sessions a header was addressed to it in, over two hours")
    Kill tQ
    Set tQ("kind") = "class", tQ("className") = "Ens.StringResponse", tQ("match") = "body"
    Do $$$AssertEquals(..Found(.tQ), tS1 _ "," _ tS2, "body finds exactly the sessions that carry the body class")
    Set tQ("match") = "source"
    Do $$$AssertEquals(..Found(.tQ), "none", "and source finds none")
    For tCase = "className|not a class!", "className|", "match|nowhere" {
        Kill tQ
        Set tQ("kind") = "class", tQ("className") = $Select($Piece(tCase, "|") = "className": $Piece(tCase, "|", 2), 1: "Ens.StringRequest")
        If $Piece(tCase, "|") = "match" Set tQ("match") = $Piece(tCase, "|", 2)
        Do ..Found(.tQ, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ tFault.%Get("code"), "400|PORT.VALIDATION", $Piece(tCase, "|") _ " '" _ $Piece(tCase, "|", 2) _ "' is refused 400 PORT.VALIDATION")
        Do $$$AssertEquals(tFault.%Get("reason"), $ClassMethod(..#PORT, "MessageCriterionReason", $Piece(tCase, "|")), "naming " _ $Piece(tCase, "|"))
    }
}

/// <p>A super-session key, or the key of a session, finds the sessions indexed under it with no window; a key is matched in any letter
/// case; <code>related</code> answers the other sessions without the seed; a session with no key reads as no rows; and giving both or
/// neither of the key and the session is refused.</p>
Method TestTheSuperSessionReads()
{
    Set tM = ..PreparedMarker
    Set tS1 = ..Session(1), tS2 = ..Session(3), tS3 = ..Session(4)
    Kill tQ
    Set tQ("kind") = "supersession", tQ("superSession") = tM _ "K"
    Do $$$AssertEquals(..Found(.tQ, .tHttp, , .tRows), tS1 _ "," _ tS2, "the key finds the two sessions indexed under it")
    Do $$$AssertEquals(tRows.%Get(0).Messages _ "|" _ tRows.%Get(1).Messages, "1|1", "each counting the one header indexed under the key")
    Kill tQ
    Set tQ("kind") = "supersession", tQ("superSession") = $ZConvert(tM, "L") _ "k"
    Do $$$AssertEquals(..Found(.tQ), tS1 _ "," _ tS2, "in any letter case")
    Kill tQ
    Set tQ("kind") = "supersession", tQ("session") = tS2
    Do $$$AssertEquals(..Found(.tQ), tS1 _ "," _ tS2, "a seed session finds its key's sessions, itself included")
    Kill tQ
    Set tQ("kind") = "related", tQ("session") = tS1
    Do $$$AssertEquals(..Found(.tQ), tS2, "related finds the other session, without the seed")
    Kill tQ
    Set tQ("kind") = "related", tQ("session") = tS3
    Do $$$AssertEquals(..Found(.tQ, .tHttp), "none", "a seed with no super-session finds none")
    Do $$$AssertEquals(tHttp, 200, "and is no fault")
    Kill tQ
    Set tQ("kind") = "supersession", tQ("superSession") = "OcuPilotNoSuchKey" _ tM
    Do $$$AssertEquals(..Found(.tQ), "none", "a key nothing holds finds none")
    Kill tQ
    Set tQ("kind") = "supersession", tQ("session") = "9223372036854775"
    Do $$$AssertEquals(..Found(.tQ), "none", "a session nothing holds finds none")
    Kill tQ
    Set tQ("kind") = "supersession", tQ("superSession") = tM _ "K", tQ("session") = tS1
    Do ..Found(.tQ, .tHttp, .tFault)
    Do $$$AssertEquals(..Refusal(tHttp, tFault), "400|PORT.VALIDATION|Give either superSession or session, not both and not neither.", "both are refused")
    Kill tQ
    Set tQ("kind") = "supersession"
    Do ..Found(.tQ, .tHttp, .tFault)
    Do $$$AssertEquals(..Refusal(tHttp, tFault), "400|PORT.VALIDATION|Give either superSession or session, not both and not neither.", "and so is neither")
}

/// <p>A window is the last <code>hours</code> ending at <code>endDateTime</code>, and the bound is exact: a header made at the window's
/// first second is in it, and one made a millisecond earlier is not. An <code>hours</code> above 720 or below 1, and an
/// <code>endDateTime</code> that is not a local date and time, are refused by name, and nothing is read.</p>
Method TestTheWindowIsBoundedAndExact()
{
    Set tM = ..PreparedMarker
    Set tReference = ..Store(tM _ "Ref", tM _ "Op", "", 9, 100)
    Do $$$AssertTrue(tReference > 0, "the reference header is stored")
    Set tRefUtc = $ClassMethod(..#FIXTURE, "StoredCreated", tReference)
    Set tBeginUtc = ..Shift($Extract(tRefUtc, 1, 19), -3600)
    Set tOut = ..StoreAt(tM _ "EdgeOut", ..Shift(tBeginUtc, -1) _ ".999")
    Set tIn = ..StoreAt(tM _ "EdgeIn", tBeginUtc _ ".000")
    Set tRef = ..StoreAt(tM _ "Ref2", $Extract(tRefUtc, 1, 19) _ ".999")
    Do $$$AssertTrue(tOut && tIn && tRef, "the edge headers are stored in time order")
    Set tEnd = $ClassMethod(..#FIXTURE, "LocalSecond", tReference)
    Kill tQ
    Set tQ("kind") = "source", tQ("hours") = 1, tQ("endDateTime") = tEnd
    Set tQ("source") = tM _ "EdgeIn"
    Do $$$AssertEquals(..Found(.tQ) = tIn, 1, "a header at the window's first second is in it")
    Set tQ("source") = tM _ "EdgeOut"
    Do $$$AssertEquals(..Found(.tQ), "none", "and one a millisecond earlier is not")
    Set tQ("hours") = 2
    Do $$$AssertEquals(..Found(.tQ) = tOut, 1, "though a wider window holds it")
    Kill tQ
    Set tQ("kind") = "time", tQ("hours") = 1, tQ("endDateTime") = tEnd
    Set tFound = ..Found(.tQ)
    Do $$$AssertTrue((tFound [ tIn) && (tFound '[ tOut), "a time search over the window holds the first and not the earlier")
    For tCase = "hours|721", "hours|0", "hours|abc", "hours|1.5", "endDateTime|yesterday", "endDateTime|2026-13-45 99:00:00" {
        Kill tQ
        Set tQ("kind") = "time", tQ($Piece(tCase, "|")) = $Piece(tCase, "|", 2)
        Do ..Found(.tQ, .tHttp, .tFault, .tRows)
        Do $$$AssertEquals(tHttp _ "|" _ tFault.%Get("code"), "400|PORT.VALIDATION", tCase _ " is refused 400 PORT.VALIDATION")
        Do $$$AssertEquals(tFault.%Get("reason"), $ClassMethod(..#PORT, "MessageCriterionReason", $Piece(tCase, "|")), tCase _ ": naming " _ $Piece(tCase, "|"))
        Do $$$AssertEquals($IsObject(tRows), 0, tCase _ ": no row is returned")
    }
    Kill tQ
    Set tQ("kind") = "time", tQ("hours") = 720
    Do ..Found(.tQ, .tHttp)
    Do $$$AssertEquals(tHttp, 200, "720 hours is the widest window and is read")
}

/// <p>The cap cuts a search to its first rows in the order answered, and an <code>errors</code> or <code>status</code> word outside its
/// set, a <code>kind</code> the port does not know and a session that is not digits are refused by name.</p>
Method TestTheCapCutsAndAMalformedCriterionIsRefused()
{
    Set tM = ..PreparedMarker
    Kill tQ
    Set tQ("kind") = "source", tQ("source") = tM _ "Svc", tQ("maxRows") = 1
    Do $$$AssertEquals(..Found(.tQ), ..Session(1), "a cap of one answers the newest session")
    Set tQ("maxRows") = 2
    Do $$$AssertEquals(..Found(.tQ), ..Session(1) _ "," _ ..Session(3), "a cap of two answers both")
    For tCase = "status|Nope", "status|", "status|Error,Completed,Created,Queued,Delivered,Discarded,Suspended,Deferred,Aborted,Error", "source|", "target|", "bodyClass|bad class", "session|12ab", "kind|nowhere" {
        Kill tQ
        Set tKind = $Select($Piece(tCase, "|") = "kind": $Piece(tCase, "|", 2), $Piece(tCase, "|") = "session": "session", $Piece(tCase, "|") = "bodyClass": "bodyclass", 1: $Piece(tCase, "|"))
        Set tQ("kind") = tKind
        If $Piece(tCase, "|") '= "kind" Set tQ($Piece(tCase, "|")) = $Piece(tCase, "|", 2)
        Do ..Found(.tQ, .tHttp, .tFault, .tRows)
        Do $$$AssertEquals(tHttp _ "|" _ tFault.%Get("code"), "400|PORT.VALIDATION", tCase _ " is refused 400 PORT.VALIDATION")
        Do $$$AssertEquals($IsObject(tRows), 0, tCase _ ": nothing is read")
    }
    Kill tQ
    Set tQ("kind") = "status", tQ("status") = "Nope"
    Do ..Found(.tQ, .tHttp, .tFault)
    Do $$$AssertEquals(tFault.%Get("reason"), "status must name one to nine of Created, Queued, Delivered, Discarded, Suspended, Deferred, Aborted, Error, Completed.", "a status word outside the nine is refused with the status sentence")
}

/// <p>The summary of a session is one row of its counts, its first and last time as local time, the seconds between them and its first
/// header's body class; a session no header holds reads as no rows; and a session that is not digits is refused by name.</p>
Method TestTheSummaryIsOneRow()
{
    Set tS1 = ..Session(1)
    Kill tQ
    Set tQ("session") = tS1
    Set tRows = ..Rows("SessionSummary", .tQ, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the summary answers")
    Do $$$AssertTrue($IsObject(tRows) && (tRows.%Size() = 1), "one row")
    If '$IsObject(tRows) || (tRows.%Size() '= 1) Quit
    Set tRow = tRows.%Get(0)
    Do $$$AssertEquals(tRow.SessionId _ "|" _ tRow.Messages _ "|" _ tRow.Errors _ "|" _ tRow.RootBodyClass, tS1 _ "|2|1|Ens.StringRequest", "the session, its two headers, one error and the first header's body class")
    Do $$$AssertEquals(tRow.%GetTypeOf("Messages") _ "|" _ tRow.%GetTypeOf("Seconds") _ "|" _ tRow.%GetTypeOf("FirstTime"), "number|number|string", "the counts and the span are numbers")
    Do $$$AssertTrue((tRow.Seconds > 99) && (tRow.Seconds < 101), "the seconds between the two headers' creation are about 100: " _ tRow.Seconds)
    Do $$$AssertEquals(tRow.FirstTime, ##class(OcuPilot.Test.InteropHostRead).LocalForm($ClassMethod(..#FIXTURE, "StoredCreated", tS1)), "the first time is the first header's, as local time")
    Do $$$AssertTrue(tRow.LastTime ] tRow.FirstTime, "and the last is after it")
    Kill tQ
    Set tQ("session") = "9223372036854775"
    Set tRows = ..Rows("SessionSummary", .tQ, .tHttp)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tRows): tRows.%Size(), 1: "none"), "200|0", "a session nothing holds reads as no rows")
    For tBad = "", "abc", "12345678901234567890" {
        Kill tQ
        Set tQ("session") = tBad
        Set tRows = ..Rows("SessionSummary", .tQ, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ tFault.%Get("code") _ "|" _ $IsObject(tRows), "400|PORT.VALIDATION|0", "'" _ tBad _ "' is refused 400 PORT.VALIDATION, nothing read")
        Do $$$AssertEquals(tFault.%Get("reason"), $ClassMethod(..#PORT, "MessageCriterionReason", "session"), "naming session")
    }
}

/// <p>The headers of a session come in <code>ID</code> order with <code>Step</code> from 1, the same row as the trace's, optionally between
/// two times, and the error headers alone for <code>errors</code> <code>yes</code>; a bound of the wrong shape is refused by name.</p>
Method TestASessionsHeadersComeInOrder()
{
    Set tM = ..PreparedMarker
    Set tH1 = $List(..PreparedIds, 1), tH2 = $List(..PreparedIds, 2)
    Kill tQ
    Set tQ("session") = tH1
    Set tRows = ..Rows("SessionMessages", .tQ, .tHttp)
    Do $$$AssertEquals(tHttp, 200, "the headers answer")
    Do $$$AssertEquals(..Steps(tRows), "1:" _ tH1 _ ",2:" _ tH2, "both headers of the session, in ID order, as steps 1 and 2")
    Set tRow = tRows.%Get(1)
    Do $$$AssertEquals(tRow.Type _ "|" _ tRow.Status _ "|" _ tRow.Source _ "|" _ tRow.Target _ "|" _ tRow.BodyClass _ "|" _ tRow.Error _ "|" _ tRow.SessionId, "Request|Error|" _ tM _ "Proc|" _ tM _ "Op|Ens.StringResponse|1|" _ tH1, "a row carries its header's words, names, error flag and session")
    Do $$$AssertEquals(tRow.%GetTypeOf("Step") _ "|" _ tRow.%GetTypeOf("Error"), "number|boolean", "Step is a number and Error a boolean")
    Set tQ("errors") = "yes"
    Do $$$AssertEquals(..Steps(..Rows("SessionMessages", .tQ)), "1:" _ tH2, "errors yes keeps the error header alone")
    Set tQ("errors") = "no"
    Do $$$AssertEquals(..Steps(..Rows("SessionMessages", .tQ)), "1:" _ tH1, "errors no keeps the others")
    Kill tQ
    Set tQ("session") = tH1, tQ("beginDateTime") = $ClassMethod(..#FIXTURE, "LocalSecond", tH2)
    Do $$$AssertEquals(..Steps(..Rows("SessionMessages", .tQ)), "1:" _ tH2, "a begin at the second header's second drops the first")
    Kill tQ
    Set tQ("session") = tH1, tQ("endDateTime") = $ClassMethod(..#FIXTURE, "LocalSecond", tH1)
    Do $$$AssertEquals(..Steps(..Rows("SessionMessages", .tQ)), "1:" _ tH1, "an end at the first header's second drops the second")
    Kill tQ
    Set tQ("session") = "9223372036854775"
    Do $$$AssertEquals(..Steps(..Rows("SessionMessages", .tQ, .tHttp)) _ "|" _ tHttp, "none|200", "a session nothing holds reads as no rows")
    For tCase = "beginDateTime|soon", "endDateTime|never", "errors|maybe", "session|x" {
        Kill tQ
        Set tQ("session") = $Select($Piece(tCase, "|") = "session": $Piece(tCase, "|", 2), 1: tH1)
        If $Piece(tCase, "|") '= "session" Set tQ($Piece(tCase, "|")) = $Piece(tCase, "|", 2)
        Set tRows = ..Rows("SessionMessages", .tQ, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ tFault.%Get("code") _ "|" _ $IsObject(tRows), "400|PORT.VALIDATION|0", tCase _ " is refused 400 PORT.VALIDATION, nothing read")
        Do $$$AssertEquals(tFault.%Get("reason"), $ClassMethod(..#PORT, "MessageCriterionReason", $Piece(tCase, "|")), tCase _ ": naming " _ $Piece(tCase, "|"))
    }
}

/// <p>The three session endpoints ask the message viewer's pair beside the Interoperability menu's (AD-8, AD-62): a caller who holds
/// <code>%Ens_Portal:USE</code> and READ on the namespace's globals database and not <code>%Ens_MessageHeader:USE</code> is refused 403
/// <code>AUTH.NOPRIVILEGE</code> naming that pair and gets no row, and reads once the pair is held; a namespace that runs no
/// interoperability is refused 409 <code>INTEROP.NAMESPACE</code>. The held set is declared to
/// <class>OcuPilot.Test.InteropGateSeam</class>'s gate, because the suite's own account holds <code>%All</code>.</p>
Method TestTheViewerPairIsRefusedToAHolderOfTheMenuPairAlone()
{
    Set tGate = "OcuPilot.Test.ScreenGate"
    Set tOk = $ClassMethod("OcuPilot.Kernel.Shell.Namespaces", "GlobalDatabase", $NAMESPACE, .tResource, .tReadOnly)
    Do $$$AssertTrue(tOk && (tResource '= ""), "the namespace's globals database resource is read: " _ tResource)
    Set tSession = ..Session(1)
    For tEndpoint = "Sessions", "SessionSummary", "SessionMessages" {
        Do $ClassMethod(tGate, "Reset")
        Do $ClassMethod(tGate, "Hold", "%Ens_Portal", "USE")
        Do $ClassMethod(tGate, "Hold", tResource, "READ")
        Kill tQ, tRows, tFault
        Set tQ("namespace") = $NAMESPACE, tQ("maxRows") = 1000, tQ("session") = tSession, tQ("kind") = "session"
        Set tSC = $ClassMethod("OcuPilot.Test.InteropGateSeam", "Invoke", tEndpoint, "LIST", .tQ, "", .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.code _ "|" _ tFault.detail.%Get("failedPair"), 1: ""), "403|AUTH.NOPRIVILEGE|%Ens_MessageHeader:USE", tEndpoint _ " is refused, naming the viewer's pair")
        Do $$$AssertEquals($IsObject($Get(tRows)), 0, tEndpoint _ ": and no row is returned")
        Do $ClassMethod(tGate, "Hold", "%Ens_MessageHeader", "USE")
        Kill tQ, tRows, tFault
        Set tQ("namespace") = $NAMESPACE, tQ("maxRows") = 1000, tQ("session") = tSession, tQ("kind") = "session"
        Set tSC = $ClassMethod("OcuPilot.Test.InteropGateSeam", "Invoke", tEndpoint, "LIST", .tQ, "", .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 200, tEndpoint _ ": answers once the pair is held")
    }
    Kill tQ, tRows, tFault
    Set tQ("namespace") = "%SYS", tQ("kind") = "time"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Sessions", "LIST", .tQ, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject(tFault): tFault.code, 1: ""), "409|INTEROP.NAMESPACE", "a namespace that runs no interoperability is refused 409")
}

/// <p>A header stored at the exact UTC stamp <var>pUtc</var> (<code>YYYY-MM-DD HH:MM:SS.mmm</code>) with source <var>pSource</var>, in its
/// own session, and its id (0 when it could not be stored). Stored in the order called, so ids rise with the stamps the caller gives.</p>
ClassMethod StoreAt(pSource As %String, pUtc As %String) As %Integer
{
    Set tId = ..Store(pSource, $Piece(pSource, "Edge", 1) _ "Op", "", 9, 5000, "", 1)
    If 'tId Quit 0
    Set tHeader = ##class(Ens.MessageHeader).%OpenId(tId)
    Set tHeader.TimeCreated = pUtc
    Set tHeader.TimeProcessed = pUtc
    If $$$ISERR(tHeader.%Save()) Quit 0
    Quit tId
}

/// <p>The UTC stamp <var>pSeconds</var> after <var>pStamp</var> (<code>YYYY-MM-DD HH:MM:SS</code>), in the same form.</p>
ClassMethod Shift(pStamp As %String, pSeconds As %Integer) As %String
{
    Set tHoro = $ZDateTimeH(pStamp, 3)
    Set tDays = $Piece(tHoro, ",", 1)
    Set tSeconds = $Piece(tHoro, ",", 2) + pSeconds
    While tSeconds < 0 {
        Set tSeconds = tSeconds + 86400
        Set tDays = tDays - 1
    }
    While tSeconds >= 86400 {
        Set tSeconds = tSeconds - 86400
        Set tDays = tDays + 1
    }
    Quit $ZDateTime(tDays _ "," _ tSeconds, 3)
}

/// <p>The step and id of each of <var>pRows</var>, <code>step:id</code>, comma-separated, in order; <code>none</code> when there are none.</p>
ClassMethod Steps(pRows As %DynamicArray) As %String
{
    Set tText = ""
    If '$IsObject(pRows) Quit "none"
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ tRow.%Get("Step") _ ":" _ tRow.%Get("ID")
    }
    Quit $Select(tText = "": "none", 1: tText)
}

}
