/// <p>Pins Story 18.16's remote database writes on both callers of each tool (AD-53, AD-55): the
/// form's Save (<class>OcuPilot.Test.RemoteDatabaseSaveFixture</class>) and row action
/// (<class>OcuPilot.Test.RemoteDatabaseActionFixture</class>), and the agent's mint and confirm
/// (<class>OcuPilot.Test.DatabaseConfirm</class>) -- the matrix's create, re-point, owner's-rule,
/// unlisted, absent, name, delete, in-use, local-target and protected legs.</p>
/// <p>The vendor's writes are real; only the data server's listing is seamed
/// (<class>OcuPilot.Test.RemoteDatabaseListingPort</class>, licensed for the class), which also records
/// every call the port makes, so a refusal shows as a recorded call or none.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class defines a probe ECP
/// data server (configuration only, never contacted), creates and deletes probe remote configurations,
/// a probe local database and a probe namespace with a mapping
/// (<class>OcuPilot.Test.RemoteDatabaseProbe</class>), and sets the governance policy. Every probe
/// object is removed by exact name before all, after each and after all.</p>
Class OcuPilot.Test.RemoteDatabaseWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_DATABASE_CONFIG";

Parameter PROBE = "OcuPilot.Test.RemoteDatabaseProbe";

Parameter SEAM = "OcuPilot.Test.RemoteDatabaseListingPort";

Parameter RECORD = "OcuPilot.Test.DatabaseRecordPort";

Parameter SAVE = "OcuPilot.Test.RemoteDatabaseSaveFixture";

Parameter ACTION = "OcuPilot.Test.RemoteDatabaseActionFixture";

Parameter RULES = "OcuPilot.Test.RemoteDatabaseRulesFixture";

Parameter CREATETOOL = "OcuPilot.Screen.Tool.RemoteDatabaseCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.RemoteDatabaseUpdate";

Parameter DELETETOOL = "OcuPilot.Screen.Tool.RemoteDatabaseDelete";

Parameter SCREEN = "osmgmt.remotedatabases";

Parameter DELETEKEY = "osmgmt.remotedatabases.delete";

Parameter SERVER = "OCUPROBE1816SRV";

/// <p>The governance policy as it stood before the class ran, restored after each test.</p>
Property PreparedPolicy [ MultiDimensional ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.RemoteDatabaseWrite creates and deletes probe remote databases, a probe database, a namespace and a data server definition on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

/// <p>Every test runs through the seam, licensed, with the probe data server defined and the agent's
/// delete key enabled over the snapshot.</p>
Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#SEAM, "Clear")
    Set ^||OcuPilotDatabaseWritePort = ..#SEAM
    Set ^||OcuPilotRemoteLicensed = 1
    Kill tSettings
    Set tSettings(..#DELETEKEY) = "enabled"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "SeedServer")
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Do $ClassMethod(..#SEAM, "Clear")
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe object is removed by exact name")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", .tRemaining))
}

/// <p>Create: on both callers the port lists the data server, then sends one configuration
/// <code>PUT</code> with <code>{Server, Directory}</code>; the read-back reads <code>matches</code>, and
/// the row is on Remote databases and not on Local databases.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.RemoteDatabasePort.DirectoryRefusal</method> answers
/// nothing -- the membership check skipped -> the unlisted directory of
/// <method>TestAnUnlistedDirectoryOrUndefinedServerIsRefused</method> is written and that goes red.</p>
Method TestACreateListsThenWritesOnBothCallers()
{
    Set tSC = ..Save("create", "OCUPROBE1816C", {"Name": "OCUPROBE1816C", "Server": (..#SERVER), "Directory": "/ocuprobe1816x/"}, .tHttp, .tCode, .tFields, .tReadBack)
    Do $$$AssertEquals(tHttp _ " " _ tCode _ tFields, "201 ", "the form's create answers 201")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes"), "Database.ConfigCRUD/PUT", "sending one configuration PUT")
    Do $$$AssertEquals(..Keys($ClassMethod(..#RECORD, "BodyOf", "Database.ConfigCRUD/PUT")), "Directory,Server", "with the data server and the directory alone")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Listings"), 1, "after one listing")
    Do $$$AssertEquals(..Verdict(tReadBack), "matches", "and its read-back matches")
    Do $ClassMethod(..#SEAM, "Clear")
    Set ^||OcuPilotRemoteLicensed = 1
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, "OCUPROBE1816A", {"Name": "OCUPROBE1816A", "Server": (..#SERVER), "Directory": "/ocuprobe1816y/"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's create is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Confirm", tProposal, .tResult), "200 ", "and its confirm writes")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes") _ " " _ $ClassMethod(..#SEAM, "Listings"), "Database.ConfigCRUD/PUT 1", "after listing once")
    Do $$$AssertEquals(..Verdict($Select($IsObject($Get(tResult)): tResult.%Get("readBack"), 1: "")), "matches", "and its read-back matches")
    For tCase = $ListBuild("OCUPROBE1816C", "/ocuprobe1816x/"), $ListBuild("OCUPROBE1816A", "/ocuprobe1816y/") {
        Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", $List(tCase, 1), "Server") _ " " _ $ClassMethod(..#PROBE, "Stored", $List(tCase, 1), "Directory"), ..#SERVER _ " " _ $List(tCase, 2), $List(tCase, 1) _ " names the data server and the directory")
    }
    Set tRemote = $ClassMethod(..#PROBE, "ListText", "OcuPilot.Screen.Descriptor.RemoteDatabaseList", "Name")
    Set tLocal = $ClassMethod(..#PROBE, "ListText", "OcuPilot.Screen.Descriptor.LocalDatabaseList", "Name")
    Do $$$AssertTrue((tRemote [ ",OCUPROBE1816C,") && (tRemote [ ",OCUPROBE1816A,"), "both are listed on Remote databases")
    Do $$$AssertTrue((tLocal '= "") && '(tLocal [ ",OCUPROBE1816C,") && '(tLocal [ ",OCUPROBE1816A,"), "and Local databases answers, naming neither")
}

/// <p>Re-point: on both callers the complete set read fresh is sent, one diff row moves the
/// directory, and the read-back matches.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.RemoteDatabaseUpdate.MergeUpdate</method> sends
/// only the changed fields -> the body's keys shrink and this goes red.</p>
Method TestARePointSendsTheCompleteSetReadFresh()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedRemote", "OCUPROBE1816R"), "a probe remote database is created")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedRemote", "OCUPROBE1816S"), "and a second")
    Set tAll = "ClusterMountMode,Directory,MountAtStartup,MountRequired,Server,StreamLocation"
    Set tSC = ..Save("update", "OCUPROBE1816R", {"Directory": "/ocuprobe1816y/"}, .tHttp, .tCode, .tFields, .tReadBack)
    Do $$$AssertEquals(tHttp _ " " _ tCode _ tFields, "200 ", "the form's re-point answers 200")
    Do $$$AssertEquals(..Keys($ClassMethod(..#RECORD, "BodyOf", "Database.ConfigCRUD/PUT")), tAll, "sending the complete set")
    Do $$$AssertEquals(..Verdict(tReadBack), "matches", "and its read-back matches")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, "OCUPROBE1816S", {"Name": "OCUPROBE1816S", "Directory": "/ocuprobe1816x/"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's re-point is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($Select($IsObject(tProposal): tProposal.%Get("changed").%Size(), 1: -1), 1, "with one diff row")
    Do $ClassMethod(..#RECORD, "Clear")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Confirm", tProposal, .tResult), "200 ", "and its confirm writes")
    Do $$$AssertEquals(..Keys($ClassMethod(..#RECORD, "BodyOf", "Database.ConfigCRUD/PUT")), tAll, "the complete set")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", "OCUPROBE1816R", "Directory") _ " " _ $ClassMethod(..#PROBE, "Stored", "OCUPROBE1816S", "Directory"), "/ocuprobe1816y/ /ocuprobe1816x/", "and both directories moved")
}

/// <p>The owner's rule: an omitted directory is refused on Directory before any vendor call, on both
/// callers and at the port; the data server's <code>IRISSYS</code> directory is refused on Directory
/// after the listing and before any write.</p>
/// <p>Mutations (Rule 19): drop the port's empty-directory check -> the port leg makes vendor calls and
/// goes red; drop the <code>IRISSYS</code> check from
/// <method>OcuPilot.Port.RemoteDatabasePort.DirectoryRefusal</method> -> the manager directory is written
/// and goes red.</p>
Method TestTheOwnersRuleRefusesNoDirectoryAndTheManagersDirectory()
{
    Set tManager = $ClassMethod(..#SEAM, "Manager")
    Set tSC = ..Save("create", "OCUPROBE1816N0", {"Name": "OCUPROBE1816N0", "Server": (..#SERVER), "Directory": ""}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tFields, "422 Directory:DATABASE.REMOTEDIRECTORY.NONE", "the form's create without a directory is refused on Directory")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "CallCount") _ " " _ $ClassMethod(..#SEAM, "Listings"), "0 0", "before any vendor call")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, "OCUPROBE1816N1", {"Name": "OCUPROBE1816N1", "Server": (..#SERVER), "Directory": ""}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ "Choose the database's directory"), "the agent's create without one is refused at the mint (" _ tProblem _ ")")
    Kill tQuery
    Set tQuery("name") = "OCUPROBE1816N2"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Database.ConfigCRUD", "PUT", .tQuery, {"Server": (..#SERVER)}, .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Refusal", tSC, tHttp, tFault) _ " calls=" _ $ClassMethod(..#RECORD, "CallCount"), "422 Directory:DATABASE.REMOTEDIRECTORY.NONE calls=0", "and the port refuses one before any vendor call")
    Set tSC = ..Save("create", "OCUPROBE1816M0", {"Name": "OCUPROBE1816M0", "Server": (..#SERVER), "Directory": (tManager)}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tFields, "422 Directory:DATABASE.REMOTEDIRECTORY.MANAGER", "the form's create of the IRISSYS directory is refused on Directory")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, "OCUPROBE1816M1", {"Name": "OCUPROBE1816M1", "Server": (..#SERVER), "Directory": (tManager)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's is minted, the mint listing nothing (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Confirm", tProposal), "422 DATABASE.REMOTEDIRECTORY.MANAGER", "and refused at its confirm")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes"), "", "nothing is written")
    For tName = "OCUPROBE1816N0", "OCUPROBE1816N1", "OCUPROBE1816N2", "OCUPROBE1816M0", "OCUPROBE1816M1" {
        Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, tName _ " is not stored")
    }
}

/// <p>A directory the data server does not list is refused on Directory, and a data server the
/// instance does not define on Server before any listing, on both callers, and nothing is sent.</p>
Method TestAnUnlistedDirectoryOrUndefinedServerIsRefused()
{
    Set tSC = ..Save("create", "OCUPROBE1816U0", {"Name": "OCUPROBE1816U0", "Server": (..#SERVER), "Directory": "/elsewhere/"}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tFields, "422 Directory:DATABASE.REMOTEDIRECTORY.ABSENT", "the form's unlisted directory is refused on Directory")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, "OCUPROBE1816U1", {"Name": "OCUPROBE1816U1", "Server": (..#SERVER), "Directory": "/elsewhere/"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Confirm", tProposal), "422 DATABASE.REMOTEDIRECTORY.ABSENT", "and the agent's at its confirm")
    Do $ClassMethod(..#SEAM, "Clear")
    Set ^||OcuPilotRemoteLicensed = 1
    Set tSC = ..Save("create", "OCUPROBE1816V0", {"Name": "OCUPROBE1816V0", "Server": "OCUPROBE1816NOSRV", "Directory": "/ocuprobe1816x/"}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tFields, "422 Server:DATABASE.SERVER.ABSENT", "the form's undefined data server is refused on Server")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, "OCUPROBE1816V1", {"Name": "OCUPROBE1816V1", "Server": "OCUPROBE1816NOSRV", "Directory": "/ocuprobe1816x/"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ "Choose a data server"), "and the agent's at the mint (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Listings") _ " " _ $ClassMethod(..#RECORD, "Writes"), "0 ", "before any listing, nothing sent")
    For tName = "OCUPROBE1816U0", "OCUPROBE1816U1", "OCUPROBE1816V0", "OCUPROBE1816V1" {
        Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, tName _ " is not stored")
    }
}

/// <p>A name held in another case, or one the instance refuses, is refused on Name on the form, and the
/// agent's is refused at the mint.</p>
Method TestATakenOrMalformedNameIsRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedRemote", "OCUPROBE1816R"), "a probe remote database is created")
    Set tSC = ..Save("create", "ocuprobe1816r", {"Name": "ocuprobe1816r", "Server": (..#SERVER), "Directory": "/ocuprobe1816x/"}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tFields, "422 Name:DATABASE.NAME.TAKEN", "a taken name is refused on Name")
    Set tSC = ..Save("create", "1AB", {"Name": "1AB", "Server": (..#SERVER), "Directory": "/ocuprobe1816x/"}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tFields, "422 Name:DATABASE.NAME.SHAPE", "a malformed one too")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, "ocuprobe1816r", {"Name": "ocuprobe1816r", "Server": (..#SERVER), "Directory": "/ocuprobe1816x/"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ "already present"), "the agent's taken name is refused at the mint (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes") _ $ClassMethod(..#PROBE, "Stored", "OCUPROBE1816R", "Directory"), "/ocuprobe1816r/", "nothing is sent and the database is unchanged")
}

/// <p>Delete: the row action and the agent's confirm each send the configuration <code>DELETE</code>
/// alone, list nothing, and the row leaves the list.</p>
Method TestADeleteSendsOnlyTheConfigurationDelete()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedRemote", "OCUPROBE1816D"), "a probe remote database to delete")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedRemote", "OCUPROBE1816E"), "and the agent's")
    Do $$$AssertEquals(..Delete("screen", "OCUPROBE1816D"), "200 ", "the row action's delete answers 200")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes"), "Database.ConfigCRUD/DELETE", "sending the configuration DELETE alone")
    Do $ClassMethod(..#RECORD, "Clear")
    Do $$$AssertEquals(..Delete("agent", "OCUPROBE1816E"), "200 ", "the agent's confirm too")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes") _ " " _ $ClassMethod(..#SEAM, "Listings"), "Database.ConfigCRUD/DELETE 0", "sending the DELETE alone, listing nothing")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", "OCUPROBE1816D") _ $ClassMethod(..#PROBE, "Holds", "OCUPROBE1816E"), "00", "both are gone")
    Set tRemote = $ClassMethod(..#PROBE, "ListText", "OcuPilot.Screen.Descriptor.RemoteDatabaseList", "Name")
    Do $$$AssertTrue((tRemote '= "") && '(tRemote [ ",OCUPROBE1816D,") && '(tRemote [ ",OCUPROBE1816E,"), "and Remote databases answers, listing neither")
}

/// <p>In use: the dialog's impact names the namespace that maps a global to the database before
/// anything is removed, with no shared-file part, and the delete is refused
/// <code>DATABASE.INUSE</code> on both callers, nothing deleted.</p>
Method TestADatabaseInUseNamesItsNamespaceAndIsRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedRemote", "OCUPROBE1816R"), "a probe remote database")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedMapping", "OCUPROBE1816R"), "which a probe namespace maps a global to")
    Set tImpact = ..RouteImpact("OCUPROBE1816R", .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the dialog's impact answers")
    Do $$$AssertEquals(..Said(tImpact), "remote-database-delete||1|OCUPROBE1816N||0||", "naming the namespace, and no application, with no shared-file part")
    Do $$$AssertEquals(..Delete("screen", "OCUPROBE1816R"), "409 DATABASE.INUSE", "the row action's delete is refused in use")
    Do $$$AssertEquals(..Delete("agent", "OCUPROBE1816R"), "409 DATABASE.INUSE", "and the agent's confirm")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", "OCUPROBE1816R"), 1, "and nothing is deleted")
}

/// <p>A local configuration named to a remote tool: the re-point and the delete are refused
/// <code>DATABASE.LOCAL</code> on both callers before anything is sent; and Local databases' file edit
/// naming a remote database keeps Story 18.3's <code>DATABASE.REMOTE</code>.</p>
/// <p>Mutation (Rule 19): the port's configuration <code>DELETE</code> drops its
/// <code>DATABASE.LOCAL</code> refusal -> the local probe's configuration is deleted and this goes
/// red.</p>
Method TestALocalTargetIsRefusedLocal()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedLocal"), "a probe local database")
    Set tLocal = $Parameter(..#PROBE, "LOCALNAME")
    Set tHeld = $ClassMethod(..#PROBE, "Stored", tLocal, "Directory")
    Set tSC = ..Save("update", tLocal, {"Directory": "/ocuprobe1816x/"}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tCode _ tFields, "409 DATABASE.LOCAL", "the form's re-point of a local database is refused")
    Do $$$AssertEquals(..Delete("screen", tLocal), "409 DATABASE.LOCAL", "and the row action's delete")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, tLocal, {"Name": (tLocal), "Directory": "/ocuprobe1816x/"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Confirm", tProposal), "409 DATABASE.LOCAL", "the agent's re-point at its confirm (" _ tProblem _ ")")
    Do $$$AssertEquals(..Delete("agent", tLocal), "409 DATABASE.LOCAL", "and its delete")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes") _ $ClassMethod(..#SEAM, "Listings"), "0", "nothing is sent and nothing listed")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tLocal, "Directory"), tHeld, "and the local database is unchanged")
    Do $$$AssertStatusOK($ClassMethod(..#RULES, "Route", "form", tLocal, .tAnswer, .tStatus), "the remote form's read runs")
    Set tCode = ""
    Try { Set tCode = ##class(%DynamicObject).%FromJSON(tAnswer).%Get("code") } Catch {}
    Do $$$AssertEquals(tStatus _ " " _ tCode, "409 DATABASE.LOCAL", "and refuses to open a local database: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedRemote", "OCUPROBE1816R"), "a probe remote database")
    Kill tQuery
    Set tQuery("name") = "OCUPROBE1816R"
    Set tSC = ##class(OcuPilot.Port.DatabasePort).Invoke("Database.SysCRUD", "GET", .tQuery, "", .tFile, .tHttp, .tFault)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Refusal", tSC, tHttp, tFault), "409 DATABASE.REMOTE", "Local databases' file read of a remote database keeps its refusal")
}

/// <p>Protected targets: the remote re-point and delete of <code>IRISSYS</code> and of OcuPilot's own
/// database are refused <code>PROHIBITED.OCUPILOTDATABASE</code> on both callers, and nothing is
/// sent.</p>
Method TestAProtectedTargetIsRefused()
{
    Set tOwn = $ZConvert($Parameter("OcuPilot.Kernel.State.Base", "DATABASENAME"), "U")
    For tName = "IRISSYS", tOwn {
        Set tSC = ..Save("update", tName, {"Directory": "/ocuprobe1816x/"}, .tHttp, .tCode, .tFields)
        Do $$$AssertEquals(tHttp _ " " _ tCode, "403 PROHIBITED.OCUPILOTDATABASE", tName _ ": the form's re-point is refused")
        Do $$$AssertEquals(..Delete("screen", tName), "403 PROHIBITED.OCUPILOTDATABASE", tName _ ": and the row action's delete")
        Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, tName, {"Name": (tName), "Directory": "/ocuprobe1816x/"}, .tProposal, .tHttp, .tProblem)
        Do $$$AssertEquals($ClassMethod(..#PROBE, "Confirm", tProposal), "403 PROHIBITED.OCUPILOTDATABASE", tName _ ": the agent's re-point at its confirm (" _ tProblem _ ")")
        Do $$$AssertEquals(..Delete("agent", tName), "403 PROHIBITED.OCUPILOTDATABASE", tName _ ": and its delete")
    }
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes"), "", "nothing is sent")
}

/// <p>The form's Save of <var>pKind</var> -- <code>create</code> or <code>update</code> -- for
/// <var>pName</var> with <var>pBody</var>: <var>pHttp</var> the status it would answer, <var>pCode</var>
/// a refusal's code, <var>pFields</var> its violations as <code>field:code</code> and
/// <var>pReadBack</var> an accepted Save's read-back.</p>
ClassMethod Save(pKind As %String, pName As %String, pBody As %DynamicObject, Output pHttp As %Integer, Output pCode As %String, Output pFields As %String, Output pReadBack As %DynamicObject) As %Status
{
    Set pCode = ""
    Set pFields = ""
    Set pReadBack = ""
    If pKind = "create" {
        Set tSC = $ClassMethod(..#SAVE, "Create", pName, pBody, .tHttp, .tFault, .tViolations, .pReadBack)
        Set pHttp = 201
    } Else {
        Set tSC = $ClassMethod(..#SAVE, "Update", ..#UPDATETOOL, pName, pBody, .tHttp, .tFault, .tViolations, .pReadBack)
        Set pHttp = 200
    }
    If $Get(tViolations) > 0 {
        Set pHttp = 422
        For tI = 1:1:tViolations {
            Set pFields = pFields _ $Select(pFields = "": "", 1: ",") _ $List(tViolations(tI), 1) _ ":" _ $List(tViolations(tI), 2)
        }
        Quit $$$OK
    }
    If $$$ISERR(tSC) {
        Set pHttp = +$Get(tHttp)
        Set pCode = $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: $System.Status.GetErrorText(tSC))
    }
    Quit $$$OK
}

/// <p>Delete <var>pName</var> through <var>pCaller</var>'s path -- the row action or the agent's mint
/// and confirm -- answering <code>http code</code>.</p>
ClassMethod Delete(pCaller As %String, pName As %String) As %String
{
    If pCaller = "agent" {
        Set tSC = $ClassMethod(..#PROBE, "Mint", ..#DELETETOOL, pName, {"Name": (pName)}, .tProposal, .tHttp, .tProblem)
        If '$IsObject(tProposal) Quit "not minted " _ tHttp _ " " _ tProblem
        Quit $ClassMethod(..#PROBE, "Confirm", tProposal)
    }
    Set tBody = {"action": "delete"}
    Do tBody.%Set("id", pName, "string")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, tBody, .tAnswer, .tStatus)
    Set tCode = ""
    Try { Set tCode = ##class(%DynamicObject).%FromJSON(tAnswer).%Get("code") } Catch {}
    Quit tStatus _ " " _ tCode
}

/// <p>The dialog's impact for deleting <var>pName</var>, read over the wire as the suite's account, or
/// <code>""</code>; <var>pStatus</var> is the route's status.</p>
ClassMethod RouteImpact(pName As %String, Output pStatus As %Integer) As %DynamicObject
{
    Set tPath = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/screens/" _ ..#SCREEN _ "/impact?action=delete&id=" _ $ZConvert(pName, "O", "URL")
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tRaw, .tHeaders)
    Set tImpact = ""
    Try { Set tImpact = ##class(%DynamicObject).%FromJSON(tRaw).%Get("impact") } Catch {}
    Quit tImpact
}

/// <p><var>pImpact</var> as <code>kind|refused|part...</code>, each part
/// <code>count|names|unchecked</code>.</p>
ClassMethod Said(pImpact As %DynamicObject) As %String
{
    If '$IsObject(pImpact) Quit "(no impact)"
    Set tOut = pImpact.%Get("kind") _ "|" _ $Select($IsObject(pImpact.%Get("refused")): pImpact.refused.code, 1: "")
    Set tIterator = pImpact.%Get("parts").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tPart) {
        Set tNames = ""
        Set tNameIterator = tPart.%Get("names").%GetIterator()
        While tNameIterator.%GetNext(.tNameIndex, .tName) {
            Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tName
        }
        Set tOut = tOut _ "|" _ tPart.%Get("count") _ "|" _ tNames _ "|" _ tPart.%Get("unchecked")
    }
    Quit tOut
}

/// <p>A read-back's verdict, or <code>(none)</code>.</p>
ClassMethod Verdict(pReadBack As %DynamicObject) As %String
{
    If '$IsObject($Get(pReadBack)) Quit "(none)"
    Quit pReadBack.%Get("verdict")
}

/// <p>The top-level keys of the JSON object text <var>pJson</var>, sorted, comma-separated.</p>
ClassMethod Keys(pJson As %String) As %String
{
    Set tObject = ""
    Try { If pJson '= "" Set tObject = ##class(%DynamicObject).%FromJSON(pJson) } Catch {}
    If '$IsObject(tObject) Quit ""
    Kill tSorted
    Set tIterator = tObject.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tSorted(tKey) = ""
    }
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tSorted(tKey))
        If tKey = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tKey
    }
    Quit tOut
}

}
