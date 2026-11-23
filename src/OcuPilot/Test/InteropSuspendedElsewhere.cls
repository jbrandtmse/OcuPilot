/// <p>Pins Story 24.16's proposals against the namespace they were read in (AD-6, AD-52): each of the agent's four writes on suspended messages -- resubmit, edit and resubmit,
/// discard and delete -- minted in <code>USER</code> and confirmed by a request scoped to <code>HSCUSTOM</code>, acts in <code>USER</code> alone, where the proposal read, and the
/// suspended probe headers <code>HSCUSTOM</code> holds, with their bodies, are as they were. Every judgment at the confirm, the fresh read, the verdicts, the production's state and the
/// vendor call, runs in the proposal's namespace.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in <code>HSCUSTOM</code> and serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, an
/// interoperability-enabled <code>USER</code> namespace and <code>HSCUSTOM</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it <b>compiles and runs a
/// probe production in <code>USER</code></b> and stores probe headers in both namespaces (<class>OcuPilot.Test.InteropSuspendedCase</class>), which it removes from both after the
/// last test, asserted clean. One class per run.</p>
Class OcuPilot.Test.InteropSuspendedElsewhere Extends OcuPilot.Test.InteropSuspendedCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>Mint <var>pTool</var> with <var>pArgs</var> in <code>USER</code> and confirm it from a request scoped to <code>HSCUSTOM</code>: <code>status</code> and, in <var>pAnswer</var>, the
/// answer; <code>0</code> when it did not mint.</p>
Method MintHere(pTool As %String, pArgs As %DynamicObject, Output pAnswer, Output pTurn) As %Integer
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tSC = $ClassMethod(..#CONTROL, "MintAs", pTool, pArgs, tUser, .tProposal, .tHttp, .tFault, .pTurn)
    Do $$$AssertStatusOK(tSC, pTool _ " mints in USER: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit 0
    Do $$$AssertEquals(tProposal.target.scope, "USER", "its target is in USER")
    Set tSC = $ClassMethod(..#CONTROL, "ConfirmHttp", tProposal.proposalId, .tStatus, .tRaw, .pAnswer, ..#OTHERNAMESPACE)
    Do $$$AssertEquals(tStatus, 200, "the proposal confirms from a request scoped to HSCUSTOM: " _ $Extract($Get(tRaw), 1, 300))
    Quit tStatus
}

/// <p>AC5: the agent's resubmit, minted in USER and confirmed from HSCUSTOM, resubmits USER's message, which the running production there processes; HSCUSTOM's suspended probe, which
/// no production runs for, is still Suspended.</p>
/// <p>Mutation (Rule 19): drop <code>Namespace</code> from <parameter>OcuPilot.Screen.Tool.InteropSuspendedAction.FINGERPRINTSUBJECT</parameter> -- the confirm judges in HSCUSTOM, refuses
/// the stopped production there and this goes red.</p>
Method TestTheResubmitIsConfirmedInTheNamespaceItWasReadIn()
{
    Set tA = ..Susp("alpha")
    Set tOther = ..OtherSuspended("E1")
    Do ..EnableKey(..#RESUBMITKEY)
    If ..MintHere(..#RESUBMITTOOL, {"Messages": (tA)}, .tAnswer, .tTurn) '= 200 Quit
    Do $$$AssertTrue(..Await(tA, 9), "USER's message was resubmitted and processed")
    Do $$$AssertEquals(..OtherStatus(tOther), 5, "and HSCUSTOM's probe is still Suspended")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>AC5: the agent's edit and resubmit, minted in USER and confirmed from HSCUSTOM, resubmits USER's message with the edited copy of its body; HSCUSTOM's suspended probe and its body are as
/// they were.</p>
/// <p>Mutation (Rule 19): drop <code>Namespace</code> from <parameter>OcuPilot.Screen.Tool.InteropMessageEditResend.FINGERPRINTSUBJECT</parameter> -- the confirm judges in HSCUSTOM and this
/// goes red.</p>
Method TestTheEditAndResubmitIsConfirmedInTheNamespaceItWasReadIn()
{
    Set tE = ..Susp("alpha")
    Set tOld = ..BodyOf(tE)
    Set tOther = ..OtherSuspended("E2")
    Do ..EnableKey(..#EDITKEY)
    If ..MintHere(..#EDITTOOL, {"Message": (tE), "Fields": {"StringValue": "edited"}}, .tAnswer, .tTurn) '= 200 Quit
    Do $$$AssertTrue(..Await(tE, 9), "USER's message was resubmitted and processed")
    Do $$$AssertEquals(..BodyText(..BodyOf(tE)) _ "|" _ ..BodyText(tOld), "StringValue=edited|StringValue=alpha", "with the edited copy, the original body unchanged")
    Do $$$AssertEquals(..OtherStatus(tOther), 5, "and HSCUSTOM's probe is still Suspended")
    Do ..DropBody(tOld)
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>AC5: the agent's discard, minted in USER and confirmed from HSCUSTOM, discards USER's message; HSCUSTOM's suspended probe is still Suspended.</p>
/// <p>Mutation (Rule 19): drop <code>Namespace</code> from <parameter>OcuPilot.Screen.Tool.InteropSuspendedAction.FINGERPRINTSUBJECT</parameter> -- the confirm reads HSCUSTOM, answers no
/// verdict for USER's id and this goes red.</p>
Method TestTheDiscardIsConfirmedInTheNamespaceItWasReadIn()
{
    Set tD = ..Susp("delta")
    Set tOther = ..OtherSuspended("E3")
    If ..MintHere(..#DISCARDTOOL, {"Messages": (tD)}, .tAnswer, .tTurn) '= 200 Quit
    Do $$$AssertEquals(..Status(tD), 4, "USER's message was discarded")
    Do $$$AssertEquals(..OtherStatus(tOther), 5, "and HSCUSTOM's probe is still Suspended")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>AC5: the agent's delete, minted in USER and confirmed from HSCUSTOM, deletes USER's message and its body; HSCUSTOM's suspended probe and its body are as they were.</p>
/// <p>Mutation (Rule 19): drop <code>Namespace</code> from <parameter>OcuPilot.Screen.Tool.InteropSuspendedAction.FINGERPRINTSUBJECT</parameter> -- the confirm reads HSCUSTOM and this goes
/// red; skip the case's <code>DropProbes</code> in <code>OnBeforeOneTest</code> and <code>OnAfterOneTest</code> -- a sibling's probes are still in HSCUSTOM and the start leg goes red.</p>
Method TestTheDeleteIsConfirmedInTheNamespaceItWasReadIn()
{
    Do $$$AssertEquals($ClassMethod(..#PURGEFIXTURE, "Count", ..#OTHERNAMESPACE, "header") _ "|" _ $ClassMethod(..#PURGEFIXTURE, "Count", ..#OTHERNAMESPACE, "body"), "0|0", "HSCUSTOM holds no probe when the test starts")
    Set tX = ..Susp("chi")
    Set tBody = ..BodyOf(tX)
    Set tOther = ..OtherSuspended("E4")
    Do ..EnableKey(..#DELETEKEY)
    If ..MintHere(..#DELETETOOL, {"Messages": (tX)}, .tAnswer, .tTurn) '= 200 Quit
    Do $$$AssertEquals(..Status(tX) _ "|" _ ..BodyText(tBody), "<none>|<none>", "USER's message and its body are gone")
    Do $$$AssertEquals(..OtherStatus(tOther), 5, "and HSCUSTOM's probe is still Suspended")
    Do $$$AssertEquals($ClassMethod(..#PURGEFIXTURE, "Count", ..#OTHERNAMESPACE, "header") _ "|" _ $ClassMethod(..#PURGEFIXTURE, "Count", ..#OTHERNAMESPACE, "body"), "1|1", "with its body")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

}
