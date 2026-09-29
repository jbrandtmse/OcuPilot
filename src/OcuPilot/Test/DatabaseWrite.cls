/// <p>Pins Story 18.3's database writes on both callers of each tool (AD-53, AD-55): the screen's Save
/// (<class>OcuPilot.Test.DatabaseSaveFixture</class>) and row action
/// (<class>OcuPilot.Test.DatabaseActionFixture</class>), and the agent's mint and confirm
/// (<class>OcuPilot.Test.DatabaseConfirm</class>) -- one method per row of the spec's matrix, the
/// delete's impact (AD-8) and the own-database refusal (AD-10).</p>
/// <p>A write that should happen goes through <class>OcuPilot.Test.DatabaseRecordPort</class>, which
/// records every call <class>OcuPilot.Port.DatabasePort</class> sequences and sends it; the protected
/// legs write through <class>OcuPilot.Test.DatabaseAcceptPort</class>, which reads the instance and
/// sends no write, so a removed predicate shows as a recorded write and never as a changed or deleted
/// database.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, the manager directory
/// among the allowed directories, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>,
/// because the class creates and deletes databases, their files, directories and resources, probe
/// namespaces, a mapping and web applications (<class>OcuPilot.Test.DatabaseWriteProbe</class>), and
/// sets the governance policy. <method>OnBeforeAllTests</method> refuses anywhere it does not; every
/// probe object is removed by exact name before all, after each and after all, and a survivor fails
/// the class.</p>
Class OcuPilot.Test.DatabaseWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_DATABASE_CONFIG";

Parameter PROBE = "OcuPilot.Test.DatabaseWriteProbe";

Parameter SAVE = "OcuPilot.Test.DatabaseSaveFixture";

Parameter ACTION = "OcuPilot.Test.DatabaseActionFixture";

Parameter CONFIRM = "OcuPilot.Test.DatabaseConfirm";

Parameter RECORD = "OcuPilot.Test.DatabaseRecordPort";

Parameter ACCEPT = "OcuPilot.Test.DatabaseAcceptPort";

Parameter CREATETOOL = "OcuPilot.Screen.Tool.LocalDatabaseCreate";

Parameter MOUNTTOOL = "OcuPilot.Screen.Tool.LocalDatabaseUpdateMount";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.LocalDatabaseUpdate";

Parameter DELETETOOL = "OcuPilot.Screen.Tool.LocalDatabaseDelete";

Parameter SCREEN = "osmgmt.localdatabases";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Parameter DELETEKEY = "osmgmt.localdatabases.delete";

Parameter OWNCODE = "PROHIBITED.OCUPILOTDATABASE";

/// <p>A probe resource an existing-resource create and a resource change name.</p>
Parameter PROBERESOURCE = "%DB_OCUPROBE183RX";

/// <p>The four routes, relative to the API base.</p>
Parameter FORMPATH = "/database/form";

Parameter CHECKPATH = "/database/check";

Parameter EDITPATH = "/database/:id";

Parameter CREATEPATH = "/database";

/// <p>The governance policy as it stood before the class ran, restored after each test.</p>
Property PreparedPolicy [ MultiDimensional ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DatabaseWrite creates and deletes databases, their files and resources, namespaces and web applications on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort, ^||OcuPilotDatabaseProhibited, ^||OcuPilotDatabaseOwnProbe, ^||OcuPilotDatabaseOwnFail
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("")
    Do $ClassMethod(..#RECORD, "Clear")
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe database object is removed by exact name")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

/// <p>Remove every probe object; a failing status when any survives or the configuration file no
/// longer validates or still names a probe database.</p>
Method OnAfterAllTests() As %Status
{
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", .tRemaining))
    If '$ClassMethod(..#PROBE, "CpfValid", .tNamesProbe) || tNamesProbe Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the configuration file does not validate, or names a probe database, after OcuPilot.Test.DatabaseWrite"))
    Quit tSC
}

/// <p>Create: on both callers the calls run the resource's <code>PUT</code>, the file's
/// <code>POST</code> with <code>{Directory, Size, GlobalJournalState, ResourceName}</code> and the
/// configuration's <code>PUT</code> with <code>{Directory}</code>, in that order, and the database reads
/// mounted, with the journal state asked for and guarded by <code>%DB_&lt;NAME&gt;</code>, which
/// exists; both appear on Local databases and on Databases.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.DatabasePort</class> skips the resource step -> the
/// read-back finds no resource and this goes red.</p>
Method TestACreateRunsTheResourceTheFileAndTheConfigurationInOrder()
{
    Set ^||OcuPilotDatabaseWritePort = ..#RECORD
    Set tRoot = $ClassMethod(..#PROBE, "Manager")
    Set tOrder = "Security.Resource/PUT,Database.SysCRUD/POST,Database.ConfigCRUD/PUT"
    Set tScreen = "OCUPROBE183SC"
    Set tSC = ..Save("create", tScreen, {"Name": (tScreen), "root": (tRoot), "path": "ocuprobe183sc", "Size": 1, "GlobalJournalState": true}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tCode _ tFields, "201 ", "the screen's create answers 201")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes"), tOrder, "the resource, the file and the configuration, in that order")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "TargetOf", "Database.ConfigCRUD/PUT"), tScreen, "the configuration is written under its name")
    Do $$$AssertEquals(..Keys($ClassMethod(..#RECORD, "BodyOf", "Database.SysCRUD/POST")) _ "|" _ ..Keys($ClassMethod(..#RECORD, "BodyOf", "Database.ConfigCRUD/PUT")), "Directory,GlobalJournalState,ResourceName,Size|Directory", "the file is made with its four keys and the configuration with its directory alone")

    Do $ClassMethod(..#RECORD, "Clear")
    Set tAgent = "OCUPROBE183AC"
    Set tSC = ..Mint(..#CREATETOOL, tAgent, {"Name": (tAgent), "root": (tRoot), "path": "ocuprobe183ac", "GlobalJournalState": false}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's create is minted (" _ tProblem _ ")")
    Do $$$AssertEquals(..Confirm(tProposal), "200 ", "and confirmed")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes"), tOrder, "in the same order")
    Do $$$AssertEquals(..Keys($ClassMethod(..#RECORD, "BodyOf", "Database.SysCRUD/POST")) _ "|" _ ..Keys($ClassMethod(..#RECORD, "BodyOf", "Database.ConfigCRUD/PUT")), "Directory,GlobalJournalState,ResourceName,Size|Directory", "with the same bodies")

    For tCase = $ListBuild(tScreen, "true"), $ListBuild(tAgent, "false") {
        Set tName = $List(tCase, 1)
        Set tDirectory = $ClassMethod(..#PROBE, "DirectoryFor", $Extract(tName, 12, *))
        Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName, "Directory"), tDirectory, tName _ ": the configuration names the resolved directory")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "Mounted", tDirectory), 1, tName _ ": the file reads mounted")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredFile", tDirectory, "GlobalJournalState"), $List(tCase, 2), tName _ ": journaled as asked")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredFile", tDirectory, "ResourceName"), "%DB_" _ tName, tName _ ": guarded by %DB_<NAME>")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "HoldsResource", "%DB_" _ tName), 1, tName _ ": which exists")
    }
    Set tLocal = ..ListText("OcuPilot.Screen.Descriptor.LocalDatabaseList", "Name")
    Set tFiles = ..ListText("OcuPilot.Screen.Descriptor.DatabaseList", "Directory")
    For tName = tScreen, tAgent {
        Do $$$AssertTrue(tLocal [ ("," _ tName _ ","), tName _ " is listed on Local databases")
        Do $$$AssertTrue($ZConvert(tFiles, "L") [ ("," _ $ClassMethod(..#PROBE, "DirectoryFor", $Extract(tName, 12, *)) _ ","), tName _ "'s file is listed on Databases")
    }
}

/// <p>Existing resource: a create naming an existing <code>%DB_*</code> resource creates none, and the
/// file is guarded by the one named, on both callers.</p>
Method TestAnExistingResourceGuardsTheFileAndNoneIsCreated()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddResource", ..#PROBERESOURCE), "a probe resource exists")
    Set ^||OcuPilotDatabaseWritePort = ..#RECORD
    Set tRoot = $ClassMethod(..#PROBE, "Manager")
    Set tScreen = "OCUPROBE183RS"
    Set tSC = ..Save("create", tScreen, {"Name": (tScreen), "root": (tRoot), "path": "ocuprobe183rs", "ResourceName": (..#PROBERESOURCE)}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tCode _ tFields, "201 ", "the screen's create answers 201")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes"), "Database.SysCRUD/POST,Database.ConfigCRUD/PUT", "no resource is created")
    Do $ClassMethod(..#RECORD, "Clear")
    Set tAgent = "OCUPROBE183RA"
    Set tSC = ..Mint(..#CREATETOOL, tAgent, {"Name": (tAgent), "root": (tRoot), "path": "ocuprobe183ra", "ResourceName": (..#PROBERESOURCE)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's create is minted (" _ tProblem _ ")")
    Do $$$AssertEquals(..Confirm(tProposal), "200 ", "and confirmed")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes"), "Database.SysCRUD/POST,Database.ConfigCRUD/PUT", "and no resource is created there either")
    For tName = tScreen, tAgent {
        Set tDirectory = $ClassMethod(..#PROBE, "DirectoryFor", $Extract(tName, 12, *))
        Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredFile", tDirectory, "ResourceName"), ..#PROBERESOURCE, tName _ ": guarded by the resource named")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "HoldsResource", "%DB_" _ tName), 0, tName _ ": and %DB_<NAME> was never made")
    }
}

/// <p>Name taken: a present name in another case is refused on Name at the Save and at the mint, and
/// nothing is sent.</p>
/// <p>Mutation (Rule 19): drop <parameter>OcuPilot.Screen.Tool.LocalDatabaseCreate.CREATES</parameter>
/// -> the mint reads the present configuration as the target of a change, and this goes red.</p>
Method TestATakenNameIsRefusedInAnyCase()
{
    Set tName = "OCUPROBE183TK"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName), "a probe database is created")
    Set tHeld = $ClassMethod(..#PROBE, "Stored", tName, "Directory")
    Set ^||OcuPilotDatabaseWritePort = ..#RECORD
    Set tRoot = $ClassMethod(..#PROBE, "Manager")
    Set tBody = {"Name": "ocuprobe183tk", "root": (tRoot), "path": "ocuprobe183tkagain"}
    Set tSC = ..Save("create", "ocuprobe183tk", tBody, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tFields, "422 Name:DATABASE.NAME.TAKEN", "the screen's create is refused on Name")
    Set tSC = ..Mint(..#CREATETOOL, "ocuprobe183tk", tBody, .tProposal, .tHttp, .tProblem)
    Do $$$AssertTrue('$IsObject(tProposal) && (tHttp = 400) && (tProblem [ "already present"), "the agent's create is refused at the mint as a name the instance holds (" _ tHttp _ " " _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes"), "", "nothing is sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName, "Directory"), tHeld, "and the configuration is unchanged")
}

/// <p>Rolled back: when the configuration's <code>PUT</code> fails after the file was made, the port
/// deletes the file it created and answers the fault with <code>detail.rolledBack</code> true.</p>
Method TestARefusedConfigurationRollsTheFileBack()
{
    Set ^||OcuPilotDatabaseWritePort = ..#RECORD
    Do $ClassMethod(..#RECORD, "FailOn", "Database.ConfigCRUD/PUT")
    Set tName = "OCUPROBE183RB"
    Set tDirectory = $ClassMethod(..#PROBE, "DirectoryFor", "rb")
    Set tSC = $ClassMethod(..#SAVE, "Create", tName, {"Name": (tName), "root": ($ClassMethod(..#PROBE, "Manager")), "path": "ocuprobe183rb"}, .tHttp, .tFault, .tViolations, .tReadBack)
    Do $$$AssertStatusNotOK(tSC, "the create fails")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("rolledBack"), 1: ""), 1, "answering that the file was rolled back")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes"), "Security.Resource/PUT,Database.SysCRUD/POST,Database.ConfigCRUD/PUT,Database.SysCRUD/DELETE", "the file's delete follows the refused configuration")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "HoldsFile", tDirectory), 0, "no database file is left")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, "and no configuration")
}

/// <p>A later step that fails is answered as far as the write landed: a file delete refused after the
/// configuration's delete answers 200 with <code>fileDeleted</code> false and the configuration gone;
/// a configuration list that fails keeps the file, sending no file delete; and a create whose
/// rollback fails too answers <code>detail.rolledBack</code> false.</p>
Method TestAFailedLaterStepIsAnsweredAsFarAsItLanded()
{
    For tCase = $ListBuild("OCUPROBE183FD", "Database.SysCRUD/DELETE", "Database.ConfigCRUD/DELETE,Database.SysCRUD/DELETE"), $ListBuild("OCUPROBE183FL", "Database.ConfigCRUD/LIST", "Database.ConfigCRUD/DELETE") {
        Set tName = $List(tCase, 1)
        Set tDirectory = $ClassMethod(..#PROBE, "DirectoryFor", $Extract(tName, 12, *))
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName), tName _ " is created")
        Do $ClassMethod(..#RECORD, "Clear")
        Do $ClassMethod(..#RECORD, "FailOn", $List(tCase, 2))
        Kill tQuery
        Set tQuery("name") = tName
        Set tQuery("DeleteFile") = 1
        Set tSC = $ClassMethod(..#RECORD, "Invoke", "Database.ConfigCRUD", "DELETE", .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals($$$ISOK(tSC) _ " " _ $Get(tHttp) _ " " _ $Select($IsObject($Get(tResult)): tResult.%Get("fileDeleted"), 1: ""), "1 200 0", tName _ ": " _ $List(tCase, 2) _ " failing, the delete answers 200 with fileDeleted false")
        Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes"), $List(tCase, 3), tName _ ": after these writes")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName) _ $ClassMethod(..#PROBE, "HoldsFile", tDirectory), "01", tName _ ": the configuration is gone and the file is kept")
    }
    Do $ClassMethod(..#RECORD, "Clear")
    Do $ClassMethod(..#RECORD, "FailOn", "Database.ConfigCRUD/PUT,Database.SysCRUD/DELETE")
    Set ^||OcuPilotDatabaseWritePort = ..#RECORD
    Set tName = "OCUPROBE183RF"
    Set tSC = $ClassMethod(..#SAVE, "Create", tName, {"Name": (tName), "root": ($ClassMethod(..#PROBE, "Manager")), "path": "ocuprobe183rf"}, .tHttp, .tFault, .tViolations, .tReadBack)
    Do $$$AssertStatusNotOK(tSC, "a create whose configuration and rollback both fail fails")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("rolledBack"), 1: ""), 0, "answering that the file was not rolled back")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, "and no configuration was made")
}

/// <p>Taken since the mint (AD-54): a create minted while its name was absent, and confirmed after a
/// configuration of that name was added, is refused <code>PROPOSAL.TARGETCHANGED</code> with nothing
/// sent -- no file, no resource, and the configuration unchanged.</p>
/// <p>Mutation (Rule 19): the confirm's re-read of a create reads its name as absent -> the upsert is
/// sent and this goes red.</p>
Method TestANameTakenSinceTheMintRefusesTheConfirm()
{
    Set ^||OcuPilotDatabaseWritePort = ..#RECORD
    Set tName = "OCUPROBE183TS"
    Set tHeld = $ClassMethod(..#PROBE, "DirectoryFor", "tsheld")
    Set tSC = ..Mint(..#CREATETOOL, tName, {"Name": (tName), "root": ($ClassMethod(..#PROBE, "Manager")), "path": "ocuprobe183ts"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the create is minted while its name is absent (" _ tProblem _ ")")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddConfiguration", tName, tHeld), "and a configuration of that name is added since")
    Do $ClassMethod(..#RECORD, "Clear")
    Do $$$AssertEquals(..Confirm(tProposal), "409 PROPOSAL.TARGETCHANGED", "the confirm is refused as the target having changed")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes"), "", "nothing is sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "HoldsFile", $ClassMethod(..#PROBE, "DirectoryFor", "ts")) _ $ClassMethod(..#PROBE, "HoldsResource", "%DB_" _ tName), "00", "no file and no resource is made")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName, "Directory"), tHeld, "and the configuration is unchanged")
}

/// <p>Edits: each group sends its endpoint's complete set read fresh, on both callers -- the mounting
/// edit the six configuration fields, the file edit the ten file fields with a new volume directory
/// resolved from its root and path -- and the agent's diff shows the one changed row (AD-4).</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Screen.Tool.LocalDatabaseUpdate</class> sends only the changed
/// keys -> the file body is short of the complete set and this goes red.</p>
Method TestTheEditsSendTheirCompleteSets()
{
    Set tName = "OCUPROBE183ED"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName), "a probe database is created")
    Set tDirectory = $ClassMethod(..#PROBE, "DirectoryFor", "ed")
    Set tVolume = $ClassMethod(..#PROBE, "DirectoryFor", "ed-vol")
    Set ^||OcuPilotDatabaseWritePort = ..#RECORD
    Set tSC = ..Save("configuration", tName, {"MountAtStartup": true}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tCode _ tFields, "200 ", "the screen's mounting edit answers 200")
    Do $$$AssertEquals(..Keys($ClassMethod(..#RECORD, "BodyOf", "Database.ConfigCRUD/PUT")), "ClusterMountMode,Directory,MountAtStartup,MountRequired,Server,StreamLocation", "sending the complete configuration set and nothing else")
    Set tSC = ..Save("file", tName, {"ExpansionSize": 5, "NewVolumeThreshold": 10, "volumeRoot": ($ClassMethod(..#PROBE, "Manager")), "volumePath": "ocuprobe183ed-vol"}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tCode _ tFields, "200 ", "the screen's file edit answers 200")
    Set tBody = $ClassMethod(..#RECORD, "BodyOf", "Database.SysCRUD/PUT")
    Do $$$AssertEquals(..Keys(tBody), "ClusterMountMode,ExpansionSize,GlobalJournalState,MaxSize,NewGlobalCollation,NewGlobalIsKeep,NewVolumeDirectory,NewVolumeThreshold,ReadOnly,ResourceName", "sending the complete file set and nothing else")
    Do $$$AssertEquals(..Member(tBody, "NewVolumeDirectory"), tVolume, "the new volume directory is the resolved one")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName, "MountAtStartup") _ " " _ $ClassMethod(..#PROBE, "StoredFile", tDirectory, "ExpansionSize") _ " " _ $ClassMethod(..#PROBE, "StoredFile", tDirectory, "NewVolumeThreshold"), "true 5 10", "which the instance holds")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "HoldsDirectory", tVolume), 1, "and the volume directory exists")

    Do $ClassMethod(..#RECORD, "Clear")
    Set tSC = ..Mint(..#UPDATETOOL, tName, {"Name": (tName), "MaxSize": 50}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's file edit is minted (" _ tProblem _ ")")
    If $IsObject(tProposal) Do $$$AssertEquals(tProposal.changed.%Size() _ " " _ tProposal.changed.%Get(0).field, "1 MaxSize", "its diff shows the one row")
    Do $$$AssertEquals(..Confirm(tProposal), "200 ", "and it is confirmed")
    Do $$$AssertEquals(..Keys($ClassMethod(..#RECORD, "BodyOf", "Database.SysCRUD/PUT")), "ClusterMountMode,ExpansionSize,GlobalJournalState,MaxSize,NewGlobalCollation,NewGlobalIsKeep,NewVolumeDirectory,NewVolumeThreshold,ReadOnly,ResourceName", "sending the complete file set")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredFile", tDirectory, "MaxSize"), 50, "which the instance holds")
    Set tSC = ..Mint(..#MOUNTTOOL, tName, {"Name": (tName), "MountAtStartup": false}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's mounting edit is minted (" _ tProblem _ ")")
    Do $$$AssertEquals(..Confirm(tProposal), "200 ", "and it is confirmed")
    Do $$$AssertEquals(..Keys($ClassMethod(..#RECORD, "BodyOf", "Database.ConfigCRUD/PUT")), "ClusterMountMode,Directory,MountAtStartup,MountRequired,Server,StreamLocation", "sending the complete configuration set")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName, "MountAtStartup"), "false", "which the instance holds")
}

/// <p>Delete, three shapes, on both callers: with the file on, the configuration, the file and its
/// second volume file are gone and the directory and resource remain; with it off, only the
/// configuration is gone; and a file another configuration name shares is kept whatever the option
/// says.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.DatabasePort</class> deletes the file although it is
/// shared -> the shared file is gone and this goes red.</p>
Method TestTheThreeDeleteShapes()
{
    Do $$$AssertStatusOK(..EnableDelete(), "the agent's delete key is enabled")
    Set ^||OcuPilotDatabaseWritePort = ..#RECORD
    For tCase = $ListBuild("OCUPROBE183DF", "screen", "true"), $ListBuild("OCUPROBE183AF", "agent", "true"), $ListBuild("OCUPROBE183DK", "screen", "false"), $ListBuild("OCUPROBE183AK", "agent", "false") {
        Set tName = $List(tCase, 1)
        Set tDirectory = $ClassMethod(..#PROBE, "DirectoryFor", $Extract(tName, 12, *))
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName), tName _ " is created")
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddVolume", tDirectory), tName _ " gains a second volume file")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "HoldsVolume", tDirectory), 1, tName _ ": which is there before the delete")
        Do $$$AssertEquals(..Delete($List(tCase, 2), tName, $List(tCase, 3)), "200 ", tName _ ": the " _ $List(tCase, 2) _ "'s delete answers 200")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, tName _ ": the configuration is gone")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "HoldsFile", tDirectory), ($List(tCase, 3) = "false"), tName _ ": the file is " _ $Select($List(tCase, 3) = "true": "gone", 1: "kept"))
        Do $$$AssertEquals($ClassMethod(..#PROBE, "HoldsVolume", tDirectory), ($List(tCase, 3) = "false"), tName _ ": and so is its second volume file")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "HoldsDirectory", tDirectory) _ $ClassMethod(..#PROBE, "HoldsResource", "%DB_" _ tName), "11", tName _ ": the directory and the resource remain")
    }
    For tCase = $ListBuild("OCUPROBE183SH", "OCUPROBE183SY", "screen"), $ListBuild("OCUPROBE183SA", "OCUPROBE183SB", "agent") {
        Set tName = $List(tCase, 1)
        Set tDirectory = $ClassMethod(..#PROBE, "DirectoryFor", $Extract(tName, 12, *))
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName), tName _ " is created")
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddConfiguration", $List(tCase, 2), tDirectory), $List(tCase, 2) _ " shares its file")
        Do $$$AssertEquals(..Said(..RouteImpact(tName, .tStatus)), "database-delete||0|||0|||1|" _ $List(tCase, 2) _ "|", tName _ ": the advisory names the sharer")
        Do $ClassMethod(..#RECORD, "Clear")
        Do $$$AssertEquals(..Delete($List(tCase, 3), tName, "true"), "200 ", tName _ ": the " _ $List(tCase, 3) _ "'s delete answers 200")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName) _ $ClassMethod(..#PROBE, "Holds", $List(tCase, 2)), "01", tName _ ": only its configuration is gone")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "HoldsFile", tDirectory), 1, tName _ ": and the shared file is kept")
        Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes"), "Database.ConfigCRUD/DELETE", tName _ ": no file delete was sent")
        Do $$$AssertEquals(..Member($ClassMethod(..#RECORD, "AnswerOf", "Database.ConfigCRUD/DELETE"), "fileDeleted"), 0, tName _ ": and the port answered fileDeleted false")
    }
    Kill tQuery
    Set tQuery("name") = "OCUPROBE183SY"
    Set tQuery("DeleteFile") = 1
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Port.DatabasePort", "Invoke", "Database.ConfigCRUD", "DELETE", .tQuery, "", .tResult, .tHttp, .tFault), "the port deletes the last sharer's configuration")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("fileDeleted"), 1: ""), 1, "and, sharing it no more, the file, answering fileDeleted")
}

/// <p>In use: a probe database that a probe namespace uses directly, with a web application in it, and
/// one that a namespace uses only through a mapping, are refused 409
/// <code>DATABASE.INUSE</code> on both callers with nothing removed, and the impact names the
/// namespaces and the application.</p>
Method TestAnInUseDeleteIsRefusedAndRemovesNothing()
{
    Do $$$AssertStatusOK(..EnableDelete(), "the agent's delete key is enabled")
    Do ..SeedInUse()
    Set ^||OcuPilotDatabaseWritePort = ..#RECORD
    For tCase = $ListBuild("OCUPROBE183IU", "database-delete||1|OCUPROBE183NS||1|/csp/ocuprobe183iu||0||"), $ListBuild("OCUPROBE183IM", "database-delete||1|OCUPROBE183NM||0|||0||") {
        Set tName = $List(tCase, 1)
        Set tDirectory = $ClassMethod(..#PROBE, "DirectoryFor", $Extract(tName, 12, *))
        Do $$$AssertEquals(..Said(..RouteImpact(tName, .tStatus)), $List(tCase, 2), tName _ ": the advisory names what uses it")
        Do $$$AssertEquals(..Delete("screen", tName, "true"), "409 DATABASE.INUSE", tName _ ": the screen's delete is refused as in use")
        Do $$$AssertEquals(..Delete("agent", tName, "true"), "409 DATABASE.INUSE", tName _ ": and so is the agent's")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName) _ $ClassMethod(..#PROBE, "HoldsFile", tDirectory), "11", tName _ ": nothing is removed")
    }
}

/// <p>The removal's impact (AD-8), from <method>OcuPilot.Kernel.Proposal.Impact.Of</method>, from the
/// dialog's route and on the agent's proposal row: the namespace that uses the database and the
/// application in it.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Proposal.Impact.KindOf</method> omits
/// <code>database-delete</code> -> no impact is answered and this goes red.</p>
Method TestTheImpactNamesTheNamespacesAndApplications()
{
    Do ..SeedInUse()
    Set tName = "OCUPROBE183IU"
    Set tExpected = "database-delete||1|OCUPROBE183NS||1|/csp/ocuprobe183iu||0||"
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("database-configuration", "instance", tName, .tRef)
    Kill tQuery
    Set tQuery("name") = tName
    Set tSC = ##class(OcuPilot.Port.DatabasePort).Invoke("Database.ConfigCRUD", "GET", .tQuery, "", .tFresh, .tHttp, .tFault)
    Set tImpact = ##class(OcuPilot.Kernel.Proposal.Impact).Of(..#DELETEKEY, tRef, $Select($IsObject($Get(tFresh)): tFresh.%ToJSON(), 1: ""), "{}", "[]")
    Do $$$AssertEquals(..Said(tImpact), tExpected, "Impact.Of names the namespace and the application")
    Do $$$AssertEquals(..Said(..RouteImpact(tName, .tStatus)), tExpected, "and so does the dialog's route (" _ tStatus _ ")")
    Set tSC = ..Mint(..#DELETETOOL, tName, {"Name": (tName), "DeleteFile": false}, .tProposal, .tHttp, , .tTurnKey)
    Do $$$AssertStatusOK(tSC, "the agent's delete is minted")
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedRowsForTurn(tTurnKey, $Username, .tRows)
    Set tRow = $Select($IsObject($Get(tRows)) && (tRows.%Size() = 1): tRows.%Get(0), 1: "")
    Do $$$AssertEquals(..Said($Select($IsObject(tRow): tRow.%Get("impact"), 1: "")), tExpected, "and so does the agent's proposal row")
}

/// <p>The removal's impact names a namespace that uses the database only through a routine mapping,
/// and one that uses it only through a package mapping.</p>
/// <p>Mutation (Rule 19): drop the routine mapping list from
/// <parameter>OcuPilot.Kernel.Proposal.Impact.MAPPINGDESCRIPTORS</parameter> -> the routine mapping's
/// namespace is not named and this goes red.</p>
Method TestTheImpactNamesRoutineAndPackageMappingUsers()
{
    For tName = "OCUPROBE183IX", "OCUPROBE183IB" {
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName), tName _ " is created")
    }
    For tCase = $ListBuild("OCUPROBE183NR", "OcuProbe183Rtn", "Routines"), $ListBuild("OCUPROBE183NP", "OcuProbe183Pkg", "Packages") {
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddNamespace", $List(tCase, 1), "OCUPROBE183IB", "OCUPROBE183IB"), $List(tCase, 1) _ " is created over OCUPROBE183IB")
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddMapping", $List(tCase, 1), $List(tCase, 2), "OCUPROBE183IX", $List(tCase, 3)), $List(tCase, 1) _ " maps " _ $List(tCase, 3) _ " to OCUPROBE183IX")
    }
    Do $$$AssertEquals(..Said(..RouteImpact("OCUPROBE183IX", .tStatus)), "database-delete||2|OCUPROBE183NP,OCUPROBE183NR||0|||0||", "the advisory names both namespaces (" _ tStatus _ ")")
}

/// <p>Governance (AD-22): at the baseline the agent's delete is refused
/// <code>GOVERNANCE.DISABLED</code> and changes nothing, while the screen's own delete proceeds.</p>
Method TestAtTheBaselineTheAgentsDeleteIsDisabledAndTheScreensProceeds()
{
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the baseline alone decides")
    Set tName = "OCUPROBE183GB"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName), "a probe database is created")
    Set ^||OcuPilotDatabaseWritePort = ..#RECORD
    Do $$$AssertEquals(..Delete("agent", tName, "false"), "403 " _ ##class(OcuPilot.Api.Error).#GOVERNANCEDISABLED, "the agent's confirm is refused as disabled by policy")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 1, "and the database is still there")
    Do $$$AssertEquals(..Delete("screen", tName, "false"), "200 ", "the screen's delete proceeds")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, "and removes it")
}

/// <p>Own databases (AD-10): for <code>OCUPILOT</code>, the install namespace's routines database and
/// <code>IRISSYS</code>, a delete and a resource or read-only change are refused
/// <code>PROHIBITED.OCUPILOTDATABASE</code> on both callers with no write sent, the dialog's route
/// states the refusal, and a change of another setting is permitted and reaches the port; each of the
/// seven system databases' deletes is refused too, and the own set holds both the globals and the
/// routines database of a namespace naming two. Every write goes to
/// <class>OcuPilot.Test.DatabaseAcceptPort</class>, which sends none.</p>
/// <p>Mutation (Rule 19): remove the own-name arm of
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Database</method> -> each refused leg is an accepted
/// write recorded by the port, and this goes red.</p>
Method TestTheProtectedDatabasesAreRefusedOnBothCallers()
{
    Do $$$AssertStatusOK(..EnableDelete(), "the agent's delete key is enabled, so only the prohibited set stands in the way")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddResource", ..#PROBERESOURCE), "a probe resource exists")
    Set ^||OcuPilotDatabaseWritePort = ..#ACCEPT
    Set tRoutines = ..InstallRoutines()
    Do $$$AssertTrue(tRoutines '= "", "the install namespace's routines database is read (" _ tRoutines _ ")")
    For tTarget = "OCUPILOT", tRoutines, "IRISSYS" {
        Do $ClassMethod(..#ACCEPT, "Clear")
        Do $$$AssertEquals(..Delete("screen", tTarget, "false"), "403 " _ ..#OWNCODE, tTarget _ ": the screen's delete is refused")
        Do $$$AssertEquals(..Delete("agent", tTarget, "false"), "403 " _ ..#OWNCODE, tTarget _ ": and the agent's")
        For tChange = {"ResourceName": (..#PROBERESOURCE)}, {"ReadOnly": true} {
            Set tField = ..Keys(tChange.%ToJSON())
            Set tSC = ..Save("file", tTarget, tChange, .tHttp, .tCode, .tFields)
            Do $$$AssertEquals(tHttp _ " " _ tCode, "403 " _ ..#OWNCODE, tTarget _ " " _ tField _ ": the screen's edit is refused")
            Do tChange.%Set("Name", tTarget, "string")
            Set tSC = ..Mint(..#UPDATETOOL, tTarget, tChange, .tProposal, .tHttp, .tProblem)
            Do $$$AssertStatusOK(tSC, tTarget _ " " _ tField _ ": the agent's edit is minted (" _ tProblem _ ")")
            Do $$$AssertEquals(..Confirm(tProposal), "403 " _ ..#OWNCODE, tTarget _ " " _ tField _ ": and its confirm is refused")
        }
        Do $$$AssertEquals($ClassMethod(..#ACCEPT, "Writes"), "", tTarget _ ": no write reached the port")
        Set tImpact = ..RouteImpact(tTarget, .tStatus)
        Do $$$AssertEquals($Select($IsObject(tImpact) && $IsObject(tImpact.refused): tImpact.refused.code _ "|" _ tImpact.refused.reason, 1: ""), ..#OWNCODE _ "|" _ ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(..#OWNCODE), tTarget _ ": the delete dialog's advisory states the refusal")
        Set tHeld = $ClassMethod(..#PROBE, "StoredFile", $ClassMethod(..#PROBE, "Stored", tTarget, "Directory"), "ExpansionSize")
        Set tSC = ..Save("file", tTarget, {"ExpansionSize": (tHeld + 1)}, .tHttp, .tCode, .tFields)
        Do $$$AssertEquals(tHttp _ " " _ tCode _ " " _ $ClassMethod(..#ACCEPT, "Writes"), "200  Database.SysCRUD/PUT", tTarget _ ": another setting's change is permitted and reaches the port")
    }
    Set tSystem = $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "SYSTEMDATABASES")
    Do $$$AssertEquals($Length(tSystem, ","), 7, "the classic dialog's seven system databases")
    For tI = 1:1:$Length(tSystem, ",") {
        Set tTarget = $Piece(tSystem, ",", tI)
        Do $ClassMethod(..#ACCEPT, "Clear")
        Do $$$AssertEquals(..Delete("screen", tTarget, "false") _ ", " _ ..Delete("agent", tTarget, "false"), "403 " _ ..#OWNCODE _ ", 403 " _ ..#OWNCODE, tTarget _ ": the delete is refused on both callers")
        Do $$$AssertEquals($ClassMethod(..#ACCEPT, "Writes"), "", tTarget _ ": and no write reached the port")
    }
    Do $ClassMethod(..#RECORD, "ArmNamespace", {"Globals": "OCUPROBE183OG", "Routines": "OCUPROBE183OR"}.%ToJSON())
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).OwnDatabaseNames(..#RECORD, .tOwn)
    Do $$$AssertStatusOK(tSC, "the own names are read through a namespace naming two databases")
    Do $$$AssertEquals((''$ListFind($Get(tOwn), "OCUPROBE183OG")) _ (''$ListFind($Get(tOwn), "OCUPROBE183OR")), "11", "they hold its globals and its routines database")
}

/// <p>A second name over an own database's file (AD-10): with a probe database standing as an own
/// database (<class>OcuPilot.Test.DatabaseProhibitedFixture</class>), a resource change sent through
/// another configuration name over its directory is refused on both callers with no write sent, while
/// another setting's change and that name's own delete are permitted.</p>
/// <p>Mutation (Rule 19): remove the directory arm of
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Database</method> -> the synonym's resource change is an
/// accepted write, and this goes red.</p>
Method TestAResourceChangeThroughASecondNameOverAnOwnFileIsRefused()
{
    Set tOwn = "OCUPROBE183PR"
    Set tSynonym = "OCUPROBE183PS"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tOwn), "a probe database is created")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddConfiguration", tSynonym, $ClassMethod(..#PROBE, "DirectoryFor", "pr")), "and a second name over its file")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddResource", ..#PROBERESOURCE), "a probe resource exists")
    Do $$$AssertStatusOK(..EnableDelete(), "the agent's delete key is enabled")
    Set ^||OcuPilotDatabaseOwnProbe = tOwn
    Set ^||OcuPilotDatabaseProhibited = "OcuPilot.Test.DatabaseProhibitedFixture"
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("OcuPilot.Test.DatabaseProhibitedFixture")
    Set ^||OcuPilotDatabaseWritePort = ..#ACCEPT
    Do $ClassMethod(..#ACCEPT, "Clear")
    Set tSC = ..Save("file", tSynonym, {"ResourceName": (..#PROBERESOURCE)}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "403 " _ ..#OWNCODE, "the screen's resource change through the second name is refused")
    Set tSC = ..Mint(..#UPDATETOOL, tSynonym, {"Name": (tSynonym), "ResourceName": (..#PROBERESOURCE)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's resource change is minted (" _ tProblem _ ")")
    Do $$$AssertEquals(..Confirm(tProposal), "403 " _ ..#OWNCODE, "and its confirm is refused")
    Do $$$AssertEquals($ClassMethod(..#ACCEPT, "Writes"), "", "no write reached the port")
    Set tSC = ..Save("file", tSynonym, {"ExpansionSize": 3}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tCode _ " " _ $ClassMethod(..#ACCEPT, "Writes"), "200  Database.SysCRUD/PUT", "another setting's change through it is permitted")
    Do $ClassMethod(..#ACCEPT, "Clear")
    Do $$$AssertEquals(..Delete("screen", tSynonym, "false"), "200 ", "and the second name's own delete is permitted")
    Do $$$AssertEquals($ClassMethod(..#ACCEPT, "Writes"), "Database.ConfigCRUD/DELETE", "reaching the port")
}

/// <p>A failed own-set read refuses (AD-10): with <class>OcuPilot.Test.DatabaseProhibitedFixture</class>
/// failing the own names read, a probe database's delete is refused
/// <code>PROHIBITED.OCUPILOTDATABASE</code> on both callers; with it failing the own directories read,
/// that database's resource change is refused on both callers; and no write reaches the port.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Proposal.Prohibited.Database</method> carries on with
/// an empty own set when the names read fails -> the delete is an accepted write and this goes red.</p>
Method TestAFailedOwnSetReadRefuses()
{
    Set tName = "OCUPROBE183OF"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName), "a probe database is created")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddResource", ..#PROBERESOURCE), "a probe resource exists")
    Do $$$AssertStatusOK(..EnableDelete(), "the agent's delete key is enabled")
    Set ^||OcuPilotDatabaseProhibited = "OcuPilot.Test.DatabaseProhibitedFixture"
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("OcuPilot.Test.DatabaseProhibitedFixture")
    Set ^||OcuPilotDatabaseWritePort = ..#ACCEPT
    Do $ClassMethod(..#ACCEPT, "Clear")
    Set ^||OcuPilotDatabaseOwnFail = "names"
    Do $$$AssertEquals(..Delete("screen", tName, "false"), "403 " _ ..#OWNCODE, "with the own names unread, the screen's delete is refused")
    Do $$$AssertEquals(..Delete("agent", tName, "false"), "403 " _ ..#OWNCODE, "and the agent's")
    Set ^||OcuPilotDatabaseOwnFail = "directories"
    Set tSC = ..Save("file", tName, {"ResourceName": (..#PROBERESOURCE)}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "403 " _ ..#OWNCODE, "with the own directories unread, the screen's resource change is refused")
    Set tSC = ..Mint(..#UPDATETOOL, tName, {"Name": (tName), "ResourceName": (..#PROBERESOURCE)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's resource change is minted (" _ tProblem _ ")")
    Do $$$AssertEquals(..Confirm(tProposal), "403 " _ ..#OWNCODE, "and its confirm is refused")
    Do $$$AssertEquals($ClassMethod(..#ACCEPT, "Writes"), "", "no write reached the port")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 1, "and the database is still there")
}

/// <p>The four routes over the wire, as the suite's account: <code>POST</code> creates and answers 201
/// <code>{name, readBack}</code> as JSON; the form read answers the configuration and the file; the
/// step check answers <code>{violations}</code>; <code>PUT</code> edits and answers 200, a refused
/// body answers 422 carrying each violation, and a refused second group names the first in
/// <code>detail.applied</code>.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.OsMgmt.DatabaseSave.Answer</method> drops
/// <code>applied</code> -> this goes red.</p>
Method TestTheRoutesAnswerOverTheWire()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    Set tName = "OCUPROBE183WR"
    Set tBody = {"Name": (tName), "path": "ocuprobe183wr"}
    Do tBody.%Set("root", $ClassMethod(..#PROBE, "Manager"), "string")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ ..#CREATEPATH, tUser, tPassword, .tStatus, .tRaw, .tHeaders, tBody.%ToJSON(), "application/json")
    Set tAnswer = ..Parsed(tRaw)
    Do $$$AssertEquals(tStatus, 201, "the create answers 201: " _ $Extract(tRaw, 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("name") _ "|" _ tAnswer.%GetTypeOf("readBack"), 1: ""), tName _ "|object", "naming the database and its read-back")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ ..#FORMPATH _ "?name=" _ tName, tUser, tPassword, .tStatus, .tRaw, .tHeaders)
    Set tAnswer = ..Parsed(tRaw)
    Do $$$AssertEquals(tStatus, 200, "the form read answers 200")
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%GetTypeOf("configuration") _ "|" _ tAnswer.%GetTypeOf("file") _ "|" _ tAnswer.%GetTypeOf("rules") _ "|" _ tAnswer.file.%Get("Directory"), 1: ""), "object|object|array|" _ $ClassMethod(..#PROBE, "DirectoryFor", "wr"), "with the configuration, the file and the rules")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ ..#CHECKPATH, tUser, tPassword, .tStatus, .tRaw, .tHeaders, {"step": "size", "values": {"Size": 0}}.%ToJSON(), "application/json")
    Set tAnswer = ..Parsed(tRaw)
    Do $$$AssertEquals(tStatus, 200, "the step check answers 200")
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Do $$$AssertEquals($Select($IsObject(tAnswer) && (tAnswer.%GetTypeOf("violations") = "array"): tAnswer.violations.%Get(0).field _ " " _ tAnswer.violations.%Get(0).code, 1: ""), "Size DATABASE.SIZE.SHAPE", "with the step's violations")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ $Replace(..#EDITPATH, ":id", tName), tUser, tPassword, .tStatus, .tRaw, .tHeaders, {"file": {"ExpansionSize": 2}}.%ToJSON(), "application/json")
    Set tAnswer = ..Parsed(tRaw)
    Do $$$AssertEquals(tStatus, 200, "the edit answers 200: " _ $Extract(tRaw, 1, 200))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("name") _ "|" _ tAnswer.%GetTypeOf("file"), 1: ""), tName _ "|object", "naming the database and the group it wrote")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ $Replace(..#EDITPATH, ":id", tName), tUser, tPassword, .tStatus, .tRaw, .tHeaders, {"file": {"MaxSize": -1}}.%ToJSON(), "application/json")
    Set tAnswer = ..Parsed(tRaw)
    Do $$$AssertEquals(tStatus, 422, "a refused value answers 422")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("code") _ " " _ tAnswer.detail.violations.%Get(0).code, 1: ""), "DATABASE.VALIDATION DATABASE.MAXSIZE.SHAPE", "on its field")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ $Replace(..#EDITPATH, ":id", tName), tUser, tPassword, .tStatus, .tRaw, .tHeaders, {"configuration": {"MountAtStartup": true}, "file": {"MaxSize": -1}}.%ToJSON(), "application/json")
    Set tAnswer = ..Parsed(tRaw)
    Set tApplied = $Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("detail")) && (tAnswer.detail.%GetTypeOf("applied") = "array"): tAnswer.detail.applied.%ToJSON(), 1: "(none)")
    Do $$$AssertEquals(tStatus _ " " _ tApplied, "422 [""configuration""]", "a refused file group after an applied configuration group names it applied: " _ $Extract(tRaw, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName, "MountAtStartup"), "true", "and the mounting change is stored")
}

/// <p>Seed the in-use probes: <code>OCUPROBE183IU</code>, which the namespace
/// <code>OCUPROBE183NS</code> uses for its globals and routines with the application
/// <code>/csp/ocuprobe183iu</code> in it; and <code>OCUPROBE183IM</code>, which the namespace
/// <code>OCUPROBE183NM</code>, over <code>OCUPROBE183IB</code>, uses only through a global
/// mapping.</p>
Method SeedInUse()
{
    For tName = "OCUPROBE183IU", "OCUPROBE183IM", "OCUPROBE183IB" {
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName), tName _ " is created")
    }
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddNamespace", "OCUPROBE183NS", "OCUPROBE183IU", "OCUPROBE183IU"), "a namespace uses OCUPROBE183IU")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddApplication", "/csp/ocuprobe183iu", "OCUPROBE183NS"), "with an application in it")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddNamespace", "OCUPROBE183NM", "OCUPROBE183IB", "OCUPROBE183IB"), "a namespace over OCUPROBE183IB")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddMapping", "OCUPROBE183NM", "OcuProbe183Map", "OCUPROBE183IM"), "maps a global to OCUPROBE183IM")
}

/// <p>The screen's Save of <var>pKind</var> -- <code>create</code>, or an edit's
/// <code>configuration</code> or <code>file</code> group -- for <var>pName</var> with <var>pBody</var>:
/// <var>pHttp</var> the status it would answer, <var>pCode</var> the refusal's code and
/// <var>pFields</var> its violations as <code>field:code</code>.</p>
ClassMethod Save(pKind As %String, pName As %String, pBody As %DynamicObject, Output pHttp As %Integer, Output pCode As %String, Output pFields As %String) As %Status
{
    Set pCode = ""
    Set pFields = ""
    If pKind = "create" {
        Set tSC = $ClassMethod(..#SAVE, "Create", pName, pBody, .tHttp, .tFault, .tViolations, .tReadBack)
        Set pHttp = 201
    } Else {
        Set tSC = $ClassMethod(..#SAVE, "Update", $ClassMethod(..#SAVE, "ToolOf", pKind), pName, pBody, .tHttp, .tFault, .tViolations, .tReadBack)
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

/// <p>Mint <var>pToolClass</var>'s proposal for <var>pName</var> from <var>pArgs</var> for this
/// process's user over a completed turn seeded for it; <var>pProposal</var> is <code>""</code> when the
/// mint refused, with its problem in <var>pProblem</var>.</p>
ClassMethod Mint(pToolClass As %String, pName As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttp As %Integer, Output pProblem As %String, Output pTurnKey As %String) As %Status
{
    Set pProposal = ""
    Set pHttp = 0
    Set pProblem = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .pTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Mint($Parameter(pToolClass, "DESCRIPTORCLASS"), $Parameter(pToolClass, "TOOLNAME"), $Username, "", pTurnKey, pArgs, ..#LIMITS, .tResult, .pHttp, .tFault, $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "IdParam"), pName, $ClassMethod(pToolClass, "IdArgument"), $ClassMethod(pToolClass, "SettableFields"), pToolClass)
    If $IsObject($Get(tResult)) Set pProposal = tResult
    If $IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")) Set pProblem = tFault.%Get("detail").%Get("problem")
    If $IsObject($Get(tFault)) && (pProblem = "") Set pProblem = tFault.%Get("code")
    If '$IsObject(pProposal) Quit $$$ERROR($$$GeneralError, "the mint answered no proposal: " _ pHttp _ " " _ pProblem)
    Quit $$$OK
}

/// <p>Confirm <var>pProposal</var> through <parameter>CONFIRM</parameter> as this process's user,
/// answering <code>http code</code>.</p>
ClassMethod Confirm(pProposal As %DynamicObject) As %String
{
    If '$IsObject(pProposal) Quit "no proposal"
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", pProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Quit $Select($$$ISOK(tSC) && ($Get(tCode) = ""): 200, 1: +$Get(tHttp)) _ " " _ $Get(tCode)
}

/// <p>Delete <var>pName</var> through <var>pCaller</var>'s path -- the screen's row action or the
/// agent's mint and confirm -- with the file option <var>pDeleteFile</var>, answering
/// <code>http code</code>.</p>
ClassMethod Delete(pCaller As %String, pName As %String, pDeleteFile As %String) As %String
{
    If pCaller = "agent" {
        Set tArgs = {}
        Do tArgs.%Set("Name", pName, "string")
        Do tArgs.%Set("DeleteFile", (pDeleteFile = "true"), "boolean")
        Set tSC = ..Mint(..#DELETETOOL, pName, tArgs, .tProposal, .tHttp, .tProblem)
        If '$IsObject(tProposal) Quit "not minted " _ tHttp _ " " _ tProblem
        Quit ..Confirm(tProposal)
    }
    Set tBody = {"action": "delete"}
    Do tBody.%Set("id", pName, "string")
    Set tValues = {}
    Do tValues.%Set("DeleteFile", pDeleteFile, "string")
    Do tBody.%Set("values", tValues)
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, tBody, .tAnswer, .tStatus)
    Set tCode = ""
    Try { Set tCode = ##class(%DynamicObject).%FromJSON(tAnswer).%Get("code") } Catch {}
    Quit tStatus _ " " _ tCode
}

/// <p>The dialog's impact for deleting <var>pName</var>, read over the wire as the suite's account
/// with the file option off, or <code>""</code>; <var>pStatus</var> is the route's status.</p>
ClassMethod RouteImpact(pName As %String, Output pStatus As %Integer) As %DynamicObject
{
    Set tPath = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/screens/" _ ..#SCREEN _ "/impact?action=delete&value=false&id=" _ $ZConvert(pName, "O", "URL")
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tRaw, .tHeaders)
    Set tImpact = ""
    Try { Set tImpact = ##class(%DynamicObject).%FromJSON(tRaw).%Get("impact") } Catch {}
    Quit tImpact
}

/// <p>The install namespace's routines database, upper-cased, read through the admin port.</p>
ClassMethod InstallRoutines() As %String
{
    Kill tQuery
    Set tQuery("name") = $NAMESPACE
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Namespace.Namespace", "GET", .tQuery, "", .tNamespace, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tNamespace)) Quit ""
    Quit $ZConvert(tNamespace.%Get("Routines"), "U")
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

/// <p>The <var>pField</var> values the declared read of <var>pDescriptor</var> answers, wrapped in
/// commas.</p>
ClassMethod ListText(pDescriptor As %String, pField As %String) As %String
{
    Set tOut = ","
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(pDescriptor, 1000, .tResult, .tHttp, .tFault)
    If $$$ISERR(tSC) || '$IsObject($Get(tResult)) Quit tOut
    Set tIterator = tResult.%Get("rows").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tOut = tOut _ tRow.%Get(pField) _ ","
    }
    Quit tOut
}

/// <p>The top-level keys of the JSON object text <var>pJson</var>, sorted, comma-separated.</p>
ClassMethod Keys(pJson As %String) As %String
{
    Set tObject = ..Parsed(pJson)
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

/// <p>Member <var>pName</var> of the JSON object text <var>pJson</var>, or <code>""</code>.</p>
ClassMethod Member(pJson As %String, pName As %String) As %String
{
    Set tObject = ..Parsed(pJson)
    If '$IsObject(tObject) Quit ""
    Quit tObject.%Get(pName)
}

/// <p><var>pJson</var> parsed as an object, or <code>""</code>.</p>
ClassMethod Parsed(pJson As %String) As %DynamicObject
{
    Set tObject = ""
    Try {
        If pJson '= "" Set tObject = ##class(%DynamicObject).%FromJSON(pJson)
    } Catch {
        Set tObject = ""
    }
    Quit tObject
}

/// <p>Enable the agent's database delete key, over the snapshot this class took.</p>
ClassMethod EnableDelete() As %Status
{
    Kill tSettings
    Set tSettings(..#DELETEKEY) = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

}
