/// <p>What <class>OcuPilot.Test.TurnTools</class> and <class>OcuPilot.Test.TurnBudget</class> share:
/// the in-process turn harness -- <class>OcuPilot.Test.TurnLoopProbe</class> over
/// <class>OcuPilot.Test.ProviderPortProbe</class> and <class>OcuPilot.Test.ProviderStub</class> --
/// with <method>RunTurn</method> to run one turn as the suite's own account, <method>Reply</method> to
/// script a provider answer, and the setup and teardown that leave no probe definition, turn, slot or
/// stub node behind. It declares no test of its own.</p>
/// <p>Spawns nothing and opens no socket.</p>
Class OcuPilot.Test.TurnToolsCase Extends %UnitTest.TestCase [ Abstract ]
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

/// <p>Create an enabled probe definition on the stub transport and answer its id. The name is unique
/// per call, so a test that creates more than one does not collide with itself before the next
/// <method>OnBeforeOneTest</method> sweeps every probe definition.</p>
Method NewDefinition() As %String
{
    Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
    Set tRow.Name = "OcuPilotProbeAgentTurnTools" _ $Increment(^||OcuPilotTurnToolsRunTurn)
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
    Quit tId
}

/// <p>Create an enabled probe definition on the stub transport, reserve, begin and run one turn as
/// the suite's own account, finish it, and answer its key with the outcome in <var>pOutcome</var>.
/// The turn's read-only snapshot is <var>pReadOnly</var>, or the instance's switch when that is
/// <code>""</code>. <var>pContextRowCap</var> is the resolved row cap every dispatched call in
/// this turn is answered under (AD-24), <code>0</code> falling back to
/// <var>LOOP</var>'s own <code>TOOLROWS</code>, exactly as <method>OcuPilot.Kernel.Agent.Loop.Run</method>
/// takes it. With <var>pStopFirst</var> the turn is asked to stop after it begins and before the
/// loop runs; <var>pContext</var> and <var>pConvo</var> pass through to the loop unchanged.</p>
Method RunTurn(Output pOutcome, pReadOnly As %String = "", pContextRowCap As %Integer = 0, pStopFirst As %Boolean = 0, pContext As %String = "", pConvo As OcuPilot.Kernel.State.Convo = "") As %String
{
    Set tId = ..NewDefinition()
    Set tLimits = $ClassMethod(..#LOOP, "LimitsClass")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedReserve($Username, tId, "TURN.ABANDONED.JOBLOST", tLimits, .tKey, .tBusy, .tSweep), "the turn is reserved")
    If $Get(tKey) = "" Quit ""
    Set ..PreparedKeys(tKey) = ""
    Do ##class(OcuPilot.Kernel.State.Switch).Resolve(.tSwitches)
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedBegin(tKey, $Username, tLimits, .tBegun, .tStarted), "the turn begins")
    Set tReadOnly = $Select(pReadOnly '= "": ''pReadOnly, 1: ''$Get(tSwitches("enforcedReadOnly")))
    If pStopFirst Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedRequestStop(tKey, $Username, .tFound), "a stop is requested")
    Set tSC = $ClassMethod(..#LOOP, "Run", tKey, $Username, tId, "what is on this instance", tReadOnly, ##class(OcuPilot.Api.Router).#ADMINRESOURCES, tStarted, .pOutcome, pContext, pContextRowCap, pConvo)
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

}
