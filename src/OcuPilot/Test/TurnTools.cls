/// <p>The turn loop's tools, in process (AD-11, AD-22): every provider request advertises every
/// registered tool, a registry that cannot list ends the turn before any provider call, several calls
/// are answered in order in one message, the step boundary runs between two calls, and no tool result
/// reaches the system prompt -- each observed on the requests <class>OcuPilot.Test.ProviderStub</class>
/// recorded and on the turn's steps.</p>
/// <p>Driven through <class>OcuPilot.Test.TurnLoopProbe</class>, with the shipped dispatcher or
/// <class>OcuPilot.Test.ToolDispatchProbe</class> over the counting fixture tools. <b>Live-safe</b>:
/// it spawns nothing and opens no socket; it writes probe agent definitions and turn rows in
/// OcuPilot's own database and removes every one after each method.</p>
Class OcuPilot.Test.TurnTools Extends %UnitTest.TestCase
{

Parameter LOOP = "OcuPilot.Test.TurnLoopProbe";

Parameter PORT = "OcuPilot.Test.ProviderPortProbe";

Parameter STUB = "OcuPilot.Test.ProviderStub";

Parameter DISPATCH = "OcuPilot.Test.ToolDispatchProbe";

Parameter PROBEKEY = "probe-local-abcdefghijklmnop";

/// <p>Every turn key a method created, so teardown removes exactly those.</p>
Property PreparedKeys [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Kill ..PreparedKeys
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Reset")
    Do $ClassMethod(..#PORT, "SetSecretClass", "OcuPilot.Test.SecretProbe")
    Do $ClassMethod(..#PORT, "SetSslState", "present")
    Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
    Do $ClassMethod(..#LOOP, "Reset")
    Do $ClassMethod(..#DISPATCH, "Reset")
    Do ##class(OcuPilot.Test.DispatchTool.Counter).Clear()
    Kill ..PreparedKeys
    Quit ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Reset")
    Do $ClassMethod(..#LOOP, "Reset")
    Do $ClassMethod(..#DISPATCH, "Reset")
    Do ##class(OcuPilot.Test.DispatchTool.Counter).Clear()
    Set tKey = ""
    For {
        Set tKey = $Order(..PreparedKeys(tKey))
        If tKey = "" Quit
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedDelete(tKey), "turn " _ tKey _ " is removed")
        Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).Field(tKey, "State"), "", "and no row of it survives")
        Do $$$AssertEquals($Data(^OcuPilotTurnSignal(tKey)), 0, "nor any signal")
        Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).StepCount(tKey), 0, "nor any step")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).SlotOwner($Username), "", "no turn slot is left held")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining), "the probe definitions are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>Create an enabled probe definition on the stub transport, reserve, begin and run one turn as
/// the suite's own account, finish it, and answer its key with the outcome in <var>pOutcome</var>.</p>
Method RunTurn(Output pOutcome) As %String
{
    Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
    Set tRow.Name = "OcuPilotProbeAgentTurnTools"
    Set tRow.Provider = "probe-local"
    Set tRow.Model = "probe-local-model-1"
    Set tRow.EndpointUrl = "https://api.anthropic.com/v1/messages"
    Set tRow.CredType = "env"
    Set tRow.EnvVarName = "OCUPILOT_PROBE_LOCAL_KEY"
    Set tRow.MaxTokens = 4000
    Set tRow.MaxIterationsPerTurn = 10
    Set tRow.Enabled = 1
    Set tRow.ConnectionVerified = 1
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tRow), "a probe definition is created")
    Set tId = tRow.%Id()
    Set tRow = ""
    Set tLimits = $ClassMethod(..#LOOP, "LimitsClass")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedReserve($Username, tId, "TURN.ABANDONED.JOBLOST", tLimits, .tKey, .tBusy, .tSweep), "the turn is reserved")
    If $Get(tKey) = "" Quit ""
    Set ..PreparedKeys(tKey) = ""
    Do ##class(OcuPilot.Kernel.State.Switch).Resolve(.tSwitches)
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedBegin(tKey, $Username, tLimits, .tBegun, .tStarted), "the turn begins")
    Set tSC = $ClassMethod(..#LOOP, "Run", tKey, $Username, tId, "what is on this instance", ''$Get(tSwitches("enforcedReadOnly")), ##class(OcuPilot.Api.Router).#ADMINRESOURCES, tStarted, .pOutcome)
    Do $$$AssertStatusOK(tSC, "the loop returns")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tKey, $Username, pOutcome("state"), pOutcome("code"), pOutcome("limit"), pOutcome("reply"), pOutcome("errorSeq"), tLimits), "and the turn is finished")
    Quit tKey
}

/// <p>A reply body: <var>pText</var> when not empty, then one <code>tool_use</code> block per entry of
/// <var>pCalls</var> (<code>{id, name, input}</code>); <code>end_turn</code> when there is none.</p>
ClassMethod Reply(pText As %String, pCalls As %DynamicArray = "") As %String
{
    Set tBody = {"content": [], "usage": {"input_tokens": 0, "output_tokens": 0}}
    If pText '= "" Do tBody.content.%Push({"type": "text", "text": (pText)})
    Set tCount = $Select($IsObject(pCalls): pCalls.%Size(), 1: 0)
    For tI = 0:1:tCount - 1 {
        Set tBlock = {"type": "tool_use"}
        Do tBlock.%Set("id", pCalls.%Get(tI).id, "string")
        Do tBlock.%Set("name", pCalls.%Get(tI).name, "string")
        Do tBlock.%Set("input", pCalls.%Get(tI).input)
        Do tBody.content.%Push(tBlock)
    }
    Do tBody.%Set("stop_reason", $Select(tCount > 0: "tool_use", 1: "end_turn"), "string")
    Quit tBody.%ToJSON()
}

/// <p>Advertise -- both provider requests of a two-call turn carry every registered tool in name
/// order, each with its wire name, its description and its emitted schema, with no
/// <code>maxLength</code> keyword and the bound in the description.</p>
/// <p>Mutation: <method>OcuPilot.Kernel.Agent.Loop.Run</method> keeps <code>Kill tTools</code> before
/// each call -> this goes red.</p>
Method TestEveryRequestAdvertisesEveryTool()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ProviderTools(.tExpected), "the registry advertises")
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("", [{"id": "toolu_1", "name": "probe_nosuch_read", "input": {}}]))
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("done"))
    Set tKey = ..RunTurn(.tOutcome)
    Do $$$AssertEquals(tOutcome("state"), "completed", "the turn completes")
    Do $$$AssertEquals($ClassMethod(..#STUB, "Calls"), 2, "after two provider calls")
    For tCall = 1, 2 {
        Set tSent = ##class(%DynamicAbstractObject).%FromJSON($ClassMethod(..#STUB, "Recorded", "body", tCall))
        Do $$$AssertTrue($IsObject(tSent.tools), "call " _ tCall _ " carries a tool array")
        If '$IsObject(tSent.tools) Continue
        Do $$$AssertEquals(tSent.tools.%Size(), +$Get(tExpected), "call " _ tCall _ " carries every registered tool")
        Do $$$AssertEquals(tSent.tools.%ToJSON() [ "maxLength", 0, "call " _ tCall _ " advertises no maxLength keyword")
        For tI = 1:1:+$Get(tExpected) {
            Set tTool = tSent.tools.%Get(tI - 1)
            Do $$$AssertEquals(tTool.name _ "|" _ tTool.description, tExpected(tI, "name") _ "|" _ tExpected(tI, "description"), "call " _ tCall _ " tool " _ tI _ ": its wire name and description, in name order")
            Do $$$AssertEquals(tTool."input_schema".%ToJSON(), tExpected(tI, "inputSchema"), "call " _ tCall _ " tool " _ tI _ ": its emitted schema")
        }
    }
    Do $$$AssertTrue($ClassMethod(..#STUB, "Recorded", "body", 1) [ "At most 50 characters.", "a declared bound is stated in a description")
}

/// <p>Advertise, refused -- a registry that cannot list ends the turn <code>failed</code>
/// <code>TURN.UNAVAILABLE</code>, logged, with no provider call.</p>
/// <p>Mutation: <method>OcuPilot.Kernel.Agent.Loop.Run</method> ends the turn without logging -> this
/// goes red.</p>
Method TestAListingThatFailsEndsTheTurnBeforeAProviderCall()
{
    Do $ClassMethod(..#LOOP, "SetDispatchClass", ..#DISPATCH)
    Do $ClassMethod(..#DISPATCH, "SetRegistryClass", "OcuPilot.Test.ReadTwinToolRegistry")
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("never"))
    Set tKey = ..RunTurn(.tOutcome)
    Do $$$AssertEquals(tOutcome("state") _ "|" _ tOutcome("code") _ "|" _ tOutcome("errorSeq"), "failed|TURN.UNAVAILABLE|0", "the turn fails before any step")
    Do $$$AssertEquals($ClassMethod(..#STUB, "Calls"), 0, "with no provider call")
    Do $$$AssertTrue($ClassMethod(..#LOOP, "Logged") [ "the turn's tools could not be advertised | TURN.UNAVAILABLE", "and the refusal is logged: " _ $ClassMethod(..#LOOP, "Logged"))
}

/// <p>Several calls -- one reply's three calls are answered by three <code>tool_result</code> blocks
/// in the same order, in one user message holding no text block, and recorded as three tool steps
/// under their dotted names.</p>
/// <p>Mutation: <method>OcuPilot.Kernel.Agent.Loop.AnswerTools</method> puts each result ahead of the
/// ones before it -> this goes red.</p>
Method TestSeveralCallsAreAnsweredInOrderInOneMessage()
{
    Do $ClassMethod(..#LOOP, "SetDispatchClass", ..#DISPATCH)
    Do $ClassMethod(..#LOOP, "SetLimitsClass", "OcuPilot.Kernel.Agent.Limits")
    Set tCalls = [{"id": "toolu_1", "name": "probe_counter_read", "input": {"marker": "m1"}}, {"id": "toolu_2", "name": "probe_nosuch_read", "input": {}}, {"id": "toolu_3", "name": "probe_counter_read", "input": {"marker": "m3"}}]
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("looking", tCalls))
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("done"))
    Set tKey = ..RunTurn(.tOutcome)
    Do $$$AssertEquals(tOutcome("state") _ "|" _ tOutcome("reply"), "completed|done", "the turn completes")
    Set tSent = ##class(%DynamicAbstractObject).%FromJSON($ClassMethod(..#STUB, "Recorded", "body", 2))
    Do $$$AssertEquals(tSent.messages.%Size(), 3, "the second request carries the message, the echo and the results")
    Set tResults = tSent.messages.%Get(2)
    Do $$$AssertEquals(tResults.role _ "|" _ tResults.content.%Size(), "user|3", "one user message of three blocks")
    Set tShape = ""
    For tI = 0:1:2 {
        Set tBlock = tResults.content.%Get(tI)
        Set tShape = tShape _ tBlock.type _ ":" _ tBlock."tool_use_id" _ ":" _ tBlock."is_error" _ ";"
    }
    Do $$$AssertEquals(tShape, "tool_result:toolu_1:0;tool_result:toolu_2:1;tool_result:toolu_3:0;", "every block a tool result, in call order, no text block")
    Do $$$AssertTrue((tResults.content.%Get(0).content [ """m1""") && (tResults.content.%Get(2).content [ """m3"""), "each carrying its own call's result")
    Do $$$AssertEquals(tResults.content.%Get(1).content, "{""code"":""TOOL.UNKNOWN""}", "and the unknown call its code")

    Do ##class(OcuPilot.Kernel.State.Turn).GuardedView(tKey, $Username, .tFound, .tView)
    Set tSteps = ""
    For tI = 0:1:tView.steps.%Size() - 1 {
        Set tStep = tView.steps.%Get(tI)
        Set tSteps = tSteps _ tStep.kind _ ":" _ tStep.name _ ":" _ tStep.status _ ";"
    }
    Do $$$AssertEquals(tSteps, "model:provider:ok;tool:probe.counter.read:ok;tool:probe_nosuch_read:error;tool:probe.counter.read:ok;model:provider:ok;", "three tool steps under their dotted names")
}

/// <p>Step boundary (AD-30) -- the kill switch turned on while a reply's first call is answered stops
/// the turn at the boundary before its second call: the second call's tool never runs, no step is
/// recorded for it, no further provider call is made, and the error names the first call's step.</p>
/// <p>Mutation: <method>OcuPilot.Kernel.Agent.Loop.AnswerTools</method> runs no boundary before a
/// call -> this goes red.</p>
Method TestTheKillSwitchStopsTheTurnBetweenTwoCalls()
{
    Do $ClassMethod(..#LOOP, "SetDispatchClass", ..#DISPATCH)
    Do $ClassMethod(..#LOOP, "SetLimitsClass", "OcuPilot.Kernel.Agent.Limits")
    Do $ClassMethod(..#LOOP, "ForceKillSwitchAfterCalls", 1, "AGENT.KILLSWITCH.USER")
    Set tCalls = [{"id": "toolu_1", "name": "probe_counter_read", "input": {"marker": "m1"}}, {"id": "toolu_2", "name": "probe_counter_read", "input": {"marker": "m2"}}]
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("looking", tCalls))
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("done"))
    Set tKey = ..RunTurn(.tOutcome)
    Do $$$AssertEquals(tOutcome("state") _ "|" _ tOutcome("code"), "stopped|AGENT.KILLSWITCH.USER", "the turn stops with the switch's code")
    Do $$$AssertEquals($ClassMethod(..#STUB, "Calls"), 1, "with no further provider call")
    Do $$$AssertEquals(##class(OcuPilot.Test.DispatchTool.Counter).Calls("probe.counter.read"), 1, "and the second call's tool never ran")
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedView(tKey, $Username, .tFound, .tView)
    Set tSteps = ""
    For tI = 0:1:tView.steps.%Size() - 1 {
        Set tStep = tView.steps.%Get(tI)
        Set tSteps = tSteps _ tStep.kind _ ":" _ tStep.name _ ":" _ tStep.status _ ";"
    }
    Do $$$AssertEquals(tSteps, "model:provider:ok;tool:probe.counter.read:ok;", "one tool step, the first call's")
    Do $$$AssertEquals(tOutcome("errorSeq"), 2, "and the error names it")
}

/// <p>Prompt -- a tool result appears in the next request only inside its <code>tool_result</code>
/// block, and every request's system prompt is the built-in one, unchanged.</p>
/// <p>Mutation: <method>OcuPilot.Kernel.Agent.Loop.Run</method> joins the last tool result to the
/// system prompt -> this goes red.</p>
Method TestNoToolResultReachesTheSystemPrompt()
{
    Do $ClassMethod(..#LOOP, "SetDispatchClass", ..#DISPATCH)
    Set tMarker = $Translate($Justify("", 37), " ", "r")
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("", [{"id": "toolu_1", "name": "probe_counter_read", "input": {"rows": 1, "width": 37}}]))
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply("done"))
    Set tKey = ..RunTurn(.tOutcome)
    Do $$$AssertEquals(tOutcome("state"), "completed", "the turn completes")
    Do $$$AssertEquals($ClassMethod(..#STUB, "Calls"), 2, "after two provider calls")
    For tCall = 1, 2 {
        Set tBody = $ClassMethod(..#STUB, "Recorded", "body", tCall)
        Set tSent = ##class(%DynamicAbstractObject).%FromJSON(tBody)
        Do $$$AssertEquals(tSent.system, ##class(OcuPilot.Kernel.Agent.Prompt).Builtin(), "call " _ tCall _ " carries the built-in system prompt, whole")
    }
    Do $$$AssertEquals($Length(tBody, tMarker) - 1, 1, "the result's text appears once in the second request")
    Set tResult = tSent.messages.%Get(2).content.%Get(0)
    Do $$$AssertEquals(tResult.type _ "|" _ (tResult.content [ tMarker), "tool_result|1", "inside the tool_result block")
}

}
