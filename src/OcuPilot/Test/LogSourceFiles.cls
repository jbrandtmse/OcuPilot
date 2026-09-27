/// <p><class>OcuPilot.Port.LogSourcePort</class>'s older console-log files at its own API (Story
/// 16.20, AD-21's fourth named case): <method>OcuPilot.Port.LogSourcePort.Files</method>'s list and
/// its order, the decoys it leaves out, its cap, and <method>OcuPilot.Port.LogSourcePort.Page</method>
/// reading one rotated file by name under the source's own gate, cursor and identity -- with every
/// other name refused <code>LOG.FILE</code> before the filesystem is touched.</p>
/// <p>Driven through <class>OcuPilot.Test.LogSourceFixture</class> against a scratch directory this
/// class creates and removes under <code>&lt;ManagerDirectory&gt;ocupilotfilesprobe/</code>, holding
/// a <file>messages.log</file>, three rotated files written a second apart in an order their names
/// do not sort in, and decoys: a directory carrying a rotated name, <file>messages.log.1</file>,
/// <file>alerts.old_20260101</file> and <file>messages.old_20260101_1.bak</file>. The instance's own
/// manager directory is never written. Needs a writable manager directory.</p>
Class OcuPilot.Test.LogSourceFiles Extends %UnitTest.TestCase
{

/// <p>The scratch root, removed whole in <method>OnAfterAllTests</method>.</p>
Parameter PROBEROOT = "ocupilotfilesprobe";

/// <p>The rotated files, in the order they are written: each a second newer than the one before,
/// so the newest-first order is this list reversed, which is not the names' own order.</p>
Parameter ROTATED = "messages.old_20260102,messages.old_20260101,messages.old_20260101_1";

/// <p>Items whose names resemble a rotated file's and must not be listed. The first is created as a
/// directory; the rest as files.</p>
Parameter DECOYS = "messages.old_20260103,messages.log.1,alerts.old_20260101,messages.old_20260101_1.bak";

/// <p>Every <code>file</code> value that must be refused <code>LOG.FILE</code> on the
/// <code>messages</code> source, <code>messages.log</code> itself among them.</p>
Parameter BADNAMES = "/etc/passwd,../messages.log,messages.log,messages.old_2026,messages.old_20260101_1.bak,alerts.log,messages.old_20260101/../messages.log,./messages.old_20260101,messages.old_20260101_1234567,messages.old_2026010a, messages.old_20260101";

/// <p>The scratch directory.</p>
ClassMethod Root() As %String
{
    Quit ##class(%File).NormalizeDirectory(..#PROBEROOT, $System.Util.ManagerDirectory())
}

/// <p>The content of scratch file <var>pTag</var>: three head-format lines that name it.</p>
ClassMethod Content(pTag As %String) As %String
{
    Set tText = ""
    For tI = 1:1:3 {
        Set tText = tText _ "09/26/26-10:00:0" _ tI _ ":000 (4242) 0 [OcuPilot.FilesProbe] " _ pTag _ " line " _ tI _ $Char(10)
    }
    Quit tText
}

/// <p>Build the scratch directory: <file>messages.log</file>, the rotated files one second apart,
/// then the decoys.</p>
Method OnBeforeAllTests() As %Status
{
    Do ##class(%File).RemoveDirectoryTree(..Root())
    Do ##class(%File).CreateDirectoryChain(..Root(), .tMade)
    If (..Root() = "") || '##class(%File).DirectoryExists(..Root()) Quit $$$ERROR($$$GeneralError, "the scratch directory could not be created under the manager directory")
    Set tSC = ##class(OcuPilot.Test.LogSource).WriteFile(..Root() _ "messages.log", ..Content("messages.log"))
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Length(..#ROTATED, ",") {
        Hang 1.1
        Set tName = $Piece(..#ROTATED, ",", tI)
        Set tSC = ##class(OcuPilot.Test.LogSource).WriteFile(..Root() _ tName, ..Content(tName))
        If $$$ISERR(tSC) Quit
    }
    If $$$ISERR(tSC) Quit tSC
    Do ##class(%File).CreateDirectoryChain(..Root() _ $Piece(..#DECOYS, ",", 1), .tMadeDecoy)
    For tI = 2:1:$Length(..#DECOYS, ",") {
        Set tSC = ##class(OcuPilot.Test.LogSource).WriteFile(..Root() _ $Piece(..#DECOYS, ",", tI), ..Content("decoy"))
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.LogSourceFixture).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.LogSourceFixture).QueueManagerDirectory(..Root())
    Quit $$$OK
}

/// <p>Remove the scratch directory and every armed answer, and return a failing status if the
/// directory survives.</p>
Method OnAfterAllTests() As %Status
{
    Do ##class(OcuPilot.Test.LogSourceFixture).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(%File).RemoveDirectoryTree(..Root())
    If ##class(%File).DirectoryExists(..Root()) Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LogSourceFiles left its scratch directory on the instance: " _ ..Root())
    Quit $$$OK
}

/// <p>The names a list answered, comma-separated in order.</p>
ClassMethod Names(pResult As %DynamicObject) As %String
{
    Set tNames = ""
    If '$IsObject(pResult) Quit ""
    Set tIterator = pResult.files.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tEntry.name
    }
    Quit tNames
}

/// <p>The code a fault carries, or <code>""</code>.</p>
ClassMethod CodeOf(pFault As %DynamicObject) As %String
{
    Quit $Select($IsObject(pFault): pFault.%Get("code"), 1: "")
}

/// <p>AC1 -- the list is the console log first, then every rotated file newest first by
/// last-modified time, each with its size in bytes and its modification time as ISO-8601 UTC. The
/// rotated files were written in an order their names do not sort in, so an order by name in
/// either direction differs from the expected one.</p>
/// <p>Mutation: sort ascending (<code>$Order(tSorted(tKey))</code> forward in
/// <method>OcuPilot.Port.LogSourcePort.Files</method>) -&gt; the order assertion goes red.</p>
Method TestTheListIsTheCurrentFileThenRotatedNewestFirst()
{
    Set tSC = ##class(OcuPilot.Test.LogSourceFixture).Files("messages", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the list is served")
    Do $$$AssertEquals(tHttp, 200, "on 200")
    If '$IsObject(tResult) Quit
    Do $$$AssertEquals(tResult.source, "messages", "for the source the caller named")
    Do $$$AssertEquals(..Names(tResult), "messages.log,messages.old_20260101_1,messages.old_20260101,messages.old_20260102", "messages.log first, then the rotated files newest first")
    Do $$$AssertEquals(tResult.%GetTypeOf("truncated"), "boolean", "the cut is reported")
    Do $$$AssertEquals(tResult.truncated, 0, "and there was none")
    Set tIterator = tResult.files.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        Do $$$AssertEquals(tEntry.size, $Length(..Content(tEntry.name)), tEntry.name _ ": its size in bytes")
        Do $$$AssertEquals(tEntry.%GetTypeOf("size"), "number", tEntry.name _ ": as a number")
        Do $$$AssertTrue($Match(tEntry.modified, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"), tEntry.name _ ": modified is ISO-8601 UTC: " _ tEntry.modified)
        Set tAge = $System.SQL.Functions.DATEDIFF("s", $Translate($Extract(tEntry.modified, 1, *-1), "T", " "), $ZDateTime($ZTimeStamp, 3))
        Do $$$AssertTrue((tAge >= -5) && (tAge < 600), tEntry.name _ ": and it is when the file was written, in UTC: " _ tEntry.modified _ " (" _ tAge _ " s ago)")
    }
}

/// <p>AC1 -- regular files matching the rotation pattern only: a directory carrying a rotated
/// name, <file>messages.log.1</file>, <file>alerts.old_20260101</file> and a rotated name with a
/// suffix are all in the scratch directory and none is listed.</p>
/// <p>Mutation: drop the <code>Type</code> = <code>F</code> filter in
/// <method>OcuPilot.Port.LogSourcePort.Files</method> -&gt; the directory is listed and this goes
/// red.</p>
Method TestDecoysAreNotListed()
{
    Set tSC = ##class(OcuPilot.Test.LogSourceFixture).Files("messages", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the list is served")
    Set tNames = "," _ ..Names(tResult) _ ","
    For tI = 1:1:$Length(..#DECOYS, ",") {
        Set tDecoy = $Piece(..#DECOYS, ",", tI)
        Do $$$AssertTrue(tNames '[ ("," _ tDecoy _ ","), tDecoy _ " is not listed")
    }
    Do $$$AssertTrue(##class(%File).DirectoryExists(..Root() _ $Piece(..#DECOYS, ",", 1)), "the directory decoy is really there to be left out")
}

/// <p>Two rotated files with one modification time are ordered by name, descending.</p>
Method TestEqualTimesBreakByNameDescending()
{
    Set tWhen = "67840,3600"
    Do ##class(OcuPilot.Test.LogSourceFixture).AddEntry("messages.old_20260926_2", "F", 10, tWhen)
    Do ##class(OcuPilot.Test.LogSourceFixture).AddEntry("messages.old_20260926_10", "F", 10, tWhen)
    Do ##class(OcuPilot.Test.LogSourceFixture).AddEntry("messages.old_20260926", "F", 10, tWhen)
    Do ##class(OcuPilot.Test.LogSourceFixture).AddEntry("messages.old_20260925", "F", 10, "67840,3599")
    Set tSC = ##class(OcuPilot.Test.LogSourceFixture).Files("messages", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the armed listing is served")
    Do $$$AssertEquals(..Names(tResult), "messages.old_20260926_2,messages.old_20260926_10,messages.old_20260926,messages.old_20260925", "equal times by name descending, then the older time")
    Do $$$AssertEquals($Select($IsObject(tResult): tResult.files.%Get(0).modified, 1: ""), "2026-09-27T01:00:00Z", "and the time is the listing's own, as UTC")
}

/// <p>AC1 -- the list answers at most 1,000 entries and says when it cut: 1,001 matching files
/// answer the newest 1,000 with <code>truncated</code> true, 1,000 answer all of them with
/// <code>truncated</code> false, and <file>messages.log</file> counts inside the 1,000.</p>
/// <p>Mutation: count only the rotated files against <parameter>OcuPilot.Port.LogSourcePort.FILESCAP</parameter>
/// -&gt; the third leg answers 1,001 entries and goes red.</p>
Method TestTheListIsCappedAndSaysSo()
{
    For tI = 1:1:1001 {
        Do ##class(OcuPilot.Test.LogSourceFixture).AddEntry("messages.old_20200101_" _ tI, "F", tI, "67000," _ tI)
    }
    Set tSC = ##class(OcuPilot.Test.LogSourceFixture).Files("messages", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "1,001 files are served")
    If '$IsObject(tResult) Quit
    Do $$$AssertEquals(tResult.files.%Size(), 1000, "as the newest 1,000")
    Do $$$AssertEquals(tResult.truncated, 1, "reporting the cut")
    Do $$$AssertEquals(tResult.files.%Get(0).name, "messages.old_20200101_1001", "newest first")
    Do $$$AssertEquals(tResult.files.%Get(999).name, "messages.old_20200101_2", "and the oldest is the one left out")

    Do ##class(OcuPilot.Test.LogSourceFixture).Clear()
    Do ##class(OcuPilot.Test.LogSourceFixture).QueueManagerDirectory(..Root())
    For tI = 1:1:1000 {
        Do ##class(OcuPilot.Test.LogSourceFixture).AddEntry("messages.old_20200101_" _ tI, "F", tI, "67000," _ tI)
    }
    Set tSC = ##class(OcuPilot.Test.LogSourceFixture).Files("messages", .tResult2, .tHttp2, .tFault2)
    Do $$$AssertStatusOK(tSC, "1,000 files are served")
    If '$IsObject(tResult2) Quit
    Do $$$AssertEquals(tResult2.files.%Size(), 1000, "all of them")
    Do $$$AssertEquals(tResult2.truncated, 0, "with no cut")

    Do ##class(OcuPilot.Test.LogSourceFixture).Clear()
    Do ##class(OcuPilot.Test.LogSourceFixture).QueueManagerDirectory(..Root())
    Do ##class(OcuPilot.Test.LogSourceFixture).AddEntry("messages.log", "F", 1, "67000,1")
    For tI = 1:1:1000 {
        Do ##class(OcuPilot.Test.LogSourceFixture).AddEntry("messages.old_20200101_" _ tI, "F", tI, "67000," _ tI)
    }
    Set tSC = ##class(OcuPilot.Test.LogSourceFixture).Files("messages", .tResult3, .tHttp3, .tFault3)
    Do $$$AssertStatusOK(tSC, "messages.log and 1,000 rotated files are served")
    If '$IsObject(tResult3) Quit
    Do $$$AssertEquals(tResult3.files.%Size(), 1000, "as 1,000 entries in all, messages.log counted")
    Do $$$AssertEquals(tResult3.truncated, 1, "reporting the cut")
    Do $$$AssertEquals(tResult3.files.%Get(0).name, "messages.log", "messages.log first")
    Do $$$AssertEquals(tResult3.files.%Get(999).name, "messages.old_20200101_2", "then the newest 999 rotated files")
}

/// <p>AC3 -- the list is gated on the console log's own pair before the directory is read: denied,
/// it answers 403 naming <code>%Admin_Operate:USE</code> with zero filesystem touches; held, it
/// reads the directory once.</p>
/// <p>Mutation: move <method>OcuPilot.Port.LogSourcePort.Files</method>'s directory read above the
/// gate -&gt; the zero-touch assertion goes red.</p>
Method TestNothingIsListedBeforeTheGate()
{
    Do ##class(OcuPilot.Test.LogSourceFixture).SetGateClass("OcuPilot.Test.ScreenGate")
    Do ##class(OcuPilot.Test.LogSourceFixture).ClearTouches()
    Set tSC = ##class(OcuPilot.Test.LogSourceFixture).Files("messages", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a caller without the pair is refused")
    Do $$$AssertEquals(tHttp, 403, "on 403")
    Do $$$AssertEquals($Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.failedPair, 1: ""), "%Admin_Operate:USE", "naming the pair")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogSourceFixture).Touches(), 0, "and the directory was not read")

    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Operate", "USE")
    Do ##class(OcuPilot.Test.LogSourceFixture).ClearTouches()
    Set tSC = ##class(OcuPilot.Test.LogSourceFixture).Files("messages", .tResult2, .tHttp2, .tFault2)
    Do $$$AssertStatusOK(tSC, "holding the pair, the list is served")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogSourceFixture).Touches(), 1, "after one read of the directory")
}

/// <p>The list is the console log's alone: the alert log and a key outside the enum are refused
/// <code>LOG.SOURCE</code> without reading the directory.</p>
Method TestOnlyTheConsoleLogListsOlderFiles()
{
    For tSource = "alerts", "nosuchsource" {
        Do ##class(OcuPilot.Test.LogSourceFixture).ClearTouches()
        Set tSC = ##class(OcuPilot.Test.LogSourceFixture).Files(tSource, .tResult, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, tSource _ ": refused")
        Do $$$AssertEquals(tHttp, 404, tSource _ ": on 404")
        Do $$$AssertEquals(..CodeOf(tFault), "LOG.SOURCE", tSource _ ": on LOG.SOURCE")
        Do $$$AssertEquals(##class(OcuPilot.Test.LogSourceFixture).Touches(), 0, tSource _ ": and the directory was not read")
    }
}

/// <p>AC3 -- every name but a rotated file's is refused 400 <code>LOG.FILE</code> before the
/// filesystem is touched, <code>messages.log</code> itself included, and the refusal repeats
/// neither the value nor a path. The same holds for any name on the alert log.</p>
/// <p>Mutation: drop the <parameter>OcuPilot.Port.LogSourcePort.ROTATEDFORM</parameter> match from
/// <method>OcuPilot.Port.LogSourcePort.RotatedName</method> -&gt; the bad names reach the
/// filesystem and these legs go red.</p>
Method TestEveryOtherNameIsRefusedBeforeAnyFileAccess()
{
    Set tBad = $ListFromString(..#BADNAMES) _ $ListBuild("messages.old_20260101" _ $Char(10), "messages.old_20260101" _ $Char(0))
    For tI = 1:1:$ListLength(tBad) {
        Set tName = $ListGet(tBad, tI)
        Set tLabel = $ZConvert(tName, "O", "JSON")
        Do ##class(OcuPilot.Test.LogSourceFixture).ClearTouches()
        Set tSC = ##class(OcuPilot.Test.LogSourceFixture).Page("messages", "", "", "", .tResult, .tHttp, .tFault, tName)
        Do $$$AssertStatusNotOK(tSC, "'" _ tLabel _ "': refused")
        Do $$$AssertEquals(tHttp, 400, "'" _ tLabel _ "': on 400")
        Do $$$AssertEquals(..CodeOf(tFault), "LOG.FILE", "'" _ tLabel _ "': on LOG.FILE")
        Do $$$AssertEquals(##class(OcuPilot.Test.LogSourceFixture).Touches(), 0, "'" _ tLabel _ "': before any file access")
        Set tBody = $Select($IsObject(tFault): tFault.%ToJSON(), 1: "")
        Do $$$AssertTrue((tBody '[ "/") && (tBody '[ ##class(%File).NormalizeDirectory(..Root())), "'" _ tLabel _ "': the refusal names no path: " _ tBody)
        If $Length(tName) > 6 Do $$$AssertTrue(tBody '[ tName, "'" _ tLabel _ "': nor the value sent")
    }

    Do ##class(OcuPilot.Test.LogSourceFixture).ClearTouches()
    Set tSC = ##class(OcuPilot.Test.LogSourceFixture).Page("alerts", "", "", "", .tResult, .tHttp, .tFault, "messages.old_20260101")
    Do $$$AssertEquals(tHttp, 400, "a rotated name on the alert log is refused 400")
    Do $$$AssertEquals(..CodeOf(tFault), "LOG.FILE", "on LOG.FILE")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogSourceFixture).Touches(), 0, "before any file access")
}

/// <p>AC3 -- the name is checked after the gate: a caller without the pair who sends a bad name is
/// answered 403 naming the pair, not 400, and nothing is touched.</p>
/// <p>Mutation: move the <code>LOG.FILE</code> check in
/// <method>OcuPilot.Port.LogSourcePort.Page</method> above the gate -&gt; this answers 400 and goes
/// red.</p>
Method TestTheNameIsCheckedAfterTheGate()
{
    Do ##class(OcuPilot.Test.LogSourceFixture).SetGateClass("OcuPilot.Test.ScreenGate")
    For tName = "/etc/passwd", "messages.old_20260101" {
        Do ##class(OcuPilot.Test.LogSourceFixture).ClearTouches()
        Set tSC = ##class(OcuPilot.Test.LogSourceFixture).Page("messages", "", "", "", .tResult, .tHttp, .tFault, tName)
        Do $$$AssertEquals(tHttp, 403, tName _ ": a caller without the pair is refused by the gate first")
        Do $$$AssertEquals(..CodeOf(tFault), "AUTH.NOPRIVILEGE", tName _ ": on the privilege code")
        Do $$$AssertEquals(##class(OcuPilot.Test.LogSourceFixture).Touches(), 0, tName _ ": and nothing was touched")
    }
}

/// <p>AC2 -- a rotated file pages through the console log's own path: its tail, a continuation
/// from the cursor the tail returned, and a restart when the held identity is another file's.</p>
Method TestAnOlderFileIsPagedUnderItsOwnCursor()
{
    Set tName = "messages.old_20260101"
    Set tSC = ##class(OcuPilot.Test.LogSourceFixture).Page("messages", "", "", "", .tPage, .tHttp, .tFault, tName)
    Do $$$AssertStatusOK(tSC, "the rotated file is served")
    Do $$$AssertEquals(tHttp, 200, "on 200")
    If '$IsObject(tPage) Quit
    Do $$$AssertEquals(tPage.source, "messages", "as the console log's source")
    Do $$$AssertEquals(tPage.lines.%Size(), 3, "its three lines")
    Do $$$AssertTrue(tPage.lines.%Get(0) [ (tName _ " line 1"), "and they are that file's own: " _ tPage.lines.%Get(0))
    Do $$$AssertEquals(tPage.size, $Length(..Content(tName)), "its size")

    Set tSC = ##class(OcuPilot.Test.LogSourceFixture).Page("messages", "", "", "", .tCurrent, .tHttpC, .tFaultC)
    Do $$$AssertStatusOK(tSC, "messages.log is still served without a name")
    Do $$$AssertTrue($IsObject(tCurrent) && (tCurrent.lines.%Get(0) [ "messages.log line 1"), "and it is messages.log")
    Do $$$AssertNotEquals($Select($IsObject(tCurrent): tCurrent.identity, 1: ""), tPage.identity, "each file carries its own identity")

    Set tSC = ##class(OcuPilot.Test.LogSourceFixture).Page("messages", 1, 100, tPage.identity, .tFirst, .tHttp1, .tFault1, tName)
    Do $$$AssertStatusOK(tSC, "a page from byte 1 under the file's identity")
    If '$IsObject(tFirst) Quit
    Do $$$AssertEquals(tFirst.restarted, 0, "does not restart")
    Set tSC = ##class(OcuPilot.Test.LogSourceFixture).Page("messages", tFirst.offset, "", tFirst.identity, .tNext, .tHttp2, .tFault2, tName)
    Do $$$AssertStatusOK(tSC, "and the next page continues")
    If '$IsObject(tNext) Quit
    Do $$$AssertEquals(tNext.restarted, 0, "without a restart")
    Do $$$AssertTrue(tNext.lines.%Get(0) [ (tName _ " line 2"), "from where the first stopped: " _ tNext.lines.%Get(0))

    Set tSC = ##class(OcuPilot.Test.LogSourceFixture).Page("messages", tFirst.offset, "", tCurrent.identity, .tMoved, .tHttp3, .tFault3, tName)
    Do $$$AssertStatusOK(tSC, "a cursor carrying messages.log's identity")
    Do $$$AssertEquals($Select($IsObject(tMoved): tMoved.restarted, 1: ""), 1, "restarts on the rotated file")
}

/// <p>A well-formed name the directory no longer holds is <code>LOG.ABSENT</code>, past the name
/// check.</p>
Method TestARemovedFileIsAbsent()
{
    Set tSC = ##class(OcuPilot.Test.LogSourceFixture).Page("messages", "", "", "", .tResult, .tHttp, .tFault, "messages.old_19990101")
    Do $$$AssertStatusNotOK(tSC, "refused")
    Do $$$AssertEquals(tHttp, 404, "on 404")
    Do $$$AssertEquals(..CodeOf(tFault), "LOG.ABSENT", "on LOG.ABSENT")
}

/// <p>The declared read is unchanged: <method>OcuPilot.Port.LogSourcePort.Rows</method> reads
/// <file>messages.log</file> and no rotated file.</p>
Method TestRowsStillReadsTheCurrentFile()
{
    Set tSC = ##class(OcuPilot.Test.LogSourceFixture).Rows("messages", 10, .tRows, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the rows are served")
    If '$IsObject(tRows) Quit
    Do $$$AssertEquals(tRows.%Size(), 3, "messages.log's three entries")
    Do $$$AssertTrue(tRows.%Get(0).text [ "messages.log line 3", "newest first, from messages.log: " _ tRows.%Get(0).text)
}

}
