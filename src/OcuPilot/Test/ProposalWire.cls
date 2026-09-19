/// <p>Pins what a turn's proposals look like on the wire (Story 5.1, AD-6, AD-13): the projection
/// the progress payload carries, its owner gate, and the fact that the stored body is not part of
/// it.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot's protected state, an account holding
/// <code>%All</code>, and the compiled source of <class>OcuPilot.Api.Turn</class>. It calls no
/// endpoint, starts no job and creates no principal, so it runs anywhere the suite runs.</p>
/// <p><b>It drives the projection rather than the route.</b> The progress route's own
/// over-the-wire test is <class>OcuPilot.Test.TurnWire</class>, which creates principals and runs
/// jobs and so is armed for a throwaway container only. What this class adds is the projection
/// that route hands to the response writer, plus the structural assertion that the handler reads
/// it inside its owner gate and nowhere else.</p>
Class OcuPilot.Test.ProposalWire Extends %UnitTest.TestCase
{

Parameter PROBEUSER = "OcuPilotProbeProposalWire";

Parameter OTHERUSER = "OcuPilotProbeProposalWireOther";

Parameter SCREEN = "OcuPilot.Test.ProposalScreen";

Parameter MINT = "OcuPilot.Test.ProposalMint";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter FRESH = "{""Enabled"":false,""Description"":""before"",""Resource"":""""}";

/// <p>The keys the progress payload's <code>proposals[]</code> entry carries, comma-separated.</p>
Parameter WIREKEYS = "proposalId,target,expiresAt,tool,changed,unchangedCount,rationale,expectedImpact,reverse,state";

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

/// <p>Mint one proposal for <var>pUser</var> on turn <var>pTurnKey</var>, changing
/// <var>pDescription</var>.</p>
Method Seed(pUser As %String, pTurnKey As %String, pDescription As %String, Output pKey As %String) As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESH)
    Set tSC = $ClassMethod(..#MINT, "Mint", ..#SCREEN, "probe.proposal.update", pUser, "probe-conv", pTurnKey, {"Name": "/csp/probe", "Description": (pDescription), "rationale": "why", "expectedImpact": "what", "reverse": "how"}, ..#LIMITS, .tProposal, .tHttp, .tFault, "WebApp.App", "name", "/csp/probe", "Name", $ListBuild("Description"))
    If $$$ISERR(tSC) Quit tSC
    Set pKey = tProposal.%Get("proposalId")
    Quit $$$OK
}

/// <p>The wire row carries the triple, the diff, the counts and the agent's words, and nothing
/// else.</p>
Method TestTheWireRowCarriesTheTripleTheDiffAndTheState()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).SeedTurn(..#PROBEUSER, "completed", .tTurn), "a turn is seeded")
    Do $$$AssertStatusOK(..Seed(..#PROBEUSER, tTurn, "after", .tKey), "and one proposal is minted on it")

    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedRowsForTurn(tTurn, ..#PROBEUSER, .tRows)
    Do $$$AssertStatusOK(tSC, "the turn's proposals are read")
    Do $$$AssertEquals(tRows.%Size(), 1, "one row comes back")
    Set tRow = tRows.%Get(0)

    Set tSeen = 0
    Set tIterator = tRow.%GetIterator()
    While tIterator.%GetNext(.tName, .tValue) {
        Do $$$AssertTrue($ListFind($ListFromString(..#WIREKEYS), tName) > 0, "the wire row carries only declared keys, not '" _ tName _ "'")
        Set tSeen = tSeen + 1
    }
    Do $$$AssertEquals(tSeen, $Length(..#WIREKEYS, ","), "and it carries every one of them")

    Do $$$AssertEquals(tRow.%Get("proposalId"), tKey, "it names the proposal")
    Do $$$AssertEquals(tRow.%Get("tool"), "probe.proposal.update", "and the tool")
    Do $$$AssertEquals(tRow.%Get("state"), ##class(OcuPilot.Kernel.State.Propose).#STATELIVE, "and its state")
    Do $$$AssertEquals(tRow.%Get("target").%Get("type"), "web-application", "the target's entity type")
    Do $$$AssertEquals(tRow.%Get("target").%Get("scope"), "instance", "its scope")
    Do $$$AssertEquals(tRow.%Get("target").%Get("id"), "/csp/probe", "and its id")
    Do $$$AssertEquals(tRow.%Get("changed").%Size(), 1, "one field changed")
    Do $$$AssertEquals(tRow.%Get("changed").%Get(0).%Get("field"), "Description", "and the diff names it")
    Do $$$AssertEquals(tRow.%Get("changed").%Get(0).%Get("before"), "before", "with the value before")
    Do $$$AssertEquals(tRow.%Get("changed").%Get(0).%Get("after"), "after", "and the value after")
    Do $$$AssertEquals(tRow.%Get("unchangedCount"), 2, "the other two properties are sent unchanged")
    Do $$$AssertEquals(tRow.%Get("rationale"), "why", "the agent's rationale travels")
    Do $$$AssertEquals(tRow.%Get("expectedImpact"), "what", "its expected impact")
    Do $$$AssertEquals(tRow.%Get("reverse"), "how", "and its reversal")
    Do $$$AssertNotEquals(tRow.%Get("expiresAt"), "", "and the row says when it stops being confirmable")
}

/// <p>AD-6: the card renders the diff and the unchanged count; the body the write will send is
/// never on the wire.</p>
Method TestTheStoredBodyIsNotOnTheWire()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).SeedTurn(..#PROBEUSER, "completed", .tTurn), "a turn is seeded")
    Do $$$AssertStatusOK(..Seed(..#PROBEUSER, tTurn, "after", .tKey), "and one proposal is minted on it")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedRowsForTurn(tTurn, ..#PROBEUSER, .tRows)
    Do $$$AssertStatusOK(tSC, "the turn's proposals are read")
    Set tJson = tRows.%ToJSON()
    Do $$$AssertEquals(tJson [ "Resource", 0, "no payload property reaches the wire")
    Do $$$AssertEquals(tJson [ "fingerprint", 0, "nor the fingerprint")
    Do $$$AssertEquals(tJson [ "token", 0, "and certainly not the token")
}

/// <p>AD-33: a poll for a turn the caller does not own answers nothing, and the store's own
/// predicate is what decides it.</p>
Method TestAnotherUsersTurnAnswersNoProposals()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).SeedTurn(..#PROBEUSER, "completed", .tTurn), "a turn is seeded")
    Do $$$AssertStatusOK(..Seed(..#PROBEUSER, tTurn, "after", .tKey), "and one proposal is minted on it")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedRowsForTurn(tTurn, ..#OTHERUSER, .tRows)
    Do $$$AssertStatusOK(tSC, "the read succeeds for another user")
    Do $$$AssertEquals(tRows.%Size(), 0, "and answers no rows at all")
}

/// <p>A turn that minted none answers an empty array, so a reader never tells "no proposals" from
/// "the key is missing".</p>
Method TestATurnThatMintedNoneAnswersAnEmptyArray()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).SeedTurn(..#PROBEUSER, "completed", .tTurn), "a turn is seeded")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedRowsForTurn(tTurn, ..#PROBEUSER, .tRows)
    Do $$$AssertStatusOK(tSC, "the read succeeds")
    Do $$$AssertEquals(tRows.%ToJSON(), "[]", "and answers an empty array")
}

/// <p>Several proposals of one turn come back oldest first, so the cards stack in the order they
/// were minted.</p>
Method TestTheTurnsProposalsComeBackOldestFirst()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).SeedTurn(..#PROBEUSER, "completed", .tTurn), "a turn is seeded")
    Do $$$AssertStatusOK(..Seed(..#PROBEUSER, tTurn, "first", .tFirst), "the first proposal is minted")
    Do $$$AssertStatusOK(..Seed(..#PROBEUSER, tTurn, "second", .tSecond), "and the second")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedRowsForTurn(tTurn, ..#PROBEUSER, .tRows)
    Do $$$AssertStatusOK(tSC, "the turn's proposals are read")
    Do $$$AssertEquals(tRows.%Size(), 2, "both come back")
    Do $$$AssertEquals(tRows.%Get(0).%Get("proposalId"), tFirst, "the first one minted comes first")
    Do $$$AssertEquals(tRows.%Get(1).%Get("proposalId"), tSecond, "and the second second")
}

/// <p>The progress handler reads the turn's proposals, and does so after the owner gate that
/// answers 404 for a turn the caller does not own.</p>
Method TestTheProgressHandlerReadsThemInsideItsOwnerGate()
{
    Set tSC = ##class(%Compiler.UDL.TextServices).GetTextAsString($Namespace, "OcuPilot.Api.Turn", .tSource)
    Do $$$AssertStatusOK(tSC, "the handler's source is readable")
    Set tHandler = $Piece(tSource, "ClassMethod HandleProgress", 2)
    Set tHandler = $Piece(tHandler, "ClassMethod HandleStop", 1)
    Do $$$AssertTrue(tHandler [ "GuardedRowsForTurn", "the progress handler reads the turn's proposals")
    Do $$$AssertTrue($Find(tHandler, "GuardedForOwner") < $Find(tHandler, "GuardedRowsForTurn"), "after the owner gate, never before it")
    Do $$$AssertTrue($Find(tHandler, "GuardedRowsForTurn") < $Find(tHandler, "Response).JSON"), "and before the payload is written")
}

}
