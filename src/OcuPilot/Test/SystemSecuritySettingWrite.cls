/// <p>Pins Story 21.10's set of a system-wide security parameter on both callers (AC1, AC6; AD-4, AD-6, AD-15, AD-22, AD-53, AD-58): the screen's Set value
/// through its own action route (<class>OcuPilot.Test.EcpActionFixture</class>) and the agent's mint and confirm
/// (<class>OcuPilot.Test.LicenseProbe</class>), against the real instance. A set changes exactly the one parameter, reads its value back and states
/// the consequence on the agent's card; a parameter shown and never changed, an unlisted name, a value outside the page's limits and a value the vendor
/// refuses change nothing, at the screen and at the mint; and with the key at its baseline the agent is refused while a person is not.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>,
/// because the class changes a system-wide security parameter and sets the governance policy. It changes <code>InactiveLimit</code> only, reads the
/// roster's parameters before each test and puts every one it changed back on every path.</p>
Class OcuPilot.Test.SystemSecuritySettingWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the setting writes, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_CONFIG_SETTINGS";

Parameter PORT = "OcuPilot.Port.ConfigPort";

Parameter ACTION = "OcuPilot.Test.EcpActionFixture";

/// <p>The class whose <code>Verdict</code> and <code>Parsed</code> read an action's answer.</p>
Parameter VERDICT = "OcuPilot.Test.EcpDataServerWrite";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter TOOL = "OcuPilot.Screen.Tool.SystemSecuritySettingSet";

Parameter KEY = "security.systemsecurity.set";

Parameter SCREEN = "security.systemsecurity";

/// <p>The parameter this class changes and the two values it moves between.</p>
Parameter NAME = "InactiveLimit";

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

/// <p>Whether <method>OnBeforeAllTests</method> took the policy snapshot; every teardown restores only then.</p>
Property PreparedPolicyTaken As %Boolean [ InitialExpression = 0 ];

/// <p>Every roster parameter as the test found it, as JSON.</p>
Property PreparedSettings As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SystemSecuritySettingWrite changes this instance's system-wide security parameters and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
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
    If tSnapshot.%ToJSON() = "{}" Quit $$$ERROR($$$GeneralError, "could not read the parameters, so no test changes one it could not put back")
    Set ..PreparedSettings = tSnapshot.%ToJSON()
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Clear()
    If $$$ISERR(tSC) Quit tSC
    Kill tSettings
    Set tSettings(..#KEY) = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

Method OnAfterOneTest() As %Status
{
    If '..PreparedPolicyTaken Quit $$$OK
    Kill ^||OcuPilotDatabaseWritePort
    Set tPrepared = ##class(%DynamicObject).%FromJSON(..PreparedSettings)
    Do $$$AssertStatusOK(..Restore(tPrepared), "every parameter the test changed is put back")
    Do $$$AssertEquals(..Snapshot().%ToJSON(), ..PreparedSettings, "and the roster's parameters read as before the test")
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

/// <p>Every roster name <code>Security.System.Get</code> answers, with its value, as JSON, read in <code>%SYS</code>; <code>{}</code> when it cannot be read.</p>
ClassMethod Snapshot() As %DynamicObject
{
    Set tAll = {}
    Set tRoster = $Parameter("OcuPilot.Test.SystemSecuritySettingRead", "NAMES")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.System).Get("SYSTEM", .tProps)
        If $$$ISOK(tSC) {
            For tI = 1:1:$Length(tRoster, ",") {
                Set tName = $Piece(tRoster, ",", tI)
                If $Data(tProps(tName)) Do tAll.%Set(tName, tProps(tName), "string")
            }
        }
    } Catch {
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tAll
}

/// <p>Put every parameter of <var>pPrepared</var> back where the instance reads another value, through the vendor's own <code>Modify</code> of the names
/// that differ, in <code>%SYS</code>. The names the page shows and never changes are put back too, in case a test moved one.</p>
ClassMethod Restore(pPrepared As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.System).Get("SYSTEM", .tProps)
        If $$$ISERR(tSC) Quit
        Set tDiffers = 0
        Kill tSend
        Set tIterator = pPrepared.%GetIterator()
        While tIterator.%GetNext(.tName, .tValue) {
            If $Get(tProps(tName)) '= tValue {
                Set tSend(tName) = tValue
                Set tDiffers = 1
            }
        }
        If tDiffers Set tSC = ##class(Security.System).Modify("SYSTEM", .tSend)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The screen action <code>set</code> on <var>pName</var> with the value <var>pValue</var>, through the action fixture; the answer's parsed envelope
/// in <var>pAnswer</var>, answering the HTTP status.</p>
ClassMethod Act(pName As %String, pValue As %String, Output pAnswer As %DynamicObject) As %Integer
{
    Set tBody = {"action": "set"}
    Do tBody.%Set("id", pName, "string")
    Set tValues = {}
    Do tValues.%Set("Value", pValue, "string")
    Do tBody.%Set("values", tValues)
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, tBody, .tJson, .tStatus)
    Set pAnswer = $ClassMethod(..#VERDICT, "Parsed", tJson)
    Quit tStatus
}

/// <p>The refusal code an answer carries, or <code>""</code>.</p>
ClassMethod Code(pAnswer As %DynamicObject) As %String
{
    Quit $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>Mint the tool for <var>pName</var> with value <var>pValue</var> and confirm it; answers <code>http code</code> and the confirm's answer in
/// <var>pResult</var>, or <code>refused: &lt;problem&gt;</code> when the mint refused. The minted proposal is in <var>pProposal</var>.</p>
ClassMethod Agent(pName As %String, pValue As %String, Output pResult As %DynamicObject, Output pProposal As %DynamicObject) As %String
{
    Set tArgs = {}
    Do tArgs.%Set("Name", pName, "string")
    Do tArgs.%Set("Value", pValue, "string")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#TOOL, pName, tArgs, .pProposal, .tHttp, .tProblem)
    If '$IsObject($Get(pProposal)) Quit "refused: " _ $Get(tProblem)
    Quit $ClassMethod(..#AGENT, "Confirm", pProposal, .pResult)
}

/// <p>The value of <var>pName</var> through the port.</p>
ClassMethod ValueOf(pName As %String) As %String
{
    Kill tQuery
    Set tQuery("name") = pName
    Set tSC = $ClassMethod(..#PORT, "Invoke", "Security", "GET", .tQuery, "", .tRow, .tHttp, .tFault)
    Quit $Select($IsObject($Get(tRow)): tRow.%Get("Value"), 1: "(" _ $Get(tHttp) _ ")")
}

/// <p>The snapshot <var>pSnapshot</var> with <var>pName</var> removed, as JSON, so what a set did not touch can be compared.</p>
ClassMethod Without(pSnapshot As %DynamicObject, pName As %String) As %String
{
    Set tCopy = ##class(%DynamicObject).%FromJSON(pSnapshot.%ToJSON())
    Do tCopy.%Remove(pName)
    Quit tCopy.%ToJSON()
}

/// <p>A value for <code>InactiveLimit</code> that differs from <var>pFound</var> and from every default an instance ships.</p>
ClassMethod Other(pFound As %String) As %String
{
    Quit $Select(pFound = 89: 88, 1: 89)
}

/// <p><b>AC1.</b> The screen's Set value and the agent's confirmed proposal change exactly <code>InactiveLimit</code>, in both directions on both callers,
/// with a read-back reading <code>matches</code>, every other parameter reading as before, and the agent's card stating the consequence code.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>SendEntry</code> sends no <code>Modify</code> -> the value assertions go red.</p>
Method TestASetChangesOnlyItsParameterOnBothCallersAndIsRestored()
{
    Set tName = ..#NAME
    Set tFound = ..ValueOf(tName)
    Set tNew = ..Other(tFound)
    Set tBefore = ..Snapshot()
    Set tStatus = ..Act(tName, tNew, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer) _ "|" _ ..ValueOf(tName), "200|matches|" _ tNew, tName _ ": the screen's Set value changes it and reads it back: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals(..Without(..Snapshot(), tName), ..Without(tBefore, tName), tName _ ": every other parameter reads as before")
    Set tOutcome = ..Agent(tName, tFound, .tResult, .tProposal)
    Do $$$AssertEquals(tOutcome _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult) _ "|" _ ..ValueOf(tName), "200 |matches|" _ tFound, tName _ ": the agent's confirmed proposal puts it back: " _ tOutcome)
    Do $$$AssertEquals(##class(OcuPilot.Test.EcpSettingsWrite).Consequence(tProposal), "SECURITY.SYSTEM.SET", tName _ ": its card states the consequence")
    Set tOutcome = ..Agent(tName, tNew, .tResult, .tProposal)
    Do $$$AssertEquals(tOutcome _ "|" _ ..ValueOf(tName), "200 |" _ tNew, tName _ ": the agent's confirmed proposal changes it")
    Do $$$AssertEquals(..Without(..Snapshot(), tName), ..Without(tBefore, tName), tName _ ": and every other parameter reads as before")
    Set tStatus = ..Act(tName, tFound, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..ValueOf(tName), "200|" _ tFound, tName _ ": the screen's Set value restores it")
}

/// <p><b>AC1.</b> A set that is refused changes nothing: at the screen's route an unlisted name is 404 <code>CONFIG.SETTING.NOTFOUND</code>, a
/// parameter shown and never changed 409 <code>CONFIG.SETTING.READONLY</code>, and a value outside the page's limits or one the vendor refuses 400
/// <code>CONFIG.SETTING.VALUE</code>; at the mint each is refused with its sentence. Every parameter reads as before.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s roster marks <code>RequiredRole</code> settable -> the 409 row and the mint's
/// refusal go red; and the roster's <code>InactiveLimit</code> maximum raised to 400 -> the 400 row goes red.</p>
Method TestARefusedSetChangesNothingOnEitherCaller()
{
    Set tBefore = ..Snapshot().%ToJSON()
    ; A parameter shown and never changed is sent the value it already holds, so a guard that regressed would write nothing new.
    Set tRole = ..ValueOf("RequiredRole")
    For tCase = $ListBuild("PrivateJWKS", "x", "404|CONFIG.SETTING.NOTFOUND"), $ListBuild("NoSuchSetting", "1", "404|CONFIG.SETTING.NOTFOUND"), $ListBuild("RequiredRole", tRole, "409|CONFIG.SETTING.READONLY"), $ListBuild("PasswordValidationRoutine", "", "409|CONFIG.SETTING.READONLY"), $ListBuild("AuditEnabled", ..ValueOf("AuditEnabled"), "409|CONFIG.SETTING.READONLY"), $ListBuild("InactiveLimit", "366", "400|CONFIG.SETTING.VALUE"), $ListBuild("InactiveLimit", "-1", "400|CONFIG.SETTING.VALUE"), $ListBuild("InvalidLoginLimit", "65", "400|CONFIG.SETTING.VALUE"), $ListBuild("AuditFlags", "2", "400|CONFIG.SETTING.VALUE"), $ListBuild("DefaultSignatureHash", "MD5", "400|CONFIG.SETTING.VALUE"), $ListBuild("PasswordPattern", "(", "400|CONFIG.SETTING.VALUE") {
        Set tStatus = ..Act($List(tCase, 1), $List(tCase, 2), .tAnswer)
        Do $$$AssertEquals(tStatus _ "|" _ ..Code(tAnswer), $List(tCase, 3), $List(tCase, 1) _ " '" _ $List(tCase, 2) _ "' is refused at the screen")
    }
    Do $$$AssertEquals(..Agent("InactiveLimit", "366", .tResult, .tProposal), "refused: This setting does not accept that value.", "a value over the page's limit is refused at the mint")
    Do $$$AssertEquals(..Agent("RequiredRole", tRole, .tResult, .tProposal), "refused: This setting is shown here and never changed here.", "a parameter shown and never changed is refused at the mint")
    Do $$$AssertEquals(..Agent("NoSuchSetting", "1", .tResult, .tProposal), "refused: 'NoSuchSetting' is not present on this instance", "an unlisted name is refused at the mint, which reads the target first")
    Do $$$AssertEquals(..Snapshot().%ToJSON(), tBefore, "and every parameter reads as before")
}

/// <p><b>AC1, AC6.</b> With the key enabled the agent's call is dispatched, mints a proposal and its confirm changes the parameter once, with a read-back
/// and one write-kind ledger row carrying the audit marker; the proposal's token is spent, so a second confirm is refused and changes nothing more.
/// With the key at its baseline the same call is refused at dispatch, while a person's Set value is not governed and still changes it (AD-22).</p>
/// <p>Mutation (Rule 19): <code>security.systemsecurity.set</code> set <code>true</code> in <class>OcuPilot.Kernel.Governance.Baseline</class> -> the
/// baseline-refusal assertion goes red.</p>
Method TestTheAgentsConfirmWritesOnceWithOneAuditMarkerAndTheBaselineRefusesIt()
{
    Set tName = ..#NAME
    Set tFound = ..ValueOf(tName)
    Set tNew = ..Other(tFound)
    Set tInput = {"Name": (tName), "rationale": "probe", "expectedImpact": "probe"}
    Do tInput.%Set("Value", tNew _ "", "string")
    Do $$$AssertEquals(..Dispatched(..#KEY, tInput, .tProposalId, .tTurnKey) _ "|" _ (tProposalId '= ""), "minted|1", "the enabled key lets the call mint a proposal")
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tProposalId, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ $Get(tCode) _ "|" _ ..ValueOf(tName) _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult), "1||" _ tNew _ "|matches", "its confirm changes the parameter, with a read-back: " _ $Get(tCode))
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tRow), 1, "one write-kind ledger row records it")
    Do $$$AssertEquals($Get(tRow("AuditMarked")), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "and the agent's audit marker landed on it")
    Do $$$AssertStatusOK(..Restore(##class(%DynamicObject).%FromJSON(..PreparedSettings)), "the parameter is put back")
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tProposalId, "", $Username, .tResult2, .tHttp2, .tCode2, .tDetail2)
    Do $$$AssertEquals($$$ISERR(tSC) _ "|" _ ..ValueOf(tName), "1|" _ tFound, "a second confirm of the same proposal is refused and changes nothing")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Clear(), "the baseline decides again")
    Do $$$AssertEquals(..Dispatched(..#KEY, tInput, .tNone), "refused", "and the same call is refused at dispatch")
    Set tStatus = ..Act(tName, tNew, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..ValueOf(tName), "200|" _ tNew, "while a person's Set value is not governed and still changes it")
}

/// <p>The agent's dispatch of <var>pKey</var> with <var>pInput</var>: <code>minted</code> with the proposal id in <var>pProposalId</var> and the turn's key
/// in <var>pTurnKey</var>, or <code>refused</code>.</p>
ClassMethod Dispatched(pKey As %String, pInput As %DynamicObject, Output pProposalId As %String, Output pTurnKey As %String) As %String
{
    Set pProposalId = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Set pTurnKey = $Get(tTurnKey)
    If $$$ISERR(tSC) Quit "no turn"
    Set tUse = {"type": "tool_use", "id": "toolu_security"}
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
