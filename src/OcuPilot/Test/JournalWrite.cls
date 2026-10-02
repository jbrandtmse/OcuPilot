/// <p>Pins Story 18.5's journal writes against the instance's own journal (AD-6, AD-26, AD-51, AD-53,
/// AD-58), each on both callers -- the Journals screen route as the test account, and the agent's
/// proposal and confirmation: the file switch, a switch made since the mint refusing the confirm, the
/// one-directory refusal of a directory switch, a directory switch to a seeded alternate and back, a
/// switch the vendor answers without moving refused as unmoved, and a clean integrity check at both
/// levels; and their read-backs.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s test account, journaling on in a stock configuration (one
/// journal directory), a caller holding <code>%All</code>, and both
/// <parameter>ARMINGVARIABLE</parameter> and <parameter>PRINCIPALSVARIABLE</parameter> reading
/// <code>1</code>: it switches the instance's journal file and directory, seeds a probe alternate
/// directory and a probe principal (<class>OcuPilot.Test.JournalProbe</class>), and restores the
/// journal settings it found after every test. The journal files its switches create are kept.</p>
Class OcuPilot.Test.JournalWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class's journal switches, set by
/// <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_JOURNAL";

/// <p>The environment variable that arms its probe principal.</p>
Parameter PRINCIPALSVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.JournalList";

Parameter SWITCHFILE = "OcuPilot.Screen.Tool.JournalSwitchFile";

Parameter SWITCHDIRECTORY = "OcuPilot.Screen.Tool.JournalSwitchDirectory";

Parameter INTEGRITY = "OcuPilot.Screen.Tool.JournalIntegrityCheck";

Parameter PROBE = "OcuPilot.Test.JournalProbe";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The probe principal holding Journals' pairs and the system database's write, without
/// <code>%Admin_Manage:USE</code>.</p>
Parameter UNMOVEDUSER = "OCUPROBE185W";

Parameter UNMOVEDROLE = "OCUPROBE185WR";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.JournalWrite switches this instance's journal file and directory and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    If $System.Util.GetEnviron(..#PRINCIPALSVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.JournalWrite creates a probe user and role on this instance and runs on a throwaway container only. " _ ..#PRINCIPALSVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
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
    Quit ..Restore()
}

/// <p>Whatever the test did, the journal settings read as found, journaling writes in the primary
/// directory found, the probe principal is gone, and the proposals it minted are removed.</p>
Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tSC = ..Restore()
    Do $$$AssertStatusOK(tSC, "the journal settings are restored: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "JournalSettings").%ToJSON(), ..SavedSettings, "Config.Journal reads as found")
    Set tSaved = ##class(%DynamicObject).%FromJSON(..SavedSettings)
    Do $$$AssertEquals($ZConvert($ClassMethod(..#PROBE, "CurrentDirectory"), "L"), $ZConvert(##class(%File).NormalizeDirectory(tSaved.%Get("CurrentDirectory")), "L"), "journaling writes in the primary directory found")
    Set tRemoveSC = $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
    Do $$$AssertStatusOK(tRemoveSC, "the probe principal is removed")
    Set tRemoveSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tRemoveSC, "the probe proposals and turns are removed")
    Quit tSC
}

/// <p>The journal settings found, put back (<class>OcuPilot.Test.JournalProbe</class>).</p>
Method Restore() As %Status
{
    If ..SavedSettings = "" Quit $$$OK
    Quit $ClassMethod(..#PROBE, "RestoreJournal", ##class(%DynamicObject).%FromJSON(..SavedSettings))
}

/// <p>AC3: the screen's Switch file and the agent's confirmed proposal each send
/// <code>SWITCHFILE</code> with no body: the list's newest file changes, in the same directory, the
/// answer publishes an update for <code>journal-file/instance/current</code> and reads back
/// <code>nothingSent</code>; the proposal's one row names the file it closes; another id is
/// refused, on the screen and at the agent's mint.</p>
/// <p>Mutation (Rule 19): make <parameter>OcuPilot.Screen.Tool.JournalSwitchFile.WRITETYPE</parameter>
/// <code>SWITCHDIR</code> -&gt; the one-directory instance refuses it and every leg here goes
/// red.</p>
Method TestTheFileIsSwitchedOnBothCallers()
{
    Set tBefore = $ClassMethod(..#PROBE, "Newest")
    Set tSC = ..Act("switchfile", "current", "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the screen's switch answers 200: " _ ..Shown(tBody))
    Set tEvent = $Select($IsObject(tBody) && $IsObject(tBody.%Get("target")): tBody.%Get("action") _ " " _ tBody.%Get("target").%ToJSON(), 1: ..Shown(tBody))
    Do $$$AssertEquals(tEvent, "updated {""type"":""journal-file"",""scope"":""instance"",""id"":""current""}", "publishing the update event")
    Do $$$AssertEquals(..Verdict(tBody), "nothingSent", "read back as nothing sent (AD-58)")
    Set tAfter = $ClassMethod(..#PROBE, "Newest")
    Do $$$AssertTrue((tAfter '= "") && (tAfter '= tBefore), "the list's newest file changed: " _ tBefore _ " -> " _ tAfter)
    Do $$$AssertEquals(##class(%File).GetDirectory(tAfter), ##class(%File).GetDirectory(tBefore), "in the same directory")
    Do $$$AssertEquals(tAfter, ##class(%SYS.Journal.System).GetCurrentFileName(), "and it is the file journaling writes now")

    Set tSC = ..Act("switchfile", tAfter, "", .tStatus, .tBody)
    Do $$$AssertTrue((tStatus = 400) && (..Code(tBody) = "TOOL.ARGUMENTS") && (..Problem(tBody) [ "'current'"), "another id is refused: " _ ..Shown(tBody))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Newest"), tAfter, "and nothing is switched")

    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "a turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Mint(..#SWITCHFILE, tTurn, tAfter, "", .tRefused, .tHttp, .tFault)
    Do $$$AssertTrue($$$ISERR(tSC) && (+$Get(tHttp) = 400) && (..Code($Get(tFault)) = "TOOL.ARGUMENTS") && (..Problem($Get(tFault)) [ "'current'"), "the agent's switch naming another id is refused: " _ ..Shown($Get(tFault)))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Newest"), tAfter, "and nothing is switched")
    Set tSC = ..Mint(..#SWITCHFILE, tTurn, "current", "", .tProposal)
    Do $$$AssertStatusOK(tSC, "the agent's switch mints: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tProposal.%Get("target").%ToJSON(), "{""type"":""journal-file"",""scope"":""instance"",""id"":""current""}", "against the current file")
    Do $$$AssertEquals(..Rows(tProposal), "CurrentFile " _ tAfter _ " ", "one row, naming the file it closes")
    Set tStoredSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(tProposal.%Get("proposalId"), .tFound, .tValues)
    Do $$$AssertEquals($Get(tValues("consequence")), "JOURNAL.SWITCHFILE", "carrying the switch's consequence")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the confirm switches: " _ $Get(tCode))
    Set tAgain = $ClassMethod(..#PROBE, "Newest")
    Do $$$AssertTrue((tAgain '= "") && (tAgain '= tAfter), "the newest file changed again: " _ tAgain)
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("auditMarked") _ " " _ tResult.%Get("action") _ " " _ ..Verdict(tResult), 1: ""), "1 updated nothingSent", "the write is marked, publishes an update and reads back nothing sent")
}

/// <p>AC3, AD-6: a proposal minted before another switch is refused at Confirm because its
/// fingerprint moved, and nothing is switched by it.</p>
/// <p>Mutation (Rule 19): make <class>OcuPilot.Port.JournalPort</class>'s <code>STATE</code> answer a
/// constant <code>CurrentFile</code> -&gt; the confirm switches and this goes red.</p>
Method TestASwitchSinceTheMintRefusesTheConfirm()
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "a turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Mint(..#SWITCHFILE, tTurn, "current", "", .tProposal)
    Do $$$AssertStatusOK(tSC, "the switch mints")
    If $$$ISERR(tSC) Quit
    Kill tQuery
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Journal.Settings", "SWITCHFILE", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the file is switched out of band")
    Set tMoved = $ClassMethod(..#PROBE, "Newest")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals($System.Status.IsOK(tSC) _ " " _ $Get(tHttp) _ " " _ $Get(tCode), "0 409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm is refused because the target moved")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Newest"), tMoved, "and nothing is switched by it")
}

/// <p>AC4: with one configured directory, the screen's Switch directory and the agent's mint are each
/// refused 409 <code>JOURNAL.SWITCHDIR.NOOTHER</code> before anything is sent, and the port's own
/// <code>SWITCHDIR</code> maps the vendor's 409 to the same code; nothing switches.</p>
/// <p>Mutation (Rule 19): drop <class>OcuPilot.Port.JournalPort</class>'s mapping of the vendor's
/// 409 -&gt; the port leg answers <code>PORT.CONFLICT</code> and goes red.</p>
Method TestOneDirectoryIsRefusedOnBothCallers()
{
    Set tSettings = $ClassMethod(..#PROBE, "JournalSettings")
    Do $$$AssertEquals($ZConvert(##class(%File).NormalizeDirectory(tSettings.%Get("AlternateDirectory")), "L"), $ZConvert(##class(%File).NormalizeDirectory(tSettings.%Get("CurrentDirectory")), "L"), "the instance has one journal directory (a stock configuration)")
    Set tBefore = $ClassMethod(..#PROBE, "Newest")
    Set tSC = ..Act("switchdirectory", "current", "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus _ " " _ ..Code(tBody), "409 JOURNAL.SWITCHDIR.NOOTHER", "the screen's switch is refused: " _ ..Shown(tBody))
    Do $$$AssertEquals($Select($IsObject(tBody): tBody.%Get("reason"), 1: ""), ##class(OcuPilot.Api.JournalError).#REASONSWITCHDIRNOOTHER, "with the published sentence")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    If $$$ISOK(tSC) {
        Set tSC = ..Mint(..#SWITCHDIRECTORY, tTurn, "current", "", .tProposal, .tHttp, .tFault)
        Do $$$AssertEquals($System.Status.IsOK(tSC) _ " " _ $Get(tHttp) _ " " _ ..Code($Get(tFault)), "0 409 JOURNAL.SWITCHDIR.NOOTHER", "the agent's mint is refused on the same code")
    }
    Kill tQuery
    Set tSC = ##class(OcuPilot.Port.JournalPort).Invoke("Journal.Settings", "SWITCHDIR", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Get(tHttp) _ " " _ ..Code($Get(tFault)), "409 JOURNAL.SWITCHDIR.NOOTHER", "the port maps the vendor's own 409")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Newest"), tBefore, "and nothing switched")
}

/// <p>AC4: with a probe alternate configured, the screen's Switch directory moves journaling there,
/// and the agent's confirmed proposal, whose one row names the other directory, moves it back.</p>
/// <p>Mutation (Rule 19): make <class>OcuPilot.Port.JournalPort</class>'s other-directory read answer
/// the alternate whatever journaling writes in -&gt; the proposal's row names the alternate and this
/// goes red.</p>
Method TestTheDirectoryIsSwitchedThereAndBack()
{
    Set tPrimary = $ClassMethod(..#PROBE, "CurrentDirectory")
    Set tSC = $ClassMethod(..#PROBE, "SeedAlternate")
    Do $$$AssertStatusOK(tSC, "the probe alternate is configured: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Set tAlternate = $ClassMethod(..#PROBE, "AlternateDirectory")
    Do $$$AssertEquals($ZConvert($ClassMethod(..#PROBE, "CurrentDirectory"), "L"), $ZConvert(tPrimary, "L"), "journaling still writes in the primary")
    Set tSC = ..Act("switchdirectory", "current", "", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the screen's switch answers 200: " _ ..Shown(tBody))
    Do $$$AssertEquals(..Verdict(tBody), "nothingSent", "read back as nothing sent")
    Do $$$AssertEquals($ZConvert($ClassMethod(..#PROBE, "CurrentDirectory"), "L"), $ZConvert(tAlternate, "L"), "journaling writes in the alternate")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "a turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Mint(..#SWITCHDIRECTORY, tTurn, "current", "", .tProposal)
    Do $$$AssertStatusOK(tSC, "the agent's switch mints: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals($ZConvert(..Rows(tProposal), "L"), $ZConvert("CurrentDirectory " _ tAlternate _ " " _ tPrimary, "L"), "one row, naming the other directory")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the confirm switches back: " _ $Get(tCode))
    Do $$$AssertEquals($ZConvert($ClassMethod(..#PROBE, "CurrentDirectory"), "L"), $ZConvert(tPrimary, "L"), "journaling writes in the primary again")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("auditMarked") _ " " _ tResult.%Get("action") _ " " _ ..Verdict(tResult), 1: ""), "1 updated nothingSent", "the write is marked, publishes an update and reads back nothing sent")
}

/// <p>AC4: a directory switch the vendor answers 200 while journaling stays in its directory -- the
/// port called by a principal holding Journals' pairs and the system database's write, without
/// <code>%Admin_Manage:USE</code>, with an alternate configured -- is refused 409
/// <code>JOURNAL.SWITCHDIR.UNMOVED</code> naming that directory, never read as a switch.</p>
/// <p>Mutation (Rule 19): drop the unmoved check from <class>OcuPilot.Port.JournalPort</class> -&gt;
/// the call answers 200 and this goes red.</p>
Method TestASwitchThatStaysIsRefusedUnmoved()
{
    Set tPrimary = $ClassMethod(..#PROBE, "CurrentDirectory")
    Set tSC = $ClassMethod(..#PROBE, "SeedAlternate")
    Do $$$AssertStatusOK(tSC, "the probe alternate is configured")
    If $$$ISERR(tSC) Quit
    Set tSC = $ClassMethod(..#PROBE, "SeedPrincipal", ..#UNMOVEDUSER, ..#UNMOVEDROLE, "%Admin_Operate:U,%DB_IRISSYS:RW")
    Do $$$AssertStatusOK(tSC, "the probe principal is seeded")
    If $$$ISERR(tSC) Quit
    Set tPlan = [{"endpoint": "Journal.Settings", "type": "SWITCHDIR", "port": "OcuPilot.Port.JournalPort"}]
    Set tOut = $ClassMethod(..#PROBE, "RunAs", ..#UNMOVEDUSER, tPlan)
    Do $$$AssertEquals(tOut.%Get("loggedIn"), 1, "the probe principal signs in: " _ tOut.%ToJSON())
    Set tStep = $Select($IsObject(tOut.%Get("steps")): tOut.%Get("steps").%Get(0), 1: "")
    Do $$$AssertEquals($Select($IsObject(tStep): tStep.%Get("http") _ " " _ ..Code(tStep.%Get("fault")), 1: ""), "409 JOURNAL.SWITCHDIR.UNMOVED", "the switch that stayed is refused: " _ ..Shown(tStep))
    Do $$$AssertEquals($Select($IsObject(tStep) && $IsObject(tStep.%Get("fault")): tStep.%Get("fault").%Get("reason"), 1: ""), ##class(OcuPilot.Api.JournalError).Unmoved(tPrimary), "naming the directory journaling still writes in")
    Do $$$AssertEquals($ZConvert($ClassMethod(..#PROBE, "CurrentDirectory"), "L"), $ZConvert(tPrimary, "L"), "journaling writes in the primary")
}

/// <p>AC5: a clean integrity check of a closed file, headers alone and every record, answers each
/// caller the finished check's output -- no lines, no errors -- and the vendor's task row is gone;
/// the agent's proposal carries the flag as its one row.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.JournalPort.IntegrityBody</method> send
/// <code>CheckDetails</code> false whatever the query says -&gt; the vendor still answers, so this
/// mutation is pinned by <method>TestTheCheckSendsTheFlagItWasGiven</method> instead.</p>
Method TestACleanCheckAnswersBothCallersAtBothLevels()
{
    Set tListed = $ClassMethod(..#PROBE, "Listed")
    If '$IsObject(tListed) || (tListed.%Size() < 2) {
        Do $$$AssertTrue(0, "the instance lists a closed journal file")
        Quit
    }
    Set tFile = tListed.%Get(1).%Get("Name")
    Set tRows = ..TaskRows()
    For tFlag = "false", "true" {
        Set tSC = ..Act("integrity", tFile, "", .tStatus, .tBody, {"CheckDetails": (tFlag)})
        Do $$$AssertEquals(tStatus, 200, "the screen's check (" _ tFlag _ ") answers 200: " _ ..Shown(tBody))
        Do $$$AssertEquals($Select($IsObject(tBody) && $IsObject(tBody.%Get("output")): tBody.%Get("output").%ToJSON(), 1: ""), "{""lines"":[],""errors"":false}", "with no lines and no errors")
        Do $$$AssertTrue('$IsObject(tBody) || (tBody.%Get("continues") '= 1), "and finished within the bound")
    }
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurn)
    Do $$$AssertStatusOK(tSC, "a turn is seeded")
    If $$$ISERR(tSC) Quit
    Set tSC = ..Mint(..#INTEGRITY, tTurn, tFile, {"CheckDetails": true}, .tProposal)
    Do $$$AssertStatusOK(tSC, "the agent's check mints: " _ $System.Status.GetErrorText(tSC))
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tProposal.%Get("target").%Get("id"), tFile, "against the file as the list spells it")
    Do $$$AssertEquals(..Rows(tProposal), "CheckDetails  true", "one row, the flag")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Confirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertStatusOK(tSC, "the confirm checks: " _ $Get(tCode))
    Do $$$AssertEquals($Select($IsObject($Get(tResult)) && $IsObject(tResult.%Get("output")): tResult.%Get("output").%ToJSON(), 1: ""), "{""lines"":[],""errors"":false}", "and answers the card no lines and no errors")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("auditMarked") _ " " _ ..Verdict(tResult), 1: ""), "1 nothingSent", "the write is marked and reads back nothing sent")
    Do $$$AssertEquals(..TaskRows(), tRows, "and no vendor task row is left behind")
}

/// <p>The check sends the flag it was given, through <class>OcuPilot.Port.JournalPort</class>'s own
/// body, and refuses a caller body.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.JournalPort.IntegrityBody</method> answer
/// <code>CheckDetails</code> false always -&gt; the true leg goes red.</p>
Method TestTheCheckSendsTheFlagItWasGiven()
{
    For tGiven = "true", "1", "false", "", "yes" {
        Kill tQuery
        Set tQuery("CheckDetails") = tGiven
        Do $$$AssertEquals(##class(OcuPilot.Port.JournalPort).IntegrityBody(.tQuery).%ToJSON(), "{""CheckDetails"":" _ $Select((tGiven = "true") || (tGiven = "1"): "true", 1: "false") _ "}", "'" _ tGiven _ "' sends its flag")
    }
    Set tListed = $ClassMethod(..#PROBE, "Listed")
    Kill tQuery
    Set tQuery("file") = tListed.%Get(1).%Get("Name")
    Set tSC = ##class(OcuPilot.Port.JournalPort).Invoke("Journal.File", "INTEGRITYCHECK", .tQuery, {"CheckDetails": true}, .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($System.Status.IsOK(tSC) _ " " _ $Get(tHttp) _ " " _ ..Code($Get(tFault)), "0 500 INTERNAL", "a caller body is refused")
}

/// <p>Mint <var>pToolClass</var>'s proposal for id <var>pId</var> with the extra arguments
/// <var>pArgs</var>, as the caller, in turn <var>pTurn</var>, through the tool's own mint.</p>
Method Mint(pToolClass As %String, pTurn As %String, pId As %String, pArgs As %DynamicObject = "", Output pProposal As %DynamicObject, Output pHttp As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tArgs = $Select($IsObject(pArgs): pArgs, 1: {})
    Do tArgs.%Set($ClassMethod(pToolClass, "IdArgument"), pId, "string")
    Quit $ClassMethod($ClassMethod(pToolClass, "MintClass"), "Mint", ..#SCREEN, $Parameter(pToolClass, "TOOLNAME"), $Username, "", pTurn, tArgs, ..#LIMITS, .pProposal, .pHttp, .pFault, $ClassMethod(pToolClass, "Endpoint"), $ClassMethod(pToolClass, "IdParam"), pId, $ClassMethod(pToolClass, "IdArgument"), $ClassMethod(pToolClass, "SettableFields"), pToolClass)
}

/// <p>A proposal's rows as <code>field before after</code>, one row expected.</p>
ClassMethod Rows(pProposal As %DynamicObject) As %String
{
    Set tRows = pProposal.%Get("changed")
    If '$IsObject(tRows) || (tRows.%Size() '= 1) Quit ..Shown(tRows)
    Quit tRows.%Get(0).field _ " " _ tRows.%Get(0).before _ " " _ tRows.%Get(0).after
}

/// <p>One action over Journals' route as <var>pUser</var>, or as the test account when it is empty,
/// with the declared <var>pValues</var>, answering the HTTP status and the parsed envelope.</p>
ClassMethod Act(pAction As %String, pId As %String, pUser As %String, Output pStatus As %Integer, Output pBody, pValues As %DynamicObject = "", pPassword As %String = "") As %Status
{
    Set pBody = ""
    Set tPassword = pPassword
    If pUser = "" {
        Set pUser = ##class(OcuPilot.Test.Http).GetTestUsername()
        Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    }
    Set tRequest = {}
    Do tRequest.%Set("action", pAction, "string")
    Do tRequest.%Set("id", pId, "string")
    If $IsObject(pValues) Do tRequest.%Set("values", pValues)
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/screens/osmgmt.journals/action", pUser, tPassword, .pStatus, .tRaw, .tHeaders, tRequest.%ToJSON(), "application/json")
    Try { Set pBody = ##class(%DynamicObject).%FromJSON(tRaw) } Catch { Set pBody = $Get(tRaw) }
    Quit tSC
}

/// <p>How many rows the admin API's async task table holds.</p>
ClassMethod TaskRows() As %Integer
{
    Set tCount = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set tTable = ##class(%Dictionary.CompiledClass).%OpenId($Parameter("OcuPilot.Port.AdminPort", "ASYNCTASKCLASS")).SqlQualifiedNameQ
        Set $NAMESPACE = "%SYS"
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) AS N FROM " _ tTable)
        If tResult.%Next() Set tCount = tResult.%Get("N")
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tCount
}

/// <p>The read-back verdict an answer <var>pBody</var> carries, or <code>""</code>.</p>
ClassMethod Verdict(pBody) As %String
{
    If '$IsObject(pBody) || '$IsObject(pBody.%Get("readBack")) Quit ""
    Quit pBody.%Get("readBack").%Get("verdict")
}

/// <p>The code an envelope <var>pBody</var> carries, or <code>""</code>.</p>
ClassMethod Code(pBody) As %String
{
    If '$IsObject(pBody) Quit ""
    Quit pBody.%Get("code")
}

/// <p>The problem sentence an envelope <var>pBody</var>'s detail carries, or <code>""</code>.</p>
ClassMethod Problem(pBody) As %String
{
    If '$IsObject(pBody) || '$IsObject(pBody.%Get("detail")) Quit ""
    Quit pBody.%Get("detail").%Get("problem")
}

/// <p><var>pBody</var> as text for an assertion message.</p>
ClassMethod Shown(pBody) As %String
{
    Quit $Select($IsObject(pBody): pBody.%ToJSON(), 1: $Get(pBody))
}

}
