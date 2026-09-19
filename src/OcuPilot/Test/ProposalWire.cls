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
Parameter WIREKEYS = "proposalId,target,expiresAt,tool,changed,unchangedCount,rationale,expectedImpact,reverse,state,auditWarning";

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
    Quit ..SeedIn(pUser, "probe-conv", pTurnKey, pDescription, "probe.proposal.update", 0, .pKey)
}

/// <p>Mint one proposal for <var>pUser</var> in conversation <var>pConvKey</var> on turn
/// <var>pTurnKey</var>, under tool <var>pTool</var>, changing <var>pDescription</var>.
/// <var>pAuditing</var> adds the auditing flag the kernel's own warning predicate reads, so the
/// warning can be driven from a value rather than from a tool that has not shipped yet.</p>
Method SeedIn(pUser As %String, pConvKey As %String, pTurnKey As %String, pDescription As %String, pTool As %String, pAuditing As %Boolean, Output pKey As %String) As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESH)
    Set tArgs = {"Name": "/csp/probe", "Description": (pDescription), "rationale": "why", "expectedImpact": "what", "reverse": "how"}
    If pAuditing '= "" Do tArgs.%Set($Parameter("OcuPilot.Kernel.Proposal.Mint", "AUDITINGFIELD"), ''pAuditing, "boolean")
    Set tSC = $ClassMethod(..#MINT, "Mint", ..#SCREEN, pTool, pUser, pConvKey, pTurnKey, tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, "WebApp.App", "name", "/csp/probe", "Name", $ListBuild("Description"))
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

/// <p>AD-10, AD-15: the in-card audit warning is the kernel's own predicate, projected on the wire
/// row -- true for the auditing write turning auditing off, false for every tool that ships
/// today.</p>
/// <p>Mutation: make <method>OcuPilot.Kernel.Proposal.Mint.WarnsAuditingOff</method> answer 0
/// unconditionally -- the first half goes red; make it answer 1 unconditionally -- the second
/// half does.</p>
Method TestTheAuditWarningIsTheKernelsPredicateOnTheWire()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).SeedTurn(..#PROBEUSER, "completed", .tTurn), "a turn is seeded")
    Set tAuditTool = $Parameter("OcuPilot.Kernel.Proposal.Mint", "AUDITINGTOOL")
    Do $$$AssertStatusOK(..SeedIn(..#PROBEUSER, "probe-conv", tTurn, "after", tAuditTool, 0, .tWarned), "the auditing write is minted with auditing off")
    Do $$$AssertStatusOK(..SeedIn(..#PROBEUSER, "probe-conv", tTurn, "other", "probe.proposal.update", "", .tQuiet), "and an ordinary write beside it")

    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedRowsForTurn(tTurn, ..#PROBEUSER, .tRows)
    Do $$$AssertStatusOK(tSC, "the turn's proposals are read")
    Do $$$AssertEquals(tRows.%Size(), 2, "both come back")
    Do $$$AssertEquals(tRows.%Get(0).%GetTypeOf("auditWarning"), "boolean", "the warning is a boolean on the wire")
    Do $$$AssertEquals(tRows.%Get(0).%Get("auditWarning"), 1, "true for the write that turns auditing off")
    Do $$$AssertEquals(tRows.%Get(1).%Get("auditWarning"), 0, "and false for an ordinary write")
}

/// <p>AD-6, AD-9, DW-1213: a restored conversation's proposals are read once for the whole
/// transcript and grouped by the turn that minted them, so a reload can render each turn's own
/// cards.</p>
/// <p>Mutation: key <method>OcuPilot.Kernel.State.Propose.GuardedRowsForConvo</method> on
/// <code>TurnKey</code> instead of <code>ConvKey</code> -- the two-turn grouping goes red.</p>
Method TestTheConversationReadGroupsProposalsByTurn()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).SeedTurn(..#PROBEUSER, "completed", .tFirstTurn), "a first turn is seeded")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).SeedTurn(..#PROBEUSER, "completed", .tSecondTurn), "and a second")
    Do $$$AssertStatusOK(..SeedIn(..#PROBEUSER, "probe-conv-a", tFirstTurn, "one", "probe.proposal.update", "", .tOne), "one proposal on the first turn")
    Do $$$AssertStatusOK(..SeedIn(..#PROBEUSER, "probe-conv-a", tSecondTurn, "two", "probe.proposal.update", "", .tTwo), "one on the second")
    Do $$$AssertStatusOK(..SeedIn(..#PROBEUSER, "probe-conv-b", tSecondTurn, "three", "probe.proposal.update", "", .tThree), "and one in another conversation")

    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedRowsForConvo("probe-conv-a", ..#PROBEUSER, .tByTurn)
    Do $$$AssertStatusOK(tSC, "the conversation's proposals are read")
    Do $$$AssertEquals($Data(tByTurn(tFirstTurn)), 1, "the first turn has its own subscript")
    Do $$$AssertEquals($Data(tByTurn(tSecondTurn)), 1, "and so does the second")
    Do $$$AssertEquals(tByTurn(tFirstTurn).%Size(), 1, "one row under the first turn")
    Do $$$AssertEquals(tByTurn(tFirstTurn).%Get(0).%Get("proposalId"), tOne, "and it is the one minted there")
    Do $$$AssertEquals(tByTurn(tSecondTurn).%Size(), 1, "one row under the second turn")
    Do $$$AssertEquals(tByTurn(tSecondTurn).%Get(0).%Get("proposalId"), tTwo, "and it is that turn's own")
    Do $$$AssertEquals(tByTurn(tFirstTurn).%Get(0).%Get("state"), ##class(OcuPilot.Kernel.State.Propose).#STATELIVE, "the wire state stays live: a restored card is shown terminal by the client")
}

/// <p>AD-33: a conversation read for a user who does not own it answers nothing, and the store's
/// own predicate is what decides it.</p>
Method TestAnotherUsersConversationAnswersNoProposals()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).SeedTurn(..#PROBEUSER, "completed", .tTurn), "a turn is seeded")
    Do $$$AssertStatusOK(..SeedIn(..#PROBEUSER, "probe-conv-a", tTurn, "one", "probe.proposal.update", "", .tOne), "and one proposal is minted in it")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedRowsForConvo("probe-conv-a", ..#OTHERUSER, .tByTurn)
    Do $$$AssertStatusOK(tSC, "the read succeeds for another user")
    Do $$$AssertEquals($Data(tByTurn), 0, "and answers no subscript at all")
}

/// <p>A proposal minted before the turn key reached the conversation entry -- or by anything that
/// stored none -- is unreachable from a restored conversation rather than attached to an arbitrary
/// turn.</p>
Method TestAProposalWithNoTurnKeyReachesNoRestoredTurn()
{
    Do $$$AssertStatusOK(..SeedIn(..#PROBEUSER, "probe-conv-a", "", "one", "probe.proposal.update", "", .tOne), "a proposal is minted with no turn key")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedRowsForConvo("probe-conv-a", ..#PROBEUSER, .tByTurn)
    Do $$$AssertStatusOK(tSC, "the conversation's proposals are read")
    Do $$$AssertEquals($Data(tByTurn), 0, "and it is grouped under no turn")
}

/// <p>The conversation handler attaches the proposals after the owner gate that answers 404 for a
/// conversation the caller does not own, before the payload is written, and outside every
/// escalated frame (AD-9) -- and a store it cannot read degrades to no proposals rather than
/// failing the read.</p>
Method TestTheConversationHandlerAttachesThemInsideItsOwnerGate()
{
    Set tSC = ##class(%Compiler.UDL.TextServices).GetTextAsString($Namespace, "OcuPilot.Api.Conversation", .tSource)
    Do $$$AssertStatusOK(tSC, "the handler's source is readable")
    Set tHandler = $Piece(tSource, "ClassMethod HandleRead", 2)
    Set tAttach = $Piece(tHandler, "ClassMethod AttachProposals", 2)
    Set tHandler = $Piece(tHandler, "ClassMethod AttachProposals", 1)
    Do $$$AssertTrue(tHandler [ "AttachProposals", "the conversation handler attaches the turns' proposals")
    Do $$$AssertTrue($Find(tHandler, "GuardedView") < $Find(tHandler, "AttachProposals"), "after the owner gate, never before it")
    Do $$$AssertTrue($Find(tHandler, "AttachProposals") < $Find(tHandler, "Response).JSON"), "and before the payload is written")

    Do $$$AssertTrue(tAttach [ "GuardedRowsForConvo", "the attachment reads the conversation-scoped projection")
    Do $$$AssertTrue(tAttach [ "GuardedTurnKeys", "and the turn keys it matches them by")
    ; Both reads' failures are logged and the array left empty, which is what makes a store that
    ; cannot be read a card that does not appear rather than a conversation read that fails.
    Do $$$AssertEquals($Length(tAttach, "LogRaw") - 1, 3, "every failure path logs: the two reads and the catch")
    Do $$$AssertTrue($Length(tAttach, "Set tRows = []") > 1, "and a turn with no rows carries an empty array")
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
