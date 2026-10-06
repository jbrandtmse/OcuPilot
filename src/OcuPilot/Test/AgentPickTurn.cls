/// <p>Pins the agent definition a user picks on real turn jobs (Story 19.11, AD-24, AD-30, AD-42, AD-50)
/// against two armed <code>turnprobe</code> definitions: the first the default, the second on another
/// host. A turn of a user who picked the second goes to the second's endpoint under its model tag and
/// reports its egress, the context chip forecasts it, and another user's turns keep the default; a
/// conversation replays only the entries that ran with the turn's own definition; and the restraint still
/// binds a picked definition -- its read-only flag decides the screen context's <code>readOnly</code>, and
/// enforced read-only and the kill switch bind it as they bind the default.</p>
/// <p><b>What it needs from the environment:</b> both <parameter>ARMINGVARIABLE</parameter> and
/// <parameter>PROVIDERVARIABLE</parameter> reading <code>1</code>. It creates two probe principals with
/// <class>OcuPilot.Test.TurnWireFixture</class>, the two probe definitions and a stored pick, and runs
/// turn jobs; after each method no probe job, turn, slot, pick or stub node remains, and the principals
/// and definitions are removed in <method>OnAfterAllTests</method>.</p>
Class OcuPilot.Test.AgentPickTurn Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter FIXTURE = "OcuPilot.Test.TurnWireFixture";

/// <p>The two definitions' model tags, which the stub provider keys its script and its records by.</p>
Parameter TAGA = "agentpick-a";

Parameter TAGB = "agentpick-b";

Property PreparedPassword As %String;

Property PreparedPrior As %String;

Property PreparedA As %String;

Property PreparedB As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedPrior = ""
    Set ..PreparedA = ""
    Set ..PreparedB = ""
    Quit $$$OK
}

/// <p>Refuse unless both variables arm the instance; create both principals and the two definitions, the
/// first the default.</p>
Method OnBeforeAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AgentPickTurn creates IRIS users and roles and runs turn jobs against the turnprobe row, on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#PROVIDERVARIABLE _ " must both read 1, so nothing was created.")
    }
    Set ..PreparedPassword = $ClassMethod(..#FIXTURE, "NewPassword")
    For tUser = $Parameter(..#FIXTURE, "USERA"), $Parameter(..#FIXTURE, "USERB") {
        Set tSC = $ClassMethod(..#FIXTURE, "EnsurePrincipal", tUser, ..PreparedPassword, $ClassMethod(..#FIXTURE, "Resources", 1))
        If $$$ISERR(tSC) Quit
    }
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPrior = $ClassMethod(..#FIXTURE, "MarkedDefault")
    Set tSC = $ClassMethod(..#FIXTURE, "EnsureDefinition", ..#TAGA, .tIdA)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedA = tIdA
    Set tSC = $ClassMethod(..#FIXTURE, "EnsureLocalDefinition", ..#TAGB, .tIdB)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedB = tIdB
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PROVIDERVARIABLE) '= 1) Quit $$$OK
    Do ..ForgetPicks()
    Set tSC = $ClassMethod(..#FIXTURE, "RemoveDefinition", ..PreparedPrior)
    Set tLeft = $ClassMethod(..#FIXTURE, "RemovePrincipals")
    If tLeft '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AgentPickTurn teardown left:" _ tLeft)
    Quit tSC
}

Method OnBeforeOneTest() As %Status
{
    Do ..ForgetPicks()
    Do ##class(OcuPilot.Test.SwitchFixture).Reset(.tRemaining)
    Do ##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly(..PreparedA, 0)
    Do ##class(OcuPilot.Test.TurnProvider).Forget(..#TAGA)
    Do ##class(OcuPilot.Test.TurnProvider).Forget(..#TAGB)
    Do $ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAGA, ..#TAGB))
    Quit ##class(OcuPilot.Kernel.State.Agent).SetDefaultGuarded(..PreparedA)
}

Method OnAfterOneTest() As %Status
{
    Do ..ForgetPicks()
    Do ##class(OcuPilot.Test.SwitchFixture).Reset(.tRemaining)
    Do ##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly(..PreparedA, 0)
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Sweep", $ListBuild(..#TAGA, ..#TAGB)), "", "no probe job, turn, slot or stub node survives the method")
    Quit $$$OK
}

/// <p>Remove the probe users' picks.</p>
ClassMethod ForgetPicks()
{
    For tUser = $Parameter(..#FIXTURE, "USERA"), $Parameter(..#FIXTURE, "USERB") {
        Do ##class(OcuPilot.Kernel.State.Pref).GuardedRemove(tUser, ##class(OcuPilot.Kernel.State.Pref).#KINDSHELL, ##class(OcuPilot.Kernel.State.Pref).#SHELLAGENTDEFINITION)
    }
}

/// <p>One request as <var>pUser</var> over the API: the HTTP status and the parsed answer.</p>
Method Call(pMethod As %String, pPath As %String, pUser As %String, pBody, Output pStatus As %Integer, Output pAnswer)
{
    Set tJson = $Select($IsObject(pBody): $ZConvert(pBody.%ToJSON(), "O", "UTF8"), 1: pBody)
    Do $ClassMethod(..#FIXTURE, "Call", pMethod, pPath, pUser, ..PreparedPassword, tJson, .pStatus, .tText, .tHeaders)
    Set pAnswer = ""
    Try { Set pAnswer = ##class(%DynamicObject).%FromJSON(tText) } Catch { Set pAnswer = $Get(tText) }
}

/// <p>Store <var>pUser</var>'s pick of definition <var>pId</var> over the route.</p>
Method PickAs(pUser As %String, pId As %String) As %Integer
{
    Do ..Call("POST", "/account/preferences", pUser, {"kind": "shell", "action": "set", "name": "agentDefinition", "value": (pId)}, .tStatus, .tAnswer)
    Quit tStatus
}

/// <p>One turn of <var>pUser</var> carrying <var>pMessage</var> in conversation <var>pConversationId</var>
/// (a new one when <code>""</code>), with <var>pContext</var> when supplied, awaited: the turn's final
/// state; <var>pView</var> is its last progress answer and <var>pConversationId</var> the conversation
/// used. An answer other than 202 at the start is <code>"start " _ status</code>, with the envelope in
/// <var>pView</var>.</p>
Method TurnAs(pUser As %String, pMessage As %String, ByRef pConversationId As %String, pContext As %DynamicObject = "", Output pView) As %String
{
    If pConversationId = "" Set pConversationId = $ClassMethod(..#FIXTURE, "StartConversation", pUser, ..PreparedPassword, .tStatus, .tText)
    Do ..Call("POST", "/turn", pUser, $ClassMethod(..#FIXTURE, "StartBody", pMessage, pConversationId, pContext), .tStartStatus, .pView)
    If tStartStatus '= 202 Quit "start " _ tStartStatus
    Quit $ClassMethod(..#FIXTURE, "AwaitEnd", pView.turnId, pUser, ..PreparedPassword, 60, .pView)
}

/// <p>The screen-context payload call 1 of <var>pTag</var> recorded, or <code>""</code>.</p>
ClassMethod RecordedContext(pTag As %String) As %DynamicObject
{
    Set tMessages = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.TurnProvider).Recorded(pTag, 1, "messages"))
    If tMessages.%Size() < 3 Quit ""
    Set tBlock = tMessages.%Get(2).content.%Get(0)
    Set tBody = ##class(OcuPilot.Test.TurnWireFixture).Unwrapped(tBlock.content, .tWrapped)
    If 'tWrapped Quit ""
    Quit ##class(%DynamicAbstractObject).%FromJSON(tBody)
}

/// <p>AC1, AC2: a turn of a user who picked the second definition goes to its endpoint under its model tag
/// and reports its host; the context chip forecasts it; before the pick, and for another user, the
/// default's endpoint answers; and the default marker has not moved.</p>
/// <p>Mutation (Rule 19): resolve <code>ResolveDefault</code> in <method>OcuPilot.Api.Turn.HandleStart</method>
/// -- the picked turn goes to the default's endpoint and this goes red.</p>
Method TestAPickedDefinitionRunsTheTurnAndReportsItsEgress()
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tOther = $Parameter(..#FIXTURE, "USERB")
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAGA, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("from A"))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAGB, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("from B"))

    Set tConv = ""
    Set tState = ..TurnAs(tUser, "before the pick", .tConv, , .tView)
    Do $$$AssertEquals(tState, "completed", "a turn before the pick completes")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAGA) _ " " _ ##class(OcuPilot.Test.TurnProvider).Calls(..#TAGB), "1 0", "and goes to the default definition")
    Do $$$AssertTrue(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAGA, 1, "url") [ "192.0.2.10", "at its endpoint")
    Do $$$AssertEquals($Select($IsObject(tView) && $IsObject(tView.%Get("egress")): tView.egress.endpointHost, 1: ""), "192.0.2.10", "its egress line names that host")
    Do ..Call("GET", "/agent/context", tUser, "", .tStatus, .tContext)
    Do $$$AssertEquals($Select($IsObject(tContext): tContext.definition.id _ " " _ tContext.endpointHost, 1: tStatus), ..PreparedA _ " 192.0.2.10", "the context chip forecasts the default")

    Do $$$AssertEquals(..PickAs(tUser, ..PreparedB), 200, "the user picks the second definition")
    Do ..Call("GET", "/agent/context", tUser, "", .tStatus, .tContext)
    Do $$$AssertEquals($Select($IsObject(tContext): tContext.definition.id _ " " _ tContext.endpointHost, 1: tStatus), ..PreparedB _ " 10.0.0.5", "the chip now forecasts the pick")
    Set tConv = ""
    Set tState = ..TurnAs(tUser, "after the pick", .tConv, , .tView)
    Do $$$AssertEquals(tState, "completed", "a turn after the pick completes")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAGA) _ " " _ ##class(OcuPilot.Test.TurnProvider).Calls(..#TAGB), "1 1", "and goes to the picked definition")
    Do $$$AssertTrue(##class(OcuPilot.Test.TurnProvider).Recorded(..#TAGB, 1, "url") [ "10.0.0.5", "at its endpoint")
    Do $$$AssertEquals($Select($IsObject(tView) && $IsObject(tView.%Get("egress")): tView.egress.endpointHost, 1: ""), "10.0.0.5", "its egress line names the picked host")

    Set tOtherConv = ""
    Set tState = ..TurnAs(tOther, "another user", .tOtherConv, , .tOtherView)
    Do $$$AssertEquals(tState, "completed", "another user's turn completes")
    Do $$$AssertEquals(##class(OcuPilot.Test.TurnProvider).Calls(..#TAGA) _ " " _ ##class(OcuPilot.Test.TurnProvider).Calls(..#TAGB), "2 1", "and keeps the default")
    Do ##class(OcuPilot.Kernel.State.Agent).ResolveDefault(.tDefault)
    Do $$$AssertEquals(tDefault, ..PreparedA, "the default marker is where it was")
}

/// <p>AC5: a turn in a conversation whose earlier turns ran under the other definition replays none of
/// them to the picked definition's provider, while the same conversation under one definition does.</p>
/// <p>Mutation (Rule 19): remove the definition filter from
/// <method>OcuPilot.Kernel.State.Convo.HistoryMessages</method> -- the picked turn's request carries the
/// earlier turns and this goes red.</p>
Method TestAConversationDoesNotReplayAnotherDefinitionsTurns()
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAGA, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("reply one"))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAGA, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("reply two"))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAGB, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("reply three"))
    Set tConv = ""
    Do $$$AssertEquals(..TurnAs(tUser, "MESSAGEONE", .tConv, , .tView), "completed", "the first turn completes under the default")
    Do $$$AssertEquals(..TurnAs(tUser, "MESSAGETWO", .tConv, , .tView), "completed", "the second does too")
    Set tSecond = ##class(OcuPilot.Test.TurnProvider).Recorded(..#TAGA, 2, "messages")
    Do $$$AssertTrue((tSecond [ "MESSAGEONE") && (tSecond [ "reply one"), "and replays the first, under one definition")
    Do $$$AssertEquals(..PickAs(tUser, ..PreparedB), 200, "the user picks the second definition")
    Do $$$AssertEquals(..TurnAs(tUser, "MESSAGETHREE", .tConv, , .tView), "completed", "a third turn in the same conversation completes")
    Set tThird = ##class(OcuPilot.Test.TurnProvider).Recorded(..#TAGB, 1, "messages")
    Do $$$AssertTrue((tThird [ "MESSAGETHREE") && (tThird '[ "MESSAGEONE") && (tThird '[ "MESSAGETWO") && (tThird '[ "reply one") && (tThird '[ "reply two"), "and its request replays none of the others: " _ $Extract(tThird, 1, 300))
}

/// <p>AC4: the picked definition's own flag decides the verdict a turn computes -- the screen context's
/// <code>readOnly</code> -- and enforced read-only and the kill switch still bind it. With a read-only
/// default, a turn without a pick reads <code>readOnly</code> true and a turn with the read/write pick
/// false; enforced read-only makes it true again; the kill switch refuses the turn as it does without a
/// pick.</p>
/// <p>Mutation (Rule 19): compute <code>Verdict</code> with <code>ResolveDefault</code>'s id in
/// <method>OcuPilot.Api.Turn.HandleStart</method> -- the pick leg reads true and this goes red.</p>
Method TestTheRestraintStillBindsAPickedDefinition()
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tContext = {"route": "logs/audit", "namespace": "HSCUSTOM"}
    Do $$$AssertStatusOK(##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly(..PreparedA, 1), "the default is read-only")
    For tCase = 1:1:3 {
        Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAGA, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("ok"))
        Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAGB, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("ok"))
    }
    Set tConv = ""
    Do $$$AssertEquals(..TurnAs(tUser, "no pick", .tConv, tContext, .tView), "completed", "a turn without a pick completes")
    Set tPayload = ..RecordedContext(..#TAGA)
    Do $$$AssertEquals($Select($IsObject(tPayload): tPayload.readOnly, 1: ""), 1, "and its context reads readOnly: the default is read-only")

    Do $$$AssertEquals(..PickAs(tUser, ..PreparedB), 200, "the user picks the read/write definition")
    Set tConv = ""
    Do $$$AssertEquals(..TurnAs(tUser, "picked", .tConv, tContext, .tView), "completed", "a turn with the pick completes")
    Set tPayload = ..RecordedContext(..#TAGB)
    Do $$$AssertEquals($Select($IsObject(tPayload): tPayload.readOnly, 1: ""), 0, "and its context does not read readOnly")

    Do ##class(OcuPilot.Test.TurnProvider).Forget(..#TAGB)
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAGB, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("ok"))
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(0, "", 1), "enforced read-only is turned on")
    Set tConv = ""
    Do $$$AssertEquals(..TurnAs(tUser, "enforced", .tConv, tContext, .tView), "completed", "a turn completes under it")
    Set tPayload = ..RecordedContext(..#TAGB)
    Do $$$AssertEquals($Select($IsObject(tPayload): tPayload.readOnly, 1: ""), 1, "and its context reads readOnly again, whatever is picked")

    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(1, "off for this test", 0), "the kill switch is turned on")
    Set tConv = ""
    Set tState = ..TurnAs(tUser, "killed", .tConv, tContext, .tView)
    Do $$$AssertEquals(tState _ " " _ $Select($IsObject(tView): tView.%Get("code"), 1: ""), "start 403 " _ ##class(OcuPilot.Api.Error).#AGENTKILLSWITCHGLOBAL, "the turn is refused as it is without a pick")
}

}
