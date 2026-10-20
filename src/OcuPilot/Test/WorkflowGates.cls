/// <p>The gates a guided-workflow write still passes (Story 20.12, AD-6, AD-10, AD-22, AD-30, AD-40, AD-66): a proposal
/// a workflow turn minted is refused at its Confirm -- 403 <code>GOVERNANCE.DISABLED</code> when its key was disabled
/// after the mint, <code>AGENT.READONLY.ENFORCED</code> under enforced read-only, <code>AGENT.KILLSWITCH.GLOBAL</code>
/// under the kill switch, and <code>PROHIBITED.CURRENTUSER</code> when a <code>newproject</code> proposal deletes the
/// turn's own principal -- with the class text and the principal unchanged; and with the key disabled before the call,
/// the call answers <code>GOVERNANCE.DISABLED</code> and mints nothing. The policy and the switches are put back after
/// each test.</p>
/// <p>The harness is <class>OcuPilot.Test.WorkflowTurnCase</class>'s. The principal holds the class tools' pairs and the
/// pairs <code>permissions.users.delete</code> requires, read from the tool registry. <b>It needs</b> OcuPilot installed
/// and serving over HTTP on a throwaway, a <code>USER</code> namespace, and both <parameter>ARMINGVARIABLE</parameter> and
/// <parameter>PROVIDERVARIABLE</parameter> reading <code>1</code>.</p>
Class OcuPilot.Test.WorkflowGates Extends OcuPilot.Test.WorkflowTurnCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROVIDERVARIABLE = "OCUPILOT_ALLOW_TEST_PROVIDER";

Parameter TAG = "workflowgates-probe";

/// <p>The class tools' grants and the pairs the user delete requires, as <code>resource:letter</code> grants, read from
/// the registry so a change to the tool's pairs moves the principal with it.</p>
Method Grants(pCodeResource As %String) As %String
{
    Quit ##super(pCodeResource) _ "," _ ..PairGrants("permissions.users.delete")
}

/// <p>Tool <var>pTool</var>'s required pairs as a role's grants: each <code>(resource, USE|READ|WRITE)</code> as
/// <code>resource:U|R|W</code>.</p>
ClassMethod PairGrants(pTool As %String) As %String
{
    Set tGrants = ""
    Set tRegistry = "OcuPilot.Screen.Tool.Registry"
    Set tSC = $ClassMethod(tRegistry, "ResolveWire", $ClassMethod(tRegistry, "WireName", pTool), .tTool)
    If $$$ISERR(tSC) || '$IsObject($Get(tTool)) Quit ""
    Set tPairs = $ClassMethod(tRegistry, "RequiredPairs", tTool, .tResolved)
    If 'tResolved Quit ""
    For tI = 1:1:$ListLength(tPairs) {
        Set tPair = $List(tPairs, tI)
        Set tGrants = tGrants _ $Select(tGrants = "": "", 1: ",") _ $List(tPair, 1) _ ":" _ $Extract($List(tPair, 2), 1)
    }
    Quit tGrants
}

/// <p>Script one <code>compileclass</code> turn whose save mints a proposal, run it, and answer the proposal's key:
/// <var>pView</var> is the turn's last progress view.</p>
Method MintSave(Output pView) As %String
{
    Do $$$AssertStatusOK(..MakeProbe(), "the probe class is saved")
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply([(..SaveCall("toolu_save", "    Quit 1", "    Quit 2"))]))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("WORKFLOWGATES"))
    Set tState = ..RunTurn(..NewConversation(), "Fix a class until it compiles, step by step", "compileclass", .pView)
    Do $$$AssertEquals(tState, "completed", "the workflow turn completes")
    Set tKey = ..FirstProposal(pView)
    Do $$$AssertNotEquals(tKey, "", "and mints its proposal")
    Quit tKey
}

/// <p>Set key <var>pKey</var> to <var>pSetting</var> (<code>enabled</code> or <code>disabled</code>) in the stored
/// policy.</p>
Method SetKey(pKey As %String, pSetting As %String)
{
    Set tSettings(pKey) = pSetting
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), pKey _ " is " _ pSetting _ " in the stored policy")
}

/// <p>AC3: the save's key is disabled between the workflow turn and its Confirm, so the Confirm answers 403
/// <code>GOVERNANCE.DISABLED</code> and the class is unchanged.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Kernel.Proposal.Confirm</code>'s governance check is skipped -> this goes
/// red.</p>
Method TestADisabledKeyRefusesTheConfirm()
{
    Set tKey = ..MintSave()
    If tKey = "" Quit
    Do ..SetKey("explorer.classes.save", "disabled")
    Do ..Confirm(tKey, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 403, "the confirm answers 403")
    Do $$$AssertEquals($Select($IsObject(tBody): tBody.%Get("code"), 1: ""), "GOVERNANCE.DISABLED", "GOVERNANCE.DISABLED")
    Do $$$AssertEquals(..Answer(), "    Quit 1", "and the class is unchanged")
}

/// <p>AC3: enforced read-only is set between the turn and its Confirm.</p>
/// <p>Mutation (Rule 19): the confirm's restraint check is skipped -> this goes red.</p>
Method TestEnforcedReadOnlyRefusesTheConfirm()
{
    Set tKey = ..MintSave()
    If tKey = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(0, "", 1), "enforced read-only is on")
    Do ..Confirm(tKey, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 403, "the confirm answers 403")
    Do $$$AssertEquals($Select($IsObject(tBody): tBody.%Get("code"), 1: ""), "AGENT.READONLY.ENFORCED", "AGENT.READONLY.ENFORCED")
    Do $$$AssertEquals(..Answer(), "    Quit 1", "and the class is unchanged")
}

/// <p>AC3: the kill switch is set between the turn and its Confirm.</p>
/// <p>Mutation (Rule 19): the confirm's kill-switch check is skipped -> this goes red.</p>
Method TestTheKillSwitchRefusesTheConfirm()
{
    Set tKey = ..MintSave()
    If tKey = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(1, "workflow gates probe", 0), "the kill switch is on")
    Do ..Confirm(tKey, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 403, "the confirm answers 403")
    Do $$$AssertEquals($Select($IsObject(tBody): tBody.%Get("code"), 1: ""), "AGENT.KILLSWITCH.GLOBAL", "AGENT.KILLSWITCH.GLOBAL")
    Do $$$AssertEquals(..Answer(), "    Quit 1", "and the class is unchanged")
}

/// <p>AC3: a <code>newproject</code> turn proposes deleting the turn's own principal -- a step's write -- and the
/// Confirm refuses it <code>PROHIBITED.CURRENTUSER</code>: the account is still there.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Kernel.Proposal.Prohibited</code>'s <code>User</code> without its current-user
/// arm -> this goes red.</p>
Method TestTheTurnsOwnPrincipalDeleteIsRefusedAtConfirm()
{
    Set tUser = $Parameter(..#FIXTURE, "USERA")
    Set tDelete = {"id": "toolu_delete", "input": {}}
    Do tDelete.input.%Set("Name", tUser, "string")
    Do tDelete.input.%Set("rationale", "remove the account", "string")
    Do tDelete.input.%Set("expectedImpact", "the account is gone", "string")
    Do tDelete.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName("permissions.users.delete"), "string")
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply([(tDelete)]))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("WORKFLOWGATES"))
    Set tState = ..RunTurn(..NewConversation(), "Set up a new project's namespace, step by step", "newproject", .tView)
    Do $$$AssertEquals(tState, "completed", "the workflow turn completes")
    Set tKey = ..FirstProposal(tView)
    Do $$$AssertNotEquals(tKey, "", "and mints the delete as a proposal of its own principal: " _ ##class(OcuPilot.Test.TurnProvider).Recorded(..#TAG, 2, "messages"))
    If tKey = "" Quit
    Do ..Confirm(tKey, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 403, "the confirm answers 403")
    Do $$$AssertEquals($Select($IsObject(tBody): tBody.%Get("code"), 1: ""), "PROHIBITED.CURRENTUSER", "PROHIBITED.CURRENTUSER")
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = "%SYS"
    Set tExists = ##class(Security.Users).Exists(tUser)
    Set $NAMESPACE = tOrigNS
    Do $$$AssertTrue(tExists, "and the principal is still there")
}

/// <p>AC3: with the save's key disabled before the call, the call answers <code>GOVERNANCE.DISABLED</code> and the turn
/// holds no proposal.</p>
/// <p>Mutation (Rule 19): the dispatcher's governance gate is skipped for a workflow turn -> this goes red.</p>
Method TestADisabledKeyRefusesTheCallAndMintsNothing()
{
    Do $$$AssertStatusOK(..MakeProbe(), "the probe class is saved")
    Do ..SetKey("explorer.classes.save", "disabled")
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply([(..SaveCall("toolu_save", "    Quit 1", "    Quit 2"))]))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("WORKFLOWGATES"))
    Set tState = ..RunTurn(..NewConversation(), "Fix a class until it compiles, step by step", "compileclass", .tView)
    Do $$$AssertEquals(tState, "completed", "the turn completes")
    Do ..ResultsOf(2, .tResults, .tWrapped)
    Set tRefused = ..Parsed($Get(tResults("toolu_save")))
    Do $$$AssertEquals(($IsObject(tRefused) && (tRefused.%Get("code") = "GOVERNANCE.DISABLED")), 1, "the call answers GOVERNANCE.DISABLED: " _ $Extract($Get(tResults("toolu_save")), 1, 200))
    Do $$$AssertEquals(..FirstProposal(tView), "", "and nothing is minted")
    Do $$$AssertEquals(..Answer(), "    Quit 1", "and the class is unchanged")
}

/// <p>AC3, the shipped policy: a <code>resendmessages</code> turn calls the resend with the policy at its defaults,
/// where that key ships off, and the call answers <code>GOVERNANCE.DISABLED</code> and mints nothing. Sorts before the
/// own-principal test, which removes the principal.</p>
/// <p>Mutation (Rule 19): the dispatcher's governance gate is skipped for a workflow turn -> this goes red.</p>
Method TestTheResendKeyShipsOffSoItsCallMintsNothing()
{
    Set tCall = {"id": "toolu_resend", "input": {"rationale": "resend the failed messages", "expectedImpact": "they are delivered again"}}
    Do tCall.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName("interop.messages.resend"), "string")
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).ToolUseReply([(tCall)]))
    Do ##class(OcuPilot.Test.TurnProvider).Script(..#TAG, 0, ##class(OcuPilot.Test.TurnProvider).TextReply("WORKFLOWGATES"))
    Set tState = ..RunTurn(..NewConversation(), "Resend failed messages, step by step", "resendmessages", .tView)
    Do $$$AssertEquals(tState, "completed", "the turn completes")
    Do ..ResultsOf(2, .tResults, .tWrapped)
    Set tRefused = ..Parsed($Get(tResults("toolu_resend")))
    Do $$$AssertEquals(($IsObject(tRefused) && (tRefused.%Get("code") = "GOVERNANCE.DISABLED")), 1, "the call answers GOVERNANCE.DISABLED: " _ $Extract($Get(tResults("toolu_resend")), 1, 200))
    Do $$$AssertEquals(..FirstProposal(tView), "", "and nothing is minted")
}

}
