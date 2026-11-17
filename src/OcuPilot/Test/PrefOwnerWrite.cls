/// <p>AD-9's owner gate, batch three: the preferences, the sharing choice and the background runs refuse a
/// write from a caller who may not make it, in the store itself, whatever route or code reached it. A real
/// principal holding <code>%Development:USE</code> and the install namespace's code read, and no
/// <code>OcuPilotAdmin</code>, is refused <code>ERROR #822</code> by every public writer of those stores that
/// names another user's account or run, by every cross-user delete and sweep, and by <code>Base</code>'s public
/// saves, and the stored rows read as they did. The same principal still writes its own rows through every owner
/// writer, an administrator writes anyone's, and a background run reserve still sweeps other users' expired runs.</p>
/// <p>The calls run in a child process logged in as the principal
/// (<class>OcuPilot.Test.PrefStateWriteProbe</class>); the stored rows are read back here by SQL, as the suite's own
/// <code>%All</code> identity, which also seeds them.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates and deletes two users and
/// two roles, rewrites OcuPilot's stores and empties the preference and sharing stores. <method>OnBeforeAllTests</method>
/// refuses anywhere it does not. Every test removes the rows it created, by the names only this class uses, and asserts
/// the removal.</p>
Class OcuPilot.Test.PrefOwnerWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.PrefStateWriteProbe";

/// <p>The principal holding <code>%Development:USE</code> and the code read, and nothing else.</p>
Parameter DEVUSER = "OcuPilotPrefDev";

Parameter DEVROLE = "OcuPilotPrefDevRole";

/// <p>The principal holding <code>OcuPilotAdmin:USE</code> and the code read, and nothing else.</p>
Parameter ADMINUSER = "OcuPilotPrefAdmin";

Parameter ADMINROLE = "OcuPilotPrefAdminRole";

/// <p>The user name whose rows the developer attacks. No account has it.</p>
Parameter VICTIM = "OcuPilotPrefVictim";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>A timestamp no live row carries: a row aged to it is past every retention.</p>
Parameter OLD = "2000-01-01T00:00:00Z";

Parameter STOREPACKAGE = "OcuPilot.Kernel.State.";

/// <p>The throwaway principals' password, generated for the run.</p>
Property PreparedPassword As %String;

/// <p>What the last seed stored: <code>prefId</code> (the victim's value row), <code>ownPrefId</code>,
/// <code>ownShareId</code>, <code>queued</code> (the victim's queued run's key), <code>queuedId</code>,
/// <code>ended</code>, <code>ownRun</code> and <code>ownRunId</code>.</p>
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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.PrefOwnerWrite creates and deletes users and roles and writes OcuPilot's stores on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuPilotPref" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit ##class(OcuPilot.Test.AdminStateWrite).EnsurePrincipals(..PreparedPassword, ..Principals())
}

/// <p>Remove the two principals and their roles; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Quit ##class(OcuPilot.Test.AdminStateWrite).RemovePrincipals(..Principals(), "OcuPilot.Test.PrefOwnerWrite")
}

/// <p>The developer and the administrator, as <method>OcuPilot.Test.AdminStateWrite.EnsurePrincipals</method> takes
/// them.</p>
ClassMethod Principals() As %List
{
    Quit $ListBuild($ListBuild(..#DEVUSER, ..#DEVROLE, "%Development:U", 0), $ListBuild(..#ADMINUSER, ..#ADMINROLE, "OcuPilotAdmin:U", 1))
}

Method OnBeforeOneTest() As %Status
{
    Kill ..Seed
    Quit ..RemoveOwnRows()
}

Method OnAfterOneTest() As %Status
{
    Set tSC = ..RemoveOwnRows()
    Do $$$AssertStatusOK(tSC, "the preferences, sharing choices and runs this test created are removed")
    Do $$$AssertEquals(..LeftOver(), 0, "and none of them survives")
    Quit $$$OK
}

/// <p>A developer calls each writer of another user's preferences, sharing choice and background runs, one call to a
/// child process so each is measured alone against a fresh set of the victim's rows
/// (<method>VictimKinds</method>): add, remove, clear, touch, set and trim a preference, save a preference row through
/// <code>Base</code>'s two public saves, set the sharing choice, reserve, begin, finish and cancel a run, and the
/// deletes, sweeps and purges across users. Each is refused <code>822</code> and the victim's rows read, versions
/// included, as they did.</p>
/// <p>Mutation (Rule 19): <code>OwnerWriteRefused</code> answers <code>$$$OK</code> first -> this goes red with the
/// batch one and two refusal tests; no owner, administrator or open-path test does. <code>SqlRun.GuardedBegin</code>
/// checks the key's stored owner before its lock -> removing that check turns the last leg red.</p>
Method TestADeveloperIsRefusedAVictimsSettings()
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
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, [{"kind": "SqlRun.GuardedBegin", "user": (..#DEVUSER), "key": (..Seed("queued"))}], ..#PROBE)
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "SqlRun.GuardedBegin ok=0 code=822", "a begin of the victim's run under the developer's own name is refused before it takes the run's lock: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
    Do $$$AssertEquals(..VictimState(), tBefore, "and leaves the victim's rows as they were")
}

/// <p>A developer holds its own preference row, sharing row and run row with their <code>UserName</code> set to the
/// victim in memory and calls that store's writer for its own name: each is refused <code>822</code>, and the stored
/// owner is still the developer. An administrator holding the victim's preference row under its own name is refused
/// the same way, so a save never changes an owner.</p>
/// <p>Mutation (Rule 19): <code>OwnerChangeRefused</code> skips the stored-versus-held owner comparison -> the three
/// developer legs and the administrator leg go red.</p>
Method TestAForgedOwnerIsRefusedAndTheStoredOwnerStands()
{
    If '..SeedVictim() Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Sharing).GuardedDeleteForUser(..#VICTIM), "the victim's sharing row is removed, so a held copy of the developer's names a free key")
    Set tBefore = ..VictimState() _ ..OwnState()
    Set tPlan = []
    Do tPlan.%Push({"kind": "Pref.ForgedSetValue", "user": (..#DEVUSER), "id": (..Seed("ownPrefId")), "heldUser": (..#VICTIM), "prefKind": "view", "name": "own/v", "value": "forged"})
    Do tPlan.%Push({"kind": "Sharing.ForgedSetForUser", "user": (..#DEVUSER), "id": (..Seed("ownShareId")), "heldUser": (..#VICTIM), "share": 0})
    Do tPlan.%Push({"kind": "SqlRun.ForgedCancel", "user": (..#DEVUSER), "id": (..Seed("ownRunId")), "key": (..Seed("ownRun")), "heldUser": (..#VICTIM), "runKind": "sql"})
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun)
    For tI = 1:1:tPlan.%Size() {
        Set tKind = tPlan.%Get(tI - 1).%Get("kind")
        Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, tI), tKind _ " ok=0 code=822", "the developer's row held as the victim's is refused 822 by " _ tKind _ ": " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, tI))
    }
    Set tPlan = [{"kind": "Pref.ForgedSetValue", "user": (..#VICTIM), "id": (..Seed("prefId")), "heldUser": (..#ADMINUSER), "prefKind": "view", "name": "tasks/v", "value": "forged"}]
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#ADMINUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#ADMINUSER, 1)
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "Pref.ForgedSetValue ok=0 code=822", "an administrator's writer save of the victim's row held under another owner is refused 822: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, 1))
    Do $$$AssertEquals(..VictimState() _ ..OwnState(), tBefore, "the stored owners, values and versions are as they were")
}

/// <p>A developer writes its own preferences, sharing choice and runs through every owner writer, in the order
/// <method>OwnerPlan</method> runs them: add, touch, set, trim, remove and clear preferences, set the sharing choice
/// twice, begin, cancel and finish its reserved run, and reserve another. Each is accepted and the rows read as the
/// writer says.</p>
/// <p>Mutation (Rule 19): <code>CallerOwns</code> answers 0 always -> this and the open-path test go red.</p>
Method TestADeveloperWritesItsOwnSettings()
{
    If '..SeedVictim() Quit
    Set tPlan = ..OwnerPlan(1, ..Seed("ownRun"))
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun)
    Do ..AssertAccepted(tRun, tPlan, "for the owner")
    Do $$$AssertEquals(..OwnPrefs(), "favorite/own/a|recent/own/r|view/own/new=x|view/own/v=y", "its preferences read as the writers left them")
    Set tPlan = ..OwnerPlan(2, ..Seed("ownRun"))
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun)
    Do ..AssertAccepted(tRun, tPlan, "for the owner")
    Do $$$AssertEquals(..OwnPrefs(), "", "its trim, remove and clear leave it no preference")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT Share FROM OcuPilot_Kernel_State.Sharing WHERE %EXACT(UserName) = '" _ ..#DEVUSER _ "'"), 1, "its sharing choice reads as the second write left it")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(UserName) = '" _ ..#DEVUSER _ "' AND State = 'queued'"), 1, "and its second reserve stored a queued run")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = '" _ ..Seed("ownRun") _ "'"), 0, "in place of the run it finished, which the reserve replaced")
}

/// <p>An administrator -- <code>OcuPilotAdmin:USE</code> and the code read, no <code>%All</code> -- writes the
/// victim's preferences, sharing choice and queued run (<method>AdministratorOwnerPlan</method>); then every
/// cross-user sweep, purge and delete that is an administrator's (<method>AdministratorPlan</method>). Each is
/// accepted and the rows read as the writer says.</p>
/// <p>Mutation (Rule 19): the administrator bypass removed from <code>OwnerWriteRefused</code> -> this goes red with
/// the other administrator tests.</p>
Method TestAnAdministratorWritesAVictimsSettingsAndSweeps()
{
    If '..SeedVictim() Quit
    Set tPlan = ..AdministratorOwnerPlan(..Seed("queued"))
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#ADMINUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#ADMINUSER, 1)
    Do ..AssertAccepted(tRun, tPlan, "for an administrator")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT Value FROM OcuPilot_Kernel_State.Pref WHERE %EXACT(UserName) = '" _ ..#VICTIM _ "' AND Kind = 'view'"), "by an administrator", "the victim's preference holds the administrator's value")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT Share FROM OcuPilot_Kernel_State.Sharing WHERE %EXACT(UserName) = '" _ ..#VICTIM _ "'"), 1, "the victim's sharing choice holds the administrator's")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT State FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = '" _ ..Seed("queued") _ "'"), "canceled", "the victim's queued run was begun, canceled and finished")
    Set tPlan = ..AdministratorPlan()
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#ADMINUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#ADMINUSER, 1)
    Do ..AssertAccepted(tRun, tPlan, "for an administrator")
    Do $$$AssertEquals(..LeftOver(..#VICTIM), 0, "the sweeps, purges and deletes removed the victim's rows")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = '" _ ..Seed("ended") _ "'"), 0, "including the victim's ended run")
}

/// <p>A background run reserve works as a real developer, one with no <code>OcuPilotAdmin</code>, against a victim's
/// rows and has the effect it had before the gate: it stores the developer's run and sweeps another user's expired
/// ended run.</p>
/// <p>Mutation (Rule 19): <code>SqlRun.GuardedReserve</code> calls the public <code>GuardedSweep</code> -> this goes
/// red.</p>
Method TestTheOpenSweepStillWorks()
{
    If '..SeedVictim() Quit
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, [{"kind": "SqlRun.GuardedReserve", "user": (..#DEVUSER)}], ..#PROBE)
    Do ..AssertPrincipal(tRun)
    Set tLeg = ##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 1)
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "SqlRun.GuardedReserve ok=1 code=", "the reserve is accepted: " _ ##class(OcuPilot.Test.AdminStateWrite).Detail(tRun))
    Do $$$AssertTrue($IsObject(tLeg) && tLeg.%Get("sweepOk"), "and the sweep reports success")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = '" _ ..Seed("ended") _ "'"), 0, "the victim's expired ended run is swept")
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT State FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = '" _ ..Seed("queued") _ "'"), "queued", "while the victim's live run stays")
}

/// <p>The owner stores of this batch are the classes whose compiled <code>OWNERWRITE</code> is not empty
/// (<method>Stores</method>), and each one's own public class methods are exactly its declared reads, owner writes,
/// administrator writes and open writes. Every owner write is a step of the stranger's list
/// (<method>VictimKinds</method>) and of the plans the owner runs (<method>OwnerPlan</method>), and every
/// administrator write one of the stranger's list and of the plan the administrator runs
/// (<method>AdministratorPlan</method>).</p>
/// <p>Mutation (Rule 19): <code>Parameter OWNERWRITE</code> emptied on <class>OcuPilot.Kernel.State.Sharing</class> ->
/// this, the victim test and the forged-owner test go red.</p>
Method TestTheOwnerStoresAreDeclared()
{
    Set tStores = ..Stores()
    Set tOwnerRan = ##class(OcuPilot.Test.AdminStateWrite).KindsOf(..OwnerPlan(1)) _ ##class(OcuPilot.Test.AdminStateWrite).KindsOf(..OwnerPlan(2)) _ ##class(OcuPilot.Test.AdminStateWrite).KindsOf(..AdministratorOwnerPlan())
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
        Set tSplit = ..Reads(tStore) _ ..OwnerWrites(tStore) _ ..AdministratorWrites(tStore)
        Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).SortedJoin(tPublic), ##class(OcuPilot.Test.AdminStateWrite).SortedJoin(tSplit), tStore _ "'s public class methods are its declared reads, owner writes and administrator writes")
        Do ..AssertCalled(tStore, ..OwnerWrites(tStore), ..VictimKinds(), "an owner write is tried by a stranger")
        Do ..AssertCalled(tStore, ..OwnerWrites(tStore), tOwnerRan, "an owner write is run by the owner's plan")
        Do ..AssertCalled(tStore, ..AdministratorWrites(tStore), ..VictimKinds(), "an administrator write is tried by a stranger")
        Do ..AssertCalled(tStore, ..AdministratorWrites(tStore), tAdministratorRan, "an administrator write is run by the administrator's plan")
    }
    Set tHandled = ""
    Set tAll = ..VictimKinds() _ tOwnerRan _ tAdministratorRan
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

/// <p>Assert that every step of <var>pPlan</var> was accepted in <var>pRun</var>.</p>
Method AssertAccepted(pRun As %DynamicObject, pPlan As %DynamicArray, pWho As %String)
{
    For tI = 1:1:pPlan.%Size() {
        Set tLeg = ##class(OcuPilot.Test.AdminStateWrite).Leg(pRun, tI)
        Do $$$AssertTrue($IsObject(tLeg) && tLeg.%Get("ok"), "step " _ tI _ " (" _ pPlan.%Get(tI - 1).%Get("kind") _ ") is accepted " _ pWho _ ": " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(pRun, tI))
    }
}

/// <p>The stores this class covers.</p>
ClassMethod Stores() As %List
{
    Quit $ListBuild("Pref", "Sharing", "SqlRun")
}

/// <p>The steps a stranger is refused on another user's rows, one child process each.</p>
ClassMethod VictimKinds() As %List
{
    Quit $ListBuild("Pref.GuardedAdd", "Pref.GuardedRemove", "Pref.GuardedClear", "Pref.GuardedTouch", "Pref.GuardedSetValue", "Pref.GuardedTrim", "Pref.BaseSave", "Pref.BaseSaveIfCurrent", "Pref.DeleteAllGuarded", "Pref.GuardedDeleteForUser", "Sharing.GuardedSetForUser", "Sharing.DeleteAllGuarded", "Sharing.GuardedDeleteForUser", "SqlRun.GuardedReserve", "SqlRun.GuardedBegin", "SqlRun.GuardedFinish", "SqlRun.GuardedCancel", "SqlRun.GuardedSweep", "SqlRun.GuardedForgetUser")
}

/// <p>The reads <var>pStore</var> declares: its public class methods that write no row.</p>
ClassMethod Reads(pStore As %String) As %List
{
    If pStore = "Pref" Quit $ListBuild("GuardedListForUser", "GuardedValue", "IsShellMember", "IsThemeValue", "GuardedCountForUser", "GuardedUsers")
    If pStore = "Sharing" Quit $ListBuild("GuardedForUser", "GuardedUsers")
    Quit $ListBuild("IsTerminal", "GuardedViewForOwner", "GuardedCancelRequested")
}

/// <p>The writes <var>pStore</var> refuses a caller who does not own the row.</p>
ClassMethod OwnerWrites(pStore As %String) As %List
{
    If pStore = "Pref" Quit $ListBuild("GuardedAdd", "GuardedRemove", "GuardedClear", "GuardedTouch", "GuardedSetValue", "GuardedTrim")
    If pStore = "Sharing" Quit $ListBuild("GuardedSetForUser")
    Quit $ListBuild("GuardedReserve", "GuardedBegin", "GuardedFinish", "GuardedCancel")
}

/// <p>The writes <var>pStore</var> refuses a caller who does not hold the administrator privilege.</p>
ClassMethod AdministratorWrites(pStore As %String) As %List
{
    If pStore = "Pref" Quit $ListBuild("DeleteAllGuarded", "GuardedDeleteForUser")
    If pStore = "Sharing" Quit $ListBuild("DeleteAllGuarded", "GuardedDeleteForUser")
    Quit $ListBuild("GuardedSweep", "GuardedForgetUser")
}

/// <p>The step a stranger tries for <var>pKind</var>, against the rows the last seed stored.</p>
Method LegStep(pKind As %String) As %DynamicObject
{
    Set tStep = {"kind": (pKind), "user": (..#VICTIM), "prefKind": "favorite", "name": "tasks/a", "keep": 0, "value": "evil", "share": 1, "key": (..Seed("queued")), "id": (..Seed("prefId")), "runKind": "sql"}
    If pKind = "Pref.GuardedAdd" Do tStep.%Set("name", "tasks/new")
    If (pKind = "Pref.GuardedTouch") || (pKind = "Pref.GuardedTrim") {
        Do tStep.%Set("prefKind", "recent")
        Do tStep.%Set("name", "tasks/r1")
    }
    If pKind = "Pref.GuardedSetValue" {
        Do tStep.%Set("prefKind", "view")
        Do tStep.%Set("name", "tasks/v")
    }
    Quit tStep
}

/// <p>The plan the developer runs against its own rows, in two parts, one step for each of its owner writes in the order
/// a person's session runs them: part 1 adds, touches and sets preferences; part 2 trims, removes and clears them, sets
/// the sharing choice and runs the run reserved for it, then reserves another.</p>
ClassMethod OwnerPlan(pPart As %Integer, pRunKey As %String = "") As %DynamicArray
{
    Set tUser = ..#DEVUSER
    Set tPlan = []
    If pPart = 1 {
        Do tPlan.%Push({"kind": "Pref.GuardedAdd", "user": (tUser), "prefKind": "favorite", "name": "own/a"})
        Do tPlan.%Push({"kind": "Pref.GuardedTouch", "user": (tUser), "prefKind": "recent", "name": "own/r"})
        Do tPlan.%Push({"kind": "Pref.GuardedTouch", "user": (tUser), "prefKind": "recent", "name": "own/r"})
        Do tPlan.%Push({"kind": "Pref.GuardedSetValue", "user": (tUser), "prefKind": "view", "name": "own/new", "value": "x"})
        Do tPlan.%Push({"kind": "Pref.GuardedSetValue", "user": (tUser), "prefKind": "view", "name": "own/v", "value": "y"})
        Quit tPlan
    }
    Do tPlan.%Push({"kind": "Pref.GuardedTrim", "user": (tUser), "prefKind": "recent", "keep": 0})
    Do tPlan.%Push({"kind": "Pref.GuardedRemove", "user": (tUser), "prefKind": "favorite", "name": "own/a"})
    Do tPlan.%Push({"kind": "Pref.GuardedClear", "user": (tUser), "prefKind": "view"})
    Do tPlan.%Push({"kind": "Sharing.GuardedSetForUser", "user": (tUser), "share": 0})
    Do tPlan.%Push({"kind": "Sharing.GuardedSetForUser", "user": (tUser), "share": 1})
    Do tPlan.%Push({"kind": "SqlRun.GuardedBegin", "user": (tUser), "key": (pRunKey)})
    Do tPlan.%Push({"kind": "SqlRun.GuardedCancel", "user": (tUser), "key": (pRunKey), "runKind": "sql"})
    Do tPlan.%Push({"kind": "SqlRun.GuardedFinish", "key": (pRunKey)})
    Do tPlan.%Push({"kind": "SqlRun.GuardedReserve", "user": (tUser)})
    Quit tPlan
}

/// <p>The plan the administrator runs against the victim's rows, first part: the owner writes, on rows that are not its
/// own.</p>
ClassMethod AdministratorOwnerPlan(pRunKey As %String = "") As %DynamicArray
{
    Set tUser = ..#VICTIM
    Set tPlan = []
    Do tPlan.%Push({"kind": "Pref.GuardedSetValue", "user": (tUser), "prefKind": "view", "name": "tasks/v", "value": "by an administrator"})
    Do tPlan.%Push({"kind": "Pref.GuardedAdd", "user": (tUser), "prefKind": "favorite", "name": "tasks/c"})
    Do tPlan.%Push({"kind": "Pref.GuardedTouch", "user": (tUser), "prefKind": "recent", "name": "tasks/r1"})
    Do tPlan.%Push({"kind": "Pref.GuardedTrim", "user": (tUser), "prefKind": "recent", "keep": 5})
    Do tPlan.%Push({"kind": "Pref.GuardedRemove", "user": (tUser), "prefKind": "favorite", "name": "tasks/b"})
    Do tPlan.%Push({"kind": "Pref.GuardedClear", "user": (tUser), "prefKind": "favorite"})
    Do tPlan.%Push({"kind": "Sharing.GuardedSetForUser", "user": (tUser), "share": 1})
    Do tPlan.%Push({"kind": "SqlRun.GuardedBegin", "user": (tUser), "key": (pRunKey)})
    Do tPlan.%Push({"kind": "SqlRun.GuardedCancel", "user": (tUser), "key": (pRunKey), "runKind": "sql"})
    Do tPlan.%Push({"kind": "SqlRun.GuardedFinish", "key": (pRunKey)})
    Quit tPlan
}

/// <p>The plan the administrator runs, second part: every sweep, purge and delete that is an administrator's.</p>
ClassMethod AdministratorPlan() As %DynamicArray
{
    Set tUser = ..#VICTIM
    Set tPlan = []
    Do tPlan.%Push({"kind": "SqlRun.GuardedSweep"})
    Do tPlan.%Push({"kind": "SqlRun.GuardedForgetUser", "user": (tUser)})
    Do tPlan.%Push({"kind": "Pref.GuardedDeleteForUser", "user": (tUser)})
    Do tPlan.%Push({"kind": "Sharing.GuardedDeleteForUser", "user": (tUser)})
    Do tPlan.%Push({"kind": "Pref.DeleteAllGuarded"})
    Do tPlan.%Push({"kind": "Sharing.DeleteAllGuarded"})
    Quit tPlan
}

/// <p>The stored preference rows that name the developer, as a string.</p>
Method OwnPrefs() As %String
{
    Set tText = ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Kind, Name, Value FROM OcuPilot_Kernel_State.Pref WHERE %EXACT(UserName) = ? ORDER BY Kind, Name", ..#DEVUSER)
    While tRS.%Next() {
        Set tText = tText _ $Select(tText = "": "", 1: "|") _ tRS.%GetData(1) _ "/" _ tRS.%GetData(2) _ $Select((tRS.%GetData(3) = "") || (tRS.%GetData(3) = $Char(0)): "", 1: "=" _ tRS.%GetData(3))
    }
    Quit tText
}

/// <p>Remove every preference, sharing choice and run of the victim and the developer. Only names this class owns are
/// touched.</p>
Method RemoveOwnRows() As %Status
{
    Set tSC = $$$OK
    For tUser = ..#VICTIM, ..#DEVUSER {
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Pref).GuardedDeleteForUser(tUser))
        Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Sharing).GuardedDeleteForUser(tUser))
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(UserName) = ?", tUser)
        If tRS.%SQLCODE < 0 Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the runs could not be removed: SQLCODE " _ tRS.%SQLCODE))
    }
    Quit tSC
}

/// <p>How many preferences, sharing choices and runs of <var>pUser</var> survive, or of the victim and the developer
/// when it is empty; the sum is 0 once <method>RemoveOwnRows</method> has run.</p>
ClassMethod LeftOver(pUser As %String = "") As %Integer
{
    Set tNames = $Select(pUser = "": "'" _ ..#VICTIM _ "', '" _ ..#DEVUSER _ "'", 1: "'" _ pUser _ "'")
    Set tCount = 0
    For tTable = "Pref", "Sharing", "SqlRun" {
        Set tCount = tCount + ##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State." _ tTable _ " WHERE UserName IN (" _ tNames _ ")")
    }
    Quit tCount
}

/// <p>Remove the rows of an earlier leg and store, as the suite's own identity, the victim's rows: two favorites, a
/// recent screen and a screen view, a sharing choice, a queued SQL run and an ended MDX run aged to
/// <parameter>OLD</parameter>; and the developer's own screen view and its queued run. The keys are in
/// <property>Seed</property>. Answers 0 after a failed assertion.</p>
Method SeedVictim() As %Boolean
{
    Set tSC = ..RemoveOwnRows()
    Do $$$AssertStatusOK(tSC, "the rows of an earlier leg are removed")
    Kill ..Seed
    Set tPref = "OcuPilot.Kernel.State.Pref"
    Set tSC = $ClassMethod(tPref, "GuardedAdd", ..#VICTIM, "favorite", "tasks/a", 20, .tAtLimit)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(tPref, "GuardedAdd", ..#VICTIM, "favorite", "tasks/b", 20, .tAtLimit)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(tPref, "GuardedTouch", ..#VICTIM, "recent", "tasks/r1")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(tPref, "GuardedSetValue", ..#VICTIM, "view", "tasks/v", "sort=Name")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(tPref, "GuardedSetValue", ..#DEVUSER, "view", "own/v", "sort=Own")
    If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Kernel.State.Sharing).GuardedSetForUser(..#VICTIM, 0)
    If $$$ISOK(tSC) Set tSC = ##class(OcuPilot.Kernel.State.Sharing).GuardedSetForUser(..#DEVUSER, 1)
    Do $$$AssertStatusOK(tSC, "the victim and the developer hold preferences and sharing choices")
    If $$$ISERR(tSC) Quit 0
    Set ..Seed("prefId") = ##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT ID FROM OcuPilot_Kernel_State.Pref WHERE %EXACT(UserName) = '" _ ..#VICTIM _ "' AND Kind = 'view'")
    Set ..Seed("ownPrefId") = ##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT ID FROM OcuPilot_Kernel_State.Pref WHERE %EXACT(UserName) = '" _ ..#DEVUSER _ "' AND Kind = 'view'")
    Set ..Seed("ownShareId") = ##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT ID FROM OcuPilot_Kernel_State.Sharing WHERE %EXACT(UserName) = '" _ ..#DEVUSER _ "'")
    Set tRun = "OcuPilot.Kernel.State.SqlRun"
    Set tSC = $ClassMethod(tRun, "GuardedReserve", ..#VICTIM, $NAMESPACE, 100, ..#LIMITS, .tEnded, .tBusy, .tFull, .tSweep, "mdx")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(tRun, "GuardedReserve", ..#VICTIM, $NAMESPACE, 100, ..#LIMITS, .tQueued, .tBusy, .tFull, .tSweep)
    If $$$ISOK(tSC) Set tSC = $ClassMethod(tRun, "GuardedReserve", ..#DEVUSER, $NAMESPACE, 100, ..#LIMITS, .tOwn, .tBusy, .tFull, .tSweep)
    Do $$$AssertTrue($$$ISOK(tSC) && (tEnded '= "") && (tQueued '= "") && (tOwn '= ""), "the victim has a queued and an ended run, and the developer a queued one")
    If (tEnded = "") || (tQueued = "") || (tOwn = "") Quit 0
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "UPDATE OcuPilot_Kernel_State.SqlRun SET State = 'ended', EndedAt = ? WHERE %EXACT(RunKey) = ?", ..#OLD, tEnded)
    Do $$$AssertTrue(tRS.%SQLCODE >= 0, "the victim's MDX run ended long ago")
    Set ..Seed("ended") = tEnded
    Set ..Seed("queued") = tQueued
    Set ..Seed("ownRun") = tOwn
    Set ..Seed("queuedId") = ##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT ID FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = '" _ tQueued _ "'")
    Set ..Seed("ownRunId") = ##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT ID FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(RunKey) = '" _ tOwn _ "'")
    Quit tRS.%SQLCODE >= 0
}

/// <p>The victim's preferences, sharing choice and runs as one string: the state a refused write must leave.</p>
Method VictimState() As %String
{
    Set tText = ""
    Set tVictim = "'" _ ..#VICTIM _ "'"
    Set tQueries = $ListBuild("SELECT UserName, Kind, Name, Value, UpdatedAt, RowVersion FROM OcuPilot_Kernel_State.Pref WHERE %EXACT(UserName) = " _ tVictim _ " ORDER BY Kind, Name", "SELECT UserName, Share, RowVersion FROM OcuPilot_Kernel_State.Sharing WHERE %EXACT(UserName) = " _ tVictim, "SELECT RunKey, UserName, Kind, State, CancelRequested, JobId, QueuedAt, StartedAt, EndedAt, Namespace, RowVersion FROM OcuPilot_Kernel_State.SqlRun WHERE %EXACT(UserName) = " _ tVictim _ " ORDER BY RunKey")
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

/// <p>The developer's own rows' owners and versions as one string.</p>
Method OwnState() As %String
{
    Set tText = " own:"
    Set tText = tText _ ##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT UserName || '|' || RowVersion FROM OcuPilot_Kernel_State.Pref WHERE ID = '" _ $Get(..Seed("ownPrefId")) _ "'")
    Set tText = tText _ "," _ ##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT UserName || '|' || RowVersion FROM OcuPilot_Kernel_State.Sharing WHERE ID = '" _ $Get(..Seed("ownShareId")) _ "'")
    Set tText = tText _ "," _ ##class(OcuPilot.Test.AdminStateWrite).Stored("SELECT UserName || '|' || RowVersion FROM OcuPilot_Kernel_State.SqlRun WHERE ID = '" _ $Get(..Seed("ownRunId")) _ "'")
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
