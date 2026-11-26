/// <p>Pins Story 24.17 Batch 4's namespace rule (AD-52, AD-62): a proposal carries the namespace it was minted in, and every confirm-time judgment and the vendor call run there, whichever namespace the
/// confirm is sent from. A task is stored under one id in <code>USER</code> and in <code>HSCUSTOM</code>; an assign minted in one and confirmed from the other acts in the first and leaves the second's task as it was. The shared id raises a counter, so the fixture's restore of it is pinned here too.</p>
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

/// <p>The fixture puts back the id counters its probes raised without ever setting one below an id that is held, or raising one: on a counter of its own, a lowering to 3 stops at the held 8,
/// goes to 3 once nothing above it is held, leaves a counter another process moved, and never raises.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Test.InteropWorkflowTaskFixture.LowerCounter</method> ignore the highest held id -- the first leg goes red.</p>
Method TestTheCounterRestoreNeverGoesBelowAHeldId()
{
    Set tFx = ..#FIXTURE
    Set tGlobal = "^IRIS.Temp.OcuP2417wCounter"
    Kill @tGlobal
    Set @tGlobal = 10, @tGlobal@(5) = "", @tGlobal@(8) = "", @tGlobal@("x") = ""
    Do $$$AssertEquals($ClassMethod(tFx, "LowerCounter", tGlobal, 3), 8, "a counter is lowered no further than the highest id held, a text subscript aside")
    Kill @tGlobal@(8)
    Do $$$AssertEquals($ClassMethod(tFx, "LowerCounter", tGlobal, 3, 7), 8, "it is left alone when it no longer reads what the probe left")
    Do $$$AssertEquals($ClassMethod(tFx, "LowerCounter", tGlobal, 3, 8), 5, "and lowered to the highest id held when it does")
    Kill @tGlobal@(5)
    Do $$$AssertEquals($ClassMethod(tFx, "LowerCounter", tGlobal, 3), 3, "to the value kept once nothing above it is held")
    Do $$$AssertEquals($ClassMethod(tFx, "LowerCounter", tGlobal, 20), 3, "and never raised")
    Kill @tGlobal
}

}
