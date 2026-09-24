/// <p>Story 10.4's reasoning echo, observed on the requests the turn loop actually makes: a reply
/// carrying Anthropic reasoning blocks is sent back as the next request's assistant turn, same
/// size, same order, each block unchanged, while a reply without them keeps the echo the loop
/// always built; and a Gemini <code>functionCall</code> part's <code>thoughtSignature</code> rides
/// the replayed call byte for byte (DW-1591), with no key written where the reply carried none.</p>
/// <p>Driven through <class>OcuPilot.Test.TurnLoopProbe</class> and the shipped dispatcher, on
/// <class>OcuPilot.Test.ProviderStub</class> for the canonical family and on
/// <class>OcuPilot.Test.GeminiStub</class> (through <class>OcuPilot.Test.CatalogProbeShipped</class>)
/// for Gemini. <b>Live-safe</b>: it spawns nothing and opens no socket; it writes probe agent
/// definitions and turn rows in OcuPilot's own database and removes every one after each
/// method.</p>
Class OcuPilot.Test.AnthropicThinking Extends %UnitTest.TestCase
{

Parameter LOOP = "OcuPilot.Test.TurnLoopProbe";

Parameter PORT = "OcuPilot.Test.ProviderPortProbe";

Parameter STUB = "OcuPilot.Test.ProviderStub";

Parameter PROBEKEY = "probe-local-abcdefghijklmnop";

/// <p>A signature carrying the three base64 characters a careless re-encoding would change.</p>
Parameter SIGNATURE = "EqQBCkYIBxgCKkB+pr0be/Sig+nat/ure==";

/// <p>A tool no registry holds, so the call is answered <code>TOOL.UNKNOWN</code> and the turn
/// carries on to its second request.</p>
Parameter TOOLNAME = "probe_nosuch_read";

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
        Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).StepCount(tKey), 0, "nor any step")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).SlotOwner($Username), "", "no turn slot is left held")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.AgentFixture).RemoveProbeDefinitions(.tRemaining), "the probe definitions are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives")
    Quit $$$OK
}

/// <p>Create an enabled probe definition on <var>pProvider</var>, reserve, begin and run one turn
/// as the suite's own account, finish it, and answer its key with the outcome in
/// <var>pOutcome</var>. <var>pEndpoint</var> <code>""</code> takes the row's own endpoint.</p>
Method RunTurn(Output pOutcome, pProvider As %String = "probe-local", pModel As %String = "probe-local-model-1", pEndpoint As %String = "https://api.anthropic.com/v1/messages", pEnvVarName As %String = "OCUPILOT_PROBE_LOCAL_KEY") As %String
{
    Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
    Set tRow.Name = $Parameter("OcuPilot.Test.AgentFixture", "PROBEPREFIX") _ "Thinking" _ $Increment(^||OcuPilotAnthropicThinking)
    Set tRow.Provider = pProvider
    Set tRow.Model = pModel
    Set tRow.EndpointUrl = pEndpoint
    Set tRow.CredType = "env"
    Set tRow.EnvVarName = pEnvVarName
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
    Set tReadOnly = ''$Get(tSwitches("enforcedReadOnly"))
    Set tSC = $ClassMethod(..#LOOP, "Run", tKey, $Username, tId, "what is on this instance", tReadOnly, ##class(OcuPilot.Api.Router).#ADMINRESOURCES, tStarted, .pOutcome)
    Do $$$AssertStatusOK(tSC, "the loop returns")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedFinish(tKey, $Username, pOutcome("state"), pOutcome("code"), pOutcome("limit"), pOutcome("reply"), pOutcome("errorSeq"), tLimits), "and the turn is finished")
    Quit tKey
}

/// <p>A Messages reply body whose <code>content</code> is <var>pContent</var>.</p>
ClassMethod Reply(pContent As %DynamicArray, pStopReason As %String = "tool_use") As %String
{
    Set tBody = {"usage": {"input_tokens": 0, "output_tokens": 0}}
    Do tBody.%Set("content", pContent)
    Do tBody.%Set("stop_reason", pStopReason, "string")
    Quit tBody.%ToJSON()
}

/// <p>The body the stub recorded on call <var>pCall</var>, parsed, or <code>""</code>.</p>
ClassMethod Sent(pCall As %Integer) As %DynamicObject
{
    Set tSent = ""
    Try {
        Set tText = $ClassMethod(..#STUB, "Recorded", "body", pCall)
        If tText = "" Quit
        Set tSent = ##class(%DynamicAbstractObject).%FromJSON($ZConvert(tText, "I", "UTF8"))
    } Catch ex {
        Set tSent = ""
    }
    Quit tSent
}

/// <p>AC4 -- a reply carrying <code>thinking</code> and <code>redacted_thinking</code> blocks
/// beside its text and a tool call: the next request's assistant message is that content array,
/// the same size and in the same order, and each block's JSON and every member value are the
/// served block's own. Observed on the recorded request through the port.</p>
Method TestReasoningBlocksReturnUnchangedInTheNextRequest()
{
    Set tServed = []
    Set tThinking = {"type": "thinking", "thinking": ""}
    Do tThinking.%Set("signature", ..#SIGNATURE, "string")
    Do tServed.%Push(tThinking)
    Do tServed.%Push({"type": "redacted_thinking", "data": "RWQ+cmVkYWN0ZWQ/YmxvY2s="})
    Do tServed.%Push({"type": "text", "text": "looking"})
    Set tUse = {"type": "tool_use", "id": "toolu_1", "input": {}}
    Do tUse.%Set("name", ..#TOOLNAME, "string")
    Do tServed.%Push(tUse)

    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply(tServed))
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply([{"type": "text", "text": "done"}], "end_turn"))
    Set tKey = ..RunTurn(.tOutcome)
    Do $$$AssertEquals(tOutcome("state") _ "|" _ tOutcome("reply"), "completed|done", "the turn completes after answering the call")
    Do $$$AssertEquals($ClassMethod(..#STUB, "Calls"), 2, "in two provider calls")

    Set tSent = ..Sent(2)
    Do $$$AssertTrue($IsObject(tSent) && $IsObject(tSent.messages), "the second request was recorded")
    If '$IsObject(tSent) || '$IsObject(tSent.messages) Quit
    Set tEcho = tSent.messages.%Get(1)
    Do $$$AssertEquals(tEcho.role, "assistant", "the second message is the assistant turn")
    Do $$$AssertTrue($IsObject(tEcho.content) && tEcho.content.%IsA("%Library.DynamicArray"), "carried as blocks")
    If '$IsObject(tEcho.content) Quit
    Do $$$AssertEquals(tEcho.content.%Size(), tServed.%Size(), "as many blocks as the reply served: " _ tEcho.content.%ToJSON())
    For tI = 0:1:tServed.%Size() - 1 {
        Set tWas = tServed.%Get(tI)
        Set tNow = tEcho.content.%Get(tI)
        Do $$$AssertTrue($IsObject(tNow), "block " _ tI _ " is present")
        If '$IsObject(tNow) Continue
        Do $$$AssertEquals(tNow.%ToJSON(), tWas.%ToJSON(), "block " _ tI _ " is the served block, in its place")
        Set tMembers = tWas.%GetIterator()
        While tMembers.%GetNext(.tMember, .tValue) {
            If $IsObject(tValue) {
                Do $$$AssertEquals(tNow.%Get(tMember).%ToJSON(), tValue.%ToJSON(), "block " _ tI _ " member " _ tMember)
                Continue
            }
            Do $$$AssertEquals(tNow.%Get(tMember), tValue, "block " _ tI _ " member " _ tMember)
        }
    }
    Do $$$AssertEquals(tEcho.content.%Get(0).signature, ..#SIGNATURE, "and the signature is byte for byte the one served")
}

/// <p>A reply with no reasoning block keeps the echo the loop always built: the text block, then
/// the tool-use blocks.</p>
Method TestAReplyWithoutReasoningKeepsTheRebuiltEcho()
{
    Set tUse = {"type": "tool_use", "id": "toolu_1", "input": {}}
    Do tUse.%Set("name", ..#TOOLNAME, "string")
    Set tServed = [{"type": "text", "text": "looking"}]
    Do tServed.%Push(tUse)
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply(tServed))
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, ..Reply([{"type": "text", "text": "done"}], "end_turn"))
    Set tKey = ..RunTurn(.tOutcome)
    Do $$$AssertEquals(tOutcome("state"), "completed", "the turn completes")
    Set tSent = ..Sent(2)
    Do $$$AssertTrue($IsObject(tSent) && $IsObject(tSent.messages), "the second request was recorded")
    If '$IsObject(tSent) || '$IsObject(tSent.messages) Quit
    Set tExpected = [{"type": "text", "text": "looking"}]
    Do tExpected.%Push(tUse)
    Do $$$AssertEquals(tSent.messages.%Get(1).content.%ToJSON(), tExpected.%ToJSON(), "the echo is the text block, then the tool-use block")
}

/// <p>DW-1591 -- a Gemini <code>functionCall</code> part carrying a <code>thoughtSignature</code>:
/// when the loop answers the call, the next request's replayed <code>functionCall</code> part
/// carries that signature byte for byte.</p>
Method TestAGeminiThoughtSignatureRidesTheReplayedCall()
{
    Do $ClassMethod(..#PORT, "SetCatalogClass", "OcuPilot.Test.CatalogProbeShipped")
    Do ##class(OcuPilot.Kernel.Provider.Catalog).Row("gemini", .tRow)
    Do $$$AssertTrue($IsObject($Get(tRow)), "the shipped gemini row is readable")
    If '$IsObject($Get(tRow)) Quit
    Do ##class(OcuPilot.Test.CatalogProbeShipped).Row("gemini", .tStubRow)
    Do $$$AssertEquals(tStubRow.adapterClass, "OcuPilot.Test.GeminiStub", "the switched catalog answers the Gemini stub, so no socket is opened")
    If tStubRow.adapterClass '= "OcuPilot.Test.GeminiStub" Quit

    Set tPart = {}
    Do tPart.%Set("functionCall", {"args": {}})
    Do tPart.functionCall.%Set("name", ..#TOOLNAME, "string")
    Do tPart.%Set("thoughtSignature", ..#SIGNATURE, "string")
    Set tReply = {"candidates": [{"content": {"role": "model", "parts": []}, "finishReason": "STOP"}], "usageMetadata": {"promptTokenCount": 1, "candidatesTokenCount": 1}}
    Do tReply.candidates.%Get(0).content.parts.%Push(tPart)
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, tReply.%ToJSON())
    Do $ClassMethod(..#STUB, "QueueAnswer", 200, "{""candidates"":[{""content"":{""role"":""model"",""parts"":[{""text"":""done""}]},""finishReason"":""STOP""}]}")
    Set tKey = ..RunTurn(.tOutcome, "gemini", tRow.defaultModel, "", tRow.defaultEnvVarName)
    Do $$$AssertEquals(tOutcome("state") _ "|" _ tOutcome("reply"), "completed|done", "the turn completes after answering the call")
    Do $$$AssertEquals($ClassMethod(..#STUB, "Calls"), 2, "in two provider calls")

    Set tSent = ..Sent(2)
    Do $$$AssertTrue($IsObject(tSent) && $IsObject(tSent.contents), "the second request was recorded in Gemini's shape")
    If '$IsObject(tSent) || '$IsObject(tSent.contents) Quit
    Set tModel = tSent.contents.%Get(1)
    Do $$$AssertEquals(tModel.role, "model", "the replayed turn is the model's")
    Set tReplayed = tModel.parts.%Get(0)
    Do $$$AssertEquals(tReplayed.functionCall.name, ..#TOOLNAME, "its first part replays the call")
    Do $$$AssertEquals(tReplayed.%GetTypeOf("thoughtSignature"), "string", "with a sibling thoughtSignature")
    Do $$$AssertEquals(tReplayed.thoughtSignature, ..#SIGNATURE, "byte for byte the one served")
}

/// <p>The Gemini translator round trip with and without a signature: a part's signature becomes
/// the canonical block's <code>thoughtSignature</code> member and is written back beside the
/// replayed call, and a part that carried none produces neither the member nor the key.</p>
Method TestTheSignatureRoundTripsAndIsNeverInvented()
{
    Set tMessages = "OcuPilot.Kernel.Provider.MessageAdapter"
    Set tBody = "{""candidates"":[{""content"":{""role"":""model"",""parts"":[{""functionCall"":{""name"":""" _ ..#TOOLNAME _ """,""args"":{}},""thoughtSignature"":""" _ ..#SIGNATURE _ """},{""functionCall"":{""name"":""" _ ..#TOOLNAME _ """,""args"":{}}}]},""finishReason"":""STOP""}]}"
    Set tResponse = ##class(OcuPilot.Kernel.Provider.Response).%New()
    Do $$$AssertStatusOK($ClassMethod(tMessages, "GeminiToCanonical", tBody, tResponse), "the reply reads")
    Set tBlocks = ##class(%DynamicAbstractObject).%FromJSON(tResponse.ToolCallsJson)
    Do $$$AssertEquals(tBlocks.%Get(0).thoughtSignature, ..#SIGNATURE, "the signed call's block carries the signature")
    Do $$$AssertEquals(tBlocks.%Get(1).%GetTypeOf("thoughtSignature"), "unassigned", "and the unsigned call's block carries no member")

    Kill tHistory
    Set tHistory = 1
    Set tHistory(1, "role") = "assistant"
    Set tHistory(1, "blocks") = tResponse.ToolCallsJson
    Do $$$AssertStatusOK($ClassMethod(tMessages, "CanonicalToGemini", .tHistory, "", .tContents, .tSystem), "the history translates back")
    Set tParts = tContents.%Get(0).parts
    Do $$$AssertEquals(tParts.%Get(0).thoughtSignature, ..#SIGNATURE, "the signed call is replayed with its signature")
    Do $$$AssertEquals(tParts.%Get(1).%GetTypeOf("thoughtSignature"), "unassigned", "and the unsigned one with no key written")
}

}
