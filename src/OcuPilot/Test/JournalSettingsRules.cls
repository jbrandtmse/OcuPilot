/// <p>Pins Story 18.18's journal settings rules on both callers (AD-21, AD-39, AD-55): every shape
/// refused on its field, the three directory refusals on their path fields -- the manager directory,
/// a directory the instance does not hold, OcuPilot's served directory -- the shown-only and undeclared
/// keys refused as unexpected, a directory removed since the mint refused at the confirm, and the
/// port's own check at the write; with no settings <code>PUT</code> reaching
/// <class>OcuPilot.Test.JournalSettingsPort</class>, which holds any that would.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, a caller holding
/// <code>%All</code>, and both <parameter>ARMINGVARIABLE</parameter> and
/// <parameter>PRINCIPALSVARIABLE</parameter> reading <code>1</code>: it creates and removes a probe
/// directory under the manager directory, and restricts the file selector's allow-list to reach the
/// served directory, recording it before each test and restoring it after
/// (<class>OcuPilot.Test.PathPortFixture</class>). It sends no settings write.</p>
Class OcuPilot.Test.JournalSettingsRules Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class's journal settings calls, set by
/// <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_JOURNAL";

/// <p>The environment variable that arms its change to the file selector's allow-list.</p>
Parameter PRINCIPALSVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.JournalProbe";

Parameter SEAM = "OcuPilot.Test.JournalSettingsPort";

Parameter FIXTURE = "OcuPilot.Test.PathPortFixture";

Parameter TOOLCLASS = "OcuPilot.Screen.Tool.JournalSettingsUpdate";

Parameter WRITE = "OcuPilot.Test.JournalSettingsWrite";

/// <p>The suffix of a probe directory the instance does not hold, and of one removed after a
/// mint.</p>
Parameter ABSENTSUFFIX = "none";

Parameter GONESUFFIX = "gone";

/// <p>Whether the file selector purpose existed before the test ran. Prefix deliberately not
/// "Test".</p>
Property SavedExists As %Boolean [ InitialExpression = 0 ];

/// <p>Whether it was restricted.</p>
Property SavedRestricted As %Boolean [ InitialExpression = 0 ];

/// <p>Its root paths, in the vendor's order.</p>
Property SavedPaths As %List;

/// <p>Whether <method>OnBeforeOneTest</method> recorded the allow-list.</p>
Property SavedOk As %Boolean [ InitialExpression = 0 ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..SavedExists = 0
    Set ..SavedRestricted = 0
    Set ..SavedPaths = ""
    Set ..SavedOk = 0
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#PRINCIPALSVARIABLE) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.JournalSettingsRules creates probe directories and restricts this instance's %GUIFileSelector allow-list, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#PRINCIPALSVARIABLE _ " must both read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets them.")
    }
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $ClassMethod(..#SEAM, "Clear")
    Do $ClassMethod(..#SEAM, "Hold")
    Set ^||OcuPilotDatabaseWritePort = ..#SEAM
    Do $ClassMethod(..#FIXTURE, "Reset")
    Set tSC = $ClassMethod(..#FIXTURE, "Snapshot", .tExists, .tRestricted, .tPaths)
    If $$$ISERR(tSC) Quit tSC
    Set ..SavedExists = tExists
    Set ..SavedRestricted = tRestricted
    Set ..SavedPaths = tPaths
    Set ..SavedOk = 1
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Do $ClassMethod(..#SEAM, "Clear")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Do $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    Do $ClassMethod(..#FIXTURE, "Reset")
    If '..SavedOk Quit $$$OK
    Set ..SavedOk = 0
    Quit $ClassMethod(..#FIXTURE, "Restore", ..SavedExists, ..SavedRestricted, ..SavedPaths)
}

Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

/// <p>AC4: each shape -- a file size over 4079 or not whole, purge days over 100, purge backups over
/// 10, a prefix holding a slash or a dot, a flag sent as text -- is refused on its field, on the Save
/// before the settings are read and at the agent's mint, and no write is sent; the agent's own schema
/// refuses a flag sent as text before anything is minted; the bounds themselves are admitted.</p>
/// <p>Mutation (Rule 19): drop the boolean check from
/// <method>OcuPilot.Area.OsMgmt.JournalRules.Validate</method> -&gt; the flag-as-text legs go red.</p>
Method TestEveryShapeIsRefusedOnItsFieldOnBothCallers()
{
    Set tCases = $ListBuild($ListBuild("FileSizeLimit", 5000, "number", "JOURNAL.FILESIZE.SHAPE"), $ListBuild("FileSizeLimit", 1.5, "number", "JOURNAL.FILESIZE.SHAPE"), $ListBuild("DaysBeforePurge", 101, "number", "JOURNAL.PURGE.SHAPE"), $ListBuild("BackupsBeforePurge", 11, "number", "JOURNAL.PURGE.SHAPE"))
    Set tCases = tCases _ $ListBuild($ListBuild("JournalFilePrefix", "a/b", "string", "JOURNAL.PREFIX.SHAPE"), $ListBuild("JournalFilePrefix", "a.b", "string", "JOURNAL.PREFIX.SHAPE"), $ListBuild("FreezeOnError", "true", "string", "JOURNAL.BOOLEAN.SHAPE"), $ListBuild("CompressFiles", 1, "number", "JOURNAL.BOOLEAN.SHAPE"))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tField = $List(tCase, 1)
        Set tCode = $List(tCase, 4)
        Set tArgs = {}
        Do tArgs.%Set(tField, $List(tCase, 2), $List(tCase, 3))
        Do $ClassMethod(..#SEAM, "Clear")
        Do $ClassMethod(..#SEAM, "Hold")
        Set tSC = $ClassMethod(..#WRITE, "Save", tArgs, .tHttp, .tRefusal, .tFields, .tReadBack)
        Do $$$AssertEquals(tHttp _ " " _ tFields, "422 " _ tField _ ":" _ tCode, tArgs.%ToJSON() _ " is refused on its field by the Save")
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 0, "before the settings are read")
        Do tArgs.%Set("Name", "SYSTEM", "string")
        Set tSC = $ClassMethod(..#WRITE, "Mint", tArgs, .tProposal, .tHttp, .tProblem)
        Do $$$AssertEquals(tHttp, 400, tArgs.%ToJSON() _ " is refused at the agent's mint")
        Do $$$AssertTrue(tProblem [ ("'" _ tField _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation(tCode)), "naming its field and the published sentence: " _ tProblem)
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Puts"), 0, "and no write is sent")
    }
    Set tSC = ##class(OcuPilot.Screen.Tool.JournalSettingsUpdate).View("", {"Name": "SYSTEM", "FreezeOnError": "true"}, 0, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "400 TOOL.ARGUMENTS", "the agent's schema refuses a flag sent as text")
    Kill tViolations
    Set tSC = ##class(OcuPilot.Area.OsMgmt.JournalRules).Validate({"FileSizeLimit": 0, "DaysBeforePurge": 100, "BackupsBeforePurge": 10, "JournalFilePrefix": "Ab9-_", "FreezeOnError": false}, .tViolations, .tHttp, .tFault)
    Do $$$AssertEquals($$$ISOK(tSC) _ " " _ +$Get(tViolations), "1 0", "and the bounds are admitted: a size of 0 and days and backups at their limits")
    Set tSC = ##class(OcuPilot.Area.OsMgmt.JournalRules).Validate({"FileSizeLimit": 4079, "JournalFilePrefix": ($Translate($Justify("", 64), " ", "a"))}, .tViolations, .tHttp, .tFault)
    Do $$$AssertEquals($$$ISOK(tSC) _ " " _ +$Get(tViolations), "1 0", "as are 4079 and a 64-character prefix")
    Set tSC = ##class(OcuPilot.Area.OsMgmt.JournalRules).Validate({"JournalFilePrefix": ($Translate($Justify("", 65), " ", "a"))}, .tViolations, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tViolations), 1, "while a 65-character prefix is refused")
}

/// <p>AC3, AD-21: a directory is refused on its path field when it is the manager directory itself,
/// one the instance does not hold, or OcuPilot's served directory -- on the Save before the settings
/// are read, and at the agent's mint -- and no write is sent.</p>
/// <p>Mutation (Rule 19): drop the <code>DirectoryExists</code> check from
/// <method>OcuPilot.Port.JournalPort.ResolveDirectory</method> -&gt; the absent legs go red; pass
/// <var>pVendorWrites</var> 0 there -&gt; the manager directory and served legs go red.</p>
Method TestEachDirectoryRefusalLandsOnItsField()
{
    Set tRoot = $ClassMethod(..#PROBE, "Manager")
    Set tAbsent = $ClassMethod(..#PROBE, "DirectoryFor", ..#ABSENTSUFFIX)
    If ##class(%File).DirectoryExists(tAbsent) Do ##class(%File).RemoveDirectory(tAbsent)
    Do $$$AssertTrue('##class(%File).DirectoryExists(tAbsent), "the absent probe directory is absent")
    Set tServed = ##class(OcuPilot.Port.PathPort).ServedDirectory()
    Set tParent = ##class(%File).ParentDirectoryName(tServed)
    Set tServedName = $Piece(tServed, "/", *-1)
    Set tCases = $ListBuild($ListBuild("primary", tRoot, "", "PATH.MANAGERDIR"), $ListBuild("primary", tRoot, $Piece(tAbsent, "/", *-1), "JOURNAL.DIRECTORY.ABSENT"), $ListBuild("primary", tParent, tServedName, "PATH.SERVED"))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tWhich = $List(tCase, 1)
        Set tCode = $List(tCase, 4)
        If tCode = "PATH.SERVED" {
            Do $$$AssertStatusOK($ClassMethod(..#FIXTURE, "SetUp", 1, $ListBuild(tServed, tParent)), "the allow-list is restricted to the served directory and the one above it")
        }
        Set tArgs = {}
        Do tArgs.%Set(tWhich _ "Root", $List(tCase, 2), "string")
        Do tArgs.%Set(tWhich _ "Path", $List(tCase, 3), "string")
        Do $ClassMethod(..#SEAM, "Clear")
        Do $ClassMethod(..#SEAM, "Hold")
        Set tSC = $ClassMethod(..#WRITE, "Save", tArgs, .tHttp, .tRefusal, .tFields, .tReadBack)
        Do $$$AssertEquals(tHttp _ " " _ tFields, "422 " _ tWhich _ "Path:" _ tCode, tArgs.%ToJSON() _ " is refused on its path field by the Save")
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 0, "before the settings are read")
        Do tArgs.%Set("Name", "SYSTEM", "string")
        Set tSC = $ClassMethod(..#WRITE, "Mint", tArgs, .tProposal, .tHttp, .tProblem)
        Do $$$AssertEquals(tHttp, 400, tArgs.%ToJSON() _ " is refused at the agent's mint")
        Do $$$AssertTrue(tProblem [ ("'" _ tWhich _ "Path': " _ ##class(OcuPilot.Api.Error).ReasonForViolation(tCode)), "naming its path field and the published sentence: " _ tProblem)
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Puts"), 0, "and no write is sent")
    }
    Do $$$AssertTrue('##class(%File).DirectoryExists(tAbsent), "and the absent directory was not created")
}

/// <p>AC4: a key outside the tool's settable fields -- the three shown-only keys, a directory named
/// as a path, an unknown key -- is refused 400 <code>PORT.FIELD.UNEXPECTED</code> on that key by the
/// Save with nothing read, and the agent's closed schema refuses the shown-only keys 400
/// <code>TOOL.ARGUMENTS</code>.</p>
/// <p>Mutation (Rule 19): admit every key in <method>OcuPilot.Area.OsMgmt.JournalSave.Update</method>
/// -&gt; the Save legs reach the instance and go red.</p>
Method TestAShownOnlyOrUndeclaredKeyIsRefused()
{
    For tKey = "wijdir", "targwijsz", "ArchiveName", "CurrentDirectory", "AlternateDirectory", "Bogus" {
        Set tArgs = {}
        Do tArgs.%Set(tKey, $Select(tKey = "targwijsz": 1, 1: "/x/"))
        Do $ClassMethod(..#SEAM, "Clear")
        Do $ClassMethod(..#SEAM, "Hold")
        Set tSC = $ClassMethod("OcuPilot.Test.JournalSettingsSaveFixture", "Update", tArgs, .tHttp, .tFault, .tViolations, .tReadBack)
        Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code") _ " " _ tFault.%Get("detail").%Get("violations").%Get(0).%Get("field"), 1: ""), "400 PORT.FIELD.UNEXPECTED " _ tKey, tKey _ " is refused on the Save as unexpected")
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls") _ " " _ $ClassMethod(..#SEAM, "Puts"), "0 0", "with nothing read or sent")
    }
    For tKey = "ArchiveName", "wijdir", "targwijsz", "CurrentDirectory" {
        Set tArgs = {"Name": "SYSTEM"}
        Do tArgs.%Set(tKey, $Select(tKey = "targwijsz": 1, 1: "/x/"))
        Set tSC = ##class(OcuPilot.Screen.Tool.JournalSettingsUpdate).View("", tArgs, 0, .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "400 TOOL.ARGUMENTS", "the agent's closed schema refuses " _ tKey)
    }
}

/// <p>AC3: an alternate whose directory is removed after the mint is refused at the confirm on its
/// path field, the proposal left live and nothing sent; and the port's own write resolves the
/// directory again and refuses it 422 <code>JOURNAL.VALIDATION</code> on that field before any
/// call.</p>
/// <p>Mutation (Rule 19): have
/// <method>OcuPilot.Screen.Tool.JournalSettingsUpdate.ConfirmProblem</method> answer nothing -&gt; the
/// confirm reaches the port, which refuses it 422, and the confirm leg goes red.</p>
Method TestADirectoryRemovedSinceTheMintIsRefusedAtTheConfirm()
{
    Set tSC = $ClassMethod(..#PROBE, "SeedDirectory", ..#GONESUFFIX, .tDirectory)
    Do $$$AssertStatusOK(tSC, "the probe directory exists")
    If $$$ISERR(tSC) Quit
    Set tRoot = $ClassMethod(..#PROBE, "Manager")
    Set tName = $Piece(tDirectory, "/", *-1)
    Set tSC = $ClassMethod(..#WRITE, "Mint", {"Name": "SYSTEM", "alternateRoot": (tRoot), "alternatePath": (tName)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the alternate is minted while the directory exists (" _ tProblem _ ")")
    If $$$ISERR(tSC) Quit
    Do $$$AssertTrue(##class(%File).RemoveDirectory(tDirectory), "the directory is removed after the mint")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $ClassMethod(..#SEAM, "Hold")
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals($Get(tHttp) _ " " _ $Get(tCode), "400 TOOL.ARGUMENTS", "the confirm is refused")
    Set tProblem = $Select($IsObject($Get(tDetail)): tDetail.%Get("problem"), 1: "")
    Do $$$AssertTrue(tProblem [ ("'alternatePath': " _ ##class(OcuPilot.Api.JournalError).#REASONDIRECTORYABSENT), "on its path field: " _ tProblem)
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Puts"), 0, "and nothing is sent")
    Set tFound = 0
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
    Do $$$AssertEquals($Get(tValues("state")), "live", "the proposal is left live")

    Kill tQuery
    Set tQuery("alternateRoot") = tRoot
    Set tQuery("alternatePath") = tName
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Journal.Settings", "PUT", .tQuery, {"FileSizeLimit": 1024}, .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code") _ " " _ tFault.%Get("detail").%Get("violations").%Get(0).%Get("field") _ ":" _ tFault.%Get("detail").%Get("violations").%Get(0).%Get("code"), 1: ""), "422 JOURNAL.VALIDATION alternatePath:JOURNAL.DIRECTORY.ABSENT", "the port's own write refuses the directory on its field")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Puts"), 0, "before any call")
}

}
