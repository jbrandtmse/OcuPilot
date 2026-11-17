/// <p>AD-9's store gate for the install-owned stores (application provenance, install stamps, version rows and
/// demo inventory) and the screen-access store, as real principals meet it. A principal holding
/// <code>%Development:USE</code> and no <code>OcuPilotAdmin</code> is refused <code>ERROR #822</code> by every
/// writer of the install records and by <code>Base</code>'s public saves of their rows, and a forged provenance
/// row cannot steer an uninstall. Screen access refuses a caller who holds neither <code>OcuPilotAdmin:USE</code>
/// nor one of the adjuster pairs, a set its port would refuse, and a changer that is not the caller, and a write
/// that is accepted is recorded once in the audit.</p>
/// <p>The calls run in a child process logged in as each principal
/// (<class>OcuPilot.Test.InstallRecordProbe</class>); the rows are read back here by SQL, as the suite's own
/// <code>%All</code> identity.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot's production install, and
/// <parameter>ARMINGVARIABLE</parameter> and <parameter>INSTALLARMING</parameter> reading <code>1</code>, because
/// the class creates and deletes users and roles, installs and uninstalls the probe profile and replaces a probe
/// web application. <method>OnBeforeAllTests</method> refuses anywhere either does not. Every row it seeds names a
/// profile or screen starting with <code>probe</code>, removed after each test.</p>
Class OcuPilot.Test.InstallRecordWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the principals, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The environment variable that arms the probe install the provenance test runs.</p>
Parameter INSTALLARMING = "OCUPILOT_ALLOW_PRODUCTION_INSTALL";

Parameter PROBE = "OcuPilot.Test.InstallRecordProbe";

Parameter STOREPACKAGE = "OcuPilot.Kernel.State.";

/// <p>Holds <code>%Development:USE</code> and the install namespace's code read, and nothing else.</p>
Parameter DEVUSER = "OcuPilotInstallRecDev";

Parameter DEVROLE = "OcuPilotInstallRecDevRole";

/// <p>Holds <code>OcuPilotAdmin:USE</code> and the install namespace's code read, and no <code>%All</code>.</p>
Parameter ADMINUSER = "OcuPilotInstallRecAdmin";

Parameter ADMINROLE = "OcuPilotInstallRecAdminRole";

/// <p>Holds <code>%Admin_Secure:USE</code>, the other adjuster pair, and the code read.</p>
Parameter SECUSER = "OcuPilotInstallRecSec";

Parameter SECROLE = "OcuPilotInstallRecSecRole";

/// <p>Holds the code read and no adjuster pair and no <code>OcuPilotAdmin</code>.</p>
Parameter PLAINUSER = "OcuPilotInstallRecPlain";

Parameter PLAINROLE = "OcuPilotInstallRecPlainRole";

/// <p>The profile of the rows the class seeds; the rows it asks a principal to write name
/// <parameter>OcuPilot.Test.InstallRecordProbe.FORGEDPROFILE</parameter>.</p>
Parameter SEEDPROFILE = "probeseed";

Parameter SEEDPATH = "/probeseed/application";

Parameter SEEDSCREEN = "probe.install.seed";

/// <p>The screen-access row the removal legs name; it is seeded beside <parameter>SEEDSCREEN</parameter>.</p>
Parameter REMOVESCREEN = "probe.install.remove";

/// <p>The prefix of every screen the class names.</p>
Parameter SCREENPREFIX = "probe.";

/// <p>The subscript of the probe global <code>^OcuPilotKernelStateProbe</code> this class writes.</p>
Parameter PROBEKEY = "probeInstallRecord";

Property PreparedPassword As %String;

Property PreparedIds As %DynamicObject;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedIds = {}
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#INSTALLARMING) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.InstallRecordWrite creates and deletes users and roles, installs and uninstalls the probe profile and rewrites OcuPilot's install records on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#INSTALLARMING _ " must both read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets them.")
    }
    Set ..PreparedPassword = "OcuPilotInstRec" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Quit ..EnsurePrincipals(..PreparedPassword)
}

Method OnAfterAllTests() As %Status
{
    Quit ##class(OcuPilot.Test.AdminStateWrite).RemovePrincipals(..Cases(), "OcuPilot.Test.InstallRecordWrite")
}

/// <p>Remove what an earlier test left and seed one row of each store the legs open.</p>
Method OnBeforeOneTest() As %Status
{
    Do ..Clean()
    Quit ..Seed()
}

Method OnAfterOneTest() As %Status
{
    Do ..Clean()
    Quit $$$OK
}

/// <p>The principals, as <code>$ListBuild(user, role, grants)</code>.</p>
ClassMethod Cases() As %List
{
    Quit $ListBuild($ListBuild(..#DEVUSER, ..#DEVROLE, "%Development:U"), $ListBuild(..#ADMINUSER, ..#ADMINROLE, "OcuPilotAdmin:U"), $ListBuild(..#SECUSER, ..#SECROLE, "%Admin_Secure:U"), $ListBuild(..#PLAINUSER, ..#PLAINROLE, ""))
}

/// <p>Create each role of <method>Cases</method> with the install namespace's databases read plus its grants,
/// and its account, then read back that none holds <code>%All</code>, that only the administrator holds
/// <code>OcuPilotAdmin</code> and that only the developer and the security principal hold an adjuster pair.</p>
ClassMethod EnsurePrincipals(pPassword As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set $NAMESPACE = "%SYS"
        Set tNamespace = ##class(Config.Namespaces).Open(tInstallNs)
        Set tRead = ""
        For tDatabaseName = tNamespace.Routines, tNamespace.Globals {
            Set tResource = ##class(SYS.Database).%OpenId(##class(Config.Databases).Open(tDatabaseName).Directory).ResourceName _ ":R"
            If tRead '[ tResource Set tRead = tRead _ $Select(tRead = "": "", 1: ",") _ tResource
        }
        Set tCases = ..Cases()
        For tI = 1:1:$ListLength(tCases) {
            Set tCase = $List(tCases, tI)
            Set tUser = $List(tCase, 1)
            Set tRole = $List(tCase, 2)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: install records (throwaway)", tRead _ $Select($List(tCase, 3) = "": "", 1: "," _ $List(tCase, 3)), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create(tUser, tRole, pPassword, "OcuPilot install record test principal (throwaway)", "", "", "", 0, 1, "Created by an OcuPilot armed test class; deleted in its OnAfterAllTests")
            If $$$ISERR(tSC) Quit
            Set tAdmin = ($SYSTEM.Security.CheckUserPermission(tUser, "OcuPilotAdmin", "USE") = 1)
            Set tAdjuster = (($SYSTEM.Security.CheckUserPermission(tUser, "%Development", "USE") = 1) || ($SYSTEM.Security.CheckUserPermission(tUser, "%Admin_Secure", "USE") = 1))
            If ($SYSTEM.Security.CheckUserPermission(tUser, "%All", "USE") = 1) || (tAdmin '= (tUser = ..#ADMINUSER)) || (tAdjuster '= ((tUser = ..#DEVUSER) || (tUser = ..#SECUSER))) {
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

/// <p>Delete every row of the five stores that names a probe profile, path or screen.</p>
ClassMethod Clean()
{
    Set tPackage = "OcuPilot_Kernel_State."
    For tTable = "WebApp", "Stamp", "Version", "Demo" {
        Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM " _ tPackage _ tTable _ " WHERE Profile %STARTSWITH 'probe' AND Profile <> 'probe'")
    }
    Do ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM " _ tPackage _ "ScreenAccess WHERE Screen %STARTSWITH ?", ..#SCREENPREFIX)
    Kill ^OcuPilotKernelStateProbe(..#PROBEKEY)
}

/// <p>Seed one row of each store under the seed profile and the seed screen, as the suite's own identity, and
/// remember the ids.</p>
Method Seed() As %Status
{
    Set tPackage = ..#STOREPACKAGE
    Set tSC = $ClassMethod(tPackage _ "WebApp", "GuardedRecord", ..#SEEDPROFILE, ..#SEEDPATH, "created")
    Set tStamp = ##class(OcuPilot.Kernel.State.Stamp).%New()
    Set tStamp.Profile = ..#SEEDPROFILE
    Set tStamp.Timestamp = "1990-01-01T00:00:00Z"
    Set tStamp.GrantOutcome = "seed"
    Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Base).GuardedSave(tStamp))
    Set tVersion = ##class(OcuPilot.Kernel.State.Version).%New()
    Set tVersion.Profile = ..#SEEDPROFILE
    Set tVersion.Phase = "installed"
    Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Base).GuardedSave(tVersion))
    Set tDemo = ##class(OcuPilot.Kernel.State.Demo).%New()
    Set tDemo.Profile = ..#SEEDPROFILE
    Set tDemo.Kind = "webapp"
    Set tDemo.Name = ..#SEEDPATH
    Set tDemo.Scope = "instance"
    Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Base).GuardedSave(tDemo))
    Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Access).GuardedPut(..#SEEDSCREEN, "%Admin_Secure:USE", 0, $Username))
    Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Kernel.State.Access).GuardedPut(..#REMOVESCREEN, "%Admin_Secure:USE", 0, $Username))
    Set ..PreparedIds = {}
    Do ..PreparedIds.%Set("WebApp", ..Stored("SELECT ID FROM OcuPilot_Kernel_State.WebApp WHERE Profile = ?", ..#SEEDPROFILE), "string")
    Do ..PreparedIds.%Set("Stamp", ..Stored("SELECT ID FROM OcuPilot_Kernel_State.Stamp WHERE Profile = ?", ..#SEEDPROFILE), "string")
    Do ..PreparedIds.%Set("Version", ..Stored("SELECT ID FROM OcuPilot_Kernel_State.Version WHERE Profile = ?", ..#SEEDPROFILE), "string")
    Do ..PreparedIds.%Set("Demo", ..Stored("SELECT ID FROM OcuPilot_Kernel_State.Demo WHERE Profile = ?", ..#SEEDPROFILE), "string")
    Do ..PreparedIds.%Set("Access", ..Stored("SELECT ID FROM OcuPilot_Kernel_State.ScreenAccess WHERE Screen = ?", ..#SEEDSCREEN), "string")
    Quit tSC
}

/// <p>The first column of the first row <var>pSql</var> answers when bound to <var>pValue</var>, or
/// <code>""</code>.</p>
ClassMethod Stored(pSql As %String, pValue As %String = "") As %String
{
    If pValue = "" {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, pSql)
    } Else {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, pSql, pValue)
    }
    If (tRS.%SQLCODE < 0) || 'tRS.%Next() Quit ""
    Quit tRS.%GetData(1)
}

/// <p>The rows of the five stores that name a probe profile or screen, and each table's size, as one string.
/// Each row is its columns joined by <code>~</code>.</p>
ClassMethod Fingerprint() As %String
{
    Set tText = ""
    Set tPackage = "OcuPilot_Kernel_State."
    Set tQueries = $ListBuild("SELECT ID, Profile, Path, Origin, GatewayReported, RowVersion FROM " _ tPackage _ "WebApp WHERE Profile %STARTSWITH 'probe' ORDER BY ID", "SELECT ID, Profile, Timestamp, GrantOutcome, RowVersion FROM " _ tPackage _ "Stamp WHERE Profile %STARTSWITH 'probe' ORDER BY ID", "SELECT ID, Profile, Phase, SchemaVersion, RowVersion FROM " _ tPackage _ "Version WHERE Profile %STARTSWITH 'probe' ORDER BY ID", "SELECT ID, Profile, Kind, Name, Scope, RowVersion FROM " _ tPackage _ "Demo WHERE Profile %STARTSWITH 'probe' ORDER BY ID", "SELECT ID, Screen, Pairs, ChangedBy, RowVersion FROM " _ tPackage _ "ScreenAccess WHERE Screen %STARTSWITH 'probe.' ORDER BY ID", "SELECT COUNT(*) FROM " _ tPackage _ "WebApp", "SELECT COUNT(*) FROM " _ tPackage _ "Stamp", "SELECT COUNT(*) FROM " _ tPackage _ "Version", "SELECT COUNT(*) FROM " _ tPackage _ "Demo", "SELECT COUNT(*) FROM " _ tPackage _ "ScreenAccess")
    For tI = 1:1:$ListLength(tQueries) {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, $List(tQueries, tI))
        If tRS.%SQLCODE < 0 {
            Set tText = tText _ "[query " _ tI _ " failed " _ tRS.%SQLCODE _ "]"
            Continue
        }
        Set tText = tText _ "[" _ tI
        While tRS.%Next() {
            Set tText = tText _ "{"
            For tC = 1:1:tRS.%ResultColumnCount {
                Set tText = tText _ $Select(tC = 1: "", 1: "~") _ tRS.%GetData(tC)
            }
            Set tText = tText _ "}"
        }
        Set tText = tText _ "]"
    }
    Quit tText
}

/// <p>The stores this class pins: the five that declare <code>ADMINWRITE</code> beside the original five.</p>
ClassMethod Stores() As %List
{
    Quit $ListBuild("WebApp", "Stamp", "Version", "Demo", "Access")
}

/// <p>The public class methods of <var>pStore</var> that write no row.</p>
ClassMethod Reads(pStore As %String) As %List
{
    If pStore = "WebApp" Quit $ListBuild("GuardedForPath", "GuardedPathsForProfile", "GuardedUnreportedForProfile")
    If pStore = "Version" Quit $ListBuild("GuardedCurrentForProfile")
    If pStore = "Demo" Quit $ListBuild("GuardedRowExists", "GuardedIdsForProfile")
    If pStore = "Access" Quit $ListBuild("GuardedAll", "GuardedGet", "GuardedPairsFor", "Timestamp")
    Quit ""
}

/// <p>The writes <var>pStore</var> refuses a caller who does not hold <code>OcuPilotAdmin:USE</code>.</p>
ClassMethod Writes(pStore As %String) As %List
{
    If pStore = "WebApp" Quit $ListBuild("GuardedRecord", "GuardedMarkGatewayReported", "DeleteByPath")
    If pStore = "Stamp" Quit $ListBuild("DeleteByProfile", "GuardedSweep")
    If pStore = "Access" Quit $ListBuild("DeleteAllGuarded")
    Quit $ListBuild("DeleteByProfile")
}

/// <p>The writes <var>pStore</var> admits to a caller holding <code>OcuPilotAdmin:USE</code> or an adjuster
/// pair.</p>
ClassMethod AdjusterWrites(pStore As %String) As %List
{
    If pStore = "Access" Quit $ListBuild("GuardedPut", "GuardedRemove")
    Quit ""
}

/// <p>Every write as <code>Store.Method</code>, adjuster writes first so a purge comes after the writes that name a row.</p>
ClassMethod WriteKinds() As %List
{
    Set tKinds = ""
    Set tStores = ..Stores()
    For tI = 1:1:$ListLength(tStores) {
        Set tStore = $List(tStores, tI)
        Set tWrites = ..AdjusterWrites(tStore) _ ..Writes(tStore)
        For tJ = 1:1:$ListLength(tWrites) Set tKinds = tKinds _ $ListBuild(tStore _ "." _ $List(tWrites, tJ))
    }
    Quit tKinds
}

/// <p>The plan step <var>pKind</var> names with the arguments an attacker would send.</p>
ClassMethod StepFor(pKind As %String) As %DynamicObject
{
    If pKind = "WebApp.GuardedRecord" Quit {"kind": (pKind), "profile": (..#SEEDPROFILE), "path": (..#SEEDPATH), "origin": "created"}
    If pKind = "WebApp.GuardedMarkGatewayReported" Quit {"kind": (pKind), "path": "/probeseed/none"}
    If pKind = "WebApp.DeleteByPath" Quit {"kind": (pKind), "path": (..#SEEDPATH)}
    If (pKind = "Stamp.DeleteByProfile") || (pKind = "Version.DeleteByProfile") || (pKind = "Demo.DeleteByProfile") Quit {"kind": (pKind), "profile": (..#SEEDPROFILE)}
    If pKind = "Access.GuardedPut" Quit {"kind": (pKind), "screen": "probe.install.put", "pairs": "%Development:USE", "version": 0, "by": "self"}
    If pKind = "Access.GuardedRemove" Quit {"kind": (pKind), "screen": (..#REMOVESCREEN), "version": 1}
    Quit {"kind": (pKind)}
}

/// <p>The steps that save a row of <var>pStore</var> through <code>Base</code>'s two public saves: a new row,
/// then the seeded row opened, changed and saved.</p>
Method BaseSaves(pStore As %String) As %DynamicArray
{
    Set tSteps = []
    For tVia = "save", "current" {
        Do tSteps.%Push({"kind": "Base.SaveNew", "store": (pStore), "via": (tVia)})
        Do tSteps.%Push({"kind": "Base.SaveOpened", "store": (pStore), "id": (..PreparedIds.%Get(pStore)), "via": (tVia)})
    }
    Quit tSteps
}

/// <p>Assert that every leg of <var>pRun</var> was refused <code>822</code>.</p>
Method AssertAllRefused(pRun As %DynamicObject, pWhat As %String)
{
    Set tLegs = $Select(pRun.%GetTypeOf("steps") = "array": pRun.%Get("steps"), 1: [])
    Do $$$AssertTrue(tLegs.%Size() > 0, pWhat _ ": the child answered its legs" _ $Select(pRun.%IsDefined("error"): ": " _ pRun.%Get("error"), 1: ""))
    For tI = 1:1:tLegs.%Size() {
        Set tLeg = tLegs.%Get(tI - 1)
        Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(pRun, tI), tLeg.%Get("kind") _ " ok=0 code=822", pWhat _ " leg " _ tI _ " is refused 822: " _ tLeg.%Get("text"))
    }
}

/// <p>Assert that <var>pRun</var> logged in as <var>pUser</var>.</p>
Method AssertPrincipal(pRun As %DynamicObject, pUser As %String, pHoldsAdmin As %Boolean)
{
    Do $$$AssertEquals(pRun.%Get("username") _ "|" _ pRun.%Get("holdsAdmin") _ "|" _ (pRun.%Get("roles") [ "%All"), pUser _ "|" _ pHoldsAdmin _ "|0", "the child runs as " _ pUser _ " with" _ $Select(pHoldsAdmin: "", 1: "out") _ " OcuPilotAdmin and without %All")
}

/// <p>A developer -- <code>%Development:USE</code>, no <code>OcuPilotAdmin</code> -- calls every writer of the
/// four install-owned stores and saves a new and an opened row of each through <code>Base</code>'s two public
/// saves. Each is refused <code>822</code> and every row reads as it did.</p>
/// <p>Mutation (Rule 19): <code>Parameter ADMINWRITE = 1</code> removed from
/// <class>OcuPilot.Kernel.State.WebApp</class> -> this and the provenance and roster tests go red; the
/// <code>AdminWriteRefused</code> line removed from one writer of <code>Stamp</code>, <code>Version</code> or
/// <code>Demo</code> -> that writer's leg goes red.</p>
Method TestADeveloperIsRefusedEveryInstallRecordWrite()
{
    Set tBefore = ..Fingerprint()
    Set tPlan = []
    For tStore = "WebApp", "Stamp", "Version", "Demo" {
        Set tSaves = ..BaseSaves(tStore)
        For tI = 0:1:tSaves.%Size() - 1 Do tPlan.%Push(tSaves.%Get(tI))
    }
    For tI = 1:1:$ListLength(..WriteKinds()) {
        Set tKind = $List(..WriteKinds(), tI)
        If $Extract(tKind, 1, 7) '= "Access." Do tPlan.%Push(..StepFor(tKind))
    }
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Do ..AssertAllRefused(tRun, "install records")
    Do $$$AssertEquals(..Fingerprint(), tBefore, "and the stores read as they did")
}

/// <p>A principal holding neither adjuster pair nor <code>OcuPilotAdmin</code> calls the three screen-access
/// writers with a valid set and saves a new and an opened row through <code>Base</code>'s public saves. Each is
/// refused <code>822</code> and the rows read as they did.</p>
/// <p>Mutation (Rule 19): <code>Access</code>'s caller check answers <code>$$$OK</code> -> the
/// <code>GuardedPut</code> and <code>GuardedRemove</code> legs go red; <code>Parameter ADMINWRITE = 1</code>
/// removed from <class>OcuPilot.Kernel.State.Access</class> -> the <code>Base</code> save legs go red.</p>
Method TestAPrincipalWithoutAnAdjusterPairIsRefusedEveryScreenAccessWrite()
{
    Set tBefore = ..Fingerprint()
    Set tPlan = []
    Set tSaves = ..BaseSaves("Access")
    For tI = 0:1:tSaves.%Size() - 1 Do tPlan.%Push(tSaves.%Get(tI))
    For tI = 1:1:$ListLength(..WriteKinds()) {
        Set tKind = $List(..WriteKinds(), tI)
        If $Extract(tKind, 1, 7) = "Access." Do tPlan.%Push(..StepFor(tKind))
    }
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#PLAINUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#PLAINUSER, 0)
    Do ..AssertAllRefused(tRun, "screen access without a pair")
    Do $$$AssertEquals(..Fingerprint(), tBefore, "and the stores read as they did")
}

/// <p>A developer, who holds an adjuster pair, is still refused what the screen-access port would refuse and
/// what only an administrator may do: an empty set, nine pairs, a malformed pair, a changer that is not itself,
/// <code>DeleteAllGuarded</code>, a save through <code>Base</code>, and a held row whose screen it changed in
/// memory. A resource name of the wrong shape and one pair named twice are refused as well. Each is refused
/// <code>822</code>, the rows read as they did, and no refused put records a security-change row.</p>
/// <p>Mutation (Rule 19): the set check skipped -> the empty, nine-pair and malformed legs go red; the changer
/// check removed -> the forged-changer leg goes red; the held-screen check removed -> the held-row leg goes red;
/// the resource-pattern clause or the duplicate clause removed from <code>SetRefused</code> -> that leg goes red;
/// the store's audit made unconditional in <code>GuardedPut</code> -> the audit assertion goes red.</p>
Method TestAnAdjusterIsRefusedWhatThePortWouldRefuse()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tBefore = ..Fingerprint()
    Set tNine = ""
    For tI = 1:1:9 Set tNine = tNine _ $Select(tNine = "": "", 1: ",") _ "%Admin_Secure:USE"
    Set tPlan = []
    Do tPlan.%Push({"kind": "Access.GuardedPut", "screen": "probe.install.empty", "pairs": "", "version": 0, "by": "self"})
    Do tPlan.%Push({"kind": "Access.GuardedPut", "screen": "probe.install.nine", "pairs": (tNine), "version": 0, "by": "self"})
    Do tPlan.%Push({"kind": "Access.GuardedPut", "screen": "probe.install.malformed", "pairs": "nocolon", "version": 0, "by": "self"})
    Do tPlan.%Push({"kind": "Access.GuardedPut", "screen": "probe.install.bogus", "pairs": "%Admin_Secure:BOGUS", "version": 0, "by": "self"})
    Do tPlan.%Push({"kind": "Access.GuardedPut", "screen": "probe.install.badname", "pairs": "bad name:USE", "version": 0, "by": "self"})
    Do tPlan.%Push({"kind": "Access.GuardedPut", "screen": "probe.install.twice", "pairs": "%Admin_Secure:USE,%admin_secure:USE", "version": 0, "by": "self"})
    Do tPlan.%Push({"kind": "Access.GuardedPut", "screen": "probe.install.forged", "pairs": "%Admin_Secure:USE", "version": 0, "by": (..#ADMINUSER)})
    Do tPlan.%Push({"kind": "Access.GuardedPut", "screen": (..#SEEDSCREEN), "pairs": "%Admin_Secure:USE,%Development:USE", "version": 1, "by": (..#ADMINUSER)})
    Do tPlan.%Push({"kind": "Access.HeldRename", "id": (..PreparedIds.%Get("Access")), "heldScreen": "probe.install.renamed", "screen": (..#SEEDSCREEN), "pairs": "%Admin_Secure:USE,%Development:USE", "version": 1})
    Set tSaves = ..BaseSaves("Access")
    For tI = 0:1:tSaves.%Size() - 1 Do tPlan.%Push(tSaves.%Get(tI))
    Do tPlan.%Push({"kind": "Access.DeleteAllGuarded"})
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Do ..AssertAllRefused(tRun, "an adjuster's refused write")
    Do $$$AssertEquals(..Fingerprint(), tBefore, "and the stores read as they did")
    For tScreen = "probe.install.empty", "probe.install.nine", "probe.install.malformed", "probe.install.bogus", "probe.install.badname", "probe.install.twice", "probe.install.forged", ..#SEEDSCREEN {
        Set tRows = ##class(OcuPilot.Test.AuditEvent).RowsCarrying(tSince, ##class(OcuPilot.Kernel.Audit.Event).EventNameFor(1), ##class(OcuPilot.Test.AuditRecord).IdMarker(tScreen), .tData, """actor"":""" _ ..#DEVUSER _ """")
        Do $$$AssertEquals(tRows, 0, tScreen _ ": a refused put records no security-change row by the developer")
    }
}

/// <p>The developer and the security principal store a valid set through <code>GuardedPut</code> and remove
/// it, as the port's callers do. Each accepted write is one <code>SecurityChange</code> row naming the writer, the
/// pairs before and after, and the verb: <code>updated</code> for a put, <code>reset</code> for a remove.</p>
/// <p>A put and a remove refused as stale record nothing, and an update records the stored set as the set before,
/// whatever before-set the caller sends.</p>
/// <p>Mutation (Rule 19): the store's audit call removed -> the audit legs go red with
/// <class>OcuPilot.Test.ScreenAccessWire</class>; the port made to audit as well -> this stays green and
/// <method>OcuPilot.Test.ScreenAccessWire.TestEachAcceptedWriteIsOneSecurityChangeRow</method> goes red on two
/// rows; <code>GuardedRemove</code>'s audit moved above its stale check -> the reset count goes red; the update's
/// read of the stored set removed from <code>GuardedPut</code> -> the before-set assertion goes red.</p>
Method TestAnAdjusterStoresAndTheStoreAuditsOnce()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    For tUser = ..#DEVUSER, ..#SECUSER {
        Set tScreen = "probe.install.audit." _ $ZConvert($Extract(tUser, *-2, *), "L")
        Set tPlan = []
        Do tPlan.%Push({"kind": "Access.GuardedPut", "screen": (tScreen), "pairs": "%Admin_Secure:USE", "version": 0, "by": "self"})
        Do tPlan.%Push({"kind": "Access.GuardedRemove", "screen": (tScreen), "version": 1})
        Do tPlan.%Push({"kind": "Access.GuardedPut", "screen": (tScreen), "pairs": "%Admin_Secure:USE", "version": 7, "by": "self"})
        Do tPlan.%Push({"kind": "Access.GuardedRemove", "screen": (tScreen), "version": 1})
        Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(tUser, tPlan, ..#PROBE)
        Do ..AssertPrincipal(tRun, tUser, 0)
        Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "Access.GuardedPut ok=1 code=", tUser _ ": a valid set is stored")
        Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 2), "Access.GuardedRemove ok=1 code=", tUser _ ": and removed")
        Do $$$AssertEquals(+##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 3).%Get("ok") _ "|" _ +##class(OcuPilot.Test.AdminStateWrite).Leg(tRun, 4).%Get("ok"), "0|0", tUser _ ": a put and a remove of a version the row no longer carries are refused")
        Set tData = ##class(OcuPilot.Test.AuditRecord).RowFor(tSince, 1, tScreen, "updated", .tRows)
        Do $$$AssertEquals(tRows, 1, tUser _ ": the put is one security-change row")
        If tRows = 1 {
            Set tRow = ##class(%DynamicAbstractObject).%FromJSON(tData)
            Do $$$AssertEquals(tRow.actor _ "|" _ tRow.target.type _ "|" _ tRow.changes.pairs.new, tUser _ "|screen-permission|%Admin_Secure:USE", tUser _ ": naming the writer, the screen-permission and the stored set")
        }
        Do ##class(OcuPilot.Test.AuditRecord).RowFor(tSince, 1, tScreen, "reset", .tRows)
        Do $$$AssertEquals(tRows, 1, tUser _ ": the remove is one security-change row, and the stale legs record none")
    }
    Set tScreen = "probe.install.audit.update"
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "INSERT INTO OcuPilot_Kernel_State.ScreenAccess (Screen, Pairs, ChangedBy, ChangedAt, RowVersion) VALUES (?, '%Admin_Secure:USE', 'seed', '1990-01-01T00:00:00Z', 1)", tScreen)
    Do $$$AssertEquals(tRS.%ROWCOUNT, 1, "a stored adjustment is seeded without an audit row")
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, [{"kind": "Access.GuardedPut", "screen": (tScreen), "pairs": "%Admin_Secure:USE,%Development:USE", "version": 1, "by": "self", "declared": "%Forged:USE"}], ..#PROBE)
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "Access.GuardedPut ok=1 code=", "the developer updates it, sending a before-set of its own: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, 1))
    Set tData = ##class(OcuPilot.Test.AuditRecord).RowFor(tSince, 1, tScreen, "updated", .tRows)
    Do $$$AssertEquals(tRows, 1, "the update is one security-change row")
    If tRows = 1 {
        Set tRow = ##class(%DynamicAbstractObject).%FromJSON(tData)
        Do $$$AssertEquals(tRow.changes.pairs.old _ "|" _ tRow.changes.pairs.new, "%Admin_Secure:USE|%Admin_Secure:USE,%Development:USE", "naming the stored set as the set before, not the caller's")
    }
}

/// <p>The developer writes nothing into the protected database through <code>Base.GuardedProbeSet</code>, called on
/// <code>Base</code> or inherited by a store; each call is refused <code>822</code> and the node stays unset. An
/// administrator who holds <code>OcuPilotAdmin:USE</code> and not <code>%All</code> writes it.</p>
/// <p>Mutation (Rule 19): the caller check removed from <method>OcuPilot.Kernel.State.Base.GuardedProbeSet</method>
/// -> the developer's legs land and this goes red.</p>
Method TestOnlyAnAdministratorWritesTheProbeGlobal()
{
    Set tPlan = [{"kind": "Base.GuardedProbeSet", "class": "OcuPilot.Kernel.State.Base", "key": (..#PROBEKEY), "value": "developer"}, {"kind": "Base.GuardedProbeSet", "class": "OcuPilot.Kernel.State.WebApp", "key": (..#PROBEKEY), "value": "developer"}]
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
    Do ..AssertAllRefused(tRun, "the developer's probe-global write")
    Do $$$AssertEquals($Data(^OcuPilotKernelStateProbe(..#PROBEKEY)), 0, "and the node stays unset")
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#ADMINUSER, [{"kind": "Base.GuardedProbeSet", "class": "OcuPilot.Kernel.State.Base", "key": (..#PROBEKEY), "value": "administrator"}], ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#ADMINUSER, 1)
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "Base.GuardedProbeSet ok=1 code=", "the administrator's write is accepted: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, 1))
    Do $$$AssertEquals($Get(^OcuPilotKernelStateProbe(..#PROBEKEY)), "administrator", "and lands")
}

/// <p>A developer opens the seeded screen-access row, changes its screen in memory to another and holds it across
/// <code>GuardedPut</code> for the original screen. The store refuses it, so no row is renamed and no screen's set
/// is rewritten by a held copy. Covered with the adjuster's other refusals in
/// <method>TestAnAdjusterIsRefusedWhatThePortWouldRefuse</method>; this leg alone proves the store holds the row it
/// stored, not the one in the caller's hands.</p>
/// <p>Mutation (Rule 19): the held-screen comparison removed from <code>Access.GuardedPut</code> -> this goes
/// red alone.</p>
Method TestAHeldScreenAccessRowCannotBeRenamed()
{
    Set tBefore = ..Fingerprint()
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, [{"kind": "Access.HeldRename", "id": (..PreparedIds.%Get("Access")), "heldScreen": "probe.install.renamed", "screen": (..#SEEDSCREEN), "pairs": "%Admin_Secure:USE,%Development:USE", "version": 1}], ..#PROBE)
    Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "Access.HeldRename ok=0 code=822", "the held row is refused: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, 1))
    Do $$$AssertEquals(..Fingerprint(), tBefore, "and the stored row keeps its screen and its set")
}

/// <p>An administrator who holds <code>OcuPilotAdmin:USE</code> and not <code>%All</code> writes every install
/// record and screen-access row the developer is refused, and saves rows of all five stores through
/// <code>Base</code>'s public saves.</p>
/// <p>Mutation (Rule 19): <code>Base.CallerIsAdministrator</code> answers 0 -> this goes red.</p>
Method TestAnAdministratorWritesTheInstallRecords()
{
    Set tPlan = []
    Do tPlan.%Push({"kind": "WebApp.GuardedRecord", "profile": (..#SEEDPROFILE), "path": "/probeseed/other", "origin": "created"})
    Do tPlan.%Push({"kind": "WebApp.GuardedMarkGatewayReported", "path": "/probeseed/other"})
    Do tPlan.%Push({"kind": "WebApp.DeleteByPath", "path": "/probeseed/other"})
    Do tPlan.%Push({"kind": "Stamp.GuardedSweep"})
    For tStore = "WebApp", "Stamp", "Version", "Demo", "Access" {
        Set tSaves = ..BaseSaves(tStore)
        For tI = 0:1:tSaves.%Size() - 1 Do tPlan.%Push(tSaves.%Get(tI))
    }
    Do tPlan.%Push({"kind": "Access.GuardedPut", "screen": "probe.install.admin", "pairs": "%Admin_Secure:USE,%Development:USE", "version": 0, "by": "self"})
    Do tPlan.%Push({"kind": "Access.GuardedRemove", "screen": "probe.install.admin", "version": 1})
    Do tPlan.%Push({"kind": "Demo.DeleteByProfile", "profile": (..#SEEDPROFILE)})
    Do tPlan.%Push({"kind": "Version.DeleteByProfile", "profile": (..#SEEDPROFILE)})
    Do tPlan.%Push({"kind": "Stamp.DeleteByProfile", "profile": (..#SEEDPROFILE)})
    Do tPlan.%Push({"kind": "Access.DeleteAllGuarded"})
    Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#ADMINUSER, tPlan, ..#PROBE)
    Do ..AssertPrincipal(tRun, ..#ADMINUSER, 1)
    Set tLegs = $Select(tRun.%GetTypeOf("steps") = "array": tRun.%Get("steps"), 1: [])
    Do $$$AssertTrue(tLegs.%Size() > 0, "the child answered its legs" _ $Select(tRun.%IsDefined("error"): ": " _ tRun.%Get("error"), 1: ""))
    For tI = 1:1:tLegs.%Size() {
        Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, tI), tLegs.%Get(tI - 1).%Get("kind") _ " ok=1 code=", "the administrator's write " _ tI _ " is accepted: " _ tLegs.%Get(tI - 1).%Get("text"))
    }
    Do $$$AssertEquals(..Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.ScreenAccess"), 0, "the administrator's screen-access purge removed every row")
}

/// <p>A forged provenance row cannot steer an uninstall. The probe profile is installed, one of its applications
/// is replaced by one install did not create, and a developer writes the provenance row that would name it
/// as install's own. The write is refused, so the uninstall leaves the application where it is.</p>
/// <p>Mutation (Rule 19): <code>Parameter ADMINWRITE = 1</code> removed from
/// <class>OcuPilot.Kernel.State.WebApp</class> -> the write lands and the uninstall removes the application,
/// so this goes red.</p>
Method TestAForgedProvenanceRowDoesNotSteerAnUninstall()
{
    Set tPath = ##class(OcuPilot.Test.Provenance).#PROBEREADINESS
    Try {
        Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install(""), "production is installed")
        Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Install("probe"), "the probe profile is installed")
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.WebApp).DeleteByPath(tPath), "the record install wrote for one of its applications is removed")
        Do $$$AssertStatusOK(##class(OcuPilot.Test.Provenance).DeleteApplication(tPath), "and the application with it")
        Do $$$AssertStatusOK(##class(OcuPilot.Test.Provenance).CreateForeignApplication(tPath), "an application install did not create takes its path")
        Set tRun = ##class(OcuPilot.Test.AdminStateWrite).RunAs(..#DEVUSER, [{"kind": "WebApp.GuardedRecord", "profile": "probe", "path": (tPath), "origin": "created"}], ..#PROBE)
        Do ..AssertPrincipal(tRun, ..#DEVUSER, 0)
        Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).LegText(tRun, 1), "WebApp.GuardedRecord ok=0 code=822", "the developer's provenance row is refused: " _ ##class(OcuPilot.Test.AdminStateWrite).DetailOf(tRun, 1))
        Do $$$AssertEquals(..Stored("SELECT COUNT(*) FROM OcuPilot_Kernel_State.WebApp WHERE %EXACT(Path) = ?", tPath), 0, "so no row names the application")
        Do $$$AssertStatusOK(##class(OcuPilot.Install.Installer).Uninstall("probe", 1), "the probe uninstall completes")
        Do $$$AssertEquals(##class(OcuPilot.Test.Provenance).ApplicationDispatchClass(tPath), ##class(OcuPilot.Test.Provenance).#FOREIGNCLASS, "and leaves the application it has no record of")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the provenance steering test raised")
    }
    Do ##class(OcuPilot.Test.Provenance).DeleteApplication(tPath)
    Do ##class(OcuPilot.Install.Installer).Uninstall("probe", 1)
    Do ##class(OcuPilot.Test.ProbeApps).Remove()
}

/// <p>The stores that declare <code>ADMINWRITE</code> are the ten, and each of the five this class pins has public
/// class methods that are exactly its declared reads, refused writes and adjuster writes. Every write is a step the
/// probe runs, and the refusal tests build their plans from the same list. <code>Access</code>' adjuster pairs and its set
/// bound are the screen-access port's own (<code>Kernel/State</code> may not name them).</p>
/// <p>Mutation (Rule 19): a public method added to <code>Version</code> -> this goes red.</p>
Method TestTheInstallRecordStoresAreDeclared()
{
    Set tStores = ..Stores()
    Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT parent FROM %Dictionary.CompiledParameter WHERE Name = 'ADMINWRITE' AND _Default = '1' AND parent %STARTSWITH ? ORDER BY parent", ..#STOREPACKAGE)
    Set tFound = ""
    While tRS.%Next() {
        Set tFound = tFound _ $ListBuild(tRS.%GetData(1))
    }
    Do $$$AssertEquals($ListLength(tFound), 10, "ten stores declare ADMINWRITE")
    For tI = 1:1:$ListLength(tStores) {
        Set tStore = $List(tStores, tI)
        Set tClass = ..#STOREPACKAGE _ tStore
        Do $$$AssertTrue($ListFind(tFound, tClass) > 0, tStore _ " declares ADMINWRITE")
        Set tPublic = ""
        Set tMethods = ##class(%SQL.Statement).%ExecDirect(, "SELECT Name FROM %Dictionary.MethodDefinition WHERE parent = ? AND ClassMethod = 1 AND Private = 0", tClass)
        While tMethods.%Next() {
            Set tPublic = tPublic _ $ListBuild(tMethods.%GetData(1))
        }
        Do $$$AssertEquals(##class(OcuPilot.Test.AdminStateWrite).SortedJoin(tPublic), ##class(OcuPilot.Test.AdminStateWrite).SortedJoin(..Reads(tStore) _ ..Writes(tStore) _ ..AdjusterWrites(tStore)), tStore _ "'s public class methods are its declared reads, refused writes and adjuster writes")
    }
    Set tKinds = ..WriteKinds()
    For tI = 1:1:$ListLength(tKinds) {
        Do $$$AssertTrue($ClassMethod(..#PROBE, "Handles", $List(tKinds, tI)), $List(tKinds, tI) _ " is a write the probe calls")
    }
    Do $$$AssertEquals($Parameter(..#STOREPACKAGE _ "Access", "MAXPAIRS"), ##class(OcuPilot.Api.AccessError).#MAXPAIRS, "the store's pair bound is the port's")
    Do $$$AssertEquals($Parameter(..#STOREPACKAGE _ "Access", "WRITERPAIRS"), $Replace(##class(OcuPilot.Screen.Gate).#ADJUSTERRESOURCES, ",", ":USE,") _ ":USE", "the store's adjuster pairs are the port's gate")
    Do $$$AssertEquals($Parameter(..#STOREPACKAGE _ "Access", "PERMISSIONS"), ##class(OcuPilot.Port.ScreenAccessPort).#PERMISSIONS, "the store's permissions are the port's")
    Do $$$AssertEquals($Parameter(..#STOREPACKAGE _ "Access", "RESOURCEPATTERN"), ##class(OcuPilot.Port.ScreenAccessPort).#RESOURCEPATTERN, "the store's resource shape is the port's")
}

}
