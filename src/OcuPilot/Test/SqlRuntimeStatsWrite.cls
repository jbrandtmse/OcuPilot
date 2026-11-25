/// <p>Pins Story 21.26's two writes on both permitted callers (AC2, AC3; AD-4, AD-6, AD-10, AD-51, AD-53, AD-58): each row of the instance-wide runtime
/// statistics collection set by the settings screen's Set value and by the agent's confirmed proposal, the defaults a level of 2 or 3 takes while no stop
/// is held, a stop moved without moving the level, collection turned off, the refusals before any call (a stop set while collection is off, a value
/// outside its row's range, the read-only row); and the namespace's runtime statistics purged by the list's Purge statistics and by the agent's confirmed
/// proposal, another namespace's rows staying, a second purge refused before any call, a proposal whose statistics changed after it was minted closed
/// target-changed, and the instance's own refusal answered 409 <code>SQL.RUNTIMESTATS.VENDOR</code> with its message in <code>detail</code> alone.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, which holds
/// <code>%Development:USE</code> and WRITE on <code>USER</code>'s and <code>HSCUSTOM</code>'s routines databases, a <code>USER</code> namespace, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the collection setting is instance-wide and the purge removes every runtime statistics row
/// of <code>USER</code>, which a test cannot confine to its own objects. It runs on a throwaway container only. It reads the collection flag before each test
/// and puts it back in its own cleanup, reading it back, and it makes and removes <class>OcuPilot.Test.SqlTuningProbe</class>'s objects.</p>
Class OcuPilot.Test.SqlRuntimeStatsWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_CONFIG_SETTINGS";

Parameter PROBE = "OcuPilot.Test.SqlTuningProbe";

Parameter WRITE = "OcuPilot.Test.SqlStatementWrite";

Parameter ACTION = "OcuPilot.Test.EcpActionFixture";

Parameter VERDICT = "OcuPilot.Test.EcpDataServerWrite";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter CONFIGPORT = "OcuPilot.Port.ConfigPort";

Parameter CONFIGSEAM = "OcuPilot.Test.ConfigGateSeam";

Parameter FIXTURE = "OcuPilot.Test.SqlTuningPortFixture";

Parameter SEAM = "OcuPilot.Test.SqlTuningGateSeam";

Parameter NAMESPACE = "USER";

/// <p>The second namespace whose probe statistics a purge of <parameter>NAMESPACE</parameter> leaves.</p>
Parameter OTHERNAMESPACE = "HSCUSTOM";

Parameter SETTINGSCREEN = "explorer.sqlruntimestatssettings";

Parameter LISTSCREEN = "explorer.sqlruntimestats";

Parameter SETTINGTOOL = "OcuPilot.Screen.Tool.ExplorerSqlRuntimeStatsSettingSet";

Parameter PURGETOOL = "OcuPilot.Screen.Tool.ExplorerSqlRuntimeStatsPurge";

/// <p>The governance policy as it stood before each test.</p>
Property PreparedPolicy [ MultiDimensional ];

Property PreparedPolicyTaken As %Boolean [ InitialExpression = 0 ];

/// <p>The collection flag as the test found it, and its stop as <code>M:minutes:level</code> when one was held.</p>
Property PreparedFlag As %String;

Property PreparedStop As %String;

Property PreparedFlagTaken As %Boolean [ InitialExpression = 0 ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPolicyTaken = 0
    Set ..PreparedFlagTaken = 0
    Set ..PreparedFlag = ""
    Set ..PreparedStop = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlRuntimeStatsWrite changes the instance's runtime statistics collection and purges the runtime statistics of " _ ..#NAMESPACE _ ", and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#CONFIGSEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Reset")
    Kill ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set ..PreparedPolicyTaken = 1
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Clear()
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedFlag = ..Flag(.tInfo)
    Set ..PreparedStop = $Select($Piece(..PreparedFlag, ":", 1) '< 2 && ($Get(tInfo("terminate", "mins")) '= ""): "M:" _ tInfo("terminate", "mins") _ ":" _ +$Get(tInfo("terminate", "resetActionFlag")), 1: "")
    Set ..PreparedFlagTaken = 1
    Set tOff = ##class(%SYS.PTools.StatsSQL).SetSQLStats(0, 1, "", "")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    If ..PreparedFlagTaken {
        Set tLevel = $Piece(..PreparedFlag, ":", 1)
        Set tPut = ##class(%SYS.PTools.StatsSQL).SetSQLStats(tLevel, 1, "", $Select(tLevel < 2: "", ..PreparedStop '= "": ..PreparedStop, 1: 0))
        Set tNow = ..Flag(.tInfo)
        Do $$$AssertEquals($Piece(tNow, ":", 1) _ ":" _ $Piece(tNow, ":", 2), $Piece(..PreparedFlag, ":", 1) _ ":" _ $Piece(..PreparedFlag, ":", 2), "the collection level read before the test is put back and read again")
        If tLevel < 2 Do $$$AssertEquals(tNow, ..PreparedFlag, "with no stop held, as before")
    }
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#NAMESPACE), "every probe object of " _ ..#NAMESPACE _ " is removed")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#OTHERNAMESPACE), "every probe object of " _ ..#OTHERNAMESPACE _ " is removed")
    Kill ^||OcuPilotDatabaseWritePort
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#CONFIGSEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    If '..PreparedPolicyTaken Quit $$$OK
    Kill tRows
    Merge tRows = ..PreparedPolicy
    Quit ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
}

/// <p>The collection flag as the instance reports it, its detail in <var>pInfo</var>.</p>
ClassMethod Flag(Output pInfo) As %String
{
    Kill pInfo
    Quit ##class(%SYS.PTools.StatsSQL).GetSQLStatsFlag(0, 0, .pInfo)
}

/// <p>The state the instance holds as <code>level|minutes|level after the stop</code>, the last two empty while no stop is held.</p>
ClassMethod State() As %String
{
    Set tFlag = ..Flag(.tInfo)
    Set tLevel = $Piece(tFlag, ":", 1)
    Quit tLevel _ "|" _ $Select(tLevel < 2: "|", 1: $Get(tInfo("terminate", "mins")) _ "|" _ $Select($Get(tInfo("terminate", "mins")) = "": "", 1: +$Get(tInfo("terminate", "resetActionFlag"))))
}

/// <p>The value of the setting row <var>pName</var> through the shipped port.</p>
ClassMethod ValueOf(pName As %String) As %String
{
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = $ClassMethod(..#CONFIGPORT, "Invoke", "SQLStats", "GET", .tQuery, "", .tRow, .tHttp, .tFault)
    Quit $Select($IsObject($Get(tRow)): tRow.%Get("Value"), 1: "(" _ $Get(tHttp) _ ")")
}

/// <p>The seconds from now, in UTC, to the time <var>pIso</var>, an ISO-8601 UTC text, or <code>""</code> when it is not one.</p>
ClassMethod SecondsUntil(pIso As %String) As %Integer
{
    If '$Match(pIso, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$") Quit ""
    Set tStop = $ZDateTimeH($Translate($Extract(pIso, 1, 19), "T", " "), 3)
    Set tNow = $ZTimeStamp
    Quit ($Piece(tStop, ",", 1) - $Piece(tNow, ",", 1)) * 86400 + ($Piece(tStop, ",", 2) - $Piece(tNow, ",", 2))
}

/// <p>The screen action <code>set</code> on <var>pName</var> with <var>pValue</var>, through the action fixture: the answer's parsed envelope in
/// <var>pAnswer</var>, answering the HTTP status.</p>
ClassMethod Act(pName As %String, pValue As %String, Output pAnswer As %DynamicObject) As %Integer
{
    Set tBody = {"action": "set"}
    Do tBody.%Set("id", pName, "string")
    Set tValues = {}
    Do tValues.%Set("Value", pValue, "string")
    Do tBody.%Set("values", tValues)
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SETTINGSCREEN, tBody, .tJson, .tStatus)
    Set pAnswer = $ClassMethod(..#VERDICT, "Parsed", tJson)
    Quit tStatus
}

/// <p>The refusal code an answer carries, or <code>""</code>.</p>
ClassMethod Code(pAnswer As %DynamicObject) As %String
{
    Quit $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>Mint the setting tool for <var>pName</var> with <var>pValue</var> and confirm it: <code>refused: &lt;problem&gt;</code> when the mint refused, else
/// the confirm's <code>http code</code>. The confirm's answer is in <var>pResult</var>, the proposal in <var>pProposal</var>.</p>
ClassMethod Agent(pName As %String, pValue As %String, Output pResult As %DynamicObject, Output pProposal As %DynamicObject) As %String
{
    Set ^||OcuPilotDatabaseWritePort = ..#CONFIGPORT
    Set tArgs = {}
    Do tArgs.%Set("Name", pName, "string")
    Do tArgs.%Set("Value", pValue, "string")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#SETTINGTOOL, pName, tArgs, .pProposal, .tHttp, .tProblem)
    If '$IsObject($Get(pProposal)) Quit "refused: " _ $Get(tProblem)
    Quit $ClassMethod(..#AGENT, "Confirm", pProposal, .pResult)
}

/// <p>AC2. The screen's Set value turns collection on to all modules with no stop held, and the instance holds a level of 3 with a stop of 50 minutes and
/// the level after it Off, the stop falling about 50 minutes ahead and read back through the list's own row; the stop moved to 120 minutes leaves the
/// level and moves the time; the level after the stop set to Off with collection code reads back; collection turned off reads level 0 and empty stop rows.
/// Each answer reads back <code>matches</code>.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.ConfigPort.SqlStatsTarget</code> builds an empty stop for a level of 2 or 3 -> the defaults assertion goes red;
/// <code>OcuPilot.Port.ConfigPort.CollectRoster</code> answers a level of 3 whatever the flag reads -> the first assertion goes red.</p>
Method TestTheScreenSetsTheLevelTheStopAndTheLevelAfterIt()
{
    Do $$$AssertEquals(..ValueOf("CollectionLevel") _ "|" _ ..ValueOf("StopAfterMinutes") _ "|" _ ..ValueOf("LevelAfterStop") _ "|" _ ..ValueOf("StopsAt"), "Off|||", "the settings port reads collection Off with every stop row empty before the first set, through its own rows")
    Set tStatus = ..Act("CollectionLevel", "On for all modules", .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer) _ "|" _ ..State(), "200|matches|3|50|0", "turning collection on takes the classic page's defaults, a 50 minute stop and Off after it: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Set tUntil = ..SecondsUntil(..ValueOf("StopsAt"))
    Do $$$AssertTrue((tUntil '= "") && (tUntil > 2850) && (tUntil < 3150), "the stop falls about 50 minutes ahead, to the minute the vendor keeps, as an ISO-8601 UTC time: " _ ..ValueOf("StopsAt") _ " (" _ tUntil _ " s)")
    Do $$$AssertEquals(..ValueOf("CollectionLevel") _ "|" _ ..ValueOf("StopAfterMinutes") _ "|" _ ..ValueOf("LevelAfterStop"), "On for all modules|50|Off", "the list's rows read the same")
    Set tStatus = ..Act("StopAfterMinutes", 120, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer) _ "|" _ ..State(), "200|matches|3|120|0", "the stop set to 120 leaves the level and the level after the stop")
    Set tUntil = ..SecondsUntil(..ValueOf("StopsAt"))
    Do $$$AssertTrue((tUntil '= "") && (tUntil > 7050) && (tUntil < 7350), "and the stop's time moves to about 120 minutes ahead (" _ tUntil _ " s)")
    Set tStatus = ..Act("LevelAfterStop", "Off with collection code", .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer) _ "|" _ ..State(), "200|matches|3|120|1", "the level after the stop set to Off with collection code reads back")
    Set tStatus = ..Act("CollectionLevel", "On for open and close", .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..State(), "200|2|120|1", "the level changed to 2 keeps the stop the instance holds")
    Set tStatus = ..Act("CollectionLevel", "Off", .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..State() _ "|" _ ..ValueOf("StopAfterMinutes") _ "|" _ ..ValueOf("LevelAfterStop") _ "|" _ ..ValueOf("StopsAt"), "200|0|||||", "turning collection off reads level 0 with every stop row empty")
}

/// <p>AC2. The agent's confirmed proposal sets the level and then the stop, the same call as the screen's: a level of 2 takes the default stop, a stop of 30
/// minutes follows, and its card states the consequence for every row.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Screen.Tool.ExplorerSqlRuntimeStatsSettingSet.Consequence</code> answers <code>""</code> -> the consequence
/// assertion goes red.</p>
Method TestTheAgentSetsTheSameRowsThroughAProposal()
{
    Set tOutcome = ..Agent("CollectionLevel", "On for open and close", .tResult, .tProposal)
    Do $$$AssertEquals(tOutcome _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult) _ "|" _ ..State(), "200 |matches|2|50|0", "the agent's confirmed level takes the defaults too: " _ tOutcome)
    Do $$$AssertEquals(##class(OcuPilot.Test.EcpSettingsWrite).Consequence(tProposal), "SQL.RUNTIMESTATS.SET", "and its card states the consequence")
    Set tOutcome = ..Agent("StopAfterMinutes", 30, .tResult, .tProposal)
    Do $$$AssertEquals(tOutcome _ "|" _ ..State(), "200 |2|30|0", "the agent's confirmed stop of 30 minutes keeps the level")
    Set tOutcome = ..Agent("LevelAfterStop", "Off with collection code", .tResult, .tProposal)
    Do $$$AssertEquals(tOutcome _ "|" _ ..State(), "200 |2|30|1", "and the level after the stop")
    Set tOutcome = ..Agent("CollectionLevel", "Off", .tResult, .tProposal)
    Do $$$AssertEquals(tOutcome _ "|" _ ..State(), "200 |0||", "the agent's confirmed Off reads level 0 with no stop")
}

/// <p>AC2. Each refusal is made before any call and changes nothing, on both callers: a stop row set while collection is off is
/// <code>CONFIG.SQLSTATS.NOSTOP</code>, a level outside the four names, minutes of 0, 100000, a fraction or text, and a level after the stop outside its two
/// names are <code>CONFIG.SETTING.VALUE</code>, and the read-only row is <code>CONFIG.SETTING.READONLY</code>. The instance's flag reads as before each.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Area.OsMgmt.ConfigSettingRules.StopRefused</code> answers 0 -> the stop rows' refusals go red and the stop is set at level 0.</p>
Method TestARefusedSetChangesNothingOnEitherCaller()
{
    Set tBefore = ..Flag()
    For tCase = $ListBuild("StopAfterMinutes", "10", "409|CONFIG.SQLSTATS.NOSTOP"), $ListBuild("LevelAfterStop", "Off", "409|CONFIG.SQLSTATS.NOSTOP"), $ListBuild("CollectionLevel", "On", "400|CONFIG.SETTING.VALUE"), $ListBuild("CollectionLevel", "1", "400|CONFIG.SETTING.VALUE"), $ListBuild("StopsAt", "2030-01-01T00:00:00Z", "409|CONFIG.SETTING.READONLY") {
        Set tStatus = ..Act($List(tCase, 1), $List(tCase, 2), .tAnswer)
        Do $$$AssertEquals(tStatus _ "|" _ ..Code(tAnswer), $List(tCase, 3), $List(tCase, 1) _ " " _ $List(tCase, 2) _ ": refused at the screen")
    }
    Do $$$AssertEquals(..Flag(), tBefore, "and the instance's flag reads as before")
    Set tOutcome = ..Agent("StopAfterMinutes", 10, .tResult, .tProposal)
    Do $$$AssertEquals(tOutcome, "refused: " _ ##class(OcuPilot.Api.ConfigError).#REASONSQLSTATSNOSTOP, "a stop set while collection is off is refused at the mint, with its sentence")
    Do $$$AssertEquals(..Agent("CollectionLevel", "On", .tResult, .tProposal), "refused: " _ ##class(OcuPilot.Api.ConfigError).#REASONSETTINGVALUE, "a level that is not one of the four names is refused at the mint")
    Set tStatus = ..Act("CollectionLevel", "On for all modules", .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..State(), "200|3|50|0", "collection is turned on so the stop rows' values can be judged")
    For tCase = $ListBuild("StopAfterMinutes", "0"), $ListBuild("StopAfterMinutes", "100000"), $ListBuild("StopAfterMinutes", "1.5"), $ListBuild("StopAfterMinutes", "abc"), $ListBuild("StopAfterMinutes", ""), $ListBuild("LevelAfterStop", "On for all modules") {
        Set tStatus = ..Act($List(tCase, 1), $List(tCase, 2), .tAnswer)
        Do $$$AssertEquals(tStatus _ "|" _ ..Code(tAnswer) _ "|" _ ..State(), "400|CONFIG.SETTING.VALUE|3|50|0", $List(tCase, 1) _ " " _ $List(tCase, 2) _ ": refused at the screen and nothing changed")
        Do $$$AssertEquals(..Agent($List(tCase, 1), $List(tCase, 2), .tResult, .tProposal), "refused: " _ ##class(OcuPilot.Api.ConfigError).#REASONSETTINGVALUE, $List(tCase, 1) _ " " _ $List(tCase, 2) _ ": refused at the mint")
    }
}

/// <p>AC2. The call the port builds, seen through the seam that records it and sends nothing: a level of 3 with no stop held sends <code>M:50:0</code>, a level
/// of 0 sends no stop, and the instance's own refusal of the call is answered as the settings' existing vendor refusal with the flag unchanged.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.ConfigPort.SqlStatsTarget</code> builds an empty stop for a level of 2 or 3 -> the recorded call assertion goes
/// red.</p>
Method TestThePortBuildsTheVendorsStopTextFromWholeNumbers()
{
    Set tSeam = ..#CONFIGSEAM
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Development", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "WRITE")
    Kill tQuery
    Set tQuery("name") = "CollectionLevel"
    Set tSC = $ClassMethod(tSeam, "Invoke", "SQLStats", "SET", .tQuery, {"Value": "On for all modules"}, .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(tSeam, "Modifies"), "200|SQLStats|3|M:50:0", "a level of 3 with no stop held sends a stop of 50 minutes and Off after it")
    Do $$$AssertEquals(..State(), "0||", "and the seam sent nothing to the instance")
    Do $ClassMethod(tSeam, "Reset")
    Set tQuery("name") = "CollectionLevel"
    Set tSC = $ClassMethod(tSeam, "Invoke", "SQLStats", "SET", .tQuery, {"Value": "Off with collection code"}, .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $ClassMethod(tSeam, "Modifies"), "200|SQLStats|1|", "a level of 1 sends no stop")
    Do $ClassMethod(tSeam, "Reset")
    Do $ClassMethod(tSeam, "VendorRefuses")
    Set tSC = $ClassMethod(tSeam, "Invoke", "SQLStats", "SET", .tQuery, {"Value": "On for open and close"}, .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "400|CONFIG.SETTING.VALUE", "the instance's refusal of the call is the settings' existing vendor refusal")
    Do $$$AssertEquals($ClassMethod(tSeam, "Faults") _ "|" _ ..State(), "CONFIG.SETTING.VALUE|error|0||", "logged without its message, and the flag is unchanged")
}

/// <p>The two namespaces' probe statements, each run once with statistics on in this process.</p>
Method MakeProbes()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Make", ..#NAMESPACE), "the probe objects are created in " _ ..#NAMESPACE)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Make", ..#OTHERNAMESPACE), "the probe objects are created in " _ ..#OTHERNAMESPACE)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RecordStats", ..#NAMESPACE), "the probe's statement is recorded in " _ ..#NAMESPACE)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RecordStats", ..#OTHERNAMESPACE), "and in " _ ..#OTHERNAMESPACE)
}

/// <p>AC3. The list's Purge statistics and the agent's confirmed proposal each remove every runtime statistics row of <code>USER</code> and leave the rows of
/// <code>HSCUSTOM</code>; a second purge of a namespace that holds none is refused with its sentence before any call, on both callers.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.StatementCall</code> calls <code>clearStatsSQLAllNS</code> -> the other namespace's rows are purged
/// too and the surviving-rows assertion goes red.</p>
Method TestThePurgeRemovesTheNamespacesRowsOnBothCallers()
{
    Do ..MakeProbes()
    Kill tSettings
    Set tSettings($Parameter(..#PURGETOOL, "TOOLNAME")) = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the purge, whose key ships disabled, is enabled through its stored setting")
    Set tOther = $ClassMethod(..#PROBE, "StatsRowCount", ..#OTHERNAMESPACE)
    Do $$$AssertTrue(($ClassMethod(..#PROBE, "StatsRowCount", ..#NAMESPACE) > 0) && (tOther > 0), "both namespaces hold the probe's rows")
    Set tStatus = $ClassMethod(..#WRITE, "Act", "purge", "*", ..#NAMESPACE, .tAnswer, ..#LISTSCREEN)
    Do $$$AssertEquals(tStatus _ "|" _ ##class(OcuPilot.Test.SqlRuntimeStatsRead).DirectCount(..#NAMESPACE) _ "|" _ ($ClassMethod(..#PROBE, "StatsRowCount", ..#OTHERNAMESPACE) = tOther), "200|0|1", "the list's purge removes every row of " _ ..#NAMESPACE _ " and leaves the other namespace's")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.id, 1: ""), "updated|sql-runtime-stat|*", "its answer names the namespace's statistics")
    Set tStatus = $ClassMethod(..#WRITE, "Act", "purge", "*", ..#NAMESPACE, .tAnswer, ..#LISTSCREEN)
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Verdict", tStatus, tAnswer) _ "|" _ $Select($IsObject(tAnswer) && $IsObject(tAnswer.detail): tAnswer.detail.problem, 1: ""), "400 TOOL.ARGUMENTS|" _ ##class(OcuPilot.Api.AtelierError).#REASONRUNTIMESTATSNOROWS, "a second purge is refused with its sentence")
    Set tConfirm = $ClassMethod(..#WRITE, "Agent", ..#PURGETOOL, "*", "Target", ..#NAMESPACE, .tProposal, .tResult)
    Do $$$AssertEquals(tConfirm, "mint 400 " _ ##class(OcuPilot.Api.AtelierError).#REASONRUNTIMESTATSNOROWS, "and so is the agent's, at the mint")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RecordStats", ..#NAMESPACE), "the probe's statement is recorded again")
    Set tConfirm = $ClassMethod(..#WRITE, "Agent", ..#PURGETOOL, "*", "Target", ..#NAMESPACE, .tProposal, .tResult)
    Do $$$AssertEquals(tConfirm _ "|" _ ##class(OcuPilot.Test.SqlRuntimeStatsRead).DirectCount(..#NAMESPACE) _ "|" _ ($ClassMethod(..#PROBE, "StatsRowCount", ..#OTHERNAMESPACE) = tOther), "200 |0|1", "the agent's confirmed purge removes them too: " _ tConfirm)
    Do $$$AssertEquals(##class(OcuPilot.Test.EcpDataServerWrite).Verdict($Get(tResult)), "nothingSent", "and its read-back reads nothing sent")
}

/// <p>AC3. The mint of a purge removes nothing; a proposal whose namespace recorded a statement after it was minted is closed
/// <code>PROPOSAL.TARGETCHANGED</code> at its confirm, and the rows are still there; the instance's own refusal of the purge is 409
/// <code>SQL.RUNTIMESTATS.VENDOR</code>, its ruled sentence on the wire and the instance's message in <code>detail</code> alone, with one call made and
/// every row left.</p>
/// <p>Mutation (Rule 19): the purge tool's <code>FINGERPRINTSUBJECT</code> drops <code>Rows</code> -> the confirm is not refused and goes red;
/// <code>OcuPilot.Port.SqlPort.StatementWrite</code> puts the message in the reason -> the reason assertion goes red; the purge tool's <code>Holds</code>
/// calls <code>clearStatsSQL</code> for the fresh read's namespace -> the mint-removes-nothing assertion goes red.</p>
Method TestAChangedTargetAndTheInstancesRefusalLeaveTheRowsBehind()
{
    Do ..MakeProbes()
    Kill tSettings
    Set tSettings($Parameter(..#PURGETOOL, "TOOLNAME")) = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the purge is enabled through its stored setting")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set ^||OcuPilotDatabaseWritePort = $Parameter(..#PURGETOOL, "PORTCLASS")
    Set tBeforeMint = $ClassMethod(..#PROBE, "StatsRowCount", ..#NAMESPACE)
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#PURGETOOL, "*", {"Target": "*"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the proposal is minted: " _ $Get(tProblem))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertTrue((tBeforeMint > 0) && ($ClassMethod(..#PROBE, "StatsRowCount", ..#NAMESPACE) = tBeforeMint), "the mint removed none of the probe's rows")
    Set tBefore = ##class(OcuPilot.Test.SqlRuntimeStatsRead).DirectCount(..#NAMESPACE)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RecordStats", ..#NAMESPACE), "a statement is recorded after the mint")
    Set tConfirm = $ClassMethod(..#AGENT, "Confirm", tProposal, .tResult)
    Do $$$AssertEquals(tConfirm, "409 PROPOSAL.TARGETCHANGED", "the confirm is refused target-changed: " _ tConfirm)
    Do $$$AssertTrue(##class(OcuPilot.Test.SqlRuntimeStatsRead).DirectCount(..#NAMESPACE) > tBefore, "and the namespace still holds every row, the new ones too")
    Do $ClassMethod(..#SEAM, "Refuse", "the statistics could not be removed")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = "*"
    Set tCount = ##class(OcuPilot.Test.SqlRuntimeStatsRead).DirectCount(..#NAMESPACE)
    Set tSC = $ClassMethod(..#FIXTURE, "Invoke", "RuntimeStats", "PURGESTATS", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "409 SQL.RUNTIMESTATS.VENDOR", "the instance's refusal is 409 with its code")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.reason, 1: ""), ##class(OcuPilot.Api.AtelierError).#REASONRUNTIMESTATSVENDOR, "its reason is the ruled sentence")
    Do $$$AssertTrue($IsObject($Get(tFault)) && (tFault.detail.message [ "could not be removed") && (tFault.reason '[ "removed"), "the instance's message is in detail alone")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls") _ "|" _ ##class(OcuPilot.Test.SqlRuntimeStatsRead).DirectCount(..#NAMESPACE), "1|" _ tCount, "one call was made and every row is still there")
}

/// <p>AC2. A proposal to turn collection on whose level moved after it was minted is closed <code>PROPOSAL.TARGETCHANGED</code> at its confirm, and the
/// instance keeps the level it was moved to; the cleanup puts the flag read before the test back and reads it again.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Screen.Tool.ExplorerSqlRuntimeStatsSettingSet.GUARDMOVED</parameter> 0, so no <code>Was</code> is added -> the
/// confirm is not refused and the assertion goes red.</p>
Method TestALevelMovedSinceTheMintRefusesTheConfirm()
{
    Set ^||OcuPilotDatabaseWritePort = ..#CONFIGPORT
    Set tArgs = {}
    Do tArgs.%Set("Name", "CollectionLevel", "string")
    Do tArgs.%Set("Value", "On for all modules", "string")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#SETTINGTOOL, "CollectionLevel", tArgs, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the proposal is minted: " _ $Get(tProblem))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(..State(), "0||", "the mint changed nothing")
    Set tMoved = ##class(%SYS.PTools.StatsSQL).SetSQLStats(2, 1, "", "M:5:0")
    Do $$$AssertEquals(..State(), "2|5|0", "the level is moved out of band")
    Set tConfirm = $ClassMethod(..#AGENT, "Confirm", tProposal, .tResult)
    Do $$$AssertEquals(tConfirm _ "|" _ ..State(), "409 PROPOSAL.TARGETCHANGED|2|5|0", "the confirm is refused target-changed and the level stays where it was moved: " _ tConfirm)
}

/// <p>AC2. A proposal for the stop in minutes, or for the level after the stop, whose row moved after it was minted is closed
/// <code>PROPOSAL.TARGETCHANGED</code> at its confirm, and the instance keeps the stop it was moved to; the cleanup puts the flag read before the test
/// back and reads it again.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Screen.Tool.ConfigSettingSet.MergeUpdate</code> adds <code>Was</code> for <code>CollectionLevel</code> alone -> both
/// confirms are not refused and the assertions go red.</p>
Method TestAStopMovedSinceTheMintRefusesTheConfirm()
{
    Set ^||OcuPilotDatabaseWritePort = ..#CONFIGPORT
    Set tOn = ##class(%SYS.PTools.StatsSQL).SetSQLStats(2, 1, "", "M:5:0")
    Do $$$AssertEquals(..State(), "2|5|0", "collection is on with a stop, out of band")
    For tCase = $ListBuild("StopAfterMinutes", "20", "M:7:0", "2|7|0"), $ListBuild("LevelAfterStop", "Off with collection code", "M:7:1", "2|7|1") {
        Set tArgs = {}
        Do tArgs.%Set("Name", $List(tCase, 1), "string")
        Do tArgs.%Set("Value", $List(tCase, 2), "string")
        Set tProposal = ""
        Set tSC = $ClassMethod(..#AGENT, "Mint", ..#SETTINGTOOL, $List(tCase, 1), tArgs, .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ ": the proposal is minted: " _ $Get(tProblem))
        If '$IsObject($Get(tProposal)) Continue
        Set tMoved = ##class(%SYS.PTools.StatsSQL).SetSQLStats(2, 1, "", $List(tCase, 3))
        Do $$$AssertEquals(..State(), $List(tCase, 4), $List(tCase, 1) _ ": the stop is moved out of band")
        Set tConfirm = $ClassMethod(..#AGENT, "Confirm", tProposal, .tResult)
        Do $$$AssertEquals(tConfirm _ "|" _ ..State(), "409 PROPOSAL.TARGETCHANGED|" _ $List(tCase, 4), $List(tCase, 1) _ ": the confirm is refused target-changed and the stop stays where it was moved: " _ tConfirm)
    }
}

}
