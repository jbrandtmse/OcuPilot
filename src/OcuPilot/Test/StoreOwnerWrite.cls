/// <p>AD-9's owner gate, batch one: the agent definitions, the proposals and the ledger refuse a
/// write from a caller who may not make it, in the store itself, whatever route or code reached it.
/// A real principal holding <code>%Development:USE</code> and the install namespace's code read, and
/// no <code>OcuPilotAdmin</code>, is refused <code>ERROR #822</code> by every public writer of those
/// stores and by <code>Base</code>'s public object saves, and the stored rows read as they did. Its
/// edit of a live proposal that an administrator then confirms changes nothing the confirm sends.
/// The same principal still writes its own rows, an administrator writes anyone's, and the four
/// writes the stores keep open for every caller (a turn's credential finding, the turn and run
/// reserves' sweeps, a close's expiry, abandoning a deleted account's turns) behave as they did
/// before the gate; <method>TestTheOpenPathsStillWork</method> passes on a tree without it.</p>
/// <p>The calls run in a child process logged in as the principal
/// (<class>OcuPilot.Test.OwnerStateWriteProbe</class>); the stored rows are read back here by SQL, as
/// the suite's own <code>%All</code> identity, which also owns the proposals that are confirmed.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates and
/// deletes two users and two roles and writes agent definitions, proposals and ledger rows.
/// <method>OnBeforeAllTests</method> refuses anywhere it does not. Every test removes the rows it
/// created, by the names and keys only this class uses, and asserts the removal.</p>
Class OcuPilot.Test.StoreOwnerWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.OwnerStateWriteProbe";

/// <p>The principal holding <code>%Development:USE</code> and the code read, and nothing else.</p>
Parameter DEVUSER = "OcuPilotOwnerWriteDev";

Parameter DEVROLE = "OcuPilotOwnerWriteDevRole";

/// <p>The principal holding <code>OcuPilotAdmin:USE</code> and the code read, and nothing else.</p>
Parameter ADMINUSER = "OcuPilotOwnerWriteAdmin";

Parameter ADMINROLE = "OcuPilotOwnerWriteAdminRole";

/// <p>The user name whose proposals and ledger rows the developer attacks. No account has it.</p>
Parameter VICTIM = "OcuPilotOwnerWriteVictim";

Parameter VICTIMTURN = "OcuPilotOwnerWriteVictimTurn";

Parameter VICTIMCONV = "OcuPilotOwnerWriteVictimConv";

/// <p>The developer's own conversation and turn keys.</p>
Parameter DEVCONV = "OcuPilotOwnerWriteDevConv";

Parameter DEVTURN = "OcuPilotOwnerWriteDevTurn";

/// <p>The prefix of the three definitions this class creates and removes.</p>
Parameter AGENTPREFIX = "OcuPilotOwnerWriteAgent";

Parameter ORIGINAL = "instructions as an administrator wrote them";

Parameter REWRITTEN = "instructions as a developer rewrote them";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.WebAppList";

Parameter TOOL = "webapp.list.update";

Parameter TARGET = "/csp/ocupilotprobeconfirm";

/// <p>The fresh read every confirm starts from; the write is answered by
/// <class>OcuPilot.Test.ProposalFixture</class>, so nothing reaches the instance.</p>
Parameter FRESH = "{""Name"":""/csp/ocupilotprobeconfirm"",""Description"":""before"",""Enabled"":true}";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter STOREPACKAGE = "OcuPilot.Kernel.State.";

/// <p>The throwaway principals' password, generated for the run.</p>
Property PreparedPassword As %String;

/// <p>The id carrying the default marker before the test.</p>
Property FoundMarked As %String;

/// <p>The turn keys this test seeded, so their rows are removed and no other.</p>
Property SeededTurnKeys [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..FoundMarked = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.StoreOwnerWrite creates and deletes users and roles and writes OcuPilot's stores on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuPilotOwner" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit ##class(OcuPilot.Test.AdminStateWrite).EnsurePrincipals(..PreparedPassword, ..Principals())
}

/// <p>Remove the two principals and their roles; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Quit ##class(OcuPilot.Test.AdminStateWrite).RemovePrincipals(..Principals(), "OcuPilot.Test.StoreOwnerWrite")
}

/// <p>The developer and the administrator, as <method>OcuPilot.Test.AdminStateWrite.EnsurePrincipals</method>
/// takes them.</p>
ClassMethod Principals() As %List
{
    Quit $ListBuild($ListBuild(..#DEVUSER, ..#DEVROLE, "%Development:U", 0), $ListBuild(..#ADMINUSER, ..#ADMINROLE, "OcuPilotAdmin:U", 1))
}

Method OnBeforeOneTest() As %Status
{
    Kill ..SeededTurnKeys
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Set ..FoundMarked = ##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT ID FROM OcuPilot_Kernel_State.Agent WHERE DefaultMark = '1'")
    Quit ..RemoveOwnRows()
}

Method OnAfterOneTest() As %Status
{
    Set tSC = ..RemoveOwnRows()
    Do $$$AssertStatusOK(tSC, "the definitions, proposals, ledger rows and turns this test created are removed")
    Do $$$AssertEquals(..LeftOver(), 0, "and none of them survives")
    If ..FoundMarked '= "" && (##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT ID FROM OcuPilot_Kernel_State.Agent WHERE DefaultMark = '1'") '= ..FoundMarked) {
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).SetDefaultGuarded(..FoundMarked), "the default marker found before the test is put back")
    }
    Quit $$$OK
}

/// <p>A developer -- <code>%Development:USE</code>, no <code>OcuPilotAdmin</code> -- calls each
/// writer of the agent definitions, one call to a child process so each is measured alone against a
/// fresh pair of definitions: rewrite the instructions, create a definition, mark a credential
/// created, set the verification, move the default marker, rebalance it, and save the opened row
/// through <code>Base</code>'s two public saves; the delete comes last. Each is refused
/// <code>822</code> and the definitions read, instructions, flags, marker and version included, as
/// they did.</p>
/// <p>Mutation (Rule 19): <code>Parameter ADMINWRITE = 1</code> removed from
/// <class>OcuPilot.Kernel.State.Agent</class> -> this and the administrator roster test go red.</p>
Method TestADeveloperIsRefusedTheAgentDefinitionWrites()
{
    Set tKinds = ..AgentWriteKinds() _ $ListBuild("Agent.BaseSave", "Agent.BaseSaveIfCurrent")
    For tI = 1:1:$ListLength(tKinds) {
        Set tKind = $List(tKinds, tI)
        Set tTarget = ..SeedDefinitions(tKind = "Agent.GuardedRebalanceDefault")
        If tTarget = "" Quit
        Set tBefore = ..AgentState()
        Set tStep = {"kind": (tKind), "id": (tTarget), "name": (..#AGENTPREFIX _ "New"), "instructions": (..#REWRITTEN)}
        Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, [(tStep)], ..#PROBE)
        If tI = 1 Do ..AssertPrincipal(tRun)
        Set tAfter = ..AgentState()
        Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), tKind _ " ok=0 code=822", tKind _ " is refused 822: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
        Do $$$AssertEquals(tAfter, tBefore, tKind _ " leaves the definitions as they were; before " _ tBefore _ " after " _ tAfter)
    }
}

/// <p>A turn finds a definition's credential no longer resolves and clears its verification, the one
/// agent-definition write open to every caller. The definition is the default; a developer who holds
/// its row with the instructions edited in memory calls <code>GuardedClearVerification</code>: the call
/// is accepted, <code>ConnectionVerified</code> and <code>Enabled</code> read 0, the default marker moves
/// to the enabled definition and the cleared marker reads <code>""</code> through the object layer, no
/// other field changes, and the held edit is not stored.</p>
/// <p>Mutation (Rule 19): <code>GuardedClearVerification</code> opens the row, clears the flags and
/// saves it without a caller check -> this goes red on the held edit alone.</p>
Method TestAClearedVerificationStoresNoHeldEdit()
{
    Set tTarget = ..SeedDefinitions(0)
    If tTarget = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).SetDefaultGuarded(tTarget), "the target carries the default marker")
    Set tOther = ##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT TOP 1 ID FROM OcuPilot_Kernel_State.Agent WHERE Enabled = 1 AND ID <> " _ tTarget _ " ORDER BY ID")
    Set tFields = ..AgentFields(tTarget)
    Set tBefore = ..AgentState()
    Set tStep = {"kind": "Agent.GuardedClearVerification", "id": (tTarget), "holdEditedRow": 1, "instructions": (..#REWRITTEN)}
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, [(tStep)], ..#PROBE)
    Do ..AssertPrincipal(tRun)
    Set tAfter = ..AgentState()
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "Agent.GuardedClearVerification ok=1 code=", "the observation is recorded for a developer: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT Enabled || '|' || ConnectionVerified FROM OcuPilot_Kernel_State.Agent WHERE ID = " _ tTarget), "0|0", "the definition serves no turn")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT ID FROM OcuPilot_Kernel_State.Agent WHERE DefaultMark = '1'"), tOther, "and the default marker moved to the lowest-id enabled definition")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).GuardedOpenId(tTarget, .tRow), "the cleared definition opens")
    Do $$$AssertEquals($IsObject(tRow) && (tRow.DefaultMark = ""), 1, "and its cleared marker reads as empty through the object layer")
    Set tRow = ""
    Do $$$AssertEquals(..AgentFields(tTarget), tFields, "no other field changed, and the held edit is not stored; before " _ tBefore _ " after " _ tAfter)
}

/// <p>A developer calls each writer of another user's ledger and proposals, one child process per
/// call against a fresh victim row of each (<method>VictimKinds</method>). Each is refused
/// <code>822</code> and the victim's rows read, versions included, as they did. The all-users expiry is
/// an administrator's, so it is refused too.</p>
/// <p>Mutation (Rule 19): <code>OwnerWriteRefused</code> answers <code>$$$OK</code> first -> this goes
/// red, and so do the overflow-count and empty-name refusals; no owner, administrator or open-path test
/// does.</p>
Method TestADeveloperIsRefusedAVictimsLedgerAndProposalRows()
{
    Set tKinds = ..VictimKinds() _ $ListBuild("Propose.GuardedExpireStale.All")
    For tI = 1:1:$ListLength(tKinds) {
        Set tKind = $List(tKinds, tI)
        If '..SeedVictim(.tProposalKey, .tLedgerKey) Quit
        If tKind [ "GuardedExpireStale" Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).AgeExpiry(tProposalKey, 3600), "the victim's proposal has lapsed, so an expiry would change it")
        If tKind = "Propose.GuardedRebuildTargetKeys" {
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuPilot_Kernel_State.Proposal SET TargetRef = ? WHERE %EXACT(ProposalKey) = ?", ..#TARGET, tProposalKey)
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuPilot_Kernel_State.Proposal SET TargetKey = NULL WHERE %EXACT(ProposalKey) = ?", tProposalKey)
            Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT TargetRef || '|' || NVL(TargetKey, '') FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(ProposalKey) = '" _ tProposalKey _ "'"), ..#TARGET _ "|", "the victim's proposal names a target and carries no key, so a rebuild would change it")
        }
        Set tBefore = ..VictimState()
        Set tVersion = ##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT RowVersion FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(UserName) = '" _ ..#VICTIM _ "'")
        Set tStep = {"kind": (tKind), "user": (..#VICTIM), "turnKey": (..#VICTIMTURN), "convKey": (..#VICTIMCONV), "target": "", "key": (tProposalKey), "version": (tVersion), "reason": "you", "iso": (##class(OcuPilot.Kernel.State.Turn).IsoOfSeconds(##class(OcuPilot.Kernel.State.Turn).NowSeconds() + 60))}
        If tKind = "Ledger.GuardedFinalize" Do tStep.%Set("key", tLedgerKey)
        If tKind = "Propose.GuardedExpireStale.All" {
            Do tStep.%Set("kind", "Propose.GuardedExpireStale")
            Do tStep.%Set("user", "")
        }
        Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, [(tStep)], ..#PROBE)
        If tI = 1 Do ..AssertPrincipal(tRun)
        Set tAfter = ..VictimState()
        Set tExpected = $Select(tKind = "Propose.GuardedExpireStale.All": "Propose.GuardedExpireStale", 1: tKind) _ " ok=0 code=822"
        Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), tExpected, tKind _ " is refused 822: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
        Do $$$AssertEquals(tAfter, tBefore, tKind _ " leaves the victim's rows as they were; before " _ tBefore _ " after " _ tAfter)
    }
}

/// <p>A developer writes its own rows through every owner writer: mint a proposal, record its
/// read-back, claim one, close one by key, by conversation and by user, expire its own lapsed ones,
/// append a ledger row, finalize it and count overflow calls onto the turn's overflow row (created, then
/// raised). Each is accepted and the rows read as the writer says.</p>
Method TestADeveloperWritesItsOwnProposalAndLedgerRows()
{
    If '..SeedOwn(.tClaimKey, .tCloseKey, .tLedgerKey) Quit
    Set tVersion = ##class(OcuPilot.Test.ProposalFixture).Field(tClaimKey, "RowVersion")
    Set tPlan = ..OwnerPlan(tClaimKey, tVersion, tCloseKey, tLedgerKey)
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun)
    For tI = 1:1:tPlan.%Size() {
        Set tLeg = ##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, tI)
        Do $$$AssertTrue($IsObject(tLeg) && tLeg.%Get("ok"), "step " _ tI _ " is accepted for the owner: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, tI))
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tClaimKey, "State") _ "|" _ ##class(OcuPilot.Test.ProposalFixture).Field(tClaimKey, "Burned"), "confirmed|1", "the claimed proposal is confirmed")
    Do $$$AssertTrue(##class(OcuPilot.Test.ProposalFixture).Field(tClaimKey, "ReadBack") [ "ok", "and carries the read-back")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tCloseKey, "State"), "canceled", "the closed proposal is canceled")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(UserName) = '" _ ..#DEVUSER _ "' AND %EXACT(State) = 'canceled'"), 3, "the three other proposals are canceled by key, conversation and user")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT Status FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(LedgerKey) = '" _ tLedgerKey _ "'"), "forged", "the finalized ledger row carries the new status")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT Dropped FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = '" _ ..#DEVTURN _ "' AND Seq = 0"), 2, "the overflow row counts both calls")
}

/// <p>An administrator -- <code>OcuPilotAdmin:USE</code> and the code read, no <code>%All</code> -- writes
/// another user's rows and the definitions: close a victim proposal, mint one for the victim, finalize
/// the victim's ledger row, expire every user's lapsed proposals, rewrite a definition's instructions
/// through <code>GuardedUpdate</code> and through <code>Base</code>'s save; then
/// rebuild the target keys, purge the ledger before an old date and delete the victim's turn rows, ledger rows and proposals. Each
/// is accepted and stored.</p>
Method TestAnAdministratorWritesAVictimsRowsAndTheDefinitions()
{
    If '..SeedVictim(.tProposalKey, .tLedgerKey) Quit
    Set tTarget = ..SeedDefinitions(0, 0)
    If tTarget = "" Quit
    Set tPlan = []
    Do tPlan.%Push({"kind": "Propose.GuardedClose", "key": (tProposalKey), "user": (..#VICTIM), "reason": "you"})
    Do tPlan.%Push({"kind": "Propose.GuardedMint", "user": (..#VICTIM), "turnKey": (..#VICTIMTURN), "convKey": "", "target": ""})
    Do tPlan.%Push({"kind": "Ledger.GuardedFinalize", "key": (tLedgerKey)})
    Do tPlan.%Push({"kind": "Propose.GuardedExpireStale", "user": ""})
    Do tPlan.%Push({"kind": "Agent.GuardedUpdate", "id": (tTarget), "instructions": (..#REWRITTEN)})
    Do tPlan.%Push({"kind": "Agent.BaseSave", "id": (tTarget), "instructions": (..#REWRITTEN _ " again")})
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#ADMINUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#ADMINUSER, 1)
    For tI = 1:1:tPlan.%Size() {
        Set tLeg = ##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, tI)
        Do $$$AssertTrue($IsObject(tLeg) && tLeg.%Get("ok"), "step " _ tI _ " is accepted for the administrator: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, tI))
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tProposalKey, "State") _ "|" _ ##class(OcuPilot.Test.ProposalFixture).Field(tProposalKey, "ClosedReason"), "canceled|you", "the victim's proposal is closed")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(UserName) = '" _ ..#VICTIM _ "'"), 2, "and the minted one is stored for the victim")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT Status FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(LedgerKey) = '" _ tLedgerKey _ "'"), "forged", "the victim's ledger row is finalized")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT SystemPromptOverride FROM OcuPilot_Kernel_State.Agent WHERE ID = " _ tTarget), ..#REWRITTEN _ " again", "the definition carries the administrator's instructions")
    Set tDelete = ..AdministratorPlan()
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#ADMINUSER, tDelete, ..#PROBE)
    For tI = 1:1:tDelete.%Size() {
        Set tLeg = ##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, tI)
        Do $$$AssertTrue($IsObject(tLeg) && tLeg.%Get("ok"), "delete " _ tI _ " is accepted for the administrator: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, tI))
    }
    Do $$$AssertEquals(..VictimState(), "[][]", "and the victim's rows are gone")
}

/// <p>The highest-risk leg. A developer opens an administrator's live proposal with the public
/// <code>GuardedOpenId</code>, replaces its arguments, payload, diff and fingerprint with the ones a
/// mint wrote for a different description, and saves it through <code>Base.GuardedSave</code>. The
/// save is refused <code>822</code>, the stored row is as it was, and the administrator's confirm
/// sends the description the administrator reviewed.</p>
/// <p>Mutation (Rule 19): <code>PublicSaveRefused</code> answers <code>$$$OK</code> -> this, the
/// conditional-save test and the agent definition test go red.</p>
Method TestAnAdministratorsLiveProposalIsNotEditedThroughGuardedSave()
{
    Do ..EditThenConfirm("save")
}

/// <p>The same attack through <code>Base.GuardedSaveIfCurrent</code>, conditional on the version the
/// opened row carries.</p>
Method TestAnAdministratorsLiveProposalIsNotEditedThroughGuardedSaveIfCurrent()
{
    Do ..EditThenConfirm("saveIfCurrent")
}

/// <p>Mint two proposals for the running identity, as an administrator would have: the one the
/// developer will edit, reviewed with the description <code>after</code>, and the one whose stored
/// values stand for a different description. The developer edits the first with the second's values
/// through the public save <var>pVia</var>; the first is then confirmed through the shipped confirm
/// and the body the port was sent is read.</p>
Method EditThenConfirm(pVia As %String)
{
    Do ##class(OcuPilot.Test.ProposalFixture).Arm(..#FRESH)
    Set tEvilKey = ..SeedProposal("EVIL")
    If tEvilKey = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tEvilKey, .tFound, .tEvil), "the values of the other description are read")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForTurn(tEvil("turnKey")), "and the proposal that held them is removed")
    Set tKey = ..SeedProposal("after")
    If tKey = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tKey, .tFound, .tBefore), "the administrator's proposal is stored")
    Set tId = ..ProposalId(tKey)
    Set tStep = {"kind": "Propose.EditSave", "id": (tId), "via": (pVia), "arguments": (tEvil("arguments")), "payload": (tEvil("payload")), "diff": (tEvil("diff")), "fingerprint": (tEvil("fingerprint"))}
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, [(tStep)], ..#PROBE)
    Do ..AssertPrincipal(tRun)
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tKey, .tFound, .tAfter), "the proposal reads back")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "Propose.EditSave ok=0 code=822", "the developer's save through " _ pVia _ " is refused 822: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
    Do $$$AssertEquals($Get(tAfter("arguments")) _ "|" _ $Get(tAfter("payload")) _ "|" _ $Get(tAfter("fingerprint")), $Get(tBefore("arguments")) _ "|" _ $Get(tBefore("payload")) _ "|" _ $Get(tBefore("fingerprint")), "the stored arguments, payload and fingerprint are as they were; payload before " _ $Get(tBefore("payload")) _ " after " _ $Get(tAfter("payload")))
    Do ##class(OcuPilot.Test.ProposalFixture).ArmWrite(..#FRESH)
    Set tSC = $ClassMethod("OcuPilot.Test.ConfirmFixture", "Confirm", tKey, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the administrator's confirm runs: " _ $System.Status.GetErrorText(tSC))
    Set tSent = ##class(OcuPilot.Test.ProposalFixture).LastWriteBody()
    Set tDescription = $Select(tSent = "": "", 1: ##class(%DynamicObject).%FromJSON(tSent).%Get("Description"))
    Do $$$AssertEquals(tDescription, "after", "and sends the description the administrator reviewed; the confirm sent " _ tSent)
}

/// <p>Mint one live proposal under <parameter>TOOL</parameter> for the running identity on a seeded,
/// completed turn, with the description <var>pDescription</var>, and answer its key.</p>
Method SeedProposal(pDescription As %String) As %String
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "the probe turn is seeded")
    If $$$ISERR(tSC) Quit ""
    Set ..SeededTurnKeys(tTurnKey) = ""
    Set tArgs = {}
    Do tArgs.%Set("Name", ..#TARGET, "string")
    Do tArgs.%Set("Description", pDescription, "string")
    Set tSC = $ClassMethod("OcuPilot.Test.ProposalMint", "Mint", ..#SCREEN, ..#TOOL, $Username, "", tTurnKey, tArgs, ..#LIMITS, .tProposal, .tHttp, .tFault, "WebApp.App", "name", ..#TARGET, "Name", ##class(OcuPilot.Screen.Tool.WebAppUpdate).SettableFields())
    Do $$$AssertStatusOK(tSC, "the probe proposal for '" _ pDescription _ "' mints")
    If $$$ISERR(tSC) Quit ""
    Quit tProposal.%Get("proposalId")
}

/// <p>The id of the proposal row <var>pKey</var> names.</p>
ClassMethod ProposalId(pKey As %String) As %String
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(ProposalKey) = ?", pKey)
    If tRS.%Next() Quit tRS.%GetData(1)
    Quit ""
}

/// <p>A developer opens another user's overflow ledger row, sets its <code>UserName</code> to its own in
/// memory, holds it, and counts an overflow call for itself on that turn: the save would store a row the
/// developer has made its own. It is refused <code>822</code> and the stored owner is still the victim.
/// The other way round, the developer's own row held with the victim's name is refused too and stays the
/// developer's. An administrator may write the victim's row but not change its owner: the same held
/// edit through the writer and through <code>Base.GuardedSave</code> is refused.</p>
/// <p>Mutation (Rule 19): <code>OwnerChangeRefused</code> skips the stored-versus-held owner comparison ->
/// this test goes red.</p>
Method TestAForgedOwnerIsRefusedAndTheStoredOwnerStands()
{
    If '..SeedVictim(.tProposalKey, .tLedgerKey) Quit
    Set tSC = ##class(OcuPilot.Kernel.State.Ledger).GuardedCountOverflow(..#VICTIMTURN, ..#VICTIM, "", .tDropped)
    Do $$$AssertStatusOK(tSC, "the victim's overflow row is stored")
    Set tSC = ##class(OcuPilot.Kernel.State.Ledger).GuardedCountOverflow(..#DEVTURN, ..#DEVUSER, "", .tDropped)
    Do $$$AssertStatusOK(tSC, "and the developer's own")
    Set tVictimRow = ##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT ID FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = '" _ ..#VICTIMTURN _ "' AND Seq = 0")
    Set tOwnRow = ##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT ID FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = '" _ ..#DEVTURN _ "' AND Seq = 0")
    Set tBefore = ..OverflowState()
    Set tPlan = [{"kind": "Ledger.ForgedOverflow", "id": (tVictimRow), "turnKey": (..#VICTIMTURN), "heldUser": (..#DEVUSER), "user": (..#DEVUSER)}, {"kind": "Ledger.ForgedOverflow", "id": (tOwnRow), "turnKey": (..#DEVTURN), "heldUser": (..#VICTIM), "user": (..#DEVUSER)}]
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun)
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "Ledger.ForgedOverflow ok=0 code=822", "the victim's row held as the developer's is refused 822: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, 1))
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 2), "Ledger.ForgedOverflow ok=0 code=822", "the developer's row held as the victim's is refused 822: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, 2))
    Set tPlan = [{"kind": "Ledger.ForgedOverflow", "id": (tVictimRow), "turnKey": (..#VICTIMTURN), "heldUser": (..#ADMINUSER), "user": (..#ADMINUSER)}, {"kind": "Ledger.ForgedSave", "id": (tVictimRow), "heldUser": (..#ADMINUSER)}]
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#ADMINUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#ADMINUSER, 1)
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "Ledger.ForgedOverflow ok=0 code=822", "an administrator's writer save of the victim's row held under another owner is refused 822: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, 1))
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 2), "Ledger.ForgedSave ok=0 code=822", "and so is its public save: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, 2))
    Do $$$AssertEquals(..OverflowState(), tBefore, "the stored owners, counts and versions are as they were; before " _ tBefore _ " after " _ ..OverflowState())
}

/// <p>A developer claims its own proposal, which names no target, passing the target of a victim's live
/// proposal: the claim would cancel the victim's proposal as its sibling. It is refused <code>822</code>,
/// the victim's proposal is still live and the developer's is not claimed.</p>
/// <p>Mutation (Rule 19): the stored-target check removed from <code>GuardedClaimAndClose</code> -> this
/// goes red.</p>
Method TestAClaimCancelsOnlyItsOwnTargetsSiblings()
{
    If '..SeedOwn(.tOwnKey, .tCloseKey, .tLedgerKey) Quit
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedMinimal(..#VICTIM, "", ..#VICTIMTURN, ..#TARGET, .tVictimKey)
    Do $$$AssertStatusOK(tSC, "a live proposal of the victim names the target")
    If $$$ISERR(tSC) Quit
    Set tStep = {"kind": "Propose.GuardedClaimAndClose", "key": (tOwnKey), "version": (##class(OcuPilot.Test.ProposalFixture).Field(tOwnKey, "RowVersion")), "target": (..#TARGET)}
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, [(tStep)], ..#PROBE)
    Do ..AssertPrincipal(tRun)
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "Propose.GuardedClaimAndClose ok=0 code=822", "the claim naming another target is refused 822: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tVictimKey, "State"), "live", "the victim's proposal is still live")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tOwnKey, "State") _ "|" _ ##class(OcuPilot.Test.ProposalFixture).Field(tOwnKey, "Burned"), "live|0", "and the developer's is not claimed")
}

/// <p>A developer counts an overflow call for itself onto the turn key of a victim's stored overflow
/// row, holding nothing: the call would raise a row another user owns. It is refused <code>822</code>
/// and the victim's row is as it was.</p>
/// <p>Mutation (Rule 19): the held-owner <code>OwnerWriteRefused</code> call removed from
/// <code>GuardedSaveOwned</code> -> this goes red, and no other test of the class does.</p>
Method TestADeveloperIsRefusedACountOntoAVictimsOverflowRow()
{
    If '..SeedVictim(.tProposalKey, .tLedgerKey) Quit
    Set tSC = ##class(OcuPilot.Kernel.State.Ledger).GuardedCountOverflow(..#VICTIMTURN, ..#VICTIM, "", .tDropped)
    Do $$$AssertStatusOK(tSC, "the victim's overflow row is stored")
    Set tBefore = ..OverflowState()
    Do $$$AssertTrue(tBefore [ ..#VICTIMTURN, "and it reads back: " _ tBefore)
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, [{"kind": "Ledger.GuardedCountOverflow", "turnKey": (..#VICTIMTURN), "user": (..#DEVUSER)}], ..#PROBE)
    Do ..AssertPrincipal(tRun)
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "Ledger.GuardedCountOverflow ok=0 code=822", "the developer's count is refused 822: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
    Do $$$AssertEquals(..OverflowState(), tBefore, "and the victim's overflow row is as it was; before " _ tBefore _ " after " _ ..OverflowState())
}

/// <p>The owner test compares names as IRIS does: a developer's own ledger append under its name in
/// lower case and in upper case is accepted, and one under the empty name is refused <code>822</code>
/// and stores nothing.</p>
/// <p>Mutation (Rule 19): <code>CallerOwns</code> compares with <code>=</code> -> the case legs go red.</p>
Method TestTheOwnerComparisonIgnoresCaseAndRefusesAnEmptyName()
{
    Set ..SeededTurnKeys(..#DEVTURN) = ""
    Set tPlan = []
    Do tPlan.%Push({"kind": "Ledger.GuardedAppend", "user": ($ZConvert(..#DEVUSER, "L")), "turnKey": (..#DEVTURN)})
    Do tPlan.%Push({"kind": "Ledger.GuardedAppend", "user": ($ZConvert(..#DEVUSER, "U")), "turnKey": (..#DEVTURN)})
    Do tPlan.%Push({"kind": "Ledger.GuardedAppend", "user": "", "turnKey": (..#DEVTURN)})
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun)
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "Ledger.GuardedAppend ok=1 code=", "the lower-case name is accepted: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, 1))
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 2), "Ledger.GuardedAppend ok=1 code=", "the upper-case name is accepted: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, 2))
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 3), "Ledger.GuardedAppend ok=0 code=822", "the empty name is refused 822: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, 3))
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = '" _ ..#DEVTURN _ "'"), 2, "and only the two accepted rows are stored")
}

/// <p>A finalize of a ledger key that names no row: a developer is refused <code>822</code>, as an
/// unresolved owner is; an administrator is answered OK and nothing is stored.</p>
/// <p>Mutation (Rule 19): <code>KeyOwnerRefused</code> answers <code>$$$OK</code> for an unresolved
/// owner -> the developer leg goes red.</p>
Method TestAFinalizeOfAKeyThatNamesNoRowIsRefusedForAStranger()
{
    Set tKey = "OcuPilotOwnerWriteNoSuchLedgerKey"
    Set tPlan = [{"kind": "Ledger.GuardedFinalize", "key": (tKey)}]
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun)
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "Ledger.GuardedFinalize ok=0 code=822", "the developer is refused 822: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#ADMINUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#ADMINUSER, 1)
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "Ledger.GuardedFinalize ok=1 code=", "the administrator is answered OK: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(LedgerKey) = '" _ tKey _ "'"), 0, "and no row is stored")
}

/// <p>The paths the stores keep open to every caller work as a real developer, one with no
/// <code>OcuPilotAdmin</code>, against a victim's rows, and have the effect they had before the gate
/// (this test passes on a tree without it):</p>
/// <ol>
/// <li>a security administrator's abandon of a deleted account's running turn
/// (<code>Turn.GuardedAbandonForUser</code>);</li>
/// <li>a turn reserve sweeps another user's expired terminal turn with its proposal, and stores its own;</li>
/// <li>a background run reserve sweeps another user's ended run;</li>
/// <li>a proposal close by key and a close by conversation expire another user's lapsed proposal and
/// close the caller's own (a close by user expires only the caller's own lapsed proposals, and is
/// unchanged);</li>
/// <li>a turn disables a definition whose credential no longer resolves, and the marker moves.</li>
/// </ol>
/// <p>Mutation (Rule 19): <code>GuardedClearVerification</code> saves through <code>GuardedUpdate</code>
/// again -> the fifth leg goes red.</p>
Method TestTheOpenPathsStillWork()
{
    Do ..AssertAbandonForDeletedUser()
    Do ..AssertReserveSweepsExpiredTurns()
    Do ..AssertRunReserveSweepsEndedRuns()
    For tKind = "Propose.GuardedClose", "Propose.GuardedCloseLiveForConvo" {
        Do ..AssertCloseExpiresLapsedProposals(tKind)
    }
    Do ..AssertCredentialFindingDisablesDefinition()
}

/// <p>Path 1: the developer abandons a victim's running turn; the turn is asked to abandon.</p>
Method AssertAbandonForDeletedUser()
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(..#VICTIM, "running", .tTurn)
    Do $$$AssertStatusOK(tSC, "a running turn of the victim is stored")
    If $$$ISERR(tSC) Quit
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, [{"kind": "Turn.GuardedAbandonForUser", "user": (..#VICTIM)}], ..#PROBE)
    Do ..AssertPrincipal(tRun)
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "Turn.GuardedAbandonForUser ok=1 code=", "the abandon is accepted: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 1).%Get("count"), 1, "it names the one running turn")
    Do $$$AssertEquals($Get(^OcuPilotTurnSignal(tTurn, "abandon")), 1, "which carries the abandon signal")
}

/// <p>Path 2: the developer reserves a turn; the victim's expired terminal turn and its proposal are swept
/// and the developer's own turn is stored.</p>
Method AssertReserveSweepsExpiredTurns()
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(..#VICTIM, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "a completed turn of the victim is stored")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedMinimal(..#VICTIM, "", tTurn, "", .tProposal)
    Do $$$AssertStatusOK(tSC, "with a proposal minted on it")
    Set tAged = ##class(OcuPilot.Kernel.State.Turn).IsoOfSeconds(##class(OcuPilot.Kernel.State.Turn).NowSeconds() - 86400)
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuPilot_Kernel_State.Turn SET EndedAt = ? WHERE %EXACT(TurnKey) = ?", tAged, tTurn)
    Do $$$AssertTrue(tRS.%SQLCODE >= 0, "whose end is a day old")
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, [{"kind": "Turn.GuardedReserve", "user": (..#DEVUSER)}], ..#PROBE)
    Do ..AssertPrincipal(tRun)
    Set tLeg = ##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 1)
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "Turn.GuardedReserve ok=1 code=", "the reserve is accepted: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
    Do $$$AssertTrue($IsObject(tLeg) && (tLeg.%Get("key") '= "") && 'tLeg.%Get("busy") && tLeg.%Get("sweepOk"), "it stores the developer's turn and the sweep reports success")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).TurnCountForTurn(tTurn), 0, "and the victim's expired turn is swept")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).ProposalCountForTurn(tTurn), 0, "with the proposal minted on it")
}

/// <p>Path 3: the developer reserves a background run; the victim's ended run is swept.</p>
Method AssertRunReserveSweepsEndedRuns()
{
    Set tKey = "OcuPilotOwnerWriteVictimRun"
    Set tAged = ##class(OcuPilot.Kernel.State.Turn).IsoOfSeconds(##class(OcuPilot.Kernel.State.Turn).NowSeconds() - 86400)
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "INSERT INTO OcuPilot_Kernel_State.SqlRun (RunKey, UserName, Namespace, State, QueuedAt, EndedAt, Kind, RowVersion) VALUES (?, ?, ?, 'ended', ?, ?, 'sql', 1)", tKey, ..#VICTIM, $NAMESPACE, tAged, tAged)
    Do $$$AssertTrue(tRS.%SQLCODE >= 0, "an ended run of the victim, a day old, is stored")
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, [{"kind": "SqlRun.GuardedReserve", "user": (..#DEVUSER)}], ..#PROBE)
    Do ..AssertPrincipal(tRun)
    Set tLeg = ##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 1)
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "SqlRun.GuardedReserve ok=1 code=", "the reserve is accepted: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
    Do $$$AssertTrue($IsObject(tLeg) && (tLeg.%Get("key") '= "") && tLeg.%Get("sweepOk"), "it stores the developer's run and the sweep reports success")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = '" _ tKey _ "'"), 0, "and the victim's ended run is swept")
}

/// <p>Path 4: the developer closes its own live proposal with the writer <var>pKind</var>; the victim's
/// lapsed proposal reads <code>expired</code> and the developer's is canceled.</p>
Method AssertCloseExpiresLapsedProposals(pKind As %String)
{
    Do ..RemoveOwnRows()
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedMinimal(..#VICTIM, "", ..#VICTIMTURN, "", .tLapsed)
    Do $$$AssertStatusOK(tSC, pKind _ ": a live proposal of the victim is stored")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedMinimal(..#DEVUSER, ..#DEVCONV, ..#DEVTURN, "", .tOwn)
    Do $$$AssertStatusOK(tSC, "and one of the developer's")
    If $$$ISERR(tSC) Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).AgeExpiry(tLapsed, 3600), "the victim's has lapsed")
    Set tStep = {"kind": (pKind), "key": (tOwn), "user": (..#DEVUSER), "convKey": (..#DEVCONV), "reason": "you"}
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, [(tStep)], ..#PROBE)
    Do ..AssertPrincipal(tRun)
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), pKind _ " ok=1 code=", pKind _ " is accepted: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tOwn, "State"), "canceled", "the developer's proposal is canceled")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tLapsed, "State"), "expired", pKind _ " also expires the victim's lapsed proposal")
}

/// <p>Path 5: the developer, whose turn finds the default definition's credential gone, clears it; the
/// definition is disabled and the marker moves to the other.</p>
Method AssertCredentialFindingDisablesDefinition()
{
    Set tTarget = ..SeedDefinitions(0)
    If tTarget = "" Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Agent).SetDefaultGuarded(tTarget), "the target is the default")
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, [{"kind": "Agent.GuardedClearVerification", "id": (tTarget)}], ..#PROBE)
    Do ..AssertPrincipal(tRun)
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "Agent.GuardedClearVerification ok=1 code=", "the finding is recorded: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT Enabled || '|' || ConnectionVerified FROM OcuPilot_Kernel_State.Agent WHERE ID = " _ tTarget), "0|0", "the definition is disabled")
    Do $$$AssertNotEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT ID FROM OcuPilot_Kernel_State.Agent WHERE DefaultMark = '1'"), tTarget, "and the default marker has moved off it")
}

/// <p>The owner stores are the classes whose compiled <code>OWNERWRITE</code> is not empty, and each one's
/// own public class methods are exactly its declared reads, owner writes, administrator writes and open
/// writes (<method>Reads</method>, <method>OwnerWrites</method>, <method>AdministratorWrites</method>,
/// <method>OpenWrites</method>). Every owner write is a step of the stranger's list
/// (<method>VictimKinds</method>) and of the plan the owner runs (<method>OwnerPlan</method>), every
/// administrator write one of the stranger's list and of the plan the administrator runs
/// (<method>AdministratorPlan</method>), and every open write one the open-path test reaches. <code>Base</code>'s own new public methods are in
/// <method>OcuPilot.Test.AdminStateWrite.BaseSurface</method>.</p>
/// <p>Mutation (Rule 19): <code>Parameter OWNERWRITE</code> emptied on
/// <class>OcuPilot.Kernel.State.Ledger</class> -> this, the victim rows test and the forged-owner test
/// go red. The classes this class does not cover are the ones <class>OcuPilot.Test.TranscriptOwnerWrite</class>
/// and <class>OcuPilot.Test.PrefOwnerWrite</class> name.</p>
Method TestTheOwnerStoresAreDeclared()
{
    Set tStores = $ListBuild("Ledger", "Propose")
    Set tOwnerRan = ##class(OcuPilot.Test.AdminStateWrite).KindsOf(..OwnerPlan("", 0, "", ""))
    Set tAdministratorRan = ##class(OcuPilot.Test.AdminStateWrite).KindsOf(..AdministratorPlan())
    Set tDeclared = ""
    Set tAllStores = tStores _ ##class(OcuPilot.Test.TranscriptOwnerWrite).Stores() _ ##class(OcuPilot.Test.PrefOwnerWrite).Stores()
    For tI = 1:1:$ListLength(tAllStores) {
        Set tDeclared = tDeclared _ $ListBuild(..#STOREPACKAGE _ $List(tAllStores, tI))
    }
    Set tFound = ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT parent FROM %Dictionary.CompiledParameter WHERE Name = 'OWNERWRITE' AND _Default IS NOT NULL AND _Default <> '' ORDER BY parent")
    While tRS.%Next() {
        Set tFound = tFound _ $ListBuild(tRS.%GetData(1))
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).SortedJoin(tFound), ##class(OcuPilot.Test.AdminStateWrite).SortedJoin(tDeclared), "the classes whose compiled OWNERWRITE is not empty are this class's two stores, the transcript stores and the preference, sharing and run stores")
    For tI = 1:1:$ListLength(tStores) {
        Set tStore = $List(tStores, tI)
        Set tClass = ..#STOREPACKAGE _ tStore
        Set tPublic = ""
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.MethodDefinition WHERE parent = ? AND ClassMethod = 1 AND Private = 0", tClass)
        While tRS.%Next() {
            Set tPublic = tPublic _ $ListBuild(tRS.%GetData(1))
        }
        Set tSplit = ..Reads(tStore) _ ..OwnerWrites(tStore) _ ..AdministratorWrites(tStore) _ ..OpenWrites(tStore)
        Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).SortedJoin(tPublic), ##class(OcuPilot.Test.AdminStateWrite).SortedJoin(tSplit), tStore _ "'s public class methods are its declared reads, owner writes, administrator writes and open writes")
        Do ..AssertCalled(tStore, ..OwnerWrites(tStore), ..VictimKinds(), "an owner write is tried by a stranger")
        Do ..AssertCalled(tStore, ..OwnerWrites(tStore), tOwnerRan, "an owner write is run by the owner's plan")
        Do ..AssertCalled(tStore, ..AdministratorWrites(tStore), ..VictimKinds(), "an administrator write is tried by a stranger")
        Do ..AssertCalled(tStore, ..AdministratorWrites(tStore), tAdministratorRan, "an administrator write is run by the administrator's plan")
        Do ..AssertCalled(tStore, ..OpenWrites(tStore), ..OpenKinds(), "an open write is reached by the open-path test")
    }
    Set tHandled = ""
    Set tAll = ..VictimKinds() _ tOwnerRan _ tAdministratorRan _ ..OpenKinds() _ ..AgentWriteKinds()
    For tI = 1:1:$ListLength(tAll) {
        If '$ClassMethod(..#PROBE, "Handles", $List(tAll, tI)) Set tHandled = tHandled _ " " _ $List(tAll, tI)
    }
    Do $$$AssertEquals(tHandled, "", "every step the tests name is one the probe runs")
}

/// <p>Assert that every method of <var>pMethods</var> on <var>pStore</var> is a kind in <var>pKinds</var>.</p>
Method AssertCalled(pStore As %String, pMethods As %List, pKinds As %List, pMessage As %String)
{
    Set tMissing = ""
    For tJ = 1:1:$ListLength(pMethods) {
        If '$ListFind(pKinds, pStore _ "." _ $List(pMethods, tJ)) Set tMissing = tMissing _ " " _ pStore _ "." _ $List(pMethods, tJ)
    }
    Do $$$AssertEquals(tMissing, "", pMessage)
}

/// <p>The steps a stranger is refused on another user's rows, one child process each.</p>
ClassMethod VictimKinds() As %List
{
    Quit $ListBuild("Ledger.GuardedAppend", "Ledger.GuardedFinalize", "Ledger.GuardedCountOverflow", "Ledger.GuardedDeleteForTurn", "Ledger.GuardedDeleteForUser", "Ledger.GuardedPurgeBefore", "Propose.GuardedDeleteForTurn", "Propose.GuardedMint", "Propose.GuardedRecordReadBack", "Propose.GuardedClaimAndClose", "Propose.GuardedClose", "Propose.GuardedCloseLiveForConvo", "Propose.GuardedCloseLiveForUser", "Propose.GuardedExpireStale", "Propose.GuardedRebuildTargetKeys", "Propose.GuardedDeleteForUser")
}

/// <p>The steps the owner of the rows makes, in the order <method>OwnerPlan</method> runs them.</p>
ClassMethod OwnerKinds() As %List
{
    Quit $ListBuild("Propose.GuardedMint", "Propose.GuardedRecordReadBack", "Propose.GuardedClaimAndClose", "Propose.GuardedClose", "Propose.GuardedCloseLiveForConvo", "Propose.GuardedCloseLiveForUser", "Propose.GuardedExpireStale", "Ledger.GuardedAppend", "Ledger.GuardedFinalize", "Ledger.GuardedCountOverflow")
}

/// <p>The steps an administrator makes on rows that are not its own, in the order
/// <method>AdministratorPlan</method> runs them.</p>
ClassMethod AdministratorKinds() As %List
{
    Quit $ListBuild("Propose.GuardedRebuildTargetKeys", "Ledger.GuardedPurgeBefore", "Ledger.GuardedDeleteForTurn", "Ledger.GuardedDeleteForUser", "Propose.GuardedDeleteForTurn", "Propose.GuardedDeleteForUser")
}

/// <p>The plan the developer runs against its own rows: one step for each of
/// <method>OwnerKinds</method>, plus the second proposal the close by user needs and the second overflow
/// count that raises the row the first created.</p>
ClassMethod OwnerPlan(pClaimKey As %String, pClaimVersion As %String, pCloseKey As %String, pLedgerKey As %String) As %DynamicArray
{
    Set tPlan = []
    Set tKinds = ..OwnerKinds()
    For tI = 1:1:$ListLength(tKinds) {
        Set tKind = $List(tKinds, tI)
        Set tStep = {"kind": (tKind), "user": (..#DEVUSER), "turnKey": (..#DEVTURN), "convKey": "", "target": "", "reason": "you", "key": "", "version": 0}
        If tKind = "Propose.GuardedMint" Do tStep.%Set("convKey", ..#DEVCONV)
        If tKind = "Propose.GuardedRecordReadBack" Do tStep.%Set("key", pClaimKey)
        If tKind = "Propose.GuardedClaimAndClose" {
            Do tStep.%Set("key", pClaimKey)
            Do tStep.%Set("version", pClaimVersion)
        }
        If tKind = "Propose.GuardedClose" Do tStep.%Set("key", pCloseKey)
        If tKind = "Propose.GuardedCloseLiveForConvo" {
            Do tStep.%Set("convKey", ..#DEVCONV)
            Do tStep.%Set("reason", "message")
        }
        If tKind = "Ledger.GuardedFinalize" Do tStep.%Set("key", pLedgerKey)
        Do tPlan.%Push(tStep)
        If tKind = "Propose.GuardedCloseLiveForConvo" Do tPlan.%Push({"kind": "Propose.GuardedMint", "user": (..#DEVUSER), "turnKey": (..#DEVTURN), "convKey": "", "target": ""})
        If tKind = "Ledger.GuardedCountOverflow" Do tPlan.%Push(tStep)
    }
    Quit tPlan
}

/// <p>The plan the administrator runs against the victim's rows and the ledger: one step for each of
/// <method>AdministratorKinds</method>.</p>
ClassMethod AdministratorPlan() As %DynamicArray
{
    Set tPlan = []
    Set tKinds = ..AdministratorKinds()
    For tI = 1:1:$ListLength(tKinds) {
        Do tPlan.%Push({"kind": ($List(tKinds, tI)), "turnKey": (..#VICTIMTURN), "user": (..#VICTIM), "iso": "2000-01-01T00:00:00Z"})
    }
    Quit tPlan
}

/// <p>The open writes the open-path test reaches.</p>
ClassMethod OpenKinds() As %List
{
    Quit $ListBuild("Agent.GuardedClearVerification", "Turn.GuardedAbandonForUser", "Turn.GuardedReserve", "SqlRun.GuardedReserve")
}

/// <p>The agent definition writers a developer is refused; the administrator roster test reads them.</p>
ClassMethod AgentWriteKinds() As %List
{
    Quit $ListBuild("Agent.GuardedUpdate", "Agent.GuardedCreate", "Agent.GuardedMarkCredentialCreated", "Agent.GuardedSetVerification", "Agent.SetDefaultGuarded", "Agent.GuardedRebalanceDefault", "Agent.GuardedDeleteId")
}

/// <p>The reads <var>pStore</var> declares: its public class methods that write no row.</p>
ClassMethod Reads(pStore As %String) As %List
{
    If pStore = "Ledger" Quit $ListBuild("GuardedIdsForWindow", "GuardedDroppedFor", "GuardedRow", "GuardedCountForTurn")
    Quit $ListBuild("GuardedByToken", "GuardedByKey", "TargetLockKey", "TargetHoldKey", "GuardedTargetHold", "GuardedTargetRelease", "GuardedRowVersion", "ProjectedState", "GuardedRowsForTurn", "GuardedRowsForConvo", "GuardedCountForTurn", "NowSeconds", "SecondsOf")
}

/// <p>The writes <var>pStore</var> refuses a caller who does not own the row.</p>
ClassMethod OwnerWrites(pStore As %String) As %List
{
    If pStore = "Ledger" Quit $ListBuild("GuardedAppend", "GuardedFinalize", "GuardedCountOverflow")
    Quit $ListBuild("GuardedMint", "GuardedRecordReadBack", "GuardedClaimAndClose", "GuardedClose", "GuardedCloseLiveForConvo", "GuardedCloseLiveForUser", "GuardedExpireStale")
}

/// <p>The writes <var>pStore</var> refuses a caller who does not hold the administrator privilege.</p>
ClassMethod AdministratorWrites(pStore As %String) As %List
{
    If pStore = "Ledger" Quit $ListBuild("GuardedDeleteForTurn", "GuardedDeleteForUser", "GuardedPurgeBefore")
    Quit $ListBuild("GuardedRebuildTargetKeys", "GuardedDeleteForTurn", "GuardedDeleteForUser")
}

/// <p>The writes <var>pStore</var> leaves open to every caller.</p>
ClassMethod OpenWrites(pStore As %String) As %List
{
    Quit ""
}

/// <p>Remove the three definitions, the victim's and the developer's rows, and the seeded turns'
/// proposals, turns and ledger rows. Only names and keys this class owns are touched.</p>
Method RemoveOwnRows() As %Status
{
    Set tSC = $$$OK
    For tName = "Target", "Other", "New" {
        Set tIdSC = ##class(OcuPilot.Kernel.State.Agent).GuardedByName(..#AGENTPREFIX _ tName, .tId)
        If $$$ISOK(tIdSC) && ($Get(tId) '= "") Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Agent).GuardedDeleteId(tId))
        Kill tId
    }
    For tUser = ..#VICTIM, ..#DEVUSER {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT TurnKey FROM OcuPilot_Kernel_State.Turn WHERE %EXACT(UserName) = ?", tUser)
        While tRS.%Next() {
            Set tKeys($Increment(tKeys)) = tRS.%GetData(1)
        }
        For tI = 1:1:+$Get(tKeys) {
            Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Turn).GuardedDelete(tKeys(tI)))
        }
        Kill tKeys
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Turn).GuardedForgetStarts(tUser))
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(UserName) = ?", tUser)
        If tRS.%SQLCODE < 0 Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the run rows could not be removed: SQLCODE=" _ tRS.%SQLCODE))
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser(tUser))
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForUser(tUser))
    }
    Set tTurn = ""
    For {
        Set tTurn = $Order(..SeededTurnKeys(tTurn))
        If tTurn = "" Quit
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurn))
    }
    Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining))
    Quit tSC
}

/// <p>How many rows of the definitions this class creates and of the victim's and the developer's
/// proposals, ledger rows, turns and runs survive, whatever case their owner name was written in; the sum is 0 once <method>RemoveOwnRows</method> has
/// run.</p>
ClassMethod LeftOver() As %Integer
{
    Set tCount = ##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Agent WHERE Name LIKE '" _ ..#AGENTPREFIX _ "%'")
    For tTable = "Proposal", "Ledger", "Turn", "SqlRun" {
        Set tCount = tCount + ##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State." _ tTable _ " WHERE UserName IN ('" _ ..#VICTIM _ "', '" _ ..#DEVUSER _ "')")
    }
    Quit tCount
}

/// <p>Remove this class's definitions and create two as the suite's own identity: the target the
/// developer attacks, enabled and not verified, and another, enabled and carrying the default marker
/// (or, with <var>pDisableMarked</var>, disabled while it carries it). <var>pClean</var> 0 leaves the
/// rows of other legs in place. Answers the target's id, or <code>""</code> after a failed
/// assertion.</p>
Method SeedDefinitions(pDisableMarked As %Boolean, pClean As %Boolean = 1) As %String
{
    If pClean {
        Set tSC = ..RemoveOwnRows()
        Do $$$AssertStatusOK(tSC, "the definitions of an earlier leg are removed")
    }
    For tName = "Other", "Target" {
        Set tRow = ##class(OcuPilot.Kernel.State.Agent).%New()
        Set tRow.Name = ..#AGENTPREFIX _ tName
        Set tRow.Provider = "openai"
        Set tRow.Model = "probe-model-1"
        Set tRow.CredType = "env"
        Set tRow.EnvVarName = "OCUPILOT_PROBE_LOCAL_KEY"
        Set tRow.SystemPromptOverride = ..#ORIGINAL
        Set tRow.Enabled = 1
        Set tRow.ConnectionVerified = 0
        Set tSC = ##class(OcuPilot.Kernel.State.Agent).GuardedCreate(tRow)
        Do $$$AssertStatusOK(tSC, "the " _ tName _ " definition is stored")
        If $$$ISERR(tSC) Quit
        Set tId(tName) = tRow.%Id()
        Set tRow = ""
    }
    If $$$ISERR(tSC) Quit ""
    Set tSC = ##class(OcuPilot.Kernel.State.Agent).SetDefaultGuarded(tId("Other"))
    Do $$$AssertStatusOK(tSC, "the other definition carries the default marker")
    If pDisableMarked {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuPilot_Kernel_State.Agent SET Enabled = 0 WHERE ID = ?", tId("Other"))
        Do $$$AssertTrue(tRS.%SQLCODE >= 0, "and is disabled")
    }
    Quit tId("Target")
}

/// <p>Remove the rows of an earlier leg and store, as the suite's own identity, one live proposal and one
/// ledger row for the victim; their keys come back. Answers 0 after a failed assertion.</p>
Method SeedVictim(Output pProposalKey As %String, Output pLedgerKey As %String) As %Boolean
{
    Set tSC = ..RemoveOwnRows()
    Do $$$AssertStatusOK(tSC, "the victim's rows of an earlier leg are removed")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedMinimal(..#VICTIM, ..#VICTIMCONV, ..#VICTIMTURN, "", .pProposalKey)
    Do $$$AssertStatusOK(tSC, "a live proposal is stored for the victim")
    If $$$ISERR(tSC) Quit 0
    Set tSC = ##class(OcuPilot.Kernel.State.Ledger).GuardedAppend(..#VICTIMTURN, ..#VICTIM, "probe", "tool", "probe.victim", "", "", "", 0, "ok", "", 0, 0, "", ..#LIMITS, .tSeq, .tStored, 0, "", .pLedgerKey)
    Do $$$AssertStatusOK(tSC, "and a ledger row")
    Quit $$$ISOK(tSC) && tStored
}

/// <p>Remove the rows of an earlier leg and store, as the suite's own identity, two live proposals and
/// one ledger row for the developer, who owns them; the keys come back. Answers 0 after a failed
/// assertion.</p>
Method SeedOwn(Output pClaimKey As %String, Output pCloseKey As %String, Output pLedgerKey As %String) As %Boolean
{
    Set tSC = ..RemoveOwnRows()
    Do $$$AssertStatusOK(tSC, "the developer's rows of an earlier leg are removed")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedMinimal(..#DEVUSER, "", ..#DEVTURN, "", .pClaimKey)
    Do $$$AssertStatusOK(tSC, "a live proposal to claim is stored for the developer")
    If $$$ISERR(tSC) Quit 0
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedMinimal(..#DEVUSER, "", ..#DEVTURN, "", .pCloseKey)
    Do $$$AssertStatusOK(tSC, "and one to close")
    If $$$ISERR(tSC) Quit 0
    Set tSC = ##class(OcuPilot.Kernel.State.Ledger).GuardedAppend(..#DEVTURN, ..#DEVUSER, "probe", "tool", "probe.own", "", "", "", 0, "ok", "", 0, 0, "", ..#LIMITS, .tSeq, .tStored, 0, "", .pLedgerKey)
    Do $$$AssertStatusOK(tSC, "and a ledger row")
    Quit $$$ISOK(tSC) && tStored
}

/// <p>The probe definitions as one string, by SQL: each row's id, name, instructions, flags, marker
/// and version, then the id carrying the default marker.</p>
ClassMethod AgentState() As %String
{
    Set tText = ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID, Name, SystemPromptOverride, Enabled, ConnectionVerified, DefaultMark, CredentialCreated, RowVersion FROM OcuPilot_Kernel_State.Agent WHERE Name LIKE '" _ ..#AGENTPREFIX _ "%' ORDER BY ID")
    While tRS.%Next() {
        Set tText = tText _ "{"
        For tC = 1:1:tRS.%ResultColumnCount {
            Set tText = tText _ $Select(tC > 1: "|", 1: "") _ tRS.%GetData(tC)
        }
        Set tText = tText _ "}"
    }
    Quit tText _ " marked=" _ ##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT ID FROM OcuPilot_Kernel_State.Agent WHERE DefaultMark = '1'")
}

/// <p>The fields of definition <var>pId</var> a credential finding must leave alone, as one string.</p>
ClassMethod AgentFields(pId As %String) As %String
{
    Quit ##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT Name || '|' || Provider || '|' || Model || '|' || CredType || '|' || EnvVarName || '|' || SystemPromptOverride || '|' || CredentialCreated || '|' || MarkedLocal || '|' || HttpAcknowledged FROM OcuPilot_Kernel_State.Agent WHERE ID = " _ pId)
}

/// <p>The victim's proposals and ledger rows as one string, by SQL.</p>
ClassMethod VictimState() As %String
{
    Set tText = ""
    Set tQueries = $ListBuild("SELECT ProposalKey, State, ClosedReason, Burned, ReadBack, TargetKey, RowVersion FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(UserName) = '" _ ..#VICTIM _ "' ORDER BY ProposalKey", "SELECT LedgerKey, Status, Code, Name, Dropped, RowVersion FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(UserName) = '" _ ..#VICTIM _ "' ORDER BY LedgerKey")
    For tI = 1:1:$ListLength(tQueries) {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, $List(tQueries, tI))
        Set tText = tText _ "["
        While tRS.%Next() {
            Set tText = tText _ "{"
            For tC = 1:1:tRS.%ResultColumnCount {
                Set tText = tText _ $Select(tC > 1: "|", 1: "") _ tRS.%GetData(tC)
            }
            Set tText = tText _ "}"
        }
        Set tText = tText _ "]"
    }
    Quit tText
}

/// <p>The two overflow rows as one string: owner, turn, count and version.</p>
ClassMethod OverflowState() As %String
{
    Set tText = ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT UserName, TurnKey, Dropped, RowVersion FROM OcuPilot_Kernel_State.Ledger WHERE Seq = 0 AND %EXACT(TurnKey) IN ('" _ ..#VICTIMTURN _ "', '" _ ..#DEVTURN _ "') ORDER BY TurnKey")
    While tRS.%Next() {
        Set tText = tText _ "{" _ tRS.%GetData(1) _ "|" _ tRS.%GetData(2) _ "|" _ tRS.%GetData(3) _ "|" _ tRS.%GetData(4) _ "}"
    }
    Quit tText
}

/// <p>Assert that <var>pRun</var> ran as <var>pUser</var>, who holds <code>%Development:USE</code> or
/// <code>OcuPilotAdmin:USE</code> as <var>pAdministrator</var> says, and does not hold <code>%All</code>.</p>
Method AssertPrincipal(pRun As %DynamicObject, pUser As %String = {..#DEVUSER}, pAdministrator As %Boolean = 0)
{
    Do $$$AssertEquals($Select(pRun.%IsDefined("error"): pRun.%Get("error"), 1: pRun.%Get("username") _ " " _ pRun.%Get("loggedIn")), pUser _ " 1", "the child process ran as " _ pUser)
    Do $$$AssertEquals(''pRun.%Get("holdsAdmin"), pAdministrator, "who " _ $Select(pAdministrator: "holds", 1: "does not hold") _ " OcuPilotAdmin:USE; roles " _ pRun.%Get("roles"))
    Do $$$AssertEquals(''pRun.%Get("holdsDevelopment"), 'pAdministrator, $Select(pAdministrator: "and not %Development:USE", 1: "holds %Development:USE"))
    Do $$$AssertTrue(("," _ pRun.%Get("roles") _ ",") '[ ",%All,", "and does not hold %All")
}

}
