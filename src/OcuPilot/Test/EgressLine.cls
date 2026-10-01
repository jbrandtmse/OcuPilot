/// <p>Story 16.15's data-egress fact over HTTP (AD-42, AD-33, AD-37): each turn records where its
/// screen data went, on the progress poll and on its conversation entry, from the same computation
/// <code>GET /agent/context</code> answers with. Driven by real armed turns against two
/// <code>turnprobe</code> definitions of <class>OcuPilot.Test.TurnWireFixture</class>: A at a
/// public test-net host and B at a private one. Also pins
/// <method>OcuPilot.Kernel.Agent.Loop.KeepEgress</method>,
/// <method>OcuPilot.Kernel.State.Turn.EgressObject</method> and
/// <method>OcuPilot.Port.ProviderPort.EgressOf</method>'s marked-local answer and the port's TLS
/// refusal directly.</p>
/// <p><b>It creates an IRIS user and a role and spawns turn jobs, so
/// <method>OnBeforeAllTests</method> refuses to run unless both</b>
/// <parameter>ARMINGVARIABLE</parameter> <b>and</b> <parameter>PROVIDERVARIABLE</parameter>
/// <b>read 1.</b> It creates only <code>OcuPilotProbeAgent</code> definitions, moves the default
/// marker between them and restores the one the instance held, and clears the instance's outbound
/// settings for each method, putting them back afterwards.</p>
Class OcuPilot.Test.EgressLine Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter FIXTURE = "OcuPilot.Test.TurnWireFixture";

/// <p>The stub script tags of definitions A and B.</p>
Parameter TAGA = "egressline-a";

Parameter TAGB = "egressline-b";

/// <p>A proxy host (RFC 5737 TEST-NET-1) that classifies public. Never connected to.</p>
Parameter PUBLICPROXY = "192.0.2.99";

/// <p>An unmarked loopback endpoint, which the address policy refuses at the call
/// (<code>PROVIDER.EGRESS</code>). Never connected to.</p>
Parameter LOOPBACKENDPOINT = "https://127.0.0.1/v1/messages";

/// <p>A loopback proxy host, which the address policy refuses at the call once the endpoint has
/// passed (<code>PROVIDER.EGRESS</code>). Never connected to.</p>
Parameter LOOPBACKPROXY = "127.0.0.1";

/// <p>A TLS configuration name the instance does not hold, which the port refuses at the call
/// (<code>PROVIDER.TLS</code>) once the endpoint and proxy have passed.</p>
Parameter ABSENTTLS = "OcuPilotProbeAbsentTls";

Property PreparedPassword As %String;

Property PreparedA As %String;

Property PreparedB As %String;

Property PreparedPrior As %String;

/// Whether the instance held an outbound-settings row before the method ran. Prefix must not begin
/// with "Test" -- see .claude/rules/objectscript-testing.md
Property DisplacedEgress As %Boolean [ InitialExpression = 0 ];

/// The settings that row resolved to, restored after the method.
Property DisplacedEgressValues [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedA = ""
    Set ..PreparedB = ""
    Set ..PreparedPrior = ""
    Set ..DisplacedEgress = 0
    Kill ..DisplacedEgressValues
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.EgressLine creates an IRIS user and a role and runs turn jobs, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    If $System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.EgressLine runs turn jobs against the turnprobe provider row, on a throwaway container only. " _ ..#PROVIDERVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Set ..PreparedPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", $Parameter(..#FIXTURE, "USERA"), ..PreparedPassword, $ClassMethod(..#FIXTURE, "Resources"))
    If $$$ISERR(tSC) Quit tSC
    ; EnsureDefinition inserts rather than upserts, so a definition an interrupted run left goes first.
    Set tSC = $ClassMethod(..#FIXTURE, "RemoveDefinition", "")
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPrior = $ClassMethod(..#FIXTURE, "MarkedDefault")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsureDefinition", ..#TAGA, .tA)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedA = tA
    Set tSC = $ClassMethod(..#FIXTURE, "EnsureLocalDefinition", ..#TAGB, .tB)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedB = tB
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1) Quit $$$OK
    Set tSC = $ClassMethod(..#FIXTURE, "RemoveDefinition", ..PreparedPrior)
    Set tLeft = $ClassMethod(..#FIXTURE, "RemovePrincipals")
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.EgressLine teardown left:" _ tLeft)
    Quit tSC
}

/// <p>A is the default and not marked local, B points at its private endpoint, both answer their
/// own tag, the probe principal shares context, and the instance's outbound settings are recorded
/// and cleared.</p>
Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAGA, ..#TAGB))
    Set tSC = $ClassMethod(..#FIXTURE, "SetMarkedLocal", ..PreparedA, 0)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#FIXTURE, "SetTag", ..PreparedA, ..#TAGA)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#FIXTURE, "SetEndpoint", ..PreparedB, $Parameter(..#FIXTURE, "LOCALENDPOINTURL"))
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#FIXTURE, "SetTag", ..PreparedB, ..#TAGB)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#FIXTURE, "MarkDefault", ..PreparedA)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Kernel.State.Sharing).GuardedSetForUser($Parameter(..#FIXTURE, "USERA"), 1)
    If $$$ISERR(tSC) Quit tSC
    Set ..DisplacedEgress = 0
    Kill ..DisplacedEgressValues
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 ID FROM OcuPilot_Kernel_State.Egress")
    If $IsObject(tRS), tRS.%Next() {
        Set tSC = ##class(OcuPilot.Kernel.State.Egress).Resolve(.tResolved)
        If $$$ISERR(tSC) Quit tSC
        Merge ..DisplacedEgressValues = tResolved
        Set ..DisplacedEgress = 1
    }
    Quit ##class(OcuPilot.Kernel.State.Egress).DeleteGuarded()
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAGA, ..#TAGB)), "", "no probe job, turn, slot or stub node survives the method")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Sharing).GuardedDeleteForUser($Parameter(..#FIXTURE, "USERA")), "the probe principal's sharing choice is removed")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Egress).DeleteGuarded(), "no outbound settings row this method wrote survives it")
    If ..DisplacedEgress {
        Merge tRestore = ..DisplacedEgressValues
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Egress).SetGuarded(.tRestore), "the instance's own outbound settings are restored")
        Set ..DisplacedEgress = 0
        Kill ..DisplacedEgressValues
    }
    Quit $$$OK
}

/// <p>One request as the probe principal.</p>
Method Call(pMethod As %String, pPath As %String, pBody As %String, Output pStatus As %Integer, Output pText As %String) As %Status
{
    Quit $ClassMethod(..#FIXTURE, "Call", pMethod, pPath, $Parameter(..#FIXTURE, "USERA"), ..PreparedPassword, pBody, .pStatus, .pText, .tHeaders)
}

/// <p><code>GET /agent/context</code>'s body, asserted readable.</p>
Method ContextRead(pLabel As %String) As %DynamicObject
{
    Do ..Call("GET", "/agent/context", "", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 200, pLabel _ ": the context status reads: " _ tText)
    If tStatus '= 200 Quit ""
    Quit ##class(%DynamicObject).%FromJSON(tText)
}

/// <p>A new conversation's id.</p>
Method Conversation() As %String
{
    Quit $ClassMethod(..#FIXTURE, "StartConversation", $Parameter(..#FIXTURE, "USERA"), ..PreparedPassword, .tStatus, .tText)
}

/// <p>Script one reply for <var>pTag</var> -- a text reply, or <var>pReply</var> answered with
/// <var>pHttpStatus</var> -- start a turn in conversation <var>pConvId</var> carrying one row of
/// <code>logs/audit</code> screen context, and wait for it to end. The final poll is
/// <var>pView</var>; the answer is its state.</p>
Method RunTurn(pTag As %String, pConvId As %String, pLabel As %String, Output pView As %DynamicObject, Output pTurnId As %String, pHttpStatus As %Integer = 200, pReply As %String = "") As %String
{
    Set pView = ""
    Set pTurnId = ""
    If pReply = "" Set pReply = ##class(OcuPilot.Test.TurnProvider).TextReply("ok")
    Do ##class(OcuPilot.Test.TurnProvider).Script(pTag, 0, pReply, pHttpStatus)
    Set tContext = {"route": "logs/audit", "namespace": "HSCUSTOM", "view": {"rows": [{"TimeStamp": "2026-09-17 00:00:01", "Description": "row 1"}]}}
    Do ..Call("POST", "/turn", $ClassMethod(..#FIXTURE, "StartBody", "where did it go", pConvId, tContext), .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 202, pLabel _ ": the start is accepted: " _ tText)
    If tStatus '= 202 Quit ""
    Set pTurnId = ##class(%DynamicObject).%FromJSON(tText).turnId
    Quit $ClassMethod(..#FIXTURE, "AwaitEnd", pTurnId, $Parameter(..#FIXTURE, "USERA"), ..PreparedPassword, 30, .pView)
}

/// <p>The turns <code>GET /conversation/:id</code> answers.</p>
Method ConversationTurns(pConvId As %String, pLabel As %String) As %DynamicArray
{
    Do ..Call("GET", "/conversation/" _ pConvId, "", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 200, pLabel _ ": the conversation reads: " _ tText)
    If tStatus '= 200 Quit []
    Quit ##class(%DynamicObject).%FromJSON(tText).turns
}

/// <p>Assert <var>pEgress</var> is an egress object naming <var>pContext</var>'s provider, host and
/// verdict, with <var>pContextSent</var>, each member typed.</p>
Method AssertEgress(pEgress, pContext As %DynamicObject, pContextSent As %Boolean, pLabel As %String)
{
    Do $$$AssertTrue($IsObject(pEgress), pLabel _ ": egress is an object")
    If '$IsObject(pEgress) || '$IsObject(pContext) Quit
    Do $$$AssertEquals(pEgress.%GetTypeOf("leavesInstance") _ "|" _ pEgress.%GetTypeOf("contextSent"), "boolean|boolean", pLabel _ ": its verdicts are JSON booleans")
    Do $$$AssertEquals(pEgress.provider, pContext.provider, pLabel _ ": the provider /agent/context names")
    Do $$$AssertEquals(pEgress.endpointHost, pContext.endpointHost, pLabel _ ": the host /agent/context names")
    Do $$$AssertEquals(pEgress.leavesInstance, pContext.leavesInstance, pLabel _ ": the verdict /agent/context answers")
    Do $$$AssertEquals(pEgress.contextSent, ''pContextSent, pLabel _ ": whether screen context was sent")
}

/// <p>Left: with A the default, the turn's egress on the poll and on its conversation entry is
/// <code>/agent/context</code>'s provider, host and verdict, the data having left.</p>
Method TestALeftTurnRecordsTheChipsDestination()
{
    Set tContext = ..ContextRead("left")
    If '$IsObject(tContext) Quit
    Do $$$AssertEquals(tContext.provider _ "|" _ tContext.endpointHost _ "|" _ tContext.leavesInstance, "turnprobe|192.0.2.10|1", "A is the default and its host leaves")
    Set tConvId = ..Conversation()
    Do $$$AssertEquals(..RunTurn(..#TAGA, tConvId, "left", .tView), "completed", "the turn completes")
    If '$IsObject(tView) Quit
    Do ..AssertEgress(tView.egress, tContext, 1, "left, on the poll")
    Set tTurns = ..ConversationTurns(tConvId, "left")
    Do $$$AssertEquals(tTurns.%Size(), 1, "one restored turn")
    If tTurns.%Size() = 1 Do ..AssertEgress(tTurns.%Get(0).egress, tContext, 1, "left, on the conversation entry")
}

/// <p>Stayed: with B, a private and unmarked host, the default, the chip and the turn both answer
/// that the data did not leave.</p>
Method TestAPrivateDefaultRecordsThatTheDataStayed()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "MarkDefault", ..PreparedB), "B is made the default")
    Set tContext = ..ContextRead("stayed")
    If '$IsObject(tContext) Quit
    Do $$$AssertEquals(tContext.endpointHost _ "|" _ tContext.%GetTypeOf("leavesInstance") _ "|" _ tContext.leavesInstance, "10.0.0.5|boolean|0", "the chip names B's private host and no egress")
    Set tConvId = ..Conversation()
    Do $$$AssertEquals(..RunTurn(..#TAGB, tConvId, "stayed", .tView), "completed", "the turn completes")
    If '$IsObject(tView) Quit
    Do ..AssertEgress(tView.egress, tContext, 1, "stayed, on the poll")
    Set tTurns = ..ConversationTurns(tConvId, "stayed")
    Do $$$AssertEquals(tTurns.%Size(), 1, "stayed: one restored turn")
    If tTurns.%Size() = 1 Do ..AssertEgress(tTurns.%Get(0).egress, tContext, 1, "stayed, on the conversation entry")
}

/// <p>Proxy: B behind a public proxy leaves, for the chip and the turn alike, because both are
/// <method>OcuPilot.Port.ProviderPort.EgressOf</method>'s answer over the same settings.</p>
Method TestAProxyMakesTheLineAndTheChipLeave()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "MarkDefault", ..PreparedB), "B is made the default")
    Set tStored("proxyServer") = ..#PUBLICPROXY
    Set tStored("proxyPort") = 3128
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Egress).SetGuarded(.tStored), "the public proxy is stored")
    Set tContext = ..ContextRead("proxy")
    If '$IsObject(tContext) Quit
    Do $$$AssertEquals(tContext.endpointHost _ "|" _ tContext.leavesInstance, "10.0.0.5|1", "the chip says B's call leaves through the proxy")
    Set tConvId = ..Conversation()
    Do $$$AssertEquals(..RunTurn(..#TAGB, tConvId, "proxy", .tView), "completed", "the turn completes")
    If '$IsObject(tView) Quit
    Do ..AssertEgress(tView.egress, tContext, 1, "proxy, on the poll")
    Set tTurns = ..ConversationTurns(tConvId, "proxy")
    Do $$$AssertEquals(tTurns.%Size(), 1, "proxy: one restored turn")
    If tTurns.%Size() = 1 Do ..AssertEgress(tTurns.%Get(0).egress, tContext, 1, "proxy, on the conversation entry")
}

/// <p>Sharing off: a turn started with context sharing off records that it sent no screen context,
/// and still names the provider and host its call went to.</p>
Method TestSharingOffRecordsThatNoContextWasSent()
{
    Do ..Call("PUT", "/agent/context", "{""share"":false}", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 200, "sharing is turned off: " _ tText)
    Set tContext = ..ContextRead("sharing off")
    If '$IsObject(tContext) Quit
    Set tConvId = ..Conversation()
    Do $$$AssertEquals(..RunTurn(..#TAGA, tConvId, "sharing off", .tView), "completed", "the turn completes")
    If '$IsObject(tView) Quit
    Do ..AssertEgress(tView.egress, tContext, 0, "sharing off, on the poll")
    Set tTurns = ..ConversationTurns(tConvId, "sharing off")
    Do $$$AssertEquals(tTurns.%Size(), 1, "sharing off: one restored turn")
    If tTurns.%Size() = 1 Do ..AssertEgress(tTurns.%Get(0).egress, tContext, 0, "sharing off, on the conversation entry")
}

/// <p>No call: a turn whose only call the address policy refused before dispatch records no egress,
/// on the poll or on its conversation entry.</p>
Method TestATurnWhoseCallWasRefusedRecordsNoEgress()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetEndpoint", ..PreparedB, ..#LOOPBACKENDPOINT), "B is pointed at an unmarked loopback endpoint")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "MarkDefault", ..PreparedB), "and made the default")
    Set tConvId = ..Conversation()
    Do $$$AssertEquals(..RunTurn(..#TAGB, tConvId, "no call", .tView), "failed", "the turn fails")
    If '$IsObject(tView) Quit
    Do $$$AssertEquals($Select($IsObject(tView.error): tView.error.code, 1: ""), "PROVIDER.EGRESS", "refused by the address policy")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAGB), 0, "and the provider was never called")
    Do $$$AssertEquals(tView.%GetTypeOf("egress"), "null", "the poll carries no egress")
    Set tTurns = ..ConversationTurns(tConvId, "no call")
    Do $$$AssertEquals(tTurns.%Size(), 1, "no call: one restored turn")
    If tTurns.%Size() = 1 Do $$$AssertEquals(tTurns.%Get(0).%GetTypeOf("egress"), "null", "nor does the conversation entry")
}

/// <p>Refused proxy: a turn whose call the address policy refused at its proxy, after the endpoint
/// passed, records no egress, on the poll or on its conversation entry.</p>
Method TestATurnWhoseProxyWasRefusedRecordsNoEgress()
{
    Set tStored("proxyServer") = ..#LOOPBACKPROXY
    Set tStored("proxyPort") = 3128
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Egress).SetGuarded(.tStored), "a loopback proxy is stored")
    Set tConvId = ..Conversation()
    Do $$$AssertEquals(..RunTurn(..#TAGA, tConvId, "proxy refused", .tView), "failed", "the turn fails")
    If '$IsObject(tView) Quit
    Do $$$AssertEquals($Select($IsObject(tView.error): tView.error.code, 1: ""), "PROVIDER.EGRESS", "refused by the address policy at the proxy")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAGA), 0, "and the provider was never called")
    Do $$$AssertEquals(tView.%GetTypeOf("egress"), "null", "the poll carries no egress")
    Set tTurns = ..ConversationTurns(tConvId, "proxy refused")
    Do $$$AssertEquals(tTurns.%Size(), 1, "proxy refused: one restored turn")
    If tTurns.%Size() = 1 Do $$$AssertEquals(tTurns.%Get(0).%GetTypeOf("egress"), "null", "nor does the conversation entry")
}

/// <p>Refused TLS: a call whose TLS configuration is absent is refused <code>PROVIDER.TLS</code>
/// before dispatch and answers no egress, while the same call under the instance's own
/// configuration is dispatched and answers one. Asked of the port in this process, because the
/// check reads the security database, which a turn's least-privileged owner cannot
/// (<method>OcuPilot.Port.ProviderPort.SslConfigurationMissing</method> then lets the call
/// proceed).</p>
Method TestACallRefusedForItsTlsConfigurationRecordsNoEgress()
{
    Set tPort = "OcuPilot.Port.ProviderPort"
    Set tMessages = 1
    Set tMessages(1, "role") = "user"
    Set tMessages(1, "content") = "where did it go"
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAGA, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("ok"))
    Do $ClassMethod(tPort, "Invoke", ..PreparedA, .tMessages, .tTools, "", .tResponse, .tHttpStatus, .tFault, "", "", .tEgress)
    Do $$$AssertTrue($IsObject(tEgress), "under the instance's own TLS configuration the call is dispatched and answers its egress")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAGA), 1, "and reaches the provider")
    Set tStored("sslConfiguration") = ..#ABSENTTLS
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Egress).SetGuarded(.tStored), "an absent TLS configuration is stored")
    Kill tEgress, tFault
    Do $ClassMethod(tPort, "Invoke", ..PreparedA, .tMessages, .tTools, "", .tResponse, .tHttpStatus, .tFault, "", "", .tEgress)
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.code, 1: ""), "PROVIDER.TLS", "the call is refused for the absent configuration")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAGA), 1, "before it reaches the provider")
    Do $$$AssertEquals($Get(tEgress), "", "and answers no egress")
}

/// <p>Provider refused: a turn whose dispatched call the provider refused still records where its
/// screen data went, on the poll and on its conversation entry.</p>
Method TestADispatchedCallThatFailedStillRecordsItsEgress()
{
    Set tContext = ..ContextRead("provider refused")
    If '$IsObject(tContext) Quit
    Set tConvId = ..Conversation()
    Do $$$AssertEquals(..RunTurn(..#TAGA, tConvId, "provider refused", .tView, , 401, "{""type"":""error"",""error"":{""message"":""invalid x-api-key""}}"), "failed", "the turn fails")
    If '$IsObject(tView) Quit
    Do $$$AssertEquals($Select($IsObject(tView.error): tView.error.code, 1: ""), "PROVIDER.REFUSED", "the provider refused the call")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAGA), 1, "after it was reached")
    Do ..AssertEgress(tView.egress, tContext, 1, "provider refused, on the poll")
    Set tTurns = ..ConversationTurns(tConvId, "provider refused")
    Do $$$AssertEquals(tTurns.%Size(), 1, "provider refused: one restored turn")
    If tTurns.%Size() = 1 Do ..AssertEgress(tTurns.%Get(0).egress, tContext, 1, "provider refused, on the conversation entry")
}

/// <p>Marked local: with A, at a public host, marked local and the default, the chip and the turn
/// both answer that the data did not leave.</p>
Method TestAMarkedLocalDefaultRecordsThatTheDataStayed()
{
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetMarkedLocal", ..PreparedA, 1), "A is marked local")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "MarkDefault", ..PreparedA), "and is the default again after that security-field edit")
    Set tContext = ..ContextRead("marked local")
    If '$IsObject(tContext) Quit
    Do $$$AssertEquals(tContext.endpointHost _ "|" _ tContext.%GetTypeOf("leavesInstance") _ "|" _ tContext.leavesInstance, "192.0.2.10|boolean|0", "the chip names A's public host and no egress")
    Set tConvId = ..Conversation()
    Do $$$AssertEquals(..RunTurn(..#TAGA, tConvId, "marked local", .tView), "completed", "the turn completes")
    If '$IsObject(tView) Quit
    Do ..AssertEgress(tView.egress, tContext, 1, "marked local, on the poll")
    Set tTurns = ..ConversationTurns(tConvId, "marked local")
    Do $$$AssertEquals(tTurns.%Size(), 1, "marked local: one restored turn")
    If tTurns.%Size() = 1 Do ..AssertEgress(tTurns.%Get(0).egress, tContext, 1, "marked local, on the conversation entry")
}

/// <p>Default moved: turn 1 runs on A, the default moves to B, turn 2 runs on B. The chip and turn 2
/// name B; turn 1 keeps A's fact on its own poll and on its conversation entry.</p>
Method TestMovingTheDefaultLeavesEachTurnItsOwnEgress()
{
    Set tBefore = ..ContextRead("before the move")
    If '$IsObject(tBefore) Quit
    Set tConvId = ..Conversation()
    Do $$$AssertEquals(..RunTurn(..#TAGA, tConvId, "turn 1", .tFirst, .tFirstId), "completed", "turn 1 completes")
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "MarkDefault", ..PreparedB), "the default moves to B")
    Set tAfter = ..ContextRead("after the move")
    If '$IsObject(tAfter) Quit
    Do $$$AssertEquals(tAfter.endpointHost _ "|" _ tAfter.leavesInstance, "10.0.0.5|0", "the chip follows the move")
    Do $$$AssertEquals(..RunTurn(..#TAGB, tConvId, "turn 2", .tSecond), "completed", "turn 2 completes")
    If '$IsObject(tSecond) Quit
    Do ..AssertEgress(tSecond.egress, tAfter, 1, "turn 2, on the poll")
    Set tFirstView = ""
    Do ..Call("GET", "/turn/" _ tFirstId _ "/progress", "", .tStatus, .tText)
    Do $$$AssertEquals(tStatus, 200, "turn 1 is polled after the move: " _ tText)
    If tStatus = 200 Set tFirstView = ##class(%DynamicObject).%FromJSON(tText)
    If $IsObject(tFirstView) Do ..AssertEgress(tFirstView.egress, tBefore, 1, "turn 1, polled after the move")
    Set tTurns = ..ConversationTurns(tConvId, "default moved")
    Do $$$AssertEquals(tTurns.%Size(), 2, "two restored turns")
    If tTurns.%Size() '= 2 Quit
    Do ..AssertEgress(tTurns.%Get(0).egress, tBefore, 1, "turn 1, on its conversation entry")
    Do ..AssertEgress(tTurns.%Get(1).egress, tAfter, 1, "turn 2, on its conversation entry")
}

/// <p>The two-call rule: the first dispatched call's fact is kept, a later call that leaves replaces
/// a kept fact that stayed, a later call that stays never replaces one that left, and a refused
/// call changes nothing.</p>
Method TestKeepEgressKeepsTheFactThatLeavesInEitherOrder()
{
    Set tStay = {"provider": "turnprobe", "endpointHost": "10.0.0.5", "leavesInstance": false}
    Set tOther = {"provider": "turnprobe", "endpointHost": "10.0.0.6", "leavesInstance": false}
    Set tLeave = {"provider": "turnprobe", "endpointHost": "192.0.2.10", "leavesInstance": true}
    Set tLoop = "OcuPilot.Kernel.Agent.Loop"
    Set tFirst = $ClassMethod(tLoop, "KeepEgress", "", tStay, 1)
    Do $$$AssertEquals(tFirst, "{""provider"":""turnprobe"",""endpointHost"":""10.0.0.5"",""leavesInstance"":false,""contextSent"":true}", "the first dispatched call's fact is kept, with contextSent")
    Do $$$AssertEquals($ClassMethod(tLoop, "KeepEgress", tFirst, tOther, 1), tFirst, "a later call that stays does not replace it")
    Do $$$AssertEquals($ClassMethod(tLoop, "KeepEgress", tFirst, "", 1), tFirst, "nor does a call refused before dispatch")
    Set tLeft = $ClassMethod(tLoop, "KeepEgress", tFirst, tLeave, 1)
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tLeft).endpointHost, "192.0.2.10", "a later call that leaves replaces a kept fact that stayed")
    Set tKeptLeft = $ClassMethod(tLoop, "KeepEgress", "", tLeave, 0)
    Do $$$AssertEquals($ClassMethod(tLoop, "KeepEgress", tKeptLeft, tStay, 0), tKeptLeft, "and a kept fact that left is never replaced by one that stayed")
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(tKeptLeft).contextSent, 0, "contextSent records a turn that sent no screen context")
    Do $$$AssertEquals($ClassMethod(tLoop, "KeepEgress", "", "", 1), "", "a turn that dispatched nothing keeps nothing")
}

/// <p><method>OcuPilot.Kernel.State.Turn.EgressObject</method> answers <code>""</code> for empty,
/// unparseable or wrong-shape text, and the typed object, in wire order, for a stored fact.</p>
Method TestEgressObjectRefusesEveryMalformedText()
{
    Set tTurn = "OcuPilot.Kernel.State.Turn"
    For tBad = "", $Char(0), "not json", "[]", "{""provider"":1,""endpointHost"":""h"",""leavesInstance"":true,""contextSent"":true}", "{""provider"":""p"",""endpointHost"":""h"",""leavesInstance"":""true"",""contextSent"":true}", "{""provider"":""p"",""endpointHost"":""h"",""contextSent"":true}", "{""provider"":""p"",""endpointHost"":""h"",""leavesInstance"":false}", "{""provider"":""p"",""leavesInstance"":true,""contextSent"":true}", "{""provider"":""p"",""endpointHost"":1,""leavesInstance"":true,""contextSent"":true}" {
        Do $$$AssertEquals($ClassMethod(tTurn, "EgressObject", tBad), "", "refused: " _ tBad)
    }
    Set tGood = $ClassMethod(tTurn, "EgressObject", "{""contextSent"":false,""leavesInstance"":true,""endpointHost"":""h"",""provider"":""p"",""extra"":1}")
    Do $$$AssertTrue($IsObject(tGood), "a stored fact reads back")
    If '$IsObject(tGood) Quit
    Do $$$AssertEquals(tGood.%ToJSON(), "{""provider"":""p"",""endpointHost"":""h"",""leavesInstance"":true,""contextSent"":false}", "as exactly the four wire members, in order")
}

/// <p><method>OcuPilot.Port.ProviderPort.EgressOf</method> answers false for a marked-local call to a
/// public host handed a public proxy, which it bypasses, and true for an unmarked private host
/// behind the same proxy.</p>
Method TestEgressOfAnswersStayedForAMarkedLocalCallBehindAPublicProxy()
{
    Set tSettings("proxyServer") = ..#PUBLICPROXY
    Set tLocal = ##class(OcuPilot.Port.ProviderPort).EgressOf("compatible", "https://192.0.2.10/v1", 1, .tSettings, .tProxy)
    Do $$$AssertEquals(tLocal.%ToJSON(), "{""provider"":""compatible"",""endpointHost"":""192.0.2.10"",""leavesInstance"":false}", "a marked-local call does not leave, though its host is public")
    Do $$$AssertEquals(tProxy, "", "and reports no proxy, which it does not go through")
    Set tUnmarked = ##class(OcuPilot.Port.ProviderPort).EgressOf("turnprobe", "https://10.0.0.5/v1/messages", 0, .tSettings, .tProxy)
    Do $$$AssertEquals(tUnmarked.leavesInstance _ "|" _ tProxy, "1|" _ ..#PUBLICPROXY, "while an unmarked private host behind the same proxy leaves through it")
}

}
