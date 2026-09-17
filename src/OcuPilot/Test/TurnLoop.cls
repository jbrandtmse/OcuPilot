/// <p>The turn loop in process (AD-7, AD-11, AD-30, AD-31, AD-41): bounds and the fallback reply,
/// every step-boundary check, provider faults, progress caps and system-prompt precedence, driven
/// through <class>OcuPilot.Test.TurnLoopProbe</class> -- the real loop over
/// <class>OcuPilot.Test.ProviderPortProbe</class>'s stub transport and
/// <class>OcuPilot.Test.TurnLimits</class>' narrowed caps.</p>
/// <p><b>Live-safe.</b> It spawns nothing and opens no socket. It writes probe agent definitions
/// and turn rows in OcuPilot's own database and removes every one of them after each method; the
/// turns run as the suite's own account, because the grants check reads a real account's
/// grants.</p>
Class OcuPilot.Test.TurnLoop Extends %UnitTest.TestCase
{

Parameter LOOP = "OcuPilot.Test.TurnLoopProbe";

Parameter PORT = "OcuPilot.Test.ProviderPortProbe";

Parameter PROBEKEY = "probe-local-abcdefghijklmnop";

Parameter JOBLOST = "TURN.ABANDONED.JOBLOST";

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
    Kill ..PreparedKeys
    Quit ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#PORT, "Reset")
    Do $ClassMethod(..#LOOP, "Reset")
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

/// <p>An enabled probe definition on the stub transport, with <var>pMaxIterations</var> and
/// <var>pOverride</var>; <var>pCreds</var> puts it on the credentials rung.</p>
Method Definition(pMaxIterations As %Integer = 10, pOverride As %String = "", pCreds As %Boolean = 0) As %String
{
    Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
    Set tRow.Name = "OcuPilotProbeAgentTurnLoop"
    Set tRow.Provider = "probe-local"
    Set tRow.Model = "probe-local-model-1"
    Set tRow.EndpointUrl = "https://api.anthropic.com/v1/messages"
    Set tRow.CredType = $Select(pCreds: "creds", 1: "env")
    Set tRow.EnvVarName = $Select(pCreds: "", 1: "OCUPILOT_PROBE_LOCAL_KEY")
    Set tRow.CredentialName = $Select(pCreds: "OcuPilotProbeNoSuchCredentialEntry", 1: "")
    Set tRow.MaxTokens = 4000
    Set tRow.MaxIterationsPerTurn = pMaxIterations
    Set tRow.SystemPromptOverride = pOverride
    Set tRow.Enabled = 1
    Set tRow.ConnectionVerified = 1
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tRow), "a probe definition is created")
    Set tId = tRow.%Id()
    Set tRow = ""
    Quit tId
}

/// <p>Reserve a turn for <var>pUser</var> (the suite's own account by default) on
/// <var>pDefinitionId</var>, and remember its key for teardown.</p>
Method Reserve(pDefinitionId As %String, pUser As %String = {$Username}) As %String
{
    Set tSC = ##class(OcuPilot.Kernel.State.Turn).GuardedReserve(pUser, pDefinitionId, ..#JOBLOST, $ClassMethod(..#LOOP, "LimitsClass"), .tKey, .tBusy, .tSweep)
    Do $$$AssertStatusOK(tSC, "the turn is reserved")
    Do $$$AssertEquals(tBusy, 0, "and the slot was free")
    If tKey '= "" Set ..PreparedKeys(tKey) = ""
    Quit tKey
}

/// <p>Begin reserved turn <var>pKey</var>, run the loop, and finish the turn with the outcome.
/// <var>pReadOnly</var> defaults to the instance's current enforced read-only, and
/// <var>pStartedOffset</var> moves the start that many seconds into the past.</p>
Method Run(pKey As %String, pDefinitionId As %String, Output pOutcome, pUser As %String = {$Username}, pReadOnly As %String = "", pStartedOffset As %Integer = 0)
{
    Set tLimits = $ClassMethod(..#LOOP, "LimitsClass")
    If pReadOnly = "" {
        Do ##class(OcuPilot.Kernel.State.Switch).Resolve(.tSwitches)
        Set pReadOnly = ''$Get(tSwitches("enforcedReadOnly"))
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedBegin(pKey, pUser, tLimits, .tBegun, .tStarted), "the turn begins")
    Do $$$AssertEquals(tBegun, 1, "in this process")
    Set tSC = $ClassMethod(..#LOOP, "Run", pKey, pUser, pDefinitionId, "what is on this screen", pReadOnly, ##class(OcuPilot.Api.Router).#ADMINRESOURCES, tStarted - pStartedOffset, .pOutcome)
    Do $$$AssertStatusOK(tSC, "the loop returns")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedFinish(pKey, pUser, pOutcome("state"), pOutcome("code"), pOutcome("limit"), pOutcome("reply"), pOutcome("errorSeq"), tLimits), "and the turn is finished")
}

/// <p>A provider reply body: <var>pStop</var> <code>end_turn</code> with <var>pText</var>, or
/// <code>tool_use</code> asking for <var>pTools</var> tools, reporting <var>pTokens</var> input
/// tokens and none out.</p>
ClassMethod Reply(pStop As %String, pText As %String = "", pTools As %Integer = 0, pTokens As %Integer = 0) As %String
{
    Set tBody = {"content": [], "usage": {"output_tokens": 0}}
    Do tBody.%Set("stop_reason", pStop, "string")
    Do tBody.usage.%Set("input_tokens", pTokens, "number")
    If pText '= "" Do tBody.content.%Push({"type": "text", "text": (pText)})
    For tI = 1:1:pTools {
        Do tBody.content.%Push({"type": "tool_use", "id": ("toolu_" _ tI), "name": ("probe.tool" _ tI), "input": {}})
    }
    Quit tBody.%ToJSON()
}

/// <p>A reply ends the turn after one call, carrying the built-in system prompt when the
/// definition has no override (DW-333), the message, and one model step.</p>
Method TestAReplyCompletesTheTurnWithTheBuiltInPrompt()
{
    Set tId = ..Definition()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..Reply("end_turn", "hello"))
    Set tKey = ..Reserve(tId)
    Do ..Run(tKey, tId, .tOutcome)
    Do $$$AssertEquals(tOutcome("state"), "completed", "the turn completes")
    Do $$$AssertEquals(tOutcome("reply"), "hello", "with the provider's text as its reply")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "after one provider call")
    Set tSent = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.ProviderStub).Recorded("body"))
    Do $$$AssertEquals(tSent.system, ##class(OcuPilot.Kernel.Agent.Prompt).Builtin(), "the call carried the built-in system prompt")
    Do $$$AssertEquals(tSent.messages.%Get(0).content, "what is on this screen", "and the message")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedView(tKey, $Username, .tFound, .tView), "the progress reads")
    Do $$$AssertEquals(tView.steps.%Size(), 1, "one step was recorded")
    Do $$$AssertEquals(tView.steps.%Get(0).kind _ "/" _ tView.steps.%Get(0).status, "model/ok", "the model step, answered")
    Do $$$AssertEquals(tView.reply, "hello", "and the stored reply is the text")
}

/// <p>DW-333: a definition's override is sent in place of the built-in prompt, whole.</p>
/// <p>Mutation: join <code>pSystemPrompt</code> and the override in
/// <method>OcuPilot.Port.ProviderPort.SystemPromptFor</method> -- this goes red.</p>
Method TestAnOverrideReplacesTheBuiltInPromptWhole()
{
    Set tId = ..Definition(10, "Answer as the probe override.")
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..Reply("end_turn", "hello"))
    Set tKey = ..Reserve(tId)
    Do ..Run(tKey, tId, .tOutcome)
    Set tSent = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.ProviderStub).Recorded("body"))
    Do $$$AssertEquals(tSent.system, "Answer as the probe override.", "the override is the whole system prompt")
}

/// <p>The iteration cap completes the turn with the fallback reply after exactly that many calls:
/// the definition's own maximum when it is lower than the limit, the limit otherwise. A call to a
/// tool no registered tool is advertised as is answered <code>TOOL.UNKNOWN</code> and echoed back
/// on the next request.</p>
/// <p>Mutation: compare the cap with <code>&gt;</code> in <method>OcuPilot.Kernel.Agent.Loop.Run</method>
/// -- the one-call leg goes red, making a second call.</p>
Method TestTheIterationCapCompletesWithTheFallbackReply()
{
    Set tId = ..Definition(1)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..Reply("tool_use", "", 1))
    Set tKey = ..Reserve(tId)
    Do ..Run(tKey, tId, .tOutcome)
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "the definition's cap of one allows one call")
    Do $$$AssertEquals(tOutcome("state") _ "|" _ tOutcome("limit"), "completed|iterations", "and completes at the iteration limit")
    Do $$$AssertTrue(tOutcome("reply") [ "limit on steps after 1 tool call", "with the fallback reply: " _ tOutcome("reply"))
    Do $$$AssertTrue(tOutcome("reply") [ "probe.tool1: TOOL.UNKNOWN", "naming the tool and its outcome")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).Field(tKey, "LimitHit"), "iterations", "and the row records the limit")
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedView(tKey, $Username, .tFound, .tView)
    Do $$$AssertEquals(tView.limit, "iterations", "and the progress names it")

    Do ##class(OcuPilot.Test.ProviderStub).Reset()
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedDelete(tKey)
    Do ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
    Set tId = ..Definition(5)
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..Reply("tool_use", "", 1))
    Set tKey = ..Reserve(tId)
    Do ..Run(tKey, tId, .tOutcome)
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 2, "the narrowed limit of two caps a definition allowing five")
    Do $$$AssertEquals(tOutcome("state") _ "|" _ tOutcome("limit"), "completed|iterations", "and completes at the iteration limit")
    Set tSecond = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.ProviderStub).Recorded("body", 2))
    Do $$$AssertEquals(tSecond.messages.%Size(), 3, "the second request carries the echo and the results")
    Do $$$AssertEquals(tSecond.messages.%Get(1).content.%Get(0).type, "tool_use", "the assistant's tool call, verbatim")
    Set tResult = tSecond.messages.%Get(2).content.%Get(0)
    Do $$$AssertEquals(tResult.type _ "|" _ tResult."tool_use_id" _ "|" _ tResult."is_error", "tool_result|toolu_1|1", "one error result per call")
    Do $$$AssertEquals(tResult.content, "{""code"":""TOOL.UNKNOWN""}", "with the unknown tool's content")
}

/// <p>A stop request and a sign-out each end the turn at the first boundary with no provider
/// call.</p>
Method TestStopAndSignOutEndTheTurnBeforeACall()
{
    Set tId = ..Definition()
    Set tKey = ..Reserve(tId)
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedRequestStop(tKey, $Username, .tFound), "a stop is requested")
    Do ..Run(tKey, tId, .tOutcome)
    Do $$$AssertEquals(tOutcome("state") _ "|" _ tOutcome("code"), "stopped|TURN.STOPPED", "the turn stops")

    Set tKey = ..Reserve(tId)
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedAbandonForUser($Username, .tCount), "the owner signs out")
    Do ..Run(tKey, tId, .tOutcome)
    Do $$$AssertEquals(tOutcome("state") _ "|" _ tOutcome("code"), "abandoned|TURN.ABANDONED.SIGNOUT", "the turn is abandoned for the sign-out")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "and neither turn called the provider")
}

/// <p>The kill switch stops the turn with the code the verdict answers, and read-only that differs
/// from the snapshot abandons it.</p>
/// <p>Mutation: remove the read-only comparison from
/// <method>OcuPilot.Kernel.Agent.Loop.Boundary</method> -- the second leg goes red.</p>
Method TestTheSwitchesEndTheTurnBeforeACall()
{
    Set tId = ..Definition()
    Do $ClassMethod(..#LOOP, "ForceKillSwitch", "AGENT.KILLSWITCH.USER")
    Set tKey = ..Reserve(tId)
    Do ..Run(tKey, tId, .tOutcome)
    Do $$$AssertEquals(tOutcome("state") _ "|" _ tOutcome("code"), "stopped|AGENT.KILLSWITCH.USER", "the kill switch stops the turn with its own code")
    Do $ClassMethod(..#LOOP, "Reset")

    Do ##class(OcuPilot.Kernel.State.Switch).Resolve(.tSwitches)
    Set tKey = ..Reserve(tId)
    Do ..Run(tKey, tId, .tOutcome, , ''$Get(tSwitches("enforcedReadOnly")) = 0)
    Do $$$AssertEquals(tOutcome("state") _ "|" _ tOutcome("code"), "abandoned|TURN.ABANDONED.READONLY", "a read-only snapshot that no longer holds abandons the turn")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "and neither turn called the provider")
}

/// <p>Switches that cannot be read fail the turn at the boundary, with no provider call, rather than
/// reading as switched off.</p>
/// <p>Mutation: in <method>OcuPilot.Kernel.Agent.Loop.Boundary</method>, go on past a failed
/// restraint read -- this goes red, the turn completing.</p>
Method TestUnreadableSwitchesFailTheTurnBeforeACall()
{
    Set tId = ..Definition()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..Reply("end_turn", "hello"))
    Do $ClassMethod(..#LOOP, "ForceRestraintError")
    Set tKey = ..Reserve(tId)
    Do ..Run(tKey, tId, .tOutcome, , 0)
    Do $$$AssertEquals(tOutcome("state") _ "|" _ tOutcome("code"), "failed|TURN.UNAVAILABLE", "the turn fails at the boundary")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "with no provider call")
}

/// <p>A user no account holds holds no resource, so the grants check abandons the turn.</p>
/// <p>Mutation: remove the grants check -- this goes red, the turn completing.</p>
Method TestAUserNoAccountHoldsIsAbandonedForPrivilege()
{
    Set tId = ..Definition()
    Set tUser = "OcuPilotProbeTurnNoSuchAccount"
    Set tKey = ..Reserve(tId, tUser)
    Do ..Run(tKey, tId, .tOutcome, tUser)
    Do $$$AssertEquals(tOutcome("state") _ "|" _ tOutcome("code"), "abandoned|TURN.ABANDONED.PRIVILEGE", "the turn is abandoned for privilege")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "with no provider call")
}

/// <p>A lapsed lease and an elapsed wall clock abandon the turn at the next boundary.</p>
/// <p>Mutation: remove the lease comparison -- the first leg goes red.</p>
Method TestTheLeaseAndTheWallClockAbandonTheTurn()
{
    Set tId = ..Definition()
    Set tLimits = $ClassMethod(..#LOOP, "LimitsClass")
    Set tKey = ..Reserve(tId)
    Set ^OcuPilotTurnSignal(tKey, "renewed") = ##class(OcuPilot.Kernel.State.Turn).NowSeconds() - $Parameter(tLimits, "LEASESECONDS")
    Do ..Run(tKey, tId, .tOutcome)
    Do $$$AssertEquals(tOutcome("state") _ "|" _ tOutcome("code"), "abandoned|TURN.ABANDONED.LEASE", "a lease not renewed for the lease period abandons the turn")

    Set tKey = ..Reserve(tId)
    Do ..Run(tKey, tId, .tOutcome, , , $Parameter(tLimits, "WALLCLOCKSECONDS"))
    Do $$$AssertEquals(tOutcome("state") _ "|" _ tOutcome("code"), "abandoned|TURN.LIMIT.DURATION", "a turn at its wall-clock limit is abandoned")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 0, "and neither turn called the provider")
}

/// <p>The token spend is checked at the boundary after the call that reached it, and the error
/// names the last step written.</p>
Method TestTheTokenLimitAbandonsAtTheNextBoundary()
{
    Set tId = ..Definition()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..Reply("tool_use", "", 1, 3))
    Set tKey = ..Reserve(tId)
    Do ..Run(tKey, tId, .tOutcome)
    Do $$$AssertEquals(tOutcome("state") _ "|" _ tOutcome("code"), "abandoned|TURN.LIMIT.TOKENS", "the turn is abandoned for tokens")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProviderStub).Calls(), 1, "after the one call that spent them")
    Do $$$AssertEquals(tOutcome("errorSeq"), 2, "naming the tool step the turn stopped after")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).Field(tKey, "InputTokens"), 3, "and the spend is on the row")
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedView(tKey, $Username, .tFound, .tView)
    Do $$$AssertEquals(tView.tokens.input _ "|" _ tView.tokens.output, "3|0", "and in the progress, input and output apart")
}

/// <p>Provider faults fail the turn naming the model step, and only
/// <code>PROVIDER.CREDENTIAL</code> disables the definition.</p>
Method TestProviderFaultsFailTheTurnNamingTheModelStep()
{
    For tLeg = "store", "credential", "refused" {
        Do $ClassMethod(..#PORT, "Reset")
        Do $ClassMethod(..#PORT, "SetSslState", "present")
        Do ##class(OcuPilot.Test.SecretProbe).Forget()
        Do ##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining)
        Set tId = ..Definition(10, "", tLeg = "store")
        If tLeg = "store" Do $ClassMethod(..#PORT, "SetSecretClass", "OcuPilot.Test.SecretRaisingRung")
        If tLeg = "refused" {
            Do $ClassMethod(..#PORT, "SetSecretClass", "OcuPilot.Test.SecretProbe")
            Do ##class(OcuPilot.Test.SecretProbe).SetValue(..#PROBEKEY)
            Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(400, "{""type"":""error"",""error"":{""type"":""invalid_request_error"",""message"":""no""}}")
        }
        Set tKey = ..Reserve(tId)
        Do ..Run(tKey, tId, .tOutcome)
        Set tExpected = $Case(tLeg, "store": "PROVIDER.CREDENTIALSTORE", "credential": "PROVIDER.CREDENTIAL", : "PROVIDER.REFUSED")
        Do $$$AssertEquals(tOutcome("state") _ "|" _ tOutcome("code"), "failed|" _ tExpected, tLeg _ ": the turn fails with the fault's code")
        Do $$$AssertEquals(tOutcome("errorSeq"), 1, tLeg _ ": naming the model step")
        Do ##class(OcuPilot.Kernel.State.Turn).GuardedView(tKey, $Username, .tFound, .tView)
        Do $$$AssertEquals(tView.error.seq _ "|" _ tView.error.code, "1|" _ tExpected, tLeg _ ": and the progress error says so")
        Do $$$AssertEquals(tView.steps.%Get(0).status _ "|" _ tView.steps.%Get(0).code, "error|" _ tExpected, tLeg _ ": on the step itself")
        Do ##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(tId, .tRow)
        Do $$$AssertEquals(tRow.Enabled, $Select(tLeg = "credential": 0, 1: 1), tLeg _ ": the definition is disabled only for an unresolved credential")
        Set tRow = ""
    }
}

/// <p>Past the step cap, steps are counted rather than stored, and a field over its cap is cut and
/// marked.</p>
Method TestCapsCountDroppedStepsAndCutFields()
{
    Set tId = ..Definition()
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..Reply("tool_use", "a reply text longer than sixteen", 3))
    Do ##class(OcuPilot.Test.ProviderStub).QueueAnswer(200, ..Reply("end_turn", "the final reply, longer than sixteen"))
    Set tKey = ..Reserve(tId)
    Do ..Run(tKey, tId, .tOutcome)
    Do $$$AssertEquals(tOutcome("state"), "completed", "the turn completes")
    Do ##class(OcuPilot.Kernel.State.Turn).GuardedView(tKey, $Username, .tFound, .tView)
    Do $$$AssertEquals(tView.steps.%Size(), 2, "two steps are stored")
    Do $$$AssertEquals(tView.stepsDropped, 3, "and the other three are counted")
    Set tFirst = tView.steps.%Get(0)
    Do $$$AssertEquals(tFirst.text, "a reply text lon", "a text is cut at its cap")
    Do $$$AssertEquals($Length(tFirst.summary), 8, "and a summary at its")
    Do $$$AssertEquals(tFirst.truncated, 1, "and the step is marked truncated")
    Do $$$AssertEquals(tView.reply, "the final reply,", "and the reply is cut at the text cap")
}

}
