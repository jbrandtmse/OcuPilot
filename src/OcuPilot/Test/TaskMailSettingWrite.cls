/// <p>Pins Story 21.19's set of a Task Manager email setting on both callers (AC2, AC6; AD-4, AD-6, AD-15, AD-22, AD-35, AD-53, AD-58): the screen's Set
/// value through its own action route (<class>OcuPilot.Test.EcpActionFixture</class>) and the agent's mint and confirm
/// (<class>OcuPilot.Test.LicenseProbe</class>), against the real instance. A set changes exactly the one setting, reads its value back and writes one
/// configuration-change audit row; <code>UseSTARTTLS</code> and the two messages are stored as the vendor's own <code>EmailGet</code> reads them; a
/// setting the port does not list, a port out of range, a field the Task Manager does not fill in and a value the
/// vendor refuses change nothing, at the screen and at the mint; a write the vendor did not store reads back as different; and with the key
/// disabled the agent is refused while a person is not. The mail password is never read or changed.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>,
/// because the class changes the Task Manager's email settings and sets the governance policy. It reads the twelve settings before each test, puts
/// every one it changed back on every path, and removes a stored row the run created.</p>
Class OcuPilot.Test.TaskMailSettingWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the setting writes, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_CONFIG_SETTINGS";

Parameter PORT = "OcuPilot.Port.ConfigPort";

Parameter SEAM = "OcuPilot.Test.ConfigGateSeam";

Parameter ACTION = "OcuPilot.Test.EcpActionFixture";

/// <p>The class whose <code>Verdict</code> and <code>Parsed</code> read an action's answer.</p>
Parameter VERDICT = "OcuPilot.Test.EcpDataServerWrite";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter TOOL = "OcuPilot.Screen.Tool.TaskMailSettingSet";

Parameter KEY = "tasks.mail.set";

Parameter SCREEN = "tasks.mail";

Parameter ENDPOINT = "TaskMail";

/// <p>The vendor event every set writes a row of.</p>
Parameter EVENT = "%System/%System/ConfigurationChange";

/// <p>The twelve settings, the mail password excluded.</p>
Parameter NAMES = "AuthUser,MessageFailure,MessageSuccess,Port,ReplyTo,SSLConfiguration,Sender,Server,SubjectFailure,SubjectSuccess,TimeZone,UseSTARTTLS";

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

/// <p>Whether <method>OnBeforeAllTests</method> took the policy snapshot; every teardown restores only then.</p>
Property PreparedPolicyTaken As %Boolean [ InitialExpression = 0 ];

/// <p>Every setting as the test found it, as JSON.</p>
Property PreparedSettings As %String(MAXLEN = "") [ InitialExpression = "" ];

/// <p>The stored rows the class found, as <code>$ListBuild</code> of the names that existed.</p>
Property PreparedRows As %List;

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TaskMailSettingWrite changes this instance's Task Manager email settings and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set ..PreparedPolicyTaken = 1
    Set ..PreparedRows = ..StoredRows()
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    ; The confirm fixture's port is the shipped config port, so the confirm reads and writes the instance.
    Set ^||OcuPilotDatabaseWritePort = ..#PORT
    Set tSnapshot = ..Snapshot()
    If tSnapshot.%Size() '= 12 Quit $$$ERROR($$$GeneralError, "could not read the settings, so no test changes one it could not put back")
    Set ..PreparedSettings = tSnapshot.%ToJSON()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Quit ##class(OcuPilot.Test.GovernanceFixture).Clear()
}

Method OnAfterOneTest() As %Status
{
    If '..PreparedPolicyTaken Quit $$$OK
    Kill ^||OcuPilotDatabaseWritePort
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Set tPrepared = ##class(%DynamicObject).%FromJSON(..PreparedSettings)
    Do $$$AssertStatusOK(..Restore(tPrepared), "every setting the test changed is put back")
    Do $$$AssertEquals(..Snapshot().%ToJSON(), ..PreparedSettings, "and the twelve settings read as before the test")
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
    Do ..RemoveCreatedRows(..PreparedRows)
    Kill tRows
    Merge tRows = ..PreparedPolicy
    Quit ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
}

/// <p>Every setting with its value, as JSON, read through <code>EmailGet</code> in <code>%SYS</code>; an empty object when any cannot be read.</p>
ClassMethod Snapshot() As %DynamicObject
{
    Set tAll = {}
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(..#NAMES, ",") {
            Set tName = $Piece(..#NAMES, ",", tI)
            Set tSC = ##class(%SYS.Task.Config).EmailGet(tName, .tValue)
            If $$$ISERR(tSC) {
                Set tAll = {}
                Quit
            }
            Do tAll.%Set(tName, tValue, "string")
        }
    } Catch {
        Set tAll = {}
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tAll
}

/// <p>Put every setting of <var>pPrepared</var> back where the instance reads another value, through the vendor's own <code>EmailSet</code> in
/// <code>%SYS</code>.</p>
ClassMethod Restore(pPrepared As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tIterator = pPrepared.%GetIterator()
        While tIterator.%GetNext(.tName, .tValue) {
            Set tRead = ##class(%SYS.Task.Config).EmailGet(tName, .tNow)
            If $$$ISERR(tRead) Set tSC = tRead Continue
            If tNow '= tValue {
                Set tSet = ##class(%SYS.Task.Config).EmailSet(tName, tValue)
                If $$$ISERR(tSet) Set tSC = tSet
            }
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The names of the twelve settings whose stored row exists, as a <code>$ListBuild</code> list, read in <code>%SYS</code>.</p>
ClassMethod StoredRows() As %List
{
    Set tFound = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(..#NAMES, ",") {
            Set tName = $Piece(..#NAMES, ",", tI)
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM %SYS_Task.Config WHERE ParamName = ?", "Mail" _ tName)
            If tRS.%Next() && (tRS.%GetData(1) > 0) Set tFound = tFound _ $ListBuild(tName)
        }
    } Catch {
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tFound
}

/// <p>Delete the stored rows of the twelve settings that did not exist in <var>pFound</var> and read empty now, so the instance holds what it held
/// before the run.</p>
ClassMethod RemoveCreatedRows(pFound As %List)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tI = 1:1:$Length(..#NAMES, ",") {
            Set tName = $Piece(..#NAMES, ",", tI)
            If $ListFind(pFound, tName) Continue
            Set tRS = ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM %SYS_Task.Config WHERE ParamName = ? AND (Data IS NULL OR Data = '')", "Mail" _ tName)
        }
    } Catch {
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
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
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "GET", .tQuery, "", .tRow, .tHttp, .tFault)
    Quit $Select($IsObject($Get(tRow)): tRow.%Get("Value"), 1: "(" _ $Get(tHttp) _ ")")
}

/// <p>The snapshot <var>pSnapshot</var> with <var>pName</var> removed, as JSON, so what a set did not touch can be compared.</p>
ClassMethod Without(pSnapshot As %DynamicObject, pName As %String) As %String
{
    Set tCopy = ##class(%DynamicObject).%FromJSON(pSnapshot.%ToJSON())
    Do tCopy.%Remove(pName)
    Quit tCopy.%ToJSON()
}

/// <p>A port that differs from <var>pFound</var>.</p>
ClassMethod OtherPort(pFound As %String) As %String
{
    Quit $Select(pFound = 2525: 2526, 1: 2525)
}

/// <p>The value of <var>pName</var> as the vendor's own <code>EmailGet</code> answers it in <code>%SYS</code>, or <code>(error)</code>.</p>
ClassMethod VendorValue(pName As %String) As %String
{
    Set tValue = "(error)"
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(%SYS.Task.Config).EmailGet(pName, .tRead)
        If $$$ISOK(tSC) Set tValue = $Get(tRead)
    } Catch {
        Set tValue = "(error)"
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tValue
}

/// <p><b>AC2.</b> <code>UseSTARTTLS</code> and the two messages round-trip through the vendor: the screen's Set value turns <code>UseSTARTTLS</code> on
/// and then off and sets <code>MessageSuccess</code> to a two-line text, and the agent's confirmed proposal sets <code>MessageFailure</code> to a text
/// of the 32,000-character cap, each reading back <code>matches</code> and read by the vendor's own <code>EmailGet</code> exactly as sent.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>SendNode</code> sends no <code>EmailSet</code> for the mail endpoint -> every
/// row goes red.</p>
Method TestTheStartTlsFlagAndTheMessagesRoundTripThroughTheVendor()
{
    For tFlag = 1, 0 {
        Set tStatus = ..Act("UseSTARTTLS", tFlag, .tAnswer)
        Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer) _ "|" _ ..VendorValue("UseSTARTTLS"), "200|matches|" _ tFlag, "UseSTARTTLS " _ tFlag _ ": the screen's Set value stores it as the vendor reads it: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    }
    Set tTwoLines = "Task #(NAME)# ran." _ $Char(13, 10) _ "Status: #(SUCCESS)#"
    Set tStatus = ..Act("MessageSuccess", tTwoLines, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer) _ "|" _ (..VendorValue("MessageSuccess") = tTwoLines), "200|matches|1", "MessageSuccess: a two-line text is stored as sent: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Set tLong = $Translate($Justify("", 32000), " ", "x")
    Set tOutcome = ..Agent("MessageFailure", tLong, .tResult, .tProposal)
    Do $$$AssertEquals(tOutcome _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult) _ "|" _ $Length(..VendorValue("MessageFailure")) _ "|" _ (..VendorValue("MessageFailure") = tLong), "200 |matches|32000|1", "MessageFailure: the agent's text at the cap is stored whole: " _ tOutcome)
}

/// <p><b>AC2.</b> The screen's Set value and the agent's confirmed proposal change exactly <code>Port</code> and a subject, on both callers, each
/// with a read-back reading <code>matches</code>, every other setting reading as before and the mail password untouched; an empty port is accepted
/// and clears it, and the vendor wrote a configuration-change audit row for the port.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>SendNode</code> sends no <code>EmailSet</code> for the mail endpoint -> the
/// value assertions go red.</p>
Method TestASetChangesOnlyItsSettingOnBothCallersAndIsRestored()
{
    Set tFound = ..ValueOf("Port")
    Set tPassword = ##class(OcuPilot.Test.TaskMailAuditMask).Stored()
    Set tBefore = ..Snapshot()
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tScreenPort = $Select(tFound = 587: 588, 1: 587)
    Set tStatus = ..Act("Port", tScreenPort, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer) _ "|" _ ..ValueOf("Port"), "200|matches|" _ tScreenPort, "Port: the screen's Set value changes it and reads it back: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals(..Without(..Snapshot(), "Port"), ..Without(tBefore, "Port"), "Port: every other setting reads as before")
    Do $$$AssertTrue($ClassMethod("OcuPilot.Test.AuditVendorSecrets", "VendorCarries", tSince, tScreenPort, ..#EVENT) >= 1, "and the vendor wrote a configuration-change row that carries the new port")
    Set tSubject = "Task #(NAME)# #(SUCCESS)#"
    Set tStatus = ..Act("SubjectSuccess", tSubject, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer) _ "|" _ ..ValueOf("SubjectSuccess"), "200|matches|" _ tSubject, "SubjectSuccess: the screen's Set value changes it and reads it back")
    Set tOutcome = ..Agent("Port", ..OtherPort(tFound), .tResult, .tProposal)
    Do $$$AssertEquals(tOutcome _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult) _ "|" _ ..ValueOf("Port"), "200 |matches|" _ ..OtherPort(tFound), "Port: the agent's confirmed proposal changes it: " _ tOutcome)
    Do $$$AssertEquals(##class(OcuPilot.Test.EcpSettingsWrite).Consequence(tProposal), "", "and its card states no consequence")
    Set tOutcome = ..Agent("SubjectFailure", "Failed: #(NAME)# #(ERROR)#", .tResult, .tProposal)
    Do $$$AssertEquals(tOutcome _ "|" _ ..ValueOf("SubjectFailure"), "200 |Failed: #(NAME)# #(ERROR)#", "SubjectFailure: the agent's confirmed proposal changes it")
    Set tStatus = ..Act("Port", "", .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..ValueOf("Port"), "200|", "an empty port is accepted and clears it")
    Do $$$AssertEquals(##class(OcuPilot.Test.TaskMailAuditMask).Stored(), tPassword, "and the mail password reads as before")
}

/// <p><b>AC2.</b> A set that is refused changes nothing: at the screen's route a port out of range or a value the kind refuses is 400
/// <code>CONFIG.SETTING.VALUE</code>, a field the Task Manager does not fill in 400 <code>CONFIG.SETTING.SUBSTITUTION</code>, and the mail password or
/// another unlisted name 404 <code>CONFIG.SETTING.NOTFOUND</code>; at the mint each is refused with its sentence. Every setting and the mail password
/// read as before.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Area.OsMgmt.ConfigSettingRules</class>'s <code>TaskMailCode</code> drops the port-range rule -> the
/// <code>65536</code> row and the mint's refusal go red.</p>
Method TestARefusedSetChangesNothingOnEitherCaller()
{
    Set tBefore = ..Snapshot().%ToJSON()
    Set tPassword = ##class(OcuPilot.Test.TaskMailAuditMask).Stored()
    For tCase = $ListBuild("Port", "65536", "400|CONFIG.SETTING.VALUE"), $ListBuild("Port", "abc", "400|CONFIG.SETTING.VALUE"), $ListBuild("UseSTARTTLS", "2", "400|CONFIG.SETTING.VALUE"), $ListBuild("Server", $Translate($Justify("", 256), " ", "a"), "400|CONFIG.SETTING.VALUE"), $ListBuild("SubjectSuccess", "#(BOGUS)#", "400|CONFIG.SETTING.SUBSTITUTION"), $ListBuild("MessageFailure", "x #(NAME)# #(TASK)#", "400|CONFIG.SETTING.SUBSTITUTION"), $ListBuild("AuthPassword", "x", "404|CONFIG.SETTING.NOTFOUND"), $ListBuild("MailPort", "587", "404|CONFIG.SETTING.NOTFOUND") {
        Set tStatus = ..Act($List(tCase, 1), $List(tCase, 2), .tAnswer)
        Do $$$AssertEquals(tStatus _ "|" _ ..Code(tAnswer), $List(tCase, 3), $List(tCase, 1) _ " is refused at the screen")
    }
    Do $$$AssertEquals(..Agent("Port", "65536", .tResult, .tProposal), "refused: This setting does not accept that value.", "a port out of range is refused at the mint")
    Do $$$AssertEquals(..Agent("SubjectFailure", "#(BOGUS)#", .tResult, .tProposal), "refused: " _ ##class(OcuPilot.Api.ConfigError).ReasonFor("CONFIG.SETTING.SUBSTITUTION"), "a field the Task Manager does not fill in is refused at the mint, naming the fields")
    Do $$$AssertEquals(..Agent("AuthPassword", "x", .tResult, .tProposal), "refused: 'AuthPassword' is not present on this instance", "the mail password is refused at the mint, which reads the target first")
    Do $$$AssertEquals(..Snapshot().%ToJSON(), tBefore, "and every setting reads as before")
    Do $$$AssertEquals(##class(OcuPilot.Test.TaskMailAuditMask).Stored(), tPassword, "and so does the mail password")
}

/// <p><b>AC2, AD-58.</b> A write the vendor did not store reads back as different: with the confirm's port the recording seam, whose write is
/// recorded and sent nowhere, the agent's confirm of a new port answers a read-back reading <code>differs</code> and the instance still holds the
/// old port.</p>
/// <p>Mutation (Rule 19): <code>ConfigSettingSet</code> declares no read-back field -> the verdict assertion goes red.</p>
Method TestAWriteTheVendorDidNotStoreReadsBackDifferent()
{
    Set tFound = ..ValueOf("Port")
    Set tNew = ..OtherPort(tFound)
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "WRITE")
    Set ^||OcuPilotDatabaseWritePort = ..#SEAM
    Set tOutcome = ..Agent("Port", tNew, .tResult, .tProposal)
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Modifies"), "TaskMail|Port|" _ tNew, "the write was made once")
    Do $$$AssertEquals($ClassMethod(..#VERDICT, "Verdict", tResult), "differs", "and its read-back reads differs, since nothing was stored: " _ tOutcome)
    Do $$$AssertEquals(..ValueOf("Port"), tFound, "the instance holds the old port")
}

/// <p><b>AC2, AC6.</b> With the key at its baseline the agent's call is dispatched, mints a proposal and its confirm changes the setting once, with a
/// read-back and one write-kind ledger row carrying the audit marker; the proposal's token is spent, so a second confirm is refused and changes nothing
/// more. With the key stored disabled the same call is refused at dispatch, while a person's Set value is not governed and still changes it (AD-22).</p>
/// <p>Mutation (Rule 19): the <code>tasks.mail.set</code> line removed from <class>OcuPilot.Kernel.Governance.Baseline</class> -> the first dispatch is
/// refused and this goes red.</p>
Method TestTheAgentsConfirmWritesOnceWithOneAuditMarkerAndADisabledKeyRefusesIt()
{
    Set tFound = ..ValueOf("Port")
    Set tNew = ..OtherPort(tFound)
    Set tInput = {"Name": "Port", "rationale": "probe", "expectedImpact": "probe"}
    Do tInput.%Set("Value", tNew _ "", "string")
    Do $$$AssertEquals(..Dispatched(..#KEY, tInput, .tProposalId, .tTurnKey) _ "|" _ (tProposalId '= ""), "minted|1", "the baseline lets the call mint a proposal")
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tProposalId, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ $Get(tCode) _ "|" _ ..ValueOf("Port") _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult), "1||" _ tNew _ "|matches", "its confirm changes the port, with a read-back: " _ $Get(tCode))
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tRow), 1, "one write-kind ledger row records it")
    Do $$$AssertEquals($Get(tRow("AuditMarked")), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "and the agent's audit marker landed on it")
    Do $$$AssertStatusOK(..Restore(##class(%DynamicObject).%FromJSON(..PreparedSettings)), "the port is put back")
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tProposalId, "", $Username, .tResult2, .tHttp2, .tCode2, .tDetail2)
    Do $$$AssertEquals($$$ISERR(tSC) _ "|" _ ..ValueOf("Port"), "1|" _ tFound, "a second confirm of the same proposal is refused and changes nothing")
    Kill tSettings
    Set tSettings(..#KEY) = "disabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the key is stored disabled")
    Do $$$AssertEquals(..Dispatched(..#KEY, tInput, .tNone), "refused", "and the same call is refused at dispatch")
    Set tStatus = ..Act("Port", tNew, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..ValueOf("Port"), "200|" _ tNew, "while a person's Set value is not governed and still changes it")
}

/// <p>The agent's dispatch of <var>pKey</var> with <var>pInput</var>: <code>minted</code> with the proposal id in <var>pProposalId</var> and the turn's key
/// in <var>pTurnKey</var>, or <code>refused</code>.</p>
ClassMethod Dispatched(pKey As %String, pInput As %DynamicObject, Output pProposalId As %String, Output pTurnKey As %String) As %String
{
    Set pProposalId = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Set pTurnKey = $Get(tTurnKey)
    If $$$ISERR(tSC) Quit "no turn"
    Set tUse = {"type": "tool_use", "id": "toolu_taskmail"}
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
