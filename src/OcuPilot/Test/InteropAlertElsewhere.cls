/// <p>Pins Story 24.17 Batch 1's proposals against the namespace they were read in (AD-6, AD-52): the agent's update of a managed alert, minted in <code>USER</code> and confirmed by a request
/// scoped to <code>HSCUSTOM</code>, acts in <code>USER</code> alone even when <code>HSCUSTOM</code> holds a probe under the same id, which is as it was. Every judgment at the confirm, the fresh
/// read, the owner list, the administration pair and the vendor call, runs in the proposal's namespace.</p>
/// <p><b>What it needs from the environment:</b> what <class>OcuPilot.Test.InteropAlertCase</class> needs. It removes every probe and every owner it made.</p>
Class OcuPilot.Test.InteropAlertElsewhere Extends OcuPilot.Test.InteropAlertCase
{

/// <p>Arrange a probe in USER and one in HSCUSTOM under the same id, the second owned by <var>pOther</var>; answer the id, or 0.</p>
Method Arrange(pOther As %String = "") As %Integer
{
    Set tId = $ClassMethod(..#FIXTURE, "NextId", ..#SOURCE)
    Set tOtherNext = $ClassMethod(..#FIXTURE, "NextId", ..#OTHER)
    If tOtherNext > tId Set tId = tOtherNext
    Set tUser = $ClassMethod(..#FIXTURE, "ProbeWithId", ..#SOURCE, tId)
    Set tHsc = $ClassMethod(..#FIXTURE, "ProbeWithId", ..#OTHER, tId, pOther)
    If (tUser '= tId) || (tHsc '= tId) Quit 0
    Quit tId
}

/// <p>AC5: the agent's update, minted in USER and confirmed from HSCUSTOM, closes USER's alert and leaves HSCUSTOM's alert of the same id as it was, and publishes the event for USER.</p>
/// <p>Mutation (Rule 19): drop <code>Namespace</code> from <parameter>OcuPilot.Screen.Tool.InteropManagedAlertUpdate.FINGERPRINTSUBJECT</parameter> -- the confirm reaches HSCUSTOM's alert and this
/// goes red.</p>
Method TestTheUpdateIsConfirmedInTheNamespaceItWasReadIn()
{
    Set tId = ..Arrange()
    Do $$$AssertTrue(tId > 0, "a probe under one id is stored in each namespace")
    If 'tId Quit
    Do $$$AssertEquals(..Mint(tId, {"Open": false, "Reason": "closing it in USER"}, .tReason, .tProposal, .tTurn), "minted", "the update mints in USER: " _ tReason)
    If '$IsObject($Get(tProposal)) Quit
    Try {
        Do $$$AssertEquals(tProposal.target.scope _ "|" _ tProposal.target.id, ..#SOURCE _ "|" _ tId, "its target is USER's alert")
        Set tSC = ..Confirm(tProposal.proposalId, .tStatus, .tRaw, .tAnswer, ..#OTHER)
        Do $$$AssertEquals(tStatus, 200, "the proposal confirms from a request scoped to HSCUSTOM: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($Select($IsObject($Get(tAnswer)) && $IsObject(tAnswer.%Get("readBack")): tAnswer.readBack.verdict, 1: ""), ##class(OcuPilot.Kernel.Proposal.ReadBack).#MATCHES, "whose read-back, taken in USER, matches")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "State", ..#SOURCE, tId), "|0|0|1", "USER's alert is closed, with one history row")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "State", ..#OTHER, tId), "|1|0|0", "and HSCUSTOM's alert of the same id is as it was")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the leg raised")
    }
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

/// <p>AC5: an owner is judged against the owner list of the proposal's namespace: a user the classic form offers for USER only is accepted at a confirm from HSCUSTOM, whose own list does not
/// hold the user.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.InteropPort.AlertOwnerNames</method> list the owners of the request's scope in place of the namespace it is given -- this goes red.</p>
Method TestAnOwnerIsJudgedInTheProposalsNamespace()
{
    Set tUser = "OcuP2417Elsewhere"
    Set tPassword = "OcuP2417" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "CreateOwner", tUser, tPassword), "the owner is created, offered for USER only")
    Try {
        Set tId = ..Arrange()
        Do $$$AssertTrue(tId > 0, "a probe under one id is stored in each namespace")
        If 'tId Quit
        Do $$$AssertEquals(..Mint(tId, {"Owner": (tUser), "Reason": "assigning in USER"}, .tReason, .tProposal, .tTurn), "minted", "the assignment mints in USER: " _ tReason)
        If '$IsObject($Get(tProposal)) Quit
        Set tSC = ..Confirm(tProposal.proposalId, .tStatus, .tRaw, .tAnswer, ..#OTHER)
        Do $$$AssertEquals(tStatus, 200, "the proposal confirms from HSCUSTOM, whose own owners do not list the user: " _ $Extract($Get(tRaw), 1, 300))
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "State", ..#SOURCE, tId), tUser _ "|1|0|1", "USER's alert is assigned")
        Do $$$AssertEquals($ClassMethod(..#FIXTURE, "State", ..#OTHER, tId), "|1|0|0", "and HSCUSTOM's is as it was")
        Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the leg raised")
    }
    Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "DropOwner", tUser), "the owner is removed")
}

/// <p>AC5: an alert that is gone from the proposal's namespace closes the confirm as moved although HSCUSTOM holds one under the same id, so the fresh read is USER's.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.InteropAction.PortQuery</method> drop the payload's namespace -- the confirm reads HSCUSTOM's alert and this goes red.</p>
Method TestTheFreshReadAtTheConfirmIsTheProposalsNamespaces()
{
    Set tId = ..Arrange()
    Do $$$AssertTrue(tId > 0, "a probe under one id is stored in each namespace")
    If 'tId Quit
    Do $$$AssertEquals(..Mint(tId, {"Open": false, "Reason": "closing it in USER"}, .tReason, .tProposal, .tTurn), "minted", "the update mints in USER: " _ tReason)
    If '$IsObject($Get(tProposal)) Quit
    Do $ClassMethod(..#FIXTURE, "Delete", ..#OTHER, tId)
    Do $ClassMethod(..#FIXTURE, "Delete", ..#SOURCE, tId)
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "State", ..#SOURCE, tId) _ "|" _ $ClassMethod(..#FIXTURE, "State", ..#OTHER, tId), "<none>|<none>", "both alerts of the id are gone")
    Set tHsc = $ClassMethod(..#FIXTURE, "ProbeWithId", ..#OTHER, tId)
    Do $$$AssertEquals(tHsc, tId, "HSCUSTOM holds an alert of the id again, USER none")
    Set tSC = ..Confirm(tProposal.proposalId, .tStatus, .tRaw, .tAnswer, ..#OTHER)
    Do $$$AssertNotEquals(tStatus, 200, "the confirm is refused, though HSCUSTOM holds an alert of the id: " _ $Extract($Get(tRaw), 1, 300))
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "State", ..#OTHER, tId), "|1|0|0", "and HSCUSTOM's alert is as it was")
    Do ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn($Get(tTurn))
}

}
