/// <p>The guided-workflow turn in process (Stories 20.12 and 20.36, AD-11, AD-66): the opening messages a turn that
/// carries a workflow builds -- the synthetic <code>workflow</code> call and result after screen context, or alone --
/// with the ordinary turn's unchanged; a model call named <code>workflow</code> answering <code>TOOL.UNKNOWN</code>;
/// a read-only workflow's refusal of a write tool; the <code>investigate</code> turn's marked context and refusal; a
/// workflow's step tools joining the turn's starting tool set; and <code>previous</code> reporting only a turn of the
/// same workflow. Each observed on the requests <class>OcuPilot.Test.ProviderStub</class> recorded.</p>
/// <p>Driven through <class>OcuPilot.Test.TurnLoopProbe</class> as <class>OcuPilot.Test.TurnToolsCase</class>
/// sets it up, with <class>OcuPilot.Test.ToolDispatchProbe</class> over the counting fixture tools where a tool is
/// called. <b>Live-safe</b>: it spawns nothing and opens no socket; it writes probe agent definitions and turn rows
/// and removes every one after each method.</p>
Class OcuPilot.Test.WorkflowLoop Extends OcuPilot.Test.TurnToolsCase
{

/// <p>The conversation a method created, or <code>""</code>.</p>
Property ProbeConvKey As %String;

/// <p>Every turn key a method minted a proposal for, so teardown removes exactly those.</p>
Property ProposedKeys [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..ProbeConvKey = ""
    Kill ..ProposedKeys
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Set tKey = ""
    For {
        Set tKey = $Order(..ProposedKeys(tKey))
        If tKey = "" Quit
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForTurn(tKey), "turn " _ tKey _ "'s proposals are removed")
    }
    Kill ..ProposedKeys
    If ..ProbeConvKey '= "" Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Convo).GuardedDelete(..ProbeConvKey), "the conversation is removed")
    Set ..ProbeConvKey = ""
    Quit ##super()
}

/// <p>A screen-context payload the loop carries as given.</p>
Parameter CONTEXT = "{""route"":""system-explorer/classes"",""namespace"":""USER"",""tools"":[]}";

/// <p>The messages of the request the stub recorded as call <var>pCall</var>.</p>
Method MessagesOf(pCall As %Integer) As %DynamicArray
{
    Set tSent = ##class(%DynamicAbstractObject).%FromJSON($ClassMethod(..#STUB, "Recorded", "body", pCall))
    Quit tSent.messages
}

/// <p>The names of the <code>tool_use</code> blocks in message <var>pIndex</var>, in order, comma-joined.</p>
Method UsesIn(pMessages As %DynamicArray, pIndex As %Integer) As %String
{
    Set tNames = ""
    Set tIterator = pMessages.%Get(pIndex).content.%GetIterator()
    While tIterator.%GetNext(.tAt, .tBlock) {
        If tBlock.type = "tool_use" Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tBlock.name _ "=" _ tBlock.id
    }
    Quit tNames
}

/// <p>The <code>tool_use_id</code> of each <code>tool_result</code> block in message <var>pIndex</var> and then the
/// type of its last block, comma-joined.</p>
Method ResultsIn(pMessages As %DynamicArray, pIndex As %Integer) As %String
{
    Set tIds = ""
    Set tLast = ""
    Set tIterator = pMessages.%Get(pIndex).content.%GetIterator()
    While tIterator.%GetNext(.tAt, .tBlock) {
        If tBlock.type = "tool_result" Set tIds = tIds _ $Select(tIds = "": "", 1: ",") _ tBlock."tool_use_id"
        Set tLast = tBlock.type
    }
    Quit tIds _ "|" _ tLast
}

/// <p>The index of the user message of <var>pMessages</var> that holds the <code>workflow</code> result, or
/// <code>-1</code>.</p>
Method WorkflowMessage(pMessages As %DynamicArray) As %Integer
{
    Set tFound = -1
    For tI = 0:1:pMessages.%Size() - 1 {
        Set tMessage = pMessages.%Get(tI)
        If tMessage.%GetTypeOf("content") '= "array" Continue
        Set tIterator = tMessage.content.%GetIterator()
        While tIterator.%GetNext(.tAt, .tBlock) {
            If (tBlock.type = "tool_result") && (tBlock."tool_use_id" = "ocupilot_workflow") Set tFound = tI
        }
    }
    Quit tFound
}

/// <p>The data-framed body of the <code>tool_result</code> block of message <var>pIndex</var> whose id is
/// <var>pId</var>, parsed.</p>
Method ResultBody(pMessages As %DynamicArray, pIndex As %Integer, pId As %String) As %DynamicAbstractObject
{
    Set tBody = ""
    Set tIterator = pMessages.%Get(pIndex).content.%GetIterator()
    While tIterator.%GetNext(.tAt, .tBlock) {
        If (tBlock.type = "tool_result") && (tBlock."tool_use_id" = pId) {
            Set tBody = ##class(OcuPilot.Test.TurnWireFixture).Unwrapped(tBlock.content, .tWrapped)
            Do $$$AssertTrue(tWrapped, pId _ "'s result is framed as data")
        }
    }
    Quit ##class(%DynamicAbstractObject).%FromJSON(tBody)
}

/// <p>A workflow turn that carries screen context opens with the context preamble, one assistant message holding
/// the <code>screen_context</code> call and then the <code>workflow</code> call, and one user message holding their
/// results in the same order and the person's text last. The workflow result is framed as data and carries the
/// catalog's members for the workflow with an empty <code>previous</code> (the turn has no earlier turn).</p>
/// <p>Mutation: <method>OcuPilot.Kernel.Agent.Loop.Run</method> adds no <code>workflow</code> pair -> this goes
/// red.</p>
Method TestAWorkflowTurnWithContextOpensWithBothPairsInOrder()
{
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("done"))
    Set tKey = ..RunTurn(.tOutcome, "", 0, 0, ..#CONTEXT, "", "", "compileclass")
    Do $$$AssertEquals(tOutcome("state"), "completed", "the turn completes")
    Set tMessages = ..MessagesOf(1)
    Do $$$AssertEquals(tMessages.%Size(), 3, "the turn opens with three messages")
    If tMessages.%Size() '= 3 Quit
    Do $$$AssertTrue(tMessages.%Get(0).%ToJSON() [ ##class(OcuPilot.Kernel.Agent.Prompt).ContextPreamble(), "the first is the context preamble")
    Do $$$AssertEquals(..UsesIn(tMessages, 1), "screen_context=ocupilot_screen_context,workflow=ocupilot_workflow", "the assistant calls screen_context, then workflow")
    Do $$$AssertEquals(..ResultsIn(tMessages, 2), "ocupilot_screen_context,ocupilot_workflow|text", "the results come in the same order, the person's text last")
    Set tWorkflow = ..ResultBody(tMessages, 2, "ocupilot_workflow")
    Do $$$AssertEquals(tWorkflow.%Get("workflow") _ "|" _ tWorkflow.%Get("previous").%Size(), "compileclass|0", "the workflow result names the workflow and an empty previous")
    Do $$$AssertEquals(tWorkflow.steps.%Get(1).writes.%ToJSON(), "[""explorer.classes.save""]", "and its steps name the save")
    Set tContext = ..ResultBody(tMessages, 2, "ocupilot_screen_context")
    Do $$$AssertEquals(tContext.route, "system-explorer/classes", "the screen context is the payload the turn carried")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).Field(tKey, "Workflow"), "compileclass", "and the turn row records its workflow")
}

/// <p>A workflow turn with no screen context opens with the workflow preamble and the <code>workflow</code> call
/// alone.</p>
/// <p>Mutation: the opening builder keeps the context preamble for a workflow turn -> this goes red.</p>
Method TestAWorkflowTurnWithoutContextOpensWithTheWorkflowPairAlone()
{
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("done"))
    Set tKey = ..RunTurn(.tOutcome, "", 0, 0, "", "", "", "securityposture")
    Do $$$AssertEquals(tOutcome("state"), "completed", "the turn completes")
    Set tMessages = ..MessagesOf(1)
    Do $$$AssertEquals(tMessages.%Size(), 3, "the turn opens with three messages")
    If tMessages.%Size() '= 3 Quit
    Do $$$AssertTrue(tMessages.%Get(0).%ToJSON() [ ##class(OcuPilot.Kernel.Agent.Prompt).WorkflowPreamble(), "the first is the workflow preamble")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Agent.Prompt).WorkflowPreamble(), "Here is the guided workflow the user chose.", "which is the published sentence")
    Do $$$AssertEquals(..UsesIn(tMessages, 1), "workflow=ocupilot_workflow", "the assistant calls workflow alone")
    Do $$$AssertEquals(..ResultsIn(tMessages, 2), "ocupilot_workflow|text", "and one result precedes the person's text")
    Set tWorkflow = ..ResultBody(tMessages, 2, "ocupilot_workflow")
    Do $$$AssertEquals(tWorkflow.%Get("workflow") _ "|" _ tWorkflow.steps.%Size(), "securityposture|5", "the result is the read-only workflow's five steps")
}

/// <p>A turn with no workflow opens exactly as it always did: one message with no context, and the three of the
/// context pair with it, holding no <code>workflow</code> call.</p>
/// <p>Mutation: the opening builder always adds the workflow pair -> this goes red.</p>
Method TestAnOrdinaryTurnOpensAsItAlwaysDid()
{
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("done"))
    Set tKey = ..RunTurn(.tOutcome)
    Set tMessages = ..MessagesOf(1)
    Do $$$AssertEquals(tMessages.%Size(), 1, "a turn with no context opens with the person's message alone")
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("done"))
    Set tKey = ..RunTurn(.tOutcome, "", 0, 0, ..#CONTEXT)
    Set tMessages = ..MessagesOf(2)
    Do $$$AssertEquals(tMessages.%Size(), 3, "a turn with context opens with the context pair")
    If tMessages.%Size() '= 3 Quit
    Do $$$AssertTrue(tMessages.%Get(0).%ToJSON() [ ##class(OcuPilot.Kernel.Agent.Prompt).ContextPreamble(), "under the context preamble")
    Do $$$AssertEquals(..UsesIn(tMessages, 1), "screen_context=ocupilot_screen_context", "with the screen_context call alone")
    Do $$$AssertEquals(..ResultsIn(tMessages, 2), "ocupilot_screen_context|text", "answered by one result before the text")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).Field(tKey, "Workflow"), "", "and the turn row records no workflow")
}

/// <p>A model call named <code>workflow</code> is unknown: the workflow pair is never advertised, so the dispatcher
/// answers <code>TOOL.UNKNOWN</code> and runs nothing.</p>
/// <p>Mutation: the dispatcher resolves the name <code>workflow</code> -> this goes red.</p>
Method TestAModelCallNamedWorkflowAnswersToolUnknown()
{
    Do $ClassMethod(..#LOOP, "SetDispatchClass", ..#DISPATCH)
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("", [{"id": "toolu_1", "name": "workflow", "input": {}}]))
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("done"))
    Set tKey = ..RunTurn(.tOutcome, "", 0, 0, "", "", "", "compileclass")
    Do $$$AssertEquals(tOutcome("state"), "completed", "the turn completes")
    Set tMessages = ..MessagesOf(2)
    Set tBody = ..ResultBody(tMessages, 4, "toolu_1")
    Do $$$AssertEquals(tBody.%Get("code"), "TOOL.UNKNOWN", "the model's call is unknown")
    Set tAdvertised = ##class(%DynamicAbstractObject).%FromJSON($ClassMethod(..#STUB, "Recorded", "body", 1)).tools
    Set tNames = ""
    Set tIterator = tAdvertised.%GetIterator()
    While tIterator.%GetNext(.tAt, .tTool) {
        Set tNames = tNames _ "," _ tTool.name
    }
    Do $$$AssertEquals((tNames _ ",") [ ",workflow,", 0, "and no tool is advertised under that name")
}

/// <p>A read-only workflow refuses every write: a <code>securityposture</code> turn that calls the fixture write
/// tool is answered <code>WORKFLOW.NOTASTEP</code> and the tool does not run, while an ordinary turn's call to it
/// runs.</p>
/// <p>Mutation: the dispatcher's workflow step is removed -> this goes red.</p>
Method TestAReadOnlyWorkflowRefusesAWriteTool()
{
    Do $ClassMethod(..#LOOP, "SetDispatchClass", ..#DISPATCH)
    Do $ClassMethod(..#DISPATCH, "ForceRestraint", "clear")
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("", [{"id": "toolu_1", "name": "probe_counter_write", "input": {"marker": "w"}}]))
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("done"))
    Set tKey = ..RunTurn(.tOutcome, "", 0, 0, "", "", "", "securityposture")
    Do $$$AssertEquals(tOutcome("state"), "completed", "the turn completes")
    Set tBody = ..ResultBody(..MessagesOf(2), 4, "toolu_1")
    Do $$$AssertEquals(tBody.%Get("code"), "WORKFLOW.NOTASTEP", "the write is refused WORKFLOW.NOTASTEP")
    Do $$$AssertEquals(##class(OcuPilot.Test.DispatchTool.Counter).Calls("probe.counter.write"), 0, "and the tool never ran")

    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("", [{"id": "toolu_2", "name": "probe_counter_write", "input": {"marker": "w"}}]))
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("done"))
    Set tKey = ..RunTurn(.tOutcome)
    Do $$$AssertEquals(tOutcome("state"), "completed", "an ordinary turn completes")
    Do $$$AssertEquals(##class(OcuPilot.Test.DispatchTool.Counter).Calls("probe.counter.write"), 1, "and its call to the write tool runs")
}

/// <p>A screen-context payload that marks the second of two rows as the entry the user chose (the explain-entry
/// marker).</p>
Parameter ENTRYCONTEXT = "{""route"":""logs/messages"",""namespace"":""HSCUSTOM"",""tools"":[],""view"":{""rows"":[{""time"":""2026-11-12T09:00:00.000"",""severity"":""0"",""text"":""first line""},{""time"":""2026-11-12T09:00:01.000"",""severity"":""2"",""text"":""second line""}],""rowsAvailable"":2,""selected"":1}}";

/// <p>An <code>investigate</code> turn from a log entry opens with the context preamble, the <code>screen_context</code>
/// call whose result carries the marker, then the <code>workflow</code> call whose result names Recap and Hypotheses,
/// has no write in any step and reports no <code>previous</code>, all before the person's text.</p>
/// <p>Mutation: the catalog's <code>investigate</code> entry is removed -> this goes red on the turn's workflow.</p>
Method TestAnInvestigateTurnOpensWithTheMarkedContextThenItsWorkflow()
{
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("done"))
    Set tKey = ..RunTurn(.tOutcome, "", 0, 0, ..#ENTRYCONTEXT, "", "", "investigate")
    Do $$$AssertEquals(tOutcome("state"), "completed", "the turn completes")
    Set tMessages = ..MessagesOf(1)
    Do $$$AssertEquals(tMessages.%Size(), 3, "the turn opens with three messages")
    If tMessages.%Size() '= 3 Quit
    Do $$$AssertEquals(..UsesIn(tMessages, 1), "screen_context=ocupilot_screen_context,workflow=ocupilot_workflow", "the assistant calls screen_context, then workflow")
    Do $$$AssertEquals(..ResultsIn(tMessages, 2), "ocupilot_screen_context,ocupilot_workflow|text", "the results come in the same order, the person's text last")
    Set tContext = ..ResultBody(tMessages, 2, "ocupilot_screen_context")
    Do $$$AssertEquals(tContext.view.selected _ "|" _ tContext.view.rows.%Get(1).text, "1|second line", "the screen context carries the marker for the chosen row")
    Do $$$AssertEquals($IsObject(tContext.view.%Get("focus")), 0, "and exactly one marker")
    Set tWorkflow = ..ResultBody(tMessages, 2, "ocupilot_workflow")
    Do $$$AssertEquals(tWorkflow.%Get("workflow") _ "|" _ tWorkflow.%Get("previous").%Size() _ "|" _ tWorkflow.steps.%Size(), "investigate|0|3", "the result names investigate, three steps and an empty previous")
    Do $$$AssertTrue((tWorkflow.finish [ "Recap") && (tWorkflow.finish [ "Hypotheses"), "and its finish names the Recap and the Hypotheses")
    Set tWrites = 0
    Set tIterator = tWorkflow.steps.%GetIterator()
    While tIterator.%GetNext(.tAt, .tStep) {
        If tStep.%GetTypeOf("writes") '= "unassigned" Set tWrites = tWrites + 1
    }
    Do $$$AssertEquals(tWrites, 0, "no step names a write")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).Field(tKey, "Workflow"), "investigate", "and the turn row records its workflow")
}

/// <p>An <code>investigate</code> turn refuses a write: the fixture write tool is answered
/// <code>WORKFLOW.NOTASTEP</code> and its counter does not move.</p>
/// <p>Mutation: the catalog's <code>investigate</code> entry gains <code>"writes": ["probe.counter.write"]</code>
/// -> this goes red (the tool runs).</p>
Method TestAnInvestigateTurnRefusesAWrite()
{
    Do $ClassMethod(..#LOOP, "SetDispatchClass", ..#DISPATCH)
    Do $ClassMethod(..#DISPATCH, "ForceRestraint", "clear")
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("", [{"id": "toolu_1", "name": "probe_counter_write", "input": {"marker": "w"}}]))
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("done"))
    Set tKey = ..RunTurn(.tOutcome, "", 0, 0, ..#ENTRYCONTEXT, "", "", "investigate")
    Do $$$AssertEquals(tOutcome("state"), "completed", "the turn completes")
    Set tMessages = ..MessagesOf(2)
    Set tBody = ..ResultBody(tMessages, tMessages.%Size() - 1, "toolu_1")
    Do $$$AssertEquals(tBody.%Get("code"), "WORKFLOW.NOTASTEP", "the write is refused WORKFLOW.NOTASTEP")
    Do $$$AssertEquals(##class(OcuPilot.Test.DispatchTool.Counter).Calls("probe.counter.write"), 0, "and the counter did not move")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedCountForTurn(tKey, .tMinted), "the turn's proposals are counted")
    Do $$$AssertEquals(tMinted, 0, "and the turn minted no proposal")
}

/// <p>A workflow's step tools join the turn's starting tool set: an <code>investigate</code> turn from a screen whose
/// context names no tools sends <code>logs_messages_read</code> and <code>osmgmt_dashboard_read</code> undeferred, as the
/// ordinary turn from the same screen defers them, and still defers a tool no step names.</p>
/// <p>Mutation: <method>OcuPilot.Kernel.Agent.Loop.Scope</method> ignores its workflow argument -> this goes red.</p>
Method TestAWorkflowsStepToolsStartInTheToolSet()
{
    Do $ClassMethod(..#LOOP, "SetLimitsClass", "OcuPilot.Kernel.Agent.Limits")
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("done"))
    Set tKey = ..RunTurn(.tOrdinary, "", 0, 0, ..#ENTRYCONTEXT)
    Do $$$AssertEquals(tOrdinary("state"), "completed", "the ordinary turn completes")
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("done"))
    Set tKey = ..RunTurn(.tOutcome, "", 0, 0, ..#ENTRYCONTEXT, "", "", "investigate")
    Do $$$AssertEquals(tOutcome("state"), "completed", "the investigate turn completes")
    Set tOrdinaryDeferred = ","_##class(OcuPilot.Test.TurnScope).Deferred(##class(OcuPilot.Test.TurnBudget).Sent(1).tools, 1)_","
    Set tStartDeferred = ","_##class(OcuPilot.Test.TurnScope).Deferred(##class(OcuPilot.Test.TurnBudget).Sent(2).tools, 1)_","
    Do $$$AssertTrue(tOrdinaryDeferred [ ",logs_messages_read,", "the ordinary turn defers the messages.log read")
    Do $$$AssertTrue(tOrdinaryDeferred [ ",osmgmt_dashboard_read,", "and the dashboard read")
    Do $$$AssertEquals(tStartDeferred [ ",logs_messages_read,", 0, "the investigate turn starts with the messages.log read")
    Do $$$AssertEquals(tStartDeferred [ ",osmgmt_dashboard_read,", 0, "and the dashboard read")
    Do $$$AssertTrue(tStartDeferred [ ",permissions_users_read,", "while a tool no step names stays deferred")
}

/// <p><code>previous</code> reports the proposals of the conversation's newest earlier turn only when that turn ran the
/// same workflow: an <code>investigate</code> turn after an ordinary turn that minted a proposal reports none, and the
/// next <code>investigate</code> turn reports the one the first minted.</p>
/// <p>Mutation: <method>OcuPilot.Kernel.Agent.Loop.WorkflowResult</method> skips the earlier turn's workflow check ->
/// this goes red at the first investigate turn.</p>
Method TestPreviousReportsOnlyATurnOfTheSameWorkflow()
{
    Set tLimits = $ClassMethod(..#LOOP, "LimitsClass")
    Set tConvo = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate("", $Username, 5, .tConvoSC, .tConflict)
    Do $$$AssertStatusOK(tConvoSC, "a conversation is created")
    If '$IsObject(tConvo) Quit
    Set ..ProbeConvKey = tConvo.ConvKey

    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("done"))
    Set tOrdinary = ..RunTurn(.tOutcome, "", 0, 0, "", tConvo)
    Do $$$AssertEquals(tOutcome("state"), "completed", "an ordinary turn completes")
    Do ..Finish(tConvo, tOrdinary, "explorer.classes.save", tLimits)

    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("done"))
    Set tFirst = ..RunTurn(.tOutcome, "", 0, 0, ..#ENTRYCONTEXT, tConvo, "", "investigate")
    Do $$$AssertEquals(tOutcome("state"), "completed", "the first investigate turn completes")
    Set tMessages = ..MessagesOf(2)
    Set tAt = ..WorkflowMessage(tMessages)
    Do $$$AssertTrue(tAt >= 0, "it carries a workflow result")
    If tAt < 0 Quit
    Set tWorkflow = ..ResultBody(tMessages, tAt, "ocupilot_workflow")
    Do $$$AssertEquals(tWorkflow.%Get("previous").%Size(), 0, "after an ordinary turn that proposed a change, previous reports none")
    Do ..Finish(tConvo, tFirst, "osmgmt.namespaces.create", tLimits)

    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("done"))
    Set tSecond = ..RunTurn(.tOutcome, "", 0, 0, ..#ENTRYCONTEXT, tConvo, "", "investigate")
    Do $$$AssertEquals(tOutcome("state"), "completed", "the second investigate turn completes")
    Set tMessages = ..MessagesOf(3)
    Set tAt = ..WorkflowMessage(tMessages)
    If tAt < 0 Quit
    Set tWorkflow = ..ResultBody(tMessages, tAt, "ocupilot_workflow")
    Do $$$AssertEquals(tWorkflow.%Get("previous").%Size(), 1, "after a turn of the same workflow, previous reports its one proposal")
    Do $$$AssertEquals(tWorkflow.%Get("previous").%Get(0).%Get("tool"), "osmgmt.namespaces.create", "and it is that turn's, not the ordinary turn's")
    Set tConvo = ""
}

/// <p>Mint one live proposal of <var>pTool</var> for turn <var>pTurnKey</var> in <var>pConvo</var>, then append the
/// turn's entry, so the conversation's newest entry is that turn.</p>
Method Finish(pConvo As OcuPilot.Kernel.State.Convo, pTurnKey As %String, pTool As %String, pLimits As %String)
{
    Kill tValues
    Set tValues("user") = $Username
    Set tValues("convKey") = pConvo.ConvKey
    Set tValues("turnKey") = pTurnKey
    Set tValues("toolName") = pTool
    Do ##class(OcuPilot.Kernel.EntityRef).Key("task", "instance", "OcuPilotProbe" _ pTurnKey, .tRef)
    Set tValues("targetRef") = tRef
    Set tValues("diff") = "[]"
    Set tValues("payload") = "{}"
    Set tValues("arguments") = "{}"
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedMint(.tValues, pLimits, .tProposal, .tToken, .tExpires), "turn " _ pTurnKey _ " minted a proposal")
    Set ..ProposedKeys(pTurnKey) = ""
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Convo).AppendEntry(pConvo, "what is on this instance", "completed", "done", "", 0, [], 0, pLimits, pTurnKey), "and its entry is appended")
}

}
