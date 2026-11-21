/// <p>Task output (Story 21.36): <class>OcuPilot.Port.LogSourcePort</class>'s <code>taskoutput</code>
/// source and the <code>tasks.taskoutput</code> screen that reads it. Pins the declaration, the tail
/// window and its truncation, the refusals and their order (none, elsewhere, absent, unknown task, the
/// gate), that no refusal carries a path, and that the screen's read and the agent's read answer the
/// same rows.</p>
/// <p>Live-safe: it creates one on-demand task of its own that is never run, and writes its probe output
/// file itself in the manager directory; both are removed in <method>OnAfterOneTest</method>. Needs the
/// API application installed in <code>HSCUSTOM</code> and a writable manager directory.</p>
Class OcuPilot.Test.TaskOutputRead Extends %UnitTest.TestCase
{

/// <p>The descriptor under test.</p>
Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.TaskOutput";

/// <p>The tool identifier the screen read and the derived read tool share.</p>
Parameter TOOL = "tasks.taskoutput";

/// <p>The source key the port reads.</p>
Parameter SOURCE = "taskoutput";

/// <p>The probe task's name.</p>
Parameter PROBETASKNAME = "OcuPilotProbeOutputTask";

/// <p>The probe task's output file name, which matches the output file pattern.</p>
Parameter PROBEFILE = "ocupilotprobeoutput.txt";

/// <p>The vendor's on-demand schedule (<code>TimePeriod</code> 5).</p>
Parameter ONDEMAND = 5;

/// <p>The probe task's id, <code>""</code> when none exists. Prefix not <code>Test</code>.</p>
Property ProbeTaskId As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..ProbeTaskId = ""
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.LogSourceFixture).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ..RemoveProbes()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.LogSourceFixture).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ..RemoveProbes()
    Quit $$$OK
}

/// <p>The manager directory with its trailing separator.</p>
ClassMethod Directory() As %String
{
    Quit ##class(%File).NormalizeDirectory($System.Util.ManagerDirectory())
}

/// <p>The probe file's path.</p>
ClassMethod ProbePath() As %String
{
    Quit ##class(%File).NormalizeFilename(..#PROBEFILE, ..Directory())
}

/// <p>Remove the probe task, found by name, and the probe file.</p>
Method RemoveProbes()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM %SYS.Task WHERE %EXACT(Name) = ?", ..#PROBETASKNAME)
        Set tIds = ""
        While tRS.%Next() {
            Set tIds = tIds _ $ListBuild(tRS.%Get("ID"))
        }
        For tI = 1:1:$ListLength(tIds) {
            Do ##class(%SYS.Task).%DeleteId($List(tIds, tI))
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
    Do ##class(%File).Delete(..ProbePath())
    Set ..ProbeTaskId = ""
}

/// <p>Create the probe task, on demand and never run, with the stored output location
/// <var>pOpen</var>, <var>pDirectory</var> and <var>pFile</var>; <property>ProbeTaskId</property> is
/// its id. The task holds no OREF here beyond the save.</p>
Method CreateProbe(pOpen As %Boolean, pDirectory As %String, pFile As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tTask = ##class(%SYS.Task).%New()
        Set tTask.Name = ..#PROBETASKNAME
        Set tTask.Description = "OcuPilot's task output probe: never run, created and deleted by its tests"
        Set tTask.NameSpace = "%SYS"
        Set tTask.TaskClass = "%SYS.Task.RunLegacyTask"
        Set tTask.TimePeriod = ..#ONDEMAND
        Set tTask.OpenOutputFile = pOpen
        Set tTask.OutputDirectory = pDirectory
        Set tTask.OutputFilename = pFile
        Set tDefinition = ##class(%SYS.Task.RunLegacyTask).%New()
        Set tDefinition.ExecuteCode = "Quit"
        Set tSC = tTask.AssignSettings(tDefinition)
        Set tDefinition = ""
        If $$$ISOK(tSC) Set tSC = tTask.%Save()
        If $$$ISOK(tSC) Set ..ProbeTaskId = tTask.%Id()
        Set tTask = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The probe task, created to write <parameter>PROBEFILE</parameter> in the manager directory, and
/// the probe file written with <var>pContent</var>; <var>pContent</var> <code>""</code> leaves an empty
/// file and <code>$Char(0)</code> leaves none.</p>
Method ArmProbe(pContent As %String) As %Status
{
    Set tSC = ..CreateProbe(1, ..Directory(), ..#PROBEFILE)
    Do $$$AssertStatusOK(tSC, "the probe task is created")
    If $$$ISERR(tSC) Quit tSC
    If pContent '= $Char(0) Set tSC = ##class(OcuPilot.Test.LogSource).WriteFile(..ProbePath(), pContent)
    Do $$$AssertStatusOK(tSC, "the probe file is written")
    Quit tSC
}

/// <p><var>pCount</var> lines of exactly <var>pWidth</var> bytes, newline included, each the
/// zero-padded line number then dots.</p>
ClassMethod Lines(pCount As %Integer, pWidth As %Integer) As %String
{
    Set tText = ""
    For tI = 1:1:pCount {
        Set tLine = $Justify(tI, 6)
        Set tLine = $Translate(tLine, " ", "0")
        Set tText = tText _ tLine _ $Translate($Justify("", pWidth - 7), " ", ".") _ $Char(10)
    }
    Quit tText
}

/// <p>One read of the source through <var>pClass</var>, for the task <var>pTaskId</var>.</p>
Method Read(pClass As %String, pTaskId As %String, pMaxRows As %Integer, Output pRows As %DynamicArray, Output pHttp As %Integer, Output pFault As %DynamicObject, Output pTruncated As %Boolean) As %Status
{
    Set tCriteria("taskId") = pTaskId
    Quit $ClassMethod(pClass, "Rows", ..#SOURCE, pMaxRows, .pRows, .pHttp, .pFault, .pTruncated, .tCriteria)
}

/// <p>The declaration passes the read, criteria and classic-link grammar; its route and tool
/// identifier resolve to it; it is the Tasks area's unlisted log viewer, parented to Task schedule,
/// keyed by a single id, with no action and no secret; its source is the log source port's
/// <code>taskoutput</code> key under Task details' own pairs; and the Tasks area covers its pairs.</p>
/// <p>Mutation: remove <code>%DB_IRISSYS:READ</code> from the descriptor -&gt;
/// <method>OcuPilot.Screen.Registry.ReadProblem</method> refuses it and this goes red.</p>
Method TestTheDeclarationValidatesAndIsDeclaredAsTaskOutput()
{
    Set tClass = ..#DESCRIPTOR
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "its read and table are the declared grammar")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).CriteriaProblem(tDeclaration), "", "and so are its criteria")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem(tDeclaration), "", "and it links out to nothing")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("tasks/schedule/output"), tClass, "the route resolves to it")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool(..#TOOL), tClass, "and so does its tool identifier")
    Do $$$AssertEquals($ClassMethod(tClass, "ClassicPage"), "%CSP.UI.Portal.TaskInfo", "the classic page is Task details' own")
    Do $$$AssertEquals($ClassMethod(tClass, "AreaKey"), "tasks", "in the Tasks area")
    Do $$$AssertEquals($ClassMethod(tClass, "SideBarPosition"), 0, "routable but unlisted")
    Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), "log-viewer", "on the log-viewer archetype")
    Do $$$AssertEquals($ClassMethod(tClass, "ParentScope"), "tasks/schedule", "parented to Task schedule")
    Do $$$AssertEquals($ClassMethod(tClass, "IdKind"), "single", "keyed by a single id")
    Do $$$AssertEquals($ClassMethod(tClass, "Refreshes"), 0, "and it does not refresh")
    Do $$$AssertEquals(tDeclaration.context.secretFields.%Size(), 0, "with no secret field")
    Do $$$AssertEquals($ListLength($ClassMethod(tClass, "RowActionIds")) + ($ClassMethod(tClass, "PrimaryActionId") '= ""), 0, "because it declares no action")
    Do $$$AssertEquals(tDeclaration.read.source.port _ "/" _ tDeclaration.read.source.endpoint, "logsource/" _ ..#SOURCE, "its source is the log source port's task output")
    Do $$$AssertEquals(tDeclaration.read.criteria.fields.%Size(), 1, "with one criterion")
    Do $$$AssertEquals(tDeclaration.read.criteria.fields.%Get(0).param, "taskId", "the task id")
    Do $$$AssertEquals(tDeclaration.read.criteria.fields.%Get(0).vendorParam, "", "which names no vendor parameter")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("tasks", $ClassMethod(tClass, "PrivilegePairs")), "", "and the Tasks area covers its pair set")
    Do $$$AssertEquals($Parameter("OcuPilot.Port.LogSourcePort", "TASKOUTPUTPAIRS"), "%Admin_Task:USE,%DB_IRISSYS:READ", "the source's pairs are Task details' own")
    Do $$$AssertTrue($ListFind(##class(OcuPilot.Port.LogSourcePort).Sources(), ..#SOURCE) > 0, "the key is in the port's enum")
    Do $$$AssertEquals($ListFind($ListFromString($Parameter("OcuPilot.Port.LogSourcePort", "TAILSOURCES")), ..#SOURCE), 0, "and not a live tail")
    Do $$$AssertEquals($ListFind($ListFromString($Parameter("OcuPilot.Port.LogSourcePort", "RECENTSOURCES")), ..#SOURCE), 0, "nor a recent source")
}

/// <p>A small file reads whole, newest line first, each row <code>{offset, text}</code> with the line's
/// first byte as its offset. A byte above 127 reaches the row as the one character of that byte: the
/// vendor writes 8-bit text, and no encoding is guessed. A file under 64 KB is never truncated.</p>
/// <p>Mutation: decode each line as UTF-8 in <code>TaskOutputRows</code> (leave <code>pDecode</code>
/// at its default) -&gt; the byte leg reads <code>?</code> in its place and goes red.</p>
Method TestASmallFileReadsWholeNewestFirstAsStored()
{
    Set tText = "first" _ $Char(10) _ "caf" _ $Char(233) _ $Char(10) _ "third" _ $Char(13) _ $Char(10) _ "last" _ $Char(10)
    If $$$ISERR(..ArmProbe(tText)) Quit
    Set tSC = ..Read("OcuPilot.Port.LogSourcePort", ..ProbeTaskId, 0, .tRows, .tHttp, .tFault, .tTruncated)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do $$$AssertEquals(tHttp, 200, "answered 200")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tRows.%Size(), 4, "four lines, one row each")
    Do $$$AssertEquals(tTruncated, 0, "a small file is not truncated")
    Do $$$AssertEquals(tRows.%Get(0).text, "last", "newest first")
    Do $$$AssertEquals(tRows.%Get(1).text, "third", "a carriage return before the line feed is not part of the text")
    Do $$$AssertEquals(tRows.%Get(2).text, "caf" _ $Char(233), "a byte above 127 is one character, as stored")
    Do $$$AssertEquals(tRows.%Get(3).text, "first", "the oldest line is last")
    Do $$$AssertEquals(tRows.%Get(3).offset, 1, "the first line starts at byte 1")
    Do $$$AssertEquals(tRows.%Get(2).offset, 7, "the second line starts after the first line and its newline")
    Do $$$AssertEquals(tRows.%Get(0).offset, $Length(tText) - 4, "the last line starts where the file's last line does")
}

/// <p>A file larger than the window reads only its last 65,536 bytes, from a line boundary, and says
/// it was cut: 1,000 lines of 100 bytes start the window mid-line 345, so the oldest row is line 346
/// at byte 34,501 and the newest is line 1,000. A file of exactly 65,536 bytes is whole, and one byte
/// more is cut.</p>
/// <p>Mutation: read the window from byte 1 in <code>TaskOutputRows</code> -&gt; the newest row is
/// line 655 and the oldest offset 1, and the first assertions go red; never set <code>pTruncated</code>
/// -&gt; the truncation assertions go red.</p>
Method TestAFileLargerThanTheWindowReadsOnlyItsEnd()
{
    If $$$ISERR(..ArmProbe(..Lines(1000, 100))) Quit
    Set tSC = ..Read("OcuPilot.Port.LogSourcePort", ..ProbeTaskId, 0, .tRows, .tHttp, .tFault, .tTruncated)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tTruncated, 1, "a file larger than the window is truncated")
    Do $$$AssertEquals(tRows.%Size(), 655, "the window holds 655 whole lines")
    Do $$$AssertEquals(tRows.%Get(0).offset, 99901, "the newest row is line 1,000")
    Do $$$AssertEquals($Extract(tRows.%Get(0).text, 1, 6), "001000", "and says so")
    Do $$$AssertEquals(tRows.%Get(654).offset, 34501, "the oldest row is the first whole line in the window")
    Do $$$AssertEquals($Extract(tRows.%Get(654).text, 1, 6), "000346", "and is line 346")
    Do $$$AssertEquals($Length(tRows.%Get(654).text), 99, "a whole line, never a part of one")

    ; Exactly the window: whole, not cut.
    Set tSC = ##class(OcuPilot.Test.LogSource).WriteFile(..ProbePath(), ..Lines(4096, 16))
    Do $$$AssertStatusOK(tSC, "a file of exactly 65,536 bytes is written")
    Set tSC = ..Read("OcuPilot.Port.LogSourcePort", ..ProbeTaskId, 0, .tRows, .tHttp, .tFault, .tTruncated)
    Do $$$AssertEquals(tRows.%Size(), 4096, "a file of exactly 65,536 bytes reads whole")
    Do $$$AssertEquals(tTruncated, 0, "and is not truncated")

    ; One byte more: cut, and the 17-byte first line the window begins in is dropped.
    Set tSC = ##class(OcuPilot.Test.LogSource).WriteFile(..ProbePath(), "a" _ ..Lines(4096, 16))
    Do $$$AssertStatusOK(tSC, "a file of 65,537 bytes is written")
    Set tSC = ..Read("OcuPilot.Port.LogSourcePort", ..ProbeTaskId, 0, .tRows, .tHttp, .tFault, .tTruncated)
    Do $$$AssertEquals(tTruncated, 1, "a file one byte over the window is truncated")
    Do $$$AssertEquals(tRows.%Size(), 4095, "the line the window begins in is dropped")
    Do $$$AssertEquals(tRows.%Get(4094).offset, 18, "so the oldest row is the second line, a whole line")
}

/// <p>An unterminated final line is a line: a one-line file with no line feed reads that line, whole
/// and not truncated, and a last line with no line feed after complete lines is the newest row.</p>
/// <p>Mutation: in <code>TaskOutputRows</code>, drop the window's last line when the file does not end
/// in a line feed -&gt; both legs go red.</p>
Method TestAnUnterminatedFinalLineIsALine()
{
    If $$$ISERR(..ArmProbe("only line, no line feed")) Quit
    Set tSC = ..Read("OcuPilot.Port.LogSourcePort", ..ProbeTaskId, 0, .tRows, .tHttp, .tFault, .tTruncated)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tRows.%Size(), 1, "a one-line file with no line feed is one row, not No entries")
    Do $$$AssertEquals(tRows.%Get(0).text, "only line, no line feed", "the whole line")
    Do $$$AssertEquals(tRows.%Get(0).offset, 1, "from byte 1")
    Do $$$AssertEquals(tTruncated, 0, "a file under the window is not truncated")

    Set tSC = ##class(OcuPilot.Test.LogSource).WriteFile(..ProbePath(), "first" _ $Char(10) _ "last, unterminated")
    Do $$$AssertStatusOK(tSC, "a two-line file whose last line has no line feed is written")
    Set tSC = ..Read("OcuPilot.Port.LogSourcePort", ..ProbeTaskId, 0, .tRows, .tHttp, .tFault, .tTruncated)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tRows.%Size(), 2, "both lines are rows")
    Do $$$AssertEquals(tRows.%Get(0).text, "last, unterminated", "the unterminated line is the newest row")
    Do $$$AssertEquals(tRows.%Get(0).offset, 7, "starting after the first line and its line feed")
}

/// <p>A file larger than the window whose last line has no line feed: after complete lines the
/// unterminated line is the newest row and the window still begins on a line boundary; when the whole
/// window is one line (70,000 bytes, with or without its line feed) the row is the end of the line,
/// without the terminator, from the window's first byte, with the answer truncated and never No
/// entries.</p>
/// <p>Mutation: in <code>TaskOutputRows</code>, answer no rows when the window holds no line feed -&gt;
/// the single-line leg goes red; drop the last line when the file does not end in a line feed -&gt;
/// the first leg's newest-row assertions go red.</p>
Method TestAnUnterminatedFinalLineInAFileLargerThanTheWindow()
{
    If $$$ISERR(..ArmProbe(..Lines(1000, 100) _ "tail-no-lf")) Quit
    Set tSC = ..Read("OcuPilot.Port.LogSourcePort", ..ProbeTaskId, 0, .tRows, .tHttp, .tFault, .tTruncated)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tTruncated, 1, "a file larger than the window is truncated")
    Do $$$AssertEquals(tRows.%Size(), 656, "the window holds 655 whole lines and the unterminated one")
    Do $$$AssertEquals(tRows.%Get(0).text, "tail-no-lf", "the unterminated line is the newest row")
    Do $$$AssertEquals(tRows.%Get(0).offset, 100001, "starting where it starts in the file")
    Do $$$AssertEquals(tRows.%Get(655).offset, 34501, "and the oldest row is still a whole line on a line boundary")

    ; 70,000 bytes: "S" is byte 4,465, the window's first, and "E" is byte 70,000, its last.
    Set tLong = $Translate($Justify("", 4464), " ", "x") _ "S" _ $Translate($Justify("", 65534), " ", "x") _ "E"
    Set tSC = ##class(OcuPilot.Test.LogSource).WriteFile(..ProbePath(), tLong)
    Do $$$AssertStatusOK(tSC, "a single 70,000-byte line with no line feed is written")
    Set tSC = ..Read("OcuPilot.Port.LogSourcePort", ..ProbeTaskId, 0, .tRows, .tHttp, .tFault, .tTruncated)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tRows.%Size(), 1, "the one line is one row, not No entries")
    Do $$$AssertEquals($Length(tRows.%Get(0).text), 65536, "holding the last 65,536 bytes of it")
    Do $$$AssertEquals($Extract(tRows.%Get(0).text, 1), "S", "starting at the window's first byte")
    Do $$$AssertEquals($Extract(tRows.%Get(0).text, *), "E", "and ending at the file's last byte")
    Do $$$AssertEquals(tRows.%Get(0).offset, 4465, "from the byte the window starts at")
    Do $$$AssertEquals(tTruncated, 1, "and the answer says only the end is shown")

    ; The same line ended by a line feed: the row is the line's end without the terminator.
    Set tSC = ##class(OcuPilot.Test.LogSource).WriteFile(..ProbePath(), tLong _ $Char(10))
    Do $$$AssertStatusOK(tSC, "the same line with a line feed is written")
    Set tSC = ..Read("OcuPilot.Port.LogSourcePort", ..ProbeTaskId, 0, .tRows, .tHttp, .tFault, .tTruncated)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tRows.%Size(), 1, "one row")
    Do $$$AssertEquals($Length(tRows.%Get(0).text), 65535, "the end of the line, 65,535 bytes")
    Do $$$AssertEquals($Extract(tRows.%Get(0).text, *), "E", "with no line feed in the text")
    Do $$$AssertEquals(tRows.%Get(0).offset, 4466, "from the byte the window starts at")
    Do $$$AssertEquals(tTruncated, 1, "still cut")
}

/// <p>A row cap shorter than the file keeps the newest rows, and the caller sees the cut from the one
/// row it asked beyond its cap.</p>
Method TestARowCapKeepsTheNewestRows()
{
    If $$$ISERR(..ArmProbe(..Lines(10, 20))) Quit
    Set tSC = ..Read("OcuPilot.Port.LogSourcePort", ..ProbeTaskId, 3, .tRows, .tHttp, .tFault, .tTruncated)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tRows.%Size(), 3, "three rows")
    Do $$$AssertEquals($Extract(tRows.%Get(0).text, 1, 6), "000010", "the newest first")
    Do $$$AssertEquals($Extract(tRows.%Get(2).text, 1, 6), "000008", "and the two before it")
    Do $$$AssertEquals(tTruncated, 0, "the port's own window held the whole file")
}

/// <p>A file that exists with no bytes answers no rows and is not truncated.</p>
Method TestAnEmptyFileAnswersNoRows()
{
    If $$$ISERR(..ArmProbe("")) Quit
    Do $$$AssertTrue(##class(%File).Exists(..ProbePath()), "the probe file exists and is empty")
    Set tSC = ..Read("OcuPilot.Port.LogSourcePort", ..ProbeTaskId, 0, .tRows, .tHttp, .tFault, .tTruncated)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tHttp, 200, "answered 200")
    Do $$$AssertEquals(tRows.%Size(), 0, "no rows")
    Do $$$AssertEquals(tTruncated, 0, "not truncated")
}

/// <p>A record that names its file in the manager directory while the file is not there yet is its
/// own refusal, 404 <code>LOG.TASKOUTPUT.ABSENT</code>, never an empty read; the answer carries no
/// path.</p>
Method TestAFileNotWrittenYetIsItsOwnRefusal()
{
    If $$$ISERR(..ArmProbe($Char(0))) Quit
    Set tSC = ..Read("OcuPilot.Port.LogSourcePort", ..ProbeTaskId, 0, .tRows, .tHttp, .tFault, .tTruncated)
    Do $$$AssertStatusNotOK(tSC, "the read is refused")
    Do $$$AssertEquals(tHttp, 404, "answered 404")
    Do $$$AssertEquals(tFault.code, "LOG.TASKOUTPUT.ABSENT", "naming the file absent")
    Do $$$AssertEquals(tFault.reason, "This task has not written its output file yet. It writes one each time it runs.", "in the ruled sentence")
    Do $$$AssertTrue(tFault.%ToJSON() '[ ..#PROBEFILE, "the refusal does not name the file")
    Do $$$AssertTrue(tFault.%ToJSON() '[ ..Directory(), "or the directory")
}

/// <p>A task that writes no output file is refused 409 <code>LOG.TASKOUTPUT.NONE</code> before any file
/// is touched, though a file of the stored name is there; so is a record with the flag on and no
/// name.</p>
Method TestATaskThatWritesNoFileIsRefusedBeforeAnyFileIsTouched()
{
    If $$$ISERR(..CreateProbe(0, ..Directory(), ..#PROBEFILE)) Quit
    Set tSC = ##class(OcuPilot.Test.LogSource).WriteFile(..ProbePath(), "left from an earlier run" _ $Char(10))
    Set tSC = ..Read("OcuPilot.Test.LogSourceFixture", ..ProbeTaskId, 0, .tRows, .tHttp, .tFault, .tTruncated)
    Do $$$AssertStatusNotOK(tSC, "the read is refused")
    Do $$$AssertEquals(tHttp, 409, "answered 409")
    Do $$$AssertEquals(tFault.code, "LOG.TASKOUTPUT.NONE", "naming the task as writing no file")
    Do $$$AssertEquals(tFault.reason, "This task does not write its output to a file.", "in the ruled sentence")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogSourceFixture).Touches(), 0, "no file was touched")

    Do ##class(OcuPilot.Test.LogSourceFixture).ArmTaskRecord(1, 1, ..Directory(), "")
    Set tSC = ..Read("OcuPilot.Test.LogSourceFixture", "1", 0, .tRows, .tHttp, .tFault, .tTruncated)
    Do $$$AssertEquals(tFault.code, "LOG.TASKOUTPUT.NONE", "a record with the flag on and no name writes no file either")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogSourceFixture).Touches(), 0, "and touches none")
}

/// <p>Every stored location that is not one file directly in the manager directory is refused 409
/// <code>LOG.TASKOUTPUT.ELSEWHERE</code> before any file is touched, with no path in the answer: another
/// directory, the manager directory without its trailing separator (which the vendor's own join turns
/// into a file beside it), no directory, a name outside the pattern, and a name holding two dots. The
/// manager directory with its separator is admitted. A relative directory that names the manager
/// directory from this process is refused too, because the task's own process resolves it from its own
/// directory.</p>
/// <p>Mutation: never raise <code>LOG.TASKOUTPUT.ELSEWHERE</code> in <code>TaskOutputRows</code> -&gt;
/// every refusal leg below goes red; compare only <code>NormalizeDirectory</code> and not the join -&gt;
/// the no-separator leg goes red alone; drop the absolute-directory test -&gt; the relative leg goes red
/// alone.</p>
Method TestALocationOtherThanOneFileInTheManagerDirectoryIsRefused()
{
    Set tManager = ..Directory()
    Set tBare = $Extract(tManager, 1, *-1)
    ; The manager directory relative to this process's own directory, up to the root and down again.
    Set tRelative = ""
    For tUp = 1:1:($Length(##class(%File).NormalizeDirectory(""), "/") - 2) Set tRelative = tRelative _ "../"
    Set tRelative = tRelative _ $Extract(tManager, 2, *)
    Do $$$AssertEquals(##class(%File).NormalizeDirectory(tRelative), tManager, "the relative directory names the manager directory from this process")
    Set tCases = $ListBuild(
        $ListBuild("a relative directory", tRelative, ..#PROBEFILE),
        $ListBuild("another directory", "/tmp/", ..#PROBEFILE),
        $ListBuild("the manager directory without its separator", tBare, ..#PROBEFILE),
        $ListBuild("no directory", "", ..#PROBEFILE),
        $ListBuild("a name outside the pattern", tManager, "run.csv"),
        $ListBuild("a name holding two dots", tManager, "a..b.txt"),
        $ListBuild("a name holding a separator", tManager, "sub/run.txt"),
        $ListBuild("a directory beneath the manager directory", tManager _ "sub/", ..#PROBEFILE))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Do ##class(OcuPilot.Test.LogSourceFixture).Clear()
        Do ##class(OcuPilot.Test.LogSourceFixture).ArmTaskRecord(1, 1, $List(tCase, 2), $List(tCase, 3))
        Set tSC = ..Read("OcuPilot.Test.LogSourceFixture", "7", 0, .tRows, .tHttp, .tFault, .tTruncated)
        Set tWhat = $List(tCase, 1)
        Do $$$AssertStatusNotOK(tSC, tWhat _ ": refused")
        Do $$$AssertEquals(tHttp, 409, tWhat _ ": answered 409")
        Do $$$AssertEquals(tFault.code, "LOG.TASKOUTPUT.ELSEWHERE", tWhat _ ": naming the location")
        Do $$$AssertEquals(tFault.reason, "OcuPilot reads output files only in the manager directory. Open this one on the server.", tWhat _ ": in the ruled sentence")
        Do $$$AssertEquals(##class(OcuPilot.Test.LogSourceFixture).Touches(), 0, tWhat _ ": no file was touched")
        Set tJson = tFault.%ToJSON()
        Do $$$AssertTrue(tJson '[ "/tmp", tWhat _ ": the answer carries no path")
        Do $$$AssertTrue(tJson '[ tManager, tWhat _ ": nor the manager directory")
        Do $$$AssertTrue(tJson '[ ..#PROBEFILE, tWhat _ ": nor the name")
    }

    Do ##class(OcuPilot.Test.LogSourceFixture).Clear()
    Set tSC = ##class(OcuPilot.Test.LogSource).WriteFile(..ProbePath(), "admitted" _ $Char(10))
    Do ##class(OcuPilot.Test.LogSourceFixture).ArmTaskRecord(1, 1, tManager, ..#PROBEFILE)
    Set tSC = ..Read("OcuPilot.Test.LogSourceFixture", "7", 0, .tRows, .tHttp, .tFault, .tTruncated)
    Do $$$AssertStatusOK(tSC, "the manager directory with its separator is admitted")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tRows.%Get(0).text, "admitted", "and its file is read")
}

/// <p>A task id that is not a whole number of at most ten digits, and an id no task holds, are the
/// unknown task, 404 <code>TASK.ABSENT</code>; a shape miss reads no record and touches no file.</p>
Method TestAnUnknownOrMalformedTaskIdIsTheUnknownTask()
{
    Set tIds = $ListBuild("abc", "", "12345678901", "1;2", "-1", "1.5", " 1", "1 ")
    For tI = 1:1:$ListLength(tIds) {
        Set tId = $List(tIds, tI)
        Do ##class(OcuPilot.Test.LogSourceFixture).Clear()
        Set tSC = ..Read("OcuPilot.Test.LogSourceFixture", tId, 0, .tRows, .tHttp, .tFault, .tTruncated)
        Do $$$AssertStatusNotOK(tSC, "'" _ tId _ "': refused")
        Do $$$AssertEquals(tHttp, 404, "'" _ tId _ "': answered 404")
        Do $$$AssertEquals(tFault.code, "TASK.ABSENT", "'" _ tId _ "': the unknown task")
        Do $$$AssertEquals(tFault.reason, "This task no longer exists.", "'" _ tId _ "': in Task details' own sentence")
        Do $$$AssertEquals(##class(OcuPilot.Test.LogSourceFixture).TaskRecordReads(), 0, "'" _ tId _ "': no record was read")
        Do $$$AssertEquals(##class(OcuPilot.Test.LogSourceFixture).Touches(), 0, "'" _ tId _ "': no file was touched")
    }
    Do ##class(OcuPilot.Test.LogSourceFixture).Clear()
    Set tSC = ..Read("OcuPilot.Test.LogSourceFixture", "999999999", 0, .tRows, .tHttp, .tFault, .tTruncated)
    Do $$$AssertEquals(tFault.code, "TASK.ABSENT", "a well-formed id no task holds is the unknown task")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogSourceFixture).TaskRecordReads(), 1, "after one record read")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogSourceFixture).Touches(), 0, "and no file touched")
}

/// <p>A stored task record that cannot be read answers the generic 500 with no path or error text in
/// it, touches no file, and logs one fault.</p>
/// <p>Mutation: answer a record read failure as an absent task in
/// <method>OcuPilot.Port.LogSourcePort.TaskOutputRows</method> -&gt; the status and code assertions go red;
/// pass the error text into the answer's reason -&gt; the no-text assertions go red.</p>
Method TestARecordThatCannotBeReadAnswersFiveHundredWithoutAPath()
{
    Set tProbe = "ocupilot-probe-" _ ..Directory() _ ..#PROBEFILE
    Do ##class(OcuPilot.Test.LogSourceFixture).ArmTaskRecordError(tProbe)
    Set tSC = ..Read("OcuPilot.Test.LogSourceFixture", "7", 0, .tRows, .tHttp, .tFault, .tTruncated)
    Do $$$AssertStatusNotOK(tSC, "the read is refused")
    Do $$$AssertEquals(tHttp, 500, "answered 500")
    Do $$$AssertEquals(tFault.code, ##class(OcuPilot.Api.Error).#INTERNAL, "on the generic internal code")
    Do $$$AssertTrue(tFault.%ToJSON() '[ ..#PROBEFILE, "the answer does not name the file")
    Do $$$AssertTrue(tFault.%ToJSON() '[ ..Directory(), "or the directory")
    Do $$$AssertTrue(tFault.%ToJSON() '[ "ocupilot-probe-", "or the error's text")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogSourceFixture).TaskRecordReads(), 1, "the record was asked for once")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogSourceFixture).Touches(), 0, "no file was touched")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogSourceFixture).Faults(), 1, "and one fault was logged")
}

/// <p>The agent's step reason for each of the three refusals is the published sentence, through
/// <method>OcuPilot.Api.Error.ReasonForToolCode</method> and <method>OcuPilot.Api.TaskError.ReasonFor</method>;
/// a code the class does not own has none.</p>
/// <p>Mutation: drop the <code>LOG.TASKOUTPUT.</code> branch from <method>ReasonForToolCode</method> -&gt; the
/// first three assertions go red; swap two returns in <method>ReasonFor</method> -&gt; the per-code assertions
/// go red.</p>
Method TestTheAgentsStepReasonForEachRefusalIsThePublishedSentence()
{
    Set tCodes = $ListBuild("LOG.TASKOUTPUT.NONE", "LOG.TASKOUTPUT.ELSEWHERE", "LOG.TASKOUTPUT.ABSENT")
    Set tReasons = $ListBuild("This task does not write its output to a file.", "OcuPilot reads output files only in the manager directory. Open this one on the server.", "This task has not written its output file yet. It writes one each time it runs.")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode), $List(tReasons, tI), tCode _ ": the agent's step carries the published sentence")
        Do $$$AssertEquals(##class(OcuPilot.Api.TaskError).ReasonFor(tCode), $List(tReasons, tI), tCode _ ": the class answers the same sentence")
    }
    Do $$$AssertEquals(##class(OcuPilot.Api.TaskError).ReasonFor("LOG.TASKOUTPUT.OTHER"), "", "a code the class does not own has no sentence")
}

/// <p>A caller lacking either of the source's two pairs is refused 403 <code>AUTH.NOPRIVILEGE</code>
/// before any record is read or file touched; a caller holding both reads.</p>
Method TestACallerLackingEitherPairIsRefusedBeforeAnyRecordIsRead()
{
    Do ##class(OcuPilot.Test.LogSourceFixture).SetGateClass("OcuPilot.Test.ScreenGate")
    Do ##class(OcuPilot.Test.LogSourceFixture).ArmTaskRecord(1, 1, ..Directory(), ..#PROBEFILE)
    Set tSC = ##class(OcuPilot.Test.LogSource).WriteFile(..ProbePath(), "held" _ $Char(10))
    Set tHolds = $ListBuild($ListBuild(""), $ListBuild("%Admin_Task:USE"), $ListBuild("%DB_IRISSYS:READ"))
    For tI = 1:1:$ListLength(tHolds) {
        Do ##class(OcuPilot.Test.ScreenGate).Reset()
        Set tHeld = $List(tHolds, tI)
        For tJ = 1:1:$ListLength(tHeld) {
            If $List(tHeld, tJ) '= "" Do ##class(OcuPilot.Test.ScreenGate).Hold($Piece($List(tHeld, tJ), ":", 1), $Piece($List(tHeld, tJ), ":", 2))
        }
        Do ##class(OcuPilot.Test.LogSourceFixture).ClearTouches()
        Set tSC = ..Read("OcuPilot.Test.LogSourceFixture", "7", 0, .tRows, .tHttp, .tFault, .tTruncated)
        Do $$$AssertStatusNotOK(tSC, "holding " _ $ListToString(tHeld) _ ": refused")
        Do $$$AssertEquals(tHttp, 403, "holding " _ $ListToString(tHeld) _ ": answered 403")
        Do $$$AssertEquals(tFault.code, ##class(OcuPilot.Kernel.Denial).Code(), "holding " _ $ListToString(tHeld) _ ": the privilege refusal")
        Do $$$AssertEquals(##class(OcuPilot.Test.LogSourceFixture).TaskRecordReads(), 0, "holding " _ $ListToString(tHeld) _ ": no record was read")
        Do $$$AssertEquals(##class(OcuPilot.Test.LogSourceFixture).Touches(), 0, "holding " _ $ListToString(tHeld) _ ": no file was touched")
    }
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Task", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Set tSC = ..Read("OcuPilot.Test.LogSourceFixture", "7", 0, .tRows, .tHttp, .tFault, .tTruncated)
    Do $$$AssertStatusOK(tSC, "holding both pairs reads")
}

/// <p>The screen's read and the agent's <code>tasks.taskoutput.read</code> answer the same lines from
/// the file's tail, bounded, with the truncation stated, and a record naming another location is refused
/// by both without a path in either answer.</p>
/// <p>Mutation: apply the row cap in the agent's view only -&gt; the row comparison goes red.</p>
Method TestTheScreenAndTheAgentToolAnswerTheSameRows()
{
    If $$$ISERR(..ArmProbe(..Lines(2000, 100))) Quit
    Set tPath = "/api/ocupilot/screens/" _ ..#TOOL _ "/read?maxRows=1000&taskId=" _ ..ProbeTaskId
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tPath, "_SYSTEM", "SYS", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the screen's read completes")
    Do $$$AssertEquals(tStatus, 200, "the screen's read answers")
    Set tScreen = ##class(%DynamicObject).%FromJSON($ZConvert(tBody, "I", "UTF8"))
    Do $$$AssertEquals(tScreen.rows.%Size(), 655, "the screen reads the file's last 655 lines")
    Do $$$AssertEquals(tScreen.truncated, 1, "and states that it is truncated")

    Set tArgs = {}
    Do tArgs.%Set("taskId", ..ProbeTaskId, "string")
    Do ##class(OcuPilot.Kernel.Scope).Set("HSCUSTOM")
    Set tToolSC = ##class(OcuPilot.Screen.Tool.Read).View(..#DESCRIPTOR, tArgs, 1000, .tView, .tViewHttp, .tViewFault)
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK(tToolSC, "the agent's read completes")
    If $$$ISERR(tToolSC) || '$IsObject(tView) Quit
    Do $$$AssertEquals(tView.fields.%ToJSON(), tScreen.fields.%ToJSON(), "the same declared fields")
    Do $$$AssertEquals(tView.rows.%ToJSON(), tScreen.rows.%ToJSON(), "the same lines")
    Do $$$AssertEquals(tView.truncated, 1, "with the truncation stated")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/" _ ..#TOOL _ "/read?maxRows=5&taskId=" _ ..ProbeTaskId, "_SYSTEM", "SYS", .tStatus, .tBody, .tHeaders)
    Set tCut = ##class(%DynamicObject).%FromJSON($ZConvert(tBody, "I", "UTF8"))
    Do $$$AssertEquals(tCut.rows.%Size(), 5, "a row cap bounds the screen's read")
    Do $$$AssertEquals(tCut.truncated, 1, "and the cut is stated")
    Do $$$AssertEquals(tCut.rows.%Get(0).text, tScreen.rows.%Get(0).text, "keeping the newest lines")
}

/// <p>A byte above 127 in the file reaches the screen's answer and the agent's read as the one character the port read, the same in both.</p>
/// <p>Mutation: decode the window as UTF-8 in <method>OcuPilot.Port.LogSourcePort.TaskOutputRows</method> -&gt; the character comparison goes red.</p>
Method TestAnEightBitByteReachesBothCallersAsStored()
{
    If $$$ISERR(..ArmProbe("first" _ $Char(10) _ "caf" _ $Char(233) _ $Char(10) _ "last" _ $Char(10))) Quit
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/" _ ..#TOOL _ "/read?maxRows=10&taskId=" _ ..ProbeTaskId, "_SYSTEM", "SYS", .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the screen's read answers")
    Set tScreen = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tScreen.rows.%Get(1).text, "caf" _ $Char(233), "the screen shows the byte as one character")
    Set tArgs = {}
    Do tArgs.%Set("taskId", ..ProbeTaskId, "string")
    Do ##class(OcuPilot.Kernel.Scope).Set("HSCUSTOM")
    Set tToolSC = ##class(OcuPilot.Screen.Tool.Read).View(..#DESCRIPTOR, tArgs, 10, .tView, .tViewHttp, .tViewFault)
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK(tToolSC, "the agent's read completes")
    If $$$ISERR(tToolSC) || '$IsObject(tView) Quit
    Do $$$AssertEquals(tView.rows.%Get(1).text, "caf" _ $Char(233), "the agent's read shows it the same")
}

/// <p>A record naming another location is refused by the screen and by the agent's read alike, and
/// neither answer carries the path.</p>
Method TestBothCallersRefuseAnotherLocationWithoutAPath()
{
    If $$$ISERR(..CreateProbe(1, "/tmp/", ..#PROBEFILE)) Quit
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/" _ ..#TOOL _ "/read?maxRows=1000&taskId=" _ ..ProbeTaskId, "_SYSTEM", "SYS", .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the screen's read completes")
    Do $$$AssertEquals(tStatus, 409, "the screen is refused")
    Set tScreen = ##class(%DynamicObject).%FromJSON($ZConvert(tBody, "I", "UTF8"))
    Do $$$AssertEquals(tScreen.code, "LOG.TASKOUTPUT.ELSEWHERE", "naming the location")
    Do $$$AssertTrue(tBody '[ "/tmp", "the screen's answer carries no path")

    Set tArgs = {}
    Do tArgs.%Set("taskId", ..ProbeTaskId, "string")
    Do ##class(OcuPilot.Kernel.Scope).Set("HSCUSTOM")
    Set tToolSC = ##class(OcuPilot.Screen.Tool.Read).View(..#DESCRIPTOR, tArgs, 1000, .tView, .tViewHttp, .tViewFault)
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusNotOK(tToolSC, "the agent's read is refused")
    Do $$$AssertEquals(tViewHttp, 409, "with the same status")
    Do $$$AssertEquals(tViewFault.code, "LOG.TASKOUTPUT.ELSEWHERE", "and the same code")
    Do $$$AssertTrue(tViewFault.%ToJSON() '[ "/tmp", "the agent's answer carries no path")
}

}
