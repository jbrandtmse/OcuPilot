/// <p>Pins Story 7.6's four Task schedule actions (AD-51, AD-52, AD-53, AD-6): the schedule run is
/// the on-demand run under two other parameters; the suspend and the delete refuse over canned
/// reads what they must; a suspend mint covers <code>Suspended</code> and is refused
/// <code>PROPOSAL.TARGETCHANGED</code> once it moves; the port holds <code>SUSPEND</code>'s
/// constant body; and <class>OcuPilot.Port.TaskPort</class>'s <code>GET</code> names a system
/// task and says it is one.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and a caller holding
/// <code>%Admin_Task:USE</code> and <code>%DB_IRISSYS:READ</code>, on an instance whose Task
/// Manager holds at least one system task. It writes no task: the mint and the confirm go through
/// <class>OcuPilot.Test.ProposalFixture</class>'s port, and every call to a shipped port is a
/// read.</p>
Class OcuPilot.Test.TaskScheduleActions Extends %UnitTest.TestCase
{

Parameter SCREEN = "OcuPilot.Screen.Descriptor.TaskScheduleList";

Parameter SCHEDULERUN = "OcuPilot.Screen.Tool.TaskScheduleRun";

Parameter SUSPEND = "OcuPilot.Screen.Tool.TaskSuspend";

Parameter RESUME = "OcuPilot.Screen.Tool.TaskResume";

Parameter DELETE = "OcuPilot.Screen.Tool.TaskDelete";

Parameter MINT = "OcuPilot.Test.ProposalMint";

Parameter CONFIRM = "OcuPilot.Test.ConfirmFixture";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>A task id no task carries.</p>
Parameter ABSENTID = 999999999;

/// <p>A scheduled task at rest, as <code>INFO</code> answers it.</p>
Parameter FRESHRUNNING = "{""Type"":""User"",""Status"":""1"",""Error"":"""",""LastSchedule"":"""",""LastStarted"":"""",""LastFinished"":"""",""NextScheduled"":""2026-09-24 03:00:00"",""Suspended"":false}";

/// <p>The same task suspended.</p>
Parameter FRESHSUSPENDED = "{""Type"":""User"",""Status"":""1"",""Error"":"""",""LastSchedule"":"""",""LastStarted"":"""",""LastFinished"":"""",""NextScheduled"":""2026-09-24 03:00:00"",""Suspended"":true}";

/// <p>A system task, as <class>OcuPilot.Port.TaskPort</class>'s <code>GET</code> answers it (the
/// fields the delete reads).</p>
Parameter FRESHSYSTEM = "{""Name"":""Switch Journal"",""TaskClass"":""%SYS.Task.SwitchJournal"",""NameSpace"":""%SYS"",""Type"":""System"",""Description"":""""}";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Quit $$$OK
}

/// <p>The schedule run is <class>OcuPilot.Screen.Tool.TaskRun</class> with only
/// <code>TOOLNAME</code> and <code>DESCRIPTORCLASS</code> of its own; the resume carries the
/// schedule's <code>resume</code>; the delete publishes a removal and is destructive; and the list
/// declares the four actions, none self-protected.</p>
/// <p>Mutation (Rule 19): give <class>OcuPilot.Screen.Tool.TaskScheduleRun</class> a third
/// parameter -- the own-members assertion goes red.</p>
Method TestTheFourToolsAndTheListDeclareTheActions()
{
    Set tDefinition = ##class(%Dictionary.ClassDefinition).%OpenId(..#SCHEDULERUN)
    Do $$$AssertTrue($IsObject(tDefinition), "the schedule run is defined")
    If $IsObject(tDefinition) {
        Do $$$AssertEquals(tDefinition.Super, "OcuPilot.Screen.Tool.TaskRun", "as the on-demand run's subclass")
        Kill tNames
        For tI = 1:1:tDefinition.Parameters.Count() {
            Set tNames(tDefinition.Parameters.GetAt(tI).Name) = ""
        }
        Set tOwn = ""
        Set tName = $Order(tNames(""))
        While tName '= "" {
            Set tOwn = tOwn _ $Select(tOwn = "": "", 1: ",") _ tName
            Set tName = $Order(tNames(tName))
        }
        Do $$$AssertEquals(tOwn, "DESCRIPTORCLASS,TOOLNAME", "declaring only its screen and its name: " _ tOwn)
        Do $$$AssertEquals(tDefinition.Methods.Count(), 0, "and no method of its own")
    }
    Do $$$AssertEquals($Parameter(..#SCHEDULERUN, "TOOLNAME"), "tasks.schedule.run", "named for the schedule")
    Do $$$AssertEquals($Parameter(..#SCHEDULERUN, "DESCRIPTORCLASS"), ..#SCREEN, "on the schedule list")

    Do $$$AssertEquals($ListToString($ClassMethod(..#RESUME, "ScreenActionIds")), "resume", "the resume carries the list's resume")
    Do $$$AssertEquals($ListToString($ClassMethod(..#SUSPEND, "ScreenActionIds")), "suspend", "the suspend the list's suspend")
    Do $$$AssertEquals($ClassMethod(..#SUSPEND, "Destructive"), 0, "which is not destructive")
    Do $$$AssertEquals($ListToString($ClassMethod(..#DELETE, "ScreenActionIds")), "delete", "the delete the list's delete")
    Do $$$AssertEquals($ClassMethod(..#DELETE, "ChangeAction"), "deleted", "which publishes a removal")
    Do $$$AssertEquals($ClassMethod(..#DELETE, "Destructive"), 1, "and is destructive")

    Set tSC = $ClassMethod(..#SCREEN, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the list's declaration parses")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tDeclaration.rowActions.%ToJSON(), "[{""id"":""run"",""selfProtection"":""""},{""id"":""suspend"",""selfProtection"":""""},{""id"":""resume"",""selfProtection"":""""},{""id"":""delete"",""selfProtection"":""""}]", "the list declares Run, Suspend, Resume and Delete, none self-protected")
    Do $$$AssertEquals(tDeclaration.table.emptyAgentKey, "taskScheduleEmptyAgent", "its empty state invites the agent")
    Do $$$AssertEquals(tDeclaration.table.emptyNextKey, "", "and names no read-only next step")
    Do $$$AssertEquals(tDeclaration.entityLabelKey, "proposalEntityTask", "and names its entity's noun")
}

/// <p>AC4: <method>OcuPilot.Screen.Tool.TaskSuspend.StateDiff</method>'s three arms -- a task at
/// rest answers <code>Status: Scheduled -&gt; Suspended</code>, a suspended task is a problem (the
/// no-op the vendor would answer 200 for), and an unreadable state is a problem.</p>
/// <p>Mutation (Rule 19): drop the already-suspended refusal from <code>StateDiff</code> -- the
/// suspended arm goes red.</p>
Method TestTheSuspendStateDiffRefusesANoOpAndAnUnreadableState()
{
    Set tSC = $ClassMethod(..#SUSPEND, "StateDiff", ##class(%DynamicAbstractObject).%FromJSON(..#FRESHRUNNING), .tRows, .tProblem)
    Do $$$AssertStatusOK(tSC, "a task at rest answers")
    Do $$$AssertEquals(tProblem, "", "with no problem")
    Do $$$AssertEquals(tRows.%ToJSON(), "[{""field"":""Status"",""before"":""Scheduled"",""after"":""Suspended""}]", "and one row: the task becomes suspended")

    Set tSC = $ClassMethod(..#SUSPEND, "StateDiff", ##class(%DynamicAbstractObject).%FromJSON(..#FRESHSUSPENDED), .tRows, .tProblem)
    Do $$$AssertStatusOK(tSC, "a suspended task answers")
    Do $$$AssertTrue(tProblem [ "already suspended", "as a problem naming the no-op: " _ tProblem)
    Do $$$AssertEquals(tRows.%Size(), 0, "and no row")

    For tJson = "{""Type"":""User""}", "{""Suspended"":""maybe""}" {
        Set tSC = $ClassMethod(..#SUSPEND, "StateDiff", ##class(%DynamicAbstractObject).%FromJSON(tJson), .tRows, .tProblem)
        Do $$$AssertStatusOK(tSC, "an unreadable state answers: " _ tJson)
        Do $$$AssertTrue(tProblem [ "did not report whether", "as a problem naming the unread state: " _ tProblem)
        Do $$$AssertEquals(tRows.%Size(), 0, "and no row")
    }
}

/// <p>AC4, AC5: <method>OcuPilot.Screen.Tool.TaskDelete.StateDiff</method> answers one removal row
/// per subject field, so a system task's rows carry <code>Type: System</code>; a read with no
/// <code>Type</code>, or no <code>Name</code>, is a problem (fail closed).</p>
/// <p>Mutation (Rule 19): drop the absent-<code>Type</code> refusal -- the fail-closed leg goes
/// red.</p>
Method TestTheDeleteStateDiffCarriesTheTypeAndFailsClosedWithoutIt()
{
    Set tSC = $ClassMethod(..#DELETE, "StateDiff", ##class(%DynamicAbstractObject).%FromJSON(..#FRESHSYSTEM), .tRows, .tProblem)
    Do $$$AssertStatusOK(tSC, "a system task answers")
    Do $$$AssertEquals(tProblem, "", "with no problem")
    Do $$$AssertEquals(tRows.%ToJSON(), "[{""field"":""Name"",""before"":""Switch Journal"",""after"":"""",""removed"":true},{""field"":""TaskClass"",""before"":""%SYS.Task.SwitchJournal"",""after"":"""",""removed"":true},{""field"":""NameSpace"",""before"":""%SYS"",""after"":"""",""removed"":true},{""field"":""Type"",""before"":""System"",""after"":"""",""removed"":true}]", "and four removal rows, the last naming it a system task")

    Set tNoType = ##class(%DynamicAbstractObject).%FromJSON(..#FRESHSYSTEM)
    Do tNoType.%Remove("Type")
    Set tSC = $ClassMethod(..#DELETE, "StateDiff", tNoType, .tRows, .tProblem)
    Do $$$AssertStatusOK(tSC, "a read with no Type answers")
    Do $$$AssertTrue(tProblem [ "system tasks", "as a problem naming the unread type: " _ tProblem)
    Do $$$AssertEquals(tRows.%Size(), 0, "and no row")

    Set tNoName = ##class(%DynamicAbstractObject).%FromJSON(..#FRESHSYSTEM)
    Do tNoName.%Remove("Name")
    Set tSC = $ClassMethod(..#DELETE, "StateDiff", tNoName, .tRows, .tProblem)
    Do $$$AssertTrue(tProblem [ "name", "a read with no Name is a problem too: " _ tProblem)
    Do $$$AssertEquals(tRows.%Size(), 0, "and no row")
}

/// <p>AC4: a suspend mint over a canned <code>INFO</code> answer reads <code>INFO</code>, writes
/// nothing and carries the state row; a confirm after the task was suspended by somebody else is
/// refused <code>PROPOSAL.TARGETCHANGED</code> and nothing reaches the port.</p>
/// <p>Mutation (Rule 19): declare
/// <parameter>OcuPilot.Screen.Tool.TaskSuspend.FINGERPRINTSUBJECT</parameter> as a field that does
/// not move -- the moved-target confirm succeeds and goes red.</p>
Method TestTheSuspendMintCoversSuspendedAndAMovedTargetIsRefused()
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESHRUNNING)
    Set tSC = ..MintFor(..#SUSPEND, "41", .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the proposal mints: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastType(), "INFO", "the fresh read is INFO")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastQuery("id"), "41", "keyed by the vendor's id parameter")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and the mint wrote nothing")
    Do $$$AssertEquals(tProposal.%Get("changed").%ToJSON(), "[{""field"":""Status"",""before"":""Scheduled"",""after"":""Suspended""}]", "the card carries the suspend")

    Set tBefore = ##class(OcuPilot.Test.ProposalFixture).ProposalCount()
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESHSUSPENDED)
    Set tSC = ..MintFor(..#SUSPEND, "41", .tRefused, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a suspend of a suspended task is refused at the mint")
    Do $$$AssertEquals(+$Get(tHttp), 400, "at 400")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).ProposalCount(), tBefore, "and nothing is proposed")

    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESHRUNNING)
    Set tSC = ..MintFor(..#SUSPEND, "41", .tProposal, .tHttp, .tFault, tTurn)
    Do $$$AssertStatusOK(tSC, "a proposal inside a turn mints: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESHSUSPENDED)
    Set tWrites = ##class(OcuPilot.Test.ProposalFixture).WriteCount()
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusNotOK(tSC, "a confirm after somebody else suspended it is refused")
    Do $$$AssertEquals(+$Get(tHttp), 409, "at 409")
    Do $$$AssertEquals($Get(tCode), $Parameter("OcuPilot.Kernel.Proposal.Write", "TARGETCHANGED"), "with the moved-target code")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), tWrites, "and nothing reached the port")
}

/// <p>AD-27, AD-51: the port holds <code>Task.CRUD</code> <code>SUSPEND</code>'s constant body,
/// the vendor's own default made explicit, and exempts no caller body for it.</p>
/// <p>Mutation (Rule 19): drop the <code>SUSPEND</code> entry from
/// <parameter>OcuPilot.Port.AdminPort.CONSTANTBODIES</parameter> -- the constant assertions go
/// red.</p>
Method TestThePortHoldsSuspendsConstantBody()
{
    Set tBody = ##class(OcuPilot.Port.AdminPort).ConstantBody("Task.CRUD", "SUSPEND")
    Do $$$AssertTrue($IsObject(tBody), "the port holds a body for Task.CRUD SUSPEND")
    If $IsObject(tBody) Do $$$AssertEquals(tBody.%ToJSON(), "{""LeaveInQueue"":true}", "which is the vendor's LeaveInQueue default")
    Do $$$AssertEquals(##class(OcuPilot.Port.AdminPort).ConstantBody("Process", "SUSPEND"), "", "and none for another endpoint's type of the same name")
    Do $$$AssertEquals(##class(OcuPilot.Port.AdminPort).ConstantBody("Task.CRUD", "DELETE"), "", "and none for the bodyless delete")
    Do $$$AssertTrue(##class(OcuPilot.Port.AdminPort).IsBodyless("Task.CRUD", "DELETE"), "which the port exempts as bodyless")

    Kill tQuery
    Set tQuery("id") = ..#ABSENTID
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Task.CRUD", "SUSPEND", .tQuery, {"LeaveInQueue": false}, .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a caller body for SUSPEND is refused")
    Do $$$AssertEquals(+$Get(tHttp), 500, "as a port fault, before the vendor is called")
    Kill tQuery
    Set tQuery("id") = ..#ABSENTID
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Task.CRUD", "SUSPEND", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp), 404, "while a bodyless SUSPEND reaches the vendor, which answers 404 for a task no task carries")
}

/// <p>AC5, AD-52: <class>OcuPilot.Port.TaskPort</class>'s <code>GET</code> of a system task the
/// vendor's <code>LIST</code> reports answers that task's <code>Name</code> and
/// <code>Type</code> <code>System</code>; its other types answer what the admin port answers; an
/// absent task answers 404. Read-only.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.TaskPort.Invoke</method> skip setting the
/// type -- the <code>Type</code> assertion goes red.</p>
Method TestTheTaskPortNamesASystemTaskAndSaysItIsOne()
{
    Kill tQuery
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Task.CRUD", "LIST", .tQuery, "", .tList, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the vendor LIST answers")
    If $$$ISERR(tSC) Quit
    Set tSystem = ""
    Set tIterator = tList.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) || (tRow.%Get("Type") '= "System") Continue
        Set tSystem = tRow
        Quit
    }
    Do $$$AssertTrue($IsObject(tSystem), "the instance holds a system task")
    If '$IsObject(tSystem) Quit

    Kill tQuery
    Set tQuery("id") = tSystem.%Get("Id")
    Set tSC = ##class(OcuPilot.Port.TaskPort).Invoke("Task.CRUD", "GET", .tQuery, "", .tRead, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the task port's GET answers: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tRead.%Get("Name"), tSystem.%Get("Name"), "naming the task the list reports")
    Do $$$AssertEquals(tRead.%Get("Type"), "System", "and saying it is a system task")
    Do $$$AssertEquals(tRead.%GetTypeOf("TaskClass"), "string", "beside its class")

    Kill tQuery
    Set tQuery("id") = tSystem.%Get("Id")
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Task.CRUD", "GET", .tQuery, "", .tPlain, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the admin port's own GET answers")
    If $IsObject($Get(tPlain)) Do $$$AssertEquals(tPlain.%GetTypeOf("Type"), "unassigned", "and carries no Type, which is why the task port completes it")

    Kill tQuery
    Set tQuery("id") = tSystem.%Get("Id")
    Set tSC = ##class(OcuPilot.Port.TaskPort).Invoke("Task.CRUD", "INFO", .tQuery, "", .tInfo, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the task port's INFO answers")
    If $IsObject($Get(tInfo)) Do $$$AssertEquals(tInfo.%GetTypeOf("Name"), "unassigned", "unchanged: INFO still names nothing")

    Kill tQuery
    Set tQuery("id") = ..#ABSENTID
    Set tSC = ##class(OcuPilot.Port.TaskPort).Invoke("Task.CRUD", "GET", .tQuery, "", .tRead, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a task no task carries fails")
    Do $$$AssertEquals(+$Get(tHttp), 404, "at the vendor's own 404")
}

/// <p>Mint one proposal of <var>pTool</var> for <var>pId</var> through <parameter>MINT</parameter>,
/// whose one replaced seam is the port.</p>
Method MintFor(pTool As %String, pId As %String, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, pTurnKey As %String = "") As %Status
{
    Set tArgs = {}
    Do tArgs.%Set($ClassMethod(pTool, "IdArgument"), pId, "string")
    Quit $ClassMethod(..#MINT, "Mint", ..#SCREEN, $Parameter(pTool, "TOOLNAME"), $Username, "", pTurnKey, tArgs, ..#LIMITS, .pProposal, .pHttpStatus, .pFault, $ClassMethod(pTool, "Endpoint"), $ClassMethod(pTool, "IdParam"), pId, $ClassMethod(pTool, "IdArgument"), $ClassMethod(pTool, "SettableFields"), pTool)
}

}
