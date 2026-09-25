/// <p>Pins the mint (Story 5.1, AD-4, AD-6, AD-13): the payload is the fresh read's whole object
/// with the arguments over it, the diff is what changed, the target is the scoped triple, the
/// fingerprint is canonical and honours the descriptor's exclusions, a target the instance no
/// longer holds is refused, and a secret-declared argument never reaches the port.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot's protected state, an account holding
/// <code>%All</code>, and nothing else. Every fresh read is
/// <class>OcuPilot.Test.ProposalFixture</class>'s armed object -- no endpoint is called and
/// nothing on the instance is written -- and every row this class mints names a user starting with
/// <parameter>OcuPilot.Test.ProposalFixture.PROBEPREFIX</parameter>, removed in
/// <method>OnAfterOneTest</method>.</p>
Class OcuPilot.Test.Proposal Extends %UnitTest.TestCase
{

Parameter PROBEUSER = "OcuPilotProbeProposalMinter";

Parameter SCREEN = "OcuPilot.Test.ProposalScreen";

Parameter MINT = "OcuPilot.Test.ProposalMint";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The fresh read every test starts from: five properties, one of them a name the derived
/// field list does not carry, one of them the descriptor's declared fingerprint exclusion.</p>
Parameter FRESH = "{""Enabled"":false,""Description"":""before"",""Resource"":"""",""ProbeOnly"":""kept"",""LastModified"":""2026-09-01T00:00:00Z""}";

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

/// <p>Mint one proposal from the armed fresh read with <var>pArgs</var>, and answer the outcome.</p>
Method Mint(pArgs As %DynamicObject, Output pProposal, Output pHttp, Output pFault) As %Status
{
    Quit $ClassMethod(..#MINT, "Mint", ..#SCREEN, "probe.proposal.update", ..#PROBEUSER, "probe-conv", "probe-turn", pArgs, ..#LIMITS, .pProposal, .pHttp, .pFault, "WebApp.App", "name", pArgs.%Get("Name"), "Name", $ListBuild("Enabled", "Description", "Resource"))
}

/// <p>AD-4: the write sends the whole object, so the stored payload carries every property the
/// fresh read returned and the diff carries only what changed.</p>
/// <p>Mutation: drop one unchanged property from the merged payload in
/// <method>OcuPilot.Kernel.Proposal.Mint.Merge</method> -- this goes red naming the missing
/// property.</p>
Method TestThePayloadCarriesEveryPropertyTheFreshReadReturned()
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESH)
    Set tSC = ..Mint({"Name": "/csp/probe", "Enabled": true, "Description": "after"}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the mint succeeds")
    Do $$$AssertEquals(tHttp, 200, "answering 200")
    Set tStored = ##class(OcuPilot.Test.ProposalFixture).Field(tProposal.%Get("proposalId"), "ProposalKey")
    Do $$$AssertEquals(tStored, tProposal.%Get("proposalId"), "and one row was stored under the answered id")

    Set tPayload = ..StoredPayload(tProposal.%Get("proposalId"))
    Set tFresh = ##class(%DynamicAbstractObject).%FromJSON(..#FRESH)
    Set tIterator = tFresh.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Do $$$AssertNotEquals(tPayload.%GetTypeOf(tKey), "unassigned", "the payload still sends " _ tKey)
    }
    Do $$$AssertEquals(tPayload.%Get("ProbeOnly"), "kept", "a property the arguments never named travels unchanged")
    Do $$$AssertEquals(tPayload.%Get("Description"), "after", "and a property they did name carries the new value")
    Do $$$AssertEquals(tProposal.%Get("unchangedCount"), 3, "three of the five properties are sent unchanged")
    Do $$$AssertEquals(tProposal.%Get("changed").%Size(), 2, "and two changed")
}

/// <p>AD-4: the merge is over the fresh read's own object, never over the derived field list. A
/// settable field the read did not return cannot be added to the body.</p>
/// <p>Mutation: build the merge from the derived field list instead of the fresh read's object --
/// this goes red, because <code>Resource</code> would be added to a payload the read never carried
/// it in.</p>
Method TestAFieldTheFreshReadDidNotCarryIsRefusedRatherThanAdded()
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm("{""Enabled"":false,""ProbeOnly"":""kept""}")
    Set tSC = ..Mint({"Name": "/csp/probe", "Resource": "%Development"}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a settable field the instance's own record does not carry is refused")
    Do $$$AssertEquals(tHttp, 400, "as a 400")
    Do $$$AssertEquals(tFault.%Get("code"), ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, "with the arguments code")
    Do $$$AssertTrue(tFault.%Get("detail").%Get("problem") [ "Resource", "naming the property")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).ProposalCount(), 0, "and nothing was stored")
}

/// <p>The 404 a single-object <code>GET</code> answers reads as zero rows, never as an empty
/// success (AD-36).</p>
Method TestATargetTheInstanceNoLongerHoldsIsRefusedNamingIt()
{
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint({"Name": "/csp/gone", "Enabled": true}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "the mint is refused")
    Do $$$AssertEquals(tHttp, 400, "as a 400")
    Do $$$AssertEquals(tFault.%Get("code"), ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, "with the arguments code")
    Do $$$AssertTrue(tFault.%Get("detail").%Get("problem") [ "/csp/gone", "naming the target")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).ProposalCount(), 0, "and no row is minted")
}

/// <p>A 200 with no object is the same "target gone", not an empty success.</p>
Method TestAnAnswerWithNoObjectIsTheSameRefusal()
{
    Do ##class(OcuPilot.Test.ProposalFixture).ArmEmpty()
    Set tSC = ..Mint({"Name": "/csp/empty", "Enabled": true}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "an answer carrying no object is refused")
    Do $$$AssertEquals(tHttp, 400, "as a 400")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).ProposalCount(), 0, "and no row is minted")
}

/// <p>AD-13: the stored target is the triple, never a bare id, and the fresh read is made by that
/// id through the endpoint's own query parameter.</p>
/// <p>Mutation: return the wrong scope from the mint's <code>EntityRef.Key</code> -- this goes red
/// on the scope, and the client's own integration test goes red on the pause.</p>
Method TestTheStoredTargetIsTheScopedTriple()
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESH)
    Set tSC = ..Mint({"Name": "/csp/probe", "Enabled": true}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the mint succeeds")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastType(), "GET", "the fresh read is a single-object GET")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastQuery("name"), "/csp/probe", "by the endpoint's own query parameter")

    Set tTarget = tProposal.%Get("target")
    Do $$$AssertEquals(tTarget.%Get("type"), "web-application", "the answered target names the entity type")
    Do $$$AssertEquals(tTarget.%Get("scope"), "instance", "the scope")
    Do $$$AssertEquals(tTarget.%Get("id"), "/csp/probe", "and the id")

    Set tRef = ##class(OcuPilot.Test.ProposalFixture).Field(tProposal.%Get("proposalId"), "TargetRef")
    Set tParseSC = ##class(OcuPilot.Kernel.EntityRef).Parse(tRef, .tType, .tScope, .tId)
    Do $$$AssertStatusOK(tParseSC, "and the stored reference parses as a triple")
    Do $$$AssertEquals(tType _ "|" _ tScope _ "|" _ tId, "web-application|instance|/csp/probe", "carrying the same three parts")
}

/// <p>AD-6: a secret-declared field is never accepted from the model, and the refusal happens
/// before the port is touched.</p>
Method TestASecretDeclaredArgumentIsRefusedBeforeAnyPortCall()
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESH)
    Set tSC = $ClassMethod(..#MINT, "Mint", ..#SCREEN, "probe.proposal.update", ..#PROBEUSER, "probe-conv", "probe-turn", {"Name": "/csp/probe", "Password": "hunter2"}, ..#LIMITS, .tProposal, .tHttp, .tFault, "WebApp.App", "name", "/csp/probe", "Name", $ListBuild("Enabled"))
    Do $$$AssertStatusNotOK(tSC, "a secret-declared argument is refused")
    Do $$$AssertEquals(tHttp, 400, "as a 400")
    Do $$$AssertTrue(tFault.%Get("detail").%Get("problem") [ "Password", "naming the field")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).CallCount(), 0, "and no port call was made at all")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).ProposalCount(), 0, "so nothing was stored")
}

/// <p>The fingerprint is canonical: the same object in a different key order is the same digest.</p>
/// <p>Mutation: reverse <method>OcuPilot.Kernel.Proposal.Fingerprint.Canonical</method>'s key
/// ordering -- the round trip below goes red.</p>
Method TestTheFingerprintIsDeterministicAcrossKeyOrder()
{
    Set tOne = {"b": 2, "a": "x", "c": [1, 2], "d": {"z": true, "y": false}}
    Set tTwo = {"d": {"y": false, "z": true}, "c": [1, 2], "a": "x", "b": 2}
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Proposal.Fingerprint).Of(tOne, "", .tFirst), "the first digest is taken")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Proposal.Fingerprint).Of(tTwo, "", .tSecond), "and the second")
    Do $$$AssertEquals(tFirst, tSecond, "key insertion order does not change the digest")
    Do $$$AssertEquals($Length(tFirst), 64, "and it is a 256-bit hex digest")

    Set tThree = {"b": 2, "a": "y", "c": [1, 2], "d": {"z": true, "y": false}}
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Proposal.Fingerprint).Of(tThree, "", .tChanged), "a changed value is digested")
    Do $$$AssertNotEquals(tFirst, tChanged, "and a changed value changes the digest")

    Set tOrdered = {"c": [2, 1]}
    Set tReversed = {"c": [1, 2]}
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Proposal.Fingerprint).Of(tOrdered, "", .tA), "an array is digested in its own order")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Proposal.Fingerprint).Of(tReversed, "", .tB), "and so is its reversal")
    Do $$$AssertNotEquals(tA, tB, "an array's order is part of its value")
}

/// <p>AD-6: the fingerprint covers everything but the paths the descriptor excludes.</p>
/// <p>Mutation: include a <code>fingerprintExcludes</code> path in
/// <method>OcuPilot.Kernel.Proposal.Fingerprint.Of</method> -- this goes red.</p>
Method TestAnExcludedPathIsOutsideTheFingerprint()
{
    Set tExcludes = $ListBuild("LastModified", "Nested.Stamp")
    Set tOne = {"Enabled": true, "LastModified": "2026-09-01T00:00:00Z", "Nested": {"Stamp": "a", "Kept": 1}}
    Set tTwo = {"Enabled": true, "LastModified": "2026-09-19T00:00:00Z", "Nested": {"Stamp": "b", "Kept": 1}}
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Proposal.Fingerprint).Of(tOne, tExcludes, .tFirst), "the first digest is taken")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Proposal.Fingerprint).Of(tTwo, tExcludes, .tSecond), "and the second")
    Do $$$AssertEquals(tFirst, tSecond, "an excluded path does not move the digest, at any depth")

    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Proposal.Fingerprint).Of(tOne, "", .tWhole), "the same object with nothing excluded")
    Do $$$AssertNotEquals(tFirst, tWhole, "differs from the excluded reading, so the exclusion is load-bearing")

    Set tThree = {"Enabled": false, "LastModified": "2026-09-01T00:00:00Z", "Nested": {"Stamp": "a", "Kept": 1}}
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Proposal.Fingerprint).Of(tThree, tExcludes, .tThird), "a property outside the exclusions is digested")
    Do $$$AssertNotEquals(tFirst, tThird, "and moving it moves the digest")

    ; An array field's ToolFields path carries the generator's [] suffix, and that is the only
    ; spelling OcuPilot.Screen.Registry.ConfirmChannelProblem accepts for it, so it is the spelling
    ; the digest has to honour.
    Set tListExcludes = $ListBuild("CorsAllowlist[]")
    Set tListOne = {"Enabled": true, "CorsAllowlist": ["https://a.example"]}
    Set tListTwo = {"Enabled": true, "CorsAllowlist": ["https://b.example", "https://c.example"]}
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Proposal.Fingerprint).Of(tListOne, tListExcludes, .tListFirst), "an array field excluded by its [] path is digested")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Proposal.Fingerprint).Of(tListTwo, tListExcludes, .tListSecond), "and so is the same field holding other elements")
    Do $$$AssertEquals(tListFirst, tListSecond, "a [] exclusion takes the whole array out of the digest")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.Proposal.Fingerprint).Of(tListOne, "", .tListWhole), "the same object with nothing excluded")
    Do $$$AssertNotEquals(tListFirst, tListWhole, "so the [] exclusion is load-bearing, not accepted and ignored")
}

/// <p>DW-1205: the fixture's own declaration is one the shipped validator accepts, so the exclusion
/// these tests rely on is declarable rather than merely unvalidated.</p>
/// <p>Mutation: refuse a read-declared path in
/// <method>OcuPilot.Screen.Registry.ConfirmChannelProblem</method> -- this goes red.</p>
Method TestTheFixturesOwnConfirmChannelIsSound()
{
    Set tSC = $ClassMethod(..#SCREEN, "DeclarationJson", .tDeclaration)
    Do $$$AssertStatusOK(tSC, "the fixture declaration parses")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Registry).ConfirmChannelProblem(tDeclaration), "", "and its declared exclusion is one the validator accepts")
}

/// <p>The descriptor's own exclusion reaches the stored digest: the mint takes it from the
/// descriptor, not from the tool.</p>
Method TestTheMintTakesItsExclusionsFromTheDescriptor()
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESH)
    Set tSC = ..Mint({"Name": "/csp/probe", "Description": "after"}, .tFirst, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the first mint succeeds")
    Set tFirstPrint = ##class(OcuPilot.Test.ProposalFixture).Field(tFirst.%Get("proposalId"), "Fingerprint")

    Do ##class(OcuPilot.Test.ProposalFixture).Arm("{""Enabled"":false,""Description"":""before"",""Resource"":"""",""ProbeOnly"":""kept"",""LastModified"":""2099-01-01T00:00:00Z""}")
    Set tSC = ..Mint({"Name": "/csp/probe", "Description": "after"}, .tSecond, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the second mint succeeds")
    Set tSecondPrint = ##class(OcuPilot.Test.ProposalFixture).Field(tSecond.%Get("proposalId"), "Fingerprint")
    Do $$$AssertEquals(tFirstPrint, tSecondPrint, "the declared exclusion keeps a side-effect stamp out of the stored digest")
}

/// <p>AD-4, DW-1212: the merged body keeps the property TYPES the instance's own read answered
/// with, so a numeric instance field set from a string argument is sent back as a number.</p>
/// <p>A tool schema's scalar type is derived from a template placeholder, which is information
/// rather than contract -- this instance answers a number for five <code>WebApp.App</code> fields
/// whose template shows a string -- so the model can only ever send the string.</p>
/// <p>Mutation: take the type from the arguments again in
/// <method>OcuPilot.Kernel.Proposal.Mint.Merge</method> -- this goes red, with the payload holding
/// the string spelling.</p>
Method TestTheMergedPayloadKeepsTheFreshReadsOwnTypes()
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm("{""Timeout"":900,""Recurse"":false,""Description"":""before""}")
    Set tArgs = {"Name": "/csp/probe", "Timeout": "300", "Recurse": "true"}
    Set tSC = $ClassMethod(..#MINT, "Mint", ..#SCREEN, "probe.proposal.update", ..#PROBEUSER, "probe-conv", "probe-turn", tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, "WebApp.App", "name", "/csp/probe", "Name", $ListBuild("Timeout", "Recurse"))
    Do $$$AssertStatusOK(tSC, "the mint succeeds")
    If $$$ISERR(tSC) Quit

    Set tPayload = ..StoredPayload(tProposal.%Get("proposalId"))
    Do $$$AssertEquals(tPayload.%GetTypeOf("Timeout"), "number", "a numeric instance field stays a number")
    Do $$$AssertEquals(tPayload.%Get("Timeout"), 300, "carrying the value the arguments sent")
    Do $$$AssertEquals(tPayload.%GetTypeOf("Recurse"), "boolean", "and a boolean one stays a boolean")
    Do $$$AssertEquals(''tPayload.%Get("Recurse"), 1, "reading the argument's own true")
}

/// <p>AD-4, AD-6: a value the instance's own property type cannot carry is refused at the mint
/// rather than coerced, so the diff the user reviews and the body the confirmed write sends are
/// the same thing. A silent coercion would show "soon" in the card and send <code>0</code>.</p>
/// <p>Mutation: drop the <method>OcuPilot.Kernel.Proposal.Mint.Representable</method> guard from
/// <method>Merge</method> -- the mint succeeds and this goes red.</p>
Method TestAValueTheInstanceTypeCannotCarryIsRefusedAtTheMint()
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm("{""Timeout"":900,""Recurse"":false,""Description"":""before""}")
    Set tArgs = {"Name": "/csp/probe", "Timeout": "soon"}
    Set tSC = $ClassMethod(..#MINT, "Mint", ..#SCREEN, "probe.proposal.update", ..#PROBEUSER, "probe-conv", "probe-turn", tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, "WebApp.App", "name", "/csp/probe", "Name", $ListBuild("Timeout", "Recurse"))
    Do $$$AssertStatusNotOK(tSC, "the mint is refused")
    Do $$$AssertEquals($IsObject($Get(tProposal)), 0, "and no proposal is minted")
    ; The wire reason stays the family's own -- the field that could not be carried is a detail of
    ; the instance's property types, not something the refusal spells out to a caller.
    Do $$$AssertTrue($IsObject($Get(tFault)), "with a wire-safe fault beside it")

    ; A numeric spelling of the same field still mints, so the guard refuses the value and not the
    ; conversion.
    Set tArgs = {"Name": "/csp/probe", "Timeout": "300"}
    Set tSC = $ClassMethod(..#MINT, "Mint", ..#SCREEN, "probe.proposal.update", ..#PROBEUSER, "probe-conv", "probe-turn", tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, "WebApp.App", "name", "/csp/probe", "Name", $ListBuild("Timeout", "Recurse"))
    Do $$$AssertStatusOK(tSC, "a numeric spelling still mints")
}

/// <p>AD-4: an array-valued settable field merges into the payload as an array, so a write tool
/// whose schema advertises one can mint against it.</p>
Method TestAnArrayValuedFieldIsMergedIntoThePayload()
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm("{""Enabled"":false,""CorsAllowlist"":[""https://a.example""]}")
    Set tArgs = {"Name": "/csp/probe", "CorsAllowlist": ["https://a.example", "https://b.example"]}
    Set tSC = $ClassMethod(..#MINT, "Mint", ..#SCREEN, "probe.proposal.update", ..#PROBEUSER, "probe-conv", "probe-turn", tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, "WebApp.App", "name", "/csp/probe", "Name", $ListBuild("Enabled", "CorsAllowlist"))
    Do $$$AssertStatusOK(tSC, "the mint succeeds for an array-valued argument")
    Do $$$AssertEquals(tHttp, 200, "answering 200, not an internal error")

    Set tPayload = ..StoredPayload(tProposal.%Get("proposalId"))
    Do $$$AssertEquals(tPayload.%GetTypeOf("CorsAllowlist"), "array", "the payload keeps the field an array")
    Do $$$AssertEquals(tPayload.%Get("CorsAllowlist").%Size(), 2, "carrying both elements the arguments sent")
    Do $$$AssertEquals(tPayload.%Get("CorsAllowlist").%Get(1), "https://b.example", "including the added one")
    Do $$$AssertEquals(tProposal.%Get("changed").%Size(), 1, "one field changed")
    Do $$$AssertEquals(tProposal.%Get("changed").%Get(0).%Get("field"), "CorsAllowlist", "and the diff names the array field")
}

/// <p>A minted row records the turn, the conversation, the tool and the agent's own words, and its
/// expiry is the server-side constant away from its creation.</p>
Method TestTheRowRecordsWhoMintedItAndWhen()
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESH)
    Set tSC = ..Mint({"Name": "/csp/probe", "Enabled": true, "rationale": "why", "expectedImpact": "what", "reverse": "how"}, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the mint succeeds")
    Set tKey = tProposal.%Get("proposalId")
    Set tFixture = "OcuPilot.Test.ProposalFixture"
    Do $$$AssertEquals($ClassMethod(tFixture, "Field", tKey, "TurnKey"), "probe-turn", "the row names the turn")
    Do $$$AssertEquals($ClassMethod(tFixture, "Field", tKey, "ConvKey"), "probe-conv", "and the conversation")
    Do $$$AssertEquals($ClassMethod(tFixture, "Field", tKey, "ToolName"), "probe.proposal.update", "and the tool")
    Do $$$AssertEquals($ClassMethod(tFixture, "Field", tKey, "Rationale"), "why", "and the agent's rationale")
    Do $$$AssertEquals($ClassMethod(tFixture, "Field", tKey, "ExpectedImpact"), "what", "its expected impact")
    Do $$$AssertEquals($ClassMethod(tFixture, "Field", tKey, "Reverse"), "how", "and its reversal")
    Do $$$AssertEquals($ClassMethod(tFixture, "Field", tKey, "State"), ##class(OcuPilot.Kernel.State.Propose).#STATELIVE, "and it is live")
    Do $$$AssertNotEquals($ClassMethod(tFixture, "Field", tKey, "Token"), tKey, "the token is not the id")
    Do $$$AssertEquals($Length($ClassMethod(tFixture, "Field", tKey, "Token")), 32, "and it is 32 hex characters")

    Set tCreated = ##class(OcuPilot.Kernel.State.Propose).SecondsOf($ClassMethod(tFixture, "Field", tKey, "CreatedAt"))
    Set tExpires = ##class(OcuPilot.Kernel.State.Propose).SecondsOf($ClassMethod(tFixture, "Field", tKey, "ExpiresAt"))
    Do $$$AssertEquals(tExpires - tCreated, +$Parameter(..#LIMITS, "PROPOSALEXPIRYSECONDS"), "and the window is the server-side constant")
}

/// <p>DW-1577: a merge write whose arguments restate what the target already holds changes nothing,
/// so the mint refuses it 400 <code>TOOL.ARGUMENTS</code> and stores no row -- for
/// <code>webapp.list.update</code> restating <code>Enabled</code>, and for
/// <code>permissions.users.update</code> restating <code>FullName</code>. A call that does move the
/// field is still minted.</p>
/// <p>Mutation (Rule 19): delete the empty-diff refusal from
/// <method>OcuPilot.Kernel.Proposal.Mint.Mint</method> -- both refusal legs go red.</p>
Method TestAMergeThatChangesNothingIsRefusedAndStoresNothing()
{
    Set tCases = $ListBuild($ListBuild("OcuPilot.Screen.Tool.WebAppUpdate", "{""Enabled"":true,""Description"":""probe"",""AutheEnabled"":32,""NameSpace"":""USER"",""MatchRoles"":[]}", "/csp/ocupilotprobenochange", "Enabled", "true", "false"))
    Set tCases = tCases _ $ListBuild($ListBuild("OcuPilot.Screen.Tool.UserUpdate", "{""FullName"":""Probe"",""Enabled"":true,""Comment"":""probe"",""Roles"":[]}", "OcuPilotProbeNoChange", "FullName", """Probe""", """Probe renamed"""))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tTool = $List(tCase, 1)
        Set tName = $Parameter(tTool, "TOOLNAME")
        Set tBefore = ##class(OcuPilot.Test.ProposalFixture).ProposalCount()
        Do ##class(OcuPilot.Test.ProposalFixture).Arm($List(tCase, 2))
        Set tArgs = ##class(%DynamicAbstractObject).%FromJSON("{""Name"":""" _ $List(tCase, 3) _ """,""" _ $List(tCase, 4) _ """:" _ $List(tCase, 5) _ "}")
        Set tSC = ..MintWith(tTool, tArgs, .tProposal, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, tName _ ": restating what the target holds is refused")
        Do $$$AssertEquals(tHttp, 400, tName _ ": at 400")
        Do $$$AssertEquals($Select($IsObject(tFault): tFault.%Get("code"), 1: ""), ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, tName _ ": with the arguments code")
        Set tProblem = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.%Get("detail").%Get("problem"), 1: "")
        Do $$$AssertTrue(tProblem [ "nothing would change", tName _ ": saying nothing would change: " _ tProblem)
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).ProposalCount(), tBefore, tName _ ": and no row is stored")

        Do ##class(OcuPilot.Test.ProposalFixture).Arm($List(tCase, 2))
        Set tArgs = ##class(%DynamicAbstractObject).%FromJSON("{""Name"":""" _ $List(tCase, 3) _ """,""" _ $List(tCase, 4) _ """:" _ $List(tCase, 6) _ "}")
        Set tSC = ..MintWith(tTool, tArgs, .tProposal, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, tName _ ": a call that moves the field is minted: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    }
}

/// <p>Mint one proposal for write tool <var>pTool</var> from the armed fresh read with
/// <var>pArgs</var>, with the tool's own endpoint, parameters, settable fields and class -- the call
/// <method>OcuPilot.Screen.Tool.Write.View</method> makes.</p>
Method MintWith(pTool As %String, pArgs As %DynamicObject, Output pProposal, Output pHttp, Output pFault) As %Status
{
    Quit $ClassMethod(..#MINT, "Mint", $Parameter(pTool, "DESCRIPTORCLASS"), $Parameter(pTool, "TOOLNAME"), ..#PROBEUSER, "probe-conv", "probe-turn", pArgs, ..#LIMITS, .pProposal, .pHttp, .pFault, $ClassMethod(pTool, "Endpoint"), $ClassMethod(pTool, "IdParam"), pArgs.%Get("Name"), $ClassMethod(pTool, "IdArgument"), $ClassMethod(pTool, "SettableFields"), pTool)
}

/// <p>The stored payload of proposal <var>pKey</var>, parsed.</p>
Method StoredPayload(pKey As %String) As %DynamicObject
{
    Do ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(pKey, .tFound, .tValues)
    If 'tFound Quit {}
    Quit ##class(%DynamicAbstractObject).%FromJSON(tValues("payload"))
}

}
