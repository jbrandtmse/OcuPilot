/// <p>Pins Story 21.3's three sets on both callers (AC1, AC2, AC3, AC4; AD-4, AD-6, AD-15, AD-53, AD-58): each screen's Set value through the
/// screen's own action route (<class>OcuPilot.Test.EcpActionFixture</class>) and the agent's mint and confirm
/// (<class>OcuPilot.Test.LicenseProbe</class>), against the real instance. A set changes exactly the one key (every other key of its class
/// reads as before), reads its value back, states the restart consequence only for a setting whose vendor source names one, and a refused
/// set changes nothing.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and <parameter>ARMINGVARIABLE</parameter> reading
/// <code>1</code>, because the class changes startup, memory and compatibility settings and sets the governance policy. It reads every
/// setting before each test and puts each one it changed back, on every path. The restart test sets <code>errlog</code> and restores it; no
/// restore clears the instance's pending-restart flag, so no test here assumes a clear one, and the one that reads it compares before and
/// after.</p>
Class OcuPilot.Test.ConfigSettingWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the setting writes, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_CONFIG_SETTINGS";

Parameter PORT = "OcuPilot.Port.ConfigPort";

Parameter ACTION = "OcuPilot.Test.EcpActionFixture";

/// <p>The class whose <code>Verdict</code> and <code>Parsed</code> read an action's answer.</p>
Parameter VERDICT = "OcuPilot.Test.EcpDataServerWrite";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

/// <p>The vendor classes the screens set.</p>
Parameter CLASSES = "Config.Startup,Config.config,Config.Miscellaneous";

/// <p>The non-restart sets: endpoint, screen, tool, setting and a value that differs from any instance's default, as the matrix names them.</p>
Parameter SETS = "Startup|osmgmt.startupsettings|StartupSettingSet|ShutdownTimeout|301;Memory|osmgmt.memorysettings|MemorySettingSet|history|501;Compatibility|osmgmt.compatibilitysettings|CompatibilitySettingSet|LineRecall|FLIP";

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

/// <p>Whether <method>OnBeforeAllTests</method> took the policy snapshot; every teardown restores only then.</p>
Property PreparedPolicyTaken As %Boolean [ InitialExpression = 0 ];

/// <p>Every setting of the three classes as the test found it, as JSON.</p>
Property PreparedSettings As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.ConfigSettingWrite changes this instance's startup, memory and compatibility settings and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set ..PreparedPolicyTaken = 1
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    ; The confirm fixture's port is the shipped config port, so the confirm reads and writes the instance.
    Set ^||OcuPilotDatabaseWritePort = ..#PORT
    Set tSnapshot = ..Snapshot()
    Set tMissing = ""
    For tI = 1:1:$Length(..#CLASSES, ",") {
        If tSnapshot.%GetTypeOf($Piece(..#CLASSES, ",", tI)) '= "object" Set tMissing = tMissing _ " " _ $Piece(..#CLASSES, ",", tI)
    }
    If tMissing '= "" Quit $$$ERROR($$$GeneralError, "could not read" _ tMissing _ ", so no test changes a setting it could not put back")
    Set ..PreparedSettings = tSnapshot.%ToJSON()
    Quit ##class(OcuPilot.Test.GovernanceFixture).Clear()
}

Method OnAfterOneTest() As %Status
{
    If '..PreparedPolicyTaken Quit $$$OK
    Kill ^||OcuPilotDatabaseWritePort
    Set tPrepared = ##class(%DynamicObject).%FromJSON(..PreparedSettings)
    Do $$$AssertStatusOK(..Restore(tPrepared), "every setting the test changed is put back")
    Do $$$AssertEquals(..Snapshot().%ToJSON(), ..PreparedSettings, "and all three classes read as before the test")
    Kill tRows
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    If '..PreparedPolicyTaken Quit $$$OK
    Kill ^||OcuPilotDatabaseWritePort
    Kill tRows
    Merge tRows = ..PreparedPolicy
    Quit ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
}

/// <p>Every key of the three vendor classes' <code>Get</code> arrays as <code>{class: {key: value}}</code>, read in <code>%SYS</code>.</p>
ClassMethod Snapshot() As %DynamicObject
{
    Set tAll = {}
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(..#CLASSES, ",") {
            Set tClass = $Piece(..#CLASSES, ",", tI)
            Kill tProps
            Set tSC = $ClassMethod(tClass, "Get", .tProps)
            If $$$ISERR(tSC) Continue
            Set tObject = {}
            Set tKey = ""
            For {
                Set tKey = $Order(tProps(tKey))
                If tKey = "" Quit
                Do tObject.%Set(tKey, tProps(tKey), "string")
            }
            Do tAll.%Set(tClass, tObject)
        }
    } Catch {
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tAll
}

/// <p>Put every key of <var>pPrepared</var> back where the instance reads another value, through the vendor's own <code>Modify</code> of the
/// complete set, in <code>%SYS</code>. Each class is restored on its own, so one class that fails leaves the others restored; the first
/// failure is answered.</p>
ClassMethod Restore(pPrepared As %DynamicObject) As %Status
{
    Set tFirst = $$$OK
    Set tOrigNS = $NAMESPACE
    For tI = 1:1:$Length(..#CLASSES, ",") {
        Set tClass = $Piece(..#CLASSES, ",", tI)
        Set tSC = $$$OK
        Try {
            Set $NAMESPACE = "%SYS"
            Kill tProps
            Set tSC = $ClassMethod(tClass, "Get", .tProps)
            If $$$ISERR(tSC) Quit
            Set tKey = ""
            For {
                Set tKey = $Order(tProps(tKey))
                If tKey = "" Quit
                Kill tProps(tKey, "Comment"), tProps(tKey, "Comments")
            }
            Set tDiffers = 0
            Set tWanted = pPrepared.%Get(tClass)
            Set tIterator = tWanted.%GetIterator()
            While tIterator.%GetNext(.tName, .tValue) {
                If $Get(tProps(tName)) '= tValue {
                    Set tProps(tName) = tValue
                    Set tDiffers = 1
                }
            }
            If tDiffers Set tSC = $ClassMethod(tClass, "Modify", .tProps)
        } Catch ex {
            Set tSC = ex.AsStatus()
        }
        If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
        If $$$ISERR(tSC) && $$$ISOK(tFirst) Set tFirst = tSC
    }
    Quit tFirst
}

/// <p>The reasons <code>Config.CPF.PendingRestart</code> reports now, as <code>section/property</code> lines in order, and their count in
/// <var>pCount</var>, read in <code>%SYS</code>.</p>
ClassMethod Pending(Output pCount As %Integer) As %String
{
    Set tOut = ""
    Set pCount = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tReasons
        Do ##class(Config.CPF).PendingRestart(.tReasons)
        Set pCount = +$Get(tReasons)
        For tI = 1:1:pCount Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ $Get(tReasons(tI, "Section")) _ "/" _ $Get(tReasons(tI, "Property"))
    } Catch {
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tOut
}

/// <p>The screen action <code>set</code> on <var>pName</var> of screen <var>pScreen</var> with the value <var>pValue</var>, through the
/// action fixture; the answer's parsed envelope in <var>pAnswer</var>, answering the HTTP status.</p>
ClassMethod Act(pScreen As %String, pName As %String, pValue As %String, Output pAnswer As %DynamicObject) As %Integer
{
    Set tBody = {"action": "set"}
    Do tBody.%Set("id", pName, "string")
    Set tValues = {}
    Do tValues.%Set("Value", pValue, "string")
    Do tBody.%Set("values", tValues)
    Set tSC = $ClassMethod(..#ACTION, "Act", pScreen, tBody, .tJson, .tStatus)
    Set pAnswer = $ClassMethod(..#VERDICT, "Parsed", tJson)
    Quit tStatus
}

/// <p>The refusal code an answer carries, or <code>""</code>.</p>
ClassMethod Code(pAnswer As %DynamicObject) As %String
{
    Quit $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>Mint <var>pTool</var> for <var>pName</var> with value <var>pValue</var> and confirm it; answers <code>http code</code> and the confirm's
/// answer in <var>pResult</var>, or <code>refused: &lt;problem&gt;</code> when the mint refused. The minted proposal is in
/// <var>pProposal</var>.</p>
ClassMethod Agent(pTool As %String, pName As %String, pValue As %String, Output pResult As %DynamicObject, Output pProposal As %DynamicObject) As %String
{
    Set tArgs = {}
    Do tArgs.%Set("Name", pName, "string")
    Do tArgs.%Set("Value", pValue, "string")
    Set tSC = $ClassMethod(..#AGENT, "Mint", pTool, pName, tArgs, .pProposal, .tHttp, .tProblem)
    If '$IsObject($Get(pProposal)) Quit "refused: " _ $Get(tProblem)
    Quit $ClassMethod(..#AGENT, "Confirm", pProposal, .pResult)
}

/// <p>The value of <var>pName</var> in the screen's read of <var>pEndpoint</var>, through the port.</p>
ClassMethod ValueOf(pEndpoint As %String, pName As %String) As %String
{
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = $ClassMethod(..#PORT, "Invoke", pEndpoint, "GET", .tQuery, "", .tRow, .tHttp, .tFault)
    Quit $Select($IsObject($Get(tRow)): tRow.%Get("Value"), 1: "(" _ $Get(tHttp) _ ")")
}

/// <p>The snapshot <var>pSnapshot</var> with <var>pName</var> of <var>pClass</var> removed, as JSON, so what a set did not touch can be compared.</p>
ClassMethod Without(pSnapshot As %DynamicObject, pClass As %String, pName As %String) As %String
{
    Set tCopy = ##class(%DynamicObject).%FromJSON(pSnapshot.%ToJSON())
    Do tCopy.%Get(pClass).%Remove(pName)
    Quit tCopy.%ToJSON()
}

/// <p><b>AC1, AC4.</b> Each screen's Set value and the agent's confirmed proposal change exactly one setting, in both directions on both
/// callers, with a read-back reading <code>matches</code>, no consequence for a setting that needs no restart, every other key of the class
/// reading as before and no new pending-restart reason.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>SendProperties</code> sends no <code>Modify</code> -> the value
/// assertions go red.</p>
Method TestASetChangesOnlyItsKeyOnBothCallersAndIsRestored()
{
    For tI = 1:1:$Length(..#SETS, ";") {
        Set tCase = $Piece(..#SETS, ";", tI)
        Set tEndpoint = $Piece(tCase, "|", 1)
        Set tScreen = $Piece(tCase, "|", 2)
        Set tTool = "OcuPilot.Screen.Tool." _ $Piece(tCase, "|", 3)
        Set tName = $Piece(tCase, "|", 4)
        Set tClass = $ClassMethod(..#PORT, "VendorClass", tEndpoint)
        Set tFound = ..ValueOf(tEndpoint, tName)
        Set tNew = $Piece(tCase, "|", 5)
        If tNew = "FLIP" Set tNew = 'tFound
        Set tBefore = ..Snapshot()
        Do ..Pending(.tPendingBefore)
        Set tStatus = ..Act(tScreen, tName, tNew, .tAnswer)
        Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer) _ "|" _ ..ValueOf(tEndpoint, tName), "200|matches|" _ tNew, tName _ ": the screen's Set value changes it and reads it back: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
        Do $$$AssertEquals(..Without(..Snapshot(), tClass, tName), ..Without(tBefore, tClass, tName), tName _ ": every other key of " _ tClass _ " reads as before")
        Set tOutcome = ..Agent(tTool, tName, tFound, .tResult, .tProposal)
        Do $$$AssertEquals(tOutcome _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult) _ "|" _ ..ValueOf(tEndpoint, tName), "200 |matches|" _ tFound, tName _ ": the agent's confirmed proposal puts it back: " _ tOutcome)
        Do $$$AssertEquals(##class(OcuPilot.Test.EcpSettingsWrite).Consequence(tProposal), "", tName _ ": and states no consequence")
        Set tOutcome = ..Agent(tTool, tName, tNew, .tResult, .tProposal)
        Do $$$AssertEquals(tOutcome _ "|" _ ..ValueOf(tEndpoint, tName), "200 |" _ tNew, tName _ ": the agent's confirmed proposal changes it")
        Do $$$AssertEquals(..Without(..Snapshot(), tClass, tName), ..Without(tBefore, tClass, tName), tName _ ": and every other key reads as before")
        Set tStatus = ..Act(tScreen, tName, tFound, .tAnswer)
        Do $$$AssertEquals(tStatus _ "|" _ ..ValueOf(tEndpoint, tName), "200|" _ tFound, tName _ ": the screen's Set value restores it")
        Do ..Pending(.tPendingAfter)
        Do $$$AssertEquals(tPendingAfter, tPendingBefore, tName _ ": and none of the four sets added a pending-restart reason")
    }
}

/// <p><b>AC2.</b> A set of a setting whose vendor source states a restart states it: the agent's card carries
/// <code>CONFIG.SETTING.RESTART</code>, the change is stored and the instance names it pending, and the screen's Set value, which has no card,
/// restores it. A change the instance needs no restart for adds no reason.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Screen.Tool.ConfigSettingSet</class>'s <code>Consequence</code> answers nothing -> the consequence
/// assertion goes red.</p>
Method TestARestartBoundSetStatesTheConsequenceAndTheInstanceNamesItPending()
{
    Set tFound = ..ValueOf("Memory", "errlog")
    Set tNew = tFound + 1
    Do ..Pending(.tBefore)
    Set tOutcome = ..Agent("OcuPilot.Screen.Tool.MemorySettingSet", "errlog", tNew, .tResult, .tProposal)
    Do $$$AssertEquals(tOutcome _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult) _ "|" _ ..ValueOf("Memory", "errlog"), "200 |matches|" _ tNew, "the agent's confirmed errlog change is stored: " _ tOutcome)
    Do $$$AssertEquals(##class(OcuPilot.Test.EcpSettingsWrite).Consequence(tProposal), "CONFIG.SETTING.RESTART", "its card states that it takes effect at the next restart")
    Set tPending = ..Pending(.tAfter)
    Do $$$AssertEquals(tAfter, tBefore + 1, "the instance names one more pending reason")
    Do $$$AssertEquals($Piece(tPending, ",", tAfter), "config/errlog", "and it is config/errlog")
    Set tStatus = ..Act("osmgmt.memorysettings", "errlog", tFound, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..ValueOf("Memory", "errlog"), "200|" _ tFound, "the screen's Set value restores it")
}

/// <p><b>AC1, AC3.</b> A set that is refused changes nothing: at the screen's route an unknown setting is 404 <code>CONFIG.SETTING.NOTFOUND</code>,
/// a setting shown and never changed 409 <code>CONFIG.SETTING.READONLY</code> and a value the setting does not accept 400
/// <code>CONFIG.SETTING.VALUE</code>; at the mint each is refused with its sentence. Every setting reads as before.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Api.ConfigError</class>'s <code>HttpStatusFor</code> answers 400 for <code>CONFIG.SETTING.NOTFOUND</code> ->
/// the 404 row goes red. A mutation that lets a read-only setting through is run against <class>OcuPilot.Test.ConfigSettingRules</class>, whose
/// seam sends nothing, and never here.</p>
Method TestARefusedSetChangesNothingOnEitherCaller()
{
    Set tBefore = ..Snapshot().%ToJSON()
    ; A setting shown and never changed is sent the value it already holds, so a guard that regressed would write nothing new.
    Set tPort = ..ValueOf("Startup", "DefaultPort")
    Set tTemp = ..ValueOf("Startup", "TempDirectory")
    For tCase = $ListBuild("osmgmt.startupsettings", "NoSuchSetting", "1", "404|CONFIG.SETTING.NOTFOUND"), $ListBuild("osmgmt.startupsettings", "DefaultPort", tPort, "409|CONFIG.SETTING.READONLY"), $ListBuild("osmgmt.startupsettings", "TempDirectory", tTemp, "409|CONFIG.SETTING.READONLY"), $ListBuild("osmgmt.startupsettings", "ShutdownTimeout", "119", "400|CONFIG.SETTING.VALUE"), $ListBuild("osmgmt.startupsettings", "ShutdownTimeout", "x", "400|CONFIG.SETTING.VALUE"), $ListBuild("osmgmt.memorysettings", "bbsiz", "100", "400|CONFIG.SETTING.VALUE"), $ListBuild("osmgmt.compatibilitysettings", "LineRecall", "2", "400|CONFIG.SETTING.VALUE"), $ListBuild("osmgmt.compatibilitysettings", "Undefined", "3", "400|CONFIG.SETTING.VALUE") {
        Set tStatus = ..Act($List(tCase, 1), $List(tCase, 2), $List(tCase, 3), .tAnswer)
        Do $$$AssertEquals(tStatus _ "|" _ ..Code(tAnswer), $List(tCase, 4), $List(tCase, 2) _ " '" _ $List(tCase, 3) _ "' is refused at the screen")
    }
    Set tDbSizes = ..Act("osmgmt.startupsettings", "DBSizesAllowed", "16384", .tAnswer)
    Do $$$AssertEquals(tDbSizes _ "|" _ ..Code(tAnswer), "400|CONFIG.SETTING.VALUE", "DBSizesAllowed without 8192 is refused at the screen")
    Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.StartupSettingSet", "ShutdownTimeout", "119", .tResult, .tProposal), "refused: This setting does not accept that value.", "a value out of range is refused at the mint")
    Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.StartupSettingSet", "DefaultPort", tPort, .tResult, .tProposal), "refused: This setting is shown here and never changed here.", "a setting shown and never changed is refused at the mint")
    Do $$$AssertEquals(..Agent("OcuPilot.Screen.Tool.MemorySettingSet", "NoSuchSetting", "1", .tResult, .tProposal), "refused: 'NoSuchSetting' is not present on this instance", "an unknown setting is refused at the mint, which reads the target first")
    Do $$$AssertEquals(..Snapshot().%ToJSON(), tBefore, "and every setting of the three classes reads as before")
}

/// <p><b>AC4.</b> With the key enabled by the baseline the agent's call for a set is dispatched, mints a proposal and its confirm changes the
/// setting once, with a read-back and one write-kind ledger row carrying the audit marker; the proposal's token is spent, so a second confirm
/// is refused and changes nothing more. With the key stored disabled the same call is refused at dispatch.</p>
/// <p>Mutation (Rule 19): <code>osmgmt.compatibilitysettings.set</code> set <code>false</code> in
/// <class>OcuPilot.Kernel.Governance.Baseline</class> -> the dispatch assertion goes red.</p>
Method TestTheAgentsConfirmWritesOnceWithOneAuditMarker()
{
    Set tFound = ..ValueOf("Compatibility", "LineRecall")
    Set tNew = 'tFound
    Set tInput = {"Name": "LineRecall", "Value": (tNew), "rationale": "probe", "expectedImpact": "probe"}
    Do tInput.%Set("Value", tNew _ "", "string")
    Do $$$AssertEquals(..Dispatched("osmgmt.compatibilitysettings.set", tInput, .tProposalId, .tTurnKey) _ "|" _ (tProposalId '= ""), "minted|1", "the baseline lets the call mint a proposal")
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tProposalId, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ $Get(tCode) _ "|" _ ..ValueOf("Compatibility", "LineRecall") _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult), "1||" _ tNew _ "|matches", "its confirm changes the setting, with a read-back: " _ $Get(tCode))
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tRow), 1, "one write-kind ledger row records it")
    Do $$$AssertEquals($Get(tRow("AuditMarked")), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "and the agent's audit marker landed on it")
    Do $$$AssertStatusOK(..Restore(##class(%DynamicObject).%FromJSON(..PreparedSettings)), "the setting is put back")
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tProposalId, "", $Username, .tResult2, .tHttp2, .tCode2, .tDetail2)
    Do $$$AssertEquals($$$ISERR(tSC) _ "|" _ ..ValueOf("Compatibility", "LineRecall"), "1|" _ tFound, "a second confirm of the same proposal is refused and changes nothing")
    Kill tSettings
    Set tSettings("osmgmt.compatibilitysettings.set") = "disabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the key is stored disabled")
    Do $$$AssertEquals(..Dispatched("osmgmt.compatibilitysettings.set", tInput, .tNone), "refused", "and the same call is refused at dispatch")
    Set tStatus = ..Act("osmgmt.compatibilitysettings", "LineRecall", tNew, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..ValueOf("Compatibility", "LineRecall"), "200|" _ tNew, "while a person's Set value is not governed and still changes it (AD-22)")
}

/// <p>The agent's dispatch of <var>pKey</var> with <var>pInput</var>: <code>minted</code> with the proposal id in <var>pProposalId</var> and
/// the turn's key in <var>pTurnKey</var>, or <code>refused</code>.</p>
ClassMethod Dispatched(pKey As %String, pInput As %DynamicObject, Output pProposalId As %String, Output pTurnKey As %String) As %String
{
    Set pProposalId = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Set pTurnKey = $Get(tTurnKey)
    If $$$ISERR(tSC) Quit "no turn"
    Set tUse = {"type": "tool_use", "id": "toolu_config"}
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName(pKey), "string")
    Do tUse.%Set("input", pInput)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurnKey)
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurnKey, $Username, "", [(tUse)], "OcuPilot.Kernel.Agent.Limits", .tResults, .tNames, 0, 0, .tDetails)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set tContent = $Select($IsObject($Get(tResults)) && (tResults.%Size() = 1): tResults.%Get(0).%Get("content"), 1: "")
    Set tParsed = ##class(OcuPilot.Test.LicenseKey).Parsed(tContent)
    If $IsObject(tParsed) Set pProposalId = tParsed.%Get("proposalId")
    Quit $Select(pProposalId '= "": "minted", 1: "refused")
}

}
