/// <p>Pins Story 24.17 Batch 4's namespace rule (AD-52, AD-62): a proposal carries the namespace it was minted in, and every confirm-time judgment and the vendor call run there, whichever namespace the
/// confirm is sent from. A task is stored under one id in <code>USER</code> and in <code>HSCUSTOM</code>; an assign minted in one and confirmed from the other acts in the first and leaves the second's task as it was.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropWorkflowCase</class> needs and the HTTP test account. It starts no production.</p>
Class OcuPilot.Test.InteropWorkflowTaskElsewhere Extends OcuPilot.Test.InteropWorkflowTaskCase
{

/// <p>AC6: the assign minted in <code>USER</code> and confirmed with <code>?ns=HSCUSTOM</code>, both namespaces holding a task under the same id, assigns the task of <code>USER</code> alone; and the
/// assign minted in <code>HSCUSTOM</code> and confirmed from <code>USER</code> acts in <code>HSCUSTOM</code> alone.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.InteropAction.PortQuery</method> drop the proposal's namespace -- the confirm acts in the namespace it was sent from and this goes red.</p>
Method TestAnAssignActsInTheNamespaceItWasMintedIn()
{
    Set tFx = ..#FIXTURE
    Do $$$AssertStatusOK(..Arrange(..#SOURCE), "the probe role and users are stored in USER")
    Do $$$AssertStatusOK(..Arrange(..#OTHER), "and in HSCUSTOM")
    Set tId = $ClassMethod(tFx, "SharedId")
    Set tUser = $ClassMethod(tFx, "ProbeTaskWithId", tId, ..#ROLE, "", ..#USERA, ..#SOURCE)
    Set tHsc = $ClassMethod(tFx, "ProbeTaskWithId", tId, ..#ROLE, "", ..#USERA, ..#OTHER)
    Do $$$AssertEquals(tUser _ "|" _ tHsc, tId _ "|" _ tId, "one task id is held by a task in each namespace")
    If (tUser '= tId) || (tHsc '= tId) Quit
    Set tCode = ..MintTask("Assign", tId, {"User": (..#USERB), "Priority": 4}, .tReason, .tProposal, .tTurn, ..#SOURCE)
    Do $$$AssertEquals(tCode, "minted", "the assign mints in USER: " _ tReason)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.target.scope, "USER", "its target is the task of USER")
    Set tStatus = ..Confirm(tProposal.proposalId, .tHttp, .tRaw, .tAnswer, ..#OTHER)
    Do $$$AssertEquals(tHttp, 200, "it confirms from HSCUSTOM: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals(..Facts(tId, ..#SOURCE), ..#ROLE _ "|" _ ..#USERB _ "|4|Assigned|0#" _ ..#USERB, "the task of USER is assigned, at the priority proposed")
    Do $$$AssertEquals(..Facts(tId, ..#OTHER), ..#ROLE _ "||0||0#" _ ..#USERA, "and the task of HSCUSTOM, under the same id, is as it was")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    Set tCode = ..MintTask("Assign", tId, {"User": (..#USERA), "Priority": 2}, .tReason, .tSecond, .tSecondTurn, ..#OTHER)
    Do $$$AssertEquals(tCode, "minted", "an assign mints in HSCUSTOM: " _ tReason)
    If '$IsObject($Get(tSecond)) Quit
    Do $$$AssertEquals(tSecond.target.scope, "HSCUSTOM", "its target is the task of HSCUSTOM")
    Set tStatus = ..Confirm(tSecond.proposalId, .tHttp, .tRaw, .tAnswer, ..#SOURCE)
    Do $$$AssertEquals(tHttp, 200, "it confirms from USER: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals(..Facts(tId, ..#OTHER), ..#ROLE _ "|" _ ..#USERA _ "|2|Assigned|0#" _ ..#USERA, "the task of HSCUSTOM is assigned to its user at priority 2")
    Do $$$AssertEquals(..Facts(tId, ..#SOURCE), ..#ROLE _ "|" _ ..#USERB _ "|4|Assigned|0#" _ ..#USERB, "and the task of USER is as the first assign left it")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tSecondTurn))
}

}
