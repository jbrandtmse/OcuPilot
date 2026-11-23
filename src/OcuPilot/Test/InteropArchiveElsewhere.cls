/// <p>Pins Story 24.16 Batch 4's proposals against the namespace they were read in (AD-6, AD-52): the agent's set of an archive setting and its archive run, each minted in
/// <code>HSCUSTOM</code> and confirmed by a request scoped to <code>USER</code>, act in <code>HSCUSTOM</code> alone, where the proposal read. The archive settings of <code>USER</code>,
/// which hold values of their own, are as they were. Every judgment at the confirm, the fresh read, the target list, the lock test, the settings read and the value rules, runs in the
/// proposal's namespace.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropArchiveCase</class> needs. It puts both namespaces' archive trees back exactly as it found them.</p>
Class OcuPilot.Test.InteropArchiveElsewhere Extends OcuPilot.Test.InteropArchiveCase
{

/// <p>USER's own settings, which no confirm from HSCUSTOM may change.</p>
Method OwnSettings()
{
    Do $ClassMethod(..#FIXTURE, "PutSettings", ..#TARGET, ..#SOURCE, "<absent>", 45)
}

/// <p>AC5: the agent's set of an archive setting, minted in HSCUSTOM and confirmed from USER, stores the setting in HSCUSTOM; USER's settings, which hold values of their own, are as they
/// were.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.InteropPurgeSettingSet.PortQuery</method> drop the payload's namespace -- the set reaches USER and this goes red.</p>
Method TestTheSettingSetIsConfirmedInTheNamespaceItWasReadIn()
{
    Do ..OwnSettings()
    Set tUserBefore = $ClassMethod(..#FIXTURE, "SettingsText", ..#TARGET)
    Do $$$AssertEquals(..MintSet(..#DAYSNAME, "90", .tReason, .tProposal, .tTurn), "minted", "the set mints in HSCUSTOM: " _ tReason)
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(tProposal.target.scope, ..#SOURCE, "its target is HSCUSTOM's setting")
    Set tSC = ..Confirm(tProposal.proposalId, .tStatus, .tRaw, .tAnswer, ..#TARGET)
    Do $$$AssertEquals(tStatus, 200, "the proposal confirms from a request scoped to USER: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($Select($IsObject($Get(tAnswer)) && $IsObject(tAnswer.%Get("readBack")): tAnswer.readBack.verdict, 1: ""), ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "whose read-back, taken in HSCUSTOM, matches")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SettingsText", ..#SOURCE), "<absent>|Ens.Archive.Manager|90", "HSCUSTOM holds the value")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SettingsText", ..#TARGET), tUserBefore, "and USER's settings are as they were")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>AC5: a target set from a request scoped to USER is judged against HSCUSTOM's own list of namespaces, the one the proposal read in: USER is listed for HSCUSTOM and is stored,
/// where USER's own list holds no namespace at all.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.InteropArchiveSettingSet.ConfirmProblem</method> judge a target by the confirming request's namespace -- this goes red.</p>
Method TestATargetIsJudgedInTheProposalsNamespace()
{
    Do $$$AssertEquals(..MintSet(..#TARGETNAME, ..#TARGET, .tReason, .tProposal, .tTurn), "minted", "the target set mints in HSCUSTOM: " _ tReason)
    If '$IsObject($Get(tProposal)) Quit
    Set tSC = ..Confirm(tProposal.proposalId, .tStatus, .tRaw, .tAnswer, ..#TARGET)
    Do $$$AssertEquals(tStatus, 200, "the proposal confirms from a request scoped to USER, whose own list is empty: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SettingsText", ..#SOURCE), ..#TARGET _ "|Ens.Archive.Manager|30", "HSCUSTOM holds USER as its target")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>AC5: the agent's run, minted in HSCUSTOM and confirmed from USER, archives HSCUSTOM alone: its back-dated probes are in USER and gone from it, the one made now stays, the run is
/// recorded in HSCUSTOM's own archive tree, and USER's settings are as they were.</p>
/// <p>Mutation (Rule 19): drop <code>Namespace</code> from <parameter>OcuPilot.Screen.Tool.InteropArchiveRun.FINGERPRINTSUBJECT</parameter> -- the run reaches USER, whose own list is empty,
/// and this goes red.</p>
Method TestTheRunIsConfirmedInTheNamespaceItWasReadIn()
{
    Do ..OwnSettings()
    Set tUserBefore = $ClassMethod(..#FIXTURE, "SettingsText", ..#TARGET)
    Do ..Settings()
    Do $$$AssertTrue(..Arrange(.tIds), "HSCUSTOM's probe messages are arranged")
    Set tSC = ..EnableKey(.tPolicy)
    Do $$$AssertStatusOK(tSC, "the run's governance key is turned on")
    Try {
        Do $$$AssertEquals(..MintRun(.tReason, .tProposal, .tTurn), "minted", "the run mints in HSCUSTOM: " _ tReason)
        If '$IsObject($Get(tProposal)) Quit
        Do $$$AssertEquals(tProposal.target.scope _ "|" _ tProposal.target.id, ..#SOURCE _ "|" _ ..#SOURCE, "its target is HSCUSTOM")
        Set tSC = ..Confirm(tProposal.proposalId, .tStatus, .tRaw, .tAnswer, ..#TARGET)
        Do $$$AssertEquals(tStatus, 200, "the proposal confirms from a request scoped to USER: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "HeaderIds", ..#TARGET) _ "|" _ $ClassMethod(..#FIXTURE, "HeaderIds", ..#SOURCE), ..OldIds(.tIds) _ "|" _ tIds("current"), "the old messages are in USER and the one made now is the one left in HSCUSTOM")
        Do $$$AssertEquals(..HistoryValue("Total messages archived"), 5, "and HSCUSTOM's history reads the run")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "SettingsText", ..#TARGET), tUserBefore, "USER's settings are as they were")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the agent leg raised")
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
}

/// <p>AC5: the lock test at the confirm runs in the proposal's namespace: with HSCUSTOM's archive lock held by a child job, the agent's run minted in HSCUSTOM and confirmed from USER,
/// whose lock is free, is refused and moves nothing.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.ArchiveTake</method> take the lock in USER -- this goes red.</p>
Method TestTheRunConfirmedElsewhereIsRefusedWhileItsOwnNamespaceIsArchiving()
{
    Do ..Settings()
    Do $$$AssertTrue(..Arrange(.tIds), "HSCUSTOM's probe messages are arranged")
    Set tSC = ..EnableKey(.tPolicy)
    Do $$$AssertStatusOK(tSC, "the run's governance key is turned on")
    Try {
        Do $$$AssertEquals(..MintRun(.tReason, .tProposal, .tTurn), "minted", "the run mints in HSCUSTOM: " _ tReason)
        If '$IsObject($Get(tProposal)) Quit
        Do $$$AssertTrue(##class(OcuPilot.Test.InteropArchiveRefusals).StartHolder(), "the lock-holding job holds HSCUSTOM's lock")
        Set tSC = ..Confirm(tProposal.proposalId, .tStatus, .tRaw, .tAnswer, ..#TARGET)
        Do $$$AssertTrue(tStatus '= 200, "the confirm from USER is refused while HSCUSTOM is archiving: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "HeaderIds", ..#TARGET) _ "|" _ $ClassMethod(..#FIXTURE, "HeaderIds", ..#SOURCE), "|" _ ..OldIds(.tIds) _ "," _ tIds("current"), "and nothing was moved")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the agent leg raised")
    }
    Do $$$AssertTrue(##class(OcuPilot.Test.InteropArchiveRefusals).StopHolder(), "the holder lets go and ends")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tPolicy), "the policy found before the test is put back")
}

}
