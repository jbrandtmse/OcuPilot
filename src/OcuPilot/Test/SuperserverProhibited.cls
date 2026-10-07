/// <p>Pins AD-10's superserver arm on both callers of Story 18.25's tools (B4): on 1972, the system default
/// superserver the web gateway connects through, a delete, <code>Enabled</code> turned off, <code>EnableCSP</code>
/// turned off and the SSL/TLS support level raised to 2 are each refused
/// <code>PROHIBITED.SERVINGSUPERSERVER</code> with the published sentence before any write -- the form's Save
/// (<class>OcuPilot.Test.SuperserverSaveFixture</class>), the list's Delete
/// (<class>OcuPilot.Test.SuperserverActionFixture</class>) and the agent's confirm
/// (<class>OcuPilot.Test.DatabaseConfirm</class>) -- and a target read that fails refuses. An SSL/TLS change that
/// is not refused is minted destructive with <code>SUPERSERVER.SERVESOCUPILOT</code>. The serving port is read
/// from a principal device: a job has none, and a process served over TCP reads its port.</p>
/// <p><b>Nothing is written for real</b>: every leg runs through <class>OcuPilot.Test.SuperserverSeamPort</class>,
/// which forwards a write for ports 21825 to 21829 only, and only 1972 is targeted, so the guard marks any
/// write a mutation lets through instead of sending it. Every test checks the superserver list reads as it
/// found it. It needs a stock instance on which nothing listens on 21829.</p>
Class OcuPilot.Test.SuperserverProhibited Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.SuperserverProbe";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter SEAM = "OcuPilot.Test.SuperserverSeamPort";

Parameter SAVE = "OcuPilot.Test.SuperserverSaveFixture";

Parameter ACTION = "OcuPilot.Test.SuperserverActionFixture";

Parameter UPDATETOOL = "OcuPilot.Test.SeamSuperserverUpdate";

Parameter DELETETOOL = "OcuPilot.Test.SeamSuperserverDelete";

Parameter PROHIBITED = "OcuPilot.Kernel.Proposal.Prohibited";

Parameter SCREEN = "security.superservers";

Parameter DELETEKEY = "security.superservers.delete";

/// <p>The code the arm refuses with.</p>
Parameter CODE = "PROHIBITED.SERVINGSUPERSERVER";

/// <p>The one name the rules seam answers as a server SSL/TLS configuration.</p>
Parameter SERVERTLS = "OcuProbeServerTLS";

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

Property PreparedFacts As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = $ClassMethod(..#PROBE, "Facts")
    Do $ClassMethod(..#SEAM, "Clear")
    Kill ^||OcuPilotSuperserverServing
    Set ^||OcuPilotDatabaseWritePort = ..#SEAM
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("OcuPilot.Test.SuperserverSet")
    Kill tSettings
    Set tSettings(..#DELETEKEY) = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort, ^||OcuPilotSuperserverServing
    Do $ClassMethod(..#SEAM, "Clear")
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("")
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertNotEquals(..PreparedFacts, "unreadable", "the superserver list was read before the test")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts"), ..PreparedFacts, "the superserver list reads as before the test")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Merge tRows = ..PreparedPolicy
    ; The failed target read logs an internal error, which raised the monitor's alert state; only a clear resets it.
    Do $SYSTEM.Monitor.Clear()
    Quit ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
}

/// <p>B4: on 1972 the form's Save refuses <code>Enabled</code> off, <code>EnableCSP</code> off and level 2, and
/// the list's Delete refuses the delete, each 403 with the published sentence and no write recorded.</p>
/// <p>Mutation (Rule 19): remove the delete, flag and level refusals from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Superserver</method> -- each leg reaches the seam's guard and
/// this goes red.</p>
Method TestTheSystemDefaultRefusesTheFourChangesOnTheScreen()
{
    Set tId = $ClassMethod(..#PROBE, "Id", 1972)
    For tCase = $ListBuild("Enabled off", "{""Enabled"":false}"), $ListBuild("web connections off", "{""EnableCSP"":false}"), $ListBuild("level 2", "{""SSLConfig"":""" _ ..#SERVERTLS _ """,""SSLSupportLevel"":2}") {
        Do $ClassMethod(..#SEAM, "Clear")
        Set tSC = $ClassMethod(..#SAVE, "Handle", tId, ##class(%DynamicObject).%FromJSON($List(tCase, 2)), .tAnswer, .tStatus)
        Set tParsed = ##class(OcuPilot.Test.LicenseKey).Parsed(tAnswer)
        Do $$$AssertEquals(tStatus _ " " _ tParsed.%Get("code") _ " " _ tParsed.%Get("reason"), "403 " _ ..#CODE _ " " _ $Parameter(..#PROHIBITED, "SERVINGSUPERSERVERREASON"), $List(tCase, 1) _ ": the Save is refused with the published sentence: " _ $Extract(tAnswer, 1, 200))
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes") _ "|" _ $ClassMethod(..#SEAM, "Refused"), "|0", $List(tCase, 1) _ ": before any write")
    }
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, {"action": "delete", "id": (tId)}, .tAnswer, .tStatus)
    Set tParsed = ##class(OcuPilot.Test.LicenseKey).Parsed(tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ tParsed.%Get("code") _ " " _ tParsed.%Get("reason"), "403 " _ ..#CODE _ " " _ $Parameter(..#PROHIBITED, "SERVINGSUPERSERVERREASON"), "the delete is refused with the published sentence: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes") _ "|" _ $ClassMethod(..#SEAM, "Refused"), "|0", "before any write")
}

/// <p>B4: the agent's mint of each change on 1972 succeeds, and its confirm is refused
/// <code>PROHIBITED.SERVINGSUPERSERVER</code> before any write; the level-2 change is judged by the set itself,
/// which every caller asks.</p>
/// <p>Mutation (Rule 19): as the screen's test -- the confirm legs record a write and go red.</p>
Method TestTheSystemDefaultRefusesTheChangesToTheAgent()
{
    Set tId = $ClassMethod(..#PROBE, "Id", 1972)
    For tCase = $ListBuild("Enabled off", ..#UPDATETOOL, "{""Port"":""1972"",""BindAddress"":""0.0.0.0"",""Enabled"":false}"), $ListBuild("web connections off", ..#UPDATETOOL, "{""Port"":""1972"",""EnableCSP"":false}"), $ListBuild("delete", ..#DELETETOOL, "{""Port"":""1972"",""BindAddress"":""""}") {
        Do $ClassMethod(..#SEAM, "Clear")
        Set tSC = $ClassMethod(..#PROBE, "Mint", $List(tCase, 2), ##class(%DynamicObject).%FromJSON($List(tCase, 3)), .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ ": the agent's change is minted (" _ tProblem _ ")")
        Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "403 " _ ..#CODE, $List(tCase, 1) _ ": its confirm is refused")
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes") _ "|" _ $ClassMethod(..#SEAM, "Refused"), "|0", $List(tCase, 1) _ ": before any write")
    }
    Set tRef = ..Ref(tId)
    Set tSC = $ClassMethod(..#PROHIBITED, "Prohibits", $Parameter(..#UPDATETOOL, "TOOLNAME"), tRef, "{""SSLConfig"":""" _ ..#SERVERTLS _ """,""SSLSupportLevel"":2}", "[{""field"":""SSLSupportLevel"",""before"":""0"",""after"":""2""}]", .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the set judges a level-2 change to 1972")
    Do $$$AssertEquals(tProhibits _ " " _ tCode, "1 " _ ..#CODE, "and refuses it")
    Set tSC = $ClassMethod(..#PROHIBITED, "Prohibits", $Parameter(..#UPDATETOOL, "TOOLNAME"), tRef, "{""Description"":""probe""}", "[{""field"":""Description"",""before"":""x"",""after"":""probe""}]", .tProhibits, .tCode)
    Do $$$AssertEquals(tProhibits, 0, "while a change to the description is not refused")
}

/// <p>B4: a target read that fails refuses, on both callers: the Save answers an internal error and the confirm
/// is not applied, each with no write.</p>
/// <p>Mutation (Rule 19): answer "not prohibited" when the target read fails in
/// <method>OcuPilot.Kernel.Proposal.Prohibited.Target</method> -- the Save reaches the seam's write and the confirm
/// answers its own re-read's 409, and both legs go red.</p>
Method TestAFailedTargetReadRefuses()
{
    Set tId = $ClassMethod(..#PROBE, "Id", 1972)
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, {"Port": "1972", "Enabled": false}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's change is minted (" _ tProblem _ ")")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $ClassMethod(..#SEAM, "ArmFailAfter", "Security.Superserver/GET", 1)
    Set tSC = $ClassMethod(..#SAVE, "Handle", tId, {"Enabled": false}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#SEAM, "Calls"), "500 Security.Superserver/GET,Security.Superserver/GET", "the Save's own read passed and the set's read of the target failed, which refuses it: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "with no write")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $ClassMethod(..#SEAM, "ClearCalls")
    Do $ClassMethod(..#SEAM, "ArmFail", "Security.Superserver/GET")
    Set tOutcome = $ClassMethod(..#AGENT, "Confirm", tProposal, .tResult)
    Do $$$AssertEquals(tOutcome, "500 INTERNAL", "the confirm is refused by the set's failed read, before its own re-read")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "with no write")
}

/// <p>B4, AD-10: a change to the SSL/TLS configuration or level of the system default superserver that is not
/// refused is permitted. The agent's proposal is minted destructive with
/// <code>SUPERSERVER.SERVESOCUPILOT</code>; the form's Save reaches the write, the seam's guard stopping a write
/// to 1972 there; and a change that touches neither carries no consequence.</p>
/// <p>Mutation (Rule 19): answer no effect from <method>OcuPilot.Kernel.Proposal.Prohibited.WeakensByEffect</method>
/// for a superserver -- the destructive and consequence legs go red.</p>
Method TestAnSslChangeIsDestructiveWithItsConsequence()
{
    Set tId = $ClassMethod(..#PROBE, "Id", 1972)
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, {"Port": "1972", "SSLConfig": (..#SERVERTLS), "SSLSupportLevel": 1}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's level 1 change is minted (" _ tProblem _ ")")
    Do $$$AssertEquals(..Stored(tProposal, "destructive") _ " " _ ..Stored(tProposal, "consequence"), "1 SUPERSERVER.SERVESOCUPILOT", "destructive, with the serving consequence")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#SAVE, "Handle", tId, {"SSLConfig": (..#SERVERTLS), "SSLSupportLevel": 1}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#SEAM, "Writes") _ " " _ $ClassMethod(..#SEAM, "Refused"), "409 PUT:1972 1", "the Save is not refused by the arm and reaches the write, which the seam's guard stops: " _ $Extract(tAnswer, 1, 200))
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, {"Port": "1972", "Description": "probe"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "a description change is minted (" _ tProblem _ ")")
    Do $$$AssertEquals(..Stored(tProposal, "destructive") _ " " _ ..Stored(tProposal, "consequence"), "0 ", "not destructive, with no consequence")
}

/// <p>B4: the serving port is the local port of a TCP principal device and nothing else, a superserver is
/// serving when it is the system default or its port is the serving one whatever its bind address, an absent
/// target is never serving, and a background job reads no serving port.</p>
/// <p>Mutation (Rule 19): answer 0 for a port that matches the serving port in
/// <method>OcuPilot.Kernel.Proposal.Prohibited.IsServingSuperserver</method> -- the port-match leg goes
/// red.</p>
Method TestTheServingPortComesFromThePrincipalDevice()
{
    Set tP = ..#PROHIBITED
    Do $$$AssertEquals($ClassMethod(tP, "ServingPortOf", "|TCP|21825|9"), 21825, "|TCP|21825|9 names 21825")
    Do $$$AssertEquals($ClassMethod(tP, "ServingPortOf", "|TCP|1972|10543"), 1972, "a gateway request's device names 1972")
    For tPrincipal = "/dev/null", "", "|TCP||9", "|TCP|abc|9", "|TERM|21825|9", "|TCP|1234567|9" {
        Do $$$AssertEquals($ClassMethod(tP, "ServingPortOf", tPrincipal), "", "'" _ tPrincipal _ "' names no serving port")
    }
    Set tProbe = {"SystemDefault": false}
    Set tSep = $Char(1)
    Do $$$AssertTrue($ClassMethod(tP, "IsServingSuperserver", "21825" _ tSep _ "0.0.0.0", tProbe, 21825), "a non-default target on the serving port is serving")
    Do $$$AssertTrue($ClassMethod(tP, "IsServingSuperserver", "21825" _ tSep _ "127.0.0.1", tProbe, 21825), "whatever its bind address")
    Do $$$AssertTrue('$ClassMethod(tP, "IsServingSuperserver", "21826" _ tSep _ "0.0.0.0", tProbe, 21825), "another port is not")
    Do $$$AssertTrue('$ClassMethod(tP, "IsServingSuperserver", "21825" _ tSep _ "0.0.0.0", tProbe, ""), "and with no serving port nothing but the system default is")
    Do $$$AssertTrue($ClassMethod(tP, "IsServingSuperserver", "21826" _ tSep _ "0.0.0.0", {"SystemDefault": true}, ""), "the system default is serving with no serving port")
    Do $$$AssertTrue('$ClassMethod(tP, "IsServingSuperserver", "21825" _ tSep _ "0.0.0.0", "", 21825), "an absent target is never serving")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "JobServingPort"), "|", "a job's serving port is empty")
    Do $ClassMethod(tP, "SuperserverLocks", "21825" _ tSep _ "0.0.0.0", {"SystemDefault": true}, .tLocks)
    Do $$$AssertEquals(tLocks.%ToJSON(), "[""Enabled"",""EnableCSP""]", "a serving superserver locks Enabled and EnableCSP")
}

/// <p>B4, AD-10: the shipped serving-port read, in a process whose principal device is a TCP connection accepted
/// on a port, as a request served through a superserver is, answers that port, and a superserver on it that is
/// not the system default locks <code>Enabled</code> and <code>EnableCSP</code>. Nothing is configured: the
/// listener is the test's own, on a probe port.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Proposal.Prohibited.ServingSuperserverPort</method> answer
/// <code>""</code> -- this goes red.</p>
Method TestAProcessServedOverTcpReadsItsPort()
{
    Do $$$AssertEquals($ClassMethod(..#PROBE, "TcpServingPort", 21829), "21829|[""Enabled"",""EnableCSP""]", "the port the connection was accepted on, and its locks")
}

/// <p>The stored value <var>pName</var> of the proposal <var>pProposal</var>.</p>
ClassMethod Stored(pProposal As %DynamicObject, pName As %String) As %String
{
    If '$IsObject(pProposal) Quit ""
    Do ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(pProposal.%Get("proposalId"), .tFound, .tValues)
    Quit $Get(tValues(pName))
}

/// <p>The reference key the kernel builds for the superserver <var>pId</var>.</p>
ClassMethod Ref(pId As %String) As %String
{
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("superserver", "instance", pId, .tRef)
    Quit $Get(tRef)
}

}
