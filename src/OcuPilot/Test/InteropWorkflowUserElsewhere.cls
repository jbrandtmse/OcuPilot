/// <p>Pins that a workflow user write the agent minted acts in the namespace the proposal read, whichever namespace the confirming request is scoped to (AD-6, AD-52, Story 24.17 Batch 3a). Each of
/// the three tools is minted in <code>USER</code> and confirmed with <code>?ns=HSCUSTOM</code>, <code>HSCUSTOM</code> holding a user of the same name: the add is made in <code>USER</code> and is
/// not refused as taken, the edit and the remove change <code>USER</code>'s user alone, and <code>HSCUSTOM</code>'s user, its memberships and its worklist are unchanged.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropWorkflowCase</class> needs, and the HTTP test account.</p>
Class OcuPilot.Test.InteropWorkflowUserElsewhere Extends OcuPilot.Test.InteropWorkflowCase
{

Parameter NAME = "OcuP2417wEa";

Parameter ROLE = "OcuP2417wRe";

/// <p>Mint <var>pTool</var> for the probe user with <var>pArgs</var> in <code>USER</code> and confirm it from <code>HSCUSTOM</code>: the status in <var>pStatus</var>, the answer in
/// <var>pAnswer</var>, the proposal's turn in <var>pTurn</var>; <code>""</code> when it did not mint.</p>
ClassMethod MintHere(pTool As %String, pArgs As %DynamicObject, Output pStatus As %Integer, Output pAnswer, Output pTurn As %String) As %String
{
    Set pStatus = ""
    Set pAnswer = ""
    Set pTurn = ""
    Set tCode = ..Mint(pTool, ..#NAME, pArgs, .tReason, .tProposal, .pTurn)
    If tCode '= "minted" Quit tCode _ ": " _ tReason
    Set tSC = ..Confirm(tProposal.proposalId, .pStatus, .tRaw, .pAnswer, ..#OTHER)
    Quit "minted"
}

/// <p>AC6: an add minted in <code>USER</code> and confirmed from <code>HSCUSTOM</code> is made in <code>USER</code>, where the name is free, though <code>HSCUSTOM</code> holds a user of that name:
/// it is not refused as taken, <code>HSCUSTOM</code>'s user is unchanged, and the audit row names <code>USER</code>.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.InteropWorkflowUserAction.PortQuery</method> drop the payload's namespace -- the add is read in <code>HSCUSTOM</code>, refused as taken, and
/// this goes red.</p>
Method TestAnAddConfirmedFromAnotherNamespaceIsJudgedAndMadeWhereItRead()
{
    Set tFx = ..#FIXTURE
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeUser", ..#NAME, "hsc", 1, ..#OTHER), "the name is held in HSCUSTOM alone, and is an instance user")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tMinted = ..MintHere("Add", {"FullName": "agent"}, .tStatus, .tAnswer, .tTurn)
    Do $$$AssertEquals(tMinted, "minted", "the add mints in USER: " _ tMinted)
    Do $$$AssertEquals(tStatus, 200, "and confirms from HSCUSTOM: " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals($ClassMethod(tFx, "UserText", ..#SOURCE, ..#NAME), "agent|1", "the user is created in USER, where the proposal read")
    Do $$$AssertEquals($ClassMethod(tFx, "UserText", ..#OTHER, ..#NAME), "hsc|1", "and HSCUSTOM's is as it was")
    Do $$$AssertEquals(..OwnRows(tSince, ..#NAME, .tData, 1, 1), 1, "one ConfigChange was recorded")
    Do $$$AssertTrue(tData [ "USER", "naming the namespace the write was made in: " _ tData)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>AC6: an edit minted in <code>USER</code> and confirmed from <code>HSCUSTOM</code> changes <code>USER</code>'s user alone, and an edit that makes it inactive deletes <code>USER</code>'s worklist
/// item and no one else's.</p>
/// <p>Mutation (Rule 19): make the tool's confirm-time read ignore the payload's namespace -- the edit acts on HSCUSTOM's user and this goes red.</p>
Method TestAnEditConfirmedFromAnotherNamespaceActsWhereItRead()
{
    Set tFx = ..#FIXTURE
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeUser", ..#NAME, "usr", 1, ..#SOURCE), "the user is held in USER")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeUser", ..#NAME, "hsc", 1, ..#OTHER, 0), "and the same name in HSCUSTOM")
    For tNamespace = ..#SOURCE, ..#OTHER {
        Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeRole", ..#ROLE, tNamespace), "a role is stored in " _ tNamespace)
        Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeMember", ..#ROLE, ..#NAME, tNamespace), "the user is its member")
        Do $$$AssertTrue($ClassMethod(tFx, "ProbeTask", ..#ROLE, ..#NAME, ..#NAME, tNamespace) > 0, "and owns a task with a worklist item")
    }
    Set tMinted = ..MintHere("Update", {"FullName": "usr changed", "IsActive": false}, .tStatus, .tAnswer, .tTurn)
    Do $$$AssertEquals(tMinted, "minted", "the update mints in USER: " _ tMinted)
    Do $$$AssertEquals(tStatus, 200, "and confirms from HSCUSTOM: " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals($ClassMethod(tFx, "UserText", ..#SOURCE, ..#NAME), "usr changed|0", "USER's user changed, where the proposal read")
    Do $$$AssertEquals($ClassMethod(tFx, "UserText", ..#OTHER, ..#NAME), "hsc|1", "and HSCUSTOM's is as it was")
    Do $$$AssertEquals($ClassMethod(tFx, "Facts", ..#SOURCE, ..#NAME), "1|0|0", "USER's worklist item is gone and its task is unassigned")
    Do $$$AssertEquals($ClassMethod(tFx, "Facts", ..#OTHER, ..#NAME), "1|1|1", "HSCUSTOM's worklist item and task are untouched")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>AC6: a remove minted in <code>USER</code> and confirmed from <code>HSCUSTOM</code> removes <code>USER</code>'s user and its memberships and leaves <code>HSCUSTOM</code>'s user, its membership,
/// its worklist item and its task as they were.</p>
/// <p>Mutation (Rule 19): make the tool's confirm-time write ignore the payload's namespace -- the remove takes HSCUSTOM's user and this goes red.</p>
Method TestARemoveConfirmedFromAnotherNamespaceActsWhereItRead()
{
    Set tFx = ..#FIXTURE
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeUser", ..#NAME, "usr", 1, ..#SOURCE), "the user is held in USER")
    Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeUser", ..#NAME, "usr", 1, ..#OTHER, 0), "and an identical one in HSCUSTOM")
    For tNamespace = ..#SOURCE, ..#OTHER {
        Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeRole", ..#ROLE, tNamespace), "a role is stored in " _ tNamespace)
        Do $$$AssertStatusOK($ClassMethod(tFx, "ProbeMember", ..#ROLE, ..#NAME, tNamespace), "the user is its member")
        Do $$$AssertTrue($ClassMethod(tFx, "ProbeTask", ..#ROLE, ..#NAME, ..#NAME, tNamespace) > 0, "and owns a task with a worklist item")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tPolicy), "the governance policy is read")
    Kill tSettings
    Set tSettings("interop.workflowusers.remove") = "enabled"
    Set tStatus = ""
    Set tAnswer = ""
    Set tTurn = ""
    Try {
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the remove tool's key is turned on")
        Set tMinted = ..MintHere("Remove", {}, .tStatus, .tAnswer, .tTurn)
        Do $$$AssertEquals(tMinted, "minted", "the remove mints in USER: " _ tMinted)
        Do $$$AssertEquals(tStatus, 200, "and confirms from HSCUSTOM: " _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""))
        Do $$$AssertEquals($ClassMethod(tFx, "UserText", ..#SOURCE, ..#NAME) _ "|" _ $ClassMethod(tFx, "Facts", ..#SOURCE, ..#NAME), "<absent>|0|0|0", "it removed the user in USER, where the proposal read, with its membership and worklist")
        Do $$$AssertEquals($ClassMethod(tFx, "UserText", ..#OTHER, ..#NAME) _ "|" _ $ClassMethod(tFx, "Facts", ..#OTHER, ..#NAME), "usr|1|1|1|1", "and left HSCUSTOM's user, membership, worklist item and task alone")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the remove leg raised")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

}
