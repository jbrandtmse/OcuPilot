/// <p>Pins the claim itself (Story 5.3, AD-34): the conditional update has exactly one winner, the
/// loser reads the row's terminal state, and the sibling cancel commits with the burn rather than
/// after it.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot's protected state and an account holding
/// <code>%All</code>. It drives
/// <method>OcuPilot.Kernel.State.Propose.GuardedClaimAndClose</method> directly -- no port is
/// called and nothing on the instance is written -- and every row it seeds names a user starting
/// with <parameter>OcuPilot.Test.ProposalFixture.PROBEPREFIX</parameter>, removed in
/// <method>OnAfterOneTest</method>.</p>
Class OcuPilot.Test.ProposalRace Extends %UnitTest.TestCase
{

Parameter PROBEUSER = "OcuPilotProbeProposalRacer";

Parameter OTHERUSER = "OcuPilotProbeProposalRacerTwo";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The two scoped targets, built through <method>OcuPilot.Kernel.EntityRef.Key</method> so the
/// separator is the one the store actually holds rather than a transcription of it.</p>
ClassMethod TargetOne() As %String
{
    Do ##class(OcuPilot.Kernel.EntityRef).Key("web-application", "instance", "/csp/ocupilotproberace", .tKey)
    Quit tKey
}

ClassMethod TargetTwo() As %String
{
    Do ##class(OcuPilot.Kernel.EntityRef).Key("web-application", "instance", "/csp/ocupilotproberaceother", .tKey)
    Quit tKey
}

Method OnAfterOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).Remove(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser(..#OTHERUSER)
    Do $$$AssertStatusOK(tSC, "and so are the second user's")
    Quit $$$OK
}

/// <p>Seed one live proposal on <var>pTargetRef</var> for <var>pUser</var> and answer its id.</p>
Method Seed(pTargetRef As %String, pUser As %String = {..#PROBEUSER}) As %String
{
    Kill tValues
    Set tValues("user") = pUser
    Set tValues("convKey") = "probe-race-conv"
    Set tValues("turnKey") = "probe-race-turn"
    Set tValues("toolName") = "webapp.list.update"
    Set tValues("targetRef") = pTargetRef
    Set tValues("fingerprint") = "0"
    Set tValues("arguments") = "{}"
    Set tValues("payload") = "{}"
    Set tValues("diff") = "[]"
    Set tValues("unchangedCount") = 0
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedProposal(.tValues, .tKey, .tToken)
    Do $$$AssertStatusOK(tSC, "a probe proposal is seeded")
    If $$$ISERR(tSC) Quit ""
    Quit tKey
}

/// <p>AC5, AD-34: two claims of the same row at the same expected version; one commits, the other
/// is told the row's terminal state and never retries.</p>
/// <p>The conditional update's three clauses are each falsified by a method of its own below --
/// the burn, the state and the version -- because together they over-determine this one: removing
/// any single clause leaves the other two refusing the loser.</p>
Method TestExactlyOneClaimWins()
{
    Set tKey = ..Seed(..TargetOne())
    If tKey = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedRowVersion(tKey, .tVersion), "the row's version reads")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedClaimAndClose(tKey, tVersion, ..TargetOne(), .tFirstWon, .tFirstTerminal), "the first claim runs")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedClaimAndClose(tKey, tVersion, ..TargetOne(), .tSecondWon, .tSecondTerminal), "and so does the second")

    Do $$$AssertEquals(tFirstWon, 1, "the first claim wins")
    Do $$$AssertEquals(tSecondWon, 0, "the second does not")
    Do $$$AssertEquals(tSecondTerminal, "confirmed", "and reads the row's terminal state, which is what it is refused with")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "Burned"), 1, "the row is burned exactly once")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "confirmed", "and carries the terminal state the winner wrote")
}

/// <p>AC6, AD-34: every other live proposal on the same scoped target closes
/// <code>canceled</code> reason <code>sibling</code> in the winner's own transaction, whoever owns
/// it; a proposal on a different target is untouched.</p>
/// <p>Mutation: move the sibling update after <code>TCOMMIT</code> in
/// <method>OcuPilot.Kernel.State.Propose.GuardedClaimAndClose</method> -- the structural assertion
/// below goes red; removing the sibling update altogether reddens the state assertions too.</p>
Method TestTheSiblingsOnTheSameTargetCloseWithTheClaim()
{
    Set tWinner = ..Seed(..TargetOne())
    Set tSibling = ..Seed(..TargetOne())
    Set tOtherUsers = ..Seed(..TargetOne(), ..#OTHERUSER)
    Set tElsewhere = ..Seed(..TargetTwo())
    If (tWinner = "") || (tSibling = "") || (tOtherUsers = "") || (tElsewhere = "") Quit

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedRowVersion(tWinner, .tVersion), "the winner's version reads")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedClaimAndClose(tWinner, tVersion, ..TargetOne(), .tWon, .tTerminal), "the claim runs")
    Do $$$AssertEquals(tWon, 1, "and wins")

    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tSibling, "State"), "canceled", "the sibling on the same target is canceled")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tSibling, "ClosedReason"), "sibling", "with the reason that names why")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tOtherUsers, "State"), "canceled", "another account's proposal on that target closes too -- the target moved for everyone")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tElsewhere, "State"), "live", "and a proposal on a different target is untouched")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tSibling, "Burned"), 0, "a canceled sibling is not burned: its token was never spent")

    ; The window AC6 forbids is one the row states cannot show: both updates commit together or
    ; neither does, so the claim's own frame is what is asserted.
    Set tSource = ""
    Do ##class(%Compiler.UDL.TextServices).GetTextAsString($Namespace, "OcuPilot.Kernel.State.Propose", .tSource)
    Set tBody = $Piece($Piece(tSource, "ClassMethod GuardedClaimAndClose", 2), "ClassMethod GuardedClose", 1)
    Set tSiblingAt = $Find(tBody, "ClosedReason = ? WHERE %EXACT(TargetRef)")
    Do $$$AssertTrue(tSiblingAt > 0, "the sibling update is in the claim")
    Do $$$AssertTrue($Find(tBody, "TSTART") < tSiblingAt, "opened inside the claim's transaction")
    Do $$$AssertTrue(tSiblingAt < $Find(tBody, "TCOMMIT"), "and committed with it, never after it")
}

/// <p>A claim on a row whose token has already been spent loses, whatever state the row carries:
/// the burn is a clause of the conditional update, not an inference from the state.</p>
/// <p>Mutation: drop the <code>Burned = 0</code> clause from the conditional <code>UPDATE</code> in
/// <method>OcuPilot.Kernel.State.Propose.GuardedClaimAndClose</method> -- this goes red.</p>
Method TestABurnedRowIsNotClaimable()
{
    Set tKey = ..Seed(..TargetOne())
    If tKey = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).SetBurned(tKey, 1), "the row's token is marked spent")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "live", "while its state is still live, so only the burn can refuse the claim")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedRowVersion(tKey, .tVersion), "its version reads")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedClaimAndClose(tKey, tVersion, ..TargetOne(), .tWon, .tTerminal), "a claim on it runs")
    Do $$$AssertEquals(tWon, 0, "and loses")
}

/// <p>A claim against a version the row no longer carries loses, which is the same refusal a
/// second claim earns -- the version is read from the store, never from a request.</p>
Method TestAStaleVersionLoses()
{
    Set tKey = ..Seed(..TargetOne())
    If tKey = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedRowVersion(tKey, .tVersion), "the row's version reads")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedClaimAndClose(tKey, tVersion + 5, ..TargetOne(), .tWon, .tTerminal), "a claim at a version the row never carried runs")
    Do $$$AssertEquals(tWon, 0, "and loses")
    Do $$$AssertEquals(tTerminal, "live", "reading the state the row is actually in")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "Burned"), 0, "and the row is untouched")
}

/// <p>A claim on a row past its expiry loses: the read-time projection and the stored state agree,
/// because the state clause of the conditional update is the same <code>live</code> the projection
/// no longer reports (DW-1209).</p>
Method TestAnExpiredRowIsNotClaimable()
{
    Set tKey = ..Seed(..TargetOne())
    If tKey = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).AgeExpiry(tKey, 3600), "the row is aged past its window")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tKey, .tFound, .tValues), "it reads back")
    Do $$$AssertEquals($Get(tValues("state")), "expired", "projected expired at read, before anything flipped the stored value")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "live", "while the stored value is still live")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedExpireStale(..#PROBEUSER), "the stale row is flipped on the next touch")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "State"), "expired", "and the stored value now agrees with the projection")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedRowVersion(tKey, .tVersion), "its version reads")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedClaimAndClose(tKey, tVersion, ..TargetOne(), .tWon, .tTerminal), "a claim on it runs")
    Do $$$AssertEquals(tWon, 0, "and loses")
    Do $$$AssertEquals(tTerminal, "expired", "with the state the loser is refused with")
}

}
