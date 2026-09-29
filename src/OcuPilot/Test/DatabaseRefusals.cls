/// <p>Pins Story 18.3's database refusals on both callers (AD-21, AD-39, AD-55): the name corpus, a
/// directory already holding a database (DW-1791), each path refusal on its field, a new volume
/// directory's refusals, a directory under OcuPilot's served directory (DW-1807), a root dropped
/// between the mint and the confirm, a bad or absent resource, the file endpoint's own faults, a
/// remote configuration, a key outside a group, an edit of a database deleted since its read, and
/// each path code's sentence. Every refusal is answered before any vendor write,
/// which <class>OcuPilot.Test.DatabaseRecordPort</class> counts.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, the manager directory
/// among the allowed directories, and both <parameter>ARMINGVARIABLE</parameter> and
/// <parameter>PRINCIPALSVARIABLE</parameter> reading <code>1</code>, because the class creates and
/// deletes probe databases and a probe remote configuration
/// (<class>OcuPilot.Test.DatabaseWriteProbe</class>) and restricts the instance's directory allow-list,
/// which it snapshots before and restores after each test.</p>
Class OcuPilot.Test.DatabaseRefusals Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the database writes, set by
/// <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_DATABASE_CONFIG";

/// <p>The environment variable that arms the allow-list changes, set there alone too.</p>
Parameter PRINCIPALSVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.DatabaseWriteProbe";

Parameter WRITE = "OcuPilot.Test.DatabaseWrite";

Parameter SAVE = "OcuPilot.Test.DatabaseSaveFixture";

Parameter RECORD = "OcuPilot.Test.DatabaseRecordPort";

Parameter ALLOWLIST = "OcuPilot.Test.PathPortFixture";

Parameter CREATETOOL = "OcuPilot.Screen.Tool.LocalDatabaseCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.LocalDatabaseUpdate";

Parameter RULES = "OcuPilot.Area.OsMgmt.DatabaseRules";

/// <p>The allow-list as it stood before each test.</p>
Property SavedExists As %Boolean;

Property SavedRestricted As %Boolean;

Property SavedPaths As %List;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..SavedExists = 0
    Set ..SavedRestricted = 0
    Set ..SavedPaths = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PRINCIPALSVARIABLE) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DatabaseRefusals creates and deletes databases and changes the directory allow-list on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#PRINCIPALSVARIABLE _ " must both read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets them.")
    }
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnBeforeOneTest() As %Status
{
    Set tSC = $ClassMethod(..#ALLOWLIST, "Snapshot", .tExists, .tRestricted, .tPaths)
    If $$$ISERR(tSC) Quit tSC
    Set ..SavedExists = tExists
    Set ..SavedRestricted = tRestricted
    Set ..SavedPaths = tPaths
    Set ^||OcuPilotDatabaseWritePort = ..#RECORD
    Do $ClassMethod(..#RECORD, "Clear")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertStatusOK($ClassMethod(..#ALLOWLIST, "Restore", ..SavedExists, ..SavedRestricted, ..SavedPaths), "the allow-list is restored")
    Kill ^||OcuPilotDatabaseWritePort
    Do $ClassMethod(..#RECORD, "Clear")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe database object is removed by exact name")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    If '$ClassMethod(..#PROBE, "CpfValid", .tNamesProbe) || tNamesProbe Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the configuration file does not validate, or names a probe database, after OcuPilot.Test.DatabaseRefusals"))
    Quit tSC
}

/// <p>The name corpus: a leading digit, a dot, a space, a leading <code>%</code> and 65 characters are
/// refused on Name by the rules on both callers with no vendor write, and the instance refuses each
/// itself; <code>-</code>, <code>_</code>, lower case and 64 characters pass the rules and the
/// instance alike.</p>
Method TestTheNameCorpusIsTheInstancesOwn()
{
    Set tLong = "OCUPROBE183" _ $Translate($Justify("", 54), " ", "X")
    Set tBad = $ListBuild("1OCUPROBE183", "OCUPROBE183.B", "OCUPROBE183 B", "%OCUPROBE183", tLong)
    Set tGood = $ListBuild("OCUPROBE183-B", "OCUPROBE183_B", "ocuprobe183lc", $Extract(tLong, 1, 64))
    Set tRoot = $ClassMethod(..#PROBE, "Manager")
    For tI = 1:1:$ListLength(tBad) {
        Set tName = $List(tBad, tI)
        Set tBody = {"root": (tRoot), "path": "ocuprobe183corpus"}
        Do tBody.%Set("Name", tName, "string")
        Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Save("create", tName, tBody, .tHttp, .tCode, .tFields)
        Do $$$AssertEquals(tHttp _ " " _ tFields, "422 Name:DATABASE.NAME.SHAPE", tName _ ": the screen refuses it on Name")
        Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Mint(..#CREATETOOL, tName, tBody, .tProposal, .tHttp, .tProblem)
        Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ "'Name'"), tName _ ": the mint refuses it on Name (" _ tProblem _ ")")
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Attempt", tName, .tAnswer), tName _ ": the instance is asked")
        Do $$$AssertTrue((tAnswer < 200) || (tAnswer > 299), tName _ ": and refuses it too (" _ tAnswer _ ")")
    }
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes"), "", "no vendor write was sent by either caller")
    For tI = 1:1:$ListLength(tGood) {
        Set tName = $List(tGood, tI)
        Kill tViolations
        Do $ClassMethod(..#RULES, "NameViolation", tName, .tViolations)
        Do $$$AssertEquals(+$Get(tViolations), 0, tName _ ": the rule accepts it")
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Attempt", tName, .tAnswer), tName _ ": the instance is asked")
        Do $$$AssertEquals(tAnswer, 201, tName _ ": and accepts it")
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", tName, 0), tName _ ": which is removed")
    }
}

/// <p>DW-1791: a create naming a directory that already holds a database file -- a probe database's
/// own, or the instance's <code>irissecurity</code> -- is refused on path at the step check, at the
/// Save and at the mint, with no vendor write; and a create minted before its directory gained a
/// database file is refused by the port at the confirm, with no write and no resource made.</p>
/// <p>Mutations (Rule 19): <class>OcuPilot.Area.OsMgmt.DatabaseRules</class> skips the database file
/// test -> the mint accepts the directory and this goes red; <class>OcuPilot.Port.DatabasePort</class>
/// skips its own test at the create -> the confirm's writes are sent and this goes red.</p>
Method TestADirectoryHoldingADatabaseIsRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", "OCUPROBE183DB"), "a probe database is created")
    Set tRoot = $ClassMethod(..#PROBE, "Manager")
    For tPath = "ocuprobe183db", "irissecurity" {
        Set tBody = {"Name": "OCUPROBE183DN", "root": (tRoot)}
        Do tBody.%Set("path", tPath, "string")
        Set tSC = $ClassMethod(..#RULES, "Validate", "OCUPROBE183DN", tBody, .tViolations, "create", 1, $ListBuild("Name", "root", "path"))
        Do $$$AssertEquals(..Fields(.tViolations), "path:DATABASE.DIRECTORY.INUSE", tPath _ ": the step check refuses it on path")
        Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Save("create", "OCUPROBE183DN", tBody, .tHttp, .tCode, .tFields)
        Do $$$AssertEquals(tHttp _ " " _ tFields, "422 path:DATABASE.DIRECTORY.INUSE", tPath _ ": and the Save")
        Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Mint(..#CREATETOOL, "OCUPROBE183DN", tBody, .tProposal, .tHttp, .tProblem)
        Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ "'path'"), tPath _ ": and the mint (" _ tProblem _ ")")
    }
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes"), "", "no vendor write was sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", "OCUPROBE183DN"), 0, "and nothing was created")
    Set tName = "OCUPROBE183DC"
    Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Mint(..#CREATETOOL, tName, {"Name": (tName), "root": (tRoot), "path": "ocuprobe183dc"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "a create is minted while its directory holds no database (" _ tProblem _ ")")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", "OCUPROBE183DX", $ClassMethod(..#PROBE, "DirectoryFor", "dc")), "and a probe database's file is then made there")
    Do $ClassMethod(..#RECORD, "Clear")
    Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseWrite).Confirm(tProposal), "422 DATABASE.VALIDATION", "the confirm is refused")
    Set tFault = ##class(OcuPilot.Test.DatabaseWrite).Parsed($ClassMethod(..#RECORD, "FaultOf", "Database.ConfigCRUD/PUT"))
    Set tViolation = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")) && $IsObject(tFault.detail.%Get("violations")): tFault.detail.violations.%Get(0), 1: "")
    Do $$$AssertEquals($Select($IsObject(tViolation): tViolation.field _ ":" _ tViolation.code, 1: ""), "path:DATABASE.DIRECTORY.INUSE", "by the port, on path")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes"), "", "no vendor write was sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "HoldsResource", "%DB_" _ tName), 0, "and no resource was made")
}

/// <p>Path refusals: a root outside the allow-list, a name with <code>..</code>, and the manager
/// directory itself are refused on their field at the step check, the Save and the mint.</p>
Method TestThePathRefusalsLandOnTheirFields()
{
    Set tRoot = $ClassMethod(..#PROBE, "Manager")
    For tCase = $ListBuild("/ocuprobe183nowhere/", "ocuprobe183p", "root:PATH.ROOT"), $ListBuild(tRoot, "../ocuprobe183p", "path:PATH.NAME"), $ListBuild(tRoot, "", "path:PATH.MANAGERDIR") {
        Set tBody = {"Name": "OCUPROBE183PT"}
        Do tBody.%Set("root", $List(tCase, 1), "string")
        Do tBody.%Set("path", $List(tCase, 2), "string")
        Set tSC = $ClassMethod(..#RULES, "Validate", "OCUPROBE183PT", tBody, .tViolations, "create", 1, $ListBuild("Name", "root", "path"))
        Do $$$AssertEquals(..Fields(.tViolations), $List(tCase, 3), $List(tCase, 3) _ ": the step check refuses it")
        Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Save("create", "OCUPROBE183PT", tBody, .tHttp, .tCode, .tFields)
        Do $$$AssertEquals(tHttp _ " " _ tFields, "422 " _ $List(tCase, 3), $List(tCase, 3) _ ": and the Save")
        Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Mint(..#CREATETOOL, "OCUPROBE183PT", tBody, .tProposal, .tHttp, .tProblem)
        Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ ("'" _ $Piece($List(tCase, 3), ":", 1) _ "'")), $List(tCase, 3) _ ": and the mint (" _ tProblem _ ")")
    }
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes"), "", "no vendor write was sent")
}

/// <p>DW-1807: with the allow-list restricted to OcuPilot's served directory and the one above it, a
/// create's directory under the served directory is refused <code>PATH.SERVED</code> on path from both
/// callers with no vendor write.</p>
Method TestAServedDirectoryIsRefusedOnPath()
{
    Set tServed = ##class(OcuPilot.Port.PathPort).ServedDirectory()
    Set tParent = ##class(%File).ParentDirectoryName(tServed)
    Set tName = $Piece(tServed, "/", *-1)
    Do $$$AssertTrue((tParent '= "") && (tName '= ""), "the served directory has a parent and a name")
    Do $$$AssertStatusOK($ClassMethod(..#ALLOWLIST, "SetUp", 1, $ListBuild(tServed, tParent)), "the allow-list is restricted to the served directory and the one above it")
    For tCase = $ListBuild(tParent, tName), $ListBuild(tServed, "ocuprobe183sv") {
        Set tBody = {"Name": "OCUPROBE183SV"}
        Do tBody.%Set("root", $List(tCase, 1), "string")
        Do tBody.%Set("path", $List(tCase, 2), "string")
        Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Save("create", "OCUPROBE183SV", tBody, .tHttp, .tCode, .tFields)
        Do $$$AssertEquals(tHttp _ " " _ tFields, "422 path:PATH.SERVED", $List(tCase, 1) _ $List(tCase, 2) _ ": the Save refuses it on path")
        Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Mint(..#CREATETOOL, "OCUPROBE183SV", tBody, .tProposal, .tHttp, .tProblem)
        Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ ##class(OcuPilot.Api.Error).#REASONPATHSERVED), $List(tCase, 1) _ $List(tCase, 2) _ ": and the mint, with its sentence (" _ tProblem _ ")")
    }
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes"), "", "no vendor write was sent")
}

/// <p>A root dropped from the allow-list after the mint refuses the confirm <code>PATH.ROOT</code>, and
/// nothing is sent (AD-21: resolved again at the write).</p>
Method TestARootDroppedAfterTheMintRefusesTheConfirm()
{
    Set tName = "OCUPROBE183RD"
    Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Mint(..#CREATETOOL, tName, {"Name": (tName), "root": ($ClassMethod(..#PROBE, "Manager")), "path": "ocuprobe183rd"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the create is minted (" _ tProblem _ ")")
    Do $$$AssertStatusOK($ClassMethod(..#ALLOWLIST, "SetUp", 1, $ListBuild("/tmp/")), "the allow-list no longer holds the manager directory")
    Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseWrite).Confirm(tProposal), "400 " _ ##class(OcuPilot.Api.Error).#PATHROOT, "the confirm is refused on the root")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes"), "", "no vendor write was sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, "and nothing was created")
}

/// <p>A file edit's new volume directory: a root outside the allow-list and a name with
/// <code>..</code> are refused on <code>volumeRoot</code> and <code>volumePath</code> at the Save and at
/// the mint, with no vendor write; and a volume root dropped from the allow-list after the mint refuses
/// the confirm <code>PATH.ROOT</code> with nothing sent (AD-21: resolved again at the write).</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.LocalDatabaseUpdate.PortQuery</method> drops
/// <code>volumeRoot</code> -> the confirm's write is sent and this goes red.</p>
Method TestTheVolumeDirectoryRefusalsLandOnTheirFields()
{
    Set tName = "OCUPROBE183VR"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName), "a probe database is created")
    Set tRoot = $ClassMethod(..#PROBE, "Manager")
    For tCase = $ListBuild("/ocuprobe183nowhere/", "ocuprobe183v", "volumeRoot:PATH.ROOT"), $ListBuild(tRoot, "../ocuprobe183v", "volumePath:PATH.NAME") {
        Set tEdit = {}
        Do tEdit.%Set("volumeRoot", $List(tCase, 1), "string")
        Do tEdit.%Set("volumePath", $List(tCase, 2), "string")
        Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Save("file", tName, tEdit, .tHttp, .tCode, .tFields)
        Do $$$AssertEquals(tHttp _ " " _ tFields, "422 " _ $List(tCase, 3), $List(tCase, 3) _ ": the Save refuses it")
        Do tEdit.%Set("Name", tName, "string")
        Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Mint(..#UPDATETOOL, tName, tEdit, .tProposal, .tHttp, .tProblem)
        Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ ("'" _ $Piece($List(tCase, 3), ":", 1) _ "'")), $List(tCase, 3) _ ": and the mint (" _ tProblem _ ")")
    }
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes"), "", "no vendor write was sent")
    Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Mint(..#UPDATETOOL, tName, {"Name": (tName), "volumeRoot": (tRoot), "volumePath": "ocuprobe183vr-vol"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "a new volume directory is minted (" _ tProblem _ ")")
    Do $$$AssertStatusOK($ClassMethod(..#ALLOWLIST, "SetUp", 1, $ListBuild("/tmp/")), "the allow-list no longer holds the manager directory")
    Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseWrite).Confirm(tProposal), "400 " _ ##class(OcuPilot.Api.Error).#PATHROOT, "the confirm is refused on the root")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes"), "", "and nothing is sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "HoldsDirectory", $ClassMethod(..#PROBE, "DirectoryFor", "vr-vol")), 0, "and no volume directory is made")
}

/// <p>A resource name that does not begin <code>%DB_</code>, and one no resource carries, are refused
/// on ResourceName by the create's and the edit's Save and mint, with no vendor write.</p>
Method TestABadOrAbsentResourceIsRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", "OCUPROBE183RE"), "a probe database is created")
    Set tRoot = $ClassMethod(..#PROBE, "Manager")
    For tCase = $ListBuild("OcuProbe183Custom", "DATABASE.RESOURCE.SHAPE"), $ListBuild("%DB_OCUPROBE183NOSUCH", "DATABASE.RESOURCE.ABSENT") {
        Set tBody = {"Name": "OCUPROBE183RN", "root": (tRoot), "path": "ocuprobe183rn"}
        Do tBody.%Set("ResourceName", $List(tCase, 1), "string")
        Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Save("create", "OCUPROBE183RN", tBody, .tHttp, .tCode, .tFields)
        Do $$$AssertEquals(tHttp _ " " _ tFields, "422 ResourceName:" _ $List(tCase, 2), $List(tCase, 1) _ ": the create's Save refuses it")
        Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Mint(..#CREATETOOL, "OCUPROBE183RN", tBody, .tProposal, .tHttp, .tProblem)
        Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ "'ResourceName'"), $List(tCase, 1) _ ": and its mint (" _ tProblem _ ")")
        Set tEdit = {}
        Do tEdit.%Set("ResourceName", $List(tCase, 1), "string")
        Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Save("file", "OCUPROBE183RE", tEdit, .tHttp, .tCode, .tFields)
        Do $$$AssertEquals(tHttp _ " " _ tFields, "422 ResourceName:" _ $List(tCase, 2), $List(tCase, 1) _ ": the edit's Save refuses it")
        Do tEdit.%Set("Name", "OCUPROBE183RE", "string")
        Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Mint(..#UPDATETOOL, "OCUPROBE183RE", tEdit, .tProposal, .tHttp, .tProblem)
        Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ "'ResourceName'"), $List(tCase, 1) _ ": and its mint (" _ tProblem _ ")")
    }
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes"), "", "no vendor write was sent")
}

/// <p>The file endpoint's own faults (AD-39), through <method>OcuPilot.Port.AdminPort.Invoke</method> on
/// probe objects: a <code>POST</code> on a probe database's directory answers
/// <code>path:DATABASE.DIRECTORY.INUSE</code>, and one naming the resource
/// <code>OcuProbe183Custom</code> answers <code>ResourceName:DATABASE.RESOURCE.SHAPE</code>, the probe
/// database's file surviving. On this build the vendor answers the first with errors 70, 60 and 73
/// (78 in place of 60 once dismounted) and the second with 896 (measured on
/// <code>ocupilot-b-ci</code>).</p>
/// <p>Mutation (Rule 19): drop the <code>Database.SysCRUD:60</code> entry from
/// <parameter>OcuPilot.Port.AdminPort.PROPERTYFAULTS</parameter> -> this goes red.</p>
Method TestTheFileEndpointsFaultsLandOnTheirFields()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", "OCUPROBE183PF"), "a probe database is created")
    For tCase = $ListBuild("pf", "", "path:DATABASE.DIRECTORY.INUSE"), $ListBuild("pfr", "OcuProbe183Custom", "ResourceName:DATABASE.RESOURCE.SHAPE") {
        Set tBody = {"Size": 1}
        Do tBody.%Set("Directory", $ClassMethod(..#PROBE, "DirectoryFor", $List(tCase, 1)), "string")
        If $List(tCase, 2) '= "" Do tBody.%Set("ResourceName", $List(tCase, 2), "string")
        Kill tNone
        Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Database.SysCRUD", "POST", .tNone, tBody, .tResult, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, $List(tCase, 3) _ ": the vendor refuses the file")
        Do $$$AssertEquals(..ViolationFields($Get(tFault)), $List(tCase, 3), $List(tCase, 3) _ ": on its field (" _ $Get(tHttp) _ ")")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "HoldsFile", $ClassMethod(..#PROBE, "DirectoryFor", "pf")), 1, "the probe database's file survives")
}

/// <p>A file edit of a remote configuration is refused 409 <code>DATABASE.REMOTE</code> by the Save,
/// the mint and the form read, and nothing is sent; and neither the Local databases list's read nor
/// <code>osmgmt.localdatabases.read</code> answers it, although the unnarrowed list does.</p>
/// <p>Mutation (Rule 19): drop <code>localOnly</code> from the list's read -> the remote row is
/// answered and this goes red.</p>
Method TestARemoteDatabaseIsRefused()
{
    Set tName = "OCUPROBE183RM"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddRemote", tName), "a probe remote configuration is created")
    Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Save("file", tName, {"MaxSize": 1}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "409 DATABASE.REMOTE", "the Save is refused as remote")
    Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Mint(..#UPDATETOOL, tName, {"Name": (tName), "MaxSize": 1}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertTrue('$IsObject(tProposal) && (tHttp = 409) && (tProblem = "DATABASE.REMOTE"), "and the mint (" _ tHttp _ " " _ tProblem _ ")")
    Set tSC = $ClassMethod(..#RULES, "Read", ..#UPDATETOOL, tName, .tFresh, .tReadHttp, .tFault)
    Do $$$AssertEquals(+$Get(tReadHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "409 DATABASE.REMOTE", "and the form's read")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes"), "", "no vendor write was sent")
    Kill tQuery
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Database.ConfigCRUD", "LIST", .tQuery, "", .tAll, .tHttp, .tFault)
    Do $$$AssertTrue(..Names($Get(tAll)) [ ("," _ tName _ ","), "the vendor's unnarrowed list answers the remote configuration")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute("OcuPilot.Screen.Descriptor.LocalDatabaseList", 1000, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the Local databases list's read answers")
    Set tRows = $Select($IsObject($Get(tResult)): tResult.%Get("rows"), 1: "")
    Do $$$AssertTrue($IsObject(tRows) && (tRows.%Size() > 0), "with rows")
    Do $$$AssertTrue(..Names(tRows) '[ ("," _ tName _ ","), "without the remote configuration")
    Set tView = ""
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("osmgmt.localdatabases.read", .tTool)
    Do $$$AssertTrue($$$ISOK(tSC) && $IsObject($Get(tTool)), "the read tool resolves")
    If $IsObject($Get(tTool)) Set tSC = $ClassMethod(tTool.class, "View", tTool.descriptor, {}, 1000, .tView, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the read tool answers")
    Set tRows = $Select($IsObject($Get(tView)): tView.%Get("rows"), 1: "")
    Do $$$AssertTrue($IsObject(tRows) && (tRows.%Size() > 0), "with rows")
    Do $$$AssertTrue(..Names(tRows) '[ ("," _ tName _ ","), "without it too")
}

/// <p>A key outside the group's tool on each group, and a group the edit does not have, are refused
/// 400 <code>PORT.FIELD.UNEXPECTED</code> with nothing sent.</p>
Method TestAKeyOutsideAGroupIsRefused()
{
    Set tName = "OCUPROBE183KO"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName), "a probe database is created")
    Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Save("configuration", tName, {"Directory": "/ocuprobe183elsewhere/"}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "400 " _ ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, "configuration: a key its tool does not admit is refused")
    Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Save("file", tName, {"NewGlobalCollation": 5}, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "400 " _ ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, "file: a key its tool does not admit is refused")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/database/" _ tName, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, {"mounting": {"MountAtStartup": true}}.%ToJSON(), "application/json")
    Set tCode = ""
    Try { Set tCode = ##class(%DynamicObject).%FromJSON(tRaw).%Get("code") } Catch {}
    Do $$$AssertEquals(tStatus _ " " _ tCode, "400 " _ ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, "and so is a group the edit does not have")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes"), "", "no vendor write was sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", tName, "MountAtStartup"), "false", "and the configuration is unchanged")
}

/// <p>An edit of a database the instance no longer holds: the Save route answers 404
/// <code>DATABASE.NAME.ABSENT</code>, and a proposal minted before the delete is refused
/// <code>PROPOSAL.TARGETCHANGED</code> at its confirm, with nothing sent.</p>
Method TestAnEditOfADeletedDatabaseIsRefused()
{
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/database/OCUPROBE183GONE", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, {"file": {"MaxSize": 2}}.%ToJSON(), "application/json")
    Set tCode = ""
    Try { Set tCode = ##class(%DynamicObject).%FromJSON(tRaw).%Get("code") } Catch {}
    Do $$$AssertEquals(tStatus _ " " _ tCode, "404 DATABASE.NAME.ABSENT", "the Save of an absent database answers 404")
    Set tName = "OCUPROBE183TC"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", tName), "a probe database is created")
    Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Mint(..#UPDATETOOL, tName, {"Name": (tName), "MaxSize": 9}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "an edit is minted (" _ tProblem _ ")")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", tName, 1), "and the database is deleted")
    Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseWrite).Confirm(tProposal), "409 PROPOSAL.TARGETCHANGED", "the confirm is refused as a moved target")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes"), "", "no vendor write was sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", tName), 0, "and the upsert did not re-create it")
}

/// <p>Every <code>PATH.*</code> code's sentence from <method>OcuPilot.Api.Error.ReasonForViolation</method>
/// is the one <class>OcuPilot.Port.PathPort</class> refuses it with -- the <code>REASON</code>
/// parameter beside the code's own -- so a form re-rendering a path refusal from its code says the
/// same thing; and a root refusal the port answers carries that sentence.</p>
/// <p>Mutation (Rule 19): drop the <code>PATH.ROOT</code> arm of
/// <method>OcuPilot.Api.Error.ReasonForPath</method> -> this goes red.</p>
Method TestEachPathCodeCarriesThePortsSentence()
{
    Set tStatement = ##class(%SQL.Statement).%New()
    Set tSC = tStatement.%Prepare("SELECT %EXACT(Name) AS Name, %EXACT(_Default) AS Code FROM %Dictionary.CompiledParameter WHERE %EXACT(parent) = ? AND %EXACT(_Default) %STARTSWITH ?")
    Do $$$AssertStatusOK(tSC, "the error class's parameters are queried")
    If $$$ISERR(tSC) Quit
    Set tRS = tStatement.%Execute("OcuPilot.Api.Error", "PATH.")
    Set tCount = 0
    While tRS.%Next() {
        Set tCount = tCount + 1
        Set tSentence = $Parameter("OcuPilot.Api.Error", "REASON" _ tRS.%Get("Name"))
        Do $$$AssertTrue(tSentence '= "", tRS.%Get("Code") _ ": the port's sentence stands beside it")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tRS.%Get("Code")), tSentence, tRS.%Get("Code") _ ": and ReasonForViolation answers it")
    }
    Do $$$AssertTrue(tCount > 0, "the error class declares PATH.* codes (" _ tCount _ ")")
    Set tSC = ##class(OcuPilot.Port.PathPort).Resolve("/ocuprobe183nowhere/", "ocuprobe183p", ##class(OcuPilot.Port.PathPort).#KINDDIRECTORY, "root", "path", .tDirectory, .tHttp, .tFault, 0, 1)
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%Get("code") _ "|" _ tFault.%Get("reason"), 1: ""), "PATH.ROOT|" _ ##class(OcuPilot.Api.Error).ReasonForViolation("PATH.ROOT"), "the port's own root refusal carries it")
}

/// <p>The <code>Name</code> of every row of <var>pRows</var>, upper-cased and wrapped in commas.</p>
ClassMethod Names(pRows) As %String
{
    Set tOut = ","
    If '$IsObject(pRows) Quit tOut
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $IsObject(tRow) Set tOut = tOut _ $ZConvert(tRow.%Get("Name"), "U") _ ","
    }
    Quit tOut
}

/// <p>The violations fault <var>pFault</var> carries in <code>detail.violations</code>, as
/// <code>field:code</code>, comma-separated, or <code>""</code>.</p>
ClassMethod ViolationFields(pFault) As %String
{
    Set tOut = ""
    If '$IsObject(pFault) || (pFault.%GetTypeOf("detail") '= "object") || (pFault.%Get("detail").%GetTypeOf("violations") '= "array") Quit tOut
    Set tIterator = pFault.%Get("detail").%Get("violations").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $IsObject(tRow) Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tRow.%Get("field") _ ":" _ tRow.%Get("code")
    }
    Quit tOut
}

/// <p><var>pViolations</var> as <code>field:code</code>, comma-separated.</p>
ClassMethod Fields(ByRef pViolations) As %String
{
    Set tOut = ""
    For tI = 1:1:+$Get(pViolations) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ $List(pViolations(tI), 1) _ ":" _ $List(pViolations(tI), 2)
    }
    Quit tOut
}

}
