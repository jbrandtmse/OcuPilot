/// <p>Pins Story 24.17 Batch 4's assign, unassign and priority change end to end against probe tasks in <code>USER</code> (AD-6, AD-14, AD-15, AD-51, AD-53, AD-58, AD-59, AD-62): a person's Assign on the
/// Workflow tasks screen and the agent's assign tool, minted and confirmed over HTTP, each answer a read-back verdict and the change event's triple, and what they stored reads back from
/// <code>EnsLib.Workflow.TaskResponse</code> and <code>Worklist</code> exactly as the vendor's assign or unassign leaves it. The vendor records no audit row, so OcuPilot's own <code>ConfigChange</code> is
/// the record, naming the namespace, the task id, the assignee and the priority, never a subject. The script form of each write names the task and runs nothing.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropWorkflowCase</class> needs, the HTTP test account, and an interoperability-enabled <code>USER</code> namespace. It starts
/// no production and removes every probe it creates.</p>
Class OcuPilot.Test.InteropWorkflowTaskControl Extends OcuPilot.Test.InteropWorkflowTaskCase
{

/// <p>The task <var>pId</var>'s assignee and priority, <code>assignedTo|priority</code>.</p>
ClassMethod Who(pId As %String, pNamespace As %String = {..#SOURCE}) As %String
{
    Quit $Piece($ClassMethod(..#FIXTURE, "TaskText", pNamespace, pId), "|", 2, 3)
}

/// <p>AC2: a person's Assign sends a task to one user, takes it off every other user's worklist, sends it to every active member when it is made Unassigned, and changes the priority alone while
/// keeping the assignment; each answers 200 with the change event's triple and a read-back that matches, stores exactly what was sent, and records one <code>ConfigChange</code> naming the namespace,
/// the task, the assignee and the priority, and no subject.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.WorkflowTaskVendor</method> skip <code>SendTaskToAll</code> after the unassign -- the members' items leg goes red.</p>
Method TestThePersonsAssignUnassignAndPriorityReadBackAsSent()
{
    Do $$$AssertStatusOK(..Arrange(), "the probe role, two active members and an inactive one are stored")
    Set tId = $ClassMethod(..#FIXTURE, "ProbeTask", ..#ROLE, "", ..#USERA)
    Do $$$AssertTrue(tId > 0, "an unassigned task with one worklist item is stored")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tText = ..ScreenAssign(tId, {"User": (..#USERB), "Priority": "2"}, .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "an Assign to the second member with priority 2 answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.id _ "|" _ tAnswer.readBack.verdict, 1: ""), "updated|interop-workflow-task|" _ tId _ "|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "publishing the updated event, whose read-back matches")
    Do $$$AssertEquals(..Who(tId) _ "#" _ $ClassMethod(..#FIXTURE, "ItemUsers", ..#SOURCE, tId), ..#USERB _ "|2#" _ ..#USERB, "the task is the second member's at priority 2, and the first member's item is gone")
    Do $$$AssertEquals(..TaskRows(tSince, tId, .tData), 1, "OcuPilot records one ConfigChange")
    Do $$$AssertTrue((tData [ "USER") && (tData [ """assignedTo"":""" _ ..#USERB _ """") && (tData [ """priority"":2") && (tData [ """completed"":true") && (tData '[ $Parameter(..#FIXTURE, "TASKSUBJECT")), "naming the namespace, the assignee and the priority, and no subject: " _ tData)
    Set tText = ..ScreenAssign(tId, {"User": ""}, .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "an Assign to Unassigned answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals(..Who(tId) _ "#" _ $ClassMethod(..#FIXTURE, "ItemUsers", ..#SOURCE, tId), "|2#" _ ..#USERA _ "," _ ..#USERB, "the task is unassigned, keeps its priority, and sits on each active member's worklist and not the inactive one's")
    Do $$$AssertEquals(..TaskRows(tSince, tId, .tData, 2), 2, "the unassign records its own row")
    Do $$$AssertTrue((tData [ """assignedTo"":""""") && (tData [ """priority"":2"), "naming no assignee: " _ tData)
    Set tText = ..ScreenAssign(tId, {"Priority": "5"}, .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "a priority alone on the unassigned task answers 200")
    Do $$$AssertEquals(..Who(tId) _ "#" _ $ClassMethod(..#FIXTURE, "ItemUsers", ..#SOURCE, tId), "|5#" _ ..#USERA _ "," _ ..#USERB, "and changes the priority, keeping the task unassigned and on the same worklists")
    Do $$$AssertEquals(..ScreenAssign(tId, {"User": (..#USERA)}, .tAnswer), "200 ", "an Assign to the first member answers 200")
    Do $$$AssertEquals(..Who(tId) _ "#" _ $ClassMethod(..#FIXTURE, "ItemUsers", ..#SOURCE, tId), ..#USERA _ "|5#" _ ..#USERA, "the task is the first member's, with its priority kept, and the other item is gone")
    Do $$$AssertEquals(..ScreenAssign(tId, {"Priority": "1"}, .tAnswer), "200 ", "a priority alone on the assigned task answers 200")
    Do $$$AssertEquals(..Who(tId) _ "#" _ $ClassMethod(..#FIXTURE, "ItemUsers", ..#SOURCE, tId), ..#USERA _ "|1#" _ ..#USERA, "and keeps the assignment")
    Do $$$AssertEquals(..TaskRows(tSince, tId, .tData, 5, 1), 5, "each of the five writes recorded one row")
    Do $$$AssertEquals(##class(OcuPilot.Test.InteropScheduleControl).VendorRows(tSince, tId), 0, "and the vendor recorded none throughout")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "TaskText", ..#OTHER, tId), "<absent>", "HSCUSTOM was never written")
}

/// <p>AC2: the agent's assign, minted for the HTTP account and confirmed over HTTP, assigns the task, answers one envelope with a read-back that matches, is ledgered once and marked (AD-15), and records
/// one <code>ConfigChange</code> carrying no subject; its consequence says the task leaves every other worklist, and an unassign's says it goes to every active member; a task reassigned after the mint
/// closes the confirm target-changed and nothing is written.</p>
/// <p>Mutation (Rule 19): remove <code>Status</code> and <code>AssignedTo</code> from <parameter>OcuPilot.Screen.Tool.InteropWorkflowTaskAssign.FINGERPRINTSUBJECT</parameter> -- the moved leg goes red.</p>
Method TestTheAgentsAssignAndUnassignConfirmOverHttp()
{
    Do $$$AssertStatusOK(..Arrange(), "the probe role and users are stored")
    Set tId = $ClassMethod(..#FIXTURE, "ProbeTask", ..#ROLE, "", ..#USERA)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tCode = ..MintTask("Assign", tId, {"User": (..#USERB), "Priority": 3}, .tReason, .tProposal, .tTurn)
    Do $$$AssertEquals(tCode, "minted", "the assign mints: " _ tReason)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.target.type _ "|" _ tProposal.target.scope _ "|" _ tProposal.target.id, "interop-workflow-task|USER|" _ tId, "the target is the task, by its id")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "INTEROP.WORKFLOW.TASKASSIGN|0", "its consequence says the task leaves every other worklist, and it is not destructive")
    Do $$$AssertEquals(..Who(tId), "|0", "nothing is written by the mint")
    Set tStatus = ..Confirm(tProposal.proposalId, .tHttp, .tRaw, .tAnswer)
    Do $$$AssertEquals(tHttp, 200, "the assign confirms over HTTP: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.action _ "|" _ tAnswer.readBack.verdict, 1: ""), "1|updated|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "marked (AD-15), whose read-back matches")
    Do $$$AssertEquals(..LedgerCount(tTurn, "interop.workflowtasks.assign"), 1, "the confirmed write is in the ledger once")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertEquals(..Who(tId) _ "#" _ $ClassMethod(..#FIXTURE, "ItemUsers", ..#SOURCE, tId), ..#USERB _ "|3#" _ ..#USERB, "the task holds what the proposal reviewed, and only the assignee's item")
    Do $$$AssertEquals(##class(OcuPilot.Test.InteropScheduleControl).VendorRows(tSince, tId), 0, "the vendor records no row")
    Do $$$AssertEquals(..TaskRows(tSince, tId, .tData, 1, 1), 1, "OcuPilot records one ConfigChange")
    Do $$$AssertTrue((tData [ """assignedTo"":""" _ ..#USERB _ """") && (tData [ """priority"":3") && (tData '[ $Parameter(..#FIXTURE, "TASKSUBJECT")), "naming the assignee and the priority and no subject: " _ tData)
    Set tCode = ..MintTask("Assign", tId, {"User": ""}, .tReason, .tUnassign, .tUnassignTurn)
    Do $$$AssertEquals(tCode, "minted", "an unassign mints: " _ tReason)
    If '$IsObject($Get(tUnassign)) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tUnassign.proposalId, "Consequence"), "INTEROP.WORKFLOW.TASKUNASSIGN", "its consequence says the task goes to every active member of its role")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "ProbeUser", "OcuP2417wTd", "Dee", 1, ..#SOURCE, 0), "a user is stored")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "ProbeMember", ..#ROLE, "OcuP2417wTd"), "and made an active member of the role")
    Set tCode = ..MintTask("Assign", tId, {"User": (..#USERA)}, .tReason, .tMoved, .tMovedTurn)
    Do $$$AssertEquals(tCode, "minted", "a second assign mints: " _ tReason)
    If '$IsObject($Get(tMoved)) Quit
    Set tStatus = ..Confirm(tUnassign.proposalId, .tHttp, .tRaw, .tAnswer)
    Do $$$AssertEquals(tHttp, 200, "the unassign confirms: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals(..Who(tId) _ "#" _ $ClassMethod(..#FIXTURE, "ItemUsers", ..#SOURCE, tId), "|3#OcuP2417wTa,OcuP2417wTb,OcuP2417wTd", "the task is unassigned and on each active member's worklist, the new member's included")
    Set tStatus = ..Confirm(tMoved.proposalId, .tHttp, .tRaw, .tAnswer)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tHttp), "PROPOSAL.TARGETCHANGED", "an assign minted before the task was unassigned is closed target-changed: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals(..Who(tId), "|3", "and nothing was written by it")
    For tT = $Get(tTurn), $Get(tUnassignTurn), $Get(tMovedTurn) {
        If tT '= "" Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tT)
    }
}

/// <p>AC7: the script form of each write renders the switch to the namespace, each refusal as one guard and the vendor calls, with the task's id and the values as literals, runs nothing, and renders no draft
/// for an id or a value the port would refuse by shape. Run line by line, an assign's script assigns the task, an unassign's sends it to the active members, a script for an inactive user or for what the task
/// already holds stops at its guard, and a cancel's stops at its guard when no production runs.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.WorkflowTaskSnippet</method> drop the active-user guard -- the inactive-user run goes red.</p>
Method TestTheScriptFormsRenderTheGuardsAndRunNothingForABadValue()
{
    Do $$$AssertStatusOK(..Arrange(), "the probe role and users are stored")
    Set tId = $ClassMethod(..#FIXTURE, "ProbeTask", ..#ROLE, "", ..#USERA)
    Kill tQuery
    Set tQuery("namespace") = ..#SOURCE
    Set tQuery("id") = tId
    Set tQuery("taskuser") = ..#USERB
    Set tQuery("taskpriority") = 4
    Set tSteps = $ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "ASSIGNWORKFLOWTASK", .tQuery, {})
    Set tText = ..StepText(tSteps)
    Do $$$AssertEquals(tSteps.%Size(), 1, "the assign's script is one step")
    Do $$$AssertTrue((tText [ "Set $NAMESPACE = ""USER""") && (tText [ "EnsLib.Workflow.TaskResponse") && (tText [ tId) && (tText [ ..#USERB) && (tText [ "AssignTask") && (tText [ "%Priority = 4"), "it switches the namespace, names the task and the user and calls the vendor: " _ tText)
    Kill tQuery
    Set tQuery("namespace") = ..#SOURCE
    Set tQuery("id") = tId
    Set tQuery("taskuser") = ""
    Set tText = ..StepText($ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "ASSIGNWORKFLOWTASK", .tQuery, {}))
    Do $$$AssertTrue((tText [ "UnassignTask") && (tText [ "SendTaskToAll"), "the unassign's script calls the vendor's two calls")
    Kill tQuery
    Set tQuery("namespace") = ..#SOURCE
    Set tQuery("id") = tId
    Set tText = ..StepText($ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "CANCELWORKFLOWTASK", .tQuery, {}))
    Do $$$AssertTrue((tText [ "CompleteTask") && (tText [ "GetProductionStatus") && (tText [ "ReturnQueueName"), "the cancel's script guards the running production and the waiting sender: " _ tText)
    Do $$$AssertEquals(..Facts(tId), ..#ROLE _ "||0||0#" _ ..#USERA, "rendering ran nothing and stored nothing: " _ ..Facts(tId))
    For tBad = $ListBuild("ASSIGNWORKFLOWTASK", "0", "", ""), $ListBuild("ASSIGNWORKFLOWTASK", "abc", "", ""), $ListBuild("ASSIGNWORKFLOWTASK", tId, "a" _ $Char(9) _ "b", ""), $ListBuild("ASSIGNWORKFLOWTASK", tId, $Translate($Justify("", 129), " ", "x"), ""), $ListBuild("ASSIGNWORKFLOWTASK", tId, "", "0"), $ListBuild("ASSIGNWORKFLOWTASK", tId, "", "6"), $ListBuild("ASSIGNWORKFLOWTASK", tId, "", "x"), $ListBuild("CANCELWORKFLOWTASK", "01", "", "") {
        Kill tQuery
        Set tQuery("namespace") = ..#SOURCE
        Set tQuery("id") = $List(tBad, 2)
        If $List(tBad, 1) = "ASSIGNWORKFLOWTASK" {
            If ($List(tBad, 3) '= "") || ($List(tBad, 4) = "") Set tQuery("taskuser") = $List(tBad, 3)
            If $List(tBad, 4) '= "" Set tQuery("taskpriority") = $List(tBad, 4)
        }
        Set tSteps = $ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, $List(tBad, 1), .tQuery, {})
        Do $$$AssertEquals(tSteps.%Size(), 0, $List(tBad, 1) _ " of '" _ $Extract($List(tBad, 2), 1, 12) _ "' with user '" _ $Extract($List(tBad, 3), 1, 6) _ "' and priority '" _ $List(tBad, 4) _ "' renders no draft")
    }
    Kill tQuery
    Set tQuery("namespace") = ..#SOURCE
    Set tQuery("id") = tId
    Set tQuery("taskuser") = ..#USERB
    Set tQuery("taskpriority") = 4
    Do $$$AssertEquals(..RunScript($ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "ASSIGNWORKFLOWTASK", .tQuery, {})), 1, "an assign's script runs")
    Do $$$AssertEquals(..Facts(tId), ..#ROLE _ "|" _ ..#USERB _ "|4|Assigned|0#" _ ..#USERB, "and assigns the task as the vendor does, at the priority the script set")
    Do $$$AssertEquals(..RunScript($ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "ASSIGNWORKFLOWTASK", .tQuery, {})), 0, "the same script again stops at its unchanged guard")
    Set tQuery("taskuser") = ..#USERC
    Kill tQuery("taskpriority")
    Do $$$AssertEquals(..RunScript($ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "ASSIGNWORKFLOWTASK", .tQuery, {})), 0, "a script for the inactive user stops at its user guard")
    Set tQuery("taskuser") = ""
    Do $$$AssertEquals(..RunScript($ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "ASSIGNWORKFLOWTASK", .tQuery, {})), 1, "an unassign's script runs")
    Do $$$AssertEquals($Piece(..Facts(tId), "|", 2) _ "#" _ $Piece(..Facts(tId), "#", 2), "#" _ ..#USERA _ "," _ ..#USERB, "and sends the task to each active member")
    Do $$$AssertEquals(..RunScript($ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "CANCELWORKFLOWTASK", .tQuery, {})), 0, "a cancel's script stops at its guard while no production runs")
    Do $$$AssertEquals($Piece(..Facts(tId), "|", 4, 5), "Unassigned|0#" _ ..#USERA _ "," _ ..#USERB, "and cancels nothing: " _ ..Facts(tId))
    Kill tQuery
    Set tQuery("namespace") = ..#SOURCE
    Set tQuery("id") = 999999999
    Set tQuery("taskpriority") = 2
    Set tStopped = ..ScriptStop($ClassMethod(..#PORT, "Snippet", ..#ENDPOINT, "ASSIGNWORKFLOWTASK", .tQuery, {}))
    Do $$$AssertTrue(tStopped [ ##class(OcuPilot.Api.Error).#PORTNOTFOUND, "a priority-only script for a task held by none stops at its not-found guard, raising nothing: " _ tStopped)
}

/// <p>What the script <var>pSteps</var> stops with when run line by line in <code>USER</code>: its status's text, <code>threw</code> when a line raised, or <code>""</code> when it ran.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.WorkflowTaskSnippet</method> read the assignee of a task it did not open -- the not-found leg reads <code>threw</code>.</p>
ClassMethod ScriptStop(pSteps As %DynamicArray) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tStop = ""
    XECUTE "Kill tSC"
    Try {
        Set tText = pSteps.%Get(0).text
        For tAt = 1:1:$Length(tText, $Char(10)) {
            Set tLine = $Piece(tText, $Char(10), tAt)
            If tLine '= "" XECUTE tLine
        }
        If '$System.Status.IsOK($Get(@"tSC")) Set tStop = $System.Status.GetErrorText(@"tSC")
    } Catch {
        Set tStop = "threw"
    }
    Set $NAMESPACE = tOrigNS
    Quit tStop
}

}
