/// <p>The Auditing configuration screen's server half (Story 7.4): its declarations, the marking
/// rule a screen action records after an auditing write, and the two embedded event lists read
/// through their own declared reads.</p>
/// <p>Nothing here writes the instance's configuration. One test sets OcuPilot's own recorded
/// marking fact and puts it back, and one writes a single OcuPilot error line to the console log.
/// The marking rule runs against
/// <class>OcuPilot.Test.MarkingPort</class>'s armed answers; the list reads go through the real
/// <class>OcuPilot.Port.AdminPort</class> and need the lists' pairs (<code>%Admin_Secure:USE</code>,
/// <code>%DB_IRISSYS:READ</code>) and OcuPilot's audit events registered, which install does.</p>
Class OcuPilot.Test.AuditingScreen Extends %UnitTest.TestCase
{

Parameter CONFIG = "OcuPilot.Screen.Descriptor.AuditingConfig";

Parameter TOOL = "OcuPilot.Screen.Tool.AuditingUpdate";

Parameter SYSTEMLIST = "OcuPilot.Screen.Descriptor.AuditSystemEventList";

Parameter USERLIST = "OcuPilot.Screen.Descriptor.AuditUserEventList";

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.MarkingPort).Clear()
    Do ##class(OcuPilot.Test.MarkingAction).Clear()
    Quit $$$OK
}

/// <p>The configuration screen is built, lists at its side-bar position, declares both actions and
/// its single-object read; its tool carries both actions and moves the marking, which a tool that
/// does not declare it does not.</p>
Method TestTheScreenIsBuiltWithBothActionsAndItsRead()
{
    Do $$$AssertEquals($ClassMethod(..#CONFIG, "IsBuilt"), 1, "the Auditing configuration screen is built")
    Do $$$AssertEquals($ClassMethod(..#CONFIG, "SideBarPosition"), 6, "at side-bar position 6")
    Do $$$AssertEquals($ListToString($ClassMethod(..#CONFIG, "RowActionIds")), "enable,disable", "declaring enable and disable")
    Set tRead = $ClassMethod(..#CONFIG, "Read")
    Do $$$AssertTrue($IsObject(tRead), "with a declared read")
    If '$IsObject(tRead) Quit
    Do $$$AssertEquals(tRead.source.endpoint _ " " _ tRead.source.type, "Security.Audit.Enabled GET", "over the single-object Security.Audit.Enabled GET")
    Do $$$AssertEquals(tRead.fields.%ToJSON(), "[""Enabled""]", "projecting Enabled")
    Do $$$AssertEquals($ListToString($ClassMethod(..#TOOL, "ScreenActionIds")), "enable,disable", "the write tool carries both actions")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Operation).MovesMarking(..#TOOL), 1, "and moves the marking")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Operation).MovesMarking("OcuPilot.Screen.Tool.WebAppUpdate"), 0, "a tool that does not declare it does not")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Operation).MovesMarking("OcuPilot.Test.NoSuchClass"), 0, "and a class that cannot be asked answers 0")
}

/// <p>A form renders its read's one object, never a grid, so the screen declares no table and no
/// empty-state sentence and its read still validates; the same read on a list, and a form over a
/// list-shaped read, are refused for want of a table, and a form that does declare a table is
/// still held to it.</p>
Method TestAFormPageReadNeedsNoTable()
{
    Set tSC = $ClassMethod(..#CONFIG, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tDeclaration.%GetTypeOf("table"), "unassigned", "the screen declares no table")
    Do $$$AssertEquals(tDeclaration.emptyStateKey, "", "and no empty-state sentence")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "and its read validates")
    Set tList = ##class(%DynamicObject).%FromJSON(tDeclaration.%ToJSON())
    Set tList.archetype = "list"
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tList) [ "table is not an object", "the same read on a list is refused for want of a table")
    Set tOverList = ##class(%DynamicObject).%FromJSON(tDeclaration.%ToJSON())
    Set tOverList.read.source.type = "LIST"
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tOverList) [ "table is not an object", "as is a form over a list-shaped read")
    Set tTabled = ##class(%DynamicObject).%FromJSON(tDeclaration.%ToJSON())
    Do tTabled.%Set("table", {"columns": [], "emptyNextKey": "", "emptyAgentKey": "auditingTurnOnAction"})
    Do $$$AssertTrue(##class(OcuPilot.Screen.Registry).ReadProblem(tTabled) [ "table.columns is empty", "and a form that declares a table is still held to it")
}

/// <p>Marked is auditing on AND the marker event enabled; the event read asks for OcuPilot's own
/// agent-write triple.</p>
Method TestObservingMarkingNeedsAuditingAndTheMarkerEvent()
{
    Set tPort = "OcuPilot.Test.MarkingPort"
    Do ##class(OcuPilot.Test.MarkingPort).Arm("1", "1")
    Set tSC = ##class(OcuPilot.Kernel.Audit.Event).ObserveMarking(tPort, .tMarked)
    Do $$$AssertStatusOK(tSC, "on/on is observed")
    Do $$$AssertEquals(tMarked, 1, "on/on is marked")
    Set tTriple = ##class(OcuPilot.Kernel.Audit.Event).Source() _ "/" _ ##class(OcuPilot.Kernel.Audit.Event).Type() _ "/" _ ##class(OcuPilot.Kernel.Audit.Event).#EVENTAGENTWRITE
    Do $$$AssertEquals(##class(OcuPilot.Test.MarkingPort).AskedEvent(), tTriple, "the event read names the agent-write triple")

    Do ##class(OcuPilot.Test.MarkingPort).Arm("0", "1")
    Set tSC = ##class(OcuPilot.Kernel.Audit.Event).ObserveMarking(tPort, .tMarked)
    Do $$$AssertStatusOK(tSC, "off/on is observed")
    Do $$$AssertEquals(tMarked, 0, "auditing off is not marked")

    Do ##class(OcuPilot.Test.MarkingPort).Arm("1", "0")
    Set tSC = ##class(OcuPilot.Kernel.Audit.Event).ObserveMarking(tPort, .tMarked)
    Do $$$AssertStatusOK(tSC, "on/off is observed")
    Do $$$AssertEquals(tMarked, 0, "a disabled marker event is not marked")

    Do ##class(OcuPilot.Test.MarkingPort).Arm("0", "fault")
    Set tSC = ##class(OcuPilot.Kernel.Audit.Event).ObserveMarking(tPort, .tMarked)
    Do $$$AssertStatusOK(tSC, "auditing off is observed without the event read")
    Do $$$AssertEquals(tMarked, 0, "and is not marked")
    Do $$$AssertEquals(##class(OcuPilot.Test.MarkingPort).AskedEvent(), "", "the event is not read when auditing is off")

    Do ##class(OcuPilot.Test.MarkingPort).Arm("1", "missing")
    Set tSC = ##class(OcuPilot.Kernel.Audit.Event).ObserveMarking(tPort, .tMarked)
    Do $$$AssertStatusOK(tSC, "an unregistered marker event is observed")
    Do $$$AssertEquals(tMarked, 0, "and is not marked, as install records it")
}

/// <p>A read fault on either half, or a flag that is not a boolean, is an error status, never an
/// answer.</p>
Method TestAFailedObservationIsAnErrorNotAnAnswer()
{
    Set tPort = "OcuPilot.Test.MarkingPort"
    Do ##class(OcuPilot.Test.MarkingPort).Arm("fault", "1")
    Set tSC = ##class(OcuPilot.Kernel.Audit.Event).ObserveMarking(tPort, .tMarked)
    Do $$$AssertStatusNotOK(tSC, "a faulted auditing read is an error")
    Do ##class(OcuPilot.Test.MarkingPort).Arm("1", "fault")
    Set tSC = ##class(OcuPilot.Kernel.Audit.Event).ObserveMarking(tPort, .tMarked)
    Do $$$AssertStatusNotOK(tSC, "a faulted marker-event read is an error")
    Do ##class(OcuPilot.Test.MarkingPort).Arm("number", "1")
    Set tSC = ##class(OcuPilot.Kernel.Audit.Event).ObserveMarking(tPort, .tMarked)
    Do $$$AssertStatusNotOK(tSC, "an auditing flag that is not a boolean is an error")
    Do ##class(OcuPilot.Test.MarkingPort).Arm("1", "number")
    Set tSC = ##class(OcuPilot.Kernel.Audit.Event).ObserveMarking(tPort, .tMarked)
    Do $$$AssertStatusNotOK(tSC, "a marker-event flag that is not a boolean is an error")
}

/// <p>The screen caller's post-write observation, on a failed read, records nothing and logs one
/// error line; it never raises (AD-53, AD-15).</p>
Method TestAFailedObservationAfterTheScreensWriteRecordsNothingAndLogs()
{
    Set tBefore = ##class(OcuPilot.Kernel.Audit.Event).WritesMarked()
    Try {
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Audit.Event).RecordMarking(1), "the fact is recorded marked first")
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Audit.Event).WritesMarked(), 1, "so a fault that recorded 'off' would show")
        Do ##class(OcuPilot.Test.MarkingPort).Arm("fault", "1")
        Do ##class(OcuPilot.Test.MarkingAction).Observe(..#TOOL)
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Audit.Event).WritesMarked(), 1, "the recorded marking fact is left as it was")
        Do $$$AssertEquals(##class(OcuPilot.Test.MarkingAction).Logged(), 1, "and one error line is logged")
    } Catch ex {
        Do $$$AssertTrue(0, "the observation raised: " _ ex.DisplayString())
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Audit.Event).RecordMarking(tBefore), "the recorded fact is put back")
}

/// <p>The production log line a failed observation writes: one <code>error</code> entry in the
/// console log under the audit-event subsystem, naming the tool and the reason.</p>
Method TestAFailedObservationLogLineNamesTheToolAndTheReason()
{
    Set tPath = ##class(%File).NormalizeFilename(##class(OcuPilot.Port.LogSourcePort).FileFor("messages"), ##class(OcuPilot.Port.LogSourcePort).ManagerDirectory())
    Set tFrom = ##class(%File).GetFileSize(tPath)
    Do $$$AssertTrue(tFrom > 0, "the console log is readable before the call: " _ tPath)
    Set tReason = "auditing-screen-probe-" _ $Job _ "-" _ $ZHorolog
    Do ##class(OcuPilot.Api.ScreenAction).LogObserveFailure(..#TOOL, $$$ERROR($$$GeneralError, tReason))
    Set tText = ""
    Try {
        Set tStream = ##class(%Stream.FileCharacter).%New()
        If tStream.LinkToFile(tPath) && tStream.MoveTo(tFrom + 1) Set tText = tStream.Read(1000000)
    } Catch ex {
        Set tText = ""
    }
    Set tLine = ""
    For tI = 1:1:$Length(tText, $Char(10)) {
        If $Piece(tText, $Char(10), tI) [ tReason Set tLine = $Piece(tText, $Char(10), tI) Quit
    }
    Do $$$AssertNotEquals(tLine, "", "one appended console line carries the reason")
    If tLine = "" Quit
    Set tEntry = ##class(%DynamicObject).%FromJSON($Piece(tLine, "[OcuPilot] ", 2, *))
    Do $$$AssertEquals(tEntry.level, "error", "at error level")
    Do $$$AssertEquals(tEntry.subsystem, ##class(OcuPilot.Kernel.Audit.Event).#LOGSUBSYSTEM, "under the audit-event subsystem")
    Do $$$AssertEquals(tEntry.msg, ##class(OcuPilot.Api.ScreenAction).#OBSERVEFAILED, "with the observation-failed message")
    Do $$$AssertEquals(tEntry.data.tool, ..#TOOL, "naming the tool")
}

/// <p>The system-event list reads the vendor's system events: the auditing change event is there
/// and OcuPilot's own events are not.</p>
Method TestTheSystemEventListReadsSystemEvents()
{
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#SYSTEMLIST, 1000, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the system-event read succeeds")
    If $$$ISERR(tSC) Quit
    Set tNames = ..EventNames(tResult)
    Do $$$AssertTrue($ListFind(tNames, "%System/%Security/AuditChange"), "it holds %System/%Security/AuditChange")
    Do $$$AssertEquals(..CountWithPrefix(tNames, ##class(OcuPilot.Kernel.Audit.Event).Source() _ "/"), 0, "and no OcuPilot event")
}

/// <p>The user-event list reads the registered user events: OcuPilot's own are there and no
/// <code>%System/</code> event is.</p>
Method TestTheUserEventListReadsUserEvents()
{
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#USERLIST, 1000, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the user-event read succeeds")
    If $$$ISERR(tSC) Quit
    Set tNames = ..EventNames(tResult)
    Do $$$AssertTrue(..CountWithPrefix(tNames, ##class(OcuPilot.Kernel.Audit.Event).Source() _ "/") > 0, "it holds OcuPilot's own events")
    Do $$$AssertEquals(..CountWithPrefix(tNames, "%System/"), 0, "and no %System/ event")
}

/// <p>The <code>EventName</code> of every row <var>pResult</var> answers.</p>
ClassMethod EventNames(pResult As %DynamicObject) As %List
{
    Set tNames = ""
    If '$IsObject(pResult) || '$IsObject(pResult.rows) Quit tNames
    Set tIterator = pResult.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tNames = tNames _ $ListBuild(tRow.%Get("EventName"))
    }
    Quit tNames
}

/// <p>How many of <var>pNames</var> begin with <var>pPrefix</var>.</p>
ClassMethod CountWithPrefix(pNames As %List, pPrefix As %String) As %Integer
{
    Set tCount = 0
    For tI = 1:1:$ListLength(pNames) {
        If $Extract($List(pNames, tI), 1, $Length(pPrefix)) = pPrefix Set tCount = tCount + 1
    }
    Quit tCount
}

}
