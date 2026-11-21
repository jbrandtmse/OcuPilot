/// <p>Pins Story 21.36's Task Manager mail password on both callers (AC2, AC3; AD-6, AD-22, AD-35, AD-56 (i), AD-58, AD-59): the screen's Set mail password through its own action
/// route (<class>OcuPilot.Test.EcpActionFixture</class>) and the agent's mint and confirm (<class>OcuPilot.Test.LicenseProbe</class>), against the real instance. Each caller
/// stores a generated probe, which the vendor's own <code>EmailGet</code> reads back equal in process (the answer is 1 or 0 and no failure text holds a value); an empty password clears it;
/// the read-back reports it written; the probe is in no answer, read, screen context, copy-out draft, proposal row, ledger row, OcuPilot audit row or log line; a target other than the
/// sign-in name and a caller short of a pair change nothing; and the baseline ships the key enabled while a disabled key refuses the agent and not a person.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class changes the Task
/// Manager's mail password and sets the governance policy. It holds the stored password before each test and puts it back after, and removes a stored row the run created. It never
/// waits for the vendor's own audit row, which the vendor writes about a minute after a change.</p>
Class OcuPilot.Test.TaskMailPasswordWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the writes, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_CONFIG_SETTINGS";

Parameter PORT = "OcuPilot.Port.ConfigPort";

Parameter SEAM = "OcuPilot.Test.ConfigGateSeam";

Parameter ACTION = "OcuPilot.Test.EcpActionFixture";

/// <p>The class whose <code>Verdict</code> and <code>Parsed</code> read an action's answer.</p>
Parameter VERDICT = "OcuPilot.Test.EcpDataServerWrite";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

/// <p>The sibling whose <code>Dispatched</code> sends one tool call through the agent's dispatch.</p>
Parameter DISPATCH = "OcuPilot.Test.TaskMailSettingWrite";

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.TaskMailSettingList";

Parameter TOOL = "OcuPilot.Screen.Tool.TaskMailPassword";

Parameter KEY = "tasks.mail.password";

Parameter SCREEN = "tasks.mail";

Parameter ENDPOINT = "TaskMail";

/// <p>The one target the write names, and the secret's name.</p>
Parameter TARGET = "AuthUser";

Parameter SECRETNAME = "AuthPassword";

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

/// <p>Whether <method>OnBeforeAllTests</method> took the policy snapshot; every teardown restores only then.</p>
Property PreparedPolicyTaken As %Boolean [ InitialExpression = 0 ];

/// <p>The stored password row as the vendor keeps it, held before each test and written back after it. It is never printed or compared in a message.</p>
Property PreparedPassword As %String(MAXLEN = "") [ InitialExpression = "" ];

/// <p>Whether the stored password row existed before the class ran.</p>
Property PreparedRowExisted As %Boolean [ InitialExpression = 0 ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.TaskMailPasswordWrite changes this instance's Task Manager mail password and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set ..PreparedPolicyTaken = 1
    Set ..PreparedRowExisted = ..RowExists()
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    ; The confirm fixture's port is the shipped config port, so the confirm writes the instance.
    Set ^||OcuPilotDatabaseWritePort = ..#PORT
    Set ..PreparedPassword = ##class(OcuPilot.Test.TaskMailAuditMask).Stored()
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
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TaskMailAuditMask).Store(..PreparedPassword), "the stored password is put back")
    Do $$$AssertTrue(##class(OcuPilot.Test.TaskMailAuditMask).Stored() = ..PreparedPassword, "and reads as it did before the test")
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
    If '..PreparedRowExisted Do ..RemoveCreatedRow()
    Kill tRows
    Merge tRows = ..PreparedPolicy
    Quit ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
}

/// <p>Whether the vendor holds a stored row for the mail password, read in <code>%SYS</code>.</p>
ClassMethod RowExists() As %Boolean
{
    Set tFound = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM %SYS_Task.Config WHERE ParamName = ?", "MailAuthPassword")
        Set tFound = tRS.%Next() && (tRS.%GetData(1) > 0)
    } Catch {
        Set tFound = 0
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tFound
}

/// <p>Delete the stored password row when it holds nothing, so the instance holds what it held before the run.</p>
ClassMethod RemoveCreatedRow()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "DELETE FROM %SYS_Task.Config WHERE ParamName = ? AND (Data IS NULL OR Data = '')", "MailAuthPassword")
    } Catch {
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
}

/// <p>A generated probe no other text holds.</p>
ClassMethod Probe() As %String
{
    Quit "OcuPwd" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(12)), "+/=", "xyz")
}

/// <p>Whether the vendor's own <code>EmailGet</code> answers <var>pExpected</var> for the password, compared in process: 1 or 0, and no text that holds either value.</p>
ClassMethod Reads(pExpected As %String) As %Boolean
{
    Set tSame = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(%SYS.Task.Config).EmailGet(..#SECRETNAME, .tRead)
        Set tSame = $$$ISOK(tSC) && ($Get(tRead) = pExpected)
    } Catch {
        Set tSame = 0
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tSame
}

/// <p>The screen action <code>password</code> on <var>pName</var> with the value <var>pValue</var>, through the action fixture; the answer's parsed envelope in
/// <var>pAnswer</var> and its text in <var>pJson</var>, answering the HTTP status.</p>
ClassMethod Act(pName As %String, pValue As %String, Output pAnswer As %DynamicObject, Output pJson As %String) As %Integer
{
    Set tBody = {"action": "password"}
    Do tBody.%Set("id", pName, "string")
    Set tValues = {}
    Do tValues.%Set(..#SECRETNAME, pValue, "string")
    Do tBody.%Set("values", tValues)
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, tBody, .pJson, .tStatus)
    Set pAnswer = $ClassMethod(..#VERDICT, "Parsed", pJson)
    Quit tStatus
}

/// <p>The read-back verdict an answer carries.</p>
ClassMethod Verdict(pAnswer) As %String
{
    Quit $ClassMethod(..#VERDICT, "Verdict", pAnswer)
}

/// <p>The refusal code an answer carries, or <code>""</code>.</p>
ClassMethod Code(pAnswer As %DynamicObject) As %String
{
    Quit $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The text of <var>pObject</var> as JSON, or <code>""</code>.</p>
ClassMethod Text(pObject) As %String
{
    Quit $Select($IsObject($Get(pObject)): pObject.%ToJSON(), 1: "")
}

/// <p>Whether any column of any row of the table <var>pTable</var> holds <var>pProbe</var>: 1 or 0, and -1 when the table cannot be read, which no assertion accepts as clean.</p>
ClassMethod TableCarries(pTable As %String, pProbe As %String) As %Integer
{
    Set tFound = 0
    Try {
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT * FROM " _ pTable)
        If tRS.%SQLCODE < 0 {
            Set tFound = -1
            Quit
        }
        While 'tFound && tRS.%Next() {
            For tAt = 1:1:tRS.%ResultColumnCount {
                If tRS.%GetData(tAt) [ pProbe {
                    Set tFound = 1
                    Quit
                }
            }
        }
    } Catch {
        Set tFound = -1
    }
    Quit tFound
}

/// <p>Whether any OcuPilot audit row recorded since <var>pSince</var> carries <var>pProbe</var> in its data or description: 1 or 0, and -1 when the audit cannot be read.</p>
ClassMethod AuditCarries(pSince As %String, pProbe As %String) As %Integer
{
    Set tFound = 0
    Set tSource = ##class(OcuPilot.Kernel.Audit.Event).Source()
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%SQL.Statement).%ExecDirect(, "SELECT EventData, Description FROM %SYS.Audit WHERE UTCTimeStamp >= ? AND %NOINDEX EventSource = ?", pSince, tSource)
        If tRS.%SQLCODE < 0 {
            Set tFound = -1
        } Else {
            While 'tFound && tRS.%Next() {
                If (tRS.%Get("EventData") [ pProbe) || (tRS.%Get("Description") [ pProbe) Set tFound = 1
            }
        }
    } Catch {
        Set tFound = -1
    }
    If $NAMESPACE '= tOrigNS Set $NAMESPACE = tOrigNS
    Quit tFound
}

/// <p>Every read of the Task Manager email screen as one text: the screen's read, the same rows as the agent's read tool answers them, the fresh read of the sign-in name, the screen context
/// built over those rows, and the tools the screen lists. <var>pRead</var> is 1 when the screen's read answered.</p>
ClassMethod ReadsText(Output pRead As %Boolean) As %String
{
    Set pRead = 0
    Set tResult = ##class(OcuPilot.Test.TaskMailSettingRead).Read(.tHttp, .tFault)
    If '$IsObject(tResult) Quit ""
    Set pRead = 1
    Set tText = tResult.%ToJSON()
    Kill tQuery
    Set tQuery("name") = ..#TARGET
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, "GET", .tQuery, "", .tRow, .tRowHttp, .tRowFault)
    Set tText = tText _ ..Text($Get(tRow))
    Set tContext = {"route": "tasks/email", "view": {}}
    Do tContext.%Set("namespace", $Namespace, "string")
    Do tContext.view.%Set("rows", tResult.%Get("rows"))
    Set tSC = ##class(OcuPilot.Screen.Context).Build(tContext, .tBuilt, .tPayload, .tFieldMax, .tDropped)
    Set tText = tText _ ..Text($Get(tPayload))
    Set tSC = ##class(OcuPilot.Screen.Context).ScreenTools(..#DESCRIPTOR, .tTools, .tList)
    Quit tText _ ..Text($Get(tTools))
}

/// <p>The one <code>changed</code> row a minted proposal shows, as <code>field|before|after</code>, or <code>""</code>.</p>
ClassMethod CardRow(pProposal As %DynamicObject) As %String
{
    If '$IsObject(pProposal) || (pProposal.%GetTypeOf("changed") '= "array") || (pProposal.%Get("changed").%Size() '= 1) Quit ""
    Set tRow = pProposal.%Get("changed").%Get(0)
    Quit tRow.%Get("field") _ "|" _ tRow.%Get("before") _ "|" _ tRow.%Get("after")
}

/// <p><b>AC2.</b> Both callers set the password and neither surfaces it. The person's Set mail password stores a probe, which the vendor's <code>EmailGet</code> reads equal, and its
/// read-back reports it written; the agent's proposal shows one masked row with no value, its copy-out script renders <code>EmailSet</code> with the placeholder, and its confirm with a
/// second probe stores that one. Neither probe is in any answer, read, screen context, script, stored proposal, ledger row, OcuPilot audit row, or line of <code>messages.log</code> and
/// <code>alerts.log</code>.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Port.ConfigPort</class>'s <code>SetPassword</code> sends <code>""</code> in place of the body's value -> the two <code>EmailGet</code> legs go red.</p>
Method TestThePasswordIsSetByBothCallersAndSurfacesNowhere()
{
    Set tProbeA = ..Probe()
    Set tProbeB = ..Probe()
    Set tMessages = ##class(OcuPilot.Test.EncryptionProbe).LineCount("messages.log")
    Set tAlerts = ##class(OcuPilot.Test.EncryptionProbe).LineCount("alerts.log")
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tStatus = ..Act(..#TARGET, tProbeA, .tAnswer, .tJson)
    Set tAnswers = tJson
    Do $$$AssertEquals(tStatus _ "|" _ ..Verdict(tAnswer) _ "|" _ ..Reads(tProbeA), "200|written|1", "the person's Set mail password stores it and reports it written, and EmailGet reads the probe equal")
    Set tTexts = ..ReadsText(.tRead)
    Do $$$AssertTrue(tRead, "the screen's read answers")
    Set tAnswers = tAnswers _ tTexts
    Do $$$AssertEquals(##class(OcuPilot.Test.TaskMailSettingRead).RowsByName(##class(OcuPilot.Test.TaskMailSettingRead).Read(), .tRows), 12, "the read still answers the twelve settings, none of them the password")

    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#TOOL, ..#TARGET, {"Name": (..#TARGET)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's proposal is minted (" _ tProblem _ ")")
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertEquals(..CardRow(tProposal), ..#SECRETNAME _ "||", "its one row names the secret and carries no value")
    Set tDraft = ##class(OcuPilot.Test.EncryptionKeyWrite).Draft(tProposal, .tSteps)
    Do $$$AssertTrue((tDraft [ "<" _ ..#SECRETNAME _ ">") && (tDraft [ "EmailSet"), "its copy-out script renders EmailSet with the placeholder")
    Do $$$AssertTrue((tDraft '[ tProbeA) && (tDraft '[ tProbeB), "and holds neither probe")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#TOOL, ..#TARGET, {"Name": (..#TARGET)}, .tProposal, .tHttp, .tProblem)
    If '$IsObject($Get(tProposal)) Quit
    Set tSecrets = {}
    Do tSecrets.%Set(..#SECRETNAME, tProbeB, "string")
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tProposal.%Get("proposalId"), tSecrets, $Username, .tResult, .tConfirmHttp, .tCode, .tDetail)
    Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ $Get(tCode) _ "|" _ ..Verdict($Get(tResult)) _ "|" _ ..Reads(tProbeB), "1||written|1", "the confirm with the second probe stores it and reads back written: " _ $Get(tCode))
    Set tAnswers = tAnswers _ tDraft _ tProposal.%ToJSON() _ ..Text($Get(tResult)) _ ..Text($Get(tDetail))
    Set tStored = ##class(OcuPilot.Test.EncryptionKeyFileWrite).StoredText(tProposal.%Get("proposalId"))
    Do $$$AssertTrue(tStored '= "", "the stored proposal row was read")
    Set tAfter = ..ReadsText(.tReadAfter)
    Set tAnswers = tAnswers _ tAfter _ tStored

    Set tControl = "OCUPROBE2136 log control " _ $ZTimeStamp
    Do ##class(%SYS.System).WriteToConsoleLog(tControl, 0, 0)
    Set tLines = ##class(OcuPilot.Test.EncryptionProbe).LinesAfter("messages.log", tMessages).%ToJSON() _ ##class(OcuPilot.Test.EncryptionProbe).LinesAfter("alerts.log", tAlerts).%ToJSON()
    Do $$$AssertTrue(tLines [ tControl, "the log scan reads the lines written since the test began")
    For tProbe = tProbeA, tProbeB {
        Do $$$AssertTrue(tAnswers '[ tProbe, "the probe is in no answer, read, screen context, script or stored proposal")
        Do $$$AssertTrue(tLines '[ tProbe, "nor in messages.log or alerts.log")
        Do $$$AssertEquals(..TableCarries("OcuPilot_Kernel_State.Proposal", tProbe), 0, "nor in any proposal row")
        Do $$$AssertEquals(..TableCarries("OcuPilot_Kernel_State.Ledger", tProbe), 0, "nor in any ledger row")
        Do $$$AssertEquals(..AuditCarries(tSince, tProbe), 0, "nor in any OcuPilot audit row")
    }
}

/// <p><b>AC2.</b> An empty password clears the stored one on both callers, and a target other than the sign-in name is refused at the screen and at the confirm and changes nothing. A password
/// set first reads back equal; the person's empty value then reads empty; the agent's confirm with an empty secret clears a second one; a refused action on <code>Server</code> answers
/// 404 <code>CONFIG.SETTING.NOTFOUND</code>, and a proposal minted for <code>Server</code> is refused at the confirm, each leaving the stored password as it was.</p>
/// <p>Mutation (Rule 19): <code>CLEARABLESECRETS</code> emptied in <class>OcuPilot.Screen.Tool.TaskMailPassword</class> -> the person's and the agent's clear legs go red.</p>
Method TestAnEmptyPasswordClearsItAndAnotherTargetIsRefused()
{
    Set tProbe = ..Probe()
    Do $$$AssertEquals(..Act(..#TARGET, tProbe, .tAnswer) _ "|" _ ..Reads(tProbe), "200|1", "a password is stored first")
    Set tStatus = ..Act("Server", ..Probe(), .tRefused)
    Do $$$AssertEquals(tStatus _ "|" _ ..Code(tRefused) _ "|" _ ..Reads(tProbe), "404|CONFIG.SETTING.NOTFOUND|1", "a target other than the sign-in name is refused at the screen and the stored password is as it was")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#TOOL, "Server", {"Name": "Server"}, .tOther, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "a proposal for another target is minted, so the confirm leg below is reached (" _ tProblem _ ")")
    If $IsObject($Get(tOther)) {
        Set tSecrets = {}
        Do tSecrets.%Set(..#SECRETNAME, ..Probe(), "string")
        Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tOther.%Get("proposalId"), tSecrets, $Username, .tResult, .tConfirmHttp, .tCode, .tDetail)
        Do $$$AssertEquals($$$ISERR(tSC) _ "|" _ ..Reads(tProbe), "1|1", "a proposal minted for another target is refused at the confirm and changes nothing")
    }
    Set tStatus = ..Act(..#TARGET, "", .tCleared)
    Do $$$AssertEquals(tStatus _ "|" _ ..Verdict(tCleared) _ "|" _ ..Reads(""), "200|written|1", "the person's empty value clears it")
    Set tProbeB = ..Probe()
    Do $$$AssertEquals(..Act(..#TARGET, tProbeB) _ "|" _ ..Reads(tProbeB), "200|1", "a second password is stored")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#TOOL, ..#TARGET, {"Name": (..#TARGET)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's proposal is minted (" _ tProblem _ ")")
    If '$IsObject($Get(tProposal)) Quit
    Set tEmpty = {}
    Do tEmpty.%Set(..#SECRETNAME, "", "string")
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tProposal.%Get("proposalId"), tEmpty, $Username, .tResult, .tConfirmHttp, .tCode, .tDetail)
    Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ $Get(tCode) _ "|" _ ..Reads(""), "1||1", "the agent's confirm with an empty secret clears it: " _ $Get(tCode))
}

/// <p><b>AC2.</b> A body that is not an object holding a string <code>AuthPassword</code> is refused 400 <code>PORT.VALIDATION</code> at the port and the stored password is as it was:
/// a missing value, a number and a non-object body each leave the probe stored.</p>
/// <p>Mutation (Rule 19): the body-shape test removed from <method>OcuPilot.Port.ConfigPort.SetPassword</method> -> the missing-value leg clears the stored password and this goes red.</p>
Method TestAMalformedBodyIsRefusedAndClearsNothing()
{
    Set tProbe = ..Probe()
    Do $$$AssertEquals(..Act(..#TARGET, tProbe) _ "|" _ ..Reads(tProbe), "200|1", "a password is stored first")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "WRITE")
    Kill tQuery
    Set tQuery("name") = ..#TARGET
    For tShape = "missing", "number", "text" {
        Set tBody = $Case(tShape, "missing": {}, "number": {"AuthPassword": 5}, : "plain text")
        Set tSC = $ClassMethod(..#SEAM, "Invoke", ..#ENDPOINT, "PASSWORD", .tQuery, tBody, .tOut, .tHttp, .tFault)
        Set tCode = $Select($IsObject(tFault): tFault.%Get("code"), 1: "")
        Do $$$AssertEquals(tHttp _ "|" _ tCode _ "|" _ ..Reads(tProbe), "400|PORT.VALIDATION|1", "a " _ tShape _ " body is refused and the stored password is as it was")
    }
}

/// <p><b>AC3.</b> The baseline ships the key enabled, so with none stored the agent's call mints a proposal and its confirm stores the password once; a second confirm of the same proposal
/// is refused. With the key stored disabled the same call is refused at dispatch while a person's Set mail password is not governed and still stores one.</p>
/// <p>Mutation (Rule 19): the <code>tasks.mail.password</code> line removed from <class>OcuPilot.Kernel.Governance.Baseline</class> -> the first dispatch is refused and this goes red.</p>
Method TestTheKeyShipsEnabledAndADisabledKeyRefusesTheAgentAndNotAPerson()
{
    Do $$$AssertEquals(##class(OcuPilot.Test.Governance).Resolved(..#KEY), "1|baseline", ..#KEY _ " ships enabled by the baseline")
    Set tInput = {"Name": (..#TARGET), "rationale": "probe", "expectedImpact": "probe"}
    Do $$$AssertEquals($ClassMethod(..#DISPATCH, "Dispatched", ..#KEY, tInput, .tProposalId, .tTurnKey) _ "|" _ (tProposalId '= ""), "minted|1", "the baseline lets the call mint a proposal")
    Set tProbe = ..Probe()
    Set tSecrets = {}
    Do tSecrets.%Set(..#SECRETNAME, tProbe, "string")
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tProposalId, tSecrets, $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ $Get(tCode) _ "|" _ ..Reads(tProbe), "1||1", "its confirm stores the password: " _ $Get(tCode))
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tRow), 1, "one write-kind ledger row records it")
    Do $$$AssertTrue(##class(OcuPilot.Test.TaskMailAuditMask).Stored() '= "", "and the vendor holds a stored password")
    Do $$$AssertStatusOK(##class(OcuPilot.Test.TaskMailAuditMask).Store(..PreparedPassword), "the stored password is put back")
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tProposalId, tSecrets, $Username, .tResult2, .tHttp2, .tCode2, .tDetail2)
    Do $$$AssertEquals($$$ISERR(tSC) _ "|" _ ..Reads(tProbe), "1|0", "a second confirm of the same proposal is refused and stores nothing more")
    Kill tSettings
    Set tSettings(..#KEY) = "disabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the key is stored disabled")
    Do $$$AssertEquals($ClassMethod(..#DISPATCH, "Dispatched", ..#KEY, tInput, .tNone), "refused", "and the same call is refused at dispatch")
    Set tPerson = ..Probe()
    Do $$$AssertEquals(..Act(..#TARGET, tPerson) _ "|" _ ..Reads(tPerson), "200|1", "while a person's Set mail password is not governed and still stores one")
}

/// <p><b>AC2, AD-8.</b> The tool's pairs are exactly <class>OcuPilot.Screen.Tool.TaskMailSettingSet</class>'s, and the port refuses a caller short of one before the vendor is reached: a caller
/// holding nothing is refused the first read pair, one holding the read pairs the write pair, and the stored password reads as it did.</p>
/// <p>Mutation (Rule 19): <class>OcuPilot.Screen.Tool.TaskMailPassword</class>'s <code>PrivilegePairs</code> answers the screen's pairs alone -> the pair-list leg goes red.</p>
Method TestThePairsAreTheSettingSetsAndAShortCallerIsRefusedBeforeTheVendor()
{
    Set tPairs = $ClassMethod(..#TOOL, "PrivilegePairs", "", .tResolved)
    Set tSet = ##class(OcuPilot.Screen.Tool.TaskMailSettingSet).PrivilegePairs("", .tSetResolved)
    Do $$$AssertTrue(tResolved && tSetResolved && (tPairs = tSet) && ($ListFind(tPairs, $ListBuild("%DB_IRISSYS", "WRITE")) > 0) && ($ListFind(tPairs, $ListBuild("%Admin_Manage", "USE")) > 0), "the tool requires the setting set's pairs, the write pair and %Admin_Manage:USE among them")
    Kill tQuery
    Set tQuery("name") = ..#TARGET
    Set tBody = {}
    Do tBody.%Set(..#SECRETNAME, ..Probe(), "string")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", ..#ENDPOINT, "PASSWORD", .tQuery, tBody, .tOut, .tHttp, .tFault)
    Set tFailed = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
    Do $$$AssertEquals(tHttp _ "|" _ tFailed, "403|%Admin_Manage:USE", "a caller holding nothing is refused the first pair")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", ..#ENDPOINT, "PASSWORD", .tQuery, tBody, .tOut, .tHttp, .tFault)
    Set tFailed = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.%Get("failedPair"), 1: "")
    Do $$$AssertEquals(tHttp _ "|" _ tFailed, "403|%DB_IRISSYS:WRITE", "a caller holding the read pairs is refused the write pair")
    Do $$$AssertTrue(##class(OcuPilot.Test.TaskMailAuditMask).Stored() = ..PreparedPassword, "and nothing reached the vendor")
    Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", ..#ENDPOINT, "PASSWORD") _ "|" _ $ClassMethod(..#PORT, "SnippetForm", "Startup", "PASSWORD"), "objectscript|", "the password write has a script form on the email endpoint and no other")
}

}
