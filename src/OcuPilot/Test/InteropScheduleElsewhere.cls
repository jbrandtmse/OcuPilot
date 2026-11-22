/// <p>Pins that a confirmed write of each of the three schedule spec tools acts in the namespace its proposal read (AD-52, AD-62, Story 24.15): the
/// agent's add, edit and remove of a schedule spec, each minted in <code>USER</code> and confirmed by a request scoped to <code>HSCUSTOM</code>, where a
/// schedule spec of the same name is held. The confirm answers 200, <code>USER</code>'s schedule spec is added, changed or removed, the add is not refused
/// as a name the namespace holds, and <code>HSCUSTOM</code>'s schedule spec is left as it was.</p>
/// <p>It borrows the helpers of <class>OcuPilot.Test.InteropScheduleControl</class>. <b>What it needs from the environment:</b> interoperability-enabled
/// <code>USER</code> and <code>HSCUSTOM</code> namespaces, the HTTP test account and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>. It
/// removes every probe schedule spec it makes in both namespaces, deletes its ledger rows and puts the governance policy back.</p>
Class OcuPilot.Test.InteropScheduleElsewhere Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FIXTURE = "OcuPilot.Test.InteropScheduleFixture";

Parameter CLEARER = "OcuPilot.Test.InteropLookupFixture";

Parameter CONTROL = "OcuPilot.Test.InteropScheduleControl";

Parameter OTHERNAMESPACE = "HSCUSTOM";

Parameter NAME = "OcuProbe2415SE";

Parameter SPEC1 = "START:*-*-*T08:00:00,STOP:*-*-*T17:00:00";

Parameter SPEC2 = "START:*-*-*T09:00:00,STOP:*-*-*T18:00:00";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InteropScheduleElsewhere writes probe schedule specs in USER and HSCUSTOM on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $ClassMethod(..#CLEARER, "Clear")
}

Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#CLEARER, "Clear")
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Quit $ClassMethod(..#CLEARER, "Clear")
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK($ClassMethod(..#CLEARER, "Clear"), "the probe schedule specs are removed from both namespaces")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "ScheduleCount") + $ClassMethod(..#FIXTURE, "ScheduleCount", "OcuProbe2415S", ..#OTHERNAMESPACE), 0, "and none survives in either")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Quit $$$OK
}

/// <p>Mint <var>pTool</var> for the probe schedule spec with <var>pSet</var> in <code>USER</code>, confirm it from a request scoped to
/// <parameter>OTHERNAMESPACE</parameter> and answer the confirm's status; the turn is in <var>pTurn</var>.</p>
Method MintAndConfirmFromOther(pTool As %String, pSet As %DynamicObject, Output pTurn, Output pRaw) As %Integer
{
    Set tSC = $ClassMethod(..#CONTROL, "Mint", pTool, $ClassMethod(..#CONTROL, "ArgsFor", ..#NAME, pSet), .tProposal, .tFault, .pTurn)
    Do $$$AssertStatusOK(tSC, pTool _ " mints in USER: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If '$IsObject($Get(tProposal)) Quit 0
    Quit $ClassMethod(..#CONTROL, "Confirm", tProposal, .tAnswer, .pRaw, ..#OTHERNAMESPACE)
}

/// <p>Matrix row 1: an add minted in <code>USER</code>, where the name is free, and confirmed from <code>HSCUSTOM</code>, where it is held, is not refused
/// as taken, creates the schedule spec in <code>USER</code> and leaves <code>HSCUSTOM</code>'s as it was.</p>
/// <p>Mutation (Rule 19): drop the <code>Namespace</code> that <method>OcuPilot.Screen.Tool.InteropScheduleAdd.ComposeCreate</method> stamps -- the
/// confirm reads the name in <code>HSCUSTOM</code>, is refused, and this goes red.</p>
Method TestAnAddConfirmedFromAnotherNamespaceIsJudgedWhereItRead()
{
    Set tFixture = ..#FIXTURE
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutSchedule", ..#NAME, ..#SPEC2, "hsc", 0, ..#OTHERNAMESPACE), "the name is held in HSCUSTOM alone")
    Set tTurn = ""
    Try {
        Set tStatus = ..MintAndConfirmFromOther("InteropScheduleAdd", {"ScheduleSpec": (..#SPEC1), "Description": "agent"}, .tTurn, .tRaw)
        Do $$$AssertEquals(tStatus, 200, "a confirm sent from HSCUSTOM answers: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($ClassMethod(tFixture, "ScheduleText", ..#NAME), ..#SPEC1 _ "|agent|0", "the schedule spec is created in USER, where the proposal read, and the add was not refused as taken")
        Do $$$AssertEquals($ClassMethod(tFixture, "ScheduleText", ..#NAME, ..#OTHERNAMESPACE), ..#SPEC2 _ "|hsc|0", "and HSCUSTOM's is as it was")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the add leg raised")
    }
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>Matrix row 2: an edit minted in <code>USER</code> and confirmed from <code>HSCUSTOM</code>, where the same schedule spec is held, changes
/// <code>USER</code>'s and leaves <code>HSCUSTOM</code>'s as it was.</p>
/// <p>Mutation (Rule 19): remove <code>Do ##super</code> from <method>OcuPilot.Screen.Tool.InteropScheduleAction.PortQuery</method> -- the confirm's
/// re-read is of HSCUSTOM's schedule spec, which differs, the proposal closes target-changed, and this goes red.</p>
Method TestAnEditConfirmedFromAnotherNamespaceActsWhereItRead()
{
    Set tFixture = ..#FIXTURE
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutSchedule", ..#NAME, ..#SPEC1, "usr"), "the schedule spec is held in USER")
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutSchedule", ..#NAME, ..#SPEC1, "hsc", 0, ..#OTHERNAMESPACE), "and the same name in HSCUSTOM")
    Set tTurn = ""
    Try {
        Set tStatus = ..MintAndConfirmFromOther("InteropScheduleUpdate", {"ScheduleSpec": (..#SPEC2)}, .tTurn, .tRaw)
        Do $$$AssertEquals(tStatus, 200, "a confirm sent from HSCUSTOM answers: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($ClassMethod(tFixture, "ScheduleText", ..#NAME), ..#SPEC2 _ "|usr|0", "USER's schedule spec changed, where the proposal read")
        Do $$$AssertEquals($ClassMethod(tFixture, "ScheduleText", ..#NAME, ..#OTHERNAMESPACE), ..#SPEC1 _ "|hsc|0", "and HSCUSTOM's is as it was")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the edit leg raised")
    }
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
}

/// <p>Matrix row 3: a remove minted in <code>USER</code> and confirmed from <code>HSCUSTOM</code>, where the same schedule spec is held, removes
/// <code>USER</code>'s and leaves <code>HSCUSTOM</code>'s as it was.</p>
/// <p>Mutation (Rule 19): take <code>Namespace</code> out of <parameter>OcuPilot.Screen.Tool.InteropScheduleRemove.FINGERPRINTSUBJECT</parameter> -- the
/// confirm removes HSCUSTOM's schedule spec and this goes red.</p>
Method TestARemoveConfirmedFromAnotherNamespaceActsWhereItRead()
{
    Set tFixture = ..#FIXTURE
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutSchedule", ..#NAME, ..#SPEC1, "usr"), "the schedule spec is held in USER")
    Do $$$AssertStatusOK($ClassMethod(tFixture, "PutSchedule", ..#NAME, ..#SPEC1, "usr", 0, ..#OTHERNAMESPACE), "and an identical one in HSCUSTOM")
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tPolicy)
    Do $$$AssertStatusOK(tSC, "the governance policy is read")
    Set tTurn = ""
    Try {
        Kill tSettings
        Set tSettings("interop.schedules.remove") = "enabled"
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the remove's key is turned on")
        Set tStatus = ..MintAndConfirmFromOther("InteropScheduleRemove", {}, .tTurn, .tRaw)
        Do $$$AssertEquals(tStatus, 200, "a confirm sent from HSCUSTOM answers: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($ClassMethod(tFixture, "ScheduleText", ..#NAME), "<absent>", "it removed the schedule spec in USER, where the proposal read")
        Do $$$AssertEquals($ClassMethod(tFixture, "ScheduleText", ..#NAME, ..#OTHERNAMESPACE), ..#SPEC1 _ "|usr|0", "and left HSCUSTOM's alone")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the remove leg raised")
    }
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn)
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
}

}
