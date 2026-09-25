/// <p>Pins Story 8.1's write kind (AD-54, AD-6, AD-13, AD-34): the <b>create</b> -- a write whose
/// fresh read must find nothing, whose payload is composed rather than merged, and whose
/// fingerprint covers the target's absence rather than a property set.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and its protected state
/// readable. Every port call is <class>OcuPilot.Test.ProposalFixture</class>'s, so <b>nothing here
/// writes to the instance</b>, no web application is created and no arming variable is required.
/// The end-to-end create against a real instance is the smoke path's and the browser spec's.</p>
/// <p>Every row it seeds hangs off a turn <method>OcuPilot.Test.ProposalFixture.SeedTurn</method>
/// created, which is what <method>OnAfterOneTest</method> removes them by.</p>
Class OcuPilot.Test.ProposalCreate Extends %UnitTest.TestCase
{

/// <p>The shipped mint with the port replaced, so the shipped inversion runs against an armed
/// answer.</p>
Parameter MINT = "OcuPilot.Test.ProposalMint";

/// <p>The shipped confirm with the port replaced, which records what a write was sent.</p>
Parameter CONFIRM = "OcuPilot.Test.ConfirmFixture";

Parameter TOOL = "OcuPilot.Screen.Tool.WebAppCreate";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.WebAppList";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter STORE = "OcuPilot.Kernel.State.Propose";

/// <p>The name every create in this class proposes: a path nothing on the instance holds, and one
/// the fixture port answers for whatever the instance actually has.</p>
Parameter TARGET = "/csp/ocupilotprobecreate";

/// <p>The same name spelled the way an agent might type it: re-cased and slash-suffixed. The
/// instance resolves it to <parameter>TARGET</parameter>, and AD-13's canonical rule is what makes
/// the two one key.</p>
Parameter OTHERSPELLING = "/CSP/OcuPilotProbeCreate/";

/// <p>The application the vendor's own <code>GET</code> would answer for a name somebody has
/// taken. Its content does not matter -- what matters is that it is an object, which is what the
/// create's inverted acceptance refuses.</p>
Parameter PRESENT = "{""Name"":""/csp/ocupilotprobecreate"",""Enabled"":true,""NameSpace"":""HSCUSTOM""}";

/// <p>The vendor property the server derives, and the directory name it resolves it from.</p>
Parameter DERIVEDFIELD = "Path";

Parameter WSGILOCATION = "ocupilot-probe-wsgi";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit $$$OK
}

/// <p>AD-54's first inversion: the fresh read keeps its place and its acceptance is inverted, so a
/// target the instance already holds refuses the mint and nothing is stored.</p>
/// <p>Mutation: make <method>OcuPilot.Kernel.Proposal.Mint.CreatesOf</method> answer 0 -> the
/// present target is accepted and the absent one refused, so both halves go red.</p>
Method TestAPresentTargetRefusesTheMintAndAnAbsentOneProceeds()
{
    Set tBefore = ##class(OcuPilot.Test.ProposalFixture).ProposalCount($Username)

    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#PRESENT)
    Set tSC = ..Mint(..#TARGET, ..Args(), .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a create whose name the instance already holds is refused")
    Do $$$AssertEquals(tHttp, 400, "at 400")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.%Get("code"), 1: ""), ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, "with the arguments code")
    Do $$$AssertTrue($Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.%Get("detail").%Get("problem"), 1: "") [ "already present", "and a problem naming the id argument")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).ProposalCount($Username), tBefore, "and no proposal was stored")

    ; The success precondition: a 404 from the same read, at the same endpoint and request type.
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint(..#TARGET, ..Args(), .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a create whose name is free is minted")
    Do $$$AssertEquals(tHttp, 200, "at 200")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastType(), $ClassMethod(..#TOOL, "ReadType"), "through the tool's own read type")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastQuery($ClassMethod(..#TOOL, "IdParam")), ..#TARGET, "and its own identifying parameter")
}

/// <p>AD-55: a create's arguments pass the screen's own field rules at the mint, so the agent
/// cannot mint a create the screen's Save would refuse. One naming no authentication method would
/// otherwise be created with the vendor's Unauthenticated default.</p>
/// <p>Mutation: make <method>OcuPilot.Screen.Tool.WebAppCreate.ArgumentProblem</method> answer no
/// problem -> the create is minted and every assertion below goes red.</p>
Method TestACreateNamingNoAuthenticationMethodIsRefusedAtTheMint()
{
    Set tBefore = ##class(OcuPilot.Test.ProposalFixture).ProposalCount($Username)
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tArgs = ..Args()
    Do tArgs.%Remove("AutheEnabled")
    Set tSC = ..Mint(..#TARGET, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a create naming no authentication method is refused")
    Do $$$AssertEquals(tHttp, 400, "at 400")
    Do $$$AssertEquals($Select($IsObject(tFault): tFault.%Get("code"), 1: ""), ##class(OcuPilot.Api.Error).#TOOLARGUMENTS, "with the arguments code")
    Do $$$AssertTrue($Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.%Get("detail").%Get("problem"), 1: "") [ "'AutheEnabled': ", "and a problem naming the field the screen's rule names")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).ProposalCount($Username), tBefore, "and no proposal was stored")
}

/// <p>AD-54's payload rule: a create composes from the caller's arguments over the tool's settable
/// field list rather than merging over a read that answered nothing, so every supplied field is a
/// diff row and the unchanged count is zero.</p>
/// <p>Mutation: return <code>tTotal - tChanged</code> from
/// <method>OcuPilot.Kernel.Proposal.Mint.Compose</method> instead of 0 -> the unchanged-count
/// assertion goes red.</p>
Method TestTheComposedPayloadIsTheArgumentsAndTheUnchangedCountIsZero()
{
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint(..#TARGET, ..Args(), .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the create is minted")
    If $$$ISERR(tSC) Quit

    Do $$$AssertEquals(tProposal.%Get("unchangedCount"), 0, "a create sends no property the caller did not name")
    Set tChanged = tProposal.%Get("changed")
    Do $$$AssertEquals(tChanged.%Size(), 3, "and every supplied field is a diff row")
    Set tIterator = tChanged.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Do $$$AssertEquals(tRow.%Get("before"), "", tRow.%Get("field") _ " moves from nothing, because there was nothing there")
        Do $$$AssertNotEquals(tRow.%Get("after"), "", "and to the value the caller supplied")
    }

    Set tSC = $ClassMethod(..#STORE, "GuardedByKey", tProposal.%Get("proposalId"), .tFound, .tValues)
    Do $$$AssertStatusOK(tSC, "the stored row reads back")
    Do $$$AssertEquals(tFound, 1, "and it is there")
    If 'tFound Quit
    Set tPayload = ##class(%DynamicAbstractObject).%FromJSON($Get(tValues("payload")))
    Do $$$AssertEquals(tPayload.%Get("NameSpace"), $Namespace, "the stored payload carries the namespace the arguments named")
    Do $$$AssertEquals(tPayload.%GetTypeOf("Name"), "unassigned", "and not the identifying argument, which is the vendor's query parameter and a 400 in the body")
    Do $$$AssertEquals(tPayload.%GetTypeOf("Description"), "string", "and the description")
    ; AD-3: a property no argument named is absent rather than defaulted, because a create sends
    ; what the caller asked for and the instance supplies the rest.
    Do $$$AssertEquals(tPayload.%GetTypeOf("Resource"), "unassigned", "and no property the arguments left alone")
}

/// <p>AD-54's second inversion and its consequence: the confirm's re-read is digested as the
/// target's absence, so a create whose name is still free writes the composed body, and one whose
/// name was taken in between is refused <code>PROPOSAL.TARGETCHANGED</code> at 409 with the row
/// closed and nothing sent.</p>
/// <p>Mutation: return the stored digest unchanged from the create branch of
/// <method>OcuPilot.Kernel.Proposal.Confirm.FingerprintMatches</method> -- that is, set
/// <code>pMatches = 1</code> there -- and the taken-name half goes red with a write at the port.</p>
Method TestTheConfirmWritesOnAFreeNameAndRefusesOneTakenSinceTheMint()
{
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint(..#TARGET, ..Args(), .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the create is minted")
    If $$$ISERR(tSC) Quit
    Set tFirst = tProposal.%Get("proposalId")

    Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite(..#PRESENT)
    Set tSC = ..Confirm(tFirst, .tHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "a confirm whose name is still free is applied")
    Do $$$AssertEquals(tHttp, 200, "at 200")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 1, "and one write went out")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastType(), $ClassMethod(..#TOOL, "WriteType"), "at the tool's own write type")
    Set tSent = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.ProposalFixture).LastWriteBody())
    Do $$$AssertEquals(tSent.%Get("NameSpace"), $Namespace, "carrying the composed body")
    Do $$$AssertEquals(tSent.%GetTypeOf("Type"), "unassigned", "and never Type, which MergeJsonAndProperties hard-codes and RequestBodySchema does not carry")

    ; The same proposal shape, confirmed against a name somebody took in between.
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint(..#TARGET, ..Args(), .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a second create is minted while the name is free")
    If $$$ISERR(tSC) Quit
    Set tSecond = tProposal.%Get("proposalId")

    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#PRESENT)
    Set tSC = ..Confirm(tSecond, .tHttp, .tCode)
    Do $$$AssertStatusNotOK(tSC, "a confirm whose name was taken since the mint is refused")
    Do $$$AssertEquals(tHttp, 409, "at 409")
    Do $$$AssertEquals(tCode, ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "as the target having changed")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and the vendor upsert is never reached")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tSecond, "State"), $Parameter(..#STORE, "STATECANCELED"), "the row is closed")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tSecond, "ClosedReason"), $Parameter(..#STORE, "REASONTARGETCHANGED"), "with the target-changed reason")
}

/// <p>AD-13 over a create: two spellings of one name are one target, so the row a mint stores
/// carries the canonical spelling whichever one the caller typed -- which is what makes AD-34's
/// per-target lock and its sibling cancel cover both.</p>
/// <p>Mutation: make <method>OcuPilot.Kernel.EntityRef.NormalizedId</method> answer its argument
/// verbatim for <code>web-application</code> -> the two refs differ and this goes red.</p>
Method TestTwoSpellingsOfOneNameReachOneTarget()
{
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint(..#OTHERSPELLING, ..Args(), .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "a create named in another spelling is minted")
    If $$$ISERR(tSC) Quit

    Set tTarget = tProposal.%Get("target")
    Do $$$AssertEquals(tTarget.%Get("id"), ..#TARGET, "and its recorded target is the canonical spelling")
    Do $$$AssertEquals(tTarget.%Get("type"), "web-application", "of the web-application type")
    Do $$$AssertEquals(tTarget.%Get("scope"), "instance", "at instance scope")
    ; The read still went out under the spelling the caller typed, because that is the name the
    ; vendor resolves; only the stored reference is canonical.
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastQuery($ClassMethod(..#TOOL, "IdParam")), ..#OTHERSPELLING, "the read asked the instance about the name as it was typed")
}

/// <p>AD-34 over two live creates of one name: the first confirm wins under the per-target lock
/// and the sibling is closed in the same transition, so the loser is refused with its terminal
/// state and never reaches the vendor's upsert.</p>
/// <p>Mutation: drop the sibling cancel from
/// <method>OcuPilot.Kernel.State.Propose.GuardedClaimAndClose</method> -> the loser's stored
/// reason is no longer <code>sibling</code> and this goes red.</p>
Method TestTwoLiveCreatesOfOneNameSerializeAndTheSiblingIsCanceled()
{
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint(..#TARGET, ..Args(), .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the first create is minted")
    If $$$ISERR(tSC) Quit
    Set tFirst = tProposal.%Get("proposalId")

    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint(..#OTHERSPELLING, ..Args(), .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "and a second, named in the other spelling of the same target")
    If $$$ISERR(tSC) Quit
    Set tSecond = tProposal.%Get("proposalId")
    Do $$$AssertNotEquals(tFirst, tSecond, "the two are separate rows")

    Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite(..#PRESENT)
    Set tSC = ..Confirm(tFirst, .tHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "the first confirm wins")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 1, "and one write went out")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tSecond, "State"), $Parameter(..#STORE, "STATECANCELED"), "the sibling is closed in the same transition")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tSecond, "ClosedReason"), $Parameter(..#STORE, "REASONSIBLING"), "as a sibling on the same target")

    Set tSC = ..Confirm(tSecond, .tHttp, .tCode)
    Do $$$AssertStatusNotOK(tSC, "and the loser is refused")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 1, "with no second write, so the vendor upsert is never reached twice")
}

/// <p>AD-15, AD-41 and AD-14 over a create: a confirmed create is marked with an audit event, its
/// ledger row records the fields the write actually sent, and the answer carries the
/// <code>created</code> action the change event travels on.</p>
/// <p>Mutation: return <code>""</code> from
/// <method>OcuPilot.Screen.Tool.WebAppCreate.ChangeAction</method> -> the action assertion goes
/// red. Make <method>OcuPilot.Kernel.Proposal.Mint.Compose</method> leave the diff empty -> the
/// ledger's field list goes red.</p>
Method TestAConfirmedCreateIsMarkedAndItsLedgerRowNamesTheFieldsSent()
{
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint(..#TARGET, ..Args(), .tProposal, .tHttp, .tFault, .tTurnKey)
    Do $$$AssertStatusOK(tSC, "the create is minted")
    If $$$ISERR(tSC) Quit

    Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite(..#PRESENT)
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult)
    Do $$$AssertStatusOK(tSC, "and confirmed")
    If $$$ISERR(tSC) Quit

    ; AD-14: the action is the tool's own declaration, and it is what puts the caret on the new
    ; row rather than re-reading one that was already there.
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("action"), 1: ""), "created", "the answer carries the created action")

    Set tRows = ##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tRow)
    Do $$$AssertEquals(tRows, 1, "the turn holds exactly one write-kind ledger row")
    If tRows '= 1 Quit
    Do $$$AssertEquals($Get(tRow("AuditMarked")), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "and the agent marker landed on it (AD-15)")
    ; The canonical scoped reference (AD-13), which is what the row carries -- not the bare name.
    Set tRefSC = ##class(OcuPilot.Kernel.EntityRef).Key("web-application", "instance", ..#TARGET, .tRef)
    Do $$$AssertStatusOK(tRefSC, "the canonical reference for the created target is built")
    Do $$$AssertEquals($Get(tRow("Target")), tRef, "it names the target the write created")
    ; AD-41: the fields ACTUALLY sent, which for a create is every argument the caller named --
    ; never the identifying one, which is the vendor's query parameter.
    Set tFields = $Get(tRow("Fields"))
    For tName = "NameSpace", "Description", "AutheEnabled" {
        Do $$$AssertTrue(tFields [ tName, "and the ledger records that " _ tName _ " was sent: " _ tFields)
    }
    Set tNamed = 0
    For tI = 1:1:$Length(tFields, ",") {
        If $Piece(tFields, ",", tI) = "Name" Set tNamed = 1
    }
    Do $$$AssertEquals(tNamed, 0, "and not the identifying argument, which is the vendor's query parameter: " _ tFields)
}

/// <p>AD-55 at the <b>confirm's</b> own call site: the body the port receives carries the
/// <code>Path</code> the tool derives from <code>WSGIAppLocation</code>, which no caller may set
/// (AD-21). Asserted on what was actually sent rather than on the derivation in isolation, because
/// a derivation nothing calls sends the vendor a WSGI application serving from nowhere.</p>
/// <p>Mutation: remove the <method>OcuPilot.Kernel.Proposal.Confirm.ToolDerivedFields</method> call
/// from <method>OcuPilot.Kernel.Proposal.Confirm.Transition</method> -> this goes red.</p>
Method TestTheConfirmedBodyCarriesTheServerDerivedPath()
{
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint(..#TARGET, ..WsgiArgs(), .tProposal, .tHttp, .tFault, .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a WSGI create is minted")
    If $$$ISERR(tSC) Quit

    ; The stored payload carries no path: it is the caller's own arguments, and Path is not one.
    Set tStoreSC = $ClassMethod(..#STORE, "GuardedByKey", tProposal.%Get("proposalId"), .tFound, .tValues)
    Do $$$AssertStatusOK(tStoreSC, "the stored row reads back")
    If tFound {
        Set tStored = ##class(%DynamicAbstractObject).%FromJSON($Get(tValues("payload")))
        Do $$$AssertEquals(tStored.%GetTypeOf(..#DERIVEDFIELD), "unassigned", "the stored payload carries no path, because no caller may set one")
    }

    Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite(..#PRESENT)
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult)
    Do $$$AssertStatusOK(tSC, "and confirmed")
    If $$$ISERR(tSC) Quit
    Set tSent = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.ProposalFixture).LastWriteBody())
    Do $$$AssertEquals(tSent.%Get(..#DERIVEDFIELD), ##class(OcuPilot.Area.WebApp.Location).Root() _ ..#WSGILOCATION _ "/", "the body the port received carries the path the tool resolved from the WSGI directory name")
}

/// <p>AD-10 at the mint: a create granting a privileged application role is proposable, and the
/// mint marks <b>that proposal</b> destructive and names the privilege in its consequence -- one
/// combined code when the application is also unauthenticated, never two. A create granting an
/// ordinary role, or none, carries neither. The confirm applies the privileged grant.</p>
/// <p>Mutations: drop <code>tPrivileged</code> from the destructive value in
/// <method>OcuPilot.Kernel.Proposal.Mint.Mint</method> -> the destructive legs go red; make
/// <method>OcuPilot.Kernel.Proposal.Mint.ConsequenceOf</method> ignore <var>pPrivileged</var> -> the
/// consequence legs go red; make <method>OcuPilot.Screen.Tool.WebAppCreate.Consequence</method>
/// ignore it -> the combined leg goes red.</p>
Method TestAPrivilegedApplicationRoleIsMintedDestructiveAndNamed()
{
    Set tPrivileged = $Parameter("OcuPilot.Kernel.Proposal.Mint", "CONSEQUENCEPRIVILEGED")
    Set tCombined = $Parameter(..#TOOL, "CONSEQUENCEUNAUTHENTICATEDPRIVILEGED")
    ; The codes are a wire contract with the client's proposal-view.ts, which matches the literals.
    Do $$$AssertEquals(tPrivileged, "GRANT.PRIVILEGED", "the privileged-grant code is the literal the card resolves")
    Do $$$AssertEquals(tCombined, "WEBAPP.UNAUTHENTICATEDPRIVILEGED", "and so is the combined one")
    For tCase = 1:1:4 {
        Set tArgs = ..Args()
        If tCase '= 4 Do tArgs.%Set("MatchRoles", ##class(%DynamicAbstractObject).%FromJSON("[{""MatchRole"":"""",""TargetRoles"":[""" _ $Select(tCase = 3: "%Developer", 1: "%All") _ """]}]"))
        If tCase = 2 Do tArgs.%Set("AutheEnabled", 64, "number")
        Set tExpectedDestructive = (tCase < 3)
        Set tExpectedConsequence = $Case(tCase, 1: tPrivileged, 2: tCombined, : "")
        Do ##class(OcuPilot.Test.ProposalFixture).Clear()
        Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
        Set tSC = ..Mint(..#TARGET, tArgs, .tProposal, .tHttp, .tFault)
        Do $$$AssertStatusOK(tSC, "case " _ tCase _ ": the create is minted")
        If $$$ISERR(tSC) Continue
        Set tSC = $ClassMethod(..#STORE, "GuardedByKey", tProposal.%Get("proposalId"), .tFound, .tValues)
        Do $$$AssertEquals(+$Get(tValues("destructive")), tExpectedDestructive, "case " _ tCase _ ": the proposal is destructive exactly when it grants privilege")
        Do $$$AssertEquals($Get(tValues("consequence")), tExpectedConsequence, "case " _ tCase _ ": and its consequence names it")
        If tCase '= 1 Continue
        Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite("{}")
        Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult)
        Do $$$AssertStatusOK(tSC, "the privileged create's confirm applies it")
        Set tSent = ##class(%DynamicAbstractObject).%FromJSON(##class(OcuPilot.Test.ProposalFixture).LastWriteBody())
        Do $$$AssertEquals(tSent.%Get("MatchRoles").%ToJSON(), tArgs.%Get("MatchRoles").%ToJSON(), "and the port receives the application roles")
    }
}

/// <p>AD-10 inside the atomic transition: a create at OcuPilot's own path that sets application
/// roles is refused <code>PRIVILEGEGRANT</code> at the confirm, before the port -- the agent's half
/// of AD-10's one remaining privilege-grant refusal; the screen's half is
/// <class>OcuPilot.Test.WebAppCreate</class>'s. The shipped mint proposes it, because the prohibited
/// set is asked at the write.</p>
/// <p>Mutation: make <method>OcuPilot.Kernel.Proposal.Prohibited.Created</method> answer
/// <code>SERVINGPATH</code> whatever an own-path create sets -> the code assertion goes red.</p>
Method TestApplicationRolesOnOcuPilotsOwnPathAreRefusedInsideTheTransition()
{
    Set tSC = ##class(OcuPilot.Install.Roster).Application("api", .tApplication)
    Do $$$AssertStatusOK(tSC, "the roster names OcuPilot's own API application")
    If '$IsObject($Get(tApplication)) Quit
    Set tName = tApplication.%Get("path") _ "/ocupilotprobe"
    Set tArgs = ..Args()
    Do tArgs.%Set("MatchRoles", ##class(%DynamicAbstractObject).%FromJSON("[{""MatchRole"":"""",""TargetRoles"":[""%All""]}]"))
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint(tName, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the mint proposes it")
    If $$$ISERR(tSC) Quit
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode, .tResult)
    Do $$$AssertStatusNotOK(tSC, "the confirm refuses it")
    Do $$$AssertEquals(tHttp, 403, "at 403")
    Do $$$AssertEquals(tCode, $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "PRIVILEGEGRANT"), "on the privilege-grant predicate")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).WriteCount(), 0, "and the vendor upsert is never reached")
}

/// <p>DW-1493, AD-54: a confirmed create names its target to the vendor as the caller typed it --
/// a web application and a user alike -- while the proposal's reference stays canonical (AD-13),
/// so the lock and the sibling cancel still cover every spelling.</p>
/// <p>Mutation (Rule 19): drop the typed-name branch from
/// <method>OcuPilot.Kernel.Proposal.Confirm.FingerprintMatches</method> -- both legs send the
/// canonical spelling and go red.</p>
Method TestAConfirmedCreateNamesItsTargetAsTyped()
{
    Set tTyped = "/csp/CaseProbe92/"
    Set tArgs = ..Args()
    Do tArgs.%Set("Name", tTyped, "string")
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ..Mint(tTyped, tArgs, .tProposal, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the web-application create is minted")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tProposal.%Get("target").%Get("id"), "/csp/caseprobe92", "under the canonical reference")
    Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite(..#PRESENT)
    Set tSC = ..Confirm(tProposal.%Get("proposalId"), .tHttp, .tCode)
    Do $$$AssertStatusOK(tSC, "and its confirm is applied")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastType(), $ClassMethod(..#TOOL, "WriteType"), "the last call is the write")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastQuery($ClassMethod(..#TOOL, "IdParam")), tTyped, "which names the application as it was typed")

    Set tUserTool = "OcuPilot.Screen.Tool.UserCreate"
    Set tUser = "CaseProbe92"
    Set tUserArgs = ##class(OcuPilot.Test.UserCreate).Args()
    Do tUserArgs.%Set("Name", tUser, "string")
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).ArmMissing()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tSC = $ClassMethod(..#MINT, "Mint", $Parameter(tUserTool, "DESCRIPTORCLASS"), $Parameter(tUserTool, "TOOLNAME"), $Username, "", tTurnKey, tUserArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, $ClassMethod(tUserTool, "Endpoint"), $ClassMethod(tUserTool, "IdParam"), tUser, $ClassMethod(tUserTool, "IdArgument"), $ClassMethod(tUserTool, "SettableFields"), tUserTool)
    Do $$$AssertStatusOK(tSC, "the user create is minted: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tProposal.%Get("target").%Get("id"), "caseprobe92", "under the canonical reference")
    Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite("{}")
    Set tResult = ""
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", tProposal.%Get("proposalId"), ##class(OcuPilot.Test.UserCreate).Secrets(), $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "and its confirm is applied")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).LastQuery($ClassMethod(tUserTool, "IdParam")), tUser, "naming the account as it was typed")
}

/// <p>The arguments a WSGI create proposes, so the derived path has something to derive from.</p>
ClassMethod WsgiArgs() As %DynamicObject
{
    Set tArgs = ..Args()
    Do tArgs.%Set("WSGIAppName", "probe.py", "string")
    Do tArgs.%Set("WSGICallable", "app", "string")
    Do tArgs.%Set("WSGIAppLocation", ..#WSGILOCATION, "string")
    Do tArgs.%Set("WSGIType", "WSGI", "string")
    Quit tArgs
}

/// <p>The arguments every create in this class proposes: a namespace, a description and an
/// authentication mask. Three settable fields, so the diff and the unchanged count are both
/// measurable.</p>
ClassMethod Args() As %DynamicObject
{
    Set tArgs = {}
    Do tArgs.%Set("NameSpace", $Namespace, "string")
    Do tArgs.%Set("Description", "OcuPilot create probe", "string")
    Do tArgs.%Set("AutheEnabled", 32, "number")
    Quit tArgs
}

/// <p>Mint one create of <var>pName</var> from <var>pArgs</var> through the fixture mint, with the
/// tool's own endpoint, parameters and settable fields -- the same call
/// <method>OcuPilot.Screen.Tool.Write.View</method> makes.</p>
Method Mint(pName As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject, Output pTurnKey As %String) As %Status
{
    Set pTurnKey = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .pTurnKey)
    Do $$$AssertStatusOK(tSC, "a probe turn is seeded")
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#MINT, "Mint", ..#SCREEN, $Parameter(..#TOOL, "TOOLNAME"), $Username, "", pTurnKey, pArgs, ..#LIMITS, .pProposal, .pHttpStatus, .pFault, $ClassMethod(..#TOOL, "Endpoint"), $ClassMethod(..#TOOL, "IdParam"), pName, $ClassMethod(..#TOOL, "IdArgument"), $ClassMethod(..#TOOL, "SettableFields"), ..#TOOL)
}

/// <p>Confirm <var>pKey</var> through the shipped transition with the fixture port in the seam.</p>
/// <p><var>pResult</var> is the answer the panel receives, which is where the AD-14 action the
/// change event carries is read from.</p>
Method Confirm(pKey As %String, Output pHttp As %Integer, Output pCode As %String, Output pResult As %DynamicObject) As %Status
{
    Set pResult = ""
    Quit $ClassMethod(..#CONFIRM, "Confirm", pKey, "", $Username, .pResult, .pHttp, .pCode, .tDetail)
}

}
