/// <p>The live log tail at the port's own API (Story 18.38): <method>OcuPilot.Port.LogSourcePort.Tail</method>
/// driven through <class>OcuPilot.Test.LogSourceFixture</class> over a scratch file this class owns under
/// <code>&lt;ManagerDirectory&gt;ocupilotlogtail/</code>, with the tail held for
/// <parameter>BOUND</parameter> seconds, looking every <parameter>CHECK</parameter> and beating every
/// <parameter>BEAT</parameter>. One row of the story's matrix per test.</p>
/// <p>This class is the heartbeat the port calls (<method>Heartbeat</method>): it counts each beat, and
/// can be armed to fail or throw as a gone client does. A writer job of its own appends to, replaces or
/// briefly removes the scratch file while a tail waits, and is stopped in <method>OnAfterOneTest</method>.
/// The instance's own console log is never written, rotated or removed here.</p>
/// <p>Needs a writable manager directory and a running principal holding <code>%Admin_Operate:USE</code>,
/// which the port's own gate checks on every call this class does not arm a stand-in gate for; the longest
/// test holds one tail to the bound.</p>
Class OcuPilot.Test.LogTail Extends %UnitTest.TestCase
{

/// <p>The scratch root, removed whole in <method>OnAfterAllTests</method>.</p>
Parameter PROBEROOT = "ocupilotlogtail";

/// <p>The scratch file's name.</p>
Parameter PROBEFILE = "tail.log";

/// <p>The source key the fixture arms: a tail source of the shipped port.</p>
Parameter PROBESOURCE = "messages";

/// <p>The longest a tail is held in these tests, in seconds.</p>
Parameter BOUND = 3;

/// <p>The pause between two looks at the file, in seconds.</p>
Parameter CHECK = 0.2;

/// <p>The pause between two heartbeats, in seconds.</p>
Parameter BEAT = 1;

/// <p>The writer job's pid, or <code>""</code>.</p>
Property PreparedWriter As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedWriter = ""
    Quit $$$OK
}

/// <p>The scratch directory.</p>
ClassMethod Directory() As %String
{
    Quit ##class(%File).NormalizeDirectory(..#PROBEROOT, $System.Util.ManagerDirectory())
}

/// <p>The scratch file's path.</p>
ClassMethod Path() As %String
{
    Quit ##class(%File).NormalizeFilename(..#PROBEFILE, ..Directory())
}

Method OnBeforeAllTests() As %Status
{
    Do ##class(%File).RemoveDirectoryTree(..Directory())
    Do ##class(%File).CreateDirectoryChain(..Directory(), .tMade)
    If '##class(%File).DirectoryExists(..Directory()) Quit $$$ERROR($$$GeneralError, "the scratch directory could not be created: " _ ..Directory())
    Quit $$$OK
}

/// <p>Remove the scratch directory and every armed answer, and fail if the directory survives.</p>
Method OnAfterAllTests() As %Status
{
    Do ##class(OcuPilot.Test.LogSourceFixture).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(%File).RemoveDirectoryTree(..Directory())
    If ##class(%File).DirectoryExists(..Directory()) Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LogTail left its scratch directory on the instance: " _ ..Directory())
    Quit $$$OK
}

/// <p>Arm the fixture on the scratch directory with the bound, check and beat seconds, write the standard
/// 20-line file and reset the beat counter.</p>
Method OnBeforeOneTest() As %Status
{
    Set ..PreparedWriter = ""
    Kill ^||OcuPilotLogTail
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ..Rearm()
    Quit ..WriteTag("alpha", 20)
}

/// <p>Forget every armed answer and arm the fixture on the scratch directory again, leaving the file and the
/// beat counter as they are.</p>
Method Rearm()
{
    Do ##class(OcuPilot.Test.LogSourceFixture).Clear()
    Do ##class(OcuPilot.Test.LogSourceFixture).QueueManagerDirectory(..Directory())
    Do ##class(OcuPilot.Test.LogSourceFixture).SetFile(..#PROBESOURCE, ..#PROBEFILE)
    Do ##class(OcuPilot.Test.LogSourceFixture).SetTail(..#BOUND, ..#CHECK, ..#BEAT)
}

/// <p>Stop the writer job if it is still running, and forget every armed answer.</p>
Method OnAfterOneTest() As %Status
{
    If (..PreparedWriter '= "") && $Data(^$JOB(..PreparedWriter)) Do $System.Process.Terminate(..PreparedWriter)
    Set ..PreparedWriter = ""
    Kill ^||OcuPilotLogTail
    Do ##class(OcuPilot.Test.LogSourceFixture).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Quit $$$OK
}

/// <p>The heartbeat the port runs while a tail waits: counts the beat, then answers as
/// <code>^||OcuPilotLogTail("mode")</code> says -- <code>""</code> a healthy client, <code>fail</code> a
/// write that reports an error, <code>throw</code> a write that throws.</p>
ClassMethod Heartbeat() As %Status
{
    Set ^||OcuPilotLogTail("beats") = $Get(^||OcuPilotLogTail("beats"), 0) + 1
    Set tMode = $Get(^||OcuPilotLogTail("mode"), "")
    If tMode = "fail" Quit $$$ERROR($$$GeneralError, "the client has gone")
    If tMode = "throw" Throw ##class(%Exception.General).%New("client gone", 5001, "Heartbeat", "armed by OcuPilot.Test.LogTail")
    Quit $$$OK
}

/// <p>How many heartbeats the port has run since the test began.</p>
ClassMethod Beats() As %Integer
{
    Quit +$Get(^||OcuPilotLogTail("beats"), 0)
}

/// <p>Replace the scratch file with <var>pCount</var> lines tagged <var>pTag</var>, each exactly
/// <parameter>OcuPilot.Test.LogSource.LINEBYTES</parameter> bytes with its newline.</p>
ClassMethod WriteTag(pTag As %String, pCount As %Integer) As %Status
{
    Set tText = ""
    For tI = 1:1:pCount Set tText = tText _ ##class(OcuPilot.Test.LogSource).LineText(pTag, tI) _ $Char(10)
    Quit ##class(OcuPilot.Test.LogSource).WriteFile(..Path(), tText)
}

/// <p>Append <var>pContent</var> to the scratch file.</p>
ClassMethod Append(pPath As %String, pContent As %String)
{
    Set tFile = ##class(%File).%New(pPath)
    Set tSC = tFile.Open("WAS")
    If $$$ISERR(tSC) Quit
    Do tFile.Write(pContent)
    Do tFile.Close()
}

/// <p>The body of the writer job. After <var>pDelay</var> seconds: <code>append</code> adds
/// <var>pContent</var> to the file; <code>replace</code> replaces the file with <var>pContent</var>;
/// <code>gap</code> removes the file and writes <var>pContent</var> back <var>pGap</var> seconds later.</p>
ClassMethod Writer(pPath As %String, pDelay As %Numeric, pMode As %String, pContent As %String, pGap As %Numeric = 0)
{
    Hang pDelay
    If pMode = "append" Do ..Append(pPath, pContent)
    If pMode = "replace" Do ##class(OcuPilot.Test.LogSource).WriteFile(pPath, pContent)
    If pMode = "gap" {
        Do ##class(%File).Delete(pPath)
        Hang pGap
        Do ##class(OcuPilot.Test.LogSource).WriteFile(pPath, pContent)
    }
}

/// <p>Start the writer job and keep its pid for <method>OnAfterOneTest</method>.</p>
Method StartWriter(pDelay As %Numeric, pMode As %String, pContent As %String, pGap As %Numeric = 0)
{
    Job ##class(OcuPilot.Test.LogTail).Writer(..Path(), pDelay, pMode, pContent, pGap)::10
    Set ..PreparedWriter = $ZChild
}

/// <p>The cursor a page of the scratch file hands back: its identity and size.</p>
Method Cursor(Output pIdentity As %String, Output pSize As %Integer, Output pOffset As %Integer)
{
    Set tSC = ##class(OcuPilot.Test.LogSourceFixture).Page(..#PROBESOURCE, "", "", "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a page of the scratch file supplies the cursor")
    Set pIdentity = $Select($IsObject(tResult): tResult.identity, 1: "")
    Set pSize = $Select($IsObject(tResult): tResult.size, 1: 0)
    Set pOffset = $Select($IsObject(tResult): tResult.offset, 1: 0)
}

/// <p>One tail through the fixture with this class as the heartbeat, timing the call in
/// <var>pElapsed</var> seconds.</p>
Method Hold(pIdentity As %String, pSize As %String, Output pResult As %DynamicObject, Output pHttp As %Integer, Output pFault As %DynamicObject, Output pElapsed As %Numeric, pSource As %String = "messages", pFile As %String = "") As %Status
{
    Set tStart = $ZHorolog
    Set tSC = ##class(OcuPilot.Test.LogSourceFixture).Tail(pSource, pIdentity, pSize, pFile, "OcuPilot.Test.LogTail", .pResult, .pHttp, .pFault)
    Set pElapsed = $ZHorolog - tStart
    Quit tSC
}

/// <p>The two sources that opt into the live tail are exactly <code>messages</code> and
/// <code>alerts</code>, in the shipped port, and each is a key of its fixed enum.</p>
/// <p>Mutation (Rule 19): add <code>systemmonitor</code> to
/// <parameter>OcuPilot.Port.LogSourcePort.TAILSOURCES</parameter> -&gt; the roster assertion goes red.</p>
Method TestTheTailSourcesAreExactlyMessagesAndAlerts()
{
    Set tTail = ##class(OcuPilot.Port.LogSourcePort).TailSources()
    Do $$$AssertEquals($ListToString(tTail, ","), "messages,alerts", "the shipped roster")
    For tI = 1:1:$ListLength(tTail) {
        Do $$$AssertTrue($ListFind(##class(OcuPilot.Port.LogSourcePort).Sources(), $List(tTail, tI)) > 0, $List(tTail, tI) _ " is a key of the port's fixed enum")
    }
}

/// <p>Moved: a size or an identity that differs from the cursor is <code>changed</code> true at once,
/// with no heartbeat and no wait.</p>
/// <p>Mutation (Rule 19): <code>Tail</code> ignores <var>size</var> in its comparison -&gt; the size leg
/// holds to the bound and goes red on the elapsed time and the answer.</p>
Method TestAMovedFileAnswersAtOnceWithoutAHeartbeat()
{
    Do ..Cursor(.tIdentity, .tSize)
    Do ..Append(..Path(), ##class(OcuPilot.Test.LogSource).LineText("alpha", 21) _ $Char(10))
    Set tSC = ..Hold(tIdentity, tSize, .tResult, .tHttp, .tFault, .tElapsed)
    Do $$$AssertStatusOK(tSC, "a longer file is answered")
    Do $$$AssertEquals(tHttp, 200, "with 200")
    Do $$$AssertEquals(tResult.%Get("changed"), 1, "changed true")
    Do $$$AssertEquals(tResult.source, "messages", "naming the source")
    Do $$$AssertEquals(..Beats(), 0, "with no heartbeat")
    Do $$$AssertTrue(tElapsed < 1.5, "and no wait: " _ tElapsed)

    ; The same length under another first line: the identity alone moves.
    Do ..WriteTag("alpha", 20)
    Do ..Cursor(.tIdentity2, .tSize2)
    Do ..WriteTag("bravo", 20)
    Set tSC = ..Hold(tIdentity2, tSize2, .tResult2, .tHttp2, .tFault2, .tElapsed2)
    Do $$$AssertStatusOK(tSC, "a file of the same length and another first line is answered")
    Do $$$AssertEquals(tResult2.%Get("changed"), 1, "changed true")
    Do $$$AssertEquals(..Beats(), 0, "with no heartbeat")
    Do $$$AssertTrue(tElapsed2 < 1.5, "and no wait: " _ tElapsed2)
}

/// <p>Moves mid-wait: a line written while the tail holds is seen within about a second, long before the
/// bound.</p>
/// <p>Mutation (Rule 19): <code>Tail</code> ignores <var>size</var> in its comparison -&gt; the tail holds
/// to the bound and the elapsed-time assertion goes red.</p>
Method TestALineWrittenMidWaitIsSeenWithinAboutASecond()
{
    Do ..Cursor(.tIdentity, .tSize)
    Do ..StartWriter(1, "append", ##class(OcuPilot.Test.LogSource).LineText("alpha", 21) _ $Char(10))
    Set tSC = ..Hold(tIdentity, tSize, .tResult, .tHttp, .tFault, .tElapsed)
    Do $$$AssertStatusOK(tSC, "the tail is answered")
    Do $$$AssertEquals(tResult.%Get("changed"), 1, "changed true")
    Do $$$AssertTrue(tElapsed >= 0.7, "after the wait, not at once: " _ tElapsed)
    Do $$$AssertTrue(tElapsed < (..#BOUND - 0.5), "and well before the bound: " _ tElapsed)
}

/// <p>Still: a file nothing writes to is held to the bound with a heartbeat every
/// <parameter>BEAT</parameter> seconds and answered <code>changed</code> false.</p>
/// <p>Mutation (Rule 19): <code>Tail</code> never calls its heartbeat -&gt; the beat-count assertion goes
/// red.</p>
Method TestAStillFileIsHeldToTheBoundWithAHeartbeatEachInterval()
{
    Do ..Cursor(.tIdentity, .tSize)
    Set tSC = ..Hold(tIdentity, tSize, .tResult, .tHttp, .tFault, .tElapsed)
    Do $$$AssertStatusOK(tSC, "the tail is answered")
    Do $$$AssertEquals(tHttp, 200, "with 200")
    Do $$$AssertEquals(tResult.%Get("changed"), 0, "changed false")
    Do $$$AssertTrue(tElapsed >= (..#BOUND - 0.1), "held to the bound: " _ tElapsed)
    Do $$$AssertTrue(tElapsed < (..#BOUND + 1.5), "and no longer: " _ tElapsed)
    Do $$$AssertTrue((..Beats() >= 2) && (..Beats() <= 3), "a heartbeat each second: " _ ..Beats())
}

/// <p>Partial line: bytes with no newline move the size, so the tail answers <code>changed</code> true;
/// the next tail, at the size the page then reports, waits.</p>
Method TestAPartialLineWakesOnceAndTheNextTailWaits()
{
    Set tPartial = "a line still being written"
    Do ..Cursor(.tIdentity, .tSize)
    Do ..Append(..Path(), tPartial)
    Set tSC = ..Hold(tIdentity, tSize, .tResult, .tHttp, .tFault, .tElapsed)
    Do $$$AssertEquals(tResult.%Get("changed"), 1, "the partial line wakes the tail")
    Do $$$AssertTrue(tElapsed < 1.5, "at once: " _ tElapsed)

    Do ..Cursor(.tIdentity2, .tSize2)
    Do $$$AssertEquals(tSize2, tSize + $Length(tPartial), "the page reports the partial bytes in the size")
    Set tSC = ..Hold(tIdentity2, tSize2, .tResult2, .tHttp2, .tFault2, .tElapsed2)
    Do $$$AssertEquals(tResult2.%Get("changed"), 0, "the next tail, at the new size, waits and finds nothing")
    Do $$$AssertTrue(tElapsed2 >= (..#BOUND - 0.1), "to the bound: " _ tElapsed2)
}

/// <p>Rotation: the file replaced mid-wait by a shorter one under another first line wakes the tail, and
/// the page read over the old cursor answers <code>restarted</code>.</p>
Method TestARotationWakesTheTailAndThePageRestarts()
{
    Do ..Cursor(.tIdentity, .tSize, .tOffset)
    Do ..StartWriter(1, "replace", ##class(OcuPilot.Test.LogSource).LineText("charlie", 1) _ $Char(10))
    Set tSC = ..Hold(tIdentity, tSize, .tResult, .tHttp, .tFault, .tElapsed)
    Do $$$AssertEquals(tResult.%Get("changed"), 1, "the rotation wakes the tail")
    Do $$$AssertTrue(tElapsed < (..#BOUND - 0.5), "before the bound: " _ tElapsed)

    Set tPageSC = ##class(OcuPilot.Test.LogSourceFixture).Page(..#PROBESOURCE, tOffset, "", tIdentity, .tPage, .tPageHttp, .tPageFault)
    Do $$$AssertStatusOK(tPageSC, "the page read over the old cursor is answered")
    Do $$$AssertEquals(tPage.restarted, 1, "and restarts")
}

/// <p>An absent file is no change before the bound and <code>changed</code> true at it, so the page read
/// reports it; an absent instant that ends where it began is waited out.</p>
/// <p>The gap leg also asserts that a look found the file absent, so it cannot pass on a writer that never
/// ran.</p>
/// <p>Mutation (Rule 19): <code>Tail</code> answers <code>changed</code> true as soon as the file is
/// absent -&gt; the gap leg answers early with <code>changed</code> true and goes red.</p>
Method TestAnAbsentFileIsWaitedOutAndReportedAtTheBound()
{
    Do ..Cursor(.tIdentity, .tSize)
    Set tContent = ""
    For tI = 1:1:20 Set tContent = tContent _ ##class(OcuPilot.Test.LogSource).LineText("alpha", tI) _ $Char(10)
    ; An instant without the file, then the same file again: nothing has moved.
    Do ..StartWriter(0.4, "gap", tContent, 0.8)
    Set tSC = ..Hold(tIdentity, tSize, .tResult, .tHttp, .tFault, .tElapsed)
    Do $$$AssertStatusOK(tSC, "the tail is answered")
    Do $$$AssertTrue(##class(OcuPilot.Test.LogSourceFixture).AbsentLooks() >= 1, "a look did find the file absent: " _ ##class(OcuPilot.Test.LogSourceFixture).AbsentLooks())
    Do $$$AssertEquals(tResult.%Get("changed"), 0, "an absent instant that ends unchanged is no change")
    Do $$$AssertTrue(tElapsed >= (..#BOUND - 0.1), "waited out to the bound: " _ tElapsed)

    ; A file that stays absent is held to the bound and then reported as a change.
    Kill ^||OcuPilotLogTail
    Do ##class(%File).Delete(..Path())
    Set tSC = ..Hold(tIdentity, tSize, .tResult2, .tHttp2, .tFault2, .tElapsed2)
    Do $$$AssertStatusOK(tSC, "an absent file is answered")
    Do $$$AssertEquals(tHttp2, 200, "with 200, not LOG.ABSENT")
    Do $$$AssertEquals(tResult2.%Get("changed"), 1, "changed true at the bound")
    Do $$$AssertTrue(tElapsed2 >= (..#BOUND - 0.1), "no earlier: " _ tElapsed2)
    Do $$$AssertTrue(..Beats() >= 2, "with heartbeats while it waited: " _ ..Beats())
    Set tPageSC = ##class(OcuPilot.Test.LogSourceFixture).Page(..#PROBESOURCE, "", "", "", .tPage, .tPageHttp, .tPageFault)
    Do $$$AssertEquals(tPageHttp _ " " _ tPageFault.code, "404 LOG.ABSENT", "and the page read reports the absence")
}

/// <p>Refused: every refusal comes before any wait, heartbeat or file access, with the matrix's status and
/// code.</p>
/// <p>Mutation (Rule 19): remove the cursor check from <code>Tail</code> -&gt; the cursor rows are answered
/// as a moved file, and the status, code and file-access assertions go red.</p>
Method TestARefusalComesBeforeAnyWaitHeartbeatOrFileAccess()
{
    Set tLong = $Translate($Justify("", 65), " ", "a")
    Set tRows = $ListBuild("nosuchlog|||||404|LOG.SOURCE", "systemmonitor|||||404|LOG.SOURCE", "integrity|||||404|LOG.SOURCE", "applicationerrors|||||404|LOG.SOURCE", "messages|||||400|LOG.OFFSET", "messages|abc||||400|LOG.OFFSET", "messages||12|||400|LOG.OFFSET", "messages|has space|12|||400|LOG.OFFSET", "messages|" _ tLong _ "|12|||400|LOG.OFFSET", "messages|abc|-1|||400|LOG.OFFSET", "messages|abc|1.5|||400|LOG.OFFSET", "messages|abc|12x|||400|LOG.OFFSET", "messages|abc|12|messages.old_20261013||400|LOG.FILE", "messages|abc|12|messages.log||400|LOG.FILE", "messages|abc|12|../x||400|LOG.FILE")
    For tI = 1:1:$ListLength(tRows) {
        Set tRow = $List(tRows, tI)
        Set tLabel = $Piece(tRow, "|", 1) _ " identity=" _ $Piece(tRow, "|", 2) _ " size=" _ $Piece(tRow, "|", 3) _ " file=" _ $Piece(tRow, "|", 4)
        Kill ^||OcuPilotLogTail
        Do ##class(OcuPilot.Test.LogSourceFixture).ClearTouches()
        Set tSC = ..Hold($Piece(tRow, "|", 2), $Piece(tRow, "|", 3), .tResult, .tHttp, .tFault, .tElapsed, $Piece(tRow, "|", 1), $Piece(tRow, "|", 4))
        Do $$$AssertStatusNotOK(tSC, tLabel _ ": is refused")
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code, 1: ""), $Piece(tRow, "|", 6) _ " " _ $Piece(tRow, "|", 7), tLabel _ ": with the matrix's status and code")
        Do $$$AssertEquals(..Beats(), 0, tLabel _ ": and no heartbeat")
        Do $$$AssertTrue(tElapsed < 1, tLabel _ ": and no wait: " _ tElapsed)
        Do $$$AssertEquals(##class(OcuPilot.Test.LogSourceFixture).Touches(), 0, tLabel _ ": and the file is not touched")
    }
}

/// <p>A caller that lacks the pair, or a source whose requirement is empty, is refused 403 before the file
/// is touched or the tail waits; the same call holding the pair is served.</p>
/// <p>Mutation (Rule 19): look at the file before the gate in <code>Tail</code> -&gt; the file-access count
/// goes red.</p>
Method TestAGateRefusalTouchesNoFile()
{
    Do ..Cursor(.tIdentity, .tSize)
    Do ##class(OcuPilot.Test.LogSourceFixture).SetGateClass("OcuPilot.Test.ScreenGate")
    Do ##class(OcuPilot.Test.LogSourceFixture).ClearTouches()
    Set tSC = ..Hold(tIdentity, tSize, .tResult, .tHttp, .tFault, .tElapsed)
    Do $$$AssertStatusNotOK(tSC, "a caller holding nothing is refused")
    Do $$$AssertEquals(tHttp _ " " _ tFault.code, "403 AUTH.NOPRIVILEGE", "403 on the privilege code")
    Do $$$AssertEquals(tFault.detail.failedPair, "%Admin_Operate:USE", "naming the pair that failed")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogSourceFixture).Touches(), 0, "with no file touched")
    Do $$$AssertEquals(..Beats(), 0, "and no heartbeat")
    Do $$$AssertTrue(tElapsed < 1, "and no wait: " _ tElapsed)

    Do ##class(OcuPilot.Test.LogSourceFixture).SetPairs(..#PROBESOURCE, "")
    Do ##class(OcuPilot.Test.LogSourceFixture).ClearTouches()
    Set tSC = ..Hold(tIdentity, tSize, .tResult2, .tHttp2, .tFault2, .tElapsed2)
    Do $$$AssertEquals(tHttp2, 403, "a source with no requirement is refused, not opened to everyone")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogSourceFixture).Touches(), 0, "with no file touched")

    Kill ^||OcuPilotLogFixture("pairs")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Operate", "USE")
    Do ..Append(..Path(), ##class(OcuPilot.Test.LogSource).LineText("alpha", 21) _ $Char(10))
    Set tSC = ..Hold(tIdentity, tSize, .tResult3, .tHttp3, .tFault3, .tElapsed3)
    Do $$$AssertStatusOK(tSC, "the same call holding the pair is served")
    Do $$$AssertEquals(tResult3.%Get("changed"), 1, "and answers the change")
}

/// <p>Client gone: a heartbeat that reports an error, or throws, ends the wait at that beat with nothing
/// logged; so does the gateway's external interrupt.</p>
/// <p>Mutation (Rule 19): <code>Tail</code> ignores a failed heartbeat -&gt; the tail holds to the bound
/// and the elapsed-time assertion goes red.</p>
Method TestAClientThatHasGoneEndsTheWaitAndLogsNothing()
{
    Do ..Cursor(.tIdentity, .tSize)
    For tMode = "fail", "throw" {
        Kill ^||OcuPilotLogTail
        Set ^||OcuPilotLogTail("mode") = tMode
        Do ..Rearm()
        Set tSC = ..Hold(tIdentity, tSize, .tResult, .tHttp, .tFault, .tElapsed)
        Do $$$AssertStatusOK(tSC, tMode _ ": the wait ends cleanly")
        Do $$$AssertEquals(tResult.%Get("changed"), 0, tMode _ ": changed false")
        Do $$$AssertEquals(..Beats(), 1, tMode _ ": at the first beat")
        Do $$$AssertTrue(tElapsed < (..#BOUND - 0.5), tMode _ ": well before the bound: " _ tElapsed)
        Do $$$AssertEquals(##class(OcuPilot.Test.LogSourceFixture).Faults(), 0, tMode _ ": and nothing is logged")
    }

    Kill ^||OcuPilotLogTail
    Do ..Rearm()
    Do ##class(OcuPilot.Test.LogSourceFixture).ArmTailThrow("<EXTERNAL INTERRUPT>", 1)
    Set tSC = ..Hold(tIdentity, tSize, .tResult2, .tHttp2, .tFault2, .tElapsed2)
    Do $$$AssertStatusOK(tSC, "an external interrupt ends the wait cleanly")
    Do $$$AssertEquals(tResult2.%Get("changed"), 0, "changed false")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogSourceFixture).Faults(), 0, "and nothing is logged")
}

/// <p>A fault before the first heartbeat is the generic internal fault, logged; after it the response has
/// flushed, so the fault is logged and answered as a change.</p>
Method TestAFaultIsInternalBeforeTheFirstBeatAndAChangeAfter()
{
    Do ..Cursor(.tIdentity, .tSize)
    Do ##class(OcuPilot.Test.LogSourceFixture).ArmTailThrow("<UNDEFINED>", 0)
    Set tSC = ..Hold(tIdentity, tSize, .tResult, .tHttp, .tFault, .tElapsed)
    Do $$$AssertStatusNotOK(tSC, "a fault before the first beat is a fault")
    Do $$$AssertEquals(tHttp _ " " _ tFault.code, "500 " _ ##class(OcuPilot.Api.Error).#INTERNAL, "the generic internal one")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogSourceFixture).Faults(), 1, "logged once")
    Do $$$AssertEquals(..Beats(), 0, "with no heartbeat")

    Kill ^||OcuPilotLogTail
    Do ..Rearm()
    Do ##class(OcuPilot.Test.LogSourceFixture).ArmTailThrow("<UNDEFINED>", 8)
    Set tSC = ..Hold(tIdentity, tSize, .tResult2, .tHttp2, .tFault2, .tElapsed2)
    Do $$$AssertStatusOK(tSC, "a fault after the first beat is answered")
    Do $$$AssertEquals(tHttp2, 200, "with 200, the status having flushed")
    Do $$$AssertEquals(tResult2.%Get("changed"), 1, "as a change")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogSourceFixture).Faults(), 1, "logged once")
    Do $$$AssertEquals(..Beats(), 1, "after one heartbeat")
}

}
