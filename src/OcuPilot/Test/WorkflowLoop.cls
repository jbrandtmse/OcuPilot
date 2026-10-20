/// <p>The guided-workflow turn in process (Story 20.12, AD-11, AD-66): the opening messages a turn that carries a
/// workflow builds -- the synthetic <code>workflow</code> call and result after screen context, or alone -- with the
/// ordinary turn's unchanged; a model call named <code>workflow</code> answering <code>TOOL.UNKNOWN</code>; and a
/// read-only workflow's refusal of a write tool. Each observed on the requests
/// <class>OcuPilot.Test.ProviderStub</class> recorded.</p>
/// <p>Driven through <class>OcuPilot.Test.TurnLoopProbe</class> as <class>OcuPilot.Test.TurnToolsCase</class>
/// sets it up, with <class>OcuPilot.Test.ToolDispatchProbe</class> over the counting fixture tools where a tool is
/// called. <b>Live-safe</b>: it spawns nothing and opens no socket; it writes probe agent definitions and turn rows
/// and removes every one after each method.</p>
Class OcuPilot.Test.WorkflowLoop Extends OcuPilot.Test.TurnToolsCase
{

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

}
