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
Parameter WIREKEYS = "proposalId,target,expiresAt,tool,changed,unchangedCount,unchanged,rationale,expectedImpact,reverse,state,closedReason,confirmedAt,auditWarning";

/// <p>The write tool whose generated field list the disclosure's masking is driven against
/// (DW-1223). The probe descriptor owns no field-list entry, which is the fail-closed case and not
/// the classified one, so the masking tests below name the shipped tool's entry.</p>
Parameter CLASSIFIEDTOOL = "webapp.list.update";

/// <p>Story 5.9's write tool, whose field list classifies its two arrays <code>opaque</code>. It
/// is the only classified entry with an <code>opaque</code> row, so it is the only one that can
/// show a classified array masked rather than a merely unnamed one.</p>
Parameter USERTOOL = "permissions.users.update";

/// <p>A fresh <code>Security.User</code> read carrying one <code>ordinary</code> literal, the two
/// <code>opaque</code> arrays, and the <code>ordinary</code> literal the proposal changes.</p>
Parameter FRESHUSER = "{""FullName"":""before"",""Roles"":[""%EnsRole_Operator""],""EscalationRoles"":[""%EnsRole_Administrator""],""Enabled"":false}";

/// <p>A fresh read carrying one <code>ordinary</code> literal, one <code>ordinary</code>
/// <b>array</b> of literals (<code>CorsAllowlist</code>, declared <code>CorsAllowlist[]</code>),
/// one subtree the classification describes only member by member (<code>MatchRoles</code>), and
/// one property with no row in the field list at all -- the four ways a path reaches the
/// disclosure.</p>
/// <p>The array is not decoration: <code>webapp.list.update</code>'s field list declares
/// <code>CorsAllowlist[]</code> and <code>CorsHeadersList[]</code> as <code>ordinary</code>
/// literals, and they reach the disclosure only through
/// <method>OcuPilot.Kernel.Proposal.Disclosure.OrdinaryPaths</method>'s <code>[]</code>-stripping
/// branch. Without a payload that uses it, that branch could be deleted and both fields would
/// silently disclose masked -- indistinguishable from the intended fail-closed behaviour.</p>
Parameter FRESHCLASSIFIED = "{""Description"":""before"",""CorsAllowlist"":[""https://a.example"",""https://b.example""],""MatchRoles"":[{""MatchRole"":""secretrole""}],""Nonsense"":""unclassifiedvalue""}";

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

/// <p>Mint one proposal on turn <var>pTurnKey</var> over <parameter>FRESHCLASSIFIED</parameter>
/// under <parameter>CLASSIFIEDTOOL</parameter>, changing <code>Description</code>.</p>
/// <p>It arms and mints here rather than through <method>SeedIn</method> because that method arms
/// <parameter>FRESH</parameter> itself, and the disclosure's masking needs a fresh read carrying
/// the three classification cases.</p>
Method SeedClassified(pTurnKey As %String, Output pKey As %String) As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESHCLASSIFIED)
    Set tArgs = {"Name": "/csp/probe", "Description": "after"}
    Set tSC = $ClassMethod(..#MINT, "Mint", ..#SCREEN, ..#CLASSIFIEDTOOL, ..#PROBEUSER, "probe-conv", pTurnKey, tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, "WebApp.App", "name", "/csp/probe", "Name", $ListBuild("Description"))
    Set pKey = $Select($IsObject($Get(tProposal)): tProposal.%Get("proposalId"), 1: "")
    Quit tSC
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

/// <p>AD-6: the stored body reaches the wire only as the disclosure's masked
/// <code>{field, value}</code> projection. The payload, the fingerprint and the token are absent
/// as keys, and the row carries no value the tool's own classification does not admit.</p>
Method TestTheStoredBodyReachesTheWireOnlyAsTheDisclosure()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).SeedTurn(..#PROBEUSER, "completed", .tTurn), "a turn is seeded")
    Do $$$AssertStatusOK(..Seed(..#PROBEUSER, tTurn, "after", .tKey), "and one proposal is minted on it")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedRowsForTurn(tTurn, ..#PROBEUSER, .tRows)
    Do $$$AssertStatusOK(tSC, "the turn's proposals are read")
    Set tRow = tRows.%Get(0)
    Set tMasked = 0
    Do $$$AssertEquals(tRow.%GetTypeOf("payload"), "unassigned", "the payload is not a key of the wire row")
    Do $$$AssertEquals(tRow.%GetTypeOf("arguments"), "unassigned", "nor the stored arguments")
    Do $$$AssertEquals(tRow.%GetTypeOf("fingerprint"), "unassigned", "nor the fingerprint")
    Do $$$AssertEquals(tRow.%GetTypeOf("token"), "unassigned", "and certainly not the token")
    ; The probe tool owns no field-list entry, which is the fail-closed case: every disclosed row
    ; carries the mask and no stored value travels at all.
    Set tIterator = tRow.%Get("unchanged").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tUnchanged) {
        Do $$$AssertEquals(tUnchanged.%Get("value"), ##class(OcuPilot.Kernel.Proposal.Disclosure).Mask(), "an unreadable field list discloses " _ tUnchanged.%Get("field") _ " masked")
        Set tMasked = tMasked + 1
    }
    Do $$$AssertEquals(tMasked, tRow.%Get("unchangedCount"), "every one of them, so no stored value travels at all")
}

/// <p>DW-1223: the disclosure's rows are the payload's top-level properties minus the changed
/// ones, in the payload's own order, and there are exactly <code>unchangedCount</code> of them.</p>
/// <p>Mutation (Rule 19): drop the <code>If $Data(tChanged(tKey)) Continue</code> line from
/// <method>OcuPilot.Kernel.Proposal.Disclosure.Rows</method> -- the length assertion goes red.</p>
Method TestTheUnchangedRowsAreThePayloadMinusTheChangedFields()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).SeedTurn(..#PROBEUSER, "completed", .tTurn), "a turn is seeded")
    Do $$$AssertStatusOK(..SeedClassified(tTurn, .tKey), "and one proposal changing Description is minted on it")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedRowsForTurn(tTurn, ..#PROBEUSER, .tRows)
    Do $$$AssertStatusOK(tSC, "the turn's proposals are read")
    Set tRow = tRows.%Get(0)
    Set tUnchangedRows = tRow.%Get("unchanged")
    Do $$$AssertEquals(tRow.%Get("unchangedCount"), 3, "three of the four properties are sent unchanged")
    Do $$$AssertEquals(tUnchangedRows.%Size(), tRow.%Get("unchangedCount"), "and the disclosure has exactly that many rows")
    Do $$$AssertEquals(tUnchangedRows.%Get(0).%Get("field"), "CorsAllowlist", "in the payload's own order, the changed field skipped")
    Do $$$AssertEquals(tUnchangedRows.%Get(1).%Get("field"), "MatchRoles", "and the rest following it")
    Do $$$AssertEquals(tUnchangedRows.%Get(2).%Get("field"), "Nonsense", "to the last of them")
    Do $$$AssertEquals(tRow.%Get("changed").%Get(0).%Get("field"), "Description", "the one changed field is on the diff and nowhere else")
}

/// <p>DW-1223, AD-3's fail-closed rule: a subtree the classification describes only member by
/// member, and a property it does not name at all, are both disclosed with the published mask, and
/// neither raw value appears anywhere in the wire row.</p>
/// <p>Mutation (Rule 19): drop the <code>If tPath [ "." Continue</code> line from
/// <method>OcuPilot.Kernel.Proposal.Disclosure.OrdinaryPaths</method>, so the
/// <code>MatchRoles[].MatchRole</code> row admits <code>MatchRoles</code> -- the secret-role
/// assertion goes red.</p>
Method TestASecretOrUnclassifiedPropertyIsDisclosedMasked()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).SeedTurn(..#PROBEUSER, "completed", .tTurn), "a turn is seeded")
    Do $$$AssertStatusOK(..SeedClassified(tTurn, .tKey), "and one proposal changing Description is minted on it")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedRowsForTurn(tTurn, ..#PROBEUSER, .tRows)
    Do $$$AssertStatusOK(tSC, "the turn's proposals are read")
    Set tRow = tRows.%Get(0)
    Set tMask = ##class(OcuPilot.Kernel.Proposal.Disclosure).Mask()
    Kill tValue
    Set tIterator = tRow.%Get("unchanged").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tUnchanged) {
        Set tValue(tUnchanged.%Get("field")) = tUnchanged.%Get("value")
    }
    Do $$$AssertEquals($Get(tValue("MatchRoles")), tMask, "the role subtree is disclosed masked, not dropped")
    Do $$$AssertEquals($Get(tValue("Nonsense")), tMask, "and so is a property the classification does not name")
    Set tJson = tRows.%ToJSON()
    Do $$$AssertEquals(tJson [ "secretrole", 0, "no role value reaches the wire")
    Do $$$AssertEquals(tJson [ "unclassifiedvalue", 0, "and no unclassified value either")
}

/// <p>DW-1223: an <code>ordinary</code> literal is disclosed with its value, rendered the way the
/// diff renders one, so the disclosure and the diff cannot read one value two ways.</p>
Method TestAnOrdinaryLiteralIsDisclosedWithItsValue()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).SeedTurn(..#PROBEUSER, "completed", .tTurn), "a turn is seeded")
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESHCLASSIFIED)
    ; "Nonsense" is the changed field here, so Description -- the one classified ordinary literal
    ; -- is among the unchanged and is the row this asserts.
    Set tArgs = {"Name": "/csp/probe", "Nonsense": "after"}
    Set tSC = $ClassMethod(..#MINT, "Mint", ..#SCREEN, ..#CLASSIFIEDTOOL, ..#PROBEUSER, "probe-conv", tTurn, tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, "WebApp.App", "name", "/csp/probe", "Name", $ListBuild("Nonsense"))
    Do $$$AssertStatusOK(tSC, "a proposal changing the unclassified property is minted")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedRowsForTurn(tTurn, ..#PROBEUSER, .tRows)
    Do $$$AssertStatusOK(tSC, "the turn's proposals are read")
    Kill tValue
    Set tIterator = tRows.%Get(0).%Get("unchanged").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tUnchanged) {
        Set tValue(tUnchanged.%Get("field")) = tUnchanged.%Get("value")
    }
    Do $$$AssertEquals($Get(tValue("Description")), "before", "the ordinary literal carries its own value")
    ; The array-of-literals branch: the field list declares this path as `CorsAllowlist[]`, and the
    ; property is admitted by stripping that suffix. Rendered by Mint.Display, which answers compact
    ; JSON for an array, so the disclosure and the diff read one value the same way.
    ;
    ; Mutation (Rule 19): drop the `If $Extract(tPath, *-1, *) = "[]"` line from
    ; OcuPilot.Kernel.Proposal.Disclosure.OrdinaryPaths -- this goes red, and every web
    ; application's CorsAllowlist and CorsHeadersList would disclose masked.
    Do $$$AssertEquals($Get(tValue("CorsAllowlist")), "[""https://a.example"",""https://b.example""]", "an ordinary array of literals carries its own value, not the mask")
    Do $$$AssertNotEquals($Get(tValue("CorsAllowlist")), ##class(OcuPilot.Kernel.Proposal.Disclosure).Mask(), "and is not masked as though nobody had classified it")
}

/// <p>Story 5.9, DW-1223, AD-3: the users write tool's disclosure. Its rows equal
/// <code>unchangedCount</code>, an <code>ordinary</code> literal carries its value, and both role
/// arrays carry the mask because the reviewed classification calls them <code>opaque</code> -- the
/// endpoint's template answers <code>[]</code> for each, so nothing types a member and
/// <code>ordinary</code> is a class neither row can carry.</p>
/// <p>Mutation (Rule 19): classify <code>Roles</code> <code>ordinary</code> in
/// <class>OcuPilot.Screen.Tool.Classification</class> -- <code>node tools/field-lists.mjs</code>
/// refuses it, which is the generator half; reaching past that by hand-editing
/// <class>OcuPilot.Screen.Tool.ToolFields</class> reddens the masking assertion here and
/// <method>OcuPilot.Test.DerivedFields</method>'s drift check.</p>
Method TestTheUserToolsDisclosureMasksBothRoleArrays()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).SeedTurn(..#PROBEUSER, "completed", .tTurn), "a turn is seeded")
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESHUSER)
    Set tArgs = {"Name": "OcuPilotProbeWireUser", "Enabled": true}
    Set tSC = $ClassMethod(..#MINT, "Mint", ..#SCREEN, ..#USERTOOL, ..#PROBEUSER, "probe-conv", tTurn, tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, "Security.User", "name", "OcuPilotProbeWireUser", "Name", $ListBuild("Enabled", "Roles"))
    Do $$$AssertStatusOK(tSC, "a proposal enabling the account is minted: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedRowsForTurn(tTurn, ..#PROBEUSER, .tRows)
    Do $$$AssertStatusOK(tSC, "the turn's proposals are read")
    Set tRow = tRows.%Get(0)
    Set tUnchangedRows = tRow.%Get("unchanged")
    Do $$$AssertEquals(tRow.%Get("unchangedCount"), 3, "three of the four properties are sent unchanged")
    Do $$$AssertEquals(tUnchangedRows.%Size(), tRow.%Get("unchangedCount"), "and the disclosure has exactly that many rows")
    Kill tValue
    Set tIterator = tUnchangedRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tUnchanged) {
        Set tValue(tUnchanged.%Get("field")) = tUnchanged.%Get("value")
    }
    Set tMask = ##class(OcuPilot.Kernel.Proposal.Disclosure).Mask()
    Do $$$AssertEquals($Get(tValue("FullName")), "before", "the ordinary literal carries its own value")
    Do $$$AssertEquals($Get(tValue("Roles")), tMask, "the roles array is disclosed masked because it is classified opaque")
    Do $$$AssertEquals($Get(tValue("EscalationRoles")), tMask, "and so is the escalation array")
    Set tJson = tRows.%ToJSON()
    Do $$$AssertEquals(tJson [ "%EnsRole", 0, "no role name from either array reaches the wire")
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
    ; The owner gate's own presence is asserted before the ordering that mentions it: $Find answers
    ; 0 for a needle that is absent, so a bare "0 < n" would read true and stay green on the very
    ; deletion the ordering exists to refuse.
    Do $$$AssertTrue(tHandler [ "GuardedView", "the conversation handler still answers through the owner gate")
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
    Do $$$AssertTrue(tHandler [ "GuardedForOwner", "the progress handler still answers through the owner gate")
    Do $$$AssertTrue($Find(tHandler, "GuardedForOwner") < $Find(tHandler, "GuardedRowsForTurn"), "after the owner gate, never before it")
    Do $$$AssertTrue($Find(tHandler, "GuardedRowsForTurn") < $Find(tHandler, "Response).JSON"), "and before the payload is written")
}

}
