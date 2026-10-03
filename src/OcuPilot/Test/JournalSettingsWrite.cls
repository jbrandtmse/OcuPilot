/// <p>Pins Story 18.18's journal settings writes against the instance's own journal (AD-4, AD-6,
/// AD-21, AD-55, AD-58), each on both callers -- Journal settings' Save
/// (<class>OcuPilot.Test.JournalSettingsSaveFixture</class>, and the route over the wire) and the
/// agent's proposal and confirmation (<class>OcuPilot.Test.SeamJournalSettingsUpdate</class>,
/// confirmed through <class>OcuPilot.Test.DatabaseConfirm</class>), every settings <code>PUT</code>
/// recorded by <class>OcuPilot.Test.JournalSettingsPort</class>: a size change sending the settable set
/// read fresh and none of the shown-only keys; a key moved since the mint refusing the confirm; an
/// alternate picked to a probe directory that Journals' directory switch then moves journaling to and
/// back; a primary picked to it, which journaling moves to at once; the purge rule's two branches; and
/// the Freeze on error consequence on the card.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s test account, journaling on, a caller holding
/// <code>%All</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>: it changes the
/// instance's journal settings, which starts journal files, seeds a probe directory and switches the
/// journal directory, and restores the settings and the directory it found after every test. The
/// journal files its writes start are kept.</p>
Class OcuPilot.Test.JournalSettingsWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_JOURNAL";

Parameter PROBE = "OcuPilot.Test.JournalProbe";

Parameter SEAM = "OcuPilot.Test.JournalSettingsPort";

Parameter SAVE = "OcuPilot.Test.JournalSettingsSaveFixture";

Parameter TOOL = "OcuPilot.Test.SeamJournalSettingsUpdate";

Parameter CONFIRM = "OcuPilot.Test.DatabaseConfirm";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The ten keys a settings write sends, sorted.</p>
Parameter SETTABLE = "AlternateDirectory,BackupsBeforePurge,CompressFiles,CurrentDirectory,DaysBeforePurge,FileSizeLimit,FreezeOnError,JournalFilePrefix,JournalcspSession,PurgeArchived";

/// <p>The suffix of the probe directory an alternate is picked to.</p>
Parameter DIRSUFFIX = "settings";

/// <p>The journal settings found before the class ran, as <code>JournalProbe.JournalSettings</code>
/// answers them.</p>
Property SavedSettings As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..SavedSettings = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.JournalSettingsWrite changes this instance's journal settings and switches its journal directory, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSettings = $ClassMethod(..#PROBE, "JournalSettings")
    If tSettings.%Get("CurrentDirectory") = "" Quit $$$ERROR($$$GeneralError, "the journal settings could not be read")
    Set ..SavedSettings = tSettings.%ToJSON()
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnAfterAllTests() As %Status
{
    Set tSC = ..Restore()
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", .tRemaining))
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do $ClassMethod(..#SEAM, "Clear")
    Set ^||OcuPilotDatabaseWritePort = ..#SEAM
    Quit ..Restore()
}

/// <p>Whatever the test did, the journal settings read as found, journaling writes in the primary
/// directory found, and the proposals it minted are removed.</p>
Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Do $ClassMethod(..#SEAM, "Clear")
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tSC = ..Restore()
    Do $$$AssertStatusOK(tSC, "the journal settings are restored: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "JournalSettings").%ToJSON(), ..SavedSettings, "Config.Journal reads as found")
    Set tSaved = ##class(%DynamicObject).%FromJSON(..SavedSettings)
    Do $$$AssertEquals($ZConvert($ClassMethod(..#PROBE, "CurrentDirectory"), "L"), $ZConvert(##class(%File).NormalizeDirectory(tSaved.%Get("CurrentDirectory")), "L"), "journaling writes in the primary directory found")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining), "the probe proposals and turns are removed")
    Do $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    Quit tSC
}

/// <p>The journal settings found, put back (<class>OcuPilot.Test.JournalProbe</class>).</p>
Method Restore() As %Status
{
    If ..SavedSettings = "" Quit $$$OK
    Quit $ClassMethod(..#PROBE, "RestoreJournal", ##class(%DynamicObject).%FromJSON(..SavedSettings))
}

/// <p>AC2, AD-4: a changed file size, on the Save and on the agent's confirmed proposal, sends one
/// <code>PUT</code> of the ten settable keys read fresh with the change applied and none of
/// <code>ArchiveName</code>, <code>wijdir</code> or <code>targwijsz</code>, the same body on both;
/// the proposal shows one row, and each write reads back <code>matches</code>.</p>
/// <p>Mutation (Rule 19): keep <code>wijdir</code> in
/// <method>OcuPilot.Screen.Tool.JournalSettingsUpdate.MergeUpdate</method>'s fresh read and drop it from
/// <parameter>OcuPilot.Port.JournalPort.SHOWNONLYKEYS</parameter> -&gt; the body carries it and the key
/// legs go red. Delete <method>OcuPilot.Area.OsMgmt.JournalSave.Update</method>'s empty-diff return
/// -&gt; the no-change Save sends a PUT and its leg goes red.</p>
Method TestASizeChangeSendsTheSettableSetOnBothCallers()
{
    Set tFound = ##class(%DynamicObject).%FromJSON(..SavedSettings).%Get("FileSizeLimit")
    Set tSC = ..Save({"FileSizeLimit": (+tFound)}, .tHttp, .tCode, .tFields, .tReadBack)
    Do $$$AssertEquals(tHttp _ " " _ tCode _ tFields _ " " _ $ClassMethod(..#SEAM, "Puts") _ " " _ $IsObject(tReadBack), "200  0 0", "a Save that changes nothing answers 200, sends no PUT and has no read-back")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSize = ..OtherSize()
    Set tSC = ..Save({"FileSizeLimit": (tSize)}, .tHttp, .tCode, .tFields, .tReadBack)
    Do $$$AssertEquals(tHttp _ " " _ tCode _ tFields, "200 ", "the Save answers 200")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Puts"), 1, "with one PUT")
    Set tSaveBody = $ClassMethod(..#SEAM, "PutBody", 1)
    Do $$$AssertEquals(..Keys(tSaveBody), ..#SETTABLE, "of the ten settable keys read fresh, none of the shown-only three: " _ tSaveBody)
    Do $$$AssertEquals(..Member(tSaveBody, "FileSizeLimit"), tSize, "with the change applied")
    Do $$$AssertEquals(..Verdict(tReadBack), "matches", "and its read-back matches (AD-58)")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "JournalSettings").%Get("FileSizeLimit"), tSize, "the instance holds the size")
    Do $$$AssertStatusOK(..Restore(), "the size is put back")
    Do $ClassMethod(..#SEAM, "Clear")

    Set tSC = ..Mint({"Name": "SYSTEM", "FileSizeLimit": (tSize)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's change is minted (" _ tProblem _ ")")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tProposal.%Get("target").%ToJSON(), "{""type"":""journal-settings"",""scope"":""instance"",""id"":""SYSTEM""}", "against the singleton")
    Do $$$AssertEquals(..Rows(tProposal), "FileSizeLimit " _ ##class(%DynamicObject).%FromJSON(..SavedSettings).%Get("FileSizeLimit") _ " " _ tSize, "one row, the size")
    Do $$$AssertEquals(tProposal.%Get("unchangedCount"), 9, "and the other nine keys sent unchanged")
    Do $$$AssertEquals(..Confirm(tProposal, .tResult), "200 ", "and its confirm writes")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Puts"), 1, "with one PUT")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "PutBody", 1), tSaveBody, "the body the Save sent")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("auditMarked") _ " " _ ..Verdict(tResult.%Get("readBack")), 1: ""), "1 matches", "the write is marked and reads back matches")
}

/// <p>AC2, AD-6: a settable key moved between the mint and the confirm refuses the confirm 409
/// <code>PROPOSAL.TARGETCHANGED</code>, and nothing is sent.</p>
/// <p>Mutation (Rule 19): exclude <code>DaysBeforePurge</code> from the fingerprint by dropping it from
/// the tool's merge -&gt; the confirm writes and this goes red.</p>
Method TestAKeyMovedSinceTheMintRefusesTheConfirm()
{
    Set tSaved = ##class(%DynamicObject).%FromJSON(..SavedSettings)
    Set tSC = ..Mint({"Name": "SYSTEM", "FileSizeLimit": (..OtherSize())}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the change is minted (" _ tProblem _ ")")
    If $$$ISERR(tSC) Quit
    Set tMoved = ##class(%DynamicObject).%FromJSON(..SavedSettings)
    Do tMoved.%Set("DaysBeforePurge", $Select(tSaved.%Get("DaysBeforePurge") = 3: 4, 1: 3), "string")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RestoreJournal", tMoved), "the purge days are moved out of band")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $$$AssertEquals(..Confirm(tProposal, .tResult), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused because the target moved")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Puts"), 0, "and nothing is sent")
}

/// <p>AC3, AD-21: an alternate picked as an allowed root and a probe directory's name, on the Save
/// and on the agent's confirmed proposal, is stored as the resolved directory and read back; Journals'
/// Switch directory then moves journaling there, and a second switch moves it back.</p>
/// <p>Mutation (Rule 19): have <method>OcuPilot.Screen.Tool.JournalSettingsUpdate.DerivedFields</method>
/// leave the payload as it is -&gt; the payload still names the old alternate, the Save's read-back
/// does not match and this goes red.</p>
Method TestAnAlternatePickedIsStoredAndSwitchedToAndBack()
{
    Set tPrimary = $ClassMethod(..#PROBE, "CurrentDirectory")
    Set tSC = $ClassMethod(..#PROBE, "SeedDirectory", ..#DIRSUFFIX, .tDirectory)
    Do $$$AssertStatusOK(tSC, "the probe directory exists")
    If $$$ISERR(tSC) Quit
    Set tRoot = $ClassMethod(..#PROBE, "Manager")
    Set tName = $Piece(tDirectory, "/", *-1)
    Set tSC = ..Save({"alternateRoot": (tRoot), "alternatePath": (tName)}, .tHttp, .tCode, .tFields, .tReadBack)
    Do $$$AssertEquals(tHttp _ " " _ tCode _ tFields, "200 ", "the Save answers 200")
    Do $$$AssertEquals(..Member($ClassMethod(..#SEAM, "PutBody", 1), "AlternateDirectory"), tDirectory, "sending the resolved directory under the vendor's key")
    Do $$$AssertEquals(..Verdict(tReadBack), "matches", "and its read-back matches, compared unslashed")
    Do $$$AssertEquals(##class(%File).NormalizeDirectory($ClassMethod(..#PROBE, "JournalSettings").%Get("AlternateDirectory")), tDirectory, "the instance holds the alternate")
    Set tSC = ##class(OcuPilot.Test.JournalWrite).Act("switchdirectory", "current", "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "Journals' Switch directory answers 200: " _ ##class(OcuPilot.Test.JournalWrite).Shown(tBody))
    Do $$$AssertEquals($ZConvert($ClassMethod(..#PROBE, "CurrentDirectory"), "L"), $ZConvert(tDirectory, "L"), "journaling writes in the alternate")
    Set tSC = ##class(OcuPilot.Test.JournalWrite).Act("switchdirectory", "current", "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "and a second switch answers 200")
    Do $$$AssertEquals($ZConvert($ClassMethod(..#PROBE, "CurrentDirectory"), "L"), $ZConvert(tPrimary, "L"), "journaling writes in the primary again")
    Do $$$AssertStatusOK(..Restore(), "the alternate is put back")
    Do $ClassMethod(..#SEAM, "Clear")

    Set tSC = ..Mint({"Name": "SYSTEM", "alternateRoot": (tRoot), "alternatePath": (tName)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's alternate is minted (" _ tProblem _ ")")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(..Fields(tProposal), "alternatePath,alternateRoot", "its rows are the root and the name")
    Do $$$AssertEquals(..Confirm(tProposal, .tResult), "200 ", "and its confirm writes")
    Do $$$AssertEquals(..Member($ClassMethod(..#SEAM, "PutBody", 1), "AlternateDirectory"), tDirectory, "sending the directory resolved again at the write")
    Do $$$AssertEquals(##class(%File).NormalizeDirectory($ClassMethod(..#PROBE, "JournalSettings").%Get("AlternateDirectory")), tDirectory, "the instance holds the alternate")
}

/// <p>AC3, AD-21: a primary picked as an allowed root and a probe directory's name, on the Save, is
/// sent under the vendor's primary key, read back, and journaling moves there at once (measured at
/// the story's Task 0).</p>
/// <p>Mutation (Rule 19): have <method>OcuPilot.Screen.Tool.JournalSettingsUpdate.DerivedFields</method>
/// set the primary under the alternate's key -&gt; the payload's primary is the old one, the read-back
/// differs and this goes red.</p>
Method TestAPrimaryPickedIsStoredAndJournaledTo()
{
    Set tSC = $ClassMethod(..#PROBE, "SeedDirectory", ..#DIRSUFFIX, .tDirectory)
    Do $$$AssertStatusOK(tSC, "the probe directory exists")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Save({"primaryRoot": ($ClassMethod(..#PROBE, "Manager")), "primaryPath": ($Piece(tDirectory, "/", *-1))}, .tHttp, .tCode, .tFields, .tReadBack)
    Do $$$AssertEquals(tHttp _ " " _ tCode _ tFields, "200 ", "the Save answers 200")
    Do $$$AssertEquals(..Member($ClassMethod(..#SEAM, "PutBody", 1), "CurrentDirectory"), tDirectory, "sending the resolved directory under the vendor's primary key")
    Do $$$AssertEquals(..Verdict(tReadBack), "matches", "and its read-back matches, compared unslashed")
    Do $$$AssertEquals($ZConvert($ClassMethod(..#PROBE, "CurrentDirectory"), "L"), $ZConvert(tDirectory, "L"), "journaling writes in the new primary at once")
}

/// <p>AC4: the classic page's purge rule shapes every body. With no archive target,
/// <code>PurgeArchived</code> sent true is sent false, on the Save and on the agent's confirmed
/// proposal; over a fresh read naming an archive target with <code>PurgeArchived</code> on, the merge
/// sends both purge counts 0 and shows them as rows.</p>
/// <p>Mutation (Rule 19): have <method>OcuPilot.Area.OsMgmt.JournalRules.PurgeRule</method> answer
/// the arguments as they are -&gt; the sent flag and the counts go red; have
/// <method>OcuPilot.Port.JournalPort.PurgeRule</method> leave the body as it is -&gt; the port legs
/// go red.</p>
Method TestThePurgeRuleShapesTheBody()
{
    Set tSaved = ##class(%DynamicObject).%FromJSON(..SavedSettings)
    Do $$$AssertEquals(tSaved.%Get("ArchiveName") _ "|" _ tSaved.%Get("PurgeArchived"), "|0", "the instance names no archive target and does not purge archived files (a stock configuration)")
    Set tSize = ..OtherSize()
    Set tSC = ..Save({"PurgeArchived": true, "FileSizeLimit": (tSize)}, .tHttp, .tCode, .tFields, .tReadBack)
    Do $$$AssertEquals(tHttp _ " " _ tCode _ tFields, "200 ", "the Save answers 200")
    Set tBody = $ClassMethod(..#SEAM, "PutBody", 1)
    Do $$$AssertEquals(..Member(tBody, "PurgeArchived") _ " " _ ..Member(tBody, "DaysBeforePurge") _ " " _ ..Member(tBody, "BackupsBeforePurge"), "0 " _ tSaved.%Get("DaysBeforePurge") _ " " _ tSaved.%Get("BackupsBeforePurge"), "with no archive target the flag is sent false and the counts as read: " _ tBody)
    Do $$$AssertEquals(..Verdict(tReadBack), "matches", "and its read-back matches, so the Save's own merge sent the flag false, not only the port")
    Do $$$AssertStatusOK(..Restore(), "the size is put back")
    Do $ClassMethod(..#SEAM, "Clear")

    Set tSC = ..Mint({"Name": "SYSTEM", "PurgeArchived": true, "FileSizeLimit": (tSize)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's change is minted (" _ tProblem _ ")")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(..Fields(tProposal), "FileSizeLimit", "its one row is the size: the flag does not move")
    Do $$$AssertEquals(..Confirm(tProposal, .tResult), "200 ", "and its confirm writes")
    Do $$$AssertEquals(..Member($ClassMethod(..#SEAM, "PutBody", 1), "PurgeArchived"), 0, "sending the flag false")

    Set tFresh = {"AlternateDirectory": "/j/", "ArchiveName": "ARCHIVE1", "BackupsBeforePurge": 2, "CurrentDirectory": "/j/", "DaysBeforePurge": 2, "FileSizeLimit": 1024, "FreezeOnError": false, "JournalFilePrefix": "", "JournalcspSession": false, "PurgeArchived": true, "CompressFiles": true, "wijdir": "", "targwijsz": 0, "primaryRoot": null, "primaryPath": null, "alternateRoot": null, "alternatePath": null}
    Set tClass = "OcuPilot.Screen.Tool.JournalSettingsUpdate"
    Set tSC = $ClassMethod(tClass, "MergeUpdate", tFresh, {"Name": "SYSTEM", "FileSizeLimit": 1000}, "Name", $ClassMethod(tClass, "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertStatusOK(tSC, "the merge over an archive target answers")
    Do $$$AssertEquals(tPayload.%Get("PurgeArchived") _ " " _ tPayload.%Get("DaysBeforePurge") _ " " _ tPayload.%Get("BackupsBeforePurge"), "1 0 0", "while it purges archived files, both counts are sent 0")
    Do $$$AssertEquals(tDiff.%ToJSON(), "[{""field"":""BackupsBeforePurge"",""before"":""2"",""after"":""0""},{""field"":""DaysBeforePurge"",""before"":""2"",""after"":""0""},{""field"":""FileSizeLimit"",""before"":""1024"",""after"":""1000""}]", "and the diff shows them, so the payload, the diff and the body agree")
    Do $$$AssertEquals(..Keys(tPayload.%ToJSON()), ..#SETTABLE, "the payload carries the ten keys and never the archive target")

    ; The port applies the rule again to the body it is handed, over its own settings read; the PUTs
    ; below are held by the seam and never reach the instance.
    Do $ClassMethod(..#SEAM, "Clear")
    Do $ClassMethod(..#SEAM, "Hold")
    Kill tQuery
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Journal.Settings", "PUT", .tQuery, {"PurgeArchived": true, "DaysBeforePurge": 3, "BackupsBeforePurge": 4}, .tAnswer, .tHttp, .tFault)
    Set tBody = $ClassMethod(..#SEAM, "PutBody", 1)
    Do $$$AssertEquals(..Member(tBody, "PurgeArchived") _ " " _ ..Member(tBody, "DaysBeforePurge") _ " " _ ..Member(tBody, "BackupsBeforePurge"), "0 3 4", "the port sends the flag false while the instance names no archive target: " _ tBody)
    Do $ClassMethod(..#SEAM, "Clear")
    Do $ClassMethod(..#SEAM, "Hold")
    Do $ClassMethod(..#SEAM, "Archive", "ARCHIVE1")
    Kill tQuery
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Journal.Settings", "PUT", .tQuery, {"PurgeArchived": true, "DaysBeforePurge": 3, "BackupsBeforePurge": 4}, .tAnswer, .tHttp, .tFault)
    Set tBody = $ClassMethod(..#SEAM, "PutBody", 1)
    Do $$$AssertEquals(..Member(tBody, "PurgeArchived") _ " " _ ..Member(tBody, "DaysBeforePurge") _ " " _ ..Member(tBody, "BackupsBeforePurge"), "1 0 0", "and both counts 0 while its read names one: " _ tBody)
    Do $ClassMethod(..#SEAM, "Clear")
}

/// <p>AC6: a proposal whose payload leaves <code>FreezeOnError</code> on carries the consequence
/// <code>JOURNAL.SETTINGS.FREEZE</code>, which the card states; one that leaves it off carries none.
/// Neither is confirmed.</p>
/// <p>Mutation (Rule 19): have
/// <method>OcuPilot.Screen.Tool.JournalSettingsUpdate.Consequence</method> answer <code>""</code>
/// -&gt; the first leg goes red.</p>
Method TestFreezeOnErrorCarriesItsConsequence()
{
    Do $$$AssertEquals(##class(%DynamicObject).%FromJSON(..SavedSettings).%Get("FreezeOnError"), 0, "the instance does not freeze on a journal error (a stock configuration)")
    Set tSC = ..Mint({"Name": "SYSTEM", "FreezeOnError": true}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "turning it on is minted (" _ tProblem _ ")")
    Do $$$AssertEquals(..Consequence($Get(tProposal)), "JOURNAL.SETTINGS.FREEZE", "carrying the consequence")
    Set tSC = ..Mint({"Name": "SYSTEM", "FileSizeLimit": (..OtherSize())}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "a size change is minted (" _ tProblem _ ")")
    Do $$$AssertEquals(..Consequence($Get(tProposal)), "", "carrying none, since it leaves the flag off")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Puts"), 0, "and nothing is sent")
}

/// <p>AD-12, AD-55: <code>PUT /api/ocupilot/journal/settings</code> over the wire answers a shown-only
/// key 400 <code>PORT.FIELD.UNEXPECTED</code> on that field with nothing written, and a size change
/// 200 with its read-back, each as JSON.</p>
/// <p>Mutation (Rule 19): admit every key in <method>OcuPilot.Area.OsMgmt.JournalSave.Update</method>
/// -&gt; the kernel merge refuses the key as <code>TOOL.ARGUMENTS</code> instead and the 400 leg's
/// code goes red.</p>
Method TestTheRouteAnswersOverTheWire()
{
    Set tPath = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/journal/settings"
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tPath, tUser, tPassword, .tStatus, .tRaw, .tHeaders, "{""wijdir"":""/x/""}", "application/json")
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 400, "a shown-only key is refused")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Set tBody = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(tBody.%Get("code") _ " " _ tBody.%Get("detail").%Get("violations").%Get(0).%Get("field"), "PORT.FIELD.UNEXPECTED wijdir", "on that field: " _ tRaw)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "JournalSettings").%ToJSON(), ..SavedSettings, "and nothing is written")
    Set tSize = ..OtherSize()
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tPath, tUser, tPassword, .tStatus, .tRaw, .tHeaders, "{""FileSizeLimit"":" _ tSize _ "}", "application/json")
    Do $$$AssertEquals(tStatus, 200, "a size change answers 200: " _ $Get(tRaw))
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Set tBody = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(..Verdict(tBody.%Get("readBack")), "matches", "with its read-back")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "JournalSettings").%Get("FileSizeLimit"), tSize, "and the instance holds the size")
}

/// <p>A file size other than the one found.</p>
Method OtherSize() As %Integer
{
    Quit $Select(##class(%DynamicObject).%FromJSON(..SavedSettings).%Get("FileSizeLimit") = 1000: 1001, 1: 1000)
}

/// <p>The Save of <var>pBody</var> in this process, as <code>http</code>, the refusal's code, and
/// <code>field:code</code> per violation.</p>
ClassMethod Save(pBody As %DynamicObject, Output pHttp As %Integer, Output pCode As %String, Output pFields As %String, Output pReadBack As %DynamicObject) As %Status
{
    Set pCode = ""
    Set pFields = ""
    Set pReadBack = ""
    Set tSC = $ClassMethod(..#SAVE, "Update", pBody, .tHttp, .tFault, .tViolations, .pReadBack)
    Set pHttp = 200
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

/// <p>Mint the seam tool's proposal for <var>pArgs</var> as the caller, in a seeded turn.</p>
ClassMethod Mint(pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttp As %Integer, Output pProblem As %String) As %Status
{
    Set pProposal = ""
    Set pHttp = 0
    Set pProblem = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    If $$$ISERR(tSC) Quit tSC
    Set tClass = ..#TOOL
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Mint($Parameter(tClass, "DESCRIPTORCLASS"), $Parameter(tClass, "TOOLNAME"), $Username, "", tTurn, pArgs, ..#LIMITS, .tResult, .pHttp, .tFault, $ClassMethod(tClass, "Endpoint"), $ClassMethod(tClass, "IdParam"), "SYSTEM", $ClassMethod(tClass, "IdArgument"), $ClassMethod(tClass, "SettableFields"), tClass)
    If $IsObject($Get(tResult)) Set pProposal = tResult
    If $IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")) Set pProblem = tFault.%Get("detail").%Get("problem")
    If $IsObject($Get(tFault)) && (pProblem = "") Set pProblem = tFault.%Get("code")
    If '$IsObject(pProposal) Quit $$$ERROR($$$GeneralError, "the mint answered no proposal: " _ pHttp _ " " _ pProblem)
    Quit $$$OK
}

/// <p>Confirm <var>pProposal</var> through <parameter>CONFIRM</parameter>, whose port is the seam, as
/// this process's user, answering <code>http code</code>.</p>
ClassMethod Confirm(pProposal As %DynamicObject, Output pResult As %DynamicObject) As %String
{
    Set pResult = ""
    If '$IsObject(pProposal) Quit "no proposal"
    Set tSC = $ClassMethod(..#CONFIRM, "Confirm", pProposal.%Get("proposalId"), "", $Username, .pResult, .tHttp, .tCode, .tDetail)
    If $$$ISOK(tSC) && ($Get(tCode) = "") Quit "200 "
    Quit +$Get(tHttp) _ " " _ $Get(tCode)
}

/// <p>The consequence code the stored proposal <var>pProposal</var> carries, or
/// <code>""</code>.</p>
ClassMethod Consequence(pProposal) As %String
{
    If '$IsObject(pProposal) Quit ""
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(pProposal.%Get("proposalId"), .tFound, .tValues)
    If $$$ISERR(tSC) || '$Get(tFound) Quit ""
    Quit $Get(tValues("consequence"))
}

/// <p>A proposal's rows as <code>field before after</code>, one row expected.</p>
ClassMethod Rows(pProposal As %DynamicObject) As %String
{
    Set tRows = pProposal.%Get("changed")
    If '$IsObject(tRows) || (tRows.%Size() '= 1) Quit $Select($IsObject(tRows): tRows.%ToJSON(), 1: "")
    Quit tRows.%Get(0).field _ " " _ tRows.%Get(0).before _ " " _ tRows.%Get(0).after
}

/// <p>A proposal's row fields, sorted, joined by commas.</p>
ClassMethod Fields(pProposal As %DynamicObject) As %String
{
    Kill tSorted
    Set tRows = pProposal.%Get("changed")
    If '$IsObject(tRows) Quit ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $IsObject(tRow) Set tSorted(tRow.%Get("field")) = ""
    }
    Set tOut = ""
    Set tName = ""
    For {
        Set tName = $Order(tSorted(tName))
        If tName = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tName
    }
    Quit tOut
}

/// <p>The top-level keys of the JSON object <var>pJson</var>, sorted, joined by commas.</p>
ClassMethod Keys(pJson As %String) As %String
{
    Kill tSorted
    Try {
        Set tIterator = ##class(%DynamicObject).%FromJSON(pJson).%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Set tSorted(tKey) = ""
        }
    } Catch {
        Quit
    }
    Set tOut = ""
    Set tName = ""
    For {
        Set tName = $Order(tSorted(tName))
        If tName = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tName
    }
    Quit tOut
}

/// <p>Member <var>pName</var> of the JSON object <var>pJson</var>, or <code>""</code>.</p>
ClassMethod Member(pJson As %String, pName As %String) As %String
{
    Set tValue = ""
    Try {
        Set tValue = ##class(%DynamicObject).%FromJSON(pJson).%Get(pName)
    } Catch {
        Set tValue = ""
    }
    Quit tValue
}

/// <p>The verdict a read-back <var>pReadBack</var> carries, or <code>""</code>.</p>
ClassMethod Verdict(pReadBack) As %String
{
    If '$IsObject(pReadBack) Quit ""
    Quit pReadBack.%Get("verdict")
}

}
