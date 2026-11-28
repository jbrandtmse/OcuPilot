/// <p>Pins that a workflow role or member write the agent minted acts in the namespace the proposal read, whichever namespace the confirming request is scoped to (AD-6, AD-52, Story 24.17 Batch 3b). Each
/// of the five tools is minted in <code>USER</code> and confirmed with <code>?ns=HSCUSTOM</code>, <code>HSCUSTOM</code> holding a role, user and membership of the same names: the role add is made in
/// <code>USER</code> and is not refused as taken, the role edit and remove and the member add and remove change <code>USER</code>'s rows alone, and <code>HSCUSTOM</code>'s roles, memberships, worklists and
/// tasks are unchanged.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropWorkflowCase</class> needs, and the HTTP test account.</p>
Class OcuPilot.Test.InteropWorkflowRoleElsewhere Extends OcuPilot.Test.InteropWorkflowCase
{

Parameter SCREEN = "/screens/interop.workflowroles";

Parameter SAVE = "/interop/workflow-roles";

Parameter ENDPOINT = "WorkflowRoles";

Parameter TOOLPREFIX = "OcuPilot.Screen.Tool.InteropWorkflowRole";

Parameter ENTITY = "interop-workflow-role";

Parameter READTYPE = "WORKFLOWROLE";

Parameter ROLE = "OcuP2417wEr";

Parameter USER = "OcuP2417wEu";

/// <p>Store the same-named role, user, membership, task and worklist item in <var>pNamespace</var>, the user inactive so the engine sends it no task of its own.</p>
ClassMethod Arrange(pNamespace As %String, pMember As %Boolean = 1) As %Status
{
    Set tFx = ..#FIXTURE
    Set tSC = $ClassMethod(tFx, "ProbeUser", ..#USER, "user " _ pNamespace, 0, pNamespace, (pNamespace = ..#SOURCE))
    Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeRole", ..#ROLE, pNamespace, "role " _ pNamespace, 20))
    If pMember {
        Set tSC = $$$ADDSC(tSC, $ClassMethod(tFx, "ProbeMember", ..#ROLE, ..#USER, pNamespace, 2, "t " _ pNamespace))
        If '$ClassMethod(tFx, "ProbeTask", ..#ROLE, "", ..#USER, pNamespace) Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the probe task was not stored"))
    }
    Quit tSC
}

/// <p>The role's facts in <var>pNamespace</var>: <code>memberships|worklist items|tasks|tasks assigned</code>.</p>
ClassMethod Facts(pNamespace As %String) As %String
{
    Quit $ClassMethod(..#FIXTURE, "RoleFacts", pNamespace, ..#ROLE)
}

/// <p>Mint the role tool <var>pTool</var> in <code>USER</code> and confirm it from <code>HSCUSTOM</code>: the status in <var>pStatus</var>, the answer in <var>pAnswer</var>, the turn in
/// <var>pTurn</var>; the mint's code when it did not mint.</p>
ClassMethod RoleHere(pTool As %String, pArgs As %DynamicObject, Output pStatus As %Integer, Output pAnswer, Output pTurn As %String) As %String
{
    Set pStatus = ""
    Set pAnswer = ""
    Set pTurn = ""
    Set tCode = ..Mint(pTool, ..#ROLE, pArgs, .tReason, .tProposal, .pTurn)
    If tCode '= "minted" Quit tCode _ ": " _ tReason
    Set tSC = ..Confirm(tProposal.proposalId, .pStatus, .tRaw, .pAnswer, ..#OTHER)
    Quit "minted"
}

/// <p>Mint the member tool <var>pTool</var> for the probe user in <code>USER</code> and confirm it from <code>HSCUSTOM</code>, as <method>RoleHere</method> answers it.</p>
ClassMethod MemberHere(pTool As %String, pArgs As %DynamicObject, Output pStatus As %Integer, Output pAnswer, Output pTurn As %String) As %String
{
    Set pStatus = ""
    Set pAnswer = ""
    Set pTurn = ""
    Set tCode = ..MintMember(pTool, ..#ROLE, ..#USER, pArgs, .tReason, .tProposal, .pTurn)
    If tCode '= "minted" Quit tCode _ ": " _ tReason
    Set tSC = ..Confirm(tProposal.proposalId, .pStatus, .tRaw, .pAnswer, ..#OTHER)
    Quit "minted"
}

/// <p>AC7: a role add minted in <code>USER</code> and confirmed from <code>HSCUSTOM</code> is made in <code>USER</code>, where the name is free, though <code>HSCUSTOM</code> holds a role of that name:
/// it is not refused as taken, <code>HSCUSTOM</code>'s role is unchanged, and the audit row names <code>USER</code>.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.InteropWorkflowAction.PortQuery</method> drop the payload's namespace -- the add is read in <code>HSCUSTOM</code>, refused as taken, and this
/// goes red.</p>
Method TestARoleAddConfirmedFromAnotherNamespaceIsJudgedAndMadeWhereItRead()
{
    Set tFx = ..#FIXTURE
    Do $$$AssertStatusOK(..Arrange(..#OTHER, 0), "the name is held in HSCUSTOM alone")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tMinted = ..RoleHere("Add", {"Description": "agent", "Capacity": 70}, .tStatus, .tAnswer, .tTurn)
    Do $$$AssertEquals(tMinted, "minted", "the add mints in USER: " _ tMinted)
    Do $$$AssertEquals(tStatus, 200, "and confirms from HSCUSTOM: " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals($ClassMethod(tFx, "RoleText", ..#SOURCE, ..#ROLE), "agent|70", "the role is created in USER, where the proposal read")
    Do $$$AssertEquals($ClassMethod(tFx, "RoleText", ..#OTHER, ..#ROLE), "role HSCUSTOM|20", "and HSCUSTOM's is as it was")
    Do $$$AssertEquals(..OwnRows(tSince, ..#ROLE, .tData, 1, 1), 1, "one ConfigChange was recorded")
    Do $$$AssertTrue(tData [ "USER", "naming the namespace the write was made in: " _ tData)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>AC7: a role edit minted in <code>USER</code> and confirmed from <code>HSCUSTOM</code> changes <code>USER</code>'s role alone.</p>
/// <p>Mutation (Rule 19): make the tool's confirm-time read ignore the payload's namespace -- the edit acts on HSCUSTOM's role and this goes red.</p>
Method TestARoleEditConfirmedFromAnotherNamespaceActsWhereItRead()
{
    Set tFx = ..#FIXTURE
    Do $$$AssertStatusOK(..Arrange(..#SOURCE), "the role is held in USER")
    Do $$$AssertStatusOK(..Arrange(..#OTHER), "and the same names in HSCUSTOM")
    Set tMinted = ..RoleHere("Update", {"Description": "usr changed", "Capacity": 33}, .tStatus, .tAnswer, .tTurn)
    Do $$$AssertEquals(tMinted, "minted", "the update mints in USER: " _ tMinted)
    Do $$$AssertEquals(tStatus, 200, "and confirms from HSCUSTOM: " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals($ClassMethod(tFx, "RoleText", ..#SOURCE, ..#ROLE), "usr changed|33", "USER's role changed, where the proposal read")
    Do $$$AssertEquals($ClassMethod(tFx, "RoleText", ..#OTHER, ..#ROLE), "role HSCUSTOM|20", "and HSCUSTOM's is as it was")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>AC7: a role remove minted in <code>USER</code> and confirmed from <code>HSCUSTOM</code> removes <code>USER</code>'s role and its membership and leaves <code>HSCUSTOM</code>'s role, membership,
/// worklist item and task as they were.</p>
/// <p>Mutation (Rule 19): make the tool's confirm-time write ignore the payload's namespace -- the remove takes HSCUSTOM's role and this goes red.</p>
Method TestARoleRemoveConfirmedFromAnotherNamespaceActsWhereItRead()
{
    Set tFx = ..#FIXTURE
    Do $$$AssertStatusOK(..Arrange(..#SOURCE), "the role is held in USER with a member, a task and a worklist item")
    Do $$$AssertStatusOK(..Arrange(..#OTHER), "and the same in HSCUSTOM")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tPolicy), "the governance policy is read")
    Kill tSettings
    Set tSettings("interop.workflowroles.remove") = "enabled"
    Set tTurn = ""
    Try {
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the remove tool's key is turned on")
        Set tMinted = ..RoleHere("Remove", {}, .tStatus, .tAnswer, .tTurn)
        Do $$$AssertEquals(tMinted, "minted", "the remove mints in USER: " _ tMinted)
        Do $$$AssertEquals(tStatus, 200, "and confirms from HSCUSTOM: " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""))
        Do $$$AssertEquals($ClassMethod(tFx, "RoleText", ..#SOURCE, ..#ROLE) _ "|" _ ..Facts(..#SOURCE), "<absent>|0|1|1|0", "it removed the role in USER, where the proposal read, with its membership, leaving its worklist item and task")
        Do $$$AssertEquals($ClassMethod(tFx, "RoleText", ..#OTHER, ..#ROLE) _ "|" _ ..Facts(..#OTHER), "role HSCUSTOM|20|1|1|1|0", "and left HSCUSTOM's role, membership, worklist item and task alone")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the remove leg raised")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>AC7: a member add minted in <code>USER</code> and confirmed from <code>HSCUSTOM</code> is made in <code>USER</code>, where the user is not yet a member, though <code>HSCUSTOM</code> holds a
/// membership of the same names, and the member remove acts on <code>USER</code>'s membership alone.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.InteropWorkflowAction.PortQuery</method> drop the payload's namespace -- the add is read in <code>HSCUSTOM</code>, refused as taken, and
/// this goes red.</p>
Method TestAMemberAddAndRemoveConfirmedFromAnotherNamespaceActWhereTheyRead()
{
    Set tFx = ..#FIXTURE
    Do $$$AssertStatusOK(..Arrange(..#SOURCE, 0), "the role and user are held in USER, with no member")
    Do $$$AssertStatusOK(..Arrange(..#OTHER), "and the same names in HSCUSTOM, where the user is a member")
    Set tMinted = ..MemberHere("Add", {"Ranking": 4, "Title": "agent"}, .tStatus, .tAnswer, .tTurn)
    Do $$$AssertEquals(tMinted, "minted", "the add mints in USER: " _ tMinted)
    Do $$$AssertEquals(tStatus, 200, "and confirms from HSCUSTOM, where the membership is held: " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals($ClassMethod(tFx, "MemberText", ..#SOURCE, ..#ROLE, ..#USER), "4|agent", "the user joined the role in USER, where the proposal read")
    Do $$$AssertEquals($ClassMethod(tFx, "MemberText", ..#OTHER, ..#ROLE, ..#USER) _ "|" _ ..Facts(..#OTHER), "2|t HSCUSTOM|1|1|1|0", "and HSCUSTOM's membership, worklist item and task are as they were")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    Set tMinted = ..MemberHere("Remove", {}, .tStatus, .tAnswer, .tTurn)
    Do $$$AssertEquals(tMinted, "minted", "the remove mints in USER: " _ tMinted)
    Do $$$AssertEquals(tStatus, 200, "and confirms from HSCUSTOM: " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals($ClassMethod(tFx, "MemberText", ..#SOURCE, ..#ROLE, ..#USER), "<absent>", "USER's membership is gone")
    Do $$$AssertEquals($ClassMethod(tFx, "MemberText", ..#OTHER, ..#ROLE, ..#USER) _ "|" _ ..Facts(..#OTHER), "2|t HSCUSTOM|1|1|1|0", "and HSCUSTOM's membership, worklist item and task are untouched")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

}
