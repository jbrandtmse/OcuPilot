/// <p>Task details (Story 6.7): the declaration against the read, criteria and classic-link
/// grammar, the Tasks area's pair set and the registry; the I/O matrix over the wire as
/// <code>_SYSTEM</code> -- the demo task, a deleted or unknown id, no id and an over-long id; that
/// <method>OcuPilot.Screen.Registry.RouteEntityType</method> answers <code>task</code> for it; and
/// the integration AC, the read tool answering the same row the route does with no
/// <code>Settings</code> key.</p>
/// <p>Needs the API application installed in <code>HSCUSTOM</code> and the demo fixture, whose
/// <code>OcuPilotDemo nightly purge</code> task supplies the one row every matrix case but "Deleted
/// or unknown" reads. It finds that task's own numeric <code>Id</code> from the task schedule at run
/// time rather than pinning it, because the vendor assigns it. Issues reads only.</p>
Class OcuPilot.Test.TaskDetails Extends %UnitTest.TestCase
{

/// <p>The descriptor under test.</p>
Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.TaskDetails";

/// <p>The tool identifier the screen read and the derived read tool share.</p>
Parameter TOOL = "tasks.taskdetails";

/// <p>The name every demo task starts with, on this instance's demo fixture.</p>
Parameter DEMONAME = "OcuPilotDemo";

/// <p>How long, in seconds, <method>TestTheDemoTaskReadsOverTheWire</method> polls Task details'
/// own read waiting for <code>Suspended</code> to read true, before asserting against whatever it
/// last read. The demo fixture's own <code>%SYS.Task.RunNow</code> request does not wait for the
/// Task Manager's next once-a-minute pass (<class>OcuPilot.Install.Fixture</class>'s
/// <code>CreateTask</code>, the owner's decision) -- the same documented async gap
/// <method>OcuPilot.Test.Demo.TestDemoTaskIsSuspendedAfterAnError</method> owns a wait for, and a
/// throwaway freshly reported healthy has not necessarily seen that pass yet. Same budget as that
/// test's <parameter>SUSPENDWAITSECONDS</parameter>, for the same reason.</p>
Parameter SUSPENDWAITSECONDS As %Integer = 180;

/// <p>Seconds between the fresh reads this class's poll makes while it waits.</p>
Parameter SUSPENDPOLLSECONDS As %Integer = 5;

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $$$OK
}

/// <p>Request <var>pTool</var>'s read at <var>pMaxRows</var>, with <var>pQuery</var> appended, as
/// <code>_SYSTEM</code>. <var>pAnswer</var> is the parsed body, or <code>""</code> when it does not
/// parse, which is a failed assertion on its own.</p>
Method Read(pTool As %String, pMaxRows As %Integer, pQuery As %String, Output pStatus As %Integer, Output pAnswer As %DynamicObject) As %Status
{
    Set pAnswer = ""
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", "/api/ocupilot/screens/" _ pTool _ "/read?maxRows=" _ pMaxRows _ pQuery, "_SYSTEM", "SYS", .pStatus, .tBody, .tHeaders)
    If $$$ISERR(tSC) Quit tSC
    Try {
        Set pAnswer = ##class(%DynamicObject).%FromJSON($ZConvert(tBody, "I", "UTF8"))
    } Catch {
        Set pAnswer = ""
    }
    Do $$$AssertTrue($IsObject(pAnswer), pTool _ ": the body parses as JSON")
    Quit tSC
}

/// <p>The demo fixture task's own numeric <code>Id</code>, found from the task schedule's live
/// rows. <code>""</code> when the demo task is not listed or the read fails, which the callers that
/// need it fail on rather than silently skip.</p>
Method DemoTaskId() As %String
{
    Set tId = ""
    Set tSC = ..Read("tasks.schedule", 1000, "", .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the task schedule request completes")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit tId
    Set tIterator = tAnswer.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $Extract(tRow.Name, 1, $Length(..#DEMONAME)) = ..#DEMONAME {
            Set tId = tRow.Id
            Quit
        }
    }
    Quit tId
}

/// <p>The declaration passes the read, criteria and classic-link grammar; its route and tool
/// identifier resolve to it; its classic page is a class compiled on this instance; it is the
/// Tasks area's entry on the <code>task</code> entity type, at instance scope, parented to Task
/// schedule, keyed by the composite <code>Id</code>, refreshing at the AD-43 roster; it declares no
/// <code>Settings</code> field anywhere and no secret; and the Tasks area covers its pair set.</p>
/// <p>Mutation: remove <code>%DB_IRISSYS:READ</code> from the descriptor -&gt;
/// <method>OcuPilot.Screen.Registry.ReadProblem</method> refuses it and this goes red naming the
/// missing pair.</p>
Method TestTheDeclarationValidatesAndIsDeclaredAsTaskDetails()
{
    Set tClass = ..#DESCRIPTOR
    Set tSC = $ClassMethod(tClass, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ReadProblem(tDeclaration), "", "its read and table are the declared grammar")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).CriteriaProblem(tDeclaration), "", "and so are its criteria")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ClassicLinkProblem(tDeclaration), "", "and it links out to nothing")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForRoute("tasks/schedule/details"), tClass, "the route resolves to it")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).DescriptorForTool(..#TOOL), tClass, "and so does its tool identifier")

    Set tPage = $ClassMethod(tClass, "ClassicPage")
    Do $$$AssertEquals(tPage, "%CSP.UI.Portal.TaskInfo", "the classic page is TaskInfo")
    Do $$$AssertTrue($IsObject(##class(%Dictionary.CompiledClass).%OpenId(tPage)), "which is a class compiled on this instance")

    Do $$$AssertEquals($ClassMethod(tClass, "AreaKey"), "tasks", "in the Tasks area")
    Do $$$AssertEquals($ClassMethod(tClass, "SideBarPosition"), 0, "routable but unlisted")
    Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), "detail", "on the detail archetype")
    Do $$$AssertEquals($ClassMethod(tClass, "ParentScope"), "tasks/schedule", "parented to Task schedule")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "EntityTypes")), "task", "on the task entity type")
    Do $$$AssertEquals($ClassMethod(tClass, "Scope"), "instance", "at instance scope")
    Do $$$AssertEquals($ClassMethod(tClass, "IdKind"), "composite", "keyed by a composite id")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "IdParts")), "Id", "over the one part Id")
    Do $$$AssertEquals($ClassMethod(tClass, "Refreshes"), 1, "and it refreshes")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "RefreshRates")), "5,10,30,60", "at the AD-43 roster")
    Do $$$AssertEquals(tDeclaration.context.secretFields.%Size(), 0, "with no secret field")
    Do $$$AssertEquals($ListLength($ClassMethod(tClass, "RowActionIds")) + ($ClassMethod(tClass, "PrimaryActionId") '= ""), 0, "because it declares no action")

    ; AD-24/AD-35: Settings carries arbitrary task-class properties, passwords among them, and is
    ; never named -- checked over the read fields, the rowGet's detail fields and the context.
    Set tAllNames = tDeclaration.read.fields.%ToJSON() _ tDeclaration.read.source.rowGet.fields.%ToJSON() _ tDeclaration.context.fields.%ToJSON()
    Do $$$AssertTrue(tAllNames '[ "Settings", "Settings is named nowhere: " _ tAllNames)

    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).AreaCoverageProblem("tasks", $ClassMethod(tClass, "PrivilegePairs")), "", "and the Tasks area covers its pair set")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).RouteEntityType(tClass), "task", "its route id names a task, resolved through its parent (DW-1020)")
}

/// <p>Matrix "Demo task" -- the demo task's own read answers every declared field as a key, with
/// <code>Name</code> the demo task, <code>TimePeriod</code> "Daily", <code>DailyFrequency</code>
/// "Once", <code>DailyStartTime</code> "03:00:00", <code>Suspended</code> true and a non-empty
/// <code>Error</code> (the fixture fails by design).</p>
/// <p><b>Polls for <code>Suspended</code> rather than asserting on the first read</b>
/// (<parameter>SUSPENDWAITSECONDS</parameter>): reproduced live against a throwaway freshly
/// reported healthy, the first read after <code>ci-throwaway.sh up --wait</code> answers
/// <code>Suspended</code> false with an empty <code>Error</code>, because the fixture's own
/// <code>RunNow</code> request had not yet reached the Task Manager's next once-a-minute pass. This
/// mirrors <method>OcuPilot.Test.Demo.TestDemoTaskIsSuspendedAfterAnError</method>'s own wait for
/// the same gap, rather than assuming it has already closed.</p>
Method TestTheDemoTaskReadsOverTheWire()
{
    Set tTaskId = ..DemoTaskId()
    Do $$$AssertTrue(tTaskId '= "", "the demo task's Id was found")
    If tTaskId = "" Quit

    Set tBudget = ..#SUSPENDWAITSECONDS
    Set tPoll = ..#SUSPENDPOLLSECONDS
    Set tWaited = 0
    Set tStatus = 0
    Set tAnswer = ""
    Set tSC = $$$OK
    While 1 {
        Set tSC = ..Read(..#TOOL, 5, "&taskId=" _ tTaskId, .tStatus, .tAnswer)
        If $$$ISERR(tSC) || (tStatus '= 200) || '$IsObject(tAnswer) || (tAnswer.rows.%Size() '= 1) Quit
        If tAnswer.rows.%Get(0).Suspended Quit
        If tWaited >= tBudget Quit
        Hang tPoll
        Set tWaited = tWaited + tPoll
    }

    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the read answers")
    If (tStatus '= 200) || '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.rows.%Size(), 1, "exactly one row")
    If tAnswer.rows.%Size() '= 1 Quit
    Set tRow = tAnswer.rows.%Get(0)

    Set tFieldIterator = $ClassMethod(..#DESCRIPTOR, "Read").fields.%GetIterator()
    While tFieldIterator.%GetNext(.tIndex, .tField) {
        Do $$$AssertTrue(tRow.%IsDefined(tField), "declared field '" _ tField _ "' is a key of the live row")
    }

    Do $$$AssertTrue(tRow.Name [ ..#DEMONAME, "Name is the demo task: " _ tRow.Name)
    Do $$$AssertEquals(tRow.TimePeriod, "Daily", "TimePeriod is Daily")
    Do $$$AssertEquals(tRow.DailyFrequency, "Once", "DailyFrequency is Once")
    Do $$$AssertEquals(tRow.DailyStartTime, "03:00:00", "DailyStartTime is 03:00:00")
    Do $$$AssertTrue(tRow.Suspended, "Suspended is true (waited " _ tWaited _ "s for the Task Manager's pass)")
    Do $$$AssertTrue(tRow.Error '= "", "Error is non-empty, since the fixture fails by design")
}

/// <p>Matrix "Deleted or unknown" -- an id no task holds answers 200 with no rows (AD-37), not a
/// refusal: there is no way to tell "wrong id" from "gone" from the vendor's own 404.</p>
Method TestAnUnknownIdReadsAsNoRows()
{
    Set tSC = ..Read(..#TOOL, 5, "&taskId=999999", .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "not a refusal")
    If tStatus '= 200 Quit
    Do $$$AssertEquals(tAnswer.rows.%Size(), 0, "and no rows")
}

/// <p>Matrix "No id" -- a parent-scoped GET called without its one criterion is refused 400
/// <code>READ.CRITERION</code> naming <code>taskId</code>, before the port.</p>
Method TestNoIdIsRefused()
{
    Set tSC = ..Read(..#TOOL, 5, "", .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 400, "refused")
    If tStatus '= 400 Quit
    Do $$$AssertEquals(tAnswer.code, "READ.CRITERION", "naming the criterion code")
    Do $$$AssertTrue(tAnswer.reason [ "taskId", "and naming taskId: " _ tAnswer.reason)
    Do $$$AssertEquals(tAnswer.%GetTypeOf("rows"), "unassigned", "with no rows")
}

/// <p>Matrix "Bad id" -- eleven characters is over <code>taskId</code>'s declared ten-character
/// bound, refused 400 <code>READ.CRITERION</code> before the port, never a 500 from an over-long
/// vendor property.</p>
Method TestAnOverLongIdIsRefused()
{
    Set tSC = ..Read(..#TOOL, 5, "&taskId=12345678901", .tStatus, .tAnswer)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 400, "refused")
    If tStatus '= 400 Quit
    Do $$$AssertEquals(tAnswer.code, "READ.CRITERION", "naming the criterion code")
}

/// <p>The integration AC -- the read tool, called in process with the demo Id, answers the same one
/// row the route's own read does, with no <code>Settings</code> key.</p>
Method TestTheReadToolAnswersTheSameRowAsTheRoute()
{
    Set tTaskId = ..DemoTaskId()
    Do $$$AssertTrue(tTaskId '= "", "the demo task's Id was found")
    If tTaskId = "" Quit

    Set tArgs = {}
    Do tArgs.%Set("taskId", tTaskId, "string")
    Do ##class(OcuPilot.Kernel.Scope).Set("HSCUSTOM")
    Set tSC = ##class(OcuPilot.Screen.Tool.Read).View(..#DESCRIPTOR, tArgs, 1000, .tView)
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK(tSC, "the tool reads")
    If $$$ISERR(tSC) || '$IsObject(tView) Quit
    Do $$$AssertEquals(tView.rows.%Size(), 1, "the tool answers one row")

    Set tRouteSC = ..Read(..#TOOL, 1000, "&taskId=" _ tTaskId, .tStatus, .tRoute)
    Do $$$AssertEquals(tStatus, 200, "the route answers the same read")
    If (tStatus '= 200) || '$IsObject(tRoute) Quit

    Do $$$AssertEquals(tView.fields.%ToJSON(), tRoute.fields.%ToJSON(), "the same declared fields")
    Do $$$AssertEquals(tView.rows.%ToJSON(), tRoute.rows.%ToJSON(), "and the same one row")
    Do $$$AssertEquals(tView.%GetTypeOf("Settings"), "unassigned", "the tool view carries no Settings key")
    If tView.rows.%Size() > 0 Do $$$AssertEquals(tView.rows.%Get(0).%GetTypeOf("Settings"), "unassigned", "and neither does its one row")
}

}
