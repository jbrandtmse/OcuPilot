/// <p>Pins the write gate (Story 5.1, AD-6, AD-40): a claim succeeds only against a valid,
/// unexpired, unburned token held by the minting user on a turn that ended normally, and each of
/// the six refusals is driven one at a time.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot's protected state and an account holding
/// <code>%All</code>. Every proposal is minted from
/// <class>OcuPilot.Test.ProposalFixture</class>'s armed object, so no endpoint is called; every
/// turn and proposal names a probe user and is removed in <method>OnAfterOneTest</method>.</p>
Class OcuPilot.Test.ProposalWrite Extends %UnitTest.TestCase
{

Parameter PROBEUSER = "OcuPilotProbeProposalClaimer";

Parameter OTHERUSER = "OcuPilotProbeProposalOther";

Parameter SCREEN = "OcuPilot.Test.ProposalScreen";

Parameter MINT = "OcuPilot.Test.ProposalMint";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter FRESH = "{""Enabled"":false,""Description"":""before""}";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).Remove(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit $$$OK
}

/// <p>Seed a turn in <var>pTurnState</var> and mint one proposal on it for <var>pUser</var>.
/// <var>pKey</var> and <var>pToken</var> are the claim's two halves.</p>
Method Seed(pTurnState As %String, pUser As %String, Output pKey As %String, Output pToken As %String) As %Status
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(pUser, pTurnState, .tTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESH)
    Set tSC = $ClassMethod(..#MINT, "Mint", ..#SCREEN, "probe.proposal.update", pUser, "probe-conv", tTurnKey, {"Name": "/csp/probe", "Enabled": true}, ..#LIMITS, .tProposal, .tHttp, .tFault, "WebApp.App", "name", "/csp/probe", "Name", $ListBuild("Enabled"))
    If $$$ISERR(tSC) Quit tSC
    Set pKey = tProposal.%Get("proposalId")
    Set pToken = ##class(OcuPilot.Test.ProposalFixture).Field(pKey, "Token")
    Quit $$$OK
}

/// <p>The refusal code <method>OcuPilot.Kernel.Proposal.Write.Claim</method> answers for one call.</p>
Method ClaimCode(pKey As %String, pToken As %String, pUser As %String) As %String
{
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Write).Claim(pKey, pToken, pUser, .tProposal, .tCode)
    If $$$ISOK(tSC) Quit ""
    Quit tCode
}

/// <p>AD-40: a turn ends the moment it emits the card, so the ordinary path runs through a turn
/// that ended <code>completed</code> and must not be caught by the abnormal-end rule.</p>
/// <p>Mutation: make <method>OcuPilot.Kernel.Proposal.Write.Claim</method> also refuse a
/// <code>completed</code> turn -- this goes red, which is the assertion that is easy to
/// under-read.</p>
Method TestAProposalOnACompletedTurnIsClaimable()
{
    Do $$$AssertStatusOK(..Seed("completed", ..#PROBEUSER, .tKey, .tToken), "a proposal is minted on a completed turn")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Write).Claim(tKey, tToken, ..#PROBEUSER, .tProposal, .tCode)
    Do $$$AssertStatusOK(tSC, "the claim succeeds")
    Do $$$AssertEquals(tCode, "", "with no refusal code")
    Do $$$AssertEquals($Get(tProposal("proposalId")), tKey, "and it hands back the stored row")
    Do $$$AssertTrue($Get(tProposal("payload")) [ "Enabled", "including the payload the write executes from")
    Do $$$AssertNotEquals($Get(tProposal("fingerprint")), "", "and its fingerprint")
}

/// <p>A turn still running is claimable too: the card can be confirmed while the turn is finishing.</p>
Method TestAProposalOnARunningTurnIsClaimable()
{
    Do $$$AssertStatusOK(..Seed("running", ..#PROBEUSER, .tKey, .tToken), "a proposal is minted on a running turn")
    Do $$$AssertEquals(..ClaimCode(tKey, tToken, ..#PROBEUSER), "", "the claim succeeds")
}

/// <p>The write path refuses a call with no token, rather than leaving it to a caller.</p>
Method TestAClaimWithNoTokenIsRefused()
{
    Do $$$AssertEquals(..ClaimCode("", "", ..#PROBEUSER), ##class(OcuPilot.Kernel.Proposal.Write).#NOTOKEN, "no id and no token is refused")
    Do $$$AssertEquals(..ClaimCode("someid", "", ..#PROBEUSER), ##class(OcuPilot.Kernel.Proposal.Write).#NOTOKEN, "an id with no token is refused")
    Do $$$AssertEquals(..ClaimCode("", "sometoken", ..#PROBEUSER), ##class(OcuPilot.Kernel.Proposal.Write).#NOTOKEN, "and a token with no id is refused")
}

/// <p>A token no row carries, and a token whose row carries another id, are both unknown.</p>
Method TestATokenNoRowCarriesIsUnknown()
{
    Do $$$AssertStatusOK(..Seed("completed", ..#PROBEUSER, .tKey, .tToken), "a proposal is minted")
    Do $$$AssertEquals(..ClaimCode(tKey, "00000000000000000000000000000000", ..#PROBEUSER), ##class(OcuPilot.Kernel.Proposal.Write).#UNKNOWN, "a token no row carries is unknown")
    Do $$$AssertEquals(..ClaimCode("00000000000000000000000000000000", tToken, ..#PROBEUSER), ##class(OcuPilot.Kernel.Proposal.Write).#UNKNOWN, "and a token paired with another id is unknown")
}

/// <p>AD-6: a proposal is confirmable only by the user who minted it.</p>
/// <p>Mutation: make the claim accept another user's token -- this goes red alone.</p>
Method TestAnotherUsersTokenIsRefused()
{
    Do $$$AssertStatusOK(..Seed("completed", ..#PROBEUSER, .tKey, .tToken), "a proposal is minted by one user")
    Do $$$AssertEquals(..ClaimCode(tKey, tToken, ..#OTHERUSER), ##class(OcuPilot.Kernel.Proposal.Write).#NOTYOURS, "another user's claim is refused")
    Do $$$AssertEquals(..ClaimCode(tKey, tToken, ..#PROBEUSER), "", "and the minting user's still succeeds")
}

/// <p>AD-6: a proposal past its window is refused.</p>
/// <p>Mutation: make the claim accept an expired token -- this goes red alone.</p>
Method TestAnExpiredProposalIsRefused()
{
    Do $$$AssertStatusOK(..Seed("completed", ..#PROBEUSER, .tKey, .tToken), "a proposal is minted")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).AgeExpiry(tKey, 60), "and its window is moved into the past")
    Do $$$AssertEquals(..ClaimCode(tKey, tToken, ..#PROBEUSER), ##class(OcuPilot.Kernel.Proposal.Write).#EXPIRED, "the claim is refused as expired")
}

/// <p>AD-6: a single-use token is spent once.</p>
/// <p>Mutation: make the claim accept a burned token -- this goes red alone.</p>
Method TestABurnedTokenIsRefused()
{
    Do $$$AssertStatusOK(..Seed("completed", ..#PROBEUSER, .tKey, .tToken), "a proposal is minted")
    Do $$$AssertEquals(..ClaimCode(tKey, tToken, ..#PROBEUSER), "", "the claim succeeds while the token is unspent")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).SetBurned(tKey, 1), "and the token is burned")
    Do $$$AssertEquals(..ClaimCode(tKey, tToken, ..#PROBEUSER), ##class(OcuPilot.Kernel.Proposal.Write).#BURNED, "the claim is then refused as burned")
}

/// <p>AD-40: a turn that ended abnormally leaves its proposals unconfirmable.</p>
/// <p>Mutation: make the claim accept a <code>stopped</code> turn -- this goes red alone.</p>
Method TestATurnThatEndedAbnormallyLeavesItsProposalsUnconfirmable()
{
    For tState = "stopped", "abandoned", "failed" {
        Do $$$AssertStatusOK(..Seed(tState, ..#PROBEUSER, .tKey, .tToken), tState _ ": a proposal is minted on such a turn")
        Do $$$AssertEquals(..ClaimCode(tKey, tToken, ..#PROBEUSER), ##class(OcuPilot.Kernel.Proposal.Write).#TURNENDED, tState _ ": the claim is refused")
    }
}

/// <p>A proposal whose turn record is gone is not claimable either: the retention window is what
/// keeps that from happening inside the proposal's own window.</p>
Method TestAProposalWhoseTurnRecordIsGoneIsRefused()
{
    Do $$$AssertStatusOK(..Seed("completed", ..#PROBEUSER, .tKey, .tToken), "a proposal is minted")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Turn).GuardedDelete(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "TurnKey")), "and its turn record is removed")
    Do $$$AssertEquals(..ClaimCode(tKey, tToken, ..#PROBEUSER), ##class(OcuPilot.Kernel.Proposal.Write).#TURNENDED, "the claim is refused")
}

/// <p>The retention window outlives the proposal window, so the case above cannot arise from
/// ageing alone.</p>
/// <p>Mutation: raise <parameter>OcuPilot.Kernel.Agent.Limits.PROPOSALEXPIRYSECONDS</parameter>
/// above <parameter>RETENTIONSECONDS</parameter> -- this goes red.</p>
Method TestRetentionOutlivesTheProposalWindow()
{
    Set tRetention = +$Parameter(..#LIMITS, "RETENTIONSECONDS")
    Set tExpiry = +$Parameter(..#LIMITS, "PROPOSALEXPIRYSECONDS")
    Do $$$AssertTrue(tExpiry > 0, "the proposal window is a positive number of seconds")
    Do $$$AssertTrue(tRetention >= tExpiry, "and a turn record is kept at least as long as its proposals stay claimable")
}

/// <p>The six refusal codes are distinct, and each is a dotted-uppercase machine code
/// (AD-39).</p>
Method TestTheRefusalCodesAreDistinctAndWellFormed()
{
    Set tClass = "OcuPilot.Kernel.Proposal.Write"
    Set tSeen = ""
    For tName = "NOTOKEN", "UNKNOWN", "NOTYOURS", "EXPIRED", "BURNED", "TURNENDED" {
        Set tCode = $Parameter(tClass, tName)
        Do $$$AssertTrue($Match(tCode, ##class(OcuPilot.Api.Error).#CODEPATTERN), tName _ ": is a dotted-uppercase machine code")
        Do $$$AssertEquals($ListFind(tSeen, tCode), 0, tName _ ": is not a code another refusal already uses")
        Set tSeen = tSeen _ $ListBuild(tCode)
    }
    Do $$$AssertEquals($ListLength(tSeen), 6, "and there are six of them")
}

}
