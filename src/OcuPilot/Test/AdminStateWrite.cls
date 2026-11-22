/// <p>AD-9's store gate: the four stores that hold OcuPilot's administrative state -- the agent
/// switches, the per-user holds, the outbound settings and the governance policy -- refuse a write
/// from a caller who does not hold <code>OcuPilotAdmin:USE</code>, in the store itself, whatever
/// route or code reached it. A real principal holding <code>%Development:USE</code> and the install
/// namespace's code read is refused <code>ERROR #822</code> by every public writer and by the public
/// object saves, and the stored rows and their versions are unchanged; a principal holding
/// <code>OcuPilotAdmin:USE</code> alone writes the kill switch and a governance key; any caller
/// records the observed <code>writesMarked</code> fact.</p>
/// <p>The calls run in a child process logged in as the principal
/// (<class>OcuPilot.Test.AdminStateWriteProbe</class>); the stored rows are read back here by SQL, as
/// the suite's own <code>%All</code> identity.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates and
/// deletes two users and two roles and rewrites the four stores. <method>OnBeforeAllTests</method>
/// refuses anywhere it does not. Every test starts from a known baseline and puts back the rows it
/// found, asserting the restore.</p>
Class OcuPilot.Test.AdminStateWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AdminStateWriteProbe";

Parameter STOREPACKAGE = "OcuPilot.Kernel.State.";

/// <p>The principal holding <code>%Development:USE</code> and the code read, and nothing else.</p>
Parameter DEVUSER = "OcuPilotAdminWriteDev";

Parameter DEVROLE = "OcuPilotAdminWriteDevRole";

/// <p>The principal holding <code>OcuPilotAdmin:USE</code> and the code read, and nothing else.</p>
Parameter ADMINUSER = "OcuPilotAdminWriteAdmin";

Parameter ADMINROLE = "OcuPilotAdminWriteAdminRole";

Parameter KEPTHOLD = "OcuPilotProbeHoldKept";

Parameter NEWHOLD = "OcuPilotProbeHoldNew";

Parameter KEYA = "OcuPilotProbeKeyA";

Parameter KEYB = "OcuPilotProbeKeyB";

/// <p>The throwaway principals' password, generated for the run.</p>
Property PreparedPassword As %String;

/// <p>The content of the four stores found before the test, as <method>Fingerprint</method> reads
/// it without ids and versions.</p>
Property FoundContent As %String;

/// <p>The rows found before the test, as <method>Capture</method> read them.</p>
Property FoundState [ MultiDimensional ];

/// <p>The policy found before the test.</p>
Property FoundPolicy [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..FoundContent = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AdminStateWrite creates and deletes users and roles and rewrites OcuPilot's stores on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuPilotState" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit ..EnsurePrincipals(..PreparedPassword)
}

/// <p>Remove the two principals and their roles; a failing status when any survives.</p>
Method OnAfterAllTests() As %Status
{
    Quit ..RemovePrincipals(..DefaultCases(), "OcuPilot.Test.AdminStateWrite")
}

/// <p>Record what the four stores hold, then leave the baseline every test starts from: no hold, no
/// settings row, no policy row, and one switch row reading its defaults.</p>
Method OnBeforeOneTest() As %Status
{
    Kill ..FoundState, ..FoundPolicy
    Set tSC = ..Capture(.tState)
    If $$$ISERR(tSC) Quit tSC
    Merge ..FoundState = tState
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..FoundPolicy = tRows
    Set ..FoundContent = ..Fingerprint(0)
    Set tSC = ##class(OcuPilot.Test.SwitchFixture).Reset(.tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Kernel.State.Egress).DeleteGuarded()
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Clear()
    If $$$ISERR(tSC) Quit tSC
    Quit ##class(OcuPilot.Test.SwitchFixture).SetSwitches(0, "", 0)
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedDeleteForUser(..#DEVUSER), "the developer's per-user row is removed")
    Kill tState, tRows
    Merge tState = ..FoundState
    Set tSC = ..Put(.tState)
    Do $$$AssertStatusOK(tSC, "the switch row, holds and settings found before the test are put back")
    Merge tRows = ..FoundPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Do $$$AssertStatusOK(tSC, "the policy found before the test is put back")
    Do $$$AssertEquals(..Fingerprint(0), ..FoundContent, "and the four stores read as they were")
    Quit $$$OK
}

/// <p>A developer -- <code>%Development:USE</code>, no <code>OcuPilotAdmin</code> -- calls the kill
/// switch's writers, then opens the switch row with the public <code>GuardedOpenId</code> and saves it
/// through <code>Base</code>'s two public saves, and hands the inherited <code>GuardedStoredValue</code>
/// a method that is not an index lookup. Each is refused <code>822</code>; the control, a direct
/// <code>UPDATE</code> of the table, is refused by the database itself; and the row reads, version
/// included, as it did.</p>
/// <p>Mutations (Rule 19): <method>OcuPilot.Kernel.State.Base.AdminWriteRefused</method> answers
/// <code>$$$OK</code> -> this, the hold test and the egress and policy test go red; the check removed
/// from the public <method>OcuPilot.Kernel.State.Base.GuardedSaveIfCurrent</method> alone -> the
/// <code>Base.GuardedSaveIfCurrent</code> leg goes red alone.</p>
Method TestADeveloperIsRefusedTheKillSwitchAndTheBypass()
{
    Set tId = ..SwitchId()
    Set tBefore = ..Fingerprint(1)
    Set tContext = {"switchId": (tId)}
    Set tSteps = []
    Do tSteps.%Push({"kind": "Sql.UpdateSwitch"})
    Do tSteps.%Push({"kind": "Base.GuardedSave", "id": (tId)})
    Do tSteps.%Push({"kind": "Base.GuardedSaveIfCurrent", "id": (tId)})
    Do tSteps.%Push({"kind": "Base.GuardedStoredValue", "method": "GuardedExecuteOneParam", "key": "UPDATE OcuPilot_Kernel_State.SwitchState SET KillSwitch = 1 WHERE ID = ? OR ID > 0", "property": "KillSwitch"})
    Do tSteps.%Push({"kind": "Base.GuardedStoredValue", "method": "%DeleteId", "key": (tId), "property": "KillSwitch"})
    Set tKinds = ..PlanKinds("switch")
    For tI = 1:1:$ListLength(tKinds) {
        Do tSteps.%Push(..StepFor($List(tKinds, tI), tContext))
    }
    Set tRun = ..RunAs(..#DEVUSER, ..WithReads(tSteps))
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Do ..AssertDeveloperLegs(tRun)
    Do ..AssertStoresUnchanged(tBefore, "the switch row and its version")
}

/// <p>A developer calls the per-user hold's writers: create, delete by id and delete all. Each is
/// refused <code>822</code> and the holds read, ids and versions included, as they did.</p>
/// <p>Mutation (Rule 19): the check removed from
/// <method>OcuPilot.Kernel.State.Hold.GuardedDeleteId</method> alone -> the
/// <code>Hold.GuardedDeleteId</code> leg goes red alone.</p>
Method TestADeveloperIsRefusedTheHoldWrites()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Hold).GuardedCreate(..#KEPTHOLD, "kept", .tKept), "a hold is created for the developer to try to remove")
    Set tBefore = ..Fingerprint(1)
    Set tContext = {"holdId": (tKept)}
    Set tSteps = []
    Set tKinds = ..PlanKinds("hold")
    For tI = 1:1:$ListLength(tKinds) {
        Do tSteps.%Push(..StepFor($List(tKinds, tI), tContext))
    }
    Set tRun = ..RunAs(..#DEVUSER, ..WithReads(tSteps))
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Do ..AssertDeveloperLegs(tRun)
    Do ..AssertStoresUnchanged(tBefore, "the holds")
}

/// <p>A developer calls the outbound settings' writers and the governance policy's: set and delete
/// the settings, apply a preset and a key at the preset's current version, delete every policy row.
/// Each is refused <code>822</code> and both stores read, versions included, as they did.</p>
Method TestADeveloperIsRefusedTheEgressAndPolicyWrites()
{
    Set tValues("proxyServer") = "kept.example.invalid"
    Set tValues("proxyPort") = 8080
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Egress).SetGuarded(.tValues), "a settings row is stored for the developer to try to rewrite")
    Set tSettings(..#KEYA) = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Policy).GuardedApply("full", .tSettings, 0), "a policy is stored for the developer to try to rewrite")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Policy).GuardedAll(.tStored, .tVersion), "and its version is read")
    Set tBefore = ..Fingerprint(1)
    Set tContext = {"policyVersion": (tVersion)}
    Set tSteps = []
    Set tKinds = ..PlanKinds("egresspolicy")
    For tI = 1:1:$ListLength(tKinds) {
        Do tSteps.%Push(..StepFor($List(tKinds, tI), tContext))
    }
    Set tRun = ..RunAs(..#DEVUSER, ..WithReads(tSteps))
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Do ..AssertDeveloperLegs(tRun)
    Do ..AssertStoresUnchanged(tBefore, "the settings and the policy")
}

/// <p>A principal holding <code>OcuPilotAdmin:USE</code> and the code read, without <code>%All</code>,
/// writes the kill switch and a governance key, and both are stored.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.State.Base.CallerIsAdministrator</method> checks
/// <code>%All:USE</code> instead -> this goes red alone.</p>
Method TestAnAdministratorWritesTheKillSwitchAndAKey()
{
    Set tPlan = []
    Do tPlan.%Push({"kind": "Switch.SetGuarded", "killSwitch": 1, "reason": "set by an administrator"})
    Do tPlan.%Push({"kind": "Policy.GuardedApply", "preset": "full", "key": (..#KEYA), "value": "disabled", "version": 0})
    Set tRun = ..RunAs(..#ADMINUSER, tPlan)
    Do ..AssertPrincipal(tRun, ..#ADMINUSER, 1)
    For tI = 1:1:2 {
        Set tLeg = ..Leg(tRun, tI)
        Do $$$AssertTrue($IsObject(tLeg) && tLeg.%Get("ok"), "the administrator's call is accepted: " _ ..LegText(tRun, tI))
    }
    Do $$$AssertEquals(..Stored("SELECT KillSwitch || '|' || KillSwitchReason FROM OcuPilot_Kernel_State.SwitchState ORDER BY ID"), "1|set by an administrator", "the kill switch is stored")
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Policy).GuardedAll(.tStored, .tVersion), "the policy reads")
    Do $$$AssertEquals($Get(tStored(..#KEYA)), "disabled", "and the governance key is stored")
}

/// <p>A developer's caller -- the confirm executor, a screen action, the restraint read -- records
/// the observed marking fact through <code>Event.RecordMarking</code> while holding the switch row
/// with its kill switch changed in memory: <code>writesMarked</code> is stored and every other switch
/// field stays as it was.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Audit.Event.RecordMarking</method> goes back to
/// <method>OcuPilot.Kernel.State.Switch.SetGuarded</method> -> this goes red alone.</p>
Method TestAnyCallerRecordsTheMarkingObservation()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.SwitchFixture).SetSwitches(1, "marking probe", 1), "the switches carry values the observation must not touch")
    Set tOthers = "SELECT KillSwitch || '|' || KillSwitchReason || '|' || EnforcedReadOnly || '|' || ShareContextByDefault || '|' || ContextRowCap || '|' || TurnsPerHour FROM OcuPilot_Kernel_State.SwitchState ORDER BY ID"
    Set tOtherBefore = ..Stored(tOthers)
    Set tMarkedBefore = ..Stored("SELECT WritesMarked FROM OcuPilot_Kernel_State.SwitchState ORDER BY ID")
    Do $$$AssertEquals(tMarkedBefore, 1, "the marking fact starts as the default")
    Set tPlan = [{"kind": "Event.RecordMarking", "marked": 0, "holdEditedRow": 1, "id": (..SwitchId())}]
    Set tRun = ..RunAs(..#DEVUSER, tPlan)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Set tLeg = ..Leg(tRun, 1)
    Do $$$AssertTrue($IsObject(tLeg) && tLeg.%Get("ok"), "the observation is recorded for a developer: " _ ..LegText(tRun, 1))
    Do $$$AssertEquals(..Stored("SELECT WritesMarked FROM OcuPilot_Kernel_State.SwitchState ORDER BY ID"), 0, "writesMarked is stored")
    Do $$$AssertEquals(..Stored(tOthers), tOtherBefore, "and every other switch field is as it was")
}

/// <p>A developer still writes a store that is not administrator-owned: a per-user row is created
/// and then updated through <code>Base</code>'s two public saves, and reads back.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.State.Base.AdminWriteRefused</method> refuses a class
/// that does not declare <parameter>ADMINWRITE</parameter> -> this goes red alone.</p>
Method TestADeveloperStillWritesAStoreThatIsNotAdministratorOwned()
{
    Set tKind = ##class(OcuPilot.Kernel.State.Pref).#KINDSCREENVIEW
    Set tPlan = []
    Do tPlan.%Push({"kind": "Pref.GuardedSetValue", "user": (..#DEVUSER), "prefKind": (tKind), "name": "probe/store-gate", "value": "sort=Name"})
    Do tPlan.%Push({"kind": "Pref.GuardedSetValue", "user": (..#DEVUSER), "prefKind": (tKind), "name": "probe/store-gate", "value": "sort=Time"})
    Set tRun = ..RunAs(..#DEVUSER, tPlan)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    For tI = 1:1:2 {
        Set tLeg = ..Leg(tRun, tI)
        Do $$$AssertTrue($IsObject(tLeg) && tLeg.%Get("ok"), "the per-user write is accepted: " _ ..LegText(tRun, tI))
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Pref).GuardedValue(..#DEVUSER, tKind, "probe/store-gate", .tValue), "the row reads back")
    Do $$$AssertEquals($Get(tValue), "sort=Time", "with the newer value")
}

/// <p>The administrator-owned stores are the classes whose compiled <code>ADMINWRITE</code> is 1,
/// and each one's own public class methods are exactly its declared reads, refused writes, adjuster writes
/// and open writes. Every refused write is a step the probe runs, and the three refusal tests,
/// <class>OcuPilot.Test.StoreOwnerWrite</class>'s agent definition test and
/// <class>OcuPilot.Test.InstallRecordWrite</class> call them through
/// <method>PlanKinds</method>; <code>GuardedRecordWritesMarked</code> and
/// <code>GuardedClearVerification</code> are the writes open to every caller. <code>Base</code>'s own
/// public class methods, which the ten inherit, are exactly <method>BaseSurface</method>'s two halves,
/// and each of its saves is a step the probe runs.</p>
/// <p>Mutation (Rule 19): <code>Parameter ADMINWRITE = 1</code> removed from
/// <class>OcuPilot.Kernel.State.Policy</class> -> this and the egress and policy test go red.</p>
Method TestTheAdministratorStoresAreDeclared()
{
    Set tStores = $ListBuild("Access", "Agent", "Demo", "Egress", "Hold", "Policy", "Stamp", "Switch", "Version", "WebApp")
    Set tDeclared = ""
    For tI = 1:1:$ListLength(tStores) {
        Set tDeclared = tDeclared _ $Select(tDeclared = "": "", 1: ",") _ ..#STOREPACKAGE _ $List(tStores, tI)
    }
    Set tFound = ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT parent FROM %Dictionary.CompiledParameter WHERE Name = 'ADMINWRITE' AND _Default = '1' ORDER BY parent")
    While tRS.%Next() {
        Set tFound = tFound _ $Select(tFound = "": "", 1: ",") _ tRS.%GetData(1)
    }
    Do $$$AssertEquals(tFound, tDeclared, "the classes whose compiled ADMINWRITE is 1 are the ten stores")
    Set tDeclaredWrites = ""
    For tI = 1:1:$ListLength(tStores) {
        Set tWrites = ..Writes($List(tStores, tI)) _ ..AdjusterWrites($List(tStores, tI))
        For tJ = 1:1:$ListLength(tWrites) {
            Set tDeclaredWrites = tDeclaredWrites _ $ListBuild($List(tStores, tI) _ "." _ $List(tWrites, tJ))
        }
    }
    Set tCalled = ..PlanKinds("switch") _ ..PlanKinds("hold") _ ..PlanKinds("egresspolicy") _ ..PlanKinds("agent") _ ..PlanKinds("install")
    Do $$$AssertEquals(..SortedJoin(tCalled), ..SortedJoin(tDeclaredWrites), "the refusal tests call every declared write and nothing else")
    For tI = 1:1:$ListLength(tStores) {
        Set tStore = $List(tStores, tI)
        Set tClass = ..#STOREPACKAGE _ tStore
        Set tPublic = ""
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.MethodDefinition WHERE parent = ? AND ClassMethod = 1 AND Private = 0", tClass)
        While tRS.%Next() {
            Set tPublic = tPublic _ $ListBuild(tRS.%GetData(1))
        }
        Set tSplit = ..Reads(tStore) _ ..Writes(tStore) _ ..AdjusterWrites(tStore) _ ..OpenWrites(tStore)
        Do $$$AssertEquals(..SortedJoin(tPublic), ..SortedJoin(tSplit), tStore _ "'s public class methods are its declared reads, refused writes, adjuster writes and open writes")
        Set tWrites = ..Writes(tStore) _ ..AdjusterWrites(tStore)
        For tJ = 1:1:$ListLength(tWrites) {
            Set tKind = tStore _ "." _ $List(tWrites, tJ)
            Do $$$AssertTrue($ClassMethod(..ProbeFor(tStore), "Handles", tKind), tKind _ " is a write the probe calls")
        }
    }
    Set tPublic = ""
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.MethodDefinition WHERE parent = 'OcuPilot.Kernel.State.Base' AND ClassMethod = 1 AND Private = 0")
    While tRS.%Next() {
        Set tPublic = tPublic _ $ListBuild(tRS.%GetData(1))
    }
    Do $$$AssertEquals(..SortedJoin(tPublic), ..SortedJoin(..BaseSurface(0) _ ..BaseSurface(1)), "Base's public class methods are its declared reads and helpers and its refused saves")
    Set tWrites = ..BaseSurface(1)
    For tJ = 1:1:$ListLength(tWrites) {
        Do $$$AssertTrue($ClassMethod(..#PROBE, "Handles", "Base." _ $List(tWrites, tJ)), "Base." _ $List(tWrites, tJ) _ " is a save the probe calls")
    }
}

/// <p><code>Base</code>'s public class methods: with <var>pWrites</var> 1, the saves that refuse an
/// administrator-owned store's object to a caller who is not an administrator; with 0, the methods that
/// write no row of those stores.</p>
ClassMethod BaseSurface(pWrites As %Boolean) As %List
{
    If pWrites Quit $ListBuild("GuardedSave", "GuardedSaveIfCurrent")
    Quit $ListBuild("AdminWriteRefused", "BoundedWhere", "CallerIsAdministrator", "CallerOwns", "GuardedExistsId", "GuardedOpenId", "GuardedProbeGet", "GuardedProbeSet", "GuardedRolesSnapshot", "GuardedRolesSnapshotThenThrow", "GuardedSslConfigRead", "GuardedStoredValue", "GuardedUserAbsent", "GuardedUserEnabled", "IsCapBusy", "IsDuplicateKey", "IsLockConflict", "IsStaleSave", "OwnerWriteRefused")
}

/// <p>The writes the refusal test <var>pTest</var> (<code>switch</code>, <code>hold</code> or
/// <code>egresspolicy</code>) calls, as <code>Store.Method</code>.</p>
ClassMethod PlanKinds(pTest As %String) As %List
{
    If pTest = "switch" Quit $ListBuild("Switch.SetGuarded", "Switch.DeleteGuarded")
    If pTest = "hold" Quit $ListBuild("Hold.GuardedCreate", "Hold.GuardedDeleteId", "Hold.DeleteAllGuarded")
    If pTest = "agent" Quit ##class(OcuPilot.Test.StoreOwnerWrite).AgentWriteKinds()
    If pTest = "install" Quit ##class(OcuPilot.Test.InstallRecordWrite).WriteKinds()
    Quit $ListBuild("Egress.SetGuarded", "Egress.DeleteGuarded", "Policy.GuardedApply", "Policy.DeleteAllGuarded")
}

/// <p>The reads <var>pStore</var> declares: its public class methods that write no row.</p>
ClassMethod Reads(pStore As %String) As %List
{
    If ..IsInstallStore(pStore) Quit ##class(OcuPilot.Test.InstallRecordWrite).Reads(pStore)
    If pStore = "Agent" Quit $ListBuild("GuardedByName", "GuardedCredentialNamedByEnabled", "GuardedCredentialOwned", "GuardedIdsByCredentialName", "GuardedIsEnabled", "GuardedList", "GuardedRetentions", "GuardedScreenRows", "GuardedVersion", "ResolveDefault", "ResolveFor", "ScreenRow", "SecurityFields", "SnapshotSecurityFields", "Timestamp")
    If pStore = "Switch" Quit $ListBuild("GuardedVersion", "Resolve", "Timestamp")
    If pStore = "Hold" Quit $ListBuild("GuardedForUser", "GuardedIdForUser", "GuardedList", "GuardedScreenRows", "ScreenRow", "Timestamp")
    If pStore = "Egress" Quit $ListBuild("GuardedVersion", "Resolve")
    Quit $ListBuild("GuardedAll", "Timestamp")
}

/// <p>The writes <var>pStore</var> refuses a caller that does not hold the administrator
/// privilege.</p>
ClassMethod Writes(pStore As %String) As %List
{
    If ..IsInstallStore(pStore) Quit ##class(OcuPilot.Test.InstallRecordWrite).Writes(pStore)
    If pStore = "Agent" Quit $ListBuild("GuardedCreate", "GuardedUpdate", "GuardedSetVerification", "GuardedMarkCredentialCreated", "GuardedDeleteId", "SetDefaultGuarded", "GuardedRebalanceDefault")
    If pStore = "Switch" Quit $ListBuild("SetGuarded", "DeleteGuarded")
    If pStore = "Hold" Quit $ListBuild("GuardedCreate", "GuardedDeleteId", "DeleteAllGuarded")
    If pStore = "Egress" Quit $ListBuild("SetGuarded", "DeleteGuarded")
    Quit $ListBuild("GuardedApply", "DeleteAllGuarded")
}

/// <p>The writes <var>pStore</var> admits to a caller who holds one of its adjuster pairs as well as to an
/// administrator: the screen-access store's two, none for any other store.</p>
ClassMethod AdjusterWrites(pStore As %String) As %List
{
    If ..IsInstallStore(pStore) Quit ##class(OcuPilot.Test.InstallRecordWrite).AdjusterWrites(pStore)
    Quit ""
}

/// <p>Whether <var>pStore</var> is one of the five stores <class>OcuPilot.Test.InstallRecordWrite</class> pins: the
/// install-owned stores and the screen-access store.</p>
ClassMethod IsInstallStore(pStore As %String) As %Boolean
{
    Quit ''$ListFind(##class(OcuPilot.Test.InstallRecordWrite).Stores(), pStore)
}

/// <p>The probe class that runs <var>pStore</var>'s steps.</p>
ClassMethod ProbeFor(pStore As %String) As %String
{
    If ..IsInstallStore(pStore) Quit ##class(OcuPilot.Test.InstallRecordWrite).#PROBE
    If pStore = "Agent" Quit "OcuPilot.Test.OwnerStateWriteProbe"
    Quit ..#PROBE
}

/// <p>The writes <var>pStore</var> leaves open to every caller.</p>
ClassMethod OpenWrites(pStore As %String) As %List
{
    If pStore = "Switch" Quit $ListBuild("GuardedRecordWritesMarked")
    If pStore = "Agent" Quit $ListBuild("GuardedClearVerification")
    Quit ""
}

/// <p>The names in <var>pNames</var>, a <code>$ListBuild</code> list, sorted and comma-joined.</p>
ClassMethod SortedJoin(pNames As %List) As %String
{
    Set tText = ""
    For tI = 1:1:$ListLength(pNames) {
        Set tSorted($List(pNames, tI)) = ""
    }
    Set tName = ""
    For {
        Set tName = $Order(tSorted(tName))
        If tName = "" Quit
        Set tText = tText _ $Select(tText = "": "", 1: ",") _ tName
    }
    Quit tText
}

/// <p>The plan step <var>pKind</var> names, with the arguments a developer would send. Context
/// holds the ids and versions the step names.</p>
ClassMethod StepFor(pKind As %String, pContext As %DynamicObject) As %DynamicObject
{
    If pKind = "Switch.SetGuarded" Quit {"kind": (pKind), "killSwitch": 1, "reason": "rewritten by a developer"}
    If pKind = "Hold.GuardedCreate" Quit {"kind": (pKind), "user": (..#NEWHOLD), "reason": "held by a developer"}
    If pKind = "Hold.GuardedDeleteId" Quit {"kind": (pKind), "id": (pContext.%Get("holdId"))}
    If pKind = "Egress.SetGuarded" Quit {"kind": (pKind), "proxyServer": "proxy.invalid", "proxyPort": 3128}
    If pKind = "Policy.GuardedApply" Quit {"kind": (pKind), "preset": "read-only", "key": (..#KEYB), "value": "disabled", "version": (pContext.%Get("policyVersion"))}
    Quit {"kind": (pKind)}
}

/// <p>The id of the switch row, read by SQL.</p>
ClassMethod SwitchId() As %String
{
    Quit ..Stored("SELECT TOP 1 ID FROM OcuPilot_Kernel_State.SwitchState ORDER BY ID")
}

/// <p>The first column of the first row <var>pSql</var> answers, or <code>""</code>.</p>
ClassMethod Stored(pSql As %String) As %String
{
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, pSql)
    If tRS.%SQLCODE < 0 Quit "SQLCODE " _ tRS.%SQLCODE
    If 'tRS.%Next() Quit ""
    Quit tRS.%GetData(1)
}

/// <p>The rows of the four stores as one string. Each row is its columns joined by <code>~</code>;
/// with <var>pFull</var> 0 the id and the version are left out, which is what a restore can
/// reproduce.</p>
ClassMethod Fingerprint(pFull As %Boolean = 1) As %String
{
    Set tText = ""
    Set tQueries = $ListBuild("SELECT ID, KillSwitch, KillSwitchReason, EnforcedReadOnly, ShareContextByDefault, ContextRowCap, TurnsPerHour, WritesMarked, RowVersion FROM OcuPilot_Kernel_State.SwitchState ORDER BY ID", "SELECT ID, UserName, Reason, RowVersion FROM OcuPilot_Kernel_State.Hold ORDER BY UserName", "SELECT ID, ProxyServer, ProxyPort, ProxyHttps, ProxyTunnel, TimeoutSeconds, MaxAttempts, SslConfiguration, RowVersion FROM OcuPilot_Kernel_State.Egress ORDER BY ID", "SELECT ID, Name, Value, RowVersion FROM OcuPilot_Kernel_State.Policy ORDER BY Name")
    For tI = 1:1:$ListLength(tQueries) {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, $List(tQueries, tI))
        If tRS.%SQLCODE < 0 {
            Set tText = tText _ "[query " _ tI _ " failed " _ tRS.%SQLCODE _ "]"
            Continue
        }
        Set tText = tText _ "[" _ tI
        While tRS.%Next() {
            Set tRow = ""
            Set tFirst = $Select(pFull: 1, 1: 2)
            Set tLast = tRS.%ResultColumnCount - $Select(pFull: 0, 1: 1)
            For tC = tFirst:1:tLast {
                Set tRow = tRow _ $Select(tRow = "": "", 1: "~") _ tRS.%GetData(tC)
            }
            Set tText = tText _ " {" _ tRow _ "}"
        }
        Set tText = tText _ "]"
    }
    Quit tText
}

/// <p>The switch row, the holds and the settings row as <var>pState</var>, by SQL, as
/// <method>Put</method> stores them again.</p>
ClassMethod Capture(Output pState) As %Status
{
    Kill pState
    Set tSC = $$$OK
    Try {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 KillSwitch, KillSwitchReason, EnforcedReadOnly, ShareContextByDefault, ContextRowCap, TurnsPerHour, WritesMarked FROM OcuPilot_Kernel_State.SwitchState ORDER BY ID")
        If tRS.%SQLCODE < 0 Set tSC = $$$ERROR($$$GeneralError, "the switch row could not be read: " _ tRS.%SQLCODE) Quit
        If tRS.%Next() {
            Set pState("switch") = $ListBuild(tRS.%GetData(1), tRS.%GetData(2), tRS.%GetData(3), tRS.%GetData(4), tRS.%GetData(5), tRS.%GetData(6), tRS.%GetData(7))
        }
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT UserName, Reason FROM OcuPilot_Kernel_State.Hold ORDER BY ID")
        If tRS.%SQLCODE < 0 Set tSC = $$$ERROR($$$GeneralError, "the holds could not be read: " _ tRS.%SQLCODE) Quit
        Set tCount = 0
        While tRS.%Next() {
            Set tCount = tCount + 1
            Set pState("hold", tCount) = $ListBuild(tRS.%GetData(1), tRS.%GetData(2))
        }
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT TOP 1 ProxyServer, ProxyPort, ProxyHttps, ProxyTunnel, TimeoutSeconds, MaxAttempts, SslConfiguration FROM OcuPilot_Kernel_State.Egress ORDER BY ID")
        If tRS.%SQLCODE < 0 Set tSC = $$$ERROR($$$GeneralError, "the settings row could not be read: " _ tRS.%SQLCODE) Quit
        If tRS.%Next() {
            Set pState("egress") = $ListBuild(tRS.%GetData(1), tRS.%GetData(2), tRS.%GetData(3), tRS.%GetData(4), tRS.%GetData(5), tRS.%GetData(6), tRS.%GetData(7))
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Put the switch row, the holds and the settings row back to <var>pState</var>, a
/// <method>Capture</method>, through the stores' own writers, as the suite's <code>%All</code>
/// identity.</p>
ClassMethod Put(ByRef pState) As %Status
{
    Set tSC = ##class(OcuPilot.Test.SwitchFixture).Reset(.tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Kernel.State.Egress).DeleteGuarded()
    If $$$ISERR(tSC) Quit tSC
    If $Data(pState("switch")) {
        Set tRow = pState("switch")
        Set tValues("killSwitch") = $List(tRow, 1)
        Set tValues("killSwitchReason") = $List(tRow, 2)
        Set tValues("enforcedReadOnly") = $List(tRow, 3)
        Set tValues("shareContextByDefault") = $List(tRow, 4)
        Set tValues("contextRowCap") = $List(tRow, 5)
        Set tValues("turnsPerHour") = $List(tRow, 6)
        Set tValues("writesMarked") = $List(tRow, 7)
        Set tSC = ##class(OcuPilot.Kernel.State.Switch).SetGuarded(.tValues)
        If $$$ISERR(tSC) Quit tSC
    }
    Set tIndex = ""
    For {
        Set tIndex = $Order(pState("hold", tIndex), 1, tRow)
        If tIndex = "" Quit
        Set tSC = ##class(OcuPilot.Kernel.State.Hold).GuardedCreate($List(tRow, 1), $List(tRow, 2))
        If $$$ISERR(tSC) Quit
    }
    If $$$ISERR(tSC) Quit tSC
    If $Data(pState("egress")) {
        Set tRow = pState("egress")
        Kill tValues
        Set tValues("proxyServer") = $List(tRow, 1)
        Set tValues("proxyPort") = $List(tRow, 2)
        Set tValues("proxyHttps") = $List(tRow, 3)
        Set tValues("proxyTunnel") = $List(tRow, 4)
        Set tValues("timeoutSeconds") = $List(tRow, 5)
        Set tValues("maxAttempts") = $List(tRow, 6)
        Set tValues("sslConfiguration") = $List(tRow, 7)
        Set tSC = ##class(OcuPilot.Kernel.State.Egress).SetGuarded(.tValues)
    }
    Quit tSC
}

/// <p>Assert that the four stores read, ids and versions included, as <var>pBefore</var>, a
/// <method>Fingerprint</method>, read them, and that neither reading failed.</p>
Method AssertStoresUnchanged(pBefore As %String, pWhat As %String)
{
    Set tNow = ..Fingerprint(1)
    Do $$$AssertTrue(pBefore '[ "failed]", "the stores could be read before and after")
    Do $$$AssertEquals(tNow, pBefore, pWhat _ " are unchanged; the stored rows read " _ tNow)
}

/// <p>Assert that <var>pRun</var> ran as <var>pUser</var>, who holds <code>OcuPilotAdmin:USE</code>
/// exactly when <var>pAdministrator</var> is 1, holds <code>%Development:USE</code> exactly when it
/// is not, and holds <code>%All</code> never.</p>
Method AssertPrincipal(pRun As %DynamicObject, pUser As %String, pAdministrator As %Boolean)
{
    Do $$$AssertEquals($Select(pRun.%IsDefined("error"): pRun.%Get("error"), 1: pRun.%Get("username") _ " " _ pRun.%Get("loggedIn")), pUser _ " 1", "the child process ran as the principal")
    Do $$$AssertEquals(''pRun.%Get("holdsAdmin"), ''pAdministrator, "the principal's OcuPilotAdmin:USE reads " _ pRun.%Get("holdsAdmin") _ "; roles " _ pRun.%Get("roles"))
    Do $$$AssertEquals(''pRun.%Get("holdsDevelopment"), $Select(pAdministrator: 0, 1: 1), "and its %Development:USE reads " _ pRun.%Get("holdsDevelopment"))
    Do $$$AssertTrue(("," _ pRun.%Get("roles") _ ",") '[ ",%All,", "and it does not hold %All")
}

/// <p><var>pSteps</var>, a developer's writes, as a plan that reads each store the writes touch once
/// before the first write and again after every write, as the principal sees it.</p>
ClassMethod WithReads(pSteps As %DynamicArray) As %DynamicArray
{
    Set tPlan = []
    Set tKinds = ""
    Set tIterator = pSteps.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tStep) {
        Set tRead = ..ReadKind(tStep.%Get("kind"))
        If '$ListFind(tKinds, tRead) {
            Set tKinds = tKinds _ $ListBuild(tRead)
            Do tPlan.%Push({"kind": (tRead)})
        }
    }
    Set tIterator = pSteps.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tStep) {
        Do tPlan.%Push(tStep)
        Do tPlan.%Push({"kind": (..ReadKind(tStep.%Get("kind")))})
    }
    Quit tPlan
}

/// <p>The read step that shows what the write <var>pKind</var> touches.</p>
ClassMethod ReadKind(pKind As %String) As %String
{
    If $Piece(pKind, ".", 1) = "Hold" Quit "Read.Holds"
    If $Piece(pKind, ".", 1) = "Egress" Quit "Read.Egress"
    If $Piece(pKind, ".", 1) = "Policy" Quit "Read.Policy"
    Quit "Read.Switch"
}

/// <p>Assert every leg of a developer's run: each write is refused with code 822 (the direct
/// <code>UPDATE</code> by the database), and every read answers what the first read of its kind
/// answered.</p>
Method AssertDeveloperLegs(pRun As %DynamicObject)
{
    Set tLegs = $Select(pRun.%GetTypeOf("steps") = "array": pRun.%Get("steps"), 1: [])
    Do $$$AssertTrue(tLegs.%Size() > 0, "the child answered its legs" _ $Select(pRun.%IsDefined("error"): ": " _ pRun.%Get("error"), 1: ""))
    For tI = 1:1:tLegs.%Size() {
        Set tLeg = tLegs.%Get(tI - 1)
        Set tKind = tLeg.%Get("kind")
        If $Extract(tKind, 1, 5) = "Read." {
            Do $$$AssertTrue(tLeg.%Get("ok"), tKind _ " answers for the principal: " _ ..LegText(pRun, tI))
            If '$Data(tBaseline(tKind)) {
                Set tBaseline(tKind) = tLeg.%Get("state")
                Continue
            }
            Do $$$AssertEquals(tLeg.%Get("state"), tBaseline(tKind), "after the writes so far the principal reads " _ tKind _ " as " _ tLeg.%Get("state") _ ", as it read it first (" _ tBaseline(tKind) _ ")")
        } ElseIf tKind = "Sql.UpdateSwitch" {
            Do $$$AssertTrue(tLeg.%Get("sqlcode") < 0, "the control, a direct UPDATE of the switch table, is refused by the database: " _ ..LegText(pRun, tI))
        } Else {
            Do $$$AssertEquals(..LegText(pRun, tI), tKind _ " ok=0 code=822", tKind _ " is refused 822: " _ ..LegText(pRun, tI) _ " " _ tLeg.%Get("text"))
        }
    }
}

/// <p>Run the probe class <var>pProbe</var> (<class>OcuPilot.Test.AdminStateWriteProbe</class> or a
/// subclass of it) as <var>pUser</var> over <var>pPlan</var> in a child process and answer what it
/// signalled, or an object carrying <code>error</code>.</p>
ClassMethod RunAs(pUser As %String, pPlan As %DynamicArray, pProbe As %String = "OcuPilot.Test.AdminStateWriteProbe") As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Set tPlan = pPlan.%ToJSON()
        Job ##class(OcuPilot.Test.AdminStateWriteProbe).RunProbe($Job, pProbe, pUser, tPlan)::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 120)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within 120 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>Step <var>pIndex</var> (from 1) of the child's answer <var>pRun</var>, or <code>""</code>.</p>
ClassMethod Leg(pRun As %DynamicObject, pIndex As %Integer) As %DynamicObject
{
    If '$IsObject(pRun) || (pRun.%GetTypeOf("steps") '= "array") Quit ""
    Quit pRun.%Get("steps").%Get(pIndex - 1)
}

/// <p>Step <var>pIndex</var> as <code>kind ok=n code=c</code>, plus <code>sqlcode</code> when the
/// step carries one, for one-line comparisons.</p>
ClassMethod LegText(pRun As %DynamicObject, pIndex As %Integer) As %String
{
    Set tLeg = ..Leg(pRun, pIndex)
    If '$IsObject(tLeg) Quit "absent"
    Set tText = tLeg.%Get("kind") _ " ok=" _ +tLeg.%Get("ok") _ " code=" _ tLeg.%Get("code")
    If tLeg.%IsDefined("sqlcode") Set tText = tText _ " sqlcode=" _ tLeg.%Get("sqlcode")
    Quit tText
}

/// <p>The step <var>pIndex</var> of <var>pRun</var> as <method>Detail</method> gives the first.</p>
ClassMethod DetailOf(pRun As %DynamicObject, pIndex As %Integer) As %String
{
    Set tLeg = ..Leg(pRun, pIndex)
    Quit ..LegText(pRun, pIndex) _ $Select($IsObject(tLeg) && (tLeg.%Get("text") '= ""): " " _ tLeg.%Get("text"), 1: "")
}

/// <p>The first step of <var>pRun</var> as <method>OcuPilot.Test.AdminStateWrite.LegText</method> gives
/// it, with the status text it carries.</p>
ClassMethod Detail(pRun As %DynamicObject) As %String
{
    Quit ..DetailOf(pRun, 1)
}

/// <p>The kinds of the steps of the plan <var>pPlan</var>, as a list.</p>
ClassMethod KindsOf(pPlan As %DynamicArray) As %List
{
    Set tKinds = ""
    For tI = 0:1:pPlan.%Size() - 1 {
        Set tKinds = tKinds _ $ListBuild(pPlan.%Get(tI).%Get("kind"))
    }
    Quit tKinds
}

/// <p>The principals this class creates, as <method>EnsurePrincipals</method> takes them: each is
/// <code>$ListBuild(user, role, grants, holdsAdministrator)</code>, plus an optional fifth element
/// <code>holdsAdjuster</code> (<code>%Development:USE</code> or <code>%Admin_Secure:USE</code>). <parameter>DEVROLE</parameter>
/// holds the install namespace's code and data read and <code>%Development:USE</code>;
/// <parameter>ADMINROLE</parameter> holds the same read and <code>OcuPilotAdmin:USE</code>.</p>
ClassMethod DefaultCases() As %List
{
    Quit $ListBuild($ListBuild(..#DEVUSER, ..#DEVROLE, "%Development:U", 0), $ListBuild(..#ADMINUSER, ..#ADMINROLE, "OcuPilotAdmin:U", 1))
}

/// <p>Delete each account and role <var>pCases</var> names (as <method>EnsurePrincipals</method> takes
/// them) and answer a failing status, naming <var>pSuite</var>, when any survives.</p>
ClassMethod RemovePrincipals(pCases As %List, pSuite As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tLeft = 0
        For tI = 1:1:$ListLength(pCases) {
            Set tUser = $List($List(pCases, tI), 1)
            Set tRole = $List($List(pCases, tI), 2)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tRole) Set tLeft = 1
        }
        If tLeft Set tSC = $$$ERROR($$$GeneralError, pSuite _ " left a throwaway principal on the instance")
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

/// <p>Create each throwaway role and the account that holds it, then read the grants back. A case of
/// <var>pCases</var> (default <method>DefaultCases</method>) holds the install namespace's code and data access
/// <var>pAccess</var> (<code>R</code> or <code>RW</code>) plus its own grants; the account's password is
/// <var>pPassword</var>. The read-back requires that no account holds <code>%All</code>, that it holds
/// <code>OcuPilotAdmin</code> as the case's fourth element says and, as the fifth says when the case has one, that it
/// holds an adjuster pair (<code>%Development:USE</code> or <code>%Admin_Secure:USE</code>); a case without a fifth
/// element holds <code>%Development:USE</code> exactly when it holds no <code>OcuPilotAdmin</code> and never
/// <code>%Admin_Secure:USE</code>.</p>
ClassMethod EnsurePrincipals(pPassword As %String, pCases As %List = "", pAccess As %String = "R") As %Status
{
    If pCases = "" Set pCases = ..DefaultCases()
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tNamespace = ##class(Config.Namespaces).Open(tInstallNs)
        Set tRead = ""
        For tDatabaseName = tNamespace.Routines, tNamespace.Globals {
            Set tDatabase = ##class(Config.Databases).Open(tDatabaseName)
            Set tResource = ##class(SYS.Database).%OpenId(tDatabase.Directory).ResourceName _ ":" _ pAccess
            If tRead '[ tResource Set tRead = tRead _ $Select(tRead = "": "", 1: ",") _ tResource
        }
        For tCaseIndex = 1:1:$ListLength(pCases) {
            Set tCase = $List(pCases, tCaseIndex)
            Set tUser = $List(tCase, 1)
            Set tRole = $List(tCase, 2)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: the store gate (throwaway)", tRead _ $Select($List(tCase, 3) = "": "", 1: "," _ $List(tCase, 3)), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create(tUser, tRole, pPassword, "OcuPilot store gate test principal (throwaway)", "", "", "", 0, 1, "Created by an OcuPilot armed test class; deleted in its OnAfterAllTests")
            If $$$ISERR(tSC) Quit
            Set tHoldsAdmin = ($SYSTEM.Security.CheckUserPermission(tUser, "OcuPilotAdmin", "USE") = 1)
            Set tHoldsDevelopment = ($SYSTEM.Security.CheckUserPermission(tUser, "%Development", "USE") = 1)
            Set tHoldsSecure = ($SYSTEM.Security.CheckUserPermission(tUser, "%Admin_Secure", "USE") = 1)
            If $ListLength(tCase) > 4 {
                Set tAdjusterWrong = ((tHoldsDevelopment || tHoldsSecure) '= $List(tCase, 5))
            } Else {
                Set tAdjusterWrong = ((tHoldsDevelopment = $List(tCase, 4)) || tHoldsSecure)
            }
            If ($SYSTEM.Security.CheckUserPermission(tUser, "%All", "USE") = 1) || (tHoldsAdmin '= $List(tCase, 4)) || tAdjusterWrong {
                Set tSC = $$$ERROR($$$GeneralError, "the throwaway principal " _ tUser _ "'s grants did not read back as declared")
                Quit
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

}
