/// <p>The guided-workflow turn over a real turn job and HTTP (Story 20.12, AD-5, AD-6, AD-66): two
/// <code>compileclass</code> turns of one conversation, each minting one proposal that the principal confirms over
/// HTTP, the second turn's first request reading the first proposal as <code>confirmed</code> in
/// <code>previous</code>; a turn that calls a tool no step names, then a step's write, then a second one, meeting
/// <code>WORKFLOW.NOTASTEP</code>, a minted proposal and <code>WORKFLOW.ONECHANGE</code> with exactly one proposal
/// held; a write call that mints nothing leaving the turn's one change unused; <code>previous</code> reading the turn
/// before's proposal whether it was canceled, confirmed or closed by a typed message; and a start naming an unknown
/// workflow answering 422 <code>WORKFLOW.UNKNOWN</code> on its field and reserving nothing, while a JSON
/// <code>null</code> workflow starts an ordinary turn.</p>
/// <p>The harness is <class>OcuPilot.Test.WorkflowTurnCase</class>'s. <b>It needs</b> OcuPilot installed and
/// serving over HTTP on a throwaway, a <code>USER</code> namespace, and both <parameter>ARMINGVARIABLE</parameter>
/// and <parameter>PROVIDERVARIABLE</parameter> reading <code>1</code>.</p>
Class OcuPilot.Test.WorkflowTurn Extends OcuPilot.Test.WorkflowTurnCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter TAG = "workflowturn-probe";

/// <p>AC1's server half: a <code>compileclass</code> turn mints one save, confirmed over HTTP; a second turn of the
/// same conversation, the Continue sentence with the same workflow, opens with a <code>previous</code> that reads
/// the first save <code>confirmed</code> with its read-back verdict, and mints a second save of its own, confirmed
/// on its own.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Agent.Loop.WorkflowResult</method> reads the current turn's
/// proposals instead of the turn before's -> the second-turn leg goes red.</p>
Method TestTwoWorkflowTurnsAreTwoConfirmations()
{
    Do $$$AssertStatusOK(..MakeProbe(), "the probe class is saved")
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply([(..SaveCall("toolu_one", "    Quit 1", "    Quit 2"))]))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("WORKFLOWTURNONE"))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply([(..SaveCall("toolu_two", "    Quit 2", "    Quit 3"))]))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("WORKFLOWTURNTWO"))
    Set tConvId = ..NewConversation()
    Set tFirst = ..RunTurn(tConvId, "Fix a class until it compiles, step by step", "compileclass", .tView)
    Do $$$AssertEquals(tFirst, "completed", "the first turn completes")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAG), 2, "after two provider calls")

    Do ..ResultsOf(1, .tResults, .tWrapped)
    Set tWorkflow = ..Parsed($Get(tResults("ocupilot_workflow")))
    Do $$$AssertTrue($Get(tWrapped("ocupilot_workflow")) && $IsObject(tWorkflow), "the first request holds the workflow result, framed as data")
    If $IsObject(tWorkflow) {
        Do $$$AssertEquals(tWorkflow.%Get("workflow"), "compileclass", "for compileclass")
        Do $$$AssertTrue(tWorkflow.%ToJSON() [ "explorer.classes.save", "whose steps name explorer.classes.save")
        Do $$$AssertEquals(tWorkflow.previous.%Size(), 0, "with no earlier proposal to report")
    }
    Set tMessages = ..Parsed(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 1, "messages"))
    Do $$$AssertEquals(tMessages.%Size(), 3, "and no screen context, so three opening messages")
    Do $$$AssertTrue(tMessages.%Get(0).%ToJSON() [ ##class(OcuPilot.Kernel.Agent.Prompt).WorkflowPreamble(), "under the workflow preamble")

    Set tKey = ..FirstProposal(tView)
    Do $$$AssertNotEquals(tKey, "", "the turn holds a proposal")
    Do $$$AssertEquals(tView.proposals.%Size(), 1, "and only one")
    If tKey = "" Quit
    Do ..Confirm(tKey, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the confirm answers 200")
    Do $$$AssertEquals(..Answer(), "    Quit 2", "and the class holds the first save")

    Set tSecond = ..RunTurn(tConvId, "Continue the guided workflow.", "compileclass", .tView2)
    Do $$$AssertEquals(tSecond, "completed", "the second turn completes")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAG), 4, "after two more provider calls")
    Do ..ResultsOf(3, .tResults2, .tWrapped2)
    Set tWorkflow2 = ..Parsed($Get(tResults2("ocupilot_workflow")))
    Do $$$AssertTrue($IsObject(tWorkflow2) && (tWorkflow2.%GetTypeOf("previous") = "array"), "the second turn's first request holds the workflow result with a previous")
    If $IsObject(tWorkflow2) && (tWorkflow2.%GetTypeOf("previous") = "array") {
        Do $$$AssertEquals(tWorkflow2.previous.%Size(), 1, "reporting the turn before's one proposal")
        Set tPrevious = tWorkflow2.previous.%Get(0)
        Do $$$AssertEquals(($IsObject(tPrevious) && (tPrevious.%Get("tool") = "explorer.classes.save") && (tPrevious.%Get("state") = "confirmed")), 1, "which is the save, confirmed: " _ tWorkflow2.previous.%ToJSON())
        Do $$$AssertEquals(($IsObject(tPrevious) && (tPrevious.%GetTypeOf("readBack") = "string") && (tPrevious.%Get("readBack") '= "")), 1, "with the read-back's verdict: " _ tWorkflow2.previous.%ToJSON())
        Do $$$AssertEquals(($IsObject(tPrevious) && (tPrevious.%Get("closedReason") = "")), 1, "and no closing reason")
        Do $$$AssertEquals(tWorkflow2.previous.%ToJSON() [ "OcuProbe2012", 0, "it names no target")
    }
    Set tKey2 = ..FirstProposal(tView2)
    Do $$$AssertTrue((tKey2 '= "") && (tKey2 '= tKey), "the second turn mints a proposal of its own")
    If tKey2 = "" Quit
    Do ..Confirm(tKey2, .tStatus2, .tBody2)
    Do $$$AssertEquals(tStatus2, 200, "confirmed on its own, it answers 200")
    Do $$$AssertEquals(..Answer(), "    Quit 3", "and the class holds the second save")
}

/// <p>AC2: a <code>compileclass</code> turn whose one reply calls <code>permissions.users.delete</code>, then
/// <code>explorer.classes.save</code>, then <code>explorer.classes.save</code> again is answered
/// <code>WORKFLOW.NOTASTEP</code>, a minted proposal and <code>WORKFLOW.ONECHANGE</code>; the turn holds exactly
/// one proposal and the class is unchanged until it is confirmed.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Agent.Workflow.WriteRefusal</method> tests
/// <code>pMinted > 1</code> -> the third result goes red; the dispatcher's workflow step is removed -> the first
/// does.</p>
Method TestOnlyTheStepsWritesAndOneChangePerTurn()
{
    Do $$$AssertStatusOK(..MakeProbe(), "the probe class is saved")
    Set tDelete = {"id": "toolu_delete", "input": {"Name": "OcuPilotProbeNobody", "rationale": "remove an account", "expectedImpact": "it is gone"}}
    Do tDelete.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName("permissions.users.delete"), "string")
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply([(tDelete), (..SaveCall("toolu_save", "    Quit 1", "    Quit 2")), (..SaveCall("toolu_again", "    Quit 1", "    Quit 4"))]))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("WORKFLOWRULES"))
    Set tConvId = ..NewConversation()
    Set tState = ..RunTurn(tConvId, "Fix a class until it compiles, step by step", "compileclass", .tView)
    Do $$$AssertEquals(tState, "completed", "the turn completes")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAG), 2, "after two provider calls")
    Do ..ResultsOf(2, .tResults, .tWrapped)
    Set tRefused = ..Parsed($Get(tResults("toolu_delete")))
    Do $$$AssertEquals(($IsObject(tRefused) && (tRefused.%Get("code") = "WORKFLOW.NOTASTEP")), 1, "a write no step names is WORKFLOW.NOTASTEP: " _ $Extract($Get(tResults("toolu_delete")), 1, 200))
    Set tMinted = ..Parsed($Get(tResults("toolu_save")))
    Do $$$AssertEquals(($IsObject(tMinted) && (tMinted.%GetTypeOf("changed") = "array") && (tMinted.changed.%Size() = 1)), 1, "a step's write mints its proposal: " _ $Extract($Get(tResults("toolu_save")), 1, 200))
    Set tSecond = ..Parsed($Get(tResults("toolu_again")))
    Do $$$AssertEquals(($IsObject(tSecond) && (tSecond.%Get("code") = "WORKFLOW.ONECHANGE")), 1, "a second write is WORKFLOW.ONECHANGE: " _ $Extract($Get(tResults("toolu_again")), 1, 200))
    Do $$$AssertEquals(($IsObject(tView.%Get("proposals")) && (tView.proposals.%Size() = 1)), 1, "the turn holds exactly one proposal")
    Do $$$AssertEquals(..Answer(), "    Quit 1", "and the class is unchanged until it is confirmed")
}

/// <p>AC1's matrix row (Continue), over four turns of one conversation: each turn's first request reads the
/// proposals of the turn before it and no other turn's. The first save is canceled, so the second turn reads
/// <code>canceled</code> with the reason <code>you</code> and no read-back; the second save is confirmed, so the
/// third turn reads exactly that one row, <code>confirmed</code> with its read-back verdict, and not the canceled
/// one; the third save is left live and a typed message follows it, so the fourth turn reads it closed by that
/// message.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Agent.Loop.WorkflowResult</method> reads the conversation's oldest
/// turn instead of its newest -> the third and fourth legs go red.</p>
Method TestPreviousReadsTheTurnBeforeWhateverItsOutcome()
{
    Do $$$AssertStatusOK(..MakeProbe(), "the probe class is saved")
    Set tProvider = "OcuPilot.Test.TurnProvider"
    Do $ClassMethod(tProvider, "Script", ..#TAG, 0, $ClassMethod(tProvider, "ToolUseReply", [(..SaveCall("toolu_one", "    Quit 1", "    Quit 2"))]))
    Do $ClassMethod(tProvider, "Script", ..#TAG, 0, $ClassMethod(tProvider, "TextReply", "PREVIOUSONE"))
    Do $ClassMethod(tProvider, "Script", ..#TAG, 0, $ClassMethod(tProvider, "ToolUseReply", [(..SaveCall("toolu_two", "    Quit 1", "    Quit 2"))]))
    Do $ClassMethod(tProvider, "Script", ..#TAG, 0, $ClassMethod(tProvider, "TextReply", "PREVIOUSTWO"))
    Do $ClassMethod(tProvider, "Script", ..#TAG, 0, $ClassMethod(tProvider, "ToolUseReply", [(..SaveCall("toolu_three", "    Quit 2", "    Quit 3"))]))
    Do $ClassMethod(tProvider, "Script", ..#TAG, 0, $ClassMethod(tProvider, "TextReply", "PREVIOUSTHREE"))
    Do $ClassMethod(tProvider, "Script", ..#TAG, 0, $ClassMethod(tProvider, "TextReply", "PREVIOUSFOUR"))
    Set tConvId = ..NewConversation()

    Set tState = ..RunTurn(tConvId, "Fix a class until it compiles, step by step", "compileclass", .tView)
    Do $$$AssertEquals(tState, "completed", "the first turn completes")
    Do $$$AssertEquals(..PreviousAt(1), "[]", "and reads no earlier proposal")
    Set tKey = ..FirstProposal(tView)
    Do $$$AssertNotEquals(tKey, "", "it mints a proposal")
    If tKey = "" Quit
    Do ..Cancel(tKey, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "which the person cancels: " _ $Select($IsObject(tBody): tBody.%ToJSON(), 1: ""))

    Set tState = ..RunTurn(tConvId, "Continue the guided workflow.", "compileclass", .tView)
    Do $$$AssertEquals(tState, "completed", "the second turn completes")
    Do $$$AssertEquals(..PreviousAt(3), "[{""tool"":""explorer.classes.save"",""state"":""canceled"",""closedReason"":""you"",""readBack"":null}]", "and reads the canceled save, closed by the person, with no read-back")
    Set tKey = ..FirstProposal(tView)
    Do $$$AssertNotEquals(tKey, "", "it mints a proposal of its own")
    If tKey = "" Quit
    Do ..Confirm(tKey, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "which the person confirms")
    Do $$$AssertEquals(..Answer(), "    Quit 2", "and the class holds that save")

    Set tState = ..RunTurn(tConvId, "Continue the guided workflow.", "compileclass", .tView)
    Do $$$AssertEquals(tState, "completed", "the third turn completes")
    Set tThird = ..Parsed(..PreviousAt(5))
    Do $$$AssertEquals($IsObject(tThird) && (tThird.%Size() = 1), 1, "it reads one row, the turn before's: " _ ..PreviousAt(5))
    If $IsObject(tThird) && (tThird.%Size() = 1) {
        Set tRow = tThird.%Get(0)
        Do $$$AssertEquals(tRow.%Get("tool") _ "|" _ tRow.%Get("state") _ "|" _ tRow.%Get("closedReason"), "explorer.classes.save|confirmed|", "the confirmed save, not the canceled one before it")
        Do $$$AssertEquals((tRow.%GetTypeOf("readBack") = "string") && (tRow.%Get("readBack") '= ""), 1, "with its read-back verdict")
    }
    Do $$$AssertNotEquals(..FirstProposal(tView), "", "it mints a proposal that nobody decides")

    Set tState = ..RunTurn(tConvId, "and then?", "compileclass", .tView)
    Do $$$AssertEquals(tState, "completed", "a typed message follows, and its turn completes")
    Do $$$AssertEquals(..PreviousAt(7), "[{""tool"":""explorer.classes.save"",""state"":""canceled"",""closedReason"":""message"",""readBack"":null}]", "it reads the undecided save as closed by the message")
}

/// <p>AC2's edge: a write call that mints nothing does not use up the turn's one change. A reply that calls the
/// class save with an <code>Old</code> the class does not hold, then with a valid edit, then with a second valid edit
/// is answered <code>TOOL.ARGUMENTS</code>, a minted proposal and <code>WORKFLOW.ONECHANGE</code>.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Agent.Dispatch.AnswerOne</method> counts the turn's write calls instead
/// of its proposals -> the second leg goes red.</p>
Method TestARefusedWriteDoesNotUseUpTheTurnsOneChange()
{
    Do $$$AssertStatusOK(..MakeProbe(), "the probe class is saved")
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply([(..SaveCall("toolu_bad", "    Quit 99", "    Quit 2")), (..SaveCall("toolu_good", "    Quit 1", "    Quit 2")), (..SaveCall("toolu_again", "    Quit 1", "    Quit 3"))]))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("WORKFLOWREFUSEDWRITE"))
    Set tState = ..RunTurn(..NewConversation(), "Fix a class until it compiles, step by step", "compileclass", .tView)
    Do $$$AssertEquals(tState, "completed", "the turn completes")
    Do ..ResultsOf(2, .tResults, .tWrapped)
    Set tBad = ..Parsed($Get(tResults("toolu_bad")))
    Do $$$AssertEquals(($IsObject(tBad) && (tBad.%Get("code") = "TOOL.ARGUMENTS")), 1, "a save of text the class does not hold is TOOL.ARGUMENTS: " _ $Extract($Get(tResults("toolu_bad")), 1, 200))
    Set tGood = ..Parsed($Get(tResults("toolu_good")))
    Do $$$AssertEquals(($IsObject(tGood) && (tGood.%GetTypeOf("changed") = "array") && (tGood.changed.%Size() = 1)), 1, "the refused call did not use up the turn's change, so the valid edit mints: " _ $Extract($Get(tResults("toolu_good")), 1, 200))
    Set tAgain = ..Parsed($Get(tResults("toolu_again")))
    Do $$$AssertEquals(($IsObject(tAgain) && (tAgain.%Get("code") = "WORKFLOW.ONECHANGE")), 1, "and a second valid edit is WORKFLOW.ONECHANGE: " _ $Extract($Get(tResults("toolu_again")), 1, 200))
    Do $$$AssertEquals(($IsObject(tView.%Get("proposals")) && (tView.proposals.%Size() = 1)), 1, "the turn holds exactly one proposal")
}

/// <p>AC4: a start naming a workflow outside the catalog, or a workflow that is no string, answers 422
/// <code>WORKFLOW.UNKNOWN</code> with the sentence on the <code>workflow</code> field and reserves nothing -- no
/// turn row, no provider call; a JSON <code>null</code> workflow passes and starts an ordinary turn.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Api.Turn.WorkflowViolation</method> always passes -> the 422 legs go
/// red.</p>
Method TestAnUnknownWorkflowIsRefusedAndReservesNothing()
{
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("ORDINARYTURN"))
    Set tConvId = ..NewConversation()
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.TurnFixture", "Keys", .tBefore), "the turns are counted before")
    For tCase = 1:1:3 {
        Set tBody = {"message": "go"}
        Do tBody.%Set("conversationId", tConvId, "string")
        If tCase = 1 Do tBody.%Set("workflow", "nosuch", "string")
        If tCase = 2 Do tBody.%Set("workflow", 5, "number")
        If tCase = 3 Do tBody.%Set("workflow", "", "string")
        Do $ClassMethod(..#FIXTURE, "Call", "POST", "/turn?ns=" _ ..#NAMESPACE, $Parameter(..#FIXTURE, "USERA"), ..PreparedTurnPassword, $ZConvert(tBody.%ToJSON(), "O", "UTF8"), .tStatus, .tText, .tHeaders)
        Set tAnswer = ..Parsed(tText)
        Do $$$AssertEquals(tStatus, 422, "case " _ tCase _ " answers 422: " _ $Extract(tText, 1, 200))
        Set tViolation = ""
        If $IsObject(tAnswer) && $IsObject(tAnswer.%Get("detail")) && $IsObject(tAnswer.detail.%Get("violations")) && (tAnswer.detail.violations.%Size() = 1) Set tViolation = tAnswer.detail.violations.%Get(0)
        Do $$$AssertEquals(($IsObject(tViolation) && (tViolation.%Get("field") = "workflow") && (tViolation.%Get("code") = "WORKFLOW.UNKNOWN") && (tViolation.%Get("reason") = "That guided workflow is not one OcuPilot offers.")), 1, "case " _ tCase _ " names WORKFLOW.UNKNOWN on workflow with its sentence: " _ $Extract(tText, 1, 300))
        Do $$$AssertEquals(($IsObject(tAnswer) && (tAnswer.%Get("code") = "WORKFLOW.UNKNOWN")), 1, "case " _ tCase _ " carries the code on the envelope")
    }
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Test.TurnFixture", "Keys", .tAfter), "and after")
    Do $$$AssertEquals(tAfter, tBefore, "no turn was reserved")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAG), 0, "and no provider call was made")

    Set tNullBody = {"message": "go", "workflow": null}
    Do tNullBody.%Set("conversationId", tConvId, "string")
    Do $ClassMethod(..#FIXTURE, "Call", "POST", "/turn?ns=" _ ..#NAMESPACE, $Parameter(..#FIXTURE, "USERA"), ..PreparedTurnPassword, $ZConvert(tNullBody.%ToJSON(), "O", "UTF8"), .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 202, "a JSON null workflow starts a turn: " _ $Extract(tText, 1, 200))
    If tStatus = 202 {
        Set tState = $ClassMethod(..#FIXTURE, "AwaitEnd", ##class(%DynamicObject).%FromJSON(tText).turnId, $Parameter(..#FIXTURE, "USERA"), ..PreparedTurnPassword, 90, .tView)
        Do $$$AssertEquals(tState, "completed", "which completes")
        Set tMessages = ..Parsed(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 1, "messages"))
        Do $$$AssertEquals(tMessages.%Size(), 1, "as an ordinary turn, opening with the person's message alone")
    }
}

}
