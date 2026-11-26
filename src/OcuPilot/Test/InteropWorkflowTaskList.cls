/// <p>Pins Story 24.17 Batch 4's reads (AD-5, AD-29, AD-36, AD-62): the Workflow tasks and Workflow worklist screens' declarations, their lists newest first and the one-task read through the port, the
/// screens' read route and the agent's read tools, which answer the same rows; and both lists' caps and one over. The probes are <code>EnsLib.Workflow.TaskResponse</code> and
/// <code>Worklist</code> rows in <code>USER</code> and <code>HSCUSTOM</code> saved through the vendor's own classes.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropWorkflowCase</class> needs. It starts no production.</p>
Class OcuPilot.Test.InteropWorkflowTaskList Extends OcuPilot.Test.InteropWorkflowTaskCase
{

/// <p>The task list row as <code>role|complete|status|priority|assignedTo|subject|namespace</code>.</p>
ClassMethod RowText(pRow As %DynamicObject) As %String
{
    Quit pRow.RoleName _ "|" _ pRow.IsComplete _ "|" _ pRow.Status _ "|" _ pRow.Priority _ "|" _ pRow.AssignedTo _ "|" _ pRow.Subject _ "|" _ pRow.Namespace
}

/// <p>The two screens are declared as the plan places them: Workflow tasks at side bar 27 keyed by the task's id with Assign and Cancel task as its row actions and no primary action, Workflow worklist at
/// side bar 28 keyed by the task and the user with no action; each over the portal's pair alone, naming the classic page it replaces and declaring no secret.</p>
/// <p>Mutation (Rule 19): change the tasks screen's <code>sideBarPosition</code> to 26 -- this goes red.</p>
Method TestTheDeclarationsRegister()
{
    Set tSC = ##class(OcuPilot.Screen.Descriptor.InteropWorkflowTaskList).DeclarationJson(.tTasks)
    Do $$$AssertStatusOK(tSC, "the tasks screen declares JSON")
    Set tSC = ##class(OcuPilot.Screen.Descriptor.InteropWorkflowWorklist).DeclarationJson(.tWorklist)
    Do $$$AssertStatusOK(tSC, "and so does the worklist screen")
    If '$IsObject($Get(tTasks)) || '$IsObject($Get(tWorklist)) Quit
    Do $$$AssertEquals(tTasks.route _ "|" _ tTasks.sideBarPosition _ "|" _ tTasks.archetype _ "|" _ tTasks.area, "interoperability/workflow-tasks|27|list|interoperability", "the tasks' route, place, archetype and area")
    Do $$$AssertEquals(tTasks.entityType _ "|" _ tTasks.id.kind _ "|" _ tTasks.id.parts.%ToJSON() _ "|" _ tTasks.toolIdentifier, "interop-workflow-task|composite|[""TaskId""]|interop.workflowtasks", "their entity type, key and tool identifier")
    Do $$$AssertEquals(tTasks.primaryAction.id _ "|" _ tTasks.rowActions.%Get(0).id _ "," _ tTasks.rowActions.%Get(1).id, "|assign,cancel", "no primary action, and Assign and Cancel task as the row actions")
    Do $$$AssertEquals(tWorklist.route _ "|" _ tWorklist.sideBarPosition _ "|" _ tWorklist.archetype _ "|" _ tWorklist.entityType _ "|" _ tWorklist.id.parts.%ToJSON() _ "|" _ tWorklist.rowActions.%Size(), "interoperability/workflow-worklist|28|list||[""TaskId"",""UserName""]|0", "the worklist's route, place, entity-less key and no row action")
    Do $$$AssertEquals(tWorklist.toolIdentifier _ "|" _ tWorklist.table.emptyNextKey, "interop.workflowworklist|tableReadOnlyEmptyNext", "its tool identifier and its read-only empty state")
    Do $$$AssertEquals(tTasks.secondaryEntityTypes.%ToJSON() _ "|" _ tWorklist.secondaryEntityTypes.%ToJSON(), "[""interop-workflow-user"",""interop-workflow-member""]|[""interop-workflow-task"",""interop-workflow-user"",""interop-workflow-member""]", "the tasks re-read on a workflow user's or member's change, and the worklist on a task's too")
    Do $$$AssertEquals(tTasks.classicPage _ "|" _ tWorklist.classicPage _ "|" _ tTasks.context.secretFields.%ToJSON() _ "|" _ tWorklist.context.secretFields.%ToJSON(), "EnsPortal.WFTasklist|EnsPortal.WFWorklist|[]|[]", "the classic pages and no secret field")
    Set tPairs = "[{""resource"":""%Ens_Portal"",""permission"":""USE""}]"
    Do $$$AssertEquals(tTasks.privileges.%ToJSON() _ tWorklist.privileges.%ToJSON(), tPairs _ tPairs, "their pairs are the classic pages': the portal's alone")
    Do $$$AssertTrue(($ListFind($ClassMethod(..#PORT, "Endpoints"), ..#ENDPOINT) > 0) && ($ListFind($ClassMethod(..#PORT, "Endpoints"), ..#WORKLISTENDPOINT) > 0), "the port serves both endpoints")
}

/// <p>AC1: the tasks list answers every probe task of the namespace newest first with its role, completeness, status, priority, assignee, subject and namespace, another namespace's tasks are not listed, and the
/// one-task read answers the same fields for the id and 404 for an id that is held by no task or that the port does not read.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ListWorkflowTasks</method> order by <code>%ID</code> ascending -- this goes red.</p>
Method TestTheTasksListAnswersEveryProbeNewestFirst()
{
    Do $$$AssertStatusOK(..Arrange(), "the probe role and users are stored")
    Set tFx = ..#FIXTURE
    Set tOne = $ClassMethod(tFx, "ProbeTask", ..#ROLE, "", ..#USERA)
    Set tTwo = $ClassMethod(tFx, "ProbeTask", ..#ROLE, ..#USERB, ..#USERB)
    Set tThree = $ClassMethod(tFx, "ProbeTask", ..#ROLE, "", "")
    Do $$$AssertTrue(tOne && tTwo && tThree && (tTwo > tOne) && (tThree > tTwo), "three tasks are stored, in order of their ids")
    Do $$$AssertStatusOK($ClassMethod(tFx, "CompleteProbe", tThree), "and the newest is completed")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeRole", ..#ROLE _ "h", ..#OTHER), "a role is stored in HSCUSTOM")
    Set tHsc = $ClassMethod(tFx, "ProbeTask", ..#ROLE _ "h", "", "", ..#OTHER)
    Kill tQuery
    Do $$$AssertEquals(..Verdict("LIST", .tRows, .tFault, .tQuery), "200 ", "the list answers 200")
    Do $$$AssertEquals(..Names(tRows, "TaskId"), tThree _ "," _ tTwo _ "," _ tOne, "exactly the probes of USER, newest first")
    If '$IsObject($Get(tRows)) Quit
    Do $$$AssertEquals(..RowText(tRows.%Get(0)) _ ";" _ ..RowText(tRows.%Get(1)) _ ";" _ ..RowText(tRows.%Get(2)), ..#ROLE _ "|1|Completed|0||" _ $Parameter(tFx, "TASKSUBJECT") _ "|USER;" _ ..#ROLE _ "|0||0|" _ ..#USERB _ "|" _ $Parameter(tFx, "TASKSUBJECT") _ "|USER;" _ ..#ROLE _ "|0||0||" _ $Parameter(tFx, "TASKSUBJECT") _ "|USER", "each row carries its role, completeness, status, priority, assignee, subject and namespace")
    Do $$$AssertEquals(tRows.%Get(1).TaskId _ "|" _ tRows.%Get(1).Duration _ "|" _ tRows.%Get(1).User, tTwo _ "||" _ ..#USERB, "the task id is text, an open task has no duration, and User is the assignee")
    Kill tQuery
    Do $$$AssertEquals(..Verdict("LIST", .tOther, .tFault, .tQuery, "", ..#OTHER), "200 ", "HSCUSTOM's list answers 200")
    Do $$$AssertEquals(..Names(tOther, "TaskId"), tHsc, "and holds its own probe alone")
    Set tText = ..Read(tTwo, "", .tRow, .tFault)
    Do $$$AssertEquals(tText _ "|" _ ..RowText(tRow), "200 |" _ ..#ROLE _ "|0||0|" _ ..#USERB _ "|" _ $Parameter(tFx, "TASKSUBJECT") _ "|USER", "the one-task read answers the same fields")
    For tBad = "999999999", "0", "abc", "0" _ tTwo, "-" _ tTwo, tTwo _ ".5" {
        Do $$$AssertEquals(..Read(tBad, "", .tRow, .tFault), "404 PORT.NOTFOUND", "'" _ tBad _ "' is held by no task or not an id this port reads")
    }
    Do $$$AssertEquals(..Read(tThree, "ASSIGNWORKFLOWTASK", .tRow, .tFault), "409 INTEROP.WORKFLOW.TASKCOMPLETE", "a read composed for an assign of the completed task is refused as the write would be")
}

/// <p>AC1: the tasks screen's declared view keeps the port's newest-first order when task IDs differ in their number of digits, as they do once IDs pass a power of ten, and when two tasks share a
/// creation time; the ID is text, so a view sorted by it would put 9 above 10.</p>
/// <p>Mutation (Rule 19): make the tasks screen's default sort <code>TaskId</code> -- this goes red.</p>
Method TestTheTasksViewKeepsNewestFirstAcrossIdLengths()
{
    Set tSC = ##class(OcuPilot.Screen.Descriptor.InteropWorkflowTaskList).DeclarationJson(.tTasks)
    Do $$$AssertStatusOK(tSC, "the tasks screen declares JSON")
    If '$IsObject($Get(tTasks)) Quit
    Set tRows = [{"TaskId": "100", "TimeCreated": "2026-01-01T00:00:03.000"}, {"TaskId": "99", "TimeCreated": "2026-01-01T00:00:03.000"}, {"TaskId": "10", "TimeCreated": "2026-01-01T00:00:02.000"}, {"TaskId": "9", "TimeCreated": "2026-01-01T00:00:01.000"}]
    Set tView = ##class(OcuPilot.Screen.Read).ApplyView(tRows, tTasks.read)
    Do $$$AssertEquals(..Names(tView, "TaskId"), "100,99,10,9", "the declared view lists the port's rows newest first")
}

/// <p>AC1: the worklist answers one row for each user a task was sent to, newest first, with the task, user, role, priority, age and the task's assignee, and none of another namespace's items.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ListWorkflowWorklist</method> read the task's id as the user's name -- this goes red.</p>
Method TestTheWorklistAnswersOneRowForEachItemNewestFirst()
{
    Do $$$AssertStatusOK(..Arrange(), "the probe role and users are stored")
    Set tFx = ..#FIXTURE
    Set tOne = $ClassMethod(tFx, "ProbeTask", ..#ROLE, "", ..#USERA)
    Set tTwo = $ClassMethod(tFx, "ProbeTask", ..#ROLE, ..#USERB, ..#USERB)
    Do $$$AssertTrue(tOne && tTwo, "two tasks with a worklist item each are stored")
    Do $$$AssertEquals(..Worklist(.tRows, .tFault), "200 ", "the worklist answers 200")
    Do $$$AssertEquals(..Canon(tRows, "TaskId,UserName,RoleName,AssignedTo,Namespace"), tTwo _ "=" _ ..#USERB _ "=" _ ..#ROLE _ "=" _ ..#USERB _ "=USER=" _ $Char(10) _ tOne _ "=" _ ..#USERA _ "=" _ ..#ROLE _ "==USER=" _ $Char(10), "one row for each item, the newer first")
    If '$IsObject($Get(tRows)) Quit
    Do $$$AssertTrue((tRows.%Get(0).Age '= "") && (tRows.%Get(0).TimeCreated '= "") && (tRows.%Get(0).Subject = $Parameter(tFx, "TASKSUBJECT")), "each row carries its age, creation time and the task's subject")
    Do $$$AssertEquals(..Worklist(.tOther, .tFault, ..#OTHER) _ "|" _ tOther.%Size(), "200 |0", "HSCUSTOM holds no item")
}

/// <p>AC1: the screens' read route and the agent's read tools answer the rows the port answers: the tasks list through the tasks screen's route and <code>interop.workflowtasks.read</code>, the worklist
/// through the worklist's route and <code>interop.workflowworklist.read</code>.</p>
/// <p>Mutation (Rule 19): rename the <code>AssignedTo</code> field in <class>OcuPilot.Screen.Descriptor.InteropWorkflowTaskList</class>'s read -- the route and the tool answer no assignee and this goes red.</p>
Method TestTheReadRoutesAndTheReadToolsAnswerTheSameRows()
{
    Do $$$AssertStatusOK(..Arrange(), "the probe role and users are stored")
    Set tFx = ..#FIXTURE
    Do $$$AssertTrue($ClassMethod(tFx, "ProbeTask", ..#ROLE, "", ..#USERA) && $ClassMethod(tFx, "ProbeTask", ..#ROLE, ..#USERB, ..#USERB), "two tasks are stored")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#SOURCE)
    Kill tQuery
    Do ..Verdict("LIST", .tPortTasks, .tFault, .tQuery)
    Do ..Worklist(.tPortItems, .tFault)
    Set tTaskClass = "OcuPilot.Screen.Descriptor.InteropWorkflowTaskList"
    Set tItemClass = "OcuPilot.Screen.Descriptor.InteropWorkflowWorklist"
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(tTaskClass, 1000, .tTaskAnswer, .tTaskHttp, .tTaskFault, .tNone)
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(tItemClass, 1000, .tItemAnswer, .tItemHttp, .tItemFault, .tNone)
    Do $$$AssertEquals(tTaskHttp _ "|" _ tItemHttp, "200|200", "both routes answer")
    Set tTaskTool = ""
    Set tItemTool = ""
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve($ClassMethod(tTaskClass, "ToolIdentifier") _ ".read", .tTaskTool)
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve($ClassMethod(tItemClass, "ToolIdentifier") _ ".read", .tItemTool)
    Do $$$AssertTrue($IsObject(tTaskTool) && $IsObject(tItemTool), "interop.workflowtasks.read and interop.workflowworklist.read are registered read tools")
    If '$IsObject(tTaskTool) || '$IsObject(tItemTool) Quit
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTaskTool, {}, 1000, .tTaskResult, .tTaskToolHttp, .tTaskToolFault)
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tItemTool, {}, 1000, .tItemResult, .tItemToolHttp, .tItemToolFault)
    Do $$$AssertEquals(tTaskToolHttp _ "|" _ tItemToolHttp, "200|200", "and both tools")
    If '$IsObject($Get(tTaskAnswer)) || '$IsObject($Get(tTaskResult)) || '$IsObject($Get(tItemAnswer)) || '$IsObject($Get(tItemResult)) Quit
    Do $$$AssertEquals(tPortTasks.%Size() _ "|" _ tPortItems.%Size(), "2|2", "the port answers two tasks and two items")
    Set tTaskFields = "TaskId,RoleName,IsComplete,Status,Priority,Source,AssignedTo,Subject"
    Set tItemFields = "TaskId,UserName,RoleName,Priority,AssignedTo,Subject"
    Do $$$AssertEquals(..Canon(tTaskAnswer.rows, tTaskFields), ..Canon(tPortTasks, tTaskFields), "the tasks route's rows are the port's")
    Do $$$AssertEquals(..Canon(tTaskResult.rows, tTaskFields), ..Canon(tPortTasks, tTaskFields), "and so are the tasks tool's")
    Do $$$AssertEquals(..Canon(tItemAnswer.rows, tItemFields), ..Canon(tPortItems, tItemFields), "the worklist route's rows are the port's")
    Do $$$AssertEquals(..Canon(tItemResult.rows, tItemFields), ..Canon(tPortItems, tItemFields), "and so are the worklist tool's")
}

/// <p>AC1: both lists are cut at a named limit when the caller names no cap, and truncation is the caller's to read from the row it asks for beyond its own cap: three tasks and three items at the limit of
/// three are all listed and a fourth of each one over answers the limit; a caller that asks for one row beyond a cap is answered it. The shipped limits are 10,000 each, measured.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.WorkflowCap</method> answer no more than <var>pLimit</var> -- the row asked for beyond the cap is lost and this goes red.</p>
Method TestBothListsStopAtTheirNamedLimit()
{
    Set tCap = ..#CAPSEAM
    Do $$$AssertEquals($Parameter(..#PORT, "WORKFLOWTASKSMAX") _ "|" _ $Parameter(..#PORT, "WORKFLOWWORKLISTMAX"), "10000|10000", "the shipped limits are 10,000 tasks and 10,000 items")
    Do $$$AssertEquals($Parameter(tCap, "WORKFLOWTASKSMAX") _ "|" _ $Parameter(tCap, "WORKFLOWWORKLISTMAX"), "3|3", "the seam lowers both to three")
    Do $$$AssertStatusOK(..Arrange(), "the probe role and users are stored")
    Set tFx = ..#FIXTURE
    For tI = 1:1:3 {
        Set tId(tI) = $ClassMethod(tFx, "ProbeTask", ..#ROLE, "", ..#USERA)
    }
    Kill tQuery
    Do ..Verdict("LIST", .tAt, .tFault, .tQuery, "", ..#SOURCE, tCap)
    Do $$$AssertEquals(..Names(tAt, "TaskId"), tId(3) _ "," _ tId(2) _ "," _ tId(1), "three tasks at the limit: all three")
    Do ..Worklist(.tItemsAt, .tFault, ..#SOURCE, tCap)
    Do $$$AssertEquals($Select($IsObject($Get(tItemsAt)): tItemsAt.%Size(), 1: -1), 3, "three items at the limit: all three")
    Set tId(4) = $ClassMethod(tFx, "ProbeTask", ..#ROLE, "", ..#USERA)
    Kill tQuery
    Do ..Verdict("LIST", .tOver, .tFault, .tQuery, "", ..#SOURCE, tCap)
    Do $$$AssertEquals(..Names(tOver, "TaskId"), tId(4) _ "," _ tId(3) _ "," _ tId(2), "four tasks, one over: the limit, the newest three")
    Do ..Worklist(.tItemsOver, .tFault, ..#SOURCE, tCap)
    Do $$$AssertEquals($Select($IsObject($Get(tItemsOver)): tItemsOver.%Size(), 1: -1), 3, "four items, one over: the limit")
    Kill tQuery
    Set tQuery("maxRows") = 4
    Do ..Verdict("LIST", .tAsked, .tFault, .tQuery, "", ..#SOURCE, tCap)
    Do $$$AssertEquals($Select($IsObject($Get(tAsked)): tAsked.%Size(), 1: -1), 4, "a caller whose cap is the limit asks for one row more and is answered it, so it reads the truncation")
    Do ..Worklist(.tItemsAsked, .tFault, ..#SOURCE, tCap, 4)
    Do $$$AssertEquals($Select($IsObject($Get(tItemsAsked)): tItemsAsked.%Size(), 1: -1), 4, "and so does a worklist reader")
    Kill tQuery
    Set tQuery("maxRows") = 0
    Do $$$AssertEquals(..Verdict("LIST", .tBad, .tFault, .tQuery), "400 PORT.VALIDATION", "a cap that is not a whole number above zero is refused by name")
}

}
