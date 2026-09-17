/// <p>The two conversation routes and <code>/turn/:id/stop</code> over HTTP (Story 4.5, AD-7,
/// AD-9, AD-33, AD-41), plus the tool-step fields DW-451 added and the history a second turn on
/// the same conversation replays -- driven the way <class>OcuPilot.Test.TurnWire</class> drives
/// the three original turn routes: two principals, a real <code>turnprobe</code> row, real turn
/// jobs.</p>
/// <p><b>It spawns turn jobs, so <method>OnBeforeAllTests</method> refuses to run unless both
/// <parameter>ARMINGVARIABLE</parameter> and <parameter>PROVIDERVARIABLE</parameter> read 1.</b>
/// Only <file>scripts/ci-throwaway.sh</file> sets them.</p>
Class OcuPilot.Test.TurnConversation Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter FIXTURE = "OcuPilot.Test.TurnWireFixture";

Parameter TAG = "turnconvo-probe";

Parameter STOPROUTE = "/turn/:id/stop";

Parameter CONVERSATIONROUTE = "/conversation/:id";

Property PreparedPassword As %String;

Property PreparedDefinitionId As %String;

Property PreparedPrior As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedDefinitionId = ""
    Set ..PreparedPrior = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TurnConversation creates IRIS users and runs turn jobs, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    If $System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TurnConversation runs turn jobs against the turnprobe provider row, on a throwaway container only. " _ ..#PROVIDERVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Set ..PreparedPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Set tSC = ##class(OcuPilot.Test.TurnWireFixture).EnsurePrincipal($Parameter(..#FIXTURE, "USERA"), ..PreparedPassword, $ClassMethod(..#FIXTURE, "Resources"))
    If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Test.TurnWireFixture).EnsurePrincipal($Parameter(..#FIXTURE, "USERB"), ..PreparedPassword, $ClassMethod(..#FIXTURE, "Resources"))
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPrior = $ClassMethod(..#FIXTURE, "MarkedDefault")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsureDefinition", ..#TAG, .tId)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedDefinitionId = tId
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1) Quit $$$OK
    Set tSC = $ClassMethod(..#FIXTURE, "RemoveDefinition", ..PreparedPrior)
    Set tLeft = ##class(OcuPilot.Test.TurnWireFixture).RemovePrincipals()
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TurnConversation teardown left:" _ tLeft)
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG))
    Quit $ClassMethod(..#FIXTURE, "SetTag", ..PreparedDefinitionId, ..#TAG)
}

Method OnAfterOneTest() As %Status
{
    Quit $$$AssertEquals($ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAG)), "", "no probe job, turn, slot or stub node survives the method")
}

/// <p>One request, as <var>pUser</var>, to <var>pPath</var> under the API.</p>
Method Call(pMethod As %String, pPath As %String, pUser As %String, pBody As %String, Output pStatus As %Integer, Output pText As %String, Output pHeaders) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, "/api/ocupilot" _ pPath, pUser, ..PreparedPassword, .pStatus, .pText, .pHeaders, pBody, "application/json")
}

/// <p>Create a conversation as <var>pUser</var>; its id, or <code>""</code>.</p>
Method NewConversation(pUser As %String) As %String
{
    Quit $ClassMethod(..#FIXTURE, "StartConversation", pUser, ..PreparedPassword, .tStatus, .tText)
}

/// <p>Start a turn for <var>pUser</var> on <var>pConversationId</var>; the turn id, or
/// <code>""</code>.</p>
Method Start(pUser As %String, pMessage As %String, pConversationId As %String, Output pStatus As %Integer, Output pText As %String) As %String
{
    Do ..Call("POST", "/turn", pUser, $ClassMethod(..#FIXTURE, "StartBody", pMessage, pConversationId), .pStatus, .pText, .tHeaders)
    If pStatus '= 202 Quit ""
    Quit ##class(%DynamicObject).%FromJSON(pText).turnId
}

Method AwaitEnd(pTurnId As %String, pUser As %String, pSeconds As %Integer, Output pView) As %String
{
    Quit $ClassMethod(..#FIXTURE, "AwaitEnd", pTurnId, pUser, ..PreparedPassword, pSeconds, .pView)
}

Method StopPath(pTurnId As %String) As %String
{
    Quit $Replace(..#STOPROUTE, ":id", pTurnId)
}

Method ConversationPath(pConversationId As %String) As %String
{
    Quit $Replace(..#CONVERSATIONROUTE, ":id", pConversationId)
}

/// <p>A create answers 201 with an opaque id; a read of it before any turn answers an empty
/// <code>turns</code> array; an unknown or foreign id is 404 <code>TURN.CONVERSATION.NOTFOUND</code>,
/// the same body either way.</p>
Method TestCreateAndReadAnEmptyConversation()
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tOther = $Parameter(..#FIXTURE, "USERB")
    Do ..Call("POST", "/conversation", tUser, "", .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 201, "create answers 201: " _ tText)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Set tId = ##class(%DynamicObject).%FromJSON(tText).conversationId
    Do $$$AssertTrue($Match(tId, "^[0-9a-f]{32}$"), "with an opaque id")

    Do ..Call("GET", ..ConversationPath(tId), tUser, "", .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the owner reads it back")
    Set tView = ##class(%DynamicObject).%FromJSON(tText)
    Do $$$AssertEquals(tView.conversationId, tId, "naming the same id")
    Do $$$AssertEquals(tView.turns.%Size(), 0, "with no turns yet")

    Do ..Call("GET", ..ConversationPath(tId), tOther, "", .tStatus, .tOthers, .tHeaders)
    Do $$$AssertEquals(tStatus, 404, "another principal's read is not found")
    Do ..Call("GET", "/conversation/0123456789abcdef0123456789abcdef", tUser, "", .tStatus, .tUnknown, .tHeaders)
    Do $$$AssertEquals(tStatus, 404, "and neither is an unknown id")
    Do $$$AssertEquals(tOthers, tUnknown, "with the same body: " _ tOthers)
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tOthers).code, "TURN.CONVERSATION.NOTFOUND", "naming the code")
}

/// <p>A start with no <code>conversationId</code> is 422 <code>TURN.CONVERSATION.REQUIRED</code>;
/// one naming a conversation the caller does not own, or none at all, is 404
/// <code>TURN.CONVERSATION.NOTFOUND</code>. Neither reserves a turn.</p>
Method TestAStartRequiresAnOwnedConversation()
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tOther = $Parameter(..#FIXTURE, "USERB")
    Do ..Call("POST", "/turn", tUser, "{""message"":""hi""}", .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 422, "no conversationId is refused: " _ tText)
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tText)
    Do $$$AssertEquals(tAnswer.code, "TURN.CONVERSATION.REQUIRED", "by code")
    Do $$$AssertEquals(tAnswer.detail.violations.%Get(0).field, "conversationId", "on the conversationId field")

    Set tForeignConv = ..NewConversation(tOther)
    Do ..Call("POST", "/turn", tUser, "{""message"":""hi"",""conversationId"":""" _ tForeignConv _ """}", .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 404, "a conversation the caller does not own is not found")
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tText).code, "TURN.CONVERSATION.NOTFOUND", "by code")

    Do ..Call("POST", "/turn", tUser, "{""message"":""hi"",""conversationId"":""0123456789abcdef0123456789abcdef""}", .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 404, "an unknown conversation is the same 404")

    Do $$$AssertEquals(##class(OcuPilot.Test.TurnFixture).TurnCount(tUser), 0, "no turn was reserved by any of the three refusals")
}

/// <p>A completed turn's step carries the real tool's <code>target</code>, redacted
/// <code>arguments</code>, and rows-shaped <code>result</code>; the entry appended to the
/// conversation records the completed state and reply; a second turn on the same conversation
/// replays the first turn's message and reply in the provider's recorded messages, and nothing
/// else.</p>
/// <p>Mutation: drop the history injection in <method>OcuPilot.Kernel.Agent.Loop.Run</method> --
/// the second call's recorded messages carry only its own message, and this goes red.</p>
Method TestToolStepFieldsAndHistoryAcrossTwoTurns()
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tConvId = ..NewConversation(tUser)
    Do $$$AssertNotEquals(tConvId, "", "the conversation was created")

    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply("shell_namespaces_read"))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("first reply"))
    Set tId1 = ..Start(tUser, "read the namespaces", tConvId, .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the first start is accepted: " _ tText)
    Do $$$AssertEquals(..AwaitEnd(tId1, tUser, 30, .tView1), "completed", "the first turn completes")
    ; steps[0] is the model/provider call that answered with the tool_use block; the tool step
    ; itself is steps[1] -- the loop always records the provider call before the tool it asked for.
    Set tToolStep = tView1.steps.%Get(1)
    Do $$$AssertEquals(tToolStep.kind _ "|" _ tToolStep.status, "tool|ok", "the tool step is ok")
    Do $$$AssertNotEquals(tToolStep.arguments, "", "with a recorded (redacted) arguments string")
    ; shell.namespaces.read's own payload is {scope, namespaces} -- a shell read carries no rows --
    ; so its step's result is null. The rows-shaped result is OcuPilot.Test.TurnTools'
    ; TestAToolStepRunsThenCarriesItsTargetAndRows.
    Do $$$AssertEquals(tToolStep.%GetTypeOf("result"), "null", "and no result -- a shell read carries no rows")
    Do $$$AssertEquals(tView1.reply, "first reply", "the turn's reply")

    Do ..Call("GET", ..ConversationPath(tConvId), tUser, "", .tStatus, .tConvText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the conversation reads back")
    Set tConvView = ##class(%DynamicObject).%FromJSON(tConvText)
    Do $$$AssertEquals(tConvView.turns.%Size(), 1, "with one entry appended")
    Set tEntry1 = tConvView.turns.%Get(0)
    Do $$$AssertEquals(tEntry1.state _ "|" _ tEntry1.reply _ "|" _ tEntry1.message, "completed|first reply|read the namespaces", "the entry matches the finished turn")

    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("second reply"))
    Set tId2 = ..Start(tUser, "second message", tConvId, .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the second start is accepted")
    Do $$$AssertEquals(..AwaitEnd(tId2, tUser, 30, .tView2), "completed", "the second turn completes")
    ; Calls are numbered across the whole tag, not per turn (Test/TurnProvider.cls "What it
    ; records per call"): turn 1 made two (the tool_use round, then "first reply"), so turn 2's
    ; own request -- the one carrying the replayed history -- is call 3, not 2.
    Set tSentMessages = ##class(%DynamicArray).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 3, "messages"))
    Do $$$AssertEquals(tSentMessages.%Get(0).role _ "|" _ tSentMessages.%Get(0).content, "user|read the namespaces", "the first turn's message is replayed")
    Do $$$AssertEquals(tSentMessages.%Get(1).role _ "|" _ tSentMessages.%Get(1).content, "assistant|first reply", "then its reply")
    Do $$$AssertEquals(tSentMessages.%Get(2).role _ "|" _ tSentMessages.%Get(2).content, "user|second message", "then the second turn's own message")
    Do $$$AssertEquals(tSentMessages.%Size(), 3, "and nothing else -- no tool results, no screen context")
}

/// <p>A failed tool step (an unknown tool name) carries <code>code</code> and its published
/// <code>reason</code>, with no <code>result</code>.</p>
Method TestAFailedToolStepCarriesItsReason()
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tConvId = ..NewConversation(tUser)
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply("not_a_real_tool"))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("done"))
    Set tId = ..Start(tUser, "call a missing tool", tConvId, .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the start is accepted")
    Do $$$AssertEquals(..AwaitEnd(tId, tUser, 30, .tView), "completed", "the turn completes")
    ; steps[0] is the model/provider call that answered with the tool_use block naming the
    ; unknown tool; the failed tool step itself is steps[1].
    Set tStep = tView.steps.%Get(1)
    Do $$$AssertEquals(tStep.status _ "|" _ tStep.code, "error|TOOL.UNKNOWN", "the step failed as unknown")
    Do $$$AssertNotEquals(tStep.reason, "", "with a published reason")
    Do $$$AssertEquals(tStep.%GetTypeOf("result"), "null", "and no result")
}

/// <p><method>OcuPilot.Kernel.Agent.Dispatch.TargetOf</method>'s priority order (<code>id</code>,
/// else <code>entity</code>, else <code>route</code>) over a real tool call, driven end to end
/// through the wire rather than asserted against the class method directly. <code>shell.namespaces.read</code>
/// declares no input properties, so a call naming all three is refused as
/// <code>TOOL.ARGUMENTS</code> -- but <var>target</var> is extracted from the model's raw input
/// before that refusal runs (<method>Dispatch.AnswerOne</method>: present whether the call
/// succeeded or failed), which is what this asserts.</p>
Method TestToolTargetPrefersIdOverEntityOverRoute()
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tConvId = ..NewConversation(tUser)
    Set tInput = {}
    Do tInput.%Set("id", "widget-1", "string")
    Do tInput.%Set("entity", "widget-2", "string")
    Do tInput.%Set("route", "widget-3", "string")
    Set tCall = {}
    Do tCall.%Set("id", "toolu_target")
    Do tCall.%Set("name", "shell.namespaces.read")
    Do tCall.%Set("input", tInput)
    Set tCalls = []
    Do tCalls.%Push(tCall)
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply(tCalls))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("done"))
    Set tId = ..Start(tUser, "target priority check", tConvId, .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the start is accepted")
    Do $$$AssertEquals(..AwaitEnd(tId, tUser, 30, .tView), "completed", "the turn completes")
    Set tStep = tView.steps.%Get(1)
    Do $$$AssertEquals(tStep.target, "widget-1", "id wins over entity and route")
}

/// <p>A credential-shaped argument key is redacted before it is stored -- the integration point
/// between <method>OcuPilot.Kernel.Agent.Dispatch.RedactedArguments</method> and
/// <method>OcuPilot.Kernel.Audit.Log.Redact</method>, unverified until now even though
/// <code>Log.Redact</code> is separately unit-tested.</p>
Method TestCredentialShapedArgumentIsRedacted()
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tConvId = ..NewConversation(tUser)
    Set tInput = {}
    Do tInput.%Set("apiKey", "sk-do-not-log-this-value", "string")
    Set tCall = {}
    Do tCall.%Set("id", "toolu_redact")
    Do tCall.%Set("name", "shell.namespaces.read")
    Do tCall.%Set("input", tInput)
    Set tCalls = []
    Do tCalls.%Push(tCall)
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply(tCalls))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("done"))
    Set tId = ..Start(tUser, "redaction check", tConvId, .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the start is accepted")
    Do $$$AssertEquals(..AwaitEnd(tId, tUser, 30, .tView), "completed", "the turn completes")
    Set tStep = tView.steps.%Get(1)
    Do $$$AssertTrue(tStep.arguments [ "[redacted]", "the stored arguments carry the redaction mark: " _ tStep.arguments)
    Do $$$AssertTrue('(tStep.arguments [ "sk-do-not-log-this-value"), "and never the raw credential value")
}

/// <p>Arguments over <parameter>OcuPilot.Kernel.Agent.Limits.SUMMARYMAXLENGTH</parameter> are
/// capped, and the step's <code>truncated</code> comes from
/// <method>OcuPilot.Kernel.Agent.Dispatch.RedactedArguments</method>'s own cap answer -- not from
/// a second re-cap at <method>OcuPilot.Kernel.State.Step.GuardedAppend</method>, which now trusts
/// the caller and stores the already-capped text verbatim.</p>
Method TestOverLongArgumentsAreCappedAndMarkedTruncated()
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tConvId = ..NewConversation(tUser)
    Set tInput = {}
    Do tInput.%Set("note", $Justify("", 1200), "string")
    Set tCall = {}
    Do tCall.%Set("id", "toolu_overlong")
    Do tCall.%Set("name", "shell.namespaces.read")
    Do tCall.%Set("input", tInput)
    Set tCalls = []
    Do tCalls.%Push(tCall)
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply(tCalls))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("done"))
    Set tId = ..Start(tUser, "over-long arguments check", tConvId, .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the start is accepted")
    Do $$$AssertEquals(..AwaitEnd(tId, tUser, 30, .tView), "completed", "the turn completes")
    Set tStep = tView.steps.%Get(1)
    Do $$$AssertEquals(tStep.truncated, 1, "the cut is recorded as truncated")
    Do $$$AssertTrue($Length(tStep.arguments) <= $Parameter("OcuPilot.Kernel.Agent.Limits", "SUMMARYMAXLENGTH"), "and the stored text is actually capped: " _ $Length(tStep.arguments))
    Do $$$AssertEquals($Extract(tStep.arguments, *), $Char(8230), "ending in U+2026")
}

/// <p><code>POST /turn/:id/stop</code> answers <code>stopRequested</code> true for a running
/// turn, records a <code>stopped</code> step naming what it was about to run, then answers false
/// for the same, now-terminal, turn; an unknown or foreign id is 404 <code>TURN.NOTFOUND</code>.</p>
Method TestStopRequestsAStopAndRecordsAStoppedStep()
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tOther = $Parameter(..#FIXTURE, "USERB")
    Set tConvId = ..NewConversation(tUser)
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 4, ##class(OcuPilot.Test.TurnProvider).ToolUseReply("shell_namespaces_read"))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("done"))
    Set tId = ..Start(tUser, "stop me", tConvId, .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, "the start is accepted")
    Do $$$AssertTrue($ClassMethod(..#FIXTURE, "AwaitCall", ..#TAG, 1, 15), "the provider call began")

    Do ..Call("POST", ..StopPath(tId), tOther, "", .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 404, "another principal cannot stop it")

    Do ..Call("POST", ..StopPath(tId), tUser, "", .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the owner's stop answers: " _ tText)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tText).stopRequested, 1, "requested true")

    Do $$$AssertEquals(..AwaitEnd(tId, tUser, 30, .tView), "stopped", "the turn stops")
    Set tStoppedStep = tView.steps.%Get(tView.steps.%Size() - 1)
    Do $$$AssertEquals(tStoppedStep.status, "stopped", "the last step is stopped")
    Do $$$AssertEquals(tStoppedStep.kind _ "|" _ tStoppedStep.name, "tool|shell.namespaces.read", "naming what it was about to run")

    Do ..Call("GET", ..ConversationPath(tConvId), tUser, "", .tStatus, .tConvText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the conversation reads back: " _ tConvText)
    Do $$$AssertEquals($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", 1, "as JSON")
    Set tEntry = ##class(%DynamicObject).%FromJSON(tConvText).turns.%Get(0)
    Do $$$AssertEquals(tEntry.state _ "|" _ tEntry.%GetTypeOf("reply") _ "|" _ tEntry.error.code, "stopped|null|TURN.STOPPED", "the stopped turn's entry was appended, with no reply")
    Do $$$AssertNotEquals(tEntry.error.reason, "", "its error carries the published reason")
    Do $$$AssertEquals(tEntry.steps.%Get(tEntry.steps.%Size() - 1).status, "stopped", "and its steps end with the stopped step")

    Do ..Call("POST", ..StopPath(tId), tUser, "", .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "stopping an already-terminal turn still answers 200")
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tText).stopRequested, 0, "requested false, not an error")

    Do ..Call("POST", ..StopPath("0123456789abcdef0123456789abcdef"), tUser, "", .tStatus, .tText, .tHeaders)
    Do $$$AssertEquals(tStatus, 404, "an unknown turn id is not found")
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tText).code, "TURN.NOTFOUND", "by code")
}

/// <p>Hold conversation <var>pKey</var> exclusively for <var>pSeconds</var>, from a job, marking
/// <code>^OcuPilotTestConvoHeld(pKey)</code> while it holds it.</p>
ClassMethod HoldConversation(pKey As %String, pSeconds As %Integer)
{
    Set tConvo = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate(pKey, "", 5, .tStatus, .tConflict)
    Set ^OcuPilotTestConvoHeld(pKey) = $IsObject(tConvo)
    Hang pSeconds
    Set tConvo = ""
    Kill ^OcuPilotTestConvoHeld(pKey)
}

/// <p>A conversation another process holds is refused within the caller's own timeout, as a lock
/// conflict rather than any other failure (<method>OcuPilot.Kernel.State.Convo.LoadOrCreate</method>).</p>
/// <p>Mutation: <method>OcuPilot.Kernel.State.Base.IsLockConflict</method> answers 0 -> this goes
/// red.</p>
Method TestAConversationHeldElsewhereTimesOutAsALockConflict()
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tConvId = ..NewConversation(tUser)
    Do $$$AssertNotEquals(tConvId, "", "the conversation was created")
    Kill ^OcuPilotTestConvoHeld(tConvId)
    Job ##class(OcuPilot.Test.TurnConversation).HoldConversation(tConvId, 6)::5
    Do $$$AssertTrue($Test, "the holding job started")
    Set tDeadline = $ZHorolog + 10
    While '$Get(^OcuPilotTestConvoHeld(tConvId)) && ($ZHorolog < tDeadline) {
        Hang 0.1
    }
    Do $$$AssertEquals($Get(^OcuPilotTestConvoHeld(tConvId)), 1, "another process holds the conversation")
    Set tStart = $ZHorolog
    Set tConvo = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate(tConvId, tUser, 1, .tStatus, .tConflict)
    Set tWaited = $ZHorolog - tStart
    Do $$$AssertTrue('$IsObject(tConvo), "no OREF is answered")
    Do $$$AssertStatusNotOK(tStatus, "with an error status")
    Do $$$AssertEquals(tConflict, 1, "classified as a lock conflict: " _ $System.Status.GetErrorText(tStatus))
    Do $$$AssertTrue(tWaited < 4, "after the caller's own timeout, not the holder's hold: " _ tWaited)
    Set tConvo = ""
    Set tDeadline = $ZHorolog + 15
    While $Data(^OcuPilotTestConvoHeld(tConvId)) && ($ZHorolog < tDeadline) {
        Hang 0.25
    }
    Do $$$AssertEquals($Data(^OcuPilotTestConvoHeld(tConvId)), 0, "the holder released it")
}

}
