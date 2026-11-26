/// <p>Pins Story 24.17 Batch 4's cancel end to end against live probe tasks in <code>USER</code> (AD-6, AD-14, AD-15, AD-51, AD-53, AD-58, AD-62): a person's Cancel task on the Workflow tasks screen and
/// the agent's cancel tool, minted and confirmed over HTTP, complete a task the probe production's business process sent to a workflow role, leave it <code>Cancelled</code> and complete with no worklist item,
/// and deliver its response to the process that waits for it; and a cancel whose response cannot be delivered (no production running, a token naming another production, a request header with no return
/// queue or gone) is refused by name before any vendor call, leaving the task and its worklist as they were.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropWorkflowCase</class> needs, the HTTP test account and an interoperability-enabled <code>USER</code> namespace. It starts the
/// probe production in <code>USER</code> and stops and removes it, and every probe it creates, before it ends.</p>
Class OcuPilot.Test.InteropWorkflowTaskCancel Extends OcuPilot.Test.InteropWorkflowTaskCase
{

/// <p>The task <var>pId</var> as <code>status|complete#users</code>.</p>
ClassMethod State(pId As %String) As %String
{
    Quit $Piece($ClassMethod(..#FIXTURE, "TaskText", ..#SOURCE, pId), "|", 4, 5) _ "#" _ $ClassMethod(..#FIXTURE, "ItemUsers", ..#SOURCE, pId)
}

/// <p>The probe role, its members and the running probe production, with one live task, whose id is answered; 0 when any did not come.</p>
Method Live() As %Integer
{
    Do $$$AssertStatusOK(..Arrange(), "the probe role and users are stored")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "LiveStart", ..#ROLE), "the probe production runs with the workflow operation of the role and the business process")
    Set tId = $ClassMethod(..#FIXTURE, "LiveTask")
    Do $$$AssertTrue(tId > 0, "a live task is stored")
    Quit tId
}

/// <p>AC3: a person's Cancel task completes a live task: it answers 200 with the change event's triple and a read-back that sent nothing, leaves the task <code>Cancelled</code> and complete with no worklist
/// item, delivers the response to the process that sent it, and records one <code>ConfigChange</code> naming the namespace and the task and that it completed, with no subject.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.WorkflowTaskVendor</method> pass an action to <code>CompleteTask</code> -- the status leg goes red.</p>
Method TestThePersonsCancelCompletesALiveTaskAndDeliversItsResponse()
{
    Set tId = ..Live()
    If 'tId Quit
    Do $$$AssertEquals(..State(tId), "Unassigned|0#" _ ..#USERA _ "," _ ..#USERB, "the live task is unassigned and sits on the two active members' worklists")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tText = ..Act("cancel", tId, "", .tAnswer)
    Do $$$AssertEquals(tText, "200 ", "the Cancel answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.id _ "|" _ tAnswer.readBack.verdict, 1: ""), "updated|interop-workflow-task|" _ tId _ "|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#NOTHINGSENT, "publishing the event, whose read-back sent nothing: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: tAnswer))
    Do $$$AssertEquals(..State(tId), "Cancelled|1#-", "the task reads Cancelled and complete, and no worklist item names it")
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "AwaitReceived", 1), "the business process was given a response")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Received"), $Parameter(..#FIXTURE, "PROCNAME") _ "|" _ tId _ "|Cancelled|Cancelled", "which is the task, Cancelled, with the action Cancelled")
    Do $$$AssertEquals(..TaskRows(tSince, tId, .tData, 1, 1), 1, "OcuPilot records one ConfigChange")
    Do $$$AssertTrue((tData [ "USER") && (tData [ """completed"":true") && (tData '[ "assignedTo") && (tData '[ $Parameter(..#FIXTURE, "TASKSUBJECT")), "naming the namespace and that it completed, and no assignee or subject: " _ tData)
    Do $$$AssertEquals(##class(OcuPilot.Test.InteropScheduleControl).VendorRows(tSince, tId), 0, "and the vendor recorded none")
    Do $$$AssertEquals(..Act("cancel", tId, "", .tAgain), "409 INTEROP.WORKFLOW.TASKCOMPLETE", "a second Cancel is refused as complete")
    Do $$$AssertEquals(..TaskRows(tSince, tId, .tData, 2, 1), 1, "and records no row")
}

/// <p>AC3: the agent's cancel is destructive and ships off: it is refused while the tool's key is off, closes target-changed when the task was assigned, or given to another user, after the mint, is
/// closed target-changed by the confirm's read when its sender stopped waiting after the mint (a precondition refusal, AD-51), and, once the key is on, completes the task, delivers its response, answers a
/// read-back that sent nothing, is ledgered once and marked (AD-15) and records one <code>ConfigChange</code>; its consequence says it cannot be undone.</p>
/// <p>Mutation (Rule 19): turn the cancel tool's baseline key on -- the refusal leg goes red; remove <code>AssignedTo</code> from
/// <parameter>OcuPilot.Screen.Tool.InteropWorkflowTaskAction.FINGERPRINTSUBJECT</parameter> -- the change-of-assignee leg goes red.</p>
Method TestTheAgentsCancelIsRefusedWhileOffAndConfirmsOnceOn()
{
    Set tId = ..Live()
    If 'tId Quit
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tPolicy)
    Do $$$AssertStatusOK(tSC, "the governance policy is read")
    Try {
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the stored policy is cleared")
        Set tCode = ..MintTask("Cancel", tId, {}, .tReason, .tProposal, .tTurn)
        Do $$$AssertEquals(tCode, "minted", "the cancel mints: " _ tReason)
        If '$IsObject($Get(tProposal)) Quit
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Consequence") _ "|" _ (##class(OcuPilot.Test.ProposalFixture).Field(tProposal.proposalId, "Destructive") + 0), "INTEROP.WORKFLOW.TASKCANCEL|1", "its consequence says it cannot be undone, and it is destructive")
        Set tStatus = ..Confirm(tProposal.proposalId, .tHttp, .tRaw, .tAnswer)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tHttp), ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "the confirm is refused while the tool's key is off: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals(..State(tId), "Unassigned|0#" _ ..#USERA _ "," _ ..#USERB, "and the task is still open")
        Kill tSettings
        Set tSettings("interop.workflowtasks.cancel") = "enabled"
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the key is turned on")
        Do $$$AssertEquals(..Assign(tId, ..#USERA, "", .tResult, .tFault), "200 ", "the task is assigned after the mint")
        Set tStatus = ..Confirm(tProposal.proposalId, .tHttp, .tRaw, .tAnswer)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tHttp), "PROPOSAL.TARGETCHANGED", "the proposal is closed target-changed: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals(..State(tId), "Assigned|0#" _ ..#USERA, "and the task is as the assign left it")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
        Set tCode = ..MintTask("Cancel", tId, {}, .tReason, .tMoved, .tMovedTurn)
        Do $$$AssertEquals(tCode, "minted", "a cancel of the assigned task mints: " _ tReason)
        If '$IsObject($Get(tMoved)) Quit
        Do $$$AssertEquals(..Assign(tId, ..#USERB, "", .tResult, .tFault), "200 ", "the task is given to another user after the mint, its status still Assigned")
        Set tStatus = ..Confirm(tMoved.proposalId, .tHttp, .tRaw, .tAnswer)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tHttp), "PROPOSAL.TARGETCHANGED", "a change of assignee alone closes the proposal target-changed: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals(..State(tId), "Assigned|0#" _ ..#USERB, "and the task is as the reassign left it")
        Set tToken = $ClassMethod(..#FIXTURE, "TokenOf", tId)
        Set tCode = ..MintTask("Cancel", tId, {}, .tReason, .tSender, .tSenderTurn)
        Do $$$AssertEquals(tCode, "minted", "a cancel mints while its sender waits: " _ tReason)
        If '$IsObject($Get(tSender)) Quit
        Do $$$AssertTrue($ClassMethod(..#FIXTURE, "SetToken", tId, $Piece(tToken, "|", 1) _ "|OtherProduction"), "the token is then made to name another production")
        Set tStatus = ..Confirm(tSender.proposalId, .tHttp, .tRaw, .tAnswer)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: tHttp), "PROPOSAL.TARGETCHANGED", "the confirm's read, refused as the sender is not waiting, closes the proposal target-changed, the token being no part of the fingerprint: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertTrue($ClassMethod(..#FIXTURE, "SetToken", tId, tToken), "the token is put back")
        Do $$$AssertEquals(..State(tId), "Assigned|0#" _ ..#USERB, "and the task and its worklist are as they were")
        Set tCode = ..MintTask("Cancel", tId, {}, .tReason, .tFresh, .tFreshTurn)
        Do $$$AssertEquals(tCode, "minted", "a fresh cancel mints: " _ tReason)
        If '$IsObject($Get(tFresh)) Quit
        Set tStatus = ..Confirm(tFresh.proposalId, .tHttp, .tRaw, .tAnswer)
        Do $$$AssertEquals(tHttp, 200, "and confirms: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("auditMarked") _ "|" _ tAnswer.readBack.verdict, 1: ""), "1|" _ ##class(OcuPilot.Kernel.Proposal.ReadBack).#NOTHINGSENT, "marked (AD-15), whose read-back sent nothing")
        Do $$$AssertEquals(..LedgerCount(tFreshTurn, "interop.workflowtasks.cancel"), 1, "ledgered once")
        Do $$$AssertEquals(..State(tId), "Cancelled|1#-", "the task reads Cancelled and complete, with no worklist item")
        Do $$$AssertTrue($ClassMethod(..#FIXTURE, "AwaitReceived", 1), "the business process was given a response")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Received"), $Parameter(..#FIXTURE, "PROCNAME") _ "|" _ tId _ "|Cancelled|Cancelled", "which is the task, Cancelled")
        Do $$$AssertEquals(..TaskRows(tSince, tId, .tData, 3, 1), 3, "the two assigns and the cancel each recorded one ConfigChange, and the refused confirms none")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the agent leg raised")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
    For tT = $Get(tTurn), $Get(tFreshTurn), $Get(tMovedTurn), $Get(tSenderTurn) {
        If tT '= "" Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tT)
    }
}

/// <p>AC4: a cancel is refused by name, before any vendor call, when its response cannot be delivered: <code>INTEROP.PRODUCTION.NOTRUNNING</code> while the namespace runs no production, whether the
/// task has a sender or not, and <code>INTEROP.WORKFLOW.TASKSENDER</code> when the production runs and the task has no sender, its token names another production, its request header has no return queue
/// or the header is gone. The person's Cancel task and the agent's mint are refused by the same codes. Each leaves the task open and its worklist as it was and records no row.</p>
/// <p>Mutation (Rule 19): remove the sender test from <method>OcuPilot.Port.InteropPort.WorkflowTaskWriteToken</method> -- the sender legs go red and the worklist is lost.</p>
Method TestACancelWhoseResponseCannotBeDeliveredIsRefusedByName()
{
    Do $$$AssertStatusOK(..Arrange(), "the probe role and users are stored")
    Set tFx = ..#FIXTURE
    Set tOffline = $ClassMethod(tFx, "ProbeTask", ..#ROLE, "", ..#USERA)
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertEquals(..Cancel(tOffline, .tResult, .tFault), "409 INTEROP.PRODUCTION.NOTRUNNING", "a task with no sender, while no production runs, is refused: no production")
    Do $$$AssertEquals(..Act("cancel", tOffline, "", .tAnswer), "409 INTEROP.PRODUCTION.NOTRUNNING", "and so is the person's Cancel task")
    Do $$$AssertEquals(..MintTask("Cancel", tOffline, {}, .tReason, .tProposal, .tTurn), "INTEROP.PRODUCTION.NOTRUNNING", "and the agent's cancel, at its mint: " _ tReason)
    Do $$$AssertStatusOK($ClassMethod(tFx, "LiveStart", ..#ROLE), "the probe production runs")
    Do $$$AssertEquals(..Cancel(tOffline, .tResult, .tFault), "409 INTEROP.WORKFLOW.TASKSENDER", "the same task, while one runs, is refused: no sender")
    Do $$$AssertEquals(..Act("cancel", tOffline, "", .tAnswer), "409 INTEROP.WORKFLOW.TASKSENDER", "and so is the person's Cancel task")
    Do $$$AssertEquals(..MintTask("Cancel", tOffline, {}, .tReason, .tProposal, .tTurn), "INTEROP.WORKFLOW.TASKSENDER", "and the agent's cancel, at its mint: " _ tReason)
    Set tLive = $ClassMethod(tFx, "LiveTask")
    Do $$$AssertTrue(tLive > 0, "a live task is stored")
    If 'tLive Quit
    Set tOpen = "Unassigned|0#" _ ..#USERA _ "," _ ..#USERB
    Set tToken = $ClassMethod(tFx, "TokenOf", tLive)
    Set tHeader = $Piece(tToken, "|", 1)
    Set tQueue = $ClassMethod(tFx, "ReturnQueue", tHeader)
    Do $$$AssertTrue((tHeader > 0) && ($Piece(tToken, "|", 2) '= "") && (tQueue '= "") && (tQueue '= "<absent>"), "its token names the request header and the running production, and the header has a return queue: " _ tToken _ " " _ tQueue)
    Do $$$AssertTrue($ClassMethod(tFx, "SetToken", tLive, tHeader _ "|OtherProduction"), "the token is made to name another production")
    Do $$$AssertEquals(..Cancel(tLive, .tResult, .tFault) _ "|" _ ..State(tLive), "409 INTEROP.WORKFLOW.TASKSENDER|" _ tOpen, "a token naming another production is refused and the worklist is kept")
    Do $$$AssertEquals(..Act("cancel", tLive, "", .tAnswer) _ "|" _ ..State(tLive), "409 INTEROP.WORKFLOW.TASKSENDER|" _ tOpen, "and so is the person's Cancel task")
    Do $$$AssertTrue($ClassMethod(tFx, "SetToken", tLive, tToken), "the token is put back")
    Do $$$AssertTrue($ClassMethod(tFx, "SetHeader", tHeader, ""), "the header's return queue is cleared")
    Do $$$AssertEquals(..Cancel(tLive, .tResult, .tFault) _ "|" _ ..State(tLive), "409 INTEROP.WORKFLOW.TASKSENDER|" _ tOpen, "a header with no return queue is refused and the worklist is kept")
    Do $$$AssertTrue($ClassMethod(tFx, "SetHeader", tHeader, tQueue), "the return queue is put back")
    Do $$$AssertStatusOK($ClassMethod(tFx, "LiveStop"), "the production is stopped")
    Do $$$AssertEquals(..Cancel(tLive, .tResult, .tFault) _ "|" _ ..State(tLive), "409 INTEROP.PRODUCTION.NOTRUNNING|" _ tOpen, "a live task, with the production stopped, is refused and the worklist is kept")
    Do $$$AssertStatusOK($ClassMethod(tFx, "LiveRestart"), "the production is started again")
    Do $$$AssertTrue($ClassMethod(tFx, "SetHeader", tHeader, "", 1), "the request header is deleted")
    Do $$$AssertEquals(..Cancel(tLive, .tResult, .tFault) _ "|" _ ..State(tLive), "409 INTEROP.WORKFLOW.TASKSENDER|" _ tOpen, "a task whose request header is gone is refused and the worklist is kept")
    Do $$$AssertEquals(..TaskRows(tSince, tLive, .tData, 1, 1), 0, "no refusal recorded a row")
    Do $$$AssertEquals($ClassMethod(tFx, "Received"), "-", "and the process was given nothing")
    Do $$$AssertStatusOK($ClassMethod(tFx, "CompleteProbe", tOffline), "a task is completed")
    Do $$$AssertEquals(..Cancel(tOffline, .tResult, .tFault), "409 INTEROP.WORKFLOW.TASKCOMPLETE", "and a cancel of a completed task is refused before the production is asked")
    Do $$$AssertEquals(..Cancel(999999999, .tResult, .tFault), "404 PORT.NOTFOUND", "and so is a cancel of a task that is held by none")
}

}
