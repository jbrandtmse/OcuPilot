/// <p>Pins Story 21.20's SQL activity cancel (AC1, AC5; AD-8, AD-51, AD-53, AD-58) on both callers: the screen's Cancel query action
/// through <class>OcuPilot.Test.EcpActionFixture</class> and the agent's mint and confirm of <code>osmgmt.sqlactivity.cancel</code>,
/// against a probe statement in a job of its own that outlives its statement (<class>OcuPilot.Test.SqlActivityProbe</class>). The
/// port's refusals of a remote row, an ended statement and a caller without the SQL privilege run through
/// <class>OcuPilot.Test.SqlActivitySeam</class>, which counts the vendor calls.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving and a <code>USER</code> namespace. It cancels only
/// the statements of probe jobs it starts, as the suite's own account, and stops every probe after each test. The cross-user legs,
/// which need principals, are <class>OcuPilot.Test.SqlActivityCancelPrivilege</class>.</p>
Class OcuPilot.Test.SqlActivityCancel Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.SqlActivityPort";

Parameter SEAM = "OcuPilot.Test.SqlActivitySeam";

Parameter PROBE = "OcuPilot.Test.SqlActivityProbe";

Parameter ACTION = "OcuPilot.Test.EcpActionFixture";

Parameter VERDICT = "OcuPilot.Test.EcpDataServerWrite";

Parameter SEAMACTION = "OcuPilot.Test.SeamSqlActivityActionFixture";

Parameter SCREEN = "osmgmt.sqlactivity";

Parameter TOOL = "osmgmt.sqlactivity.cancel";

Parameter NAMESPACE = "USER";

/// <p>The governance policy as it stood before the test ran.</p>
Property PreparedPolicy [ MultiDimensional ];

Property PreparedPolicyTaken As %Boolean [ InitialExpression = 0 ];

Method OnBeforeOneTest() As %Status
{
    ; The confirm fixture's port is the shipped SQL activity port, so the confirm cancels the instance's own statement.
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
    Do $ClassMethod(..#SEAM, "Clear")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "StopAll"), "every probe job is stopped")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Running"), 0, "and none is left running")
    If ..PreparedPolicyTaken {
        Kill tRows
        Merge tRows = ..PreparedPolicy
        Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
        Set ..PreparedPolicyTaken = 0
    }
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

/// <p>Start a probe job that outlives its statement, in <code>USER</code>; its pid in <var>pPid</var> and the composite id the
/// list reports it by in <var>pId</var>.</p>
Method StartProbe(Output pPid As %Integer, Output pId As %String) As %Status
{
    Set pId = ""
    Set tLiteral = "OcuSeedCancel2120" _ (10000000 + $Random(90000000))
    Set tSC = $ClassMethod(..#PROBE, "Start", ..#NAMESPACE, tLiteral, "OcuSecretProbe2120" _ (10000000 + $Random(90000000)), .pPid, 0, 1)
    If $$$ISERR(tSC) Quit tSC
    Kill tQuery
    Set tSC = $ClassMethod(..#PORT, "Invoke", "CurrentStatements", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("ProcessID") = pPid Set pId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(tRow.%Get("Server"), tRow.%Get("ProcessID"), tRow.%Get("StatementHash")))
    }
    If pId = "" Quit $$$ERROR($$$GeneralError, "the list does not report the probe job " _ pPid)
    Quit $$$OK
}

/// <p>The screen's Cancel query on <var>pId</var>, through the action fixture; the answer's parsed envelope in <var>pAnswer</var>,
/// answering the HTTP status.</p>
ClassMethod Act(pId As %String, Output pAnswer As %DynamicObject, pFixture As %String = {..#ACTION}) As %Integer
{
    Set tBody = {"action": "cancel"}
    Do tBody.%Set("id", pId, "string")
    Set tSC = $ClassMethod(pFixture, "Act", ..#SCREEN, tBody, .tJson, .tStatus)
    Set pAnswer = $ClassMethod(..#VERDICT, "Parsed", tJson)
    Quit tStatus
}

/// <p>How many agent-write markers the audit database holds since <var>pSince</var>, whichever proposal they name.</p>
ClassMethod AgentMarkers(pSince As %String) As %Integer
{
    Quit ##class(OcuPilot.Test.AuditMarker).MarkerRows(pSince, """proposalId"":""", .tData)
}

/// <p>The list's row of probe job <var>pPid</var> as a one-row JSON array, with the members of <var>pOverride</var> set over it.</p>
ClassMethod RowJsonOf(pPid As %Integer, pOverride As %DynamicObject = "") As %String
{
    Kill tQuery
    Set tSC = $ClassMethod(..#PORT, "Invoke", "CurrentStatements", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Set tRow = {}
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tCandidate) {
        If tCandidate.%Get("ProcessID") = pPid Set tRow = tCandidate
    }
    If $IsObject(pOverride) {
        Set tOverrideIterator = pOverride.%GetIterator()
        While tOverrideIterator.%GetNext(.tKey, .tValue) {
            Do tRow.%Set(tKey, tValue, pOverride.%GetTypeOf(tKey))
        }
    }
    Quit [(tRow)].%ToJSON()
}

/// <p>The port's answer for <var>pType</var> on <var>pId</var> through <var>pPort</var>: <code>http code</code>, with the fault in
/// <var>pFault</var>.</p>
ClassMethod Ask(pPort As %String, pType As %String, pId As %String, Output pFault As %DynamicObject) As %String
{
    Kill tQuery
    Set tQuery("id") = pId
    Set tSC = $ClassMethod(pPort, "Invoke", "CurrentStatements", pType, .tQuery, "", .tAnswer, .tHttp, .pFault)
    Quit +$Get(tHttp) _ "|" _ $Select($IsObject($Get(pFault)): pFault.%Get("code"), 1: "")
}

/// <p>Wait up to <var>pSeconds</var> for the statement <var>pId</var> names to stop being listed.</p>
ClassMethod Gone(pId As %String, pSeconds As %Integer) As %Boolean
{
    Set tEnd = $ZHorolog + pSeconds
    While $ZHorolog < tEnd {
        If $Piece(..Ask(..#PORT, "ROW", pId), "|", 1) = 404 Quit
        Hang 0.25
    }
    Quit ($Piece(..Ask(..#PORT, "ROW", pId), "|", 1) = 404)
}

/// <p>The agent's dispatch of <code>osmgmt.sqlactivity.cancel</code> for the statement <var>pId</var> names, with
/// <var>pOverride</var>'s members replacing the arguments built from it: <code>minted</code> with the proposal id in
/// <var>pProposalId</var> and the turn's key in <var>pTurnKey</var>, or <code>refused</code>; the answer's content is in
/// <var>pContent</var>.</p>
ClassMethod Dispatched(pId As %String, pOverride As %DynamicObject, Output pProposalId As %String, Output pTurnKey As %String, Output pContent As %String) As %String
{
    Set pProposalId = ""
    Set pContent = ""
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pId)
    Set tInput = {"rationale": "probe", "expectedImpact": "probe"}
    Do tInput.%Set("server", $List(tParts, 1), "string")
    Do tInput.%Set("processId", $List(tParts, 2), "string")
    Do tInput.%Set("statementHash", $List(tParts, 3), "string")
    If $IsObject(pOverride) {
        Set tIterator = pOverride.%GetIterator()
        While tIterator.%GetNext(.tKey, .tValue) {
            Do tInput.%Set(tKey, tValue, "string")
        }
    }
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Set pTurnKey = $Get(tTurnKey)
    If $$$ISERR(tSC) Quit "no turn"
    Set tUse = {"type": "tool_use", "id": "toolu_sqlactivity"}
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName(..#TOOL), "string")
    Do tUse.%Set("input", tInput)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Set(tTurnKey)
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurnKey, $Username, "", [(tUse)], "OcuPilot.Kernel.Agent.Limits", .tResults, .tNames, 0, 0, .tDetails)
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Set pContent = $Select($IsObject($Get(tResults)) && (tResults.%Size() = 1): tResults.%Get(0).%Get("content"), 1: "")
    Set tParsed = ##class(OcuPilot.Test.LicenseKey).Parsed(pContent)
    If $IsObject(tParsed) Set pProposalId = tParsed.%Get("proposalId")
    Quit $Select(pProposalId '= "": "minted", 1: "refused")
}

/// <p>A row of another server, as the port's list reads it, whose composite id is <var>pId</var>.</p>
ClassMethod RemoteRowJson(Output pId As %String) As %String
{
    Set pId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("otherhost:1972", 4242, "hashRemote"))
    Quit "[{""Server"":""otherhost:1972"",""ProcessID"":4242,""UserName"":""_SYSTEM"",""Namespace"":""USER"",""Started"":""2026-11-20 10:00:00"",""StatementId"":""sid-remote"",""StatementHash"":""hashRemote"",""Statement"":"""",""Remote"":true}]"
}

/// <p>A row of this server, as the port's list reads it, whose composite id is <var>pId</var>.</p>
ClassMethod LocalRowJson(Output pId As %String) As %String
{
    Set tServer = $ClassMethod(..#PORT, "LocalServer")
    Set pId = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(tServer, 4243, "hashLocal"))
    Quit "[{""Server"":""" _ tServer _ """,""ProcessID"":4243,""UserName"":""_SYSTEM"",""Namespace"":""USER"",""Started"":""2026-11-20 10:00:00"",""StatementId"":""sid-local"",""StatementHash"":""hashLocal"",""Statement"":"""",""Remote"":false}]"
}

/// <p><b>AC1.</b> On both callers a probe's statement stops, its row is gone on the next read, and its process still runs. The
/// agent's confirm records one marker and a read-back that finds the row absent; a second cancel of the gone statement is 404 at
/// the screen and refused at the mint.</p>
/// <p>Mutation (Rule 19): <code>Cancel</code> answers <code>$$$OK</code> without calling the vendor -> the first row-gone leg goes red.</p>
Method TestBothCallersCancelTheStatementAndTheProcessSurvives()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertStatusOK(..StartProbe(.tPid, .tId), "a probe statement runs in a job that outlives it")
    Set tStatus = ..Act(tId, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tAnswer), "200|notFound", "the screen's Cancel query answers 200 and its read-back finds the statement absent: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Do $$$AssertEquals(..Gone(tId, 10), 1, "the statement's row is gone on the next read")
    Do $$$AssertTrue($Data(^$JOB(tPid)) > 0, "and its process still runs")
    Do $$$AssertEquals(..AgentMarkers(tSince), 0, "the person's cancel records no agent-write marker (AD-53)")
    Do $$$AssertEquals(..Act(tId, .tAgain), 404, "a second cancel of the gone statement is 404 at the screen")
    Do $$$AssertEquals($Piece(..Dispatched(tId, "", .tNoId, .tNoKey, .tNoContent), "|", 1), "refused", "and refused at the mint")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "StopAll"), "the first probe is stopped")

    Do $$$AssertStatusOK(..StartProbe(.tPid2, .tId2), "a second probe statement runs")
    Do $$$AssertEquals(..Dispatched(tId2, "", .tProposalId, .tTurnKey, .tContent), "minted", "the agent's call mints a proposal: " _ tContent)
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tProposalId, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ $Get(tCode) _ "|" _ $ClassMethod(..#VERDICT, "Verdict", tResult), "1||notFound", "its confirm cancels the statement and its read-back finds the row absent: " _ $Get(tCode))
    Do $$$AssertEquals(..Gone(tId2, 10), 1, "the statement's row is gone")
    Do $$$AssertTrue($Data(^$JOB(tPid2)) > 0, "and its process still runs")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).WriteRow(tTurnKey, .tRow), 1, "one write-kind ledger row records the agent's cancel")
    Do $$$AssertEquals($Get(tRow("AuditMarked")), $Parameter("OcuPilot.Kernel.State.Ledger", "MARKEDYES"), "and the agent's audit marker landed on it")
    Do $$$AssertEquals(##class(OcuPilot.Test.AuditMarker).MarkerRows(tSince, """proposalId"":""" _ tProposalId _ """", .tData), 1, "and one agent marker names the proposal")
}

/// <p><b>AC1.</b> A row of another server is refused 409 <code>SQLACTIVITY.REMOTE</code> with its sentence before the vendor is
/// called, for a caller that names it by its composite id.</p>
/// <p>Mutation (Rule 19): drop the <code>Remote</code> refusal in <method>OcuPilot.Port.SqlActivityPort.Statement</method> -> the
/// vendor is called and the cancel count goes red.</p>
Method TestARemoteRowIsRefusedBeforeTheVendor()
{
    Do $ClassMethod(..#SEAM, "Arm", "rowsJson", ..RemoteRowJson(.tId))
    Set tGot = ..Ask(..#SEAM, "CANCEL", tId, .tFault)
    Do $$$AssertEquals(tGot, "409|SQLACTIVITY.REMOTE", "a remote row is refused 409 SQLACTIVITY.REMOTE")
    Do $$$AssertEquals(tFault.%Get("reason"), $Parameter("OcuPilot.Api.SqlActivityError", "REASONREMOTE"), "with its sentence")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Count", "cancel"), 0, "and the vendor is never called")
}

/// <p><b>AC1.</b> The vendor's answer that a statement is not running is 409 <code>SQLACTIVITY.ENDED</code>, and its answer that the
/// caller lacks the SQL privilege <code>%CANCEL_QUERY</code> is 403 <code>SQLACTIVITY.NOPRIVILEGE</code> with its sentence; each
/// call reached the vendor once with the row's own process and statement id. A statement the list does not report is 404.</p>
/// <p>Mutation (Rule 19): map #6164 to <code>NOPRIVILEGE</code> in <method>OcuPilot.Port.SqlActivityPort.Statement</method> -> the ended
/// leg goes red.</p>
Method TestTheVendorsAnswersMapToTheirCodes()
{
    Do $ClassMethod(..#SEAM, "Arm", "rowsJson", ..LocalRowJson(.tId))
    Do $ClassMethod(..#SEAM, "Arm", "cancel", $System.Status.Error(6164, "the statement is not running"))
    Do $$$AssertEquals(..Ask(..#SEAM, "CANCEL", tId, .tFault), "409|SQLACTIVITY.ENDED", "an ended statement is refused 409 SQLACTIVITY.ENDED")
    Do $$$AssertEquals(tFault.%Get("reason"), $Parameter("OcuPilot.Api.SqlActivityError", "REASONENDED"), "with its sentence")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Canceled"), "4243|sid-local", "and the vendor was asked about the row's own process and statement id")
    Do $ClassMethod(..#SEAM, "Arm", "cancel", $System.Status.Error(5521, "does not have the SQL Admin Privilege %CANCEL_QUERY"))
    Do $$$AssertEquals(..Ask(..#SEAM, "CANCEL", tId, .tFault), "403|SQLACTIVITY.NOPRIVILEGE", "a caller without the SQL privilege is refused 403 SQLACTIVITY.NOPRIVILEGE")
    Do $$$AssertEquals(tFault.%Get("reason"), $Parameter("OcuPilot.Api.SqlActivityError", "REASONNOPRIVILEGE"), "with its sentence")
    Do $ClassMethod(..#SEAM, "Arm", "cancel", $System.Status.Error(5001, "an unrelated vendor failure"))
    Do $$$AssertEquals($Piece(..Ask(..#SEAM, "CANCEL", tId, .tFault), "|", 1), 500, "any other vendor answer is 500, logged")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Count", "cancel"), 3, "each call reached the vendor once")
    Do $$$AssertEquals($Piece(..Ask(..#SEAM, "CANCEL", ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("x", 1, "y")), .tFault), "|", 1), 404, "a statement the list does not report is 404")
    Do $$$AssertEquals($Piece(..Ask(..#SEAM, "CANCEL", "malformed", .tFault), "|", 1), 404, "and so is an id that is no composite")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Count", "cancel"), 3, "and neither reached the vendor")
}

/// <p><b>AC1.</b> A caller missing a pair is refused 403 naming it, before any read or vendor call.</p>
/// <p>Mutation (Rule 19): skip the gate for <code>CANCEL</code> in <method>OcuPilot.Port.SqlActivityPort.Invoke</method> -> the refusal goes
/// red.</p>
Method TestACallerMissingAPairIsRefusedByName()
{
    Do $ClassMethod(..#SEAM, "Arm", "gate", 1)
    Do $ClassMethod(..#SEAM, "Arm", "rowsJson", ..LocalRowJson(.tId))
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Operate", "USE")
    Do $$$AssertEquals(..Ask(..#SEAM, "CANCEL", tId, .tFault), "403|PORT.ACCESSDENIED", "a caller short of %DB_IRISSYS:READ is refused 403")
    Do $$$AssertEquals(tFault.%Get("detail").%Get("failedPair"), "%DB_IRISSYS:READ", "naming the pair")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Count", "rows") _ "|" _ $ClassMethod(..#SEAM, "Count", "cancel"), "0|0", "and nothing was read or canceled")
}

/// <p><b>AC5.</b> At the default baseline the agent's call mints; with the key disabled the governance gate refuses it, and a
/// separator character in an argument is refused at the mint.</p>
/// <p>Mutation (Rule 19): <code>osmgmt.sqlactivity.cancel</code> is <code>false</code> in <class>OcuPilot.Kernel.Governance.Baseline</class>
/// -> the default leg goes red.</p>
Method TestTheKeyGovernsTheCancel()
{
    Do $$$AssertStatusOK(..StartProbe(.tPid, .tId), "a probe statement runs")
    Do $$$AssertEquals(..Dispatched(tId, "", .tProposalId, .tTurnKey, .tContent), "minted", "the default baseline mints the proposal: " _ tContent)
    Do $$$AssertEquals(..Dispatched(tId, {"server": ("x" _ $Char(1) _ "y")}, .tSeparatorId, .tSeparatorKey, .tSeparatorContent), "refused", "a separator character in an argument is refused at the mint")
    Do $$$AssertTrue(tSeparatorContent [ "TOOL.ARGUMENTS", "with the argument refusal code: " _ tSeparatorContent)
    Kill tSettings
    Set tSettings(..#TOOL) = "disabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the key is disabled")
    Do $$$AssertEquals(..Dispatched(tId, "", .tDisabledId, .tDisabledKey, .tDisabledContent) _ "|" _ tDisabledContent, "refused|{""code"":""GOVERNANCE.DISABLED""}", "the governance gate refuses the same call")
}

/// <p><b>AC1.</b> Each refusal code of the cancel carries its published sentence and status through the tool-result resolver.</p>
/// <p>Mutation (Rule 19): drop the <code>SQLACTIVITY.</code> branch from <method>OcuPilot.Api.Error.ReasonForToolCode</method> -- this
/// goes red.</p>
Method TestEachRefusalCodeResolvesToItsSentence()
{
    Set tError = "OcuPilot.Api.SqlActivityError"
    For tCase = $ListBuild("REMOTE", 409), $ListBuild("ENDED", 409), $ListBuild("NOPRIVILEGE", 403) {
        Set tCode = $Parameter(tError, $List(tCase, 1))
        Set tReason = $Parameter(tError, "REASON" _ $List(tCase, 1))
        Do $$$AssertTrue((tCode [ "SQLACTIVITY.") && (tReason '= ""), $List(tCase, 1) _ " names a SQLACTIVITY code and a sentence")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode), tReason, tCode _ " answers its sentence through the tool-result resolver")
        Do $$$AssertEquals($ClassMethod(tError, "HttpStatusFor", tCode), $List(tCase, 2), tCode _ " is answered with " _ $List(tCase, 2))
    }
}

/// <p><b>AC1.</b> A remote row and a refused SQL privilege are refused on both callers with their codes and sentences, and the
/// vendor is not asked about the remote row. The screen's action runs over rows and answers the port seam is armed with
/// (<class>OcuPilot.Test.SeamSqlActivityActionFixture</class>); the agent's mint reads the real row and its confirm reads the
/// seam's, which carries the same fingerprint. A refused confirm leaves no agent-write marker, and the probe's statement keeps
/// running.</p>
/// <p>Mutation (Rule 19): drop the <code>Remote</code> refusal in <method>OcuPilot.Port.SqlActivityPort.Statement</method> -> the
/// remote legs go red.</p>
Method TestARemoteRowAndAMissingPrivilegeAreRefusedOnBothCallers()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Set tError = "OcuPilot.Api.SqlActivityError"
    Do $$$AssertStatusOK(..StartProbe(.tPid, .tId), "a probe statement runs")
    Do $ClassMethod(..#SEAM, "Arm", "rowsJson", ..RowJsonOf(tPid, {"Remote": true}))
    Set tStatus = ..Act(tId, .tAnswer, ..#SEAMACTION)
    Set tText = $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: "")
    Do $$$AssertEquals(tStatus, 409, "the screen's cancel of a remote row is 409: " _ tText)
    Do $$$AssertTrue((tText [ $Parameter(tError, "REMOTE")) && (tText [ $Parameter(tError, "REASONREMOTE")), "naming its code and carrying its sentence: " _ tText)
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Count", "cancel"), 0, "and the vendor is never called")

    Do $$$AssertEquals(..Dispatched(tId, "", .tProposalId, .tTurnKey, .tContent), "minted", "the agent's call mints a proposal: " _ tContent)
    Set ^||OcuPilotDatabaseWritePort = ..#SEAM
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tProposalId, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals($$$ISERR(tSC) _ "|" _ $Get(tHttp) _ "|" _ $Get(tCode), "1|409|" _ $Parameter(tError, "REMOTE"), "its confirm of the remote row is refused 409 with the code")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Count", "cancel"), 0, "and the vendor is still never called")
    Do $$$AssertEquals(..AgentMarkers(tSince), 0, "a refused cancel leaves no agent-write marker")

    Do $ClassMethod(..#SEAM, "Clear")
    Do $ClassMethod(..#SEAM, "Arm", "rowsJson", ..RowJsonOf(tPid))
    Do $ClassMethod(..#SEAM, "Arm", "cancel", $System.Status.Error(5521, "does not have the SQL Admin Privilege %CANCEL_QUERY"))
    Set tNoPrivilegeStatus = ..Act(tId, .tNoPrivilege, ..#SEAMACTION)
    Set tNoPrivilegeText = $Select($IsObject(tNoPrivilege): tNoPrivilege.%ToJSON(), 1: "")
    Do $$$AssertEquals(tNoPrivilegeStatus, 403, "the screen's cancel without the SQL privilege is 403: " _ tNoPrivilegeText)
    Do $$$AssertTrue((tNoPrivilegeText [ $Parameter(tError, "NOPRIVILEGE")) && (tNoPrivilegeText [ $Parameter(tError, "REASONNOPRIVILEGE")), "naming its code and carrying its sentence: " _ tNoPrivilegeText)
    Do $$$AssertEquals(..Dispatched(tId, "", .tSecondProposalId, .tSecondTurnKey, .tSecondContent), "minted", "a second proposal mints: " _ tSecondContent)
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tSecondProposalId, "", $Username, .tResult2, .tHttp2, .tCode2, .tDetail2)
    Do $$$AssertEquals($$$ISERR(tSC) _ "|" _ $Get(tHttp2) _ "|" _ $Get(tCode2), "1|403|" _ $Parameter(tError, "NOPRIVILEGE"), "the agent's confirm without it is refused 403 with the code")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Count", "cancel"), 2, "each reached the vendor once")
    Do $$$AssertEquals(..AgentMarkers(tSince), 0, "and the refused confirm still leaves no agent-write marker")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Listed", tPid), 1, "the probe's statement keeps running")
}

/// <p><b>AC1.</b> A confirm after the statement ended, and one after the process moved to another statement, are refused before
/// any vendor call and leave no agent-write marker.</p>
/// <p>Mutation (Rule 19): drop <code>StatementId</code> from <code>FINGERPRINTSUBJECT</code> and make <code>Started</code> the
/// <code>PRECONDITIONFIELD</code> in <class>OcuPilot.Screen.Tool.SqlActivityCancel</class> -> the moved-statement leg goes red.</p>
Method TestAConfirmAfterTheStatementEndedOrMovedIsRefusedBeforeTheVendor()
{
    Set tSince = ##class(OcuPilot.Test.AuditEvent).Now()
    Do $$$AssertStatusOK(..StartProbe(.tPid, .tId), "a probe statement runs")
    Do $$$AssertEquals(..Dispatched(tId, "", .tMovedProposalId, .tMovedTurnKey, .tMovedContent), "minted", "the agent's call mints a proposal: " _ tMovedContent)
    Set ^||OcuPilotDatabaseWritePort = ..#SEAM
    Do $ClassMethod(..#SEAM, "Arm", "rowsJson", ..RowJsonOf(tPid, {"StatementId": "moved-on"}))
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tMovedProposalId, "", $Username, .tResult, .tHttp, .tCode, .tDetail)
    Do $$$AssertEquals($$$ISERR(tSC), 1, "a confirm after the process moved to another statement is refused: " _ $Get(tCode))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Count", "cancel"), 0, "before the vendor is called")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Listed", tPid), 1, "and the statement keeps running")

    Do $ClassMethod(..#SEAM, "Clear")
    Do $$$AssertEquals(..Dispatched(tId, "", .tEndedProposalId, .tEndedTurnKey, .tEndedContent), "minted", "a second proposal mints: " _ tEndedContent)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "StopAll"), "the probe job is stopped, so its statement has ended")
    Do $$$AssertEquals(..Gone(tId, 10), 1, "and its row is gone")
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tEndedProposalId, "", $Username, .tResult2, .tHttp2, .tCode2, .tDetail2)
    Do $$$AssertEquals($$$ISERR(tSC), 1, "a confirm after the statement ended is refused: " _ $Get(tCode2))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Count", "cancel"), 0, "before the vendor is called")
    Do $$$AssertEquals(..AgentMarkers(tSince), 0, "and neither refusal leaves an agent-write marker")
}

/// <p><b>AC1.</b> The cancel's script form is the vendor call for the row's own process and statement hash, a statement of another
/// server renders one comment step with the refusal's sentence, and an id that is no composite renders none.</p>
/// <p>Mutation (Rule 19): drop the <code>IsRemote</code> branch from <method>OcuPilot.Port.SqlActivityPort.Snippet</method> -> the
/// remote leg goes red.</p>
Method TestTheScriptFormIsTheVendorCallForTheRowsOwnProcessAndStatement()
{
    Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", "CurrentStatements", "CANCEL"), "objectscript", "the cancel has a script form")
    Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", "CurrentStatements", "LIST"), "", "the list has none")
    Kill tQuery
    Set tQuery("id") = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild($ClassMethod(..#PORT, "LocalServer"), 4243, "hashLocal"))
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "CurrentStatements", "CANCEL", .tQuery)
    Do $$$AssertEquals(tSteps.%Size() _ "|" _ tSteps.%Get(0).kind, "1|objectscript", "a local row renders one objectscript step")
    Set tText = tSteps.%Get(0).text
    Do $$$AssertTrue(tText [ "WHERE ProcessID = ? AND StatementIndexHash = ?"", 4243, ""hashLocal"")", "which finds the statement by the row's process id and statement hash: " _ tText)
    Do $$$AssertTrue(tText [ ("$SYSTEM.SQL.CancelQuery(4243, tRS.%GetData(1), " _ $Parameter(..#PORT, "CANCELSECONDS") _ ")"), "and cancels it with the vendor call: " _ tText)
    Set tQuery("id") = ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild("otherhost:1972", 4242, "hashRemote"))
    Set tRemote = $ClassMethod(..#PORT, "Snippet", "CurrentStatements", "CANCEL", .tQuery)
    Do $$$AssertEquals(tRemote.%Size() _ "|" _ tRemote.%Get(0).kind _ "|" _ tRemote.%Get(0).text, "1|comment|" _ $Parameter("OcuPilot.Api.SqlActivityError", "REASONREMOTE"), "a remote row renders one comment step with the refusal's sentence and no call")
    Set tQuery("id") = "malformed"
    Do $$$AssertEquals($ClassMethod(..#PORT, "Snippet", "CurrentStatements", "CANCEL", .tQuery).%Size(), 0, "an id that is no composite renders no step")
}

}
