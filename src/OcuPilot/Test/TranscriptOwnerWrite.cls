/// <p>AD-9's owner gate, batch two: the turns, their steps and navigation directives, and the
/// conversations and their entries refuse a write from a caller who may not make it, in the store
/// itself, whatever route or code reached it. A real principal holding <code>%Development:USE</code>
/// and the install namespace's code read, and no <code>OcuPilotAdmin</code>, is refused
/// <code>ERROR #822</code> by every public writer of those stores that names another user's turn,
/// conversation or account, by every cross-user delete, sweep and purge, and by <code>Base</code>'s
/// public saves, and the stored rows read as they did. The same principal still writes its own turns
/// and conversations through every owner writer, an administrator writes anyone's, a turn reserve still
/// sweeps other users' expired turns, and a signed-out account's running turns can still be abandoned.
/// A developer also cannot spend another user's turn caps with ledger rows or proposals minted on that
/// turn's key.</p>
/// <p>The calls run in a child process logged in as the principal
/// (<class>OcuPilot.Test.TranscriptStateWriteProbe</class>); the stored rows are read back here by SQL, as
/// the suite's own <code>%All</code> identity, which also seeds them.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates and deletes two
/// users and two roles and writes turns and conversations. <method>OnBeforeAllTests</method> refuses
/// anywhere it does not. Every test removes the rows it created, by the names only this class uses, and
/// asserts the removal.</p>
Class OcuPilot.Test.TranscriptOwnerWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.TranscriptStateWriteProbe";

/// <p>The principal holding <code>%Development:USE</code> and the code read, and nothing else.</p>
Parameter DEVUSER = "OcuPilotTranscriptDev";

Parameter DEVROLE = "OcuPilotTranscriptDevRole";

/// <p>The principal holding <code>OcuPilotAdmin:USE</code> and the code read, and nothing else.</p>
Parameter ADMINUSER = "OcuPilotTranscriptAdmin";

Parameter ADMINROLE = "OcuPilotTranscriptAdminRole";

/// <p>The user name whose turns and conversations the developer attacks. No account has it.</p>
Parameter VICTIM = "OcuPilotTranscriptVictim";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>A timestamp no live row carries, and the cutoff just after it: a sweep or purge given the cutoff
/// reaches only the rows this class aged to the timestamp.</p>
Parameter OLD = "2000-01-01T00:00:00Z";

Parameter CUTOFFISO = "2000-01-02T00:00:00Z";

Parameter STOREPACKAGE = "OcuPilot.Kernel.State.";

/// <p>The throwaway principals' password, generated for the run.</p>
Property PreparedPassword As %String;

/// <p>The keys the last seed stored, by role: <code>queued</code>, <code>running</code>, <code>old</code>,
/// <code>own</code>, <code>convA</code>, <code>convAId</code>, <code>convB</code>, <code>proposal</code>.</p>
Property Seed [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TranscriptOwnerWrite creates and deletes users and roles and writes OcuPilot's stores on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuPilotTranscript" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit ##class(OcuPilot.Test.AdminStateWrite).EnsurePrincipals(..PreparedPassword, ..Principals())
}

/// <p>Remove the two principals and their roles; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Quit ##class(OcuPilot.Test.AdminStateWrite).RemovePrincipals(..Principals(), "OcuPilot.Test.TranscriptOwnerWrite")
}

/// <p>The developer and the administrator, as <method>OcuPilot.Test.AdminStateWrite.EnsurePrincipals</method>
/// takes them.</p>
ClassMethod Principals() As %List
{
    Quit $ListBuild($ListBuild(..#DEVUSER, ..#DEVROLE, "%Development:U", 0), $ListBuild(..#ADMINUSER, ..#ADMINROLE, "OcuPilotAdmin:U", 1))
}

Method OnBeforeOneTest() As %Status
{
    Kill ..Seed
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Quit ..RemoveOwnRows()
}

Method OnAfterOneTest() As %Status
{
    Set tSC = ..RemoveOwnRows()
    Do $$$AssertStatusOK(tSC, "the turns, conversations, proposals and ledger rows this test created are removed")
    Do $$$AssertEquals(..LeftOver(), 0, "and none of them survives")
    Quit $$$OK
}

/// <p>A developer calls each writer of another user's turns, steps, directives, conversations and
/// entries, one call to a child process so each is measured alone against a fresh set of the victim's
/// rows (<method>VictimKinds</method>): finish, stop, renew and delete a turn, reserve and reconcile for
/// the victim, append, update and delete steps, request and settle a directive, load, append to and
/// delete a conversation, and the sweeps and purges across users. Each is refused <code>822</code> and
/// the victim's rows read, versions and signals included, as they did.</p>
/// <p>Mutation (Rule 19): <code>OwnerWriteRefused</code> answers <code>$$$OK</code> first -> this goes red
/// with the batch one refusal tests; no owner, administrator or open-path test does.</p>
Method TestADeveloperIsRefusedAVictimsTranscript()
{
    Set tKinds = ..VictimKinds()
    For tI = 1:1:$ListLength(tKinds) {
        Set tKind = $List(tKinds, tI)
        If '..SeedVictim() Quit
        Set tBefore = ..VictimState()
        Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, [(..LegStep(tKind))], ..#PROBE)
        If tI = 1 Do ..AssertPrincipal(tRun)
        Set tAfter = ..VictimState()
        Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), tKind _ " ok=0 code=822", tKind _ " is refused 822: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
        Do $$$AssertEquals(tAfter, tBefore, tKind _ " leaves the victim's rows as they were; before " _ tBefore _ " after " _ tAfter)
    }
    If '..SeedVictim() Quit
    Set tBefore = ..VictimState()
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, [{"kind": "Convo.LoadOrCreate", "user": (..#VICTIM), "convKey": ""}], ..#PROBE)
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "Convo.LoadOrCreate ok=0 code=822", "a conversation created in the victim's name is refused 822: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
    Do $$$AssertEquals(..VictimState(), tBefore, "and the victim holds no new conversation")
}

/// <p>A developer's own ledger rows and proposals on a victim's turn key or conversation key are refused
/// <code>822</code> and store nothing: the rows would spend that key's caps. On the developer's own turn key every one is accepted. A key that names no turn
/// is no one's, so it is accepted too.</p>
/// <p>Mutation (Rule 19): the turn-owner check removed from <code>Ledger.GuardedAppend</code> -> the append
/// leg goes red alone.</p>
Method TestADeveloperCannotSpendAVictimsTurnCaps()
{
    Set tLegs = $ListBuild("Ledger.GuardedAppend", "Ledger.GuardedCountOverflow", "Propose.GuardedMint", "Propose.GuardedMint.Convo", "Ledger.GuardedAppend.Convo", "Ledger.GuardedCountOverflow.Convo")
    For tI = 1:1:$ListLength(tLegs) {
        Set tLeg = $List(tLegs, tI)
        If '..SeedVictim() Quit
        Set tBefore = ..VictimState()
        Set tStep = {"kind": ($Piece(tLeg, ".", 1, 2)), "user": (..#DEVUSER), "turnKey": (..Seed("running")), "convKey": "", "target": ""}
        If tLeg = "Propose.GuardedMint.Convo" {
            Do tStep.%Set("turnKey", "")
            Do tStep.%Set("convKey", ..Seed("convA"))
        }
        If ($Extract(tLeg, 1, 7) = "Ledger.") && ($Piece(tLeg, ".", 3) = "Convo") Do tStep.%Set("turnKey", ..Seed("convA"))
        Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, [(tStep)], ..#PROBE)
        If tI = 1 Do ..AssertPrincipal(tRun)
        Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), tStep.%Get("kind") _ " ok=0 code=822", tLeg _ " on the victim's key is refused 822: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
        Do $$$AssertEquals(..VictimState(), tBefore, tLeg _ " leaves the victim's turn and conversation as they were")
    }
    If '..SeedVictim() Quit
    Set tPlan = []
    Do tPlan.%Push({"kind": "Ledger.GuardedAppend", "user": (..#DEVUSER), "turnKey": (..Seed("own"))})
    Do tPlan.%Push({"kind": "Ledger.GuardedCountOverflow", "user": (..#DEVUSER), "turnKey": (..Seed("own"))})
    Do tPlan.%Push({"kind": "Propose.GuardedMint", "user": (..#DEVUSER), "turnKey": (..Seed("own")), "convKey": "", "target": ""})
    Do tPlan.%Push({"kind": "Ledger.GuardedAppend", "user": (..#DEVUSER), "turnKey": "OcuPilotTranscriptNoSuchTurn"})
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    For tI = 1:1:tPlan.%Size() {
        Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, tI).%Get("ok"), 1, "step " _ tI _ " on the developer's own or an unowned key is accepted: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, tI))
    }
}

/// <p>A developer reserves and begins its own turn, which holds its turn slot, deletes the turn, and then
/// finishes it: the finish is refused <code>822</code> because the key names no turn, and the slot is no
/// longer held.</p>
/// <p>Mutation (Rule 19): the slot release removed from <code>Turn.GuardedFinish</code>'s refusal -> the
/// held leg goes red.</p>
Method TestARefusedFinishReleasesTheOwnersSlot()
{
    Set tUser = ..#DEVUSER
    Set tPlan = [{"kind": "Turn.GuardedReserve", "user": (tUser)}, {"kind": "Turn.GuardedBegin", "user": (tUser), "key": "$reserved"}, {"kind": "Turn.SlotHeld", "user": (tUser)}, {"kind": "Turn.GuardedDelete", "key": "$reserved"}, {"kind": "Turn.GuardedFinish", "user": (tUser), "key": "$reserved"}, {"kind": "Turn.SlotHeld", "user": (tUser)}]
    Set tRun = ..RunAsWatched(tUser, tPlan)
    Do ..AssertPrincipal(tRun)
    For tI = 1, 2, 4 {
        Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, tI).%Get("ok"), 1, "step " _ tI _ " is accepted for the owner: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, tI))
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 3).%Get("held"), 1, "the begun turn holds the owner's slot: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, 3))
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 5), "Turn.GuardedFinish ok=0 code=822", "a finish of the deleted turn is refused 822: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, 5))
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 6).%Get("held"), 0, "and the slot is no longer held: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, 6))
}

/// <p>A developer's owner writers on a key that names no turn are refused <code>822</code>, as for a
/// non-administrator a row with no owner is no one's to write.</p>
/// <p>Mutation (Rule 19): <code>KeyOwnerRefused</code> answers <code>$$$OK</code> for a key that names no row
/// -> this and the finish leg of <method>TestARefusedFinishReleasesTheOwnersSlot</method> go red.</p>
Method TestAnOwnerWriterOnAKeyThatNamesNoTurnIsRefused()
{
    Set tUser = ..#DEVUSER
    Set tKey = "OcuPilotTranscriptNoSuchTurn"
    Set tPlan = [{"kind": "Turn.GuardedProgress", "key": (tKey)}, {"kind": "Turn.GuardedRenew", "key": (tKey)}, {"kind": "Turn.GuardedFinish", "user": (tUser), "key": (tKey)}]
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(tUser, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun)
    For tI = 1:1:tPlan.%Size() {
        Set tKind = tPlan.%Get(tI - 1).%Get("kind")
        Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, tI), tKind _ " ok=0 code=822", tKind _ " on a key that names no turn is refused 822: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, tI))
    }
}

/// <p>A developer holds its own turn with its <code>UserName</code> set to the victim in memory and calls
/// <code>GuardedProgress</code> and <code>Base.GuardedSave</code>: refused <code>822</code>, and the stored
/// owner is still the developer. An administrator holding the victim's turn under its own name is refused
/// the same way, so a save never changes an owner.</p>
/// <p>Mutation (Rule 19): <code>OwnerChangeRefused</code> skips the stored-versus-held owner comparison ->
/// the administrator legs go red.</p>
Method TestAForgedOwnerIsRefusedAndTheStoredOwnerStands()
{
    If '..SeedVictim() Quit
    Set tOwnId = ##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT ID FROM OcuPilot_Kernel_State.Turn WHERE %EXACT(TurnKey) = '" _ ..Seed("own") _ "'")
    Set tVictimId = ##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT ID FROM OcuPilot_Kernel_State.Turn WHERE %EXACT(TurnKey) = '" _ ..Seed("running") _ "'")
    Set tBefore = ..VictimState() _ ..OwnState()
    Set tPlan = [{"kind": "Turn.ForgedProgress", "id": (tOwnId), "key": (..Seed("own")), "heldUser": (..#VICTIM)}, {"kind": "Turn.ForgedSave", "id": (tOwnId), "key": (..Seed("own")), "heldUser": (..#VICTIM)}]
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun)
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "Turn.ForgedProgress ok=0 code=822", "the developer's turn held as the victim's is refused 822 by the writer: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, 1))
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 2), "Turn.ForgedSave ok=0 code=822", "and by the public save: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, 2))
    Set tPlan = [{"kind": "Turn.ForgedProgress", "id": (tVictimId), "key": (..Seed("running")), "heldUser": (..#ADMINUSER)}, {"kind": "Turn.ForgedSave", "id": (tVictimId), "key": (..Seed("running")), "heldUser": (..#ADMINUSER)}]
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#ADMINUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#ADMINUSER, 1)
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "Turn.ForgedProgress ok=0 code=822", "an administrator's writer save of the victim's turn held under another owner is refused 822: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, 1))
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 2), "Turn.ForgedSave ok=0 code=822", "and so is its public save: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, 2))
    Do $$$AssertEquals(..VictimState() _ ..OwnState(), tBefore, "the stored owners, counts and versions are as they were")
}

/// <p>A developer writes its own turn and conversation through every owner writer, in the order
/// <method>OwnerPlan</method> runs them: reserve, begin, append and update steps, snapshot and finish a
/// tool step, request and settle a directive, record progress, count a dropped step, renew, stop,
/// finish, reconcile, create and load a conversation, append entries and delete both. Each is accepted
/// and the rows read as the writer says.</p>
/// <p>Mutation (Rule 19): <code>CallerOwns</code> answers 0 always -> this and the open-path test go red.</p>
Method TestADeveloperWritesItsOwnTurnAndConversation()
{
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, ..OwnerPlan(), ..#PROBE)
    Do ..AssertPrincipal(tRun)
    Set tPlan = ..OwnerPlan()
    For tI = 1:1:tPlan.%Size() {
        Set tLeg = ##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, tI)
        Do $$$AssertTrue($IsObject(tLeg) && tLeg.%Get("ok"), "step " _ tI _ " (" _ tPlan.%Get(tI - 1).%Get("kind") _ ") is accepted for the owner: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, tI))
    }
    Set tKey = ##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT TOP 1 TurnKey FROM OcuPilot_Kernel_State.Turn WHERE %EXACT(UserName) = '" _ ..#DEVUSER _ "'")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT State || '|' || Iterations || '|' || StepsDropped || '|' || Reply FROM OcuPilot_Kernel_State.Turn WHERE %EXACT(TurnKey) = '" _ tKey _ "'"), "completed|7|1|a reply", "the turn finished with its progress, one dropped step and its reply")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Step WHERE %EXACT(TurnKey) = '" _ tKey _ "'"), 3, "it holds its three steps")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT Outcome FROM OcuPilot_Kernel_State.Nav WHERE %EXACT(TurnKey) = '" _ tKey _ "'"), "opened", "and its settled directive")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Entry e JOIN OcuPilot_Kernel_State.Convo c ON e.ConvoKey = c.ConvKey WHERE %EXACT(c.UserName) = '" _ ..#DEVUSER _ "'"), 2, "and its conversation holds the two entries")
    Set tConv = ##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT TOP 1 ConvKey FROM OcuPilot_Kernel_State.Convo WHERE %EXACT(UserName) = '" _ ..#DEVUSER _ "'")
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, ..OwnerDeletePlan(tKey, tConv), ..#PROBE)
    Do ..AssertPrincipal(tRun)
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "Convo.GuardedDelete ok=1 code=", "the owner deletes its conversation: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, 1))
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 2), "Turn.GuardedDelete ok=1 code=", "and its turn: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, 2))
    Do $$$AssertEquals(..LeftOver(), 0, "nothing of either survives")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Entry WHERE %EXACT(ConvoKey) = '" _ tConv _ "'"), 0, "and the deleted conversation's entries are gone with it")
}

/// <p>An administrator -- <code>OcuPilotAdmin:USE</code> and the code read, no <code>%All</code> -- writes
/// the victim's turn and conversation (<method>AdministratorPlan</method>): finish, stop and renew the turn,
/// append a step, request and settle a directive, append entries; then every cross-user sweep, purge and
/// delete, and the victim's own turn and conversation deletes. Each is accepted and the rows read as the
/// writer says.</p>
/// <p>Mutation (Rule 19): the administrator bypass removed from <code>OwnerWriteRefused</code> -> this goes
/// red with the other administrator and owner-of-another tests.</p>
Method TestAnAdministratorWritesAVictimsTranscriptAndSweeps()
{
    If '..SeedVictim() Quit
    Set tPlan = ..AdministratorPlan(..Seed("running"), ..Seed("convA"))
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#ADMINUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#ADMINUSER, 1)
    For tI = 1:1:tPlan.%Size() {
        Set tLeg = ##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, tI)
        Do $$$AssertTrue($IsObject(tLeg) && tLeg.%Get("ok"), "step " _ tI _ " (" _ tPlan.%Get(tI - 1).%Get("kind") _ ") is accepted for an administrator: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, tI))
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).TurnCountForTurn(..Seed("old")), 0, "the sweep removed the victim's expired turn")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Convo WHERE %EXACT(ConvKey) = '" _ ..Seed("convB") _ "'"), 0, "the purge removed the victim's empty conversation")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).TurnCountForTurn(..Seed("running")), 0, "the delete removed the victim's turn")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Convo WHERE %EXACT(ConvKey) = '" _ ..Seed("convA") _ "'"), 0, "and its conversation")
}

/// <p>The paths the stores keep open to every caller work as a real developer, one with no
/// <code>OcuPilotAdmin</code>, against a victim's rows, and have the effect they had before the gate:</p>
/// <ol>
/// <li>a turn reserve sweeps another user's expired terminal turn with its steps, directive, proposal and
/// signals, and stores the developer's own turn;</li>
/// <li>a security administrator's abandon of a deleted account's turns
/// (<code>Turn.GuardedAbandonForUser</code>) sets the abandon signal on each of its queued and running
/// turns.</li>
/// </ol>
/// <p>Mutation (Rule 19): <code>Turn.GuardedReserve</code> calls the public <code>GuardedSweep</code> -> this
/// goes red.</p>
Method TestTheOpenPathsStillWork()
{
    If '..SeedVictim() Quit
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, [{"kind": "Turn.GuardedReserve", "user": (..#DEVUSER)}], ..#PROBE)
    Do ..AssertPrincipal(tRun)
    Set tLeg = ##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 1)
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "Turn.GuardedReserve ok=1 code=", "the reserve is accepted: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
    Do $$$AssertTrue($IsObject(tLeg) && (tLeg.%Get("key") '= "") && 'tLeg.%Get("busy") && tLeg.%Get("sweepOk"), "it stores the developer's turn and the sweep reports success")
    Set tOld = ..Seed("old")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).TurnCountForTurn(tOld), 0, "the victim's expired turn is swept")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Step WHERE %EXACT(TurnKey) = '" _ tOld _ "'"), 0, "with its step")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.Nav WHERE %EXACT(TurnKey) = '" _ tOld _ "'"), 0, "its directive")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).ProposalCountForTurn(tOld), 0, "its proposal")
    Do $$$AssertEquals($Data(^OcuPilotTurnSignal(tOld)), 0, "and its signals")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).TurnCountForTurn(..Seed("running")), 1, "while the victim's live turn stays")
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, [{"kind": "Turn.GuardedAbandonForUser", "user": (..#VICTIM)}], ..#PROBE)
    Do ..AssertPrincipal(tRun)
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "Turn.GuardedAbandonForUser ok=1 code=", "the abandon is accepted: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 1).%Get("count"), 2, "it names the victim's queued and running turns")
    Do $$$AssertEquals($Get(^OcuPilotTurnSignal(..Seed("running"), "abandon")) _ $Get(^OcuPilotTurnSignal(..Seed("queued"), "abandon")), "11", "each carries the abandon signal")
}

/// <p>The owner stores of this batch are the classes whose compiled <code>OWNERWRITE</code> is not empty
/// (<method>Stores</method>), and each one's own public class methods are exactly its declared reads, owner
/// writes, administrator writes and open writes. Every owner write is a step of the stranger's list
/// (<method>VictimKinds</method>) and of the plan the owner runs (<method>OwnerPlan</method>), every
/// administrator write one of the stranger's list and of the plan the administrator runs
/// (<method>AdministratorPlan</method>), and every open write one the open-path test reaches.</p>
/// <p>Mutation (Rule 19): <code>Parameter OWNERWRITE</code> emptied on
/// <class>OcuPilot.Kernel.State.Step</class> -> this and the victim test go red.</p>
Method TestTheOwnerStoresAreDeclared()
{
    Set tStores = ..Stores()
    Set tOwnerRan = ##class(OcuPilot.Test.AdminStateWrite).KindsOf(..OwnerPlan()) _ ##class(OcuPilot.Test.AdminStateWrite).KindsOf(..OwnerDeletePlan("", ""))
    Set tAdministratorRan = ##class(OcuPilot.Test.AdminStateWrite).KindsOf(..AdministratorPlan())
    For tI = 1:1:$ListLength(tStores) {
        Set tStore = $List(tStores, tI)
        Set tClass = ..#STOREPACKAGE _ tStore
        Do $$$AssertNotEquals($Parameter(tClass, "OWNERWRITE"), "", tStore _ " declares the property that carries its owner")
        Set tPublic = ""
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.MethodDefinition WHERE parent = ? AND ClassMethod = 1 AND Private = 0", tClass)
        While tRS.%Next() {
            Set tPublic = tPublic _ $ListBuild(tRS.%GetData(1))
        }
        Set tSplit = ..Reads(tStore) _ ..OwnerWrites(tStore) _ ..AdministratorWrites(tStore) _ ..OpenWrites(tStore)
        Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).SortedJoin(tPublic), ##class(OcuPilot.Test.AdminStateWrite).SortedJoin(tSplit), tStore _ "'s public class methods are its declared reads, owner writes, administrator writes and open writes")
        Do ..AssertCalled(tStore, ..OwnerWrites(tStore), ..VictimKinds() _ ..CapKinds(), "an owner write is tried by a stranger")
        Do ..AssertCalled(tStore, ..OwnerWrites(tStore), tOwnerRan, "an owner write is run by the owner's plan")
        Do ..AssertCalled(tStore, ..AdministratorWrites(tStore), ..VictimKinds(), "an administrator write is tried by a stranger")
        Do ..AssertCalled(tStore, ..AdministratorWrites(tStore), tAdministratorRan, "an administrator write is run by the administrator's plan")
        Do ..AssertCalled(tStore, ..OpenWrites(tStore), ..OpenKinds(), "an open write is reached by the open-path test")
    }
    Set tHandled = ""
    Set tAll = ..VictimKinds() _ tOwnerRan _ tAdministratorRan _ ..OpenKinds()
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

/// <p>The stores this class covers.</p>
ClassMethod Stores() As %List
{
    Quit $ListBuild("Turn", "Step", "Nav", "Convo", "Entry")
}

/// <p>The steps a stranger is refused on another user's rows, one child process each.</p>
ClassMethod VictimKinds() As %List
{
    Quit $ListBuild("Turn.GuardedReserve", "Turn.GuardedBegin", "Turn.GuardedProgress", "Turn.GuardedAddDropped", "Turn.GuardedFinish", "Turn.GuardedRenew", "Turn.GuardedRequestStop", "Turn.GuardedReconcile", "Turn.GuardedForgetStarts", "Turn.GuardedSweepStarts", "Turn.GuardedSweep", "Turn.GuardedDelete", "Step.GuardedAppend", "Step.GuardedUpdate", "Step.GuardedSnapshotText", "Step.GuardedFinishTool", "Step.GuardedDeleteForTurn", "Nav.GuardedRequest", "Nav.GuardedSettle", "Nav.GuardedDeleteForTurn", "Convo.LoadOrCreate", "Convo.AppendEntry", "Convo.GuardedDelete", "Convo.GuardedPurgeEmpty", "Entry.GuardedAppend", "Entry.GuardedDeleteForConvo", "Entry.GuardedPurge", "Propose.GuardedDeleteForTurn")
}

/// <p>The writes on another user's turn key that <method>TestADeveloperCannotSpendAVictimsTurnCaps</method>
/// tries.</p>
ClassMethod CapKinds() As %List
{
    Quit $ListBuild("Ledger.GuardedAppend", "Ledger.GuardedCountOverflow", "Propose.GuardedMint")
}

/// <p>The steps the open-path test reaches.</p>
ClassMethod OpenKinds() As %List
{
    Quit $ListBuild("Turn.GuardedReserve", "Turn.GuardedAbandonForUser")
}

/// <p>The reads <var>pStore</var> declares: its public class methods that write no row.</p>
ClassMethod Reads(pStore As %String) As %List
{
    If pStore = "Turn" Quit $ListBuild("Timestamp", "NowSeconds", "SecondsOf", "IsTerminal", "Cap", "MinuteCeiling", "IsoOfSeconds", "GuardedDropped", "GuardedLiveUsers", "GuardedIsTurnJob", "GuardedSignals", "GuardedDefinitionOf", "GuardedWorkflowOf", "GuardedForOwner", "GuardedView", "CitationsArray", "EgressObject")
    If pStore = "Step" Quit $ListBuild("GuardedRows")
    If pStore = "Nav" Quit $ListBuild("GuardedPending")
    If pStore = "Convo" Quit $ListBuild("GuardedOwner", "GuardedOwnerOf", "GuardedScreenRows", "GuardedView", "HistoryMessages")
    Quit $ListBuild("GuardedRows", "GuardedTurnKeys")
}

/// <p>The writes <var>pStore</var> refuses a caller who does not own the row.</p>
ClassMethod OwnerWrites(pStore As %String) As %List
{
    If pStore = "Turn" Quit $ListBuild("GuardedReserve", "GuardedBegin", "GuardedProgress", "GuardedAddDropped", "GuardedFinish", "GuardedRenew", "GuardedRequestStop", "GuardedReconcile", "GuardedDelete")
    If pStore = "Step" Quit $ListBuild("GuardedAppend", "GuardedUpdate", "GuardedSnapshotText", "GuardedFinishTool")
    If pStore = "Nav" Quit $ListBuild("GuardedRequest", "GuardedSettle")
    If pStore = "Convo" Quit $ListBuild("LoadOrCreate", "AppendEntry", "GuardedDelete")
    Quit $ListBuild("GuardedAppend")
}

/// <p>The writes <var>pStore</var> refuses a caller who does not hold the administrator privilege.</p>
ClassMethod AdministratorWrites(pStore As %String) As %List
{
    If pStore = "Turn" Quit $ListBuild("GuardedForgetStarts", "GuardedSweepStarts", "GuardedSweep")
    If pStore = "Step" Quit $ListBuild("GuardedDeleteForTurn")
    If pStore = "Nav" Quit $ListBuild("GuardedDeleteForTurn")
    If pStore = "Convo" Quit $ListBuild("GuardedPurgeEmpty")
    Quit $ListBuild("GuardedDeleteForConvo", "GuardedPurge")
}

/// <p>The writes <var>pStore</var> leaves open to every caller.</p>
ClassMethod OpenWrites(pStore As %String) As %List
{
    If pStore = "Turn" Quit $ListBuild("GuardedAbandonForUser")
    Quit ""
}

/// <p>The step a stranger tries for <var>pKind</var>, against the keys the last seed stored.</p>
Method LegStep(pKind As %String) As %DynamicObject
{
    Set tStep = {"kind": (pKind), "user": (..#VICTIM), "key": (..Seed("running")), "turnKey": (..Seed("running")), "seq": 2, "convKey": (..Seed("convA")), "id": (..Seed("convAId")), "cutoff": (##class(OcuPilot.Kernel.State.Turn).SecondsOf(..#CUTOFFISO)), "iso": (..#CUTOFFISO), "stepKind": "tool", "status": "running"}
    If pKind = "Turn.GuardedBegin" Do tStep.%Set("key", ..Seed("queued"))
    If $Extract(pKind, 1, 4) = "Nav." Do tStep.%Set("seq", 1)
    Quit tStep
}

/// <p>The plan the developer runs against its own rows: one step for each of its owner writes, in the
/// order a turn runs them, then a conversation. <code>$reserved</code> is the turn <code>Turn.GuardedReserve</code>
/// answered and <code>$conv</code> the conversation <code>Convo.LoadOrCreate</code> created.</p>
ClassMethod OwnerPlan() As %DynamicArray
{
    Set tUser = ..#DEVUSER
    Set tPlan = []
    Do tPlan.%Push({"kind": "Turn.GuardedReserve", "user": (tUser)})
    Do tPlan.%Push({"kind": "Turn.GuardedBegin", "user": (tUser), "key": "$reserved"})
    Do tPlan.%Push({"kind": "Step.GuardedAppend", "key": "$reserved", "stepKind": "announce", "status": "running", "as": "announce"})
    Do tPlan.%Push({"kind": "Step.GuardedAppend", "key": "$reserved", "stepKind": "model", "status": "running", "as": "model"})
    Do tPlan.%Push({"kind": "Step.GuardedSnapshotText", "key": "$reserved", "seq": "$model"})
    Do tPlan.%Push({"kind": "Step.GuardedUpdate", "key": "$reserved", "seq": "$model"})
    Do tPlan.%Push({"kind": "Step.GuardedAppend", "key": "$reserved", "stepKind": "tool", "status": "running", "as": "tool"})
    Do tPlan.%Push({"kind": "Step.GuardedFinishTool", "key": "$reserved", "seq": "$tool"})
    Do tPlan.%Push({"kind": "Nav.GuardedRequest", "key": "$reserved", "seq": "$announce"})
    Do tPlan.%Push({"kind": "Nav.GuardedSettle", "key": "$reserved", "seq": "$announce"})
    Do tPlan.%Push({"kind": "Turn.GuardedProgress", "key": "$reserved"})
    Do tPlan.%Push({"kind": "Turn.GuardedAddDropped", "key": "$reserved"})
    Do tPlan.%Push({"kind": "Turn.GuardedRenew", "key": "$reserved"})
    Do tPlan.%Push({"kind": "Turn.GuardedRequestStop", "user": (tUser), "key": "$reserved"})
    Do tPlan.%Push({"kind": "Turn.GuardedFinish", "user": (tUser), "key": "$reserved"})
    Do tPlan.%Push({"kind": "Turn.GuardedReconcile", "user": (tUser)})
    Do tPlan.%Push({"kind": "Convo.LoadOrCreate", "user": (tUser), "convKey": "", "hold": 1})
    Do tPlan.%Push({"kind": "Convo.AppendEntry", "key": "$reserved"})
    Do tPlan.%Push({"kind": "Entry.GuardedAppend", "convKey": "$conv"})
    Do tPlan.%Push({"kind": "Convo.LoadOrCreate", "user": (tUser), "convKey": "$conv", "hold": 0})
    Quit tPlan
}

/// <p>The owner's deletes of the turn <var>pTurnKey</var> and conversation <var>pConvKey</var>.</p>
ClassMethod OwnerDeletePlan(pTurnKey As %String, pConvKey As %String) As %DynamicArray
{
    Quit [{"kind": "Convo.GuardedDelete", "convKey": (pConvKey)}, {"kind": "Turn.GuardedDelete", "key": (pTurnKey)}]
}

/// <p>The plan the administrator runs against the victim's turn <var>pTurnKey</var> and conversation
/// <var>pConvKey</var>: the owner's writes on them, then every cross-user sweep, purge and delete that is
/// an administrator's, the victim's own deletes last.</p>
ClassMethod AdministratorPlan(pTurnKey As %String = "", pConvKey As %String = "") As %DynamicArray
{
    Set tPlan = []
    Set tUser = ..#VICTIM
    Do tPlan.%Push({"kind": "Step.GuardedAppend", "key": (pTurnKey), "stepKind": "tool", "status": "running"})
    Do tPlan.%Push({"kind": "Nav.GuardedSettle", "key": (pTurnKey), "seq": 1})
    Do tPlan.%Push({"kind": "Turn.GuardedRenew", "key": (pTurnKey)})
    Do tPlan.%Push({"kind": "Turn.GuardedRequestStop", "user": (tUser), "key": (pTurnKey)})
    Do tPlan.%Push({"kind": "Turn.GuardedFinish", "user": (tUser), "key": (pTurnKey)})
    Do tPlan.%Push({"kind": "Convo.LoadOrCreate", "user": (tUser), "convKey": (pConvKey), "hold": 1})
    Do tPlan.%Push({"kind": "Convo.AppendEntry", "key": (pTurnKey)})
    Do tPlan.%Push({"kind": "Entry.GuardedAppend", "convKey": (pConvKey)})
    Do tPlan.%Push({"kind": "Turn.GuardedSweep"})
    Do tPlan.%Push({"kind": "Turn.GuardedSweepStarts"})
    Do tPlan.%Push({"kind": "Turn.GuardedForgetStarts", "user": (tUser)})
    Do tPlan.%Push({"kind": "Convo.GuardedPurgeEmpty", "iso": (..#CUTOFFISO)})
    Do tPlan.%Push({"kind": "Entry.GuardedPurge", "cutoff": (##class(OcuPilot.Kernel.State.Turn).SecondsOf(..#CUTOFFISO))})
    Do tPlan.%Push({"kind": "Entry.GuardedDeleteForConvo", "convKey": (pConvKey)})
    Do tPlan.%Push({"kind": "Nav.GuardedDeleteForTurn", "key": (pTurnKey)})
    Do tPlan.%Push({"kind": "Step.GuardedDeleteForTurn", "key": (pTurnKey)})
    Do tPlan.%Push({"kind": "Propose.GuardedDeleteForTurn", "turnKey": (pTurnKey)})
    Do tPlan.%Push({"kind": "Convo.GuardedDelete", "convKey": (pConvKey)})
    Do tPlan.%Push({"kind": "Turn.GuardedDelete", "key": (pTurnKey)})
    Quit tPlan
}

/// <p>Remove every turn, conversation, proposal, ledger row and start record of the victim and the
/// developer, and the seeded turns' leftovers. Only names this class owns are touched.</p>
Method RemoveOwnRows() As %Status
{
    Set tSC = $$$OK
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
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT ConvKey FROM OcuPilot_Kernel_State.Convo WHERE %EXACT(UserName) = ?", tUser)
        While tRS.%Next() {
            Set tKeys($Increment(tKeys)) = tRS.%GetData(1)
        }
        For tI = 1:1:+$Get(tKeys) {
            Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Convo).GuardedDelete(tKeys(tI)))
        }
        Kill tKeys
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser(tUser))
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForUser(tUser))
    }
    Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining))
    Quit tSC
}

/// <p>How many turns, conversations, proposals and ledger rows of the victim and the developer survive,
/// whatever case their owner name was written in; the sum is 0 once <method>RemoveOwnRows</method> has
/// run.</p>
ClassMethod LeftOver() As %Integer
{
    Set tCount = 0
    For tTable = "Turn", "Convo", "Proposal", "Ledger" {
        Set tCount = tCount + ##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State." _ tTable _ " WHERE UserName IN ('" _ ..#VICTIM _ "', '" _ ..#DEVUSER _ "')")
    }
    Quit tCount
}

/// <p>Remove the rows of an earlier leg and store, as the suite's own identity, the victim's rows: a
/// queued turn with its start record, a running turn with a model step, an announce step, a directive and
/// a proposal, an expired terminal turn with a step, a directive and a proposal, a conversation with an
/// entry and an empty one, both aged to <parameter>OLD</parameter>; and a running turn of the developer's own. The keys are in
/// <property>Seed</property>. Answers 0 after a failed assertion.</p>
Method SeedVictim() As %Boolean
{
    Set tSC = ..RemoveOwnRows()
    Do $$$AssertStatusOK(tSC, "the rows of an earlier leg are removed")
    Kill ..Seed
    Set tSC = ##class(OcuPilot.Kernel.State.Turn).GuardedReserve(..#VICTIM, "1", "lost", ..#LIMITS, .tQueued, .tBusy, .tSweep)
    Do $$$AssertTrue($$$ISOK(tSC) && (tQueued '= ""), "the victim has a queued turn and a start record")
    If tQueued = "" Quit 0
    Set ..Seed("queued") = tQueued
    Kill ^OcuPilotTurnStarts(..#VICTIM)
    Set ^OcuPilotTurnStarts(..#VICTIM, 1, tQueued) = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(..#VICTIM, "running", .tRunning)
    If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(..#VICTIM, "completed", .tOld)
    If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(..#DEVUSER, "running", .tOwn)
    Do $$$AssertStatusOK(tSC, "a running, an expired and the developer's own turn are stored")
    If $$$ISERR(tSC) Quit 0
    Set ..Seed("running") = tRunning
    Set ..Seed("old") = tOld
    Set ..Seed("own") = tOwn
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuPilot_Kernel_State.Turn SET EndedAt = ? WHERE %EXACT(TurnKey) = ?", ..#OLD, tOld)
    Do $$$AssertTrue(tRS.%SQLCODE >= 0, "the expired turn ended long ago")
    For tKey = tRunning, tOld, tQueued {
        Set ^OcuPilotTurnSignal(tKey, "renewed") = 1
    }
    For tKey = tRunning, tOld {
        Set tSC = ##class(OcuPilot.Kernel.State.Step).GuardedAppend(tKey, "announce", "shell.screen.open", "running", "", "", "", ..#LIMITS, .tAnnounce, .tStored, "tasks/schedule")
        If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Kernel.State.Nav).GuardedRequest(tKey, tAnnounce, "tasks/schedule", "")
        If $$$ISOK(tSC) && (tKey = tRunning) Set tSC = ##class(OcuPilot.Kernel.State.Step).GuardedAppend(tKey, "model", "provider", "running", "", "", "", ..#LIMITS, .tModel, .tStored)
        Do $$$AssertStatusOK(tSC, "the turn " _ $Select(tKey = tRunning: "running", 1: "expired") _ " holds its steps and its directive")
        If $$$ISERR(tSC) Quit
    }
    If $$$ISERR(tSC) Quit 0
    Set tConvo = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate("", ..#VICTIM, 5, .tSC, .tConflict)
    If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Kernel.State.Convo).AppendEntry(tConvo, "hello", "completed", "a reply", "", 0, [], 0, ..#LIMITS, tRunning)
    Do $$$AssertStatusOK(tSC, "the victim's conversation holds an entry")
    If $$$ISERR(tSC) Quit 0
    Set ..Seed("convA") = tConvo.ConvKey
    Set ..Seed("convAId") = tConvo.%Id()
    Set tConvo = ##class(OcuPilot.Kernel.State.Convo).LoadOrCreate("", ..#VICTIM, 5, .tSC, .tConflict)
    Do $$$AssertStatusOK(tSC, "and another is empty")
    If $$$ISERR(tSC) Quit 0
    Set ..Seed("convB") = tConvo.ConvKey
    Set tConvo = ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuPilot_Kernel_State.Entry SET AppendedAt = ? WHERE %EXACT(ConvoKey) = ?", ..#OLD, ..Seed("convA"))
    Set tAged = tRS.%SQLCODE
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuPilot_Kernel_State.Convo SET CreatedAt = ? WHERE %EXACT(ConvKey) = ?", ..#OLD, ..Seed("convB"))
    Do $$$AssertTrue((tAged >= 0) && (tRS.%SQLCODE >= 0), "the entry and the empty conversation are old")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedMinimal(..#VICTIM, ..Seed("convA"), tRunning, "", .tProposal)
    If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedMinimal(..#VICTIM, "", tOld, "", .tOldProposal)
    Do $$$AssertStatusOK(tSC, "each victim turn carries a proposal")
    Quit $$$ISOK(tSC)
}

/// <p>The victim's turns, steps, directives, conversations, entries, proposals, ledger rows, signals and
/// start records, and the developer's own turn, as one string: the state a refused write must leave.</p>
Method VictimState() As %String
{
    Set tText = ""
    Set tVictim = "'" _ ..#VICTIM _ "'"
    Set tRunning = "'" _ $Get(..Seed("running")) _ "'"
    Set tConvA = "'" _ $Get(..Seed("convA")) _ "'"
    Set tQueries = $ListBuild("SELECT TurnKey, UserName, State, Code, Iterations, StepsDropped, Reply, EndedAt, RowVersion FROM OcuPilot_Kernel_State.Turn WHERE %EXACT(UserName) = " _ tVictim _ " ORDER BY TurnKey", "SELECT s.TurnKey, s.Seq, s.Status, s.Summary, s.Text, s.RowVersion FROM OcuPilot_Kernel_State.Step s JOIN OcuPilot_Kernel_State.Turn t ON s.TurnKey = t.TurnKey WHERE %EXACT(t.UserName) = " _ tVictim _ " ORDER BY s.TurnKey, s.Seq", "SELECT n.TurnKey, n.Seq, n.Outcome, n.Code, n.RowVersion FROM OcuPilot_Kernel_State.Nav n JOIN OcuPilot_Kernel_State.Turn t ON n.TurnKey = t.TurnKey WHERE %EXACT(t.UserName) = " _ tVictim _ " ORDER BY n.TurnKey", "SELECT ConvKey, UserName, CreatedAt, RowVersion FROM OcuPilot_Kernel_State.Convo WHERE %EXACT(UserName) = " _ tVictim _ " ORDER BY ConvKey", "SELECT e.ConvoKey, e.Seq, e.Message, e.AppendedAt, e.RowVersion FROM OcuPilot_Kernel_State.Entry e JOIN OcuPilot_Kernel_State.Convo c ON e.ConvoKey = c.ConvKey WHERE %EXACT(c.UserName) = " _ tVictim _ " ORDER BY e.ConvoKey, e.Seq", "SELECT ProposalKey, UserName, State, TurnKey, ConvKey, RowVersion FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(UserName) = " _ tVictim _ " OR %EXACT(TurnKey) = " _ tRunning _ " OR %EXACT(ConvKey) = " _ tConvA _ " ORDER BY ProposalKey", "SELECT LedgerKey, UserName, TurnKey, Seq FROM OcuPilot_Kernel_State.Ledger WHERE %EXACT(TurnKey) = " _ tRunning _ " OR %EXACT(TurnKey) = " _ tConvA _ " OR %EXACT(UserName) = " _ tVictim _ " ORDER BY LedgerKey")
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
    For tName = "queued", "running", "old" {
        Set tKey = $Get(..Seed(tName))
        Set tText = tText _ tName _ ":" _ $Get(^OcuPilotTurnSignal(tKey, "stop")) _ "/" _ $Get(^OcuPilotTurnSignal(tKey, "abandon")) _ "/" _ $Get(^OcuPilotTurnSignal(tKey, "renewed")) _ " "
    }
    Set tStarts = 0
    Set tSeconds = ""
    For {
        Set tSeconds = $Order(^OcuPilotTurnStarts(..#VICTIM, tSeconds))
        If tSeconds = "" Quit
        Set tStarts = tStarts + 1
    }
    Quit tText _ "starts=" _ tStarts
}

/// <p>The developer's own turn's owner, progress and version as one string.</p>
Method OwnState() As %String
{
    Quit " own:" _ ##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT UserName || '|' || Iterations || '|' || RowVersion FROM OcuPilot_Kernel_State.Turn WHERE %EXACT(TurnKey) = '" _ $Get(..Seed("own")) _ "'")
}

/// <p><method>OcuPilot.Test.AdminStateWrite.RunAs</method> for a plan of probe <var>pProbe</var> whose steps ask
/// this process a question (<method>OcuPilot.Test.OwnerStateWriteProbe.Ask</method>), answered as the suite's own
/// identity, and the child goes on once it is told: <code>slot</code>, whether any process holds the named user's
/// turn slot; <code>runlock</code>, whether any process holds the named run's lock; <code>forgetrun</code>, delete
/// the named run's row, answering 1 when the statement succeeded.</p>
ClassMethod RunAsWatched(pUser As %String, pPlan As %DynamicArray, pProbe As %String = {..#PROBE}) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Job ##class(OcuPilot.Test.AdminStateWriteProbe).RunProbe($Job, pProbe, pUser, pPlan.%ToJSON())::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        For {
            Set tMessage = $System.Event.WaitMsg("", 120)
            If $ListGet(tMessage, 1) '= 1 {
                Do tOut.%Set("error", "the probe process signalled nothing within 120 seconds")
                Quit
            }
            Set tText = $ListGet(tMessage, 2)
            Set tQuestion = $Piece(tText, "|", 1)
            Set tArgument = $Piece(tText, "|", 3)
            If tQuestion = "slot" {
                Set tAnswer = ''$Data(^$LOCK($Name(^OcuPilotTurnSlot(tArgument))))
            } ElseIf tQuestion = "runlock" {
                Set tAnswer = ''$Data(^$LOCK($Name(^OcuPilotSqlRun(tArgument))))
            } ElseIf tQuestion = "forgetrun" {
                Set tAnswer = (##class(%SQL.Statement).%ExecDirect(, "DELETE FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = ?", tArgument).%SQLCODE = 0)
            } Else {
                Set tOut = ##class(%DynamicObject).%FromJSON(tText)
                Quit
            }
            Do $System.Event.Signal($Piece(tText, "|", 2), tAnswer)
        }
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
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
