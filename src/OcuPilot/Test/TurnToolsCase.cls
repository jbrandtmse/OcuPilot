/// <p>What <class>OcuPilot.Test.TurnTools</class>, <class>OcuPilot.Test.TurnBudget</class>,
/// <class>OcuPilot.Test.TurnScope</class> and <class>OcuPilot.Test.TurnScopeFamilies</class> share:
/// the in-process turn harness -- <class>OcuPilot.Test.TurnLoopProbe</class> over
/// <class>OcuPilot.Test.ProviderPortProbe</class> and <class>OcuPilot.Test.ProviderStub</class> --
/// with <method>RunTurn</method> to run one turn as the suite's own account, <method>Reply</method> to
/// script a provider answer, and the setup and teardown that leave no probe definition, turn, ledger
/// row, slot or stub node behind. Setup forces the loop's restraint verdict clear, so the instance's
/// kill switch, read-only switch and holds do not reach a test. It declares no test of its own.</p>
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
    Do $ClassMethod(..#LOOP, "ForceRestraintClear")
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
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tKey), "turn " _ tKey _ "'s ledger rows are removed")
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Ledger).GuardedCountForTurn(tKey, .tLedgerRows), "and counted")
        Do $$$AssertEquals(tLedgerRows, 0, "and none survives")
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
/// <method>OnBeforeOneTest</method> sweeps every probe definition. The provider, model, endpoint and
/// key variable are the canonical probe family's unless a test names another family's, and
/// <var>pLocal</var> marks the endpoint local and its plain http acknowledged, as a keyed definition
/// on an operator's own network needs.</p>
Method NewDefinition(pProvider As %String = "probe-local", pModel As %String = "probe-local-model-1", pEndpoint As %String = "https://api.anthropic.com/v1/messages", pEnvVarName As %String = "OCUPILOT_PROBE_LOCAL_KEY", pLocal As %Boolean = 0) As %String
{
    Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
    Set tRow.Name = "OcuPilotProbeAgentTurnTools" _ $Increment(^||OcuPilotTurnToolsRunTurn)
    Set tRow.Provider = pProvider
    Set tRow.Model = pModel
    Set tRow.EndpointUrl = pEndpoint
    Set tRow.CredType = "env"
    Set tRow.EnvVarName = pEnvVarName
    If pLocal {
        Set tRow.MarkedLocal = 1
        Set tRow.HttpAcknowledged = 1
    }
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
/// The turn's read-only snapshot is <var>pReadOnly</var>, <code>""</code> reading as 0 as the
/// verdict setup forced clear does. <var>pContextRowCap</var> is the resolved row cap every
/// dispatched call in this turn is answered under (AD-24), <code>0</code> falling back to
/// <var>LOOP</var>'s own <code>TOOLROWS</code>, exactly as <method>OcuPilot.Kernel.Agent.Loop.Run</method>
/// takes it. With <var>pStopFirst</var> the turn is asked to stop after it begins and before the
/// loop runs; <var>pContext</var> and <var>pConvo</var> pass through to the loop unchanged. A turn
/// runs under the definition <var>pDefinitionId</var> when a test made one with
/// <method>NewDefinition</method>, else under a new canonical-family one. <var>pWorkflow</var>, a
/// guided workflow's catalog id, is recorded on the turn at begin (Story 20.12, AD-66).</p>
Method RunTurn(Output pOutcome, pReadOnly As %String = "", pContextRowCap As %Integer = 0, pStopFirst As %Boolean = 0, pContext As %String = "", pConvo As OcuPilot.Kernel.State.Convo = "", pDefinitionId As %String = "", pWorkflow As %String = "") As %String
{
    Set tId = $Select(pDefinitionId '= "": pDefinitionId, 1: ..NewDefinition())
    Set tLimits = $ClassMethod(..#LOOP, "LimitsClass")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedReserve($Username, tId, "TURN.ABANDONED.JOBLOST", tLimits, .tKey, .tBusy, .tSweep), "the turn is reserved")
    If $Get(tKey) = "" Quit ""
    Set ..PreparedKeys(tKey) = ""
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedBegin(tKey, $Username, tLimits, .tBegun, .tStarted, "", pWorkflow), "the turn begins")
    Set tReadOnly = ''pReadOnly
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
