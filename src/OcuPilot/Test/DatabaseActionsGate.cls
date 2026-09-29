/// <p>Pins Story 18.4's pairs with least-privileged principals (AD-8, AD-29, AC9): each extra pair a disk
/// operation declares, when missing, is refused 403 naming it on both callers with the port asked
/// nothing; and a principal holding exactly a tool's declared pairs writes on both callers, the
/// instance holding what it wrote.</p>
/// <p>The screen and confirm legs run in a child process logged in as the principal
/// (<class>OcuPilot.Test.DatabaseActionsGateProbe</class>), which reports what
/// <class>OcuPilot.Test.DatabaseRecordPort</class> was asked. A classic page's custom resource is
/// <class>OcuPilot.Test.ClassicPageGate</class>'s.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and both
/// <parameter>ARMINGVARIABLE</parameter> and <parameter>DATABASEVARIABLE</parameter> reading
/// <code>1</code>, because the class creates and deletes eight users, eight roles, a resource and probe
/// databases (<class>OcuPilot.Test.DatabaseActionProbe</class>) and sets the governance policy.
/// <method>OnBeforeAllTests</method> refuses anywhere either does not; every probe object is removed by
/// exact name.</p>
Class OcuPilot.Test.DatabaseActionsGate Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter DATABASEVARIABLE = "OCUPILOT_ALLOW_DATABASE_CONFIG";

Parameter PROBE = "OcuPilot.Test.DatabaseActionProbe";

/// <p>The resource guarding the compact's and defragment's target, outside the probe resource prefix so
/// the principals' grant to it outlives each test's removal.</p>
Parameter TARGETRESOURCE = "%DB_OCUGATE184";

/// <p>The principals, each <code>user:role:grants</code> beyond the install namespace's code read.</p>
Parameter PRINCIPALS = "OcuProbe184GateOperate:OcuProbe184GateOperateRole:%Admin_Operate:U;%DB_IRISSYS:R,OcuProbe184GateMount:OcuProbe184GateMountRole:%Admin_Operate:U;%DB_IRISSYS:R;%Admin_Secure:U,OcuProbe184GateNoTarget:OcuProbe184GateNoTargetRole:%Admin_Operate:U;%DB_IRISSYS:RW,OcuProbe184GateCompact:OcuProbe184GateCompactRole:%Admin_Operate:U;%DB_IRISSYS:RW;%DB_OCUGATE184:R,OcuProbe184GateManage:OcuProbe184GateManageRole:%Admin_Manage:U;%DB_IRISSYS:R,OcuProbe184GateLocal:OcuProbe184GateLocalRole:%Admin_Manage:U;%DB_IRISSYS:R;%Admin_Operate:U,OcuProbe184GateIntegrity:OcuProbe184GateIntegrityRole:%Admin_Manage:U;%DB_IRISSYS:RW;%Admin_Operate:U,OcuProbe184GateDismount:OcuProbe184GateDismountRole:%Admin_Operate:U;%DB_IRISSYS:R;%Admin_Manage:U";

Property PreparedPassword As %String;

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
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#DATABASEVARIABLE) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DatabaseActionsGate creates and deletes users, roles, a resource and databases on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#DATABASEVARIABLE _ " must both read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets them.")
    }
    Set ..PreparedPassword = "OcuProbe184Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If $$$ISERR(tSC) Quit tSC
    Quit ..EnsurePrincipals()
}

Method OnAfterOneTest() As %Status
{
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe object is removed")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", .tRemaining))
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(..#PRINCIPALS, ",") {
            Set tUser = $Piece($Piece(..#PRINCIPALS, ",", tI), ":", 1)
            Set tRole = $Piece($Piece(..#PRINCIPALS, ",", tI), ":", 2)
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            If ##class(Security.Users).Exists(tUser) || ##class(Security.Roles).Exists(tRole) Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "OcuPilot.Test.DatabaseActionsGate left the principal " _ tUser))
        }
        If ##class(Security.Resources).Exists(..#TARGETRESOURCE) Set tSC = $$$ADDSC(tSC, ##class(Security.Resources).Delete(..#TARGETRESOURCE))
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Quit tSC
}

/// <p>Each extra pair, missing (AC9): the mount without <code>%Admin_Secure:USE</code>, the dismount
/// without <code>%Admin_Manage:USE</code> (its prohibited set's own-database read), the compact and
/// defragment without <code>%DB_IRISSYS:WRITE</code>, the compact and defragment without read on the
/// target's own resource, the size grow, Add a volume and the integrity check without
/// <code>%Admin_Operate:USE</code>, and the integrity check without <code>%DB_IRISSYS:WRITE</code> are
/// each refused 403 naming the pair on both callers -- the size grow's by its Save and its agent
/// confirm -- with the port asked nothing, and nothing changes.</p>
/// <p>Mutation (Rule 19): drop <code>%DB_IRISSYS:WRITE</code> from
/// <class>OcuPilot.Screen.Tool.DatabaseCompact</class> -> the compact legs are refused naming another
/// pair, the declared-pairs principal among them, and this goes red; the same from
/// <class>OcuPilot.Screen.Tool.DatabaseDefragment</class>, or <code>%Admin_Operate</code> from
/// <class>OcuPilot.Screen.Tool.LocalDatabaseGrow</class>, reddens its own legs.</p>
Method TestEachMissingPairIsRefusedBeforeAnyPortCall()
{
    Do ..Seed()
    Set tA = $ClassMethod(..#PROBE, "DirectoryOf", "OCUPROBE184GA")
    Set tB = $ClassMethod(..#PROBE, "DirectoryOf", "OCUPROBE184GB")
    Set tC = $ClassMethod(..#PROBE, "DirectoryOf", "OCUPROBE184GC")
    Do $$$AssertStatusOK(..Mount(tA, "DISMOUNT"), "the mount's target is dismounted")
    Set tCases = $ListBuild($ListBuild(1, "%Admin_Secure:USE", "mount", tA, "OcuPilot.Screen.Tool.DatabaseMount", {"ReadOnly": "false"}.%ToJSON()))
    Set tCases = tCases _ $ListBuild($ListBuild(1, "%Admin_Manage:USE", "dismount", tB, "OcuPilot.Screen.Tool.DatabaseDismount", ""))
    Set tCases = tCases _ $ListBuild($ListBuild(1, "%DB_IRISSYS:WRITE", "compact", tC, "OcuPilot.Screen.Tool.DatabaseCompact", {"TargetFreeSpace": "0"}.%ToJSON()))
    Set tCases = tCases _ $ListBuild($ListBuild(3, ..#TARGETRESOURCE _ ":READ", "compact", tC, "OcuPilot.Screen.Tool.DatabaseCompact", {"TargetFreeSpace": "0"}.%ToJSON()))
    Set tCases = tCases _ $ListBuild($ListBuild(1, "%DB_IRISSYS:WRITE", "defragment", tC, "OcuPilot.Screen.Tool.DatabaseDefragment", ""))
    Set tCases = tCases _ $ListBuild($ListBuild(3, ..#TARGETRESOURCE _ ":READ", "defragment", tC, "OcuPilot.Screen.Tool.DatabaseDefragment", ""))
    Set tCases = tCases _ $ListBuild($ListBuild(5, "%Admin_Operate:USE", "integrity", tC, "OcuPilot.Screen.Tool.DatabaseIntegrityCheck", {"Globals": "[]"}.%ToJSON()))
    Set tCases = tCases _ $ListBuild($ListBuild(6, "%DB_IRISSYS:WRITE", "integrity", tC, "OcuPilot.Screen.Tool.DatabaseIntegrityCheck", {"Globals": "[]"}.%ToJSON()))
    Set tCases = tCases _ $ListBuild($ListBuild(5, "%Admin_Operate:USE", "expand", "OCUPROBE184GC", "OcuPilot.Screen.Tool.LocalDatabaseExpand", {"InitialSize": "1"}.%ToJSON()))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tUser = ..User($List(tCase, 1))
        Set tValues = $Select($List(tCase, 6) = "": "", 1: ##class(%DynamicObject).%FromJSON($List(tCase, 6)))
        Set tRun = ..Legs(tUser, $List(tCase, 3), $List(tCase, 4), $List(tCase, 5), tValues)
        For tLeg = 1, 2 {
            Do $$$AssertEquals(..LegText(tRun, tLeg), "403 AUTH.NOPRIVILEGE " _ $List(tCase, 2) _ " calls=0 types=", tUser _ " " _ $List(tCase, 3) _ ": " _ $Select(tLeg = 1: "the screen's action", 1: "the agent's confirm") _ " is refused naming " _ $List(tCase, 2))
        }
    }
    Set tRun = ..RunAs(..User(5), [{"kind": "update", "name": "OCUPROBE184GC", "body": {"size": {"Size": 999}}}])
    Do $$$AssertEquals(..LegText(tRun, 1), "403 AUTH.NOPRIVILEGE %Admin_Operate:USE calls=0 types=", "the size grow's Save without %Admin_Operate:USE is refused naming it")
    Set tProposal = ..MintFor(..User(5), "OcuPilot.Screen.Tool.LocalDatabaseGrow", "OCUPROBE184GC", {"Size": (##class(OcuPilot.Test.DatabaseActions).StateOf(tC, "Size") + 2)})
    Do $$$AssertTrue($IsObject(tProposal), "the agent's size grow is minted for " _ ..User(5))
    Set tRun = ..RunAs(..User(5), [{"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))}])
    Do $$$AssertEquals(..LegText(tRun, 1), "403 AUTH.NOPRIVILEGE %Admin_Operate:USE calls=0 types=", "and its agent confirm without %Admin_Operate:USE is refused naming it")
    Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseActions).StateOf(tA, "Mounted") _ ##class(OcuPilot.Test.DatabaseActions).StateOf(tB, "Mounted"), "falsetrue", "the mount's target is still dismounted, and the dismount's still mounted")
}

/// <p>Exactly the declared pairs (AC9): a principal holding each tool's declared set writes on both
/// callers -- truncate with Database details' pairs alone, dismount with <code>%Admin_Manage:USE</code>
/// beside them, the mount with
/// <code>%Admin_Secure:USE</code> beside them, the compact and defragment with the system database's
/// write and the target's read, the size grow and Add a volume with Local databases' pairs and
/// <code>%Admin_Operate:USE</code>, the integrity check with the Databases list's, that and the system
/// database's write -- each reaching the port's operation.</p>
Method TestExactlyTheDeclaredPairsWriteOnBothCallers()
{
    Do ..Seed()
    Set tA = $ClassMethod(..#PROBE, "DirectoryOf", "OCUPROBE184GA")
    Set tB = $ClassMethod(..#PROBE, "DirectoryOf", "OCUPROBE184GB")
    Set tC = $ClassMethod(..#PROBE, "DirectoryOf", "OCUPROBE184GC")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Grow", "OCUPROBE184GA", 10), "the truncate's targets are grown")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Grow", "OCUPROBE184GB", 10), "both of them")
    Do ..Both(1, "truncate", tA, tB, "OcuPilot.Screen.Tool.DatabaseTruncate", {"TargetSize": "0"}, "Database.Actions/TRUNCATE")
    Do ..Both(8, "dismount", tA, tB, "OcuPilot.Screen.Tool.DatabaseDismount", "", "Database.Actions/DISMOUNT")
    Do ..Both(2, "mount", tA, tB, "OcuPilot.Screen.Tool.DatabaseMount", {"ReadOnly": "false"}, "Database.Actions/MOUNT")
    Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseActions).StateOf(tA, "Mounted") _ ##class(OcuPilot.Test.DatabaseActions).StateOf(tB, "Mounted"), "truetrue", "both are mounted again")
    Set tD = $ClassMethod(..#PROBE, "DirectoryOf", "OCUPROBE184GD")
    Do ..Both(4, "compact", tC, tD, "OcuPilot.Screen.Tool.DatabaseCompact", {"TargetFreeSpace": "0"}, "Database.Actions/COMPACT")
    Do ..Both(4, "defragment", tC, tD, "OcuPilot.Screen.Tool.DatabaseDefragment", "", "Database.Actions/DEFRAGMENT")
    Do ..Both(6, "expand", "OCUPROBE184GA", "OCUPROBE184GB", "OcuPilot.Screen.Tool.LocalDatabaseExpand", {"InitialSize": "1"}, "Database.Actions/EXPANDVOL")
    Do ..Both(7, "integrity", tA, tB, "OcuPilot.Screen.Tool.DatabaseIntegrityCheck", {"Globals": "[]"}, "Database.Actions/INTEGRITYCHECK")
    Set tSize = ##class(OcuPilot.Test.DatabaseActions).StateOf(tA, "Size")
    Set tBody = {"size": {}}
    Do tBody.%Get("size").%Set("Size", tSize + 2, "number")
    Set tRun = ..RunAs(..User(6), [{"kind": "update", "name": "OCUPROBE184GA", "body": (tBody)}])
    Set tLeg = ..Leg(tRun, 1)
    Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http"), 1: ""), 200, "the size grow's Save succeeds for Local databases' pairs and %Admin_Operate:USE (" _ ..LegText(tRun, 1) _ ")")
    Do $$$AssertTrue($IsObject(tLeg) && $ListFind($ListFromString(tLeg.%Get("types")), "Database.Actions/MODIFYSIZE"), "reaching the port's size grow")
    Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseActions).StateOf(tA, "Size"), tSize + 2, "and the file reads the new size")
    Set tProposal = ..MintFor(..User(6), "OcuPilot.Screen.Tool.LocalDatabaseGrow", "OCUPROBE184GB", {"Size": (##class(OcuPilot.Test.DatabaseActions).StateOf(tB, "Size") + 2)})
    Set tRun = ..RunAs(..User(6), [{"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))}])
    Set tLeg = ..Leg(tRun, 1)
    Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http"), 1: ""), 200, "the agent's size grow confirm succeeds (" _ ..LegText(tRun, 1) _ ")")
    Do $$$AssertTrue($IsObject(tLeg) && $ListFind($ListFromString(tLeg.%Get("types")), "Database.Actions/MODIFYSIZE"), "reaching the port's size grow")
}

/// <p>Run <var>pAction</var> on the screen against <var>pScreenId</var> and the agent's confirm of
/// <var>pToolClass</var> against <var>pAgentId</var>, as principal <var>pIndex</var>, each succeeding and
/// reaching <var>pType</var>.</p>
Method Both(pIndex As %Integer, pAction As %String, pScreenId As %String, pAgentId As %String, pToolClass As %String, pValues As %DynamicObject, pType As %String)
{
    Set tUser = ..User(pIndex)
    Set tRun = ..Legs(tUser, pAction, pScreenId, pToolClass, pValues, pAgentId)
    For tLeg = 1, 2 {
        Set tOne = ..Leg(tRun, tLeg)
        Do $$$AssertEquals($Select($IsObject(tOne): tOne.%Get("http"), 1: ""), 200, tUser _ " " _ pAction _ ": " _ $Select(tLeg = 1: "the screen's action", 1: "the agent's confirm") _ " succeeds (" _ ..LegText(tRun, tLeg) _ ")")
        Do $$$AssertTrue($IsObject(tOne) && $ListFind($ListFromString(tOne.%Get("types")), pType), tUser _ " " _ pAction _ ": and reaches " _ pType)
    }
}

/// <p>Mint <var>pToolClass</var>'s proposal against <var>pAgentId</var> (<var>pScreenId</var> when
/// empty) for <var>pUser</var>, then run as <var>pUser</var> the screen's <var>pAction</var> against
/// <var>pScreenId</var> with <var>pValues</var> and the confirm, answering what the child
/// signalled.</p>
Method Legs(pUser As %String, pAction As %String, pScreenId As %String, pToolClass As %String, pValues As %DynamicObject, pAgentId As %String = "") As %DynamicObject
{
    Set tAgentId = $Select(pAgentId = "": pScreenId, 1: pAgentId)
    Set tArgs = {}
    If $IsObject(pValues) {
        Set tIterator = pValues.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            If tKey = "Globals" {
                Do tArgs.%Set(tKey, [])
            } ElseIf (tValue = "true") || (tValue = "false") {
                Do tArgs.%Set(tKey, (tValue = "true"), "boolean")
            } Else {
                Do tArgs.%Set(tKey, +tValue, "number")
            }
        }
    }
    Set tProposal = ..MintFor(pUser, pToolClass, tAgentId, tArgs)
    Do $$$AssertTrue($IsObject(tProposal), pUser _ " " _ pAction _ ": the agent's proposal is minted for the principal")
    Set tScreen = $Select(pToolClass [ "LocalDatabase": "osmgmt.localdatabases", pToolClass [ "IntegrityCheck": "osmgmt.databases", 1: "osmgmt.databasedetails")
    Set tStep = {"kind": "act"}
    Do tStep.%Set("screen", tScreen, "string")
    Do tStep.%Set("action", pAction, "string")
    Do tStep.%Set("id", pScreenId, "string")
    If $IsObject(pValues) Do tStep.%Set("values", pValues)
    Set tPlan = []
    Do tPlan.%Push(tStep)
    Do tPlan.%Push({"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))})
    Set tRun = ..RunAs(pUser, tPlan)
    Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseWriteGate).Ran(tRun), pUser _ " 1", "the child process ran as " _ pUser)
    Quit tRun
}

/// <p>Mint <var>pToolClass</var>'s proposal against <var>pId</var> with <var>pArgs</var> for
/// <var>pUser</var>, over a completed turn seeded for that user, or <code>""</code>.</p>
Method MintFor(pUser As %String, pToolClass As %String, pId As %String, pArgs As %DynamicObject) As %DynamicObject
{
    Set tArgs = ##class(%DynamicObject).%FromJSON(pArgs.%ToJSON())
    Do tArgs.%Set($ClassMethod(pToolClass, "IdArgument"), pId, "string")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(pUser, "completed", .tTurn)
    If $$$ISERR(tSC) Quit ""
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Mint($Parameter(pToolClass, "DESCRIPTORCLASS"), $Parameter(pToolClass, "TOOLNAME"), pUser, "", tTurn, tArgs, "OcuPilot.Kernel.Agent.Limits", .tProposal, .tHttp, .tFault, $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "IdParam"), pId, $ClassMethod(pToolClass, "IdArgument"), $ClassMethod(pToolClass, "SettableFields"), pToolClass)
    Quit $Get(tProposal)
}

/// <p>The four probe databases: two guarded by their own resources and two, the compact's and
/// defragment's targets on each caller (a confirm cancels its target's sibling proposals, AD-34), by
/// <parameter>TARGETRESOURCE</parameter>, filled a little so their operations have work; and every
/// tool's key enabled.</p>
Method Seed()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", "OCUPROBE184GA"), "a probe database is created")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", "OCUPROBE184GB"), "and a second")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", "OCUPROBE184GC", "", ..#TARGETRESOURCE), "and a third, guarded by the principals' target resource")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", "OCUPROBE184GD", "", ..#TARGETRESOURCE), "and a fourth, guarded by it too")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Fill", "OCUPROBE184GC", 4), "the third is filled a little")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Fill", "OCUPROBE184GD", 4), "and the fourth")
    Kill tSettings
    For tKey = "osmgmt.databasedetails.mount", "osmgmt.databasedetails.dismount", "osmgmt.databasedetails.truncate", "osmgmt.databasedetails.compact", "osmgmt.databasedetails.defragment", "osmgmt.databases.integrity", "osmgmt.localdatabases.grow", "osmgmt.localdatabases.expand" {
        Set tSettings(tKey) = "enabled"
    }
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "every tool's key is enabled, so only the pairs stand in the way")
}

/// <p>Mount or dismount (<var>pType</var>) the database in <var>pDirectory</var> through the shipped
/// port, as seeding.</p>
ClassMethod Mount(pDirectory As %String, pType As %String) As %Status
{
    Quit ##class(OcuPilot.Test.DatabaseActions).Mount(pDirectory, pType)
}

/// <p>The principal of entry <var>pIndex</var> of <parameter>PRINCIPALS</parameter>.</p>
ClassMethod User(pIndex As %Integer) As %String
{
    Quit $Piece($Piece(..#PRINCIPALS, ",", pIndex), ":", 1)
}

/// <p>Run <class>OcuPilot.Test.DatabaseActionsGateProbe</class> as <var>pUser</var> over
/// <var>pPlan</var> in a child process and answer what it signalled, or an object carrying
/// <code>error</code>.</p>
ClassMethod RunAs(pUser As %String, pPlan As %DynamicArray) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Set tPlan = pPlan.%ToJSON()
        Job ##class(OcuPilot.Test.DatabaseActionsGateProbe).Run($Job, pUser, tPlan)::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 300)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within 300 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

ClassMethod Leg(pRun As %DynamicObject, pIndex As %Integer) As %DynamicObject
{
    Quit ##class(OcuPilot.Test.DatabaseWriteGate).Leg(pRun, pIndex)
}

ClassMethod LegText(pRun As %DynamicObject, pIndex As %Integer) As %String
{
    Quit ##class(OcuPilot.Test.DatabaseWriteGate).LegText(pRun, pIndex)
}

/// <p>Create <parameter>TARGETRESOURCE</parameter>, the throwaway roles and the accounts that hold them,
/// each with the install namespace's code read and its entry's grants, and read each declared grant
/// back.</p>
Method EnsurePrincipals() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        If '##class(Security.Resources).Exists(..#TARGETRESOURCE) {
            Set tSC = ##class(Security.Resources).Create(..#TARGETRESOURCE, "OcuPilot test: the disk operation gate's target (throwaway)", "", "")
            If $$$ISERR(tSC) Quit
        }
        Set tNamespace = ##class(Config.Namespaces).Open(tInstallNs)
        Set tDatabase = ##class(Config.Databases).Open(tNamespace.Routines)
        Set tCode = ##class(SYS.Database).%OpenId(tDatabase.Directory).ResourceName _ ":R"
        For tI = 1:1:$Length(..#PRINCIPALS, ",") {
            Set tEntry = $Piece(..#PRINCIPALS, ",", tI)
            Set tUser = $Piece(tEntry, ":", 1)
            Set tRole = $Piece(tEntry, ":", 2)
            Set tGrants = $Translate($Piece(tEntry, ":", 3, *), ";", ",")
            If ##class(Security.Users).Exists(tUser) Do ##class(Security.Users).Delete(tUser)
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
            Set tSC = ##class(Security.Roles).Create(tRole, "OcuPilot test: the disk operation gate (throwaway)", tCode _ "," _ tGrants, "")
            If $$$ISERR(tSC) Quit
            Set tSC = ##class(Security.Users).Create(tUser, tRole, ..PreparedPassword, "OcuPilot disk operation test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.DatabaseActionsGate; deleted in OnAfterAllTests")
            If $$$ISERR(tSC) Quit
            For tJ = 1:1:$Length(tGrants, ",") {
                Set tGrant = $Piece(tGrants, ",", tJ)
                For tK = 1:1:$Length($Piece(tGrant, ":", 2)) {
                    Set tPermission = $Case($Extract($Piece(tGrant, ":", 2), tK), "R": "READ", "W": "WRITE", "U": "USE", : "")
                    If $SYSTEM.Security.CheckUserPermission(tUser, $Piece(tGrant, ":", 1), tPermission) '= 1 {
                        Set tSC = $$$ERROR($$$GeneralError, "the throwaway principal " _ tUser _ "'s grant " _ tGrant _ " did not read back as declared")
                        Quit
                    }
                }
                If $$$ISERR(tSC) Quit
            }
            If $$$ISERR(tSC) Quit
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

}
