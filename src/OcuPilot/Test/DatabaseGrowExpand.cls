/// <p>Pins Story 18.4's Local databases editor operations (AC3, AC11): the size grow on both callers --
/// the editor's Save of group <code>size</code> (<code>PUT /database/:id</code>, through
/// <class>OcuPilot.Test.DatabaseWriteGateProbe</class>'s route handler) and the agent's
/// <code>osmgmt.localdatabases.grow</code> -- and Add a volume on both callers -- the Local databases
/// list's <code>expand</code> action (<class>OcuPilot.Test.DatabaseActionFixture</class>) and
/// <code>osmgmt.localdatabases.expand</code> -- each with its body, its effect and its refusals; and
/// DW-1791, a new volume directory that is another database's directory or volume directory, refused
/// on <code>volumePath</code> at the Save, the mint and the confirm with no vendor write, and the
/// vendor's own faults for it landing there too; and the owner's database-directory rule (AD-21's sixth
/// case), a volume never placed where the database names no new volume directory or in the manager
/// directory, on Add a volume, on a grow or defragment past a threshold and on a threshold the file edit
/// sets (DW-1860).</p>
/// <p>A write that should happen goes through <class>OcuPilot.Test.DatabaseRecordPort</class>, which
/// records and sends it; a refused leg writes through <class>OcuPilot.Test.DatabaseAcceptPort</class>,
/// which sends no write.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates, grows,
/// expands and deletes probe databases (<class>OcuPilot.Test.DatabaseActionProbe</class>) and sets the
/// governance policy. <method>OnBeforeAllTests</method> refuses anywhere it does not; every probe object
/// is removed before all, after each and after all.</p>
Class OcuPilot.Test.DatabaseGrowExpand Extends %UnitTest.TestCase
{

Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_DATABASE_CONFIG";

Parameter PROBE = "OcuPilot.Test.DatabaseActionProbe";

Parameter ACTION = "OcuPilot.Test.DatabaseActionFixture";

Parameter RECORD = "OcuPilot.Test.DatabaseRecordPort";

Parameter ACCEPT = "OcuPilot.Test.DatabaseAcceptPort";

Parameter WRITE = "OcuPilot.Test.DatabaseWrite";

Parameter SCREEN = "osmgmt.localdatabases";

Parameter GROWTOOL = "OcuPilot.Screen.Tool.LocalDatabaseGrow";

Parameter EXPANDTOOL = "OcuPilot.Screen.Tool.LocalDatabaseExpand";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.LocalDatabaseUpdate";

Parameter DEFRAGMENTTOOL = "OcuPilot.Screen.Tool.DatabaseDefragment";

/// <p>The port that answers an armed new volume directory, and Add a volume's tool reading through
/// it.</p>
Parameter VOLUME = "OcuPilot.Test.DatabaseVolumePort";

Parameter VOLUMEEXPANDTOOL = "OcuPilot.Test.SeamVolumeLocalDatabaseExpand";

/// <p>The grow's and the defragment's tools reading through <parameter>VOLUME</parameter>.</p>
Parameter VOLUMEGROWTOOL = "OcuPilot.Test.SeamVolumeLocalDatabaseGrow";

Parameter VOLUMEDEFRAGMENTTOOL = "OcuPilot.Test.SeamVolumeDatabaseDefragment";

Property PreparedPolicy [ MultiDimensional ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.DatabaseGrowExpand creates, grows, expands and deletes databases on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort, ^||OcuPilotDatabaseRulesPort
    Do $ClassMethod(..#RECORD, "Clear")
    Do $ClassMethod(..#VOLUME, "Clear")
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe object and task is removed")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", .tRemaining))
    If '$ClassMethod(..#PROBE, "CpfValid", .tNamesProbe) || tNamesProbe Set tSC = $$$ADDSC(tSC, $$$ERROR($$$GeneralError, "the configuration file does not validate, or names a probe database, after OcuPilot.Test.DatabaseGrowExpand"))
    Quit tSC
}

/// <p>The size grow (AC3): the editor's Save of group <code>size</code> sends <code>MODIFYSIZE</code>
/// with <code>{"Size":n}</code> to the database's directory and the file reads <var>n</var> MB; the
/// agent's grow does the same. Each is queued, read once and forgotten.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Area.OsMgmt.DatabaseSave</class> drops the <code>size</code>
/// group -> the Save is refused as unexpected and this goes red.</p>
Method TestTheSizeGrowsOnTheSaveAndThroughTheTool()
{
    Set tA = ..AddProbe("OCUPROBE184GA")
    Set tB = ..AddProbe("OCUPROBE184GB")
    Set tAlerts = $ClassMethod(..#PROBE, "SecondReads")
    Do $$$AssertTrue(tAlerts >= 0, "messages.log is read (" _ tAlerts _ ")")
    Set ^||OcuPilotDatabaseWritePort = ..#RECORD
    Set tSize = ..StateOf(tA, "Size") + 3
    Set tBody = {"size": {}}
    Do tBody.size.%Set("Size", tSize, "number")
    Set tSC = ##class(OcuPilot.Test.DatabaseWriteGateProbe).Handle("update", "OCUPROBE184GA", tBody, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the editor's Save of the size answers 200: " _ $Extract(tAnswer, 1, 200))
    Set tWanted = {}
    Do tWanted.%Set("Size", tSize, "number")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes") _ "|" _ $ClassMethod(..#RECORD, "BodyOf", "Database.Actions/MODIFYSIZE") _ "|" _ $ClassMethod(..#RECORD, "TargetOf", "Database.Actions/MODIFYSIZE"), "Database.Actions/MODIFYSIZE|" _ tWanted.%ToJSON() _ "|" _ tA, "sending the new size to the database's directory")
    Do $$$AssertEquals(..StateOf(tA, "Size"), tSize, "and the file reads it")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.DatabaseActions).Enable("osmgmt.localdatabases.grow"), "the agent's key is enabled")
    Do $ClassMethod(..#RECORD, "Clear")
    Set tSize = ..StateOf(tB, "Size") + 2
    Set tArgs = {}
    Do tArgs.%Set("Size", tSize, "number")
    Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseActions).Agent(..#GROWTOOL, "OCUPROBE184GB", tArgs), "200 ", "the agent's grow is minted and confirmed")
    Do tWanted.%Set("Size", tSize, "number")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "BodyOf", "Database.Actions/MODIFYSIZE"), tWanted.%ToJSON(), "sending the new size")
    Do $$$AssertEquals(..StateOf(tB, "Size"), tSize, "and the file reads it")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "OwnTaskCount"), 0, "each queued grow was read once and its row deleted")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "SecondReads"), tAlerts, "and no second read of an ended task was logged")
}

/// <p>A grow still running at the port's bound (AC2): the editor's Save of the size answers 200 with
/// <code>continues</code> true and the size group's read-back <code>unchecked</code>.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Area.OsMgmt.DatabaseSave</class> no longer sets
/// <code>continues</code> for a 202 -> this goes red.</p>
Method TestAGrowStillRunningAtTheBoundContinuesOnTheSave()
{
    Set tA = ..AddProbe("OCUPROBE184GA")
    Set ^||OcuPilotDatabaseWritePort = "OcuPilot.Test.DatabaseTimeoutPort"
    Set tBody = {"size": {}}
    Do tBody.size.%Set("Size", ..StateOf(tA, "Size") + 3, "number")
    Set tSC = ##class(OcuPilot.Test.DatabaseWriteGateProbe).Handle("update", "OCUPROBE184GA", tBody, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the editor's Save of the size answers 200: " _ $Extract(tAnswer, 1, 200))
    Set tParsed = ""
    Try {
        Set tParsed = ##class(%DynamicObject).%FromJSON(tAnswer)
    } Catch {
        Set tParsed = ""
    }
    Set tSize = $Select($IsObject(tParsed) && $IsObject(tParsed.%Get("size")) && $IsObject(tParsed.size.%Get("readBack")): tParsed.size.readBack.%Get("verdict"), 1: "")
    Do $$$AssertEquals($Select($IsObject(tParsed): tParsed.%Get("continues"), 1: "") _ "|" _ tSize, "1|unchecked", "continuing on the instance, its read-back unchecked")
}

/// <p>The grow's rules (AC3): a size at or below the current size, not a whole number, or above a
/// maximum size that is set is refused 422 <code>DATABASE.GROWSIZE.SHAPE</code> on <code>Size</code> at
/// the Save and the mint, with no write sent.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.DatabasePort.ActionViolations</method> accepts a size
/// equal to the current one -> the accept port records a grow and this goes red.</p>
Method TestTheGrowRulesRefuseBeforeAnyVendorCall()
{
    Set tA = ..AddProbe("OCUPROBE184GA")
    Set tSize = ..StateOf(tA, "Size")
    Do $$$AssertStatusOK(..SetFile(tA, "MaxSize", tSize + 4), "a maximum size is set")
    Set ^||OcuPilotDatabaseWritePort = ..#ACCEPT
    Do $ClassMethod(..#ACCEPT, "Clear")
    For tValue = tSize, tSize - 1, "1.5", "abc", tSize + 5 {
        Set tGroup = {}
        If $IsValidNum(tValue) {
            Do tGroup.%Set("Size", +tValue, "number")
        } Else {
            Do tGroup.%Set("Size", tValue, "string")
        }
        Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Save("size", "OCUPROBE184GA", tGroup, .tHttp, .tCode, .tFields)
        Do $$$AssertEquals(tHttp _ " " _ tFields, "422 Size:DATABASE.GROWSIZE.SHAPE", tValue _ ": the Save is refused on Size (" _ tCode _ ")")
        Do $$$AssertTrue(##class(OcuPilot.Test.DatabaseActions).MintProblem(..#GROWTOOL, "OCUPROBE184GA", tGroup) [ "'Size'", tValue _ ": and the mint")
    }
    Do $$$AssertEquals($ClassMethod(..#ACCEPT, "Writes"), "", "no write reached the port")
}

/// <p>Add a volume (AC3): the Local databases list's <code>expand</code> sends <code>EXPANDVOL</code>
/// with <code>{"InitialSize":1}</code> and a volume file appears in the database's new volume
/// directory; the agent's does the same. An initial size of 0, a fraction, or one above a non-zero
/// new-volume threshold is refused 422 <code>DATABASE.INITIALSIZE.SHAPE</code> on
/// <code>InitialSize</code> on both callers with no write sent.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.DatabasePort.ActionBody</method> sends no
/// <code>InitialSize</code> -> the vendor refuses the expand and this goes red.</p>
Method TestAddAVolumeOnBothCallers()
{
    Set tA = ..AddProbe("OCUPROBE184GA")
    Set tB = ..AddProbe("OCUPROBE184GB")
    Set ^||OcuPilotDatabaseWritePort = ..#RECORD
    Do $$$AssertEquals(..Act("OCUPROBE184GA", {"InitialSize": "1"}), "200 ", "the screen's Add a volume answers 200")
    Set tWanted = {"InitialSize": 1}
    Do $$$AssertEquals($ClassMethod(..#RECORD, "BodyOf", "Database.Actions/EXPANDVOL") _ "|" _ $ClassMethod(..#RECORD, "TargetOf", "Database.Actions/EXPANDVOL"), tWanted.%ToJSON() _ "|" _ tA, "sending the initial size to the database's directory")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "HoldsVolume", ..StateOf(tA, "NewVolumeDirectory")), 1, "and a volume file is in its new volume directory")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.DatabaseActions).Enable("osmgmt.localdatabases.expand"), "the agent's key is enabled")
    Do $ClassMethod(..#RECORD, "Clear")
    Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseActions).Agent(..#EXPANDTOOL, "OCUPROBE184GB", {"InitialSize": 1}), "200 ", "the agent's Add a volume is minted and confirmed")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "BodyOf", "Database.Actions/EXPANDVOL"), tWanted.%ToJSON(), "sending the initial size")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "HoldsVolume", ..StateOf(tB, "NewVolumeDirectory")), 1, "and a volume file is in its new volume directory")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "OwnTaskCount"), 0, "each queued expand was read once and its row deleted")

    Do $$$AssertStatusOK(..SetFile(tA, "NewVolumeThreshold", 5), "a new-volume threshold is set")
    Set ^||OcuPilotDatabaseWritePort = ..#ACCEPT
    Do $ClassMethod(..#ACCEPT, "Clear")
    For tValue = "0", "1.5", "6" {
        Set tValues = {}
        Do tValues.%Set("InitialSize", tValue, "string")
        Do $$$AssertEquals(..Act("OCUPROBE184GA", tValues, .tAnswer), "422 DATABASE.VALIDATION", tValue _ ": the screen's Add a volume is refused")
        Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseActions).Violation(tAnswer), "InitialSize:DATABASE.INITIALSIZE.SHAPE", tValue _ ": on InitialSize")
        Set tArgs = {}
        Do tArgs.%Set("InitialSize", +tValue, "number")
        Do $$$AssertTrue(##class(OcuPilot.Test.DatabaseActions).MintProblem(..#EXPANDTOOL, "OCUPROBE184GA", tArgs) [ "'InitialSize'", tValue _ ": and the mint")
    }
    Do $$$AssertEquals($ClassMethod(..#ACCEPT, "Writes"), "", "no refused write reached the port")
}

/// <p>DW-1791 (AC11): a file edit naming as its new volume directory another database's directory, or
/// another database's volume directory, is refused on <code>volumePath</code> with
/// <code>DATABASE.DIRECTORY.INUSE</code> at the Save and the mint; one that became another database's
/// volume directory after the mint is refused at the confirm; none sends a write. The database's own
/// directory is not refused.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.OsMgmt.DatabaseRules.DirectoryViolations</method> skips
/// the volume-directory test -> the mint legs go red; <class>OcuPilot.Port.DatabasePort</class>'s own
/// refusal is removed -> the confirm leg and "no write was sent" go red. The Save is refused under
/// either alone, since both guard it.</p>
Method TestAVolumeDirectoryInUseIsRefused()
{
    Set tA = ..AddProbe("OCUPROBE184GA")
    Set tB = ..AddProbe("OCUPROBE184GB")
    Set tRoot = $ClassMethod(..#PROBE, "Manager")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddVolumeIn", tB, tRoot _ "ocuprobe184gbv/"), "the other database has a volume in its own volume directory")
    Set ^||OcuPilotDatabaseWritePort = ..#RECORD
    For tPath = "ocuprobe184gb", "ocuprobe184gbv" {
        Set tGroup = {}
        Do tGroup.%Set("volumeRoot", tRoot, "string")
        Do tGroup.%Set("volumePath", tPath, "string")
        Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Save("file", "OCUPROBE184GA", tGroup, .tHttp, .tCode, .tFields)
        Do $$$AssertEquals(tHttp _ " " _ tFields, "422 volumePath:DATABASE.DIRECTORY.INUSE", tPath _ ": the Save is refused on volumePath (" _ tCode _ ")")
        Set tArgs = ##class(%DynamicObject).%FromJSON(tGroup.%ToJSON())
        Do tArgs.%Set("Name", "OCUPROBE184GA", "string")
        Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Mint(..#UPDATETOOL, "OCUPROBE184GA", tArgs, .tProposal, .tHttp, .tProblem)
        Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ "volumePath"), tPath _ ": and the mint (" _ tHttp _ " " _ tProblem _ ")")
    }
    Set tArgs = {"Name": "OCUPROBE184GA", "volumePath": "ocuprobe184gc"}
    Do tArgs.%Set("volumeRoot", tRoot, "string")
    Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Mint(..#UPDATETOOL, "OCUPROBE184GA", tArgs, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "a free volume directory is minted (" _ tProblem _ ")")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddVolumeIn", tB, tRoot _ "ocuprobe184gc/"), "which then becomes the other database's volume directory")
    Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseWrite).Confirm(tProposal), "422 " _ ##class(OcuPilot.Api.DatabaseError).#VALIDATION, "and the confirm is refused")
    Do $$$AssertEquals($ClassMethod(..#RECORD, "Writes"), "", "no write was sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredFile", tA, "NewVolumeDirectory"), tA, "and the database's new volume directory is unchanged")
    Set tGroup = {"volumePath": "ocuprobe184ga"}
    Do tGroup.%Set("volumeRoot", tRoot, "string")
    Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Save("file", "OCUPROBE184GA", tGroup, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tCode _ tFields, "200 ", "the database's own directory is not refused")
}

/// <p>The vendor's own faults (AC11), through <method>OcuPilot.Port.AdminPort.Invoke</method> on probe
/// objects: a <code>PUT</code> of a probe database's <code>NewVolumeDirectory</code> naming another's
/// directory (#576) or another's volume directory (#575) lands on <code>volumePath</code> as
/// <code>DATABASE.DIRECTORY.INUSE</code>, and the setting is unchanged.</p>
/// <p>Mutation (Rule 19): drop the <code>Database.SysCRUD:576</code> entry from
/// <parameter>OcuPilot.Port.AdminPort.PROPERTYFAULTS</parameter> -> the first leg goes red.</p>
Method TestTheVendorsVolumeFaultsLandOnVolumePath()
{
    Set tA = ..AddProbe("OCUPROBE184GA")
    Set tB = ..AddProbe("OCUPROBE184GB")
    Set tVolume = $ClassMethod(..#PROBE, "Manager") _ "ocuprobe184gbv/"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "AddVolumeIn", tB, tVolume), "the other database has a volume in its own volume directory")
    For tCase = $ListBuild(tB, "another database's directory"), $ListBuild(tVolume, "another database's volume directory") {
        Kill tQuery
        Set tQuery("dir") = tA
        Set tBody = {}
        Do tBody.%Set("NewVolumeDirectory", $List(tCase, 1), "string")
        Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Database.SysCRUD", "PUT", .tQuery, tBody, .tResult, .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, $List(tCase, 2) _ ": the vendor refuses it")
        Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseRefusals).ViolationFields($Get(tFault)), "volumePath:DATABASE.DIRECTORY.INUSE", $List(tCase, 2) _ ": on volumePath (" _ $Get(tHttp) _ ")")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredFile", tA, "NewVolumeDirectory"), tA, "and the setting is unchanged")
}

/// <p>The owner's database-directory rule on Add a volume (AD-21's sixth case): IRISSYS's new volume
/// directory is the manager directory, so its Add a volume is refused 409
/// <code>DATABASE.VOLUMEDIRECTORY.MANAGER</code> on the Local databases list's action and at the agent's
/// mint with the code's sentence; a probe database read as naming no new volume directory
/// (<class>OcuPilot.Test.DatabaseVolumePort</class>) is refused 409
/// <code>DATABASE.VOLUMEDIRECTORY.NONE</code> on both callers the same way, and one read as naming the
/// manager directory without its trailing separator is refused naming the manager directory. No write
/// reaches the port.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.DatabasePort.ActionViolations</method> skips the new
/// volume directory -> each leg is admitted, the accept port records the expand, and this goes red;
/// comparing the directory unnormalized admits the last leg alone.</p>
Method TestAddAVolumeNeverLeavesItsDirectoryToTheVendor()
{
    Set tManager = ##class(OcuPilot.Port.PathPort).ManagerDirectory()
    Do $$$AssertTrue(##class(OcuPilot.Port.DatabasePort).SameDirectory(..StateOf(tManager, "NewVolumeDirectory"), tManager), "IRISSYS's new volume directory is the manager directory (" _ ..StateOf(tManager, "NewVolumeDirectory") _ ")")
    Set tA = ..AddProbe("OCUPROBE184GA")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.DatabaseActions).Enable("osmgmt.localdatabases.expand"), "the agent's key is enabled")
    Do $ClassMethod(..#VOLUME, "Clear")
    Set ^||OcuPilotDatabaseWritePort = ..#ACCEPT
    Set tCode = ##class(OcuPilot.Api.DatabaseError).#VOLUMEDIRECTORYMANAGER
    Do $$$AssertEquals(..Act("IRISSYS", {"InitialSize": "1"}), "409 " _ tCode, "IRISSYS's Add a volume is refused on the screen")
    Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseActions).MintProblem(..#EXPANDTOOL, "IRISSYS", {"InitialSize": 1}), ##class(OcuPilot.Api.DatabaseError).ReasonFor(tCode), "and at the agent's mint, with the code's sentence")
    Set ^||OcuPilotDatabaseWritePort = ..#VOLUME
    Do $ClassMethod(..#VOLUME, "Arm", "")
    Set tCode = ##class(OcuPilot.Api.DatabaseError).#VOLUMEDIRECTORYNONE
    Do $$$AssertEquals(..Act("OCUPROBE184GA", {"InitialSize": "1"}), "409 " _ tCode, "a database naming no new volume directory is refused on the screen")
    Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseActions).MintProblem(..#VOLUMEEXPANDTOOL, "OCUPROBE184GA", {"InitialSize": 1}), ##class(OcuPilot.Api.DatabaseError).ReasonFor(tCode), "and at the agent's mint, with the code's sentence")
    Do $ClassMethod(..#VOLUME, "Arm", $Extract(tManager, 1, *-1))
    Do $$$AssertEquals(..Act("OCUPROBE184GA", {"InitialSize": "1"}), "409 " _ ##class(OcuPilot.Api.DatabaseError).#VOLUMEDIRECTORYMANAGER, "the manager directory without its trailing separator (" _ $Extract(tManager, 1, *-1) _ ") is still the manager directory")
    Do $$$AssertEquals($ClassMethod(..#VOLUME, "Writes"), "", "no write reached the port")
}

/// <p>The same rule past a threshold (a grow or a defragment of a database with a new volume threshold
/// adds volume files in its new volume directory, measured): a probe database read as naming the
/// manager directory (<class>OcuPilot.Test.DatabaseVolumePort</class>, read by the Save's rules and its
/// write alike) grows on the editor's Save and defragments on Database details while its threshold is
/// 0; once a threshold is set, the Save is refused 422 on <code>Size</code> by its rules, and Database
/// details' defragment 409 and the agent's mint of a grow and of a defragment, each naming the manager
/// directory, and naming none when the directory reads unset; and the agent's grow and defragment
/// minted while the instance's own reading passed are refused at their confirm as the target having
/// changed, the new volume directory being in their fingerprint (AD-51). Only the two threshold-0
/// writes reach the port, which sends neither.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.DatabasePort.PlacesVolume</method> answers 0 for the
/// threshold types -> the threshold legs are admitted and this goes red; answering 1 for them whatever
/// the threshold reddens the threshold-0 legs; <method>OcuPilot.Area.OsMgmt.DatabaseRules.GrowViolations</method>
/// dropping the state code -> the Save reaches the port's 409 and this goes red;
/// <parameter>OcuPilot.Screen.Tool.LocalDatabaseGrow.FINGERPRINTSUBJECT</parameter> without the new
/// volume directory -> the grow's confirm answers the rule's 409 and this goes red.</p>
Method TestAGrowOrDefragmentPastAThresholdKeepsTheRule()
{
    Set tA = ..AddProbe("OCUPROBE184GA")
    Set tManager = ##class(OcuPilot.Port.PathPort).ManagerDirectory()
    Do $$$AssertStatusOK(##class(OcuPilot.Test.DatabaseActions).Enable("osmgmt.localdatabases.grow", "osmgmt.databasedetails.defragment"), "the agent's keys are enabled")
    Do $ClassMethod(..#VOLUME, "Clear")
    Do $ClassMethod(..#VOLUME, "Arm", tManager)
    Set ^||OcuPilotDatabaseWritePort = ..#VOLUME
    Set ^||OcuPilotDatabaseRulesPort = ..#VOLUME
    Set tGroup = {}
    Do tGroup.%Set("Size", ..StateOf(tA, "Size") + 1, "number")
    Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Save("size", "OCUPROBE184GA", tGroup, .tHttp, .tCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tCode _ tFields, "200 ", "with no threshold the Save's grow is not held to the rule")
    Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseActions).Act("defragment", tA), "200 ", "nor Database details' defragment")
    Do $$$AssertEquals($ClassMethod(..#VOLUME, "Writes"), "Database.Actions/MODIFYSIZE,Database.Actions/DEFRAGMENT", "each reaching the port, which sends neither")

    Do $$$AssertStatusOK(..SetFile(tA, "NewVolumeThreshold", 5), "a new volume threshold is set")
    For tArmed = tManager, "" {
        Set tRuleCode = $Select(tArmed = "": ##class(OcuPilot.Api.DatabaseError).#VOLUMEDIRECTORYNONE, 1: ##class(OcuPilot.Api.DatabaseError).#VOLUMEDIRECTORYMANAGER)
        Set tWanted = "409 " _ tRuleCode
        Set tLabel = $Select(tArmed = "": "naming no new volume directory", 1: "naming the manager directory")
        Set tGrow = {}
        Do tGrow.%Set("Size", ..StateOf(tA, "Size") + 2, "number")
        Set tGrowProposal = ##class(OcuPilot.Test.DatabaseActions).Minted(..#GROWTOOL, "OCUPROBE184GA", tGrow)
        Set tDefragProposal = ##class(OcuPilot.Test.DatabaseActions).Minted(..#DEFRAGMENTTOOL, tA, {})
        Do $$$AssertTrue($IsObject(tGrowProposal) && $IsObject(tDefragProposal), tLabel _ ": the agent's grow and defragment are minted over the instance's own reading")
        Do $ClassMethod(..#VOLUME, "Arm", tArmed)
        Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Save("size", "OCUPROBE184GA", tGroup, .tHttp, .tCode, .tFields)
        Do $$$AssertEquals(tHttp _ " " _ tCode _ tFields, "422 Size:" _ tRuleCode, tLabel _ ": the Save's grow is refused on Size by its rules")
        Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseActions).Act("defragment", tA), tWanted, tLabel _ ": and Database details' defragment")
        Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseActions).MintProblem(..#VOLUMEGROWTOOL, "OCUPROBE184GA", tGrow), ##class(OcuPilot.Api.DatabaseError).ReasonFor(tRuleCode), tLabel _ ": and the agent's mint of the grow, with the code's sentence")
        Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseActions).MintProblem(..#VOLUMEDEFRAGMENTTOOL, tA, {}), ##class(OcuPilot.Api.DatabaseError).ReasonFor(tRuleCode), tLabel _ ": and of the defragment")
        Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseWrite).Confirm(tGrowProposal), "409 PROPOSAL.TARGETCHANGED", tLabel _ ": the agent's grow minted over the instance's own reading is refused at its confirm, its reviewed directory having moved")
        Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseWrite).Confirm(tDefragProposal), "409 PROPOSAL.TARGETCHANGED", tLabel _ ": and so is its defragment")
    }
    Do $$$AssertEquals($ClassMethod(..#VOLUME, "Writes"), "Database.Actions/MODIFYSIZE,Database.Actions/DEFRAGMENT", "no refused write reached the port")
}

/// <p>The same rule on the file edit (DW-1860): a new volume threshold above 0 is refused 422
/// <code>DATABASE.NEWVOLUMETHRESHOLD.MANAGER</code> on <code>NewVolumeThreshold</code> where the file's
/// new volume directory is the manager directory -- IRISSYS's own, and a probe database read as naming
/// it (<class>OcuPilot.Test.DatabaseVolumePort</class>) -- on the editor's Save, at the agent's mint
/// with the code's sentence, and at the port's write for a body carrying it; a probe database naming
/// its own directory keeps its threshold on the Save and at the port. The write port sends nothing.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.OsMgmt.DatabaseRules.ThresholdViolations</method> adds
/// no violation -> the mint and the armed Save legs go red; <method>OcuPilot.Port.DatabasePort.Invoke</method>
/// skips <method>OcuPilot.Port.DatabasePort.ThresholdRefused</method> -> the port legs go red.</p>
Method TestANewVolumeThresholdNeverSendsVolumesToTheManagerDirectory()
{
    Set tManager = ##class(OcuPilot.Port.PathPort).ManagerDirectory()
    Set tA = ..AddProbe("OCUPROBE184GA")
    Set tCode = ##class(OcuPilot.Api.DatabaseError).#NEWVOLUMETHRESHOLDMANAGER
    Set ^||OcuPilotDatabaseWritePort = ..#ACCEPT
    Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Save("file", "IRISSYS", {"NewVolumeThreshold": 5}, .tHttp, .tHttpCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tFields, "422 NewVolumeThreshold:" _ tCode, "IRISSYS's threshold is refused on the Save")
    Do $$$AssertEquals(##class(OcuPilot.Test.DatabaseActions).MintProblem(..#UPDATETOOL, "IRISSYS", {"NewVolumeThreshold": 5}), "'NewVolumeThreshold': " _ ##class(OcuPilot.Api.DatabaseError).ReasonFor(tCode), "and at the agent's mint, with the code's sentence")
    Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Save("file", "OCUPROBE184GA", {"NewVolumeThreshold": 5}, .tHttp, .tHttpCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tFields, "200 ", "a database whose new volume directory is its own keeps the threshold on the Save")
    Set ^||OcuPilotDatabaseRulesPort = ..#VOLUME
    Do $ClassMethod(..#VOLUME, "Arm", tManager)
    Set tSC = ##class(OcuPilot.Test.DatabaseWrite).Save("file", "OCUPROBE184GA", {"NewVolumeThreshold": 5}, .tHttp, .tHttpCode, .tFields)
    Do $$$AssertEquals(tHttp _ " " _ tFields, "422 NewVolumeThreshold:" _ tCode, "and one read as naming the manager directory is refused by its rules")
    Do $ClassMethod(..#ACCEPT, "Clear")
    For tCase = $ListBuild("IRISSYS", tManager, "422 NewVolumeThreshold:" _ tCode), $ListBuild("OCUPROBE184GA", tManager, "422 NewVolumeThreshold:" _ tCode), $ListBuild("OCUPROBE184GA", tA, "200 ") {
        Kill tQuery
        Set tQuery("name") = $List(tCase, 1)
        Set tBody = {}
        Do tBody.%Set("NewVolumeThreshold", 5, "number")
        Do tBody.%Set("NewVolumeDirectory", $List(tCase, 2), "string")
        Set tSC = $ClassMethod(..#ACCEPT, "Invoke", "Database.SysCRUD", "PUT", .tQuery, tBody, .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(+$Get(tHttp) _ " " _ ##class(OcuPilot.Test.DatabaseRefusals).ViolationFields($Get(tFault)), $List(tCase, 3), "the port's write of " _ $List(tCase, 1) _ " with new volumes in " _ $List(tCase, 2))
    }
    Do $$$AssertEquals($ClassMethod(..#ACCEPT, "Writes"), "Database.SysCRUD/PUT", "only the probe naming its own directory reached the vendor call, which the port does not send")
}

/// <p>Create the probe database <var>pName</var> and answer its directory.</p>
Method AddProbe(pName As %String) As %String
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Add", pName), pName _ " is created")
    Quit $ClassMethod(..#PROBE, "DirectoryOf", pName)
}

/// <p>Run the Local databases list's <code>expand</code> action on <var>pName</var> with the values
/// <var>pValues</var>, answering <code>http code</code> and the envelope in <var>pAnswer</var>.</p>
ClassMethod Act(pName As %String, pValues As %DynamicObject = "", Output pAnswer As %String) As %String
{
    Set pAnswer = ""
    Set tBody = {"action": "expand"}
    Do tBody.%Set("id", pName, "string")
    If $IsObject(pValues) Do tBody.%Set("values", pValues)
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, tBody, .pAnswer, .tStatus)
    If $$$ISERR(tSC) Quit "error " _ $System.Status.GetErrorText(tSC)
    Set tCode = ""
    Set tParsed = ##class(OcuPilot.Test.DatabaseWrite).Parsed(pAnswer)
    If (+tStatus >= 400) && $IsObject(tParsed) Set tCode = tParsed.%Get("code")
    Quit tStatus _ " " _ tCode
}

/// <p>Set the file setting <var>pField</var> of the database in <var>pDirectory</var> to the number
/// <var>pValue</var> through the admin port, as seeding.</p>
ClassMethod SetFile(pDirectory As %String, pField As %String, pValue As %Integer) As %Status
{
    Kill tQuery
    Set tQuery("dir") = pDirectory
    Set tBody = {}
    Do tBody.%Set(pField, pValue, "number")
    Quit ##class(OcuPilot.Port.AdminPort).Invoke("Database.SysCRUD", "PUT", .tQuery, tBody, .tResult, .tHttp, .tFault)
}

/// <p>The rendered <var>pField</var> of the database in <var>pDirectory</var>'s <code>STATE</code>.</p>
ClassMethod StateOf(pDirectory As %String, pField As %String) As %String
{
    Quit ##class(OcuPilot.Test.DatabaseActions).StateOf(pDirectory, pField)
}

}
