/// <p>Pins DW-1784 (AD-44 as amended 2026-09-28, Story 18.14) against the instance's real
/// custom-resource store: a probe resource assigned to a classic page a namespace, mapping or
/// database write tool declares it performs (<parameter>OcuPilot.Screen.Tool.Write.CLASSICPAGES</parameter>) gates that
/// tool on the agent's caller and the screen's, refused 403 <code>AUTH.NOPRIVILEGE</code> naming
/// <code>&lt;resource&gt;:USE</code> with no port call, while a principal also holding the resource is
/// admitted and its write reaches the port; with no assignment each tool's pairs are its declared
/// set.</p>
/// <p><b>This is the one test that writes the store</b> (<method>OcuPilot.Screen.Gate.ClassicResource</method>),
/// and only on a throwaway: it records every declared page's custom resource before all tests and
/// restores each after every test and after all, and a page that does not read its recorded value
/// afterwards fails the class. The child-process legs run as real principals through
/// <class>OcuPilot.Test.NamespaceWriteGateProbe</class>,
/// <class>OcuPilot.Test.MappingWriteGateProbe</class> and, for SQL query's background run in
/// <code>USER</code>, <method>OcuPilot.Test.SqlBackgroundJob.StartAs</method>.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and both
/// <parameter>ARMINGVARIABLE</parameter> and <parameter>NAMESPACEVARIABLE</parameter> reading
/// <code>1</code>, because the class assigns custom resources to classic pages, creates and deletes a
/// resource, two users, two roles, probe namespaces and a mapping, and sets the governance policy.
/// <method>OnBeforeAllTests</method> refuses anywhere either does not.</p>
Class OcuPilot.Test.ClassicPageGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the principals, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The environment variable that arms the namespace and mapping writes and the classic-page
/// assignments, set there alone too.</p>
Parameter NAMESPACEVARIABLE = "OCUPILOT_ALLOW_NAMESPACE_CONFIG";

/// <p>The probe resource assigned to the classic pages.</p>
Parameter RESOURCE = "OcuProbe1814Page";

/// <p>The principal holding every pair the declaring tools declare but the probe resource, and the
/// one holding those and the probe resource.</p>
Parameter LACKINGUSER = "OcuProbe1814PageLacking";

Parameter HOLDINGUSER = "OcuProbe1814PageHolding";

Parameter NSPROBE = "OcuPilot.Test.NamespaceWriteProbe";

Parameter MAPPINGPROBE = "OcuPilot.Test.MappingProbe";

Parameter NSGATE = "OcuPilot.Test.NamespaceWriteGate";

Parameter MAPPINGGATE = "OcuPilot.Test.MappingWriteGate";

Parameter DELETEKEY = "osmgmt.namespaces.delete";

/// <p>The agent's database delete key, which the baseline disables too (Story 18.3).</p>
Parameter DATABASEDELETEKEY = "osmgmt.localdatabases.delete";

/// <p>Story 18.4's disk operation keys that declare a classic page, which the baseline disables too.</p>
Parameter DISKKEYS = "osmgmt.databasedetails.mount,osmgmt.databasedetails.truncate,osmgmt.databasedetails.compact,osmgmt.databasedetails.defragment,osmgmt.databases.integrity,osmgmt.localdatabases.grow,osmgmt.localdatabases.expand";

/// <p>The agent's task import key, which the baseline disables too.</p>
Parameter TASKIMPORTKEY = "tasks.schedule.import";

/// <p>The agent's enable-interop key, which the baseline disables too (Story 18.15).</p>
Parameter ENABLEINTEROPKEY = "osmgmt.namespaces.enableinterop";

/// <p>The agent's remote database delete key, which the baseline disables too (Story 18.16).</p>
Parameter REMOTEDELETEKEY = "osmgmt.remotedatabases.delete";

/// <p>The tool whose first own pair is <code>%All:USE</code>: a holder of the <code>%All</code> role
/// holds every custom resource, so its page's resource is never the pair that fails, and its legs
/// assert the <code>%All:USE</code> refusal instead (AD-8 as amended 2026-10-01).</p>
Parameter ALLTOOL = "osmgmt.namespaces.enableinterop";

/// <p>The pairs each declaring tool declares beyond its list's own, as <code>tool=pair|pair</code>
/// entries: its declared set, with no classic page assigned. The declaring tools are exactly these,
/// and the database file edit, the truncate, the service update and the two document exports declare
/// none of their own; Story 18.4's dismount, whose classic page performs it itself, declares no
/// page.</p>
Parameter OWNPAIRS = "osmgmt.localdatabases.create=%DB_IRISSYS:WRITE|%Admin_Secure:USE|%Admin_FileSystemAccess:USE,osmgmt.localdatabases.updatemount=%DB_IRISSYS:WRITE,osmgmt.localdatabases.update=,osmgmt.localdatabases.delete=%DB_IRISSYS:WRITE,osmgmt.namespaces.create=%DB_IRISSYS:WRITE,osmgmt.namespaces.update=%DB_IRISSYS:WRITE,osmgmt.namespaces.delete=%DB_IRISSYS:WRITE|%Admin_Secure:USE,osmgmt.namespaces.copymappings=%Admin_Operate:USE|%DB_IRISSYS:WRITE,osmgmt.globalmappings.create=%DB_IRISSYS:WRITE,osmgmt.globalmappings.update=%DB_IRISSYS:WRITE,osmgmt.routinemappings.create=%DB_IRISSYS:WRITE,osmgmt.routinemappings.update=%DB_IRISSYS:WRITE,osmgmt.packagemappings.create=%DB_IRISSYS:WRITE,osmgmt.packagemappings.update=%DB_IRISSYS:WRITE,osmgmt.databasedetails.mount=%Admin_Secure:USE,osmgmt.databasedetails.truncate=,osmgmt.databasedetails.compact=%DB_IRISSYS:WRITE,osmgmt.databasedetails.defragment=%DB_IRISSYS:WRITE,osmgmt.databases.integrity=%Admin_Operate:USE|%DB_IRISSYS:WRITE,osmgmt.localdatabases.grow=%Admin_Operate:USE,osmgmt.localdatabases.expand=%Admin_Operate:USE,tasks.schedule.export=%Admin_FileSystemAccess:USE,tasks.schedule.import=%Admin_FileSystemAccess:USE,osmgmt.languageservers.start=%Admin_ExternalLanguageServerEdit:USE,osmgmt.languageservers.stop=%Admin_ExternalLanguageServerEdit:USE,osmgmt.languageservers.create=%DB_IRISSYS:WRITE|%Admin_Manage:USE,osmgmt.languageservers.update=%DB_IRISSYS:WRITE|%Admin_Manage:USE,osmgmt.locks.remove=%DB_IRISSYS:WRITE,osmgmt.locks.removeprocess=%DB_IRISSYS:WRITE,osmgmt.locks.removeclient=%DB_IRISSYS:WRITE,permissions.services.update=,security.ldap.update=,security.ldap.create=,security.ldap.password=,osmgmt.namespaces.enableinterop=%All:USE|%Admin_Operate:USE,explorer.classes.compile=%DB_HSCUSTOM:WRITE,explorer.routines.compile=%DB_HSCUSTOM:WRITE,osmgmt.remotedatabases.create=%DB_IRISSYS:WRITE,osmgmt.remotedatabases.update=%DB_IRISSYS:WRITE,osmgmt.remotedatabases.delete=%DB_IRISSYS:WRITE,explorer.classes.export=,explorer.routines.export=,explorer.classes.import=%DB_HSCUSTOM:WRITE,explorer.routines.import=%DB_HSCUSTOM:WRITE,interop.productions.recover=%Ens_ProductionRun:USE|%DB_HSCUSTOM:WRITE,interop.productions.restart=%Ens_ProductionRun:USE|%DB_HSCUSTOM:WRITE,interop.productions.start=%Ens_ProductionRun:USE|%DB_HSCUSTOM:WRITE,interop.productions.stop=%Ens_ProductionRun:USE|%DB_HSCUSTOM:WRITE,interop.productions.update=%Ens_ProductionRun:USE|%DB_HSCUSTOM:WRITE,osmgmt.journals.switchfile=,osmgmt.journals.switchdirectory=%DB_IRISSYS:WRITE|%Admin_Manage:USE,osmgmt.journals.integrity=,osmgmt.licensekey.activate=,osmgmt.ecpdataservers.create=%DB_IRISSYS:WRITE,osmgmt.ecpdataservers.update=%DB_IRISSYS:WRITE,osmgmt.ecpdataservers.changestatus=%Admin_Operate:USE,security.encryptionkeyfile.create=,security.encryptionkeyfileadmins.addadministrator=,security.encryptionkeyfile.addkey=,security.superservers.create=,security.superservers.update=,security.mftconnections.create=,security.mftconnections.update=,permissions.users.copy=,permissions.users.grantsql=,permissions.users.revokesql=,permissions.roles.grantsql=,permissions.roles.revokesql=,webapp.pctaccess.create=";

/// <p>The agent's document import keys, which the baseline disables too (Story 19.13).</p>
Parameter EXPLORERIMPORTKEYS = "explorer.classes.import,explorer.routines.import";

/// <p>The agent's ECP data server status change key, which the baseline disables too (Story 18.20).</p>
Parameter ECPSTATUSKEY = "osmgmt.ecpdataservers.changestatus";

/// <p>Story 18.7's key file create and administrator and key adds, which declare a classic page and
/// which the baseline disables too.</p>
Parameter ENCRYPTIONKEYS = "security.encryptionkeyfile.create,security.encryptionkeyfileadmins.addadministrator,security.encryptionkeyfile.addkey";

/// <p>The throwaway principals' password, generated for the run.</p>
Property PreparedPassword As %String;

/// <p>Each declared page's custom resource as it stood before the class ran, keyed by page.</p>
Property PreparedPages [ MultiDimensional ];

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#NAMESPACEVARIABLE) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ClassicPageGate assigns custom resources to classic portal pages and creates and deletes users, roles, a resource, namespaces and mappings on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#NAMESPACEVARIABLE _ " must both read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets them.")
    }
    Set tSC = ..Roster(.tRoster)
    If $$$ISERR(tSC) Quit tSC
    Set tPage = ""
    For {
        Set tPage = $Order(tRoster(tPage))
        If tPage = "" Quit
        Set ..PreparedPages(tPage) = ##class(%CSP.Portal.Utils).%GetCustomResource($ZConvert(tPage, "O", "URL"))
    }
    Set ..PreparedPassword = "OcuProbe1814Page" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set tSC = ..RemoveProbes()
    If $$$ISERR(tSC) Quit tSC
    Quit ..EnsurePrincipals()
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertStatusOK(..RestorePages(), "every classic page reads its recorded custom resource again")
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK(..RemoveProbes(), "every probe namespace is removed by exact name")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

/// <p>Restore every page and the policy and remove every probe object; a failing status when a page
/// does not read its recorded value or anything survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = ..RestorePages()
    Merge tRows = ..PreparedPolicy
    Set tSC = $$$ADDSC(tSC, ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows))
    Set tSC = $$$ADDSC(tSC, ..RemoveProbes())
    Set tSC = $$$ADDSC(tSC, ..RemovePrincipals())
    Quit tSC
}

/// <p>With no page assigned, each declaring tool's pairs are its declared set: its list's pairs and
/// its own, with no probe resource among them.</p>
Method TestWithNoAssignmentEachToolsPairsAreItsDeclaredSet()
{
    Set tSC = ..Roster(.tRoster, .tTools)
    Do $$$AssertStatusOK(tSC, "the declaring tools are read from the registry")
    Do $$$AssertEquals($ListToString(tTools), $ListToString(..Declared()), "the tools declaring a replaced classic page are the sixty-nine OWNPAIRS names")
    For tI = 1:1:$ListLength(tTools) {
        Set tName = $List(tTools, tI)
        Kill tTool
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(tName, .tTool, 1)
        Do $$$AssertStatusOK(tSC, tName _ ": resolves in the registry")
        If '$IsObject($Get(tTool)) Continue
        Set tPairs = ##class(OcuPilot.Screen.Tool.Registry).RequiredPairs(tTool, .tResolved)
        Set tDeclared = ##class(OcuPilot.Screen.Gate).RequiredPairs($Parameter(tTool.class, "DESCRIPTORCLASS"), .tDeclaredResolved)
        Set tOwn = ""
        For tJ = 1:1:$Length(..#OWNPAIRS, ",") {
            If $Piece($Piece(..#OWNPAIRS, ",", tJ), "=", 1) = tName Set tOwn = $Piece($Piece(..#OWNPAIRS, ",", tJ), "=", 2)
        }
        For tJ = 1:1:$Length(tOwn, "|") {
            If $Piece(tOwn, "|", tJ) = "" Continue
            Set tPair = $ListFromString($Piece(tOwn, "|", tJ), ":")
            If '$ListFind(tDeclared, tPair) Set tDeclared = tDeclared _ $ListBuild(tPair)
        }
        ; An operator's own assignment, recorded before the class ran, is part of the declared set.
        Set tPages = $Parameter(tTool.class, "CLASSICPAGES")
        For tJ = 1:1:$Length(tPages, ",") {
            Set tRecorded = $Get(..PreparedPages($ZStrip($Piece(tPages, ",", tJ), "<>W")))
            If tRecorded = "" Continue
            Set tPair = $ListBuild(tRecorded, "USE")
            If '$ListFind(tDeclared, tPair) Set tDeclared = tDeclared _ $ListBuild(tPair)
        }
        Do $$$AssertTrue(tResolved && tDeclaredResolved && (tPairs = tDeclared), tName _ ": its pairs are its declared set")
        Do $$$AssertEquals(..Names(tPairs) [ ..#RESOURCE, 0, tName _ ": naming no probe resource")
    }
}

/// <p>The arguments the probe sends a tool. Every tool takes none but a copy, whose input schema requires a
/// name and a source, so the copy names <code>_SYSTEM</code>, a local account every instance holds (Story 18.29).</p>
ClassMethod AgentInput(pTool As %String) As %DynamicObject
{
    If pTool = $Parameter("OcuPilot.Screen.Tool.UserCopy", "TOOLNAME") Quit {"Name": "OcuProbeGate", "CopyFrom": "_SYSTEM"}
    Quit {}
}

/// <p>With the probe resource assigned to every declared page, each declaring tool's call on the
/// agent's caller is refused 403 <code>AUTH.NOPRIVILEGE</code> naming <code>OcuProbe1814Page:USE</code>
/// for the principal lacking it, before its arguments are read; the principal holding it passes that
/// gate. The legs are the declared roster's, so a tool that stops declaring its page is admitted for
/// the lacking principal and its leg goes red. A namespace create minted for each is refused at the
/// lacking principal's confirm naming the pair with no port call, and applied at the holding
/// principal's, reaching the port.</p>
/// <p><parameter>ALLTOOL</parameter> is refused naming <code>%All:USE</code> for both principals, which
/// hold every declared pair but not the <code>%All</code> role.</p>
/// <p>Its pairs are read directly to carry the assigned page's resource, which neither refusal can
/// show (AD-44). Mutation (Rule 19): its <method>PrivilegePairs</method> skips
/// <method>OcuPilot.Screen.Gate.WithClassicPages</method> -> that read goes red.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Gate.WithClassicPages</method> answers
/// <var>pPairs</var> unchanged -> the lacking principal is admitted and this goes red.</p>
Method TestAnAssignedPageGatesEveryDeclaringToolOnTheAgentsCaller()
{
    Do $$$AssertStatusOK(..EnableDelete(), "the agent's namespace and database delete keys and its task import key are enabled, so only the pairs stand in the way")
    Set tSC = ..Roster(.tRoster)
    Set tTools = ..Declared()
    Do $$$AssertStatusOK(..Assign(.tRoster), "the probe resource is assigned to every declared page")
    Kill tAllTool
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(..#ALLTOOL, .tAllTool, 1)
    Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tAllTool)) && $ListFind(##class(OcuPilot.Screen.Tool.Registry).RequiredPairs(tAllTool, .tAllResolved), $ListBuild(..#RESOURCE, "USE")), ..#ALLTOOL _ ": its pairs carry the assigned page's resource, though %All:USE fails first for every principal here")
    For tUser = ..#LACKINGUSER, ..#HOLDINGUSER {
        Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(tUser, "running", .tTurnKey)
        Do $$$AssertStatusOK(tSC, tUser _ ": a running turn is seeded")
        Set tPlan = []
        For tI = 1:1:$ListLength(tTools) {
            Do tPlan.%Push({"kind": "dispatch", "turnKey": (tTurnKey), "tool": ($List(tTools, tI)), "input": (..AgentInput($List(tTools, tI)))})
        }
        Set tRun = ##class(OcuPilot.Test.MappingWriteGate).RunAs(tUser, tPlan)
        Set tRan = ##class(OcuPilot.Test.NamespaceWriteGate).Ran(tRun)
        Do $$$AssertEquals(tRan, tUser _ " 1", tUser _ ": the child process ran as the principal (it answered: " _ tRan _ ")")
        For tI = 1:1:$ListLength(tTools) {
            Set tLeg = ##class(OcuPilot.Test.NamespaceWriteGate).Leg(tRun, tI)
            Set tSaid = $Select($IsObject(tLeg): tLeg.%Get("http") _ " " _ tLeg.%Get("code") _ " " _ tLeg.%Get("failedPair"), 1: "absent")
            ; Story 18.6: an unadvertised tool is no agent tool at all (AD-53), so its call is refused as
            ; unknown whoever makes it; its page's resource is in its pairs, which the screen's caller asks.
            Kill tListedTool
            Do ##class(OcuPilot.Screen.Tool.Registry).Resolve($List(tTools, tI), .tListedTool, 1)
            If $IsObject($Get(tListedTool)) && '$ClassMethod(tListedTool.class, "Advertised") {
                Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("code"), 1: ""), ##class(OcuPilot.Api.Error).#TOOLUNKNOWN, $List(tTools, tI) _ ": " _ tUser _ "'s call of an unadvertised tool is refused as unknown (" _ tSaid _ ")")
                Do $$$AssertTrue($ListFind(##class(OcuPilot.Screen.Tool.Registry).RequiredPairs(tListedTool, .tListedResolved), $ListBuild(..#RESOURCE, "USE")), $List(tTools, tI) _ ": while its pairs carry the assigned page's resource")
                Continue
            }
            If $List(tTools, tI) = ..#ALLTOOL {
                Do $$$AssertEquals(tSaid, "403 AUTH.NOPRIVILEGE %All:USE", $List(tTools, tI) _ ": " _ tUser _ "'s call is refused naming %All:USE")
                Continue
            }
            If tUser = ..#LACKINGUSER {
                Do $$$AssertEquals(tSaid, "403 AUTH.NOPRIVILEGE " _ ..#RESOURCE _ ":USE", $List(tTools, tI) _ ": the lacking principal's call is refused naming the page's resource (" _ tSaid _ ")")
            } Else {
                Do $$$AssertTrue($IsObject(tLeg) && (tLeg.%Get("failedPair") = "") && (tLeg.%Get("code") '= "AUTH.NOPRIVILEGE"), $List(tTools, tI) _ ": the holding principal passes the pair gate (" _ tSaid _ ")")
            }
        }
        Do $$$AssertStatusOK(##class(OcuPilot.Kernel.State.Ledger).GuardedDeleteForTurn(tTurnKey), tUser _ ": this class removes the ledger rows its calls wrote")
    }
    For tCase = $ListBuild(..#LACKINGUSER, "OCUPROBE182CPL", "403 AUTH.NOPRIVILEGE " _ ..#RESOURCE _ ":USE calls=0 types="), $ListBuild(..#HOLDINGUSER, "OCUPROBE182CPH", "") {
        Set tUser = $List(tCase, 1)
        Set tName = $List(tCase, 2)
        Set tSC = ..MintFor(tUser, tName, .tProposal)
        Do $$$AssertStatusOK(tSC, tUser _ ": a namespace create is minted for the principal")
        If '$IsObject($Get(tProposal)) Continue
        Set tRun = ##class(OcuPilot.Test.NamespaceWriteGate).RunAs(tUser, [{"kind": "confirm", "proposalId": (tProposal.%Get("proposalId"))}])
        If $List(tCase, 3) '= "" {
            Do $$$AssertEquals(##class(OcuPilot.Test.NamespaceWriteGate).LegText(tRun, 1), $List(tCase, 3), tUser _ ": the confirm is refused naming the page's resource, the port asked nothing")
            Do $$$AssertEquals($ClassMethod(..#NSPROBE, "Holds", tName), 0, tUser _ ": and nothing is created")
        } Else {
            Set tLeg = ##class(OcuPilot.Test.NamespaceWriteGate).Leg(tRun, 1)
            Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http"), 1: ""), 200, tUser _ ": the confirm is applied (" _ ##class(OcuPilot.Test.NamespaceWriteGate).LegText(tRun, 1) _ ")")
            Do $$$AssertTrue($IsObject(tLeg) && $ListFind($ListFromString(tLeg.%Get("types")), "PUT"), tUser _ ": its write reaches the port")
            Do $$$AssertEquals($ClassMethod(..#NSPROBE, "Holds", tName), 1, tUser _ ": and the namespace is created")
        }
    }
}

/// <p>With the probe resource assigned to the one page each tool declares, the namespace create's
/// Save, the namespace delete's row action and the global mapping create's Save are refused 403
/// <code>AUTH.NOPRIVILEGE</code> naming <code>OcuProbe1814Page:USE</code> for the lacking principal
/// with no port call; for the holding principal each is admitted and its write reaches the port. One
/// page at a time, so the form's own classic page stays unassigned and the refusal is the tool's.</p>
/// <p>Mutation (Rule 19): empty <parameter>OcuPilot.Screen.Tool.NamespaceCreate.CLASSICPAGES</parameter>
/// -> the lacking principal's create Save is admitted and this goes red on that leg.</p>
Method TestAnAssignedPageGatesTheScreensCaller()
{
    Do $$$AssertStatusOK($ClassMethod(..#MAPPINGPROBE, "Add", "OCUPROBE1814A"), "a probe namespace for the mapping is created")
    Set tLegs = $ListBuild($ListBuild("the namespace create's Save", "%CSP.UI.Portal.Namespace", 201, "PUT"), $ListBuild("the namespace delete's row action", "%CSP.UI.Portal.Dialog.NamespaceDelete", 200, "DELETE"), $ListBuild("the global mapping create's Save", "%CSP.UI.Portal.Mappings.Global", 201, "PUT"))
    For tCase = $ListBuild(..#LACKINGUSER, "L"), $ListBuild(..#HOLDINGUSER, "H") {
        Set tUser = $List(tCase, 1)
        Set tSuffix = $List(tCase, 2)
        Set tDelete = "OCUPROBE182CPD" _ tSuffix
        Do $$$AssertStatusOK($ClassMethod(..#NSPROBE, "Add", tDelete), tUser _ ": a namespace to delete is created")
        For tI = 1:1:$ListLength(tLegs) {
            Set tLegCase = $List(tLegs, tI)
            Kill tOne
            Set tOne($List(tLegCase, 2)) = ""
            Do $$$AssertStatusOK(..RestorePages(), $List(tLegCase, 1) _ ": every page reads its recorded resource first")
            Do $$$AssertStatusOK(..Assign(.tOne), $List(tLegCase, 1) _ ": the probe resource is assigned to " _ $List(tLegCase, 2) _ " alone")
            If tI = 1 {
                Set tRun = ##class(OcuPilot.Test.NamespaceWriteGate).RunAs(tUser, [{"kind": "create", "name": ("OCUPROBE182CPS" _ tSuffix), "body": {"Name": ("OCUPROBE182CPS" _ tSuffix), "Globals": "USER", "Routines": "USER"}}])
            } ElseIf tI = 2 {
                Set tRun = ##class(OcuPilot.Test.NamespaceWriteGate).RunAs(tUser, [{"kind": "delete", "name": (tDelete)}])
            } Else {
                Set tRun = ##class(OcuPilot.Test.MappingWriteGate).RunAs(tUser, [{"kind": "create", "mappingKind": "global", "body": {"Namespace": "OCUPROBE1814A", "Name": ("OcuProbe1814CP" _ tSuffix), "Database": "USER"}}])
            }
            Do $$$AssertEquals(##class(OcuPilot.Test.NamespaceWriteGate).Ran(tRun), tUser _ " 1", tUser _ ": " _ $List(tLegCase, 1) _ " ran as the principal")
            Set tText = ##class(OcuPilot.Test.NamespaceWriteGate).LegText(tRun, 1)
            If tUser = ..#LACKINGUSER {
                Do $$$AssertEquals(tText, "403 AUTH.NOPRIVILEGE " _ ..#RESOURCE _ ":USE calls=0 types=", tUser _ ": " _ $List(tLegCase, 1) _ " is refused naming the page's resource, the port asked nothing")
            } Else {
                Set tLeg = ##class(OcuPilot.Test.NamespaceWriteGate).Leg(tRun, 1)
                Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http"), 1: ""), $List(tLegCase, 3), tUser _ ": " _ $List(tLegCase, 1) _ " is admitted (" _ tText _ ")")
                Do $$$AssertTrue($IsObject(tLeg) && $ListFind($ListFromString(tLeg.%Get("types")), $List(tLegCase, 4)), tUser _ ": and its write reaches the port")
            }
        }
        Do $$$AssertEquals($ClassMethod(..#NSPROBE, "Holds", tDelete), (tUser = ..#LACKINGUSER), tUser _ ": the namespace to delete " _ $Select(tUser = ..#LACKINGUSER: "survives", 1: "is gone"))
    }
    Do $$$AssertEquals($ClassMethod(..#MAPPINGPROBE, "Names", "global", "OCUPROBE1814A"), "OcuProbe1814CPH", "only the holding principal's mapping is created")
}

/// <p>AC10 on the service Save (Story 16.13): with the probe resource assigned to one page at a time
/// -- the classic Edit Service dialog, then the Services list page, whose resource only the tool's
/// own pairs carry -- the principal lacking it is refused 403 <code>AUTH.NOPRIVILEGE</code> naming
/// <code>OcuProbe1814Page:USE</code> before the service is read, and the one holding it passes the
/// gate and is answered 404 <code>SERVICE.ABSENT</code> for a name the instance does not hold, so
/// nothing is written.</p>
/// <p>Mutation (Rule 19): drop the tool's <code>PrivilegePairs</code> check from
/// <method>OcuPilot.Area.Permissions.ServiceSave.Gate</method> -- the lacking principal's Save on the
/// list page's leg is answered 404 and this goes red.</p>
Method TestAnAssignedPageGatesTheServiceSave()
{
    Set tPath = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/services/" _ ##class(OcuPilot.Kernel.EntityId).Encode("OcuPilotNoSuchService99")
    For tPage = "%CSP.UI.Portal.Dialog.Service", "%CSP.UI.Portal.Services" {
        Kill tOne
        Set tOne(tPage) = ""
        ; Recorded here too, so the restore after the test puts it back even when no tool declares it.
        If '$Data(..PreparedPages(tPage)) Set ..PreparedPages(tPage) = ##class(%CSP.Portal.Utils).%GetCustomResource($ZConvert(tPage, "O", "URL"))
        Do $$$AssertStatusOK(..RestorePages(), tPage _ ": every page reads its recorded resource first")
        Do $$$AssertStatusOK(..Assign(.tOne), "the probe resource is assigned to " _ tPage _ " alone")
        For tCase = $ListBuild(..#LACKINGUSER, "403 AUTH.NOPRIVILEGE " _ ..#RESOURCE _ ":USE"), $ListBuild(..#HOLDINGUSER, "404 SERVICE.ABSENT ") {
            Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tPath, $List(tCase, 1), ..PreparedPassword, .tStatus, .tText, .tHeaders, "{""Enabled"":false}", "application/json")
            Set tAnswer = ""
            Try { Set tAnswer = ##class(%DynamicObject).%FromJSON($Get(tText)) } Catch {}
            Set tSaid = $Get(tStatus) _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code") _ " " _ $Select(tAnswer.%GetTypeOf("detail") = "object": tAnswer.%Get("detail").%Get("failedPair"), 1: ""), 1: $Get(tText))
            Do $$$AssertEquals(tSaid, $List(tCase, 2), $List(tCase, 1) _ ": the service Save with " _ tPage _ " assigned")
        }
    }
}

/// <p>AC11 on the LDAP editor's routes (Story 16.14): with the probe resource assigned to one page at
/// a time -- the classic LDAP editor, whose operation the update, create and password tools perform,
/// then the classic Test LDAP Authentication page, which the test route unions -- the principal
/// lacking it is refused 403 <code>AUTH.NOPRIVILEGE</code> naming <code>OcuProbe1814Page:USE</code>
/// on that page's routes before anything is read, and the one holding it passes the gate and is
/// answered for a name the instance does not hold, so nothing is written or tested.</p>
/// <p>The Save and create legs are gated by the form descriptor's own classic page as well as by the
/// tools' <parameter>OcuPilot.Screen.Tool.Write.CLASSICPAGES</parameter>, which the agent's-caller tests
/// pin.</p>
/// <p>Mutation (Rule 19): empty <parameter>OcuPilot.Area.Security.LdapRules.TESTPAGE</parameter> --
/// the lacking principal's test is answered 404 and this goes red.</p>
Method TestAnAssignedPageGatesTheLdapRoutes()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tName = ##class(OcuPilot.Kernel.EntityId).Encode("ocup99nosuchgate.invalid")
    Set tLegs = $ListBuild($ListBuild("%CSP.UI.Portal.LDAP", "PUT", tBase _ "/ldap/" _ tName, "{""Description"":""gated""}", "404 LDAP.ABSENT "), $ListBuild("%CSP.UI.Portal.LDAP", "POST", tBase _ "/ldap", "{""Name"":""ocup99nosuchgate.invalid""}", "422 LDAP.VALIDATION "), $ListBuild("%CSP.UI.Portal.LDAPTest", "POST", tBase _ "/ldap/" _ tName _ "/test", "{""Username"":""ocup99user"",""Password"":""x""}", "404 LDAP.ABSENT "))
    For tI = 1:1:$ListLength(tLegs) {
        Set tLeg = $List(tLegs, tI)
        Set tPage = $List(tLeg, 1)
        Kill tOne
        Set tOne(tPage) = ""
        If '$Data(..PreparedPages(tPage)) Set ..PreparedPages(tPage) = ##class(%CSP.Portal.Utils).%GetCustomResource($ZConvert(tPage, "O", "URL"))
        Do $$$AssertStatusOK(..RestorePages(), tPage _ ": every page reads its recorded resource first")
        Do $$$AssertStatusOK(..Assign(.tOne), "the probe resource is assigned to " _ tPage _ " alone")
        For tCase = $ListBuild(..#LACKINGUSER, "403 AUTH.NOPRIVILEGE " _ ..#RESOURCE _ ":USE"), $ListBuild(..#HOLDINGUSER, $List(tLeg, 5)) {
            Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest($List(tLeg, 2), $List(tLeg, 3), $List(tCase, 1), ..PreparedPassword, .tStatus, .tText, .tHeaders, $List(tLeg, 4), "application/json")
            Set tAnswer = ""
            Try { Set tAnswer = ##class(%DynamicObject).%FromJSON($Get(tText)) } Catch {}
            Set tSaid = $Get(tStatus) _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code") _ " " _ $Select((tAnswer.%GetTypeOf("detail") = "object") && (tAnswer.%Get("detail").%GetTypeOf("failedPair") = "string"): tAnswer.%Get("detail").%Get("failedPair"), 1: ""), 1: $Get(tText))
            Do $$$AssertEquals(tSaid, $List(tCase, 2), $List(tCase, 1) _ ": " _ $List(tLeg, 2) _ " " _ $List(tLeg, 3) _ " with " _ tPage _ " assigned")
        }
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.ServiceLdapProbe).LdapExists("ocup99nosuchgate.invalid"), 0, "and nothing was created")
}

/// <p>Story 19.6 AC8: with the probe resource assigned to the classic SQL page, the principal lacking
/// it is refused 403 <code>AUTH.NOPRIVILEGE</code> naming <code>OcuProbe1814Page:USE</code> on SQL
/// query's run route, its plan route and its confirmed run; the one holding it is answered a query's
/// rows, its plan, and the confirmed run's SQL error for a table the namespace does not hold, so
/// nothing changes.</p>
/// <p>Mutation (Rule 19): drop <method>OcuPilot.Screen.Tool.ExplorerSqlRun.PrivilegePairs</method> --
/// the lacking principal's confirmed run is admitted and its leg goes red; drop the screen gate from
/// <method>OcuPilot.Area.Explorer.SqlConsole.Prepare</method> -- its run and plan legs go red.</p>
Method TestAnAssignedPageGatesTheSqlConsole()
{
    Set tPage = "%CSP.UI.Portal.SQL.Home"
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tScope = "?ns=" _ $NAMESPACE
    Kill tOne
    Set tOne(tPage) = ""
    If '$Data(..PreparedPages(tPage)) Set ..PreparedPages(tPage) = ##class(%CSP.Portal.Utils).%GetCustomResource($ZConvert(tPage, "O", "URL"))
    Do $$$AssertStatusOK(..RestorePages(), tPage _ ": every page reads its recorded resource first")
    Do $$$AssertStatusOK(..Assign(.tOne), "the probe resource is assigned to " _ tPage _ " alone")
    Set tAction = {"action": "run", "id": "sql", "values": {"statement": "DELETE FROM OcuProbe1814NoSuch.Gate", "parameters": "[]", "maxRows": "10"}}.%ToJSON()
    Set tLegs = $ListBuild($ListBuild(tBase _ "/explorer/sql/run" _ tScope, "{""statement"":""SELECT 1 AS One""}", "200 rows"), $ListBuild(tBase _ "/explorer/sql/plan" _ tScope, "{""statement"":""SELECT 1 AS One""}", "200 plan"), $ListBuild(tBase _ "/screens/explorer.sqlquery/action" _ tScope, tAction, "200 error"))
    For tI = 1:1:$ListLength(tLegs) {
        Set tLeg = $List(tLegs, tI)
        For tCase = $ListBuild(..#LACKINGUSER, "403 AUTH.NOPRIVILEGE " _ ..#RESOURCE _ ":USE"), $ListBuild(..#HOLDINGUSER, $List(tLeg, 3)) {
            Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", $List(tLeg, 1), $List(tCase, 1), ..PreparedPassword, .tStatus, .tText, .tHeaders, $List(tLeg, 2), "application/json")
            Set tAnswer = ""
            Try { Set tAnswer = ##class(%DynamicObject).%FromJSON($Get(tText)) } Catch {}
            If '$IsObject(tAnswer) {
                Set tSaid = $Get(tStatus) _ " " _ $Get(tText)
            } ElseIf tAnswer.%GetTypeOf("code") = "string" {
                Set tSaid = tStatus _ " " _ tAnswer.code _ " " _ $Select(tAnswer.%GetTypeOf("detail") = "object": tAnswer.detail.%Get("failedPair"), 1: "")
            } ElseIf tAnswer.%GetTypeOf("output") = "object" {
                Set tSaid = tStatus _ " " _ tAnswer.output.%Get("outcome")
            } Else {
                Set tSaid = tStatus _ " " _ tAnswer.%Get("outcome")
            }
            Do $$$AssertEquals(tSaid, $List(tCase, 2), $List(tCase, 1) _ ": " _ $List(tLeg, 1) _ " with " _ tPage _ " assigned")
        }
    }
}

/// <p>Story 19.15 AC10: with the probe resource assigned to the classic SQL page, the principal lacking
/// it is refused 403 <code>AUTH.NOPRIVILEGE</code> naming <code>OcuProbe1814Page:USE</code> on SQL
/// query's background start, poll and cancel, and a run reserved and spawned for it past the route
/// ends <code>failed</code> with that refusal from the job's own gate; the one holding it starts a
/// background query, polls it and cancels it, and its run ends <code>ended</code> or
/// <code>canceled</code>.</p>
/// <p>Mutation (Rule 19): drop the screen gate from
/// <method>OcuPilot.Area.Explorer.SqlConsole.Read</method>, which the background start reads its body
/// through -- the lacking principal's start is answered 202 and its leg goes red. Drop the screen gate
/// from <method>OcuPilot.Area.Explorer.SqlBackground.Run</method> -- the job's run past the route no
/// longer names the page's resource and its leg goes red.</p>
Method TestAnAssignedPageGatesTheBackgroundRun()
{
    Set tPage = "%CSP.UI.Portal.SQL.Home"
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/explorer/sql/background"
    Set tScope = "?ns=" _ $NAMESPACE
    Kill tOne
    Set tOne(tPage) = ""
    If '$Data(..PreparedPages(tPage)) Set ..PreparedPages(tPage) = ##class(%CSP.Portal.Utils).%GetCustomResource($ZConvert(tPage, "O", "URL"))
    Do $$$AssertStatusOK(..RestorePages(), tPage _ ": every page reads its recorded resource first")
    Do $$$AssertStatusOK(..Assign(.tOne), "the probe resource is assigned to " _ tPage _ " alone")
    Set tAbsent = "0123456789abcdef0123456789abcdef"
    Set tBody = "{""statement"":""SELECT 1 AS One""}"
    For tLeg = $ListBuild("POST", tBase _ tScope, tBody), $ListBuild("GET", tBase _ "/" _ tAbsent _ tScope, ""), $ListBuild("POST", tBase _ "/" _ tAbsent _ "/cancel" _ tScope, "") {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest($List(tLeg, 1), $List(tLeg, 2), ..#LACKINGUSER, ..PreparedPassword, .tStatus, .tText, .tHeaders, $List(tLeg, 3), "application/json")
        Set tAnswer = ""
        Try { Set tAnswer = ##class(%DynamicObject).%FromJSON($Get(tText)) } Catch {}
        Set tSaid = $Get(tStatus) _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code") _ " " _ $Select(tAnswer.%GetTypeOf("detail") = "object": tAnswer.detail.%Get("failedPair"), 1: ""), 1: $Get(tText))
        Do $$$AssertEquals(tSaid, "403 AUTH.NOPRIVILEGE " _ ..#RESOURCE _ ":USE", ..#LACKINGUSER _ ": " _ $List(tLeg, 1) _ " " _ $List(tLeg, 2) _ " with " _ tPage _ " assigned")
    }
    Set tStart = ##class(OcuPilot.Test.SqlBackgroundJob).StartAs(..#LACKINGUSER, "OcuPilot.Area.Explorer.SqlBackground", "SELECT 1 AS One")
    Do $$$AssertEquals(tStart.%Get("http"), 202, ..#LACKINGUSER _ ": a run is reserved and spawned past the route: " _ tStart.%ToJSON())
    Set tView = ##class(OcuPilot.Test.SqlBackgroundJob).AwaitInProcess(..#LACKINGUSER, tStart.%Get("key"))
    Set tSaid = $Select($IsObject(tView) && (tView.%GetTypeOf("refusal") = "object"): tView.status _ " " _ tView.refusal.code _ " " _ $Select(tView.refusal.%GetTypeOf("detail") = "object": tView.refusal.detail.%Get("failedPair"), 1: ""), 1: ##class(OcuPilot.Test.SqlBackgroundJob).Said(tView))
    Do $$$AssertEquals(tSaid, "failed AUTH.NOPRIVILEGE " _ ..#RESOURCE _ ":USE", ..#LACKINGUSER _ ": the job's own gate refuses the run, naming the page's resource")
    Do ##class(OcuPilot.Kernel.State.SqlRun).GuardedForgetUser(..#LACKINGUSER)
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ tScope, ..#HOLDINGUSER, ..PreparedPassword, .tStatus, .tText, .tHeaders, tBody, "application/json")
    Set tAnswer = ""
    Try { Set tAnswer = ##class(%DynamicObject).%FromJSON($Get(tText)) } Catch {}
    Do $$$AssertEquals($Get(tStatus), 202, ..#HOLDINGUSER _ ": the background start is answered: " _ $Get(tText))
    Set tKey = $Select($IsObject(tAnswer): tAnswer.%Get("id"), 1: tAbsent)
    For tLeg = $ListBuild("GET", tBase _ "/" _ tKey _ tScope), $ListBuild("POST", tBase _ "/" _ tKey _ "/cancel" _ tScope) {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest($List(tLeg, 1), $List(tLeg, 2), ..#HOLDINGUSER, ..PreparedPassword, .tStatus, .tText, .tHeaders, "", "application/json")
        Do $$$AssertEquals($Get(tStatus), 200, ..#HOLDINGUSER _ ": " _ $List(tLeg, 1) _ " of its run is answered: " _ $Get(tText))
    }
    Set tDeadline = $ZHorolog + 10
    For {
        Do ##class(OcuPilot.Area.Explorer.SqlBackground).View(tKey, ..#HOLDINGUSER, .tFound, .tView)
        If '$Get(tFound) || (tView.%Get("status") '= "running") || ($ZHorolog > tDeadline) Quit
        Hang 0.25
    }
    Do $$$AssertTrue($Get(tFound) && ((tView.%Get("status") = "ended") || (tView.%Get("status") = "canceled")), "and its run ends, ended or canceled: " _ ##class(OcuPilot.Test.SqlBackgroundJob).Said($Get(tView)))
    Do ##class(OcuPilot.Kernel.State.SqlRun).GuardedForgetUser(..#HOLDINGUSER)
}

/// <p>Story 19.7 AC9: with the probe resource assigned to either classic Open Table page alone -- the
/// table page the screen declares, or the view page its route unions -- the principal lacking it is
/// refused 403 <code>AUTH.NOPRIVILEGE</code> naming <code>OcuProbe1814Page:USE</code> on Data
/// browser's route, and the one holding it passes every gate and is answered 404
/// <code>EXPLORER.DATA.NOTFOUND</code> for a table the namespace does not hold, so nothing is read.</p>
/// <p>Mutation (Rule 19): drop the view page from <method>OcuPilot.Area.Explorer.SqlData.Gate</method>
/// -- the lacking principal's leg with the view page assigned goes red.</p>
Method TestAnAssignedPageGatesTheDataBrowser()
{
    Set tPath = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/explorer/sql/data?ns=" _ $NAMESPACE
    Set tBody = "{""schema"":""OcuProbe1814NoSuch"",""table"":""Gate""}"
    For tPage = "%cspapp.exp.utilsqlopen", "%cspapp.exp.utilsqlopenview" {
        Kill tOne
        Set tOne(tPage) = ""
        If '$Data(..PreparedPages(tPage)) Set ..PreparedPages(tPage) = ##class(%CSP.Portal.Utils).%GetCustomResource($ZConvert(tPage, "O", "URL"))
        Do $$$AssertStatusOK(..RestorePages(), tPage _ ": every page reads its recorded resource first")
        Do $$$AssertStatusOK(..Assign(.tOne), "the probe resource is assigned to " _ tPage _ " alone")
        For tCase = $ListBuild(..#LACKINGUSER, "403 AUTH.NOPRIVILEGE " _ ..#RESOURCE _ ":USE"), $ListBuild(..#HOLDINGUSER, "404 EXPLORER.DATA.NOTFOUND ") {
            Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tPath, $List(tCase, 1), ..PreparedPassword, .tStatus, .tText, .tHeaders, tBody, "application/json")
            Set tAnswer = ""
            Try { Set tAnswer = ##class(%DynamicObject).%FromJSON($Get(tText)) } Catch {}
            Set tSaid = $Get(tStatus) _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code") _ " " _ $Select(tAnswer.%GetTypeOf("detail") = "object": tAnswer.detail.%Get("failedPair"), 1: ""), 1: $Get(tText))
            Do $$$AssertEquals(tSaid, $List(tCase, 2), $List(tCase, 1) _ ": POST /explorer/sql/data with " _ tPage _ " assigned")
        }
    }
}

/// <p>Mint the namespace create of <var>pName</var> for <var>pUser</var> over a completed turn seeded
/// for that user.</p>
Method MintFor(pUser As %String, pName As %String, Output pProposal As %DynamicObject) As %Status
{
    Set pProposal = ""
    Set tTool = "OcuPilot.Screen.Tool.NamespaceCreate"
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(pUser, "completed", .tTurn)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Mint($Parameter(tTool, "DESCRIPTORCLASS"), $Parameter(tTool, "TOOLNAME"), pUser, "", tTurn, {"Name": (pName), "Globals": "USER", "Routines": "USER"}, "OcuPilot.Kernel.Agent.Limits", .pProposal, .tHttp, .tFault, $ClassMethod(tTool, "Endpoint"), $ClassMethod(tTool, "IdParam"), pName, $ClassMethod(tTool, "IdArgument"), $ClassMethod(tTool, "SettableFields"), tTool)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(pProposal) Quit $$$ERROR($$$GeneralError, "the mint answered no proposal")
    Quit $$$OK
}

/// <p>Every page a registered write tool declares in
/// <parameter>OcuPilot.Screen.Tool.Write.CLASSICPAGES</parameter>, as <code>pRoster(page) = ""</code>,
/// and the declaring tools' names, sorted, in <var>pTools</var>.</p>
ClassMethod Roster(Output pRoster, Output pTools As %List) As %Status
{
    Kill pRoster
    Set pTools = ""
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ListTools(.tAll)
    If $$$ISERR(tSC) Quit tSC
    Kill tSorted
    Set tIterator = tAll.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tEntry) {
        If '$IsObject(tEntry) || (tEntry.%Get("kind") '= "write") Continue
        Set tPages = $Parameter(tEntry.%Get("class"), "CLASSICPAGES")
        If tPages = "" Continue
        Set tSorted(tEntry.%Get("name")) = ""
        For tI = 1:1:$Length(tPages, ",") {
            Set tPage = $ZStrip($Piece(tPages, ",", tI), "<>W")
            If tPage '= "" Set pRoster(tPage) = ""
        }
    }
    Set tName = ""
    For {
        Set tName = $Order(tSorted(tName))
        If tName = "" Quit
        Set pTools = pTools _ $ListBuild(tName)
    }
    Quit $$$OK
}

/// <p>Assign <parameter>RESOURCE</parameter> to every page of <var>pRoster</var>.</p>
Method Assign(ByRef pRoster) As %Status
{
    Set tSC = $$$OK
    Set tPage = ""
    For {
        Set tPage = $Order(pRoster(tPage))
        If tPage = "" Quit
        Set tSC = $$$ADDSC(tSC, ##class(%CSP.Portal.Utils).%SetCustomResource($ZConvert(tPage, "O", "URL"), ..#RESOURCE))
        If ##class(%CSP.Portal.Utils).%GetCustomResource($ZConvert(tPage, "O", "URL")) '= ..#RESOURCE Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, tPage _ " does not read the probe resource after its assignment"))
    }
    Quit tSC
}

/// <p>Restore every recorded page to its recorded custom resource; an error when one does not read
/// it afterwards.</p>
Method RestorePages() As %Status
{
    Set tSC = $$$OK
    Set tPage = ""
    For {
        Set tPage = $Order(..PreparedPages(tPage), 1, tRecorded)
        If tPage = "" Quit
        Set tEncoded = $ZConvert(tPage, "O", "URL")
        If ##class(%CSP.Portal.Utils).%GetCustomResource(tEncoded) '= tRecorded Set tSC = $$$ADDSC(tSC, ##class(%CSP.Portal.Utils).%SetCustomResource(tEncoded, tRecorded))
        If ##class(%CSP.Portal.Utils).%GetCustomResource(tEncoded) '= tRecorded Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, tPage _ " does not read its recorded custom resource '" _ tRecorded _ "'"))
    }
    Quit tSC
}

/// <p>Enable the agent's namespace and database delete keys, its task import key and Story 18.4's
/// disk operation keys, over the snapshot this class took.</p>
/// <p>And Story 18.15's enable-interop key.</p>
/// <p>And Story 18.16's remote database delete key.</p>
Method EnableDelete() As %Status
{
    Kill tSettings
    Set tSettings(..#DELETEKEY) = "enabled"
    Set tSettings(..#DATABASEDELETEKEY) = "enabled"
    Set tSettings(..#TASKIMPORTKEY) = "enabled"
    Set tSettings(..#ENABLEINTEROPKEY) = "enabled"
    Set tSettings(..#REMOTEDELETEKEY) = "enabled"
    For tI = 1:1:$Length(..#DISKKEYS, ",") {
        Set tSettings($Piece(..#DISKKEYS, ",", tI)) = "enabled"
    }
    For tI = 1:1:$Length(..#EXPLORERIMPORTKEYS, ",") {
        Set tSettings($Piece(..#EXPLORERIMPORTKEYS, ",", tI)) = "enabled"
    }
    Set tSettings(..#ECPSTATUSKEY) = "enabled"
    For tI = 1:1:$Length(..#ENCRYPTIONKEYS, ",") {
        Set tSettings($Piece(..#ENCRYPTIONKEYS, ",", tI)) = "enabled"
    }
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

/// <p>Remove every probe namespace of both suites, each by its exact name.</p>
ClassMethod RemoveProbes() As %Status
{
    Set tSC = $ClassMethod(..#NSPROBE, "RemoveAll", .tRemaining)
    Quit $$$ADDSC(tSC, $ClassMethod(..#MAPPINGPROBE, "RemoveAll", .tRemaining))
}

/// <p>The install namespace's routines database's resource at read, spelled for a role's
/// resources: what a principal needs to run OcuPilot's code.</p>
ClassMethod CodeRead() As %String
{
    Set tCode = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set $NAMESPACE = "%SYS"
        Set tNamespace = ##class(Config.Namespaces).Open(tInstallNs)
        Set tDatabase = ##class(Config.Databases).Open(tNamespace.Routines)
        Set tCode = ##class(SYS.Database).%OpenId(tDatabase.Directory).ResourceName _ ":R"
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tCode = ""
    }
    Quit tCode
}

/// <p>Create the probe resource and the two throwaway principals, then read the grants back.</p>
Method EnsurePrincipals() As %Status
{
    Set tSC = $$$OK
    Set tCode = ..CodeRead()
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If '##class(Security.Resources).Exists(..#RESOURCE) {
            Set tSC = ##class(Security.Resources).Create(..#RESOURCE, "OcuPilot test: a classic page's custom resource (throwaway)", "")
            If $$$ISERR(tSC) Quit
        }
        ; WRITE on the install namespace's code database and %Development:USE are System Explorer's
        ; compile and import pairs (Stories 19.2 and 19.13), so their legs fail on the page's
        ; resource alone. The Ens_ pairs are Interoperability's production actions' (Story 20.2).
        Set tDeclared = $Piece(tCode, ":", 1) _ ":RW,%Development:U,%DB_IRISSYS:RW,%Admin_Manage:U,%Admin_Secure:U,%Admin_Operate:U,%Admin_Task:U,%Admin_FileSystemAccess:U,%Admin_ExternalLanguageServerEdit:U,%Ens_Portal:U,%Ens_ProductionConfig:R,%Ens_ProductionRun:U"
        For tCase = $ListBuild(..#LACKINGUSER, tDeclared, 0), $ListBuild(..#HOLDINGUSER, tDeclared _ "," _ ..#RESOURCE _ ":U", 1) {
            Set tUser = $List(tCase, 1)
            Set tRole = tUser _ "Role"
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: the classic-page gate (throwaway)", $List(tCase, 2), "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create(tUser, tRole, ..PreparedPassword, "OcuPilot classic-page test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.ClassicPageGate; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
            If ($SYSTEM.Security.CheckUserPermission(tUser, "%DB_IRISSYS", "WRITE") '= 1) || ($SYSTEM.Security.CheckUserPermission(tUser, "%Admin_Secure", "USE") '= 1) || ($SYSTEM.Security.CheckUserPermission(tUser, "%Admin_Operate", "USE") '= 1) || ($SYSTEM.Security.CheckUserPermission(tUser, "%Admin_FileSystemAccess", "USE") '= 1) || (($SYSTEM.Security.CheckUserPermission(tUser, ..#RESOURCE, "USE") = 1) '= $List(tCase, 3)) {
                Set tSC = $$$ERROR($$$GeneralError, "the throwaway principal " _ tUser _ "'s grants did not read back as declared")
                Quit
            }
        }
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>Delete the principals, their roles and the probe resource; an error when any survives.</p>
Method RemovePrincipals() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tUser = ..#LACKINGUSER, ..#HOLDINGUSER {
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tUser _ "Role") Do ##class(Security.Roles).Delete(tUser _ "Role")
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tUser _ "Role") Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.ClassicPageGate left the principal or role of " _ tUser))
        }
        If ##class(Security.Resources).Exists(..#RESOURCE) Do ##class(Security.Resources).Delete(..#RESOURCE)
        If ##class(Security.Resources).Exists(..#RESOURCE) Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.ClassicPageGate left the resource " _ ..#RESOURCE))
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

/// <p><var>pPairs</var> spelled <code>resource:permission</code>, comma-separated.</p>
ClassMethod Names(pPairs As %List) As %String
{
    Set tOut = ""
    For tI = 1:1:$ListLength(pPairs) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ $ListToString($List(pPairs, tI), ":")
    }
    Quit tOut
}

/// <p>The declaring tools <parameter>OWNPAIRS</parameter> names, sorted, as a <class>%List</class>.</p>
ClassMethod Declared() As %List
{
    Kill tSorted
    For tI = 1:1:$Length(..#OWNPAIRS, ",") {
        Set tName = $Piece($Piece(..#OWNPAIRS, ",", tI), "=", 1)
        If tName '= "" Set tSorted(tName) = ""
    }
    Set tTools = ""
    Set tName = ""
    For {
        Set tName = $Order(tSorted(tName))
        If tName = "" Quit
        Set tTools = tTools _ $ListBuild(tName)
    }
    Quit tTools
}

}
