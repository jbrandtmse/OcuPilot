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
/// <class>OcuPilot.Test.NamespaceWriteGateProbe</class> and
/// <class>OcuPilot.Test.MappingWriteGateProbe</class>.</p>
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

/// <p>The agent's task import key, which the baseline disables too (DW-1827).</p>
Parameter TASKIMPORTKEY = "tasks.schedule.import";

/// <p>The pairs each declaring tool declares beyond its list's own, as <code>tool=pair|pair</code>
/// entries: its declared set, with no classic page assigned. The declaring tools are exactly these,
/// and the database file edit and truncate declare none of their own; Story 18.4's dismount, whose
/// classic page performs it itself, declares no page.</p>
Parameter OWNPAIRS = "osmgmt.localdatabases.create=%DB_IRISSYS:WRITE|%Admin_Secure:USE|%Admin_FileSystemAccess:USE,osmgmt.localdatabases.updatemount=%DB_IRISSYS:WRITE,osmgmt.localdatabases.update=,osmgmt.localdatabases.delete=%DB_IRISSYS:WRITE,osmgmt.namespaces.create=%DB_IRISSYS:WRITE,osmgmt.namespaces.update=%DB_IRISSYS:WRITE,osmgmt.namespaces.delete=%DB_IRISSYS:WRITE|%Admin_Secure:USE,osmgmt.namespaces.copymappings=%Admin_Operate:USE|%DB_IRISSYS:WRITE,osmgmt.globalmappings.create=%DB_IRISSYS:WRITE,osmgmt.globalmappings.update=%DB_IRISSYS:WRITE,osmgmt.routinemappings.create=%DB_IRISSYS:WRITE,osmgmt.routinemappings.update=%DB_IRISSYS:WRITE,osmgmt.packagemappings.create=%DB_IRISSYS:WRITE,osmgmt.packagemappings.update=%DB_IRISSYS:WRITE,osmgmt.databasedetails.mount=%Admin_Secure:USE,osmgmt.databasedetails.truncate=,osmgmt.databasedetails.compact=%DB_IRISSYS:WRITE,osmgmt.databasedetails.defragment=%DB_IRISSYS:WRITE,osmgmt.databases.integrity=%Admin_Operate:USE|%DB_IRISSYS:WRITE,osmgmt.localdatabases.grow=%Admin_Operate:USE,osmgmt.localdatabases.expand=%Admin_Operate:USE,tasks.schedule.export=%Admin_FileSystemAccess:USE,tasks.schedule.import=%Admin_FileSystemAccess:USE,osmgmt.languageservers.start=%Admin_ExternalLanguageServerEdit:USE,osmgmt.languageservers.stop=%Admin_ExternalLanguageServerEdit:USE";

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
    Do $$$AssertEquals($ListToString(tTools), $ListToString(..Declared()), "the tools declaring a replaced classic page are the twenty-five OWNPAIRS names")
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

/// <p>With the probe resource assigned to every declared page, each declaring tool's call on the
/// agent's caller is refused 403 <code>AUTH.NOPRIVILEGE</code> naming <code>OcuProbe1814Page:USE</code>
/// for the principal lacking it, before its arguments are read; the principal holding it passes that
/// gate. The legs are the declared roster's, so a tool that stops declaring its page is admitted for
/// the lacking principal and its leg goes red. A namespace create minted for each is refused at the
/// lacking principal's confirm naming the pair with no port call, and applied at the holding
/// principal's, reaching the port.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Gate.WithClassicPages</method> answers
/// <var>pPairs</var> unchanged -> the lacking principal is admitted and this goes red.</p>
Method TestAnAssignedPageGatesEveryDeclaringToolOnTheAgentsCaller()
{
    Do $$$AssertStatusOK(..EnableDelete(), "the agent's namespace and database delete keys and its task import key are enabled, so only the pairs stand in the way")
    Set tSC = ..Roster(.tRoster)
    Set tTools = ..Declared()
    Do $$$AssertStatusOK(..Assign(.tRoster), "the probe resource is assigned to every declared page")
    For tUser = ..#LACKINGUSER, ..#HOLDINGUSER {
        Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(tUser, "running", .tTurnKey)
        Do $$$AssertStatusOK(tSC, tUser _ ": a running turn is seeded")
        Set tPlan = []
        For tI = 1:1:$ListLength(tTools) {
            Do tPlan.%Push({"kind": "dispatch", "turnKey": (tTurnKey), "tool": ($List(tTools, tI)), "input": {}})
        }
        Set tRun = ##class(OcuPilot.Test.MappingWriteGate).RunAs(tUser, tPlan)
        Do $$$AssertEquals(##class(OcuPilot.Test.NamespaceWriteGate).Ran(tRun), tUser _ " 1", tUser _ ": the child process ran as the principal")
        For tI = 1:1:$ListLength(tTools) {
            Set tLeg = ##class(OcuPilot.Test.NamespaceWriteGate).Leg(tRun, tI)
            Set tSaid = $Select($IsObject(tLeg): tLeg.%Get("http") _ " " _ tLeg.%Get("code") _ " " _ tLeg.%Get("failedPair"), 1: "absent")
            If tUser = ..#LACKINGUSER {
                Do $$$AssertEquals(tSaid, "403 AUTH.NOPRIVILEGE " _ ..#RESOURCE _ ":USE", $List(tTools, tI) _ ": the lacking principal's call is refused naming the page's resource")
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
Method EnableDelete() As %Status
{
    Kill tSettings
    Set tSettings(..#DELETEKEY) = "enabled"
    Set tSettings(..#DATABASEDELETEKEY) = "enabled"
    Set tSettings(..#TASKIMPORTKEY) = "enabled"
    For tI = 1:1:$Length(..#DISKKEYS, ",") {
        Set tSettings($Piece(..#DISKKEYS, ",", tI)) = "enabled"
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
        Set tDeclared = tCode _ ",%DB_IRISSYS:RW,%Admin_Manage:U,%Admin_Secure:U,%Admin_Operate:U,%Admin_Task:U,%Admin_FileSystemAccess:U,%Admin_ExternalLanguageServerEdit:U"
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
