/// <p><class>OcuPilot.Port.LogSourcePort</class> at its own API, driven through
/// <class>OcuPilot.Test.LogSourceFixture</class> against a scratch file this class creates,
/// appends to, rotates and removes under
/// <code>&lt;ManagerDirectory&gt;ocupilotlogprobe/</code>.</p>
/// <p><b>The instance's own <file>messages.log</file> is never touched by this class</b> -- not
/// written, not rotated, not removed, not read. The real file is read over HTTP by
/// <class>OcuPilot.Test.LogSourceWire</class>, and the one real rotation this story performs is
/// <class>OcuPilot.Test.LogSourceRotation</class>'s, on a throwaway container.</p>
/// <p>Needs a writable manager directory and nothing else.</p>
Class OcuPilot.Test.LogSource Extends %UnitTest.TestCase
{

/// <p>The scratch root, removed whole in <method>OnAfterAllTests</method>.</p>
Parameter PROBEROOT = "ocupilotlogprobe";

/// <p>The scratch file's name, resolved against whichever scratch directory is armed.</p>
Parameter PROBEFILE = "probe.log";

/// <p>A scratch directory named as a <i>file</i> to the port: it exists, it opens, and the first
/// read of it fails, which is the "present and unreadable" condition DW-19 names.</p>
Parameter PROBENOTAFILE = "notafile";

/// <p>The source key the fixture arms; the port's own, so the production
/// <method>OcuPilot.Port.LogSourcePort.PairsFor</method> answers for it unless a test says
/// otherwise.</p>
Parameter PROBESOURCE = "messages";

/// <p>Every scratch line is exactly this many bytes, newline included, so a window's start and
/// stop land on arithmetic a test can state rather than on whatever the file happens to hold.</p>
Parameter LINEBYTES As INTEGER = 100;

/// <p>How many lines <method>Arm</method> writes: 20 lines of
/// <parameter>LINEBYTES</parameter> bytes, so the scratch file is 2,000 bytes.</p>
Parameter LINECOUNT As INTEGER = 20;

/// <p>The scratch root under the manager directory.</p>
ClassMethod Root() As %String
{
    Quit ##class(%File).NormalizeDirectory(..#PROBEROOT, $System.Util.ManagerDirectory())
}

/// <p>The first scratch directory, which <method>Arm</method> queues.</p>
ClassMethod DirectoryOne() As %String
{
    Quit ##class(%File).NormalizeDirectory("one", ..Root())
}

/// <p>The second scratch directory, queued only by the never-cached test.</p>
ClassMethod DirectoryTwo() As %String
{
    Quit ##class(%File).NormalizeDirectory("two", ..Root())
}

/// <p>Build the scratch tree, <b>root first</b>: <method>%File.NormalizeDirectory</method>
/// resolves a child by entering its parent, so it answers <code>""</code> for a parent that is not
/// there yet -- and a <code>""</code> directory silently resolves every scratch path against the
/// process's own default directory instead. Each level is created and then checked.</p>
Method OnBeforeAllTests() As %Status
{
    Do ##class(%File).RemoveDirectoryTree(..Root())
    Do ##class(%File).CreateDirectoryChain(..Root(), .tRoot)
    If '##class(%File).DirectoryExists(..Root()) Quit $$$ERROR($$$GeneralError, "the scratch root could not be created: " _ ..Root())
    For tDir = ..DirectoryOne(), ..DirectoryTwo() {
        If tDir = "" Quit
        Do ##class(%File).CreateDirectoryChain(tDir, .tMade)
    }
    If (..DirectoryOne() = "") || '##class(%File).DirectoryExists(..DirectoryOne()) Quit $$$ERROR($$$GeneralError, "the scratch directory 'one' could not be created under " _ ..Root())
    If (..DirectoryTwo() = "") || '##class(%File).DirectoryExists(..DirectoryTwo()) Quit $$$ERROR($$$GeneralError, "the scratch directory 'two' could not be created under " _ ..Root())
    Set tNotAFile = ##class(%File).NormalizeDirectory(..#PROBENOTAFILE, ..DirectoryOne())
    Do ##class(%File).CreateDirectoryChain(tNotAFile, .tMadeNotAFile)
    If (tNotAFile = "") || '##class(%File).DirectoryExists(tNotAFile) Quit $$$ERROR($$$GeneralError, "the unreadable-path scratch directory could not be created under " _ ..DirectoryOne())
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Quit ..Arm()
}

/// <p>Remove the scratch tree and every armed answer, and <b>return a failing status</b> if the
/// tree survives: a leaked scratch directory under the manager directory is not caught by
/// <file>ui/tools/ci-runner.mjs</file>'s leftover check, which covers probe web applications
/// only.</p>
Method OnAfterAllTests() As %Status
{
    Do ##class(OcuPilot.Test.LogSourceFixture).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(%File).RemoveDirectoryTree(..Root())
    If ##class(%File).DirectoryExists(..Root()) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LogSource left its scratch directory on the instance: " _ ..Root())
    }
    Quit $$$OK
}

/// <p>Clear every armed answer, queue <method>DirectoryOne</method> as the manager directory,
/// name the scratch file, and write the standard 20-line file into it.</p>
Method Arm() As %Status
{
    Do ##class(OcuPilot.Test.LogSourceFixture).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    ; Queued once: the queue's last entry answers every later call, so one entry points every
    ; call at the same directory and a test that needs a second one appends it.
    Do ##class(OcuPilot.Test.LogSourceFixture).QueueManagerDirectory(..DirectoryOne())
    Do ##class(OcuPilot.Test.LogSourceFixture).SetFile(..#PROBESOURCE, ..#PROBEFILE)
    Quit ..WriteLines(..DirectoryOne(), "alpha", ..#LINECOUNT)
}

/// <p>The exact text of line <var>pIndex</var> tagged <var>pTag</var>, padded to
/// <parameter>LINEBYTES</parameter> minus the newline, so a test states the line it expects
/// rather than recognising one.</p>
ClassMethod LineText(pTag As %String, pIndex As %Integer) As %String
{
    Set tBody = pTag _ " line " _ pIndex
    Quit tBody _ $Justify("", ..#LINEBYTES - 1 - $Length(tBody))
}

/// <p>Write <var>pCount</var> lines tagged <var>pTag</var> as <parameter>PROBEFILE</parameter> in
/// <var>pDirectory</var>, replacing whatever was there.</p>
ClassMethod WriteLines(pDirectory As %String, pTag As %String, pCount As %Integer) As %Status
{
    Set tText = ""
    For tI = 1:1:pCount {
        Set tText = tText _ ..LineText(pTag, tI) _ $Char(10)
    }
    Quit ..WriteFile(##class(%File).NormalizeFilename(..#PROBEFILE, pDirectory), tText)
}

/// <p>Write <var>pContent</var> to <var>pPath</var> as raw bytes, replacing whatever was there.
/// Empty content leaves a <b>zero-byte file that exists</b>: a stream saved with nothing written
/// to it creates no file at all, which is the absent case and not the empty one.</p>
ClassMethod WriteFile(pPath As %String, pContent As %String) As %Status
{
    Do ##class(%File).Delete(pPath)
    If pContent = "" {
        Set tFile = ##class(%File).%New(pPath)
        Set tSC = tFile.Open("WN")
        If $$$ISERR(tSC) Quit tSC
        Do tFile.Close()
        Quit $$$OK
    }
    Set tStream = ##class(%Stream.FileBinary).%New()
    Set tSC = tStream.LinkToFile(pPath)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = tStream.Write(pContent)
    If $$$ISERR(tSC) Quit tSC
    Quit tStream.%Save()
}

/// <p>One call to the port through the fixture.</p>
Method Call(pSource As %String, pOffset As %String, pMaxBytes As %String, pIdentity As %String, Output pResult As %DynamicObject, Output pHttp As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ##class(OcuPilot.Test.LogSourceFixture).Page(pSource, pOffset, pMaxBytes, pIdentity, .pResult, .pHttp, .pFault)
}

/// <p>The failed pair a fault names, or <code>""</code>.</p>
ClassMethod FailedPair(pFault As %DynamicObject) As %String
{
    If '$IsObject(pFault) Quit ""
    If '$IsObject(pFault.%Get("detail")) Quit ""
    Quit pFault.detail.failedPair
}

/// <p>Story 6.13 AC1 -- the <code>alerts</code> key is in the enum, resolves to
/// <code>alerts.log</code> and declares <code>%Admin_Operate:USE</code> alone, the same one pair the
/// screen over it declares: reading a file off disk consults no database resource. The production
/// port is asked, not the fixture, so this is the shipped enum rather than an armed one.</p>
/// <p>Mutation: drop <code>alerts</code> from
/// <parameter>OcuPilot.Port.LogSourcePort.SOURCES</parameter> -&gt; the membership assertion and the
/// live page both go red.</p>
Method TestTheAlertsKeyIsServedFromTheManagerDirectory()
{
    Set tSources = ##class(OcuPilot.Port.LogSourcePort).Sources()
    Do $$$AssertTrue($ListFind(tSources, "alerts") > 0, "the alerts key is in the shipped enum: " _ $ListToString(tSources, ","))
    Do $$$AssertEquals(##class(OcuPilot.Port.LogSourcePort).FileFor("alerts"), "alerts.log", "and resolves to the instance's alert log")

    Set tPairs = ##class(OcuPilot.Port.LogSourcePort).PairsFor("alerts")
    Do $$$AssertEquals($ListLength(tPairs), 1, "one declared pair")
    If $ListLength(tPairs) '= 1 Quit
    Do $$$AssertEquals($ListToString($List(tPairs, 1), ":"), "%Admin_Operate:USE", "the operate pair alone")

    ; An instance that has raised no alert has no alerts.log at all, which is the state a fresh
    ; container is in, so the page is either the file's tail or the named absence -- never anything
    ; else, and never a refusal that fails to name which.
    Set tSC = ##class(OcuPilot.Port.LogSourcePort).Page("alerts", "", 4096, "", .tResult, .tHttp, .tFault)
    Do $$$AssertTrue((tHttp = 200) || (tHttp = 404), "the production port answers the alert log's tail or names its absence: " _ tHttp)
    If tHttp = 200 {
        Do $$$AssertStatusOK(tSC, "the page is served")
        Do $$$AssertEquals($Select($IsObject(tResult): tResult.source, 1: ""), "alerts", "naming the key it was asked for")
        Do $$$AssertTrue($Select($IsObject(tResult): tResult.identity '= "", 1: 0), "and carrying a file identity, which is what the next page's cursor travels with")
    } Else {
        Do $$$AssertEquals($Select($IsObject(tFault): tFault.code, 1: ""), "LOG.ABSENT", "and an instance that has raised no alert is told so by name")
    }

    ; The declared read answers either way: a log the instance has not written yet is an empty
    ; screen, not a failed one.
    Set tSC = ##class(OcuPilot.Port.LogSourcePort).Rows("alerts", 5, .tRows, .tRowHttp, .tRowFault)
    Do $$$AssertStatusOK(tSC, "the declared read over the same key answers")
    Do $$$AssertEquals(tRowHttp, 200, "with 200 whether or not the instance has written the file")
    Do $$$AssertTrue($IsObject(tRows) && tRows.%IsA("%Library.DynamicArray"), "as a list of rows")
}

/// <p>The five scratch lines <method>TestRowsProjectTheTailNewestFirst</method> writes: a leading
/// continuation, a head line with a bracketed category and a continuation of its own, one with no
/// category, one whose text merely contains a bracket, and one whose category is stripped.</p>
ClassMethod GrammarFile() As %String
{
    Set tNl = $Char(10)
    Set tText = "partial tail of an earlier entry" _ tNl
    Set tText = tText _ "09/18/26-04:25:09:123 (1234) 0 [Generic] first entry" _ tNl
    Set tText = tText _ "  continuation of the first" _ tNl
    Set tText = tText _ "09/18/26-04:25:10:456 (5678) 2 severe and unbracketed" _ tNl
    Set tText = tText _ "09/18/26-04:25:11:789 (9012) 7 keeps [a bracket] inside" _ tNl
    Set tText = tText _ "09/18/26-04:25:12:000 (3) 1 [Warn] bracketed category" _ tNl
    Quit tText
}

/// <p>Story 6.13 AC3, AC4 -- <method>OcuPilot.Port.LogSourcePort.Rows</method> projects one window
/// into <code>{time, severity, text}</code> rows newest first: a continuation line folds into the
/// entry above it, a window opening mid-continuation keeps those bytes as an entry with no time and
/// no severity, a severity the vendor's scale does not name survives as its own number, and the
/// bracketed category is stripped only where the client's own optional group would strip it.</p>
/// <p>Newest first is what makes the cap keep the newest entries:
/// <method>OcuPilot.Screen.Read.Execute</method> keeps the first rows it is handed.</p>
/// <p>Mutations: emit the entries in file order in
/// <method>OcuPilot.Port.LogSourcePort.Entries</method> -&gt; the capped call answers the three
/// oldest and the order assertions go red; give each row a fourth key there (AC10) -&gt; the
/// row-key assertion goes red.</p>
Method TestRowsProjectTheTailNewestFirst()
{
    Set tNl = $Char(10)
    Set tSC = ..WriteFile(##class(%File).NormalizeFilename(..#PROBEFILE, ..DirectoryOne()), ..GrammarFile())
    Do $$$AssertStatusOK(tSC, "the grammar scratch file is written")
    If $$$ISERR(tSC) Quit

    Set tSC = ##class(OcuPilot.Test.LogSourceFixture).Rows(..#PROBESOURCE, 3, .tCapped, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the capped call answers")
    Do $$$AssertEquals(tHttp, 200, "with 200")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tCapped.%Size(), 3, "the cap is honoured: " _ tCapped.%Size())
    If tCapped.%Size() '= 3 Quit
    Do $$$AssertEquals(tCapped.%Get(0).time, "2026-09-18T04:25:12.000", "the newest entry is first, its two-digit year pivoted the way IRIS pivots it")
    Do $$$AssertEquals(tCapped.%Get(0).severity, "1", "carrying the vendor's own severity number")
    Do $$$AssertEquals(tCapped.%Get(0).text, "bracketed category", "and its text with the bracketed category stripped")
    Set tKeys = []
    Set tKeyIterator = tCapped.%Get(0).%GetIterator()
    While tKeyIterator.%GetNext(.tKey, .tValue) {
        Do tKeys.%Push(tKey)
    }
    Do $$$AssertEquals(tKeys.%ToJSON(), "[""time"",""severity"",""text""]", "every row carries exactly the three declared keys: " _ tKeys.%ToJSON())
    Do $$$AssertEquals(tCapped.%Get(1).severity, "7", "a severity outside the vendor's scale survives as the number itself")
    Do $$$AssertEquals(tCapped.%Get(1).text, "keeps [a bracket] inside", "and a bracket inside the message is not read as a category")
    Do $$$AssertEquals(tCapped.%Get(2).text, "severe and unbracketed", "the third-newest entry, which declares no category")

    Set tSC = ##class(OcuPilot.Test.LogSourceFixture).Rows(..#PROBESOURCE, 0, .tAll, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "and an uncapped call answers the whole window")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tAll.%Size(), 5, "five entries from six lines, because one line is a continuation: " _ tAll.%Size())
    If tAll.%Size() '= 5 Quit
    Do $$$AssertEquals(tAll.%Get(3).text, "first entry" _ tNl _ "  continuation of the first", "the continuation folds into the entry above it")
    Do $$$AssertEquals(tAll.%Get(4).time, "", "the window opens mid-continuation, so its oldest entry carries no time")
    Do $$$AssertEquals(tAll.%Get(4).severity, "", "and no severity")
    Do $$$AssertEquals(tAll.%Get(4).text, "partial tail of an earlier entry", "while its bytes are kept rather than dropped")
}

/// <p>AC2 -- a key outside <method>OcuPilot.Port.LogSourcePort.Sources</method> is refused 404
/// <code>LOG.SOURCE</code> <b>before the gate and before any file access</b>, even when that key
/// does have a file and a pair set behind it. The counter is what makes "before any file access"
/// an observation: the scratch file is there and nothing looked for it.</p>
/// <p>Mutation: delete the enum check from
/// <method>OcuPilot.Port.LogSourcePort.Page</method> -&gt; the armed key resolves to the scratch
/// file and the call answers 200 with lines, red on the status, on the code and on the
/// counter.</p>
Method TestAnUnknownSourceIsRefusedBeforeAnyFileAccess()
{
    Do ##class(OcuPilot.Test.LogSourceFixture).SetSources(..#PROBESOURCE)
    Do ##class(OcuPilot.Test.LogSourceFixture).SetFile("probe", ..#PROBEFILE)
    Do ##class(OcuPilot.Test.LogSourceFixture).SetPairs("probe", "%Admin_Operate:USE")
    Do ##class(OcuPilot.Test.LogSourceFixture).ClearTouches()

    Set tSC = ..Call("probe", "", "", "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a key outside the enum is refused")
    Do $$$AssertEquals(tHttp, 404, "with 404")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.code, 1: ""), "LOG.SOURCE", "on LOG.SOURCE")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.error, 1: ""), "not_found", "on the not_found slug")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogSourceFixture).Touches(), 0, "and nothing reached the filesystem, though the key's file is there to find")

    ; The file the refused key names really is readable, so the counter reading 0 above is the
    ; enum check refusing and not the scratch file being absent.
    Do ##class(OcuPilot.Test.LogSourceFixture).SetSources("probe")
    Set tSC2 = ..Call("probe", "", "", "", .tResult2, .tHttp2, .tFault2)
    Do $$$AssertStatusOK(tSC2, "the same key inside the enum is served")
    Do $$$AssertEquals(tHttp2, 200, "with 200")
    Do $$$AssertEquals($Select($IsObject(tResult2): tResult2.lines.%Size(), 1: 0), ..#LINECOUNT, "and the scratch file's lines")
}

/// <p>AC4 -- the port evaluates its declared pair set <b>before</b> it resolves, opens or reads
/// anything: a caller holding none of it is refused 403 <code>AUTH.NOPRIVILEGE</code> naming
/// <code>%Admin_Operate:USE</code> with the filesystem untouched, and the same caller holding
/// that one pair is served.</p>
/// <p>The gate is driven through <class>OcuPilot.Test.ScreenGate</class> because
/// <code>%UnitTest</code> runs as an account holding <code>%All</code>, for which the real
/// <code>$System.Security.Check</code> answers yes to everything. The real check is exercised
/// over the wire by <class>OcuPilot.Test.LogSourceDenial</class>.</p>
/// <p>Mutation: move the <method>OcuPilot.Port.LogSourcePort.Gate</method> call below
/// <method>OcuPilot.Port.LogSourcePort.Resolve</method> -&gt; the counter reads 1 where it must
/// read 0. Make <method>OcuPilot.Port.LogSourcePort.Gate</method> answer 1 unconditionally -&gt;
/// the refusal assertions go red.</p>
Method TestNoFileIsOpenedBeforeTheGate()
{
    Do ##class(OcuPilot.Test.LogSourceFixture).SetGateClass("OcuPilot.Test.ScreenGate")
    Do ##class(OcuPilot.Test.LogSourceFixture).ClearTouches()

    Set tSC = ..Call(..#PROBESOURCE, "", "", "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a caller holding none of the pair set is refused")
    Do $$$AssertEquals(tHttp, 403, "with 403")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.code, 1: ""), "AUTH.NOPRIVILEGE", "on AUTH.NOPRIVILEGE")
    Do $$$AssertEquals(..FailedPair(tFault), "%Admin_Operate:USE", "naming the pair that failed")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogSourceFixture).Touches(), 0, "and no file was resolved, opened or read")

    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Operate", "USE")
    Do ##class(OcuPilot.Test.LogSourceFixture).ClearTouches()
    Set tSC2 = ..Call(..#PROBESOURCE, "", "", "", .tResult2, .tHttp2, .tFault2)
    Do $$$AssertStatusOK(tSC2, "the same caller holding that one pair is served")
    Do $$$AssertEquals(tHttp2, 200, "with 200")
    Do $$$AssertTrue(##class(OcuPilot.Test.LogSourceFixture).Touches() > 0, "and the file was reached only then")
}

/// <p>AC4 -- a source whose declared pair set is <b>empty</b> is refused rather than admitted.
/// An empty set is held by everyone
/// (<method>OcuPilot.Screen.Gate.EvaluatePairs</method>), so a port that handed it to the gate
/// would serve a log to a caller no requirement was ever stated for.</p>
/// <p>The gate is armed holding <code>%Admin_Operate:USE</code>, so the 403 here cannot be a
/// failed pair check: with a non-empty set this caller is served.</p>
/// <p>Mutation: delete the empty-pair-set refusal from
/// <method>OcuPilot.Port.LogSourcePort.Page</method> -&gt; the gate holds the empty set and the
/// call answers 200, red on the status and the code.</p>
Method TestASourceWithNoDeclaredPairIsRefusedNotAdmitted()
{
    Do ##class(OcuPilot.Test.LogSourceFixture).SetGateClass("OcuPilot.Test.ScreenGate")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Operate", "USE")
    Do ##class(OcuPilot.Test.LogSourceFixture).SetPairs(..#PROBESOURCE, "")
    Do ##class(OcuPilot.Test.LogSourceFixture).ClearTouches()

    Set tSC = ..Call(..#PROBESOURCE, "", "", "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a source with no declared pair is refused")
    Do $$$AssertEquals(tHttp, 403, "with 403")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.code, 1: ""), "AUTH.NOPRIVILEGE", "on AUTH.NOPRIVILEGE")
    Do $$$AssertEquals(..FailedPair(tFault), "", "naming no pair, because there is no requirement to report")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogSourceFixture).Touches(), 0, "and nothing reached the filesystem")

    ; The same caller and the same gate, with one pair declared: served. So the refusal above is
    ; the empty set and not this principal.
    Do ##class(OcuPilot.Test.LogSourceFixture).SetPairs(..#PROBESOURCE, "%Admin_Operate:USE")
    Set tSC2 = ..Call(..#PROBESOURCE, "", "", "", .tResult2, .tHttp2, .tFault2)
    Do $$$AssertStatusOK(tSC2, "one declared pair this caller holds is served")
    Do $$$AssertEquals(tHttp2, 200, "with 200")
}

/// <p>AC3 (fast witness) -- a cursor held across a rotation restarts at byte 1 of the file that
/// is there now. The scratch file is genuinely rotated: renamed away and a new one created whose
/// first bytes differ, which is the shape IRIS's own rotation takes.</p>
/// <p>The held cursor is asserted to be a position <b>inside</b> the rotated-in file before the
/// restart is, so the identity is the only thing that can have restarted this page and the
/// <code>offset &gt; size + 1</code> condition cannot pass for it. Without that assertion the
/// isolation would rest on the two files happening to be the same length.</p>
/// <p>Mutation: make <method>OcuPilot.Port.LogSourcePort.Identity</method> answer a constant
/// -&gt; the held identity matches, the page is served from the held offset, and both the
/// <code>restarted</code> and first-line assertions go red.</p>
Method TestARotationRestartsThePage()
{
    Set tSC = ..Call(..#PROBESOURCE, "", 250, "", .tFirst, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the first page is served")
    Do $$$AssertEquals(tHttp, 200, "with 200")
    If tHttp '= 200 Quit
    Set tHeldOffset = tFirst.offset
    Set tHeldIdentity = tFirst.identity
    Do $$$AssertTrue(tHeldOffset > 1, "and a cursor past the start of the file: " _ tHeldOffset)

    ; Rotate: the old file is renamed away and a new one created, exactly as IRIS rotates its own.
    Do ##class(%File).Rename(##class(%File).NormalizeFilename(..#PROBEFILE, ..DirectoryOne()), ##class(%File).NormalizeFilename("probe.old", ..DirectoryOne()))
    Set tWriteSC = ..WriteLines(..DirectoryOne(), "bravo", ..#LINECOUNT)
    Do $$$AssertStatusOK(tWriteSC, "the rotated-in file is written")

    Set tSC2 = ..Call(..#PROBESOURCE, tHeldOffset, 250, tHeldIdentity, .tSecond, .tHttp2, .tFault2)
    Do $$$AssertStatusOK(tSC2, "the held cursor is answered, not refused")
    Do $$$AssertEquals(tHttp2, 200, "with 200")
    If tHttp2 '= 200 Quit
    Do $$$AssertNotEquals(tSecond.identity, tHeldIdentity, "the file's identity moved, which is the precondition this test needs")
    Do $$$AssertTrue(tHeldOffset <= (tSecond.size + 1), "the held cursor is still a position inside the rotated-in file, so only its identity can restart this page: offset " _ tHeldOffset _ " against size " _ tSecond.size)
    Do $$$AssertEquals(tSecond.restarted, 1, "the page restarted")
    Do $$$AssertTrue(tSecond.lines.%Size() > 0, "and served lines: " _ tSecond.lines.%Size())
    If tSecond.lines.%Size() = 0 Quit
    Do $$$AssertEquals(tSecond.lines.%Get(0), ..LineText("bravo", 1), "from byte 1 of the file that is there now")
}

/// <p>AC3 -- an offset past the current end restarts <b>on its own</b>, with the identity still
/// matching, and an offset of exactly <code>size + 1</code> -- a reader that has caught up -- does
/// not. Two adjacent offsets, one either side of the boundary, so the condition cannot be
/// satisfied by an off-by-one that restarts everything.</p>
/// <p>Mutation: drop the <code>offset &gt; size + 1</code> condition from
/// <method>OcuPilot.Port.LogSourcePort.Page</method> -&gt; the past-the-end call answers
/// <code>restarted</code> 0 with no lines and this goes red, while
/// <method>TestARotationRestartsThePage</method> stays green, so neither condition can pass for
/// the other's reason.</p>
Method TestAnOffsetPastTheEndRestarts()
{
    Set tSC = ..Call(..#PROBESOURCE, "", 250, "", .tFirst, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the first page is served")
    Do $$$AssertEquals(tHttp, 200, "with 200")
    If tHttp '= 200 Quit
    Set tIdentity = tFirst.identity
    Set tSize = tFirst.size
    Do $$$AssertEquals(tSize, ..#LINECOUNT * ..#LINEBYTES, "the scratch file is the size this test computes from")

    Set tSC2 = ..Call(..#PROBESOURCE, tSize + 2, 250, tIdentity, .tPast, .tHttp2, .tFault2)
    Do $$$AssertStatusOK(tSC2, "an offset past the end is answered")
    Do $$$AssertEquals(tHttp2, 200, "with 200")
    If tHttp2 '= 200 Quit
    Do $$$AssertEquals(tPast.identity, tIdentity, "the identity still matches, so nothing but the offset can have restarted it")
    Do $$$AssertEquals(tPast.restarted, 1, "and the page restarted")
    Do $$$AssertEquals(tPast.lines.%Get(0), ..LineText("alpha", 1), "from byte 1")

    Set tSC3 = ..Call(..#PROBESOURCE, tSize + 1, 250, tIdentity, .tCaughtUp, .tHttp3, .tFault3)
    Do $$$AssertStatusOK(tSC3, "an offset of exactly size + 1 is answered")
    Do $$$AssertEquals(tHttp3, 200, "with 200")
    If tHttp3 '= 200 Quit
    Do $$$AssertEquals(tCaughtUp.restarted, 0, "a reader that has caught up has not restarted")
    Do $$$AssertEquals(tCaughtUp.lines.%Size(), 0, "and is served nothing new")
    Do $$$AssertEquals(tCaughtUp.offset, tSize + 1, "with its cursor where it left it")
}

/// <p>AC6 (DW-19) -- an absent file is a <b>named refusal</b>, 404 <code>LOG.ABSENT</code>, and
/// not a 200 with no lines. Paired with
/// <method>TestAnEmptyFileIsTwoHundredWithNoLines</method>, which is the 200 with no lines: either
/// assertion alone would survive folding the two answers together.</p>
/// <p>Mutation: answer the absent branch of
/// <method>OcuPilot.Port.LogSourcePort.Resolve</method> with a 200 carrying zero lines -&gt; red
/// on the status and on the code.</p>
Method TestAnAbsentSourceIsANamedRefusalNotAnEmptyPage()
{
    Do ##class(%File).Delete(##class(%File).NormalizeFilename(..#PROBEFILE, ..DirectoryOne()))
    Do $$$AssertEquals(##class(%File).Exists(##class(%File).NormalizeFilename(..#PROBEFILE, ..DirectoryOne())), 0, "the scratch file really is gone")

    Set tSC = ..Call(..#PROBESOURCE, "", "", "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "an absent source is refused")
    Do $$$AssertEquals(tHttp, 404, "with 404")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.code, 1: ""), "LOG.ABSENT", "on LOG.ABSENT")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.error, 1: ""), "not_found", "on the not_found slug")
    Do $$$AssertEquals($IsObject($Get(tResult)), 0, "and no page comes back with it")
    Do $$$AssertEquals(($Select($IsObject(tFault): tFault.reason, 1: "") [ ..Root()), 0, "the resolved path is never echoed back")
}

/// <p>AC6 -- a file that exists and holds nothing is a 200 with an empty page, a cursor at byte 1
/// and no restart. See <method>TestAnAbsentSourceIsANamedRefusalNotAnEmptyPage</method> for the
/// other half of the pair.</p>
/// <p>Mutation: answer the absent branch of
/// <method>OcuPilot.Port.LogSourcePort.Resolve</method> with a 200 carrying zero lines -&gt; that
/// test goes red while this one stays green, which is what makes the two answers distinct rather
/// than merely both asserted.</p>
Method TestAnEmptyFileIsTwoHundredWithNoLines()
{
    Set tWriteSC = ..WriteFile(##class(%File).NormalizeFilename(..#PROBEFILE, ..DirectoryOne()), "")
    Do $$$AssertStatusOK(tWriteSC, "the empty scratch file is written")

    Set tSC = ..Call(..#PROBESOURCE, "", "", "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "an empty file is served")
    Do $$$AssertEquals(tHttp, 200, "with 200")
    If tHttp '= 200 Quit
    Do $$$AssertEquals(tResult.size, 0, "the file is empty")
    Do $$$AssertEquals(tResult.lines.%Size(), 0, "the page carries no lines")
    Do $$$AssertEquals(tResult.offset, 1, "the cursor is at byte 1")
    Do $$$AssertEquals(tResult.restarted, 0, "nothing restarted")
    Do $$$AssertEquals(tResult.truncated, 0, "and nothing was cut")
    Do $$$AssertEquals($Length(tResult.identity), 44, "an empty file still has an identity: " _ tResult.identity)
}

/// <p>AC6 (DW-19) -- a source that is present and cannot be read is 503
/// <code>LOG.UNREADABLE</code>, told apart from the absent 404 above. The scratch path is a
/// directory: it exists, the open succeeds, and the first read of it fails, which is exactly the
/// shape a file the instance may not read takes.</p>
/// <p>Mutation: make <method>OcuPilot.Port.LogSourcePort.ReadBytes</method> answer
/// <code>$$$OK</code> on a failed read -&gt; the identity reads as the empty file's, the window
/// comes back empty, and the call answers 200 with no lines; red on the status and the code.</p>
Method TestAnUnreadableSourceIsUnavailable()
{
    Do ##class(OcuPilot.Test.LogSourceFixture).SetFile(..#PROBESOURCE, ..#PROBENOTAFILE)
    Set tPath = ##class(%File).NormalizeFilename(..#PROBENOTAFILE, ..DirectoryOne())
    Do $$$AssertEquals(##class(%File).Exists(tPath), 1, "the path is present, so this is not the absent branch")
    ; The preconditions this leg needs, stated rather than assumed: the path opens, and it reports
    ; a size, so the port reaches a read rather than taking the empty-file path to a 200.
    Set tProbe = ##class(%Stream.FileBinary).%New()
    Do $$$AssertStatusOK(tProbe.LinkToFile(tPath), "the path opens")
    Do $$$AssertTrue(tProbe.Size > 0, "and reports a size: " _ tProbe.Size)
    Set tProbe = ""

    Set tSC = ..Call(..#PROBESOURCE, "", "", "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a present but unreadable source is refused")
    Do $$$AssertEquals(tHttp, 503, "with 503")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.code, 1: ""), "LOG.UNREADABLE", "on LOG.UNREADABLE")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.error, 1: ""), "unavailable", "on the unavailable slug")
    Do $$$AssertEquals($IsObject($Get(tResult)), 0, "and no page comes back with it")
}

/// <p>AC2 -- the manager directory is resolved on <b>every</b> call and nothing carries over from
/// the previous one. Two scratch directories hold two different files under the same name; the
/// fixture answers the first directory once and the second afterwards, and the two calls serve
/// the two files.</p>
/// <p>Mutation: cache the resolved directory in a process-private global on the first call in
/// <method>OcuPilot.Port.LogSourcePort.Resolve</method> -&gt; the second call serves the first
/// directory's file and the <code>charlie</code> assertion goes red.</p>
Method TestTheManagerDirectoryIsResolvedOnEveryCall()
{
    Set tWriteSC = ..WriteLines(..DirectoryTwo(), "charlie", ..#LINECOUNT)
    Do $$$AssertStatusOK(tWriteSC, "the second directory's file is written")
    Do ##class(OcuPilot.Test.LogSourceFixture).QueueManagerDirectory(..DirectoryTwo())

    Set tSC = ..Call(..#PROBESOURCE, "", 250, "", .tOne, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the first call is served")
    Do $$$AssertEquals(tHttp, 200, "with 200")
    If tHttp '= 200 Quit
    Do $$$AssertEquals(tOne.lines.%Get(0), ..LineText("alpha", ..#LINECOUNT - 1), "from the first directory's file")

    Set tSC2 = ..Call(..#PROBESOURCE, "", 250, "", .tTwo, .tHttp2, .tFault2)
    Do $$$AssertStatusOK(tSC2, "the second call is served")
    Do $$$AssertEquals(tHttp2, 200, "with 200")
    If tHttp2 '= 200 Quit
    Do $$$AssertEquals(tTwo.lines.%Get(0), ..LineText("charlie", ..#LINECOUNT - 1), "from the second directory's file, which only a fresh resolution reaches")
    Do $$$AssertNotEquals(tTwo.identity, tOne.identity, "and the two files are told apart by identity as well")
}

/// <p>AC1 -- a window that begins mid-line discards to the next newline. The scratch file is 20
/// lines of exactly 100 bytes, so a 250-byte tail window starts at byte 1,751, inside line 18,
/// and the whole lines inside it are 19 and 20 -- stated here rather than recognised.</p>
/// <p>Mutation: delete the mid-line discard from
/// <method>OcuPilot.Port.LogSourcePort.ReadWindow</method> -&gt; the first line served is the
/// tail of line 18 and both the count and the first-line assertions go red.</p>
Method TestAWindowThatStartsMidLineDiscardsToTheNextNewline()
{
    Set tSC = ..Call(..#PROBESOURCE, "", 250, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the tail page is served")
    Do $$$AssertEquals(tHttp, 200, "with 200")
    If tHttp '= 200 Quit
    Do $$$AssertEquals(tResult.size, 2000, "the scratch file is 2,000 bytes, which is what the arithmetic below assumes")
    Do $$$AssertEquals(tResult.lines.%Size(), 2, "two whole lines fit the 250-byte tail window")
    If tResult.lines.%Size() '= 2 Quit
    Do $$$AssertEquals(tResult.lines.%Get(0), ..LineText("alpha", 19), "the first is line 19 whole, not the tail of line 18")
    Do $$$AssertEquals(tResult.lines.%Get(1), ..LineText("alpha", 20), "and the second is line 20")
    Do $$$AssertEquals(tResult.offset, 2001, "the cursor is one past the end of the file")
    Do $$$AssertEquals(tResult.truncated, 0, "and the page reached the end")
}

/// <p>AC1 -- a window that stops mid-line drops the partial tail and points its cursor at that
/// tail's first byte, so the next page serves the line whole. A 250-byte window from byte 1 holds
/// lines 1 and 2 and half of line 3.</p>
/// <p>Mutation: delete the partial-tail drop from
/// <method>OcuPilot.Port.LogSourcePort.ReadWindow</method> -&gt; a third, half-length line is
/// served and the count, cursor and continuation assertions go red.</p>
Method TestAWindowThatStopsMidLineDropsThePartialTail()
{
    Set tSC = ..Call(..#PROBESOURCE, "", 250, "", .tTail, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the tail page is served, for its identity")
    If tHttp '= 200 Quit
    Set tIdentity = tTail.identity

    Set tSC2 = ..Call(..#PROBESOURCE, 1, 250, tIdentity, .tResult, .tHttp2, .tFault2)
    Do $$$AssertStatusOK(tSC2, "the page from byte 1 is served")
    Do $$$AssertEquals(tHttp2, 200, "with 200")
    If tHttp2 '= 200 Quit
    Do $$$AssertEquals(tResult.restarted, 0, "the identity matched, so nothing restarted")
    Do $$$AssertEquals(tResult.lines.%Size(), 2, "two whole lines fit in 250 bytes; the third is cut and dropped")
    If tResult.lines.%Size() '= 2 Quit
    Do $$$AssertEquals(tResult.lines.%Get(0), ..LineText("alpha", 1), "line 1 whole")
    Do $$$AssertEquals(tResult.lines.%Get(1), ..LineText("alpha", 2), "line 2 whole")
    Do $$$AssertEquals(tResult.offset, 201, "the cursor points at the dropped line's first byte")
    Do $$$AssertEquals(tResult.truncated, 1, "and the page reports that it did not reach the end")

    Set tSC3 = ..Call(..#PROBESOURCE, tResult.offset, 250, tIdentity, .tNext, .tHttp3, .tFault3)
    Do $$$AssertStatusOK(tSC3, "the next page is served")
    If tHttp3 '= 200 Quit
    Do $$$AssertEquals(tNext.lines.%Get(0), ..LineText("alpha", 3), "and it serves the dropped line whole")
}

/// <p>AC1 -- <code>maxBytes</code> is refused outside the cap rather than clamped and served, and
/// the cap it is measured against is <method>OcuPilot.Port.LogSourcePort.MaxBytesCap</method>'s
/// answer rather than a value declared somewhere else: the fixture lowers it to 100 and the
/// refusal boundary moves with it.</p>
/// <p>Mutation: clamp a <code>maxBytes</code> above the cap and serve it -&gt; every refusal
/// assertion goes red.</p>
Method TestAMaxBytesOutsideTheCapIsRefused()
{
    Do ##class(OcuPilot.Test.LogSourceFixture).SetMaxBytesCap(100)
    For tBad = 101, 0, -1, "abc", "12.5", " " {
        Set tSC = ..Call(..#PROBESOURCE, "", tBad, "", .tResult, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, "maxBytes '" _ tBad _ "' is refused")
        Do $$$AssertEquals(tHttp, 400, "maxBytes '" _ tBad _ "': with 400")
        Do $$$AssertEquals($Select($IsObject(tFault): tFault.code, 1: ""), "LOG.MAXBYTES", "maxBytes '" _ tBad _ "': on LOG.MAXBYTES")
        Do $$$AssertEquals($IsObject($Get(tResult)), 0, "maxBytes '" _ tBad _ "': and no page is served with it")
    }

    Set tSC2 = ..Call(..#PROBESOURCE, "", 100, "", .tAtCap, .tHttp2, .tFault2)
    Do $$$AssertStatusOK(tSC2, "maxBytes at the cap is served")
    Do $$$AssertEquals(tHttp2, 200, "with 200")
    If tHttp2 '= 200 Quit
    Do $$$AssertEquals(tAtCap.lines.%Size(), 1, "one 100-byte line fits a 100-byte window")
    Do $$$AssertEquals(tAtCap.lines.%Get(0), ..LineText("alpha", ..#LINECOUNT), "and it is the file's last line")
}

/// <p>AC2 -- half a cursor is refused before the file is opened: an <code>offset</code> without
/// its <code>identity</code>, an <code>identity</code> without its <code>offset</code>, and an
/// offset that is not a whole number from one upwards.</p>
/// <p>Mutation: drop the paired check from
/// <method>OcuPilot.Port.LogSourcePort.Page</method> -&gt; an offset with no identity is read as
/// a cursor whose identity never matches, the call restarts and answers 200, and the first two
/// legs go red.</p>
Method TestHalfACursorIsRefused()
{
    For tCase = "offset", "identity", "zero", "negative", "text" {
        Set tOffset = $Case(tCase, "offset": 1, "identity": "", "zero": 0, "negative": -5, : "abc")
        Set tIdentity = $Case(tCase, "offset": "", : "an-identity")
        Do ##class(OcuPilot.Test.LogSourceFixture).ClearTouches()
        Set tSC = ..Call(..#PROBESOURCE, tOffset, "", tIdentity, .tResult, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, tCase _ ": the cursor is refused")
        Do $$$AssertEquals(tHttp, 400, tCase _ ": with 400")
        Do $$$AssertEquals($Select($IsObject(tFault): tFault.code, 1: ""), "LOG.OFFSET", tCase _ ": on LOG.OFFSET")
        Do $$$AssertEquals(##class(OcuPilot.Test.LogSourceFixture).Touches(), 0, tCase _ ": before the file was opened")
    }
}

/// <p>AC3 -- a file <b>smaller than the hashed prefix</b> keeps its identity while it is appended
/// to, so a cursor held across an append is a continuation and not a restart. That is the state a
/// console log is in for the seconds after a rotation, which is the one this endpoint exists to
/// survive: an identity that moved with every append would restart every poll in exactly that
/// window.</p>
/// <p>The file written here is three lines -- 300 bytes against a 512-byte prefix -- so the
/// appended bytes are inside the region the identity is taken from, which is what makes this
/// falsifiable rather than a restatement of "the prefix did not change".</p>
/// <p>Mutation: hash <code>tPrefix</code> whole instead of its first line in
/// <method>OcuPilot.Port.LogSourcePort.Identity</method> -&gt; the appended line changes the
/// hashed bytes, the identity moves and both the identity and the <code>restarted</code>
/// assertions go red.</p>
Method TestAShortFileKeepsItsIdentityAcrossAnAppend()
{
    Set tShortLines = 3
    Set tWriteSC = ..WriteLines(..DirectoryOne(), "alpha", tShortLines)
    Do $$$AssertStatusOK(tWriteSC, "the short scratch file is written")

    Set tSC = ..Call(..#PROBESOURCE, "", 250, "", .tFirst, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the first page is served")
    Do $$$AssertEquals(tHttp, 200, "with 200")
    If tHttp '= 200 Quit
    Do $$$AssertTrue(tFirst.size < 512, "the file is smaller than the hashed prefix, which is the state this test is about: " _ tFirst.size)
    Set tHeldIdentity = tFirst.identity
    Set tHeldOffset = tFirst.offset

    ; The same three lines plus a fourth -- byte-for-byte what an append leaves behind, written
    ; the one way this class writes files.
    Set tAppendSC = ..WriteLines(..DirectoryOne(), "alpha", tShortLines + 1)
    Do $$$AssertStatusOK(tAppendSC, "a fourth line is added")

    Set tSC2 = ..Call(..#PROBESOURCE, tHeldOffset, 250, tHeldIdentity, .tSecond, .tHttp2, .tFault2)
    Do $$$AssertStatusOK(tSC2, "the held cursor is answered")
    Do $$$AssertEquals(tHttp2, 200, "with 200")
    If tHttp2 '= 200 Quit
    Do $$$AssertTrue(tSecond.size > tFirst.size, "the file really did grow: " _ tFirst.size _ " to " _ tSecond.size)
    Do $$$AssertEquals(tSecond.identity, tHeldIdentity, "the identity did not move with the append")
    Do $$$AssertEquals(tSecond.restarted, 0, "so the held cursor continued rather than restarting")
    Do $$$AssertEquals(tSecond.lines.%Get(0), ..LineText("alpha", tShortLines + 1), "and the appended line is what it served")
}

/// <p>AC3 -- the identity token is spendable as a query value <b>as it is handed back</b>: it
/// carries only characters a query string leaves alone. Standard Base64's <code>+</code> decodes
/// to a space in a query string, so a token carrying one would restart a caller that echoed it
/// verbatim -- and every wire test percent-encodes it, so no wire assertion can see that.</p>
/// <p>Mutation: drop the <code>$Translate</code> from
/// <method>OcuPilot.Port.LogSourcePort.Identity</method> -&gt; roughly nine tokens in ten carry a
/// <code>+</code> or a <code>/</code> and this goes red. The loop runs the file through enough
/// distinct contents that a single lucky hash cannot carry it.</p>
Method TestTheIdentityTokenIsSpendableAsAQueryValue()
{
    Set tBad = ""
    Set tSeen = 0
    For tI = 1:1:24 {
        Set tWriteSC = ..WriteLines(..DirectoryOne(), "tag" _ tI, 2)
        Do $$$AssertStatusOK(tWriteSC, "scratch file " _ tI _ " is written")
        Set tSC = ..Call(..#PROBESOURCE, "", 250, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp, 200, "page " _ tI _ " answers")
        If tHttp '= 200 Quit
        Set tSeen = tSeen + 1
        Set tToken = tResult.identity
        Do $$$AssertEquals($Length(tToken), 44, "page " _ tI _ ": the token is 44 characters: " _ tToken)
        If $Match(tToken, "^[A-Za-z0-9_-]+=*$") Continue
        If tBad = "" Set tBad = "page " _ tI _ " carries a character a query string does not leave alone: " _ tToken
    }
    Do $$$AssertEquals(tSeen, 24, "every one of the twenty-four files was paged")
    Do $$$AssertEquals(tBad, "", "every identity token is spendable as a query value unencoded")
}

/// <p>AC1 -- a window narrower than the line it lands in serves nothing, says so, and still moves
/// the cursor forward, so a reader cannot loop on it. The port cannot serve half a line without
/// breaking the whole-lines contract, so the only thing that makes this survivable is that the
/// cursor advances and <code>truncated</code> is true.</p>
/// <p>Mutation: leave <var>pNextOffset</var> where it was in
/// <method>OcuPilot.Port.LogSourcePort.ReadWindow</method>'s no-newline branches -&gt; the second
/// call is answered the same empty page from the same offset and the progress assertions go
/// red. Drop either <code>Set pTruncated = 1</code> -&gt; the page claims it reached the end of a
/// 2,000-byte file it is 40 bytes into.</p>
Method TestAWindowNarrowerThanOneLineStillMovesForward()
{
    Set tNarrow = 40
    Do $$$AssertTrue(tNarrow < ..#LINEBYTES, "the window is narrower than a line, which is what this test is about")

    Set tSC = ..Call(..#PROBESOURCE, "", 250, "", .tTail, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the tail page is served, for its identity")
    If tHttp '= 200 Quit
    Set tIdentity = tTail.identity

    Set tSC2 = ..Call(..#PROBESOURCE, 1, tNarrow, tIdentity, .tFirst, .tHttp2, .tFault2)
    Do $$$AssertStatusOK(tSC2, "a window narrower than a line is answered, not refused")
    Do $$$AssertEquals(tHttp2, 200, "with 200")
    If tHttp2 '= 200 Quit
    Do $$$AssertEquals(tFirst.lines.%Size(), 0, "no partial line is served")
    Do $$$AssertEquals(tFirst.truncated, 1, "the page says it did not reach the end")
    Do $$$AssertTrue(tFirst.offset > 1, "and the cursor moved forward: " _ tFirst.offset)

    Set tSC3 = ..Call(..#PROBESOURCE, tFirst.offset, tNarrow, tIdentity, .tSecond, .tHttp3, .tFault3)
    Do $$$AssertStatusOK(tSC3, "the returned cursor is answered")
    If tHttp3 '= 200 Quit
    Do $$$AssertTrue(tSecond.offset > tFirst.offset, "and moves forward again rather than standing still: " _ tSecond.offset _ " after " _ tFirst.offset)

    ; The same reader, widened once: the line the narrow windows could not carry comes back whole,
    ; so "nothing served" above is the window's doing and not the file's.
    Set tSC4 = ..Call(..#PROBESOURCE, 1, ..#LINEBYTES, tIdentity, .tWide, .tHttp4, .tFault4)
    Do $$$AssertStatusOK(tSC4, "a window one line wide is answered")
    If tHttp4 '= 200 Quit
    Do $$$AssertEquals(tWide.lines.%Size(), 1, "and carries the whole line the narrow windows could not")
    Do $$$AssertEquals(tWide.lines.%Get(0), ..LineText("alpha", 1), "which is line 1")
}

/// <p>AC2 -- a key the enum carries but this port has no file for is refused 404
/// <code>LOG.SOURCE</code>, the second of the two places that code is raised. The first is
/// <method>OcuPilot.Port.LogSourcePort.Page</method>'s enum check; this one is
/// <method>OcuPilot.Port.LogSourcePort.Resolve</method>'s, which is the branch Story 2.12 reaches
/// when it adds a source key ahead of the file behind it.</p>
/// <p>The gate is armed and held first, so the refusal here is the missing file and not a
/// privilege.</p>
/// <p>Mutation: answer the resolved directory's own name for a key with no file in
/// <method>OcuPilot.Port.LogSourcePort.Resolve</method> -&gt; the refusal becomes
/// <code>LOG.ABSENT</code> and the code assertion goes red.</p>
Method TestAnEnumKeyWithNoFileIsRefused()
{
    Do ##class(OcuPilot.Test.LogSourceFixture).SetSources(..#PROBESOURCE _ ",filelesskey")
    Do ##class(OcuPilot.Test.LogSourceFixture).SetPairs("filelesskey", "%Admin_Operate:USE")
    Do ##class(OcuPilot.Test.LogSourceFixture).SetFile("filelesskey", "")
    Do ##class(OcuPilot.Test.LogSourceFixture).SetGateClass("OcuPilot.Test.ScreenGate")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Operate", "USE")

    Set tSC = ..Call("filelesskey", "", "", "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a key in the enum with no file behind it is refused")
    Do $$$AssertEquals(tHttp, 404, "with 404")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.code, 1: ""), "LOG.SOURCE", "on LOG.SOURCE and not LOG.ABSENT")
    Do $$$AssertEquals($IsObject($Get(tResult)), 0, "and no page comes back with it")

    ; The same key with a file behind it, same gate, same caller: served. So the refusal above is
    ; the missing file and nothing else.
    Do ##class(OcuPilot.Test.LogSourceFixture).SetFile("filelesskey", ..#PROBEFILE)
    Set tSC2 = ..Call("filelesskey", "", "", "", .tServed, .tHttp2, .tFault2)
    Do $$$AssertStatusOK(tSC2, "the same key with a file behind it is served")
    Do $$$AssertEquals(tHttp2, 200, "with 200")
}

}
