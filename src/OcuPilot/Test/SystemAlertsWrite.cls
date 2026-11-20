/// <p>Pins Story 21.20's alert reset on both callers (AC4, AC5; AD-23, AD-51, AD-53, AD-58): System alerts' Reset alerts action
/// through <class>OcuPilot.Test.EcpActionFixture</class> and the agent's mint and confirm of <code>osmgmt.systemalerts.reset</code>,
/// each running the harvested body for real. After a reset the alert count reads 0 and the state OK, and <code>alerts.log</code>
/// holds every line it held before; with the key disabled the governance gate refuses the agent's call.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and <parameter>ARMINGVARIABLE</parameter> reading
/// <code>1</code>, because the class sets the instance's system state and resets its alerts. The state a test found is not put
/// back: a reset is not undoable, and the throwaway's own monitor raises it again.</p>
Class OcuPilot.Test.SystemAlertsWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the alert reset, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_ALERT_RESET";

Parameter PORT = "OcuPilot.Port.MonitorPort";

Parameter ACTION = "OcuPilot.Test.EcpActionFixture";

Parameter VERDICT = "OcuPilot.Test.EcpDataServerWrite";

Parameter SCREEN = "osmgmt.systemalerts";

Parameter TOOL = "osmgmt.systemalerts.reset";

/// <p>The governance policy as it stood before the test ran.</p>
Property PreparedPolicy [ MultiDimensional ];

Property PreparedPolicyTaken As %Boolean [ InitialExpression = 0 ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SystemAlertsWrite sets the instance's system state and resets its alerts and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    ; The confirm fixture's port is the shipped monitor port, so the confirm resets the instance's own alerts.
    Set ^||OcuPilotDatabaseWritePort = ..#PORT
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Kill ..PreparedPolicy
    Merge ..PreparedPolicy = tRows
    Set ..PreparedPolicyTaken = 1
    Quit ##class(OcuPilot.Test.GovernanceFixture).Clear()
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    If ..PreparedPolicyTaken {
        Kill tRows
        Merge tRows = ..PreparedPolicy
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
        Set ..PreparedPolicyTaken = 0
    }
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

/// <p>Put the instance in the system state <var>pState</var> (an alert state by default):
/// <code>%SYSTEM.Monitor.SetState</code>, in <code>%SYS</code>.</p>
ClassMethod Arrange(pState As %Integer = 2)
{
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = "%SYS"
    Do $SYSTEM.Monitor.SetState(pState)
    Set $NAMESPACE = tOrigNS
}

/// <p>How many agent-write markers the audit database holds since <var>pSince</var>, whichever proposal they name.</p>
ClassMethod AgentMarkers(pSince As %String) As %Integer
{
    Quit ##class(OcuPilot.Test.AuditMarker).MarkerRows(pSince, """proposalId"":""", .tData)
}

/// <p>The instance's own alert state, read in <code>%SYS</code>: <code>State|AlertCount</code>.</p>
ClassMethod State() As %String
{
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = "%SYS"
    Set tText = $SYSTEM.Monitor.State() _ "|" _ $SYSTEM.Monitor.Alerts()
    Set $NAMESPACE = tOrigNS
    Quit tText
}

/// <p>How many lines <code>alerts.log</code> holds, or <code>-1</code> when the instance has none.</p>
ClassMethod LogLines() As %Integer
{
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = "%SYS"
    Set tFile = $ZUtil(12) _ "alerts.log"
    Set tCount = -1
    If ##class(%File).Exists(tFile) {
        Set tCount = 0
        Set tStream = ##class(%Stream.FileCharacter).%New()
        Do tStream.LinkToFile(tFile)
        While 'tStream.AtEnd {
            Do tStream.ReadLine()
            Set tCount = tCount + 1
        }
    }
    Set $NAMESPACE = tOrigNS
    Quit tCount
}

/// <p>The screen's Reset alerts on the singleton, through the action fixture; the answer's parsed envelope in
/// <var>pAnswer</var>, answering the HTTP status.</p>
ClassMethod Act(Output pAnswer As %DynamicObject) As %Integer
{
    Set tBody = {"action": "reset"}
    Do tBody.%Set("id", "SYSTEM", "string")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, tBody, .tJson, .tStatus)
    Set pAnswer = $ClassMethod(..#VERDICT, "Parsed", tJson)
    Quit tStatus
}

/// <p>The agent's dispatch of <code>osmgmt.systemalerts.reset</code> for <var>pName</var>: <code>minted</code> with the proposal id in
/// <var>pProposalId</var> and the turn's key in <var>pTurnKey</var>, or <code>refused</code>; the answer's content is in
/// <var>pContent</var>.</p>
ClassMethod Dispatched(pName As %String, Output pProposalId As %String, Output pTurnKey As %String, Output pContent As %String) As %String
{
    Set pProposalId = ""
    Set pContent = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Set pTurnKey = $Get(tTurnKey)
    If $$$ISERR(tSC) Quit "no turn"
    Set tUse = {"type": "tool_use", "id": "toolu_alerts"}
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName(..#TOOL), "string")
    Do tUse.%Set("input", {"Name": (pName), "rationale": "probe", "expectedImpact": "probe"})
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurnKey)
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurnKey, $Username, "", [(tUse)], "OcuPilot.Kernel.Agent.Limits", .tResults, .tNames, 0, 0, .tDetails)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set pContent = $Select($IsObject($Get(tResults)) && (tResults.%Size() = 1): tResults.%Get(0).%Get("content"), 1: "")
    Set tParsed = ##class(OcuPilot.Test.LicenseKey).Parsed(pContent)
    If $IsObject(tParsed) Set pProposalId = tParsed.%Get("proposalId")
    Quit $Select(pProposalId '= "": "minted", 1: "refused")
}

/// <p><b>AC4.</b> The screen's Reset alerts and the agent's confirmed reset each run the harvested body once: the state then reads
/// OK and the count 0, and <code>alerts.log</code> holds every line it held. The agent's confirm records one marker and a read-back.</p>
/// <p>Mutation (Rule 19): skip <code>$SYSTEM.Monitor.Clear()</code> in <method>OcuPilot.Port.Harvest.Alerts.AlertsManage</method> -- the
/// state legs go red.</p>
Method TestBothCallersResetTheAlerts()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tLinesBefore = ..LogLines()
    Do ..Arrange()
    Do $$$AssertEquals($Piece(..State(), "|", 1), 2, "the instance reads an alert state")
    Set tStatus = ..Act(.tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer), "200|nothingSent", "the screen's Reset alerts answers 200: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Set tAfter = ..State()
    Do $$$AssertEquals(tAfter, "0|0", "the state then reads OK and the count 0, from one read")
    Do $$$AssertTrue(..LogLines() >= tLinesBefore, "and alerts.log holds every line it held")
    Do $$$AssertEquals(..AgentMarkers(tSince), 0, "the person's reset records no agent-write marker (AD-53)")

    Do ..Arrange()
    Do $$$AssertEquals($Piece(..State(), "|", 1), 2, "the instance reads an alert state again")
    Do $$$AssertEquals(..Dispatched("SYSTEM", .tProposalId, .tTurnKey, .tContent), "minted", "the agent's call mints a proposal: " _ tContent)
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tProposalId, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ $Get(tCode) _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult), "1||nothingSent", "its confirm resets the alerts, with a read-back: " _ $Get(tCode))
    Set tAfterAgent = ..State()
    Do $$$AssertEquals(tAfterAgent, "0|0", "the state reads OK and the count 0, from one read")
    Do $$$AssertTrue(..LogLines() >= tLinesBefore, "and alerts.log still holds every line")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tRow), 1, "one write-kind ledger row records the agent's reset")
    Do $$$AssertEquals($Get(tRow("AuditMarked")), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "and the agent's audit marker landed on it")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).MarkerRows(tSince, """proposalId"":""" _ tProposalId _ """", .tData), 1, "and one agent marker names the proposal")
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tProposalId, "", $Username, .tResult2, .tHttp2, .tCode2, .tDetail2)
    Do $$$AssertEquals($$$ISERR(tSC), 1, "a second confirm of the same proposal is refused")
}

/// <p><b>AC4, AC5.</b> A confirm after the system state moved is refused, resets nothing, and leaves no agent-write marker.</p>
/// <p>Mutation (Rule 19): skip the fingerprint comparison in <method>OcuPilot.Kernel.Proposal.Confirm.FingerprintMatches</method> --
/// the refusal leg goes red.</p>
Method TestAConfirmAfterTheStateMovedIsRefusedAndResetsNothing()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do ..Arrange()
    Do $$$AssertEquals(..Dispatched("SYSTEM", .tProposalId, .tTurnKey, .tContent), "minted", "the agent's call mints a proposal while the state is Alert: " _ tContent)
    Do ..Arrange(1)
    Do $$$AssertEquals($Piece(..State(), "|", 1), 1, "the state then moves to Warning")
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tProposalId, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals($$$ISERR(tSC), 1, "the confirm is refused: " _ $Get(tCode))
    Do $$$AssertEquals($Piece(..State(), "|", 1), 1, "nothing was reset")
    Do $$$AssertEquals(..AgentMarkers(tSince), 0, "and no agent-write marker was recorded")
    Do ..Arrange(0)
}

/// <p><b>AC5.</b> At the default baseline the agent's call mints; with the key disabled the governance gate refuses the same call
/// and a target other than <code>SYSTEM</code> is refused at the mint.</p>
/// <p>Mutation (Rule 19): <code>osmgmt.systemalerts.reset</code> is <code>false</code> in
/// <class>OcuPilot.Kernel.Governance.Baseline</class> -- the default leg goes red.</p>
Method TestTheKeyGovernsTheReset()
{
    Do $$$AssertEquals(..Dispatched("SYSTEM", .tProposalId, .tTurnKey, .tContent), "minted", "the default baseline mints the proposal: " _ tContent)
    Do $$$AssertEquals(..Dispatched("OTHER", .tOtherId, .tOtherKey, .tOtherContent), "refused", "a target other than SYSTEM is refused at the mint")
    Kill tSettings
    Set tSettings(..#TOOL) = "disabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the key is disabled")
    Do $$$AssertEquals(..Dispatched("SYSTEM", .tDisabledId, .tDisabledKey, .tDisabledContent) _ "|" _ tDisabledContent, "refused|{""code"":""GOVERNANCE.DISABLED""}", "the governance gate refuses the same call")
}

}
