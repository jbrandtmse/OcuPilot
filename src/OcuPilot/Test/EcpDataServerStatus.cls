/// <p>Pins Story 18.20's status change on both callers (AC B4, B5, B6; AD-26, AD-51): the list's Change
/// status (<class>OcuPilot.Test.EcpActionFixture</class>) and the agent's mint and confirm
/// (<class>OcuPilot.Test.DatabaseConfirm</class>). The real Disabled and Not connected are queued and
/// polled within the bound; the same status and an unlicensed Normal are refused with no action sent;
/// Normal on a licensed instance, a change past the bound and a task the vendor fails each run through
/// <class>OcuPilot.Test.EcpSeamPort</class>, which never sends <code>Action</code> 3 to the vendor.</p>
/// <p>The status change is action-style (AD-51), so its read-back reads <code>nothingSent</code>
/// (AD-58), and the list is what shows the new status.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, a license that enables
/// no ECP, as every Community instance's, room for one data server under the instance's limit, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates, changes and
/// deletes a probe data server (<class>OcuPilot.Test.EcpProbe</class>) and sets the governance policy.
/// Every probe object is removed by exact name before all, after each and after all; after each test no
/// ECP process runs and the license reads as that test found it.</p>
Class OcuPilot.Test.EcpDataServerStatus Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the data server writes, set by
/// <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_ECP_CONFIG";

Parameter PROBE = "OcuPilot.Test.EcpProbe";

/// <p>The mint, confirm and list helpers, shared with Story 18.6's suites.</p>
Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter SEAM = "OcuPilot.Test.EcpSeamPort";

Parameter ACTION = "OcuPilot.Test.EcpActionFixture";

Parameter TOOL = "OcuPilot.Screen.Tool.EcpDataServerChangeStatus";

/// <p>The tool through the seam, whose mint asks the seam's license.</p>
Parameter SEAMTOOL = "OcuPilot.Test.SeamEcpDataServerChangeStatus";

Parameter SCREEN = "osmgmt.ecpdataservers";

Parameter KEY = "osmgmt.ecpdataservers.changestatus";

Parameter SERVER = "OCUPROBEECPA";

/// <p>The governance policy as it stood before the class ran, restored after each test.</p>
Property PreparedPolicy [ MultiDimensional ];

/// <p>The license's facts before each test, which the test must leave as found.</p>
Property PreparedFacts As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.EcpDataServerStatus creates, changes and deletes a probe ECP data server on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

/// <p>Every test seeds the probe data server, Not Connected, and records through the seam, with the
/// agent's status change key enabled over the snapshot.</p>
Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = ##class(OcuPilot.Test.LicenseProbe).LicenseFacts().%ToJSON()
    Do $ClassMethod(..#SEAM, "Clear")
    Kill ^||OcuPilotRemoteLicensed
    Set ^||OcuPilotDatabaseWritePort = ..#SEAM
    Kill tSettings
    Set tSettings(..#KEY) = "enabled"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
    If $$$ISERR(tSC) Quit tSC
    Quit $ClassMethod(..#PROBE, "SeedServer", ..#SERVER)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort, ^||OcuPilotRemoteLicensed
    Do $ClassMethod(..#SEAM, "Clear")
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe object is removed by exact name")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "EcpJobs"), 0, "no ECP process runs after the test")
    Do $$$AssertEquals(##class(OcuPilot.Test.LicenseProbe).LicenseFacts().%ToJSON(), ..PreparedFacts, "the license reads as before the test")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort, ^||OcuPilotRemoteLicensed
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", .tRemaining))
}

/// <p>B4: Disabled and then Not connected, through the list's Change status and through a confirmed
/// proposal, each send one <code>SERVERACTION</code> with its <code>Action</code>, polled within the
/// bound; the list shows each status, the read-back reads <code>nothingSent</code>, no ECP process
/// starts, and <code>messages.log</code> gains no ERROR #7846.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Port.EcpPort.STATUSACTIONS</parameter> maps
/// <code>disabled</code> to 1 -- the list keeps Not Connected and this goes red.</p>
Method TestDisabledAndBackToNotConnectedOnBothCallers()
{
    Set tLines = $ClassMethod(..#PROBE, "LineCount", "messages.log")
    For tCase = $ListBuild("disabled", "2", "Disabled", 4), $ListBuild("notconnected", "1", "Not Connected", 1) {
        Do $ClassMethod(..#SEAM, "Clear")
        Set tLabel = "the list's " _ $List(tCase, 1)
        Set tSC = ..Change($List(tCase, 1), .tAnswer, .tStatus)
        Set tParsed = ..Parsed(tAnswer)
        Do $$$AssertEquals(tStatus, 200, tLabel _ " answers 200: " _ $Extract(tAnswer, 1, 200))
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Actions"), $List(tCase, 2), tLabel _ " sends one SERVERACTION with its Action")
        Do $$$AssertEquals($Select($IsObject(tParsed): tParsed.%Get("action") _ " " _ ..Verdict(tParsed) _ " " _ tParsed.%IsDefined("continues"), 1: ""), "updated nothingSent 0", tLabel _ " finished within the bound, an action-style write whose read-back sends nothing")
        Do $$$AssertEquals(..Listed(), $List(tCase, 3), tLabel _ ": the list shows the new status")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "ConnState", ..#SERVER), $List(tCase, 4), tLabel _ ": the instance's connection state agrees")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "EcpJobs"), 0, tLabel _ ": no ECP process starts")
    }
    For tCase = $ListBuild("disabled", "2", "Disabled", 4), $ListBuild("notconnected", "1", "Not Connected", 1) {
        Set tLabel = "the agent's " _ $List(tCase, 1)
        Set tSC = $ClassMethod(..#AGENT, "Mint", ..#TOOL, ..#SERVER, ..Args($List(tCase, 1)), .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusOK(tSC, tLabel _ " is minted (" _ tProblem _ ")")
        Do $$$AssertEquals($Select($IsObject(tProposal): ..Rows(tProposal.%Get("changed")), 1: ""), "Status:" _ $Select($List(tCase, 1) = "disabled": "Not Connected", 1: "Disabled") _ ">" _ $List(tCase, 3), tLabel _ ": its card's one row is the status change")
        Do $ClassMethod(..#SEAM, "Clear")
        Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", tLabel _ ": its confirm changes the status")
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Actions"), $List(tCase, 2), tLabel _ " sends one SERVERACTION with its Action")
        Do $$$AssertEquals(..Verdict($Get(tResult)) _ " " _ $Select($IsObject($Get(tResult)): tResult.%IsDefined("continues"), 1: ""), "nothingSent 0", tLabel _ " finished within the bound")
        Do $$$AssertEquals(..Listed(), $List(tCase, 3), tLabel _ ": the list shows the new status")
        Do $$$AssertEquals($ClassMethod(..#PROBE, "EcpJobs"), 0, tLabel _ ": no ECP process starts")
    }
    Set tAfter = $ClassMethod(..#PROBE, "LinesAfter", "messages.log", tLines)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "CountContaining", tAfter, "#7846"), 0, "messages.log gains no ERROR #7846 (" _ tAfter.%Size() _ " new lines)")
}

/// <p>B5: a status equal to the current one is refused 422 <code>ECP.STATUS.SAME</code> on
/// <code>Status</code> by the list's Change status and at the agent's mint, with no
/// <code>SERVERACTION</code> sent and no task row written -- for Not Connected, and for Disabled.</p>
/// <p>Mutation (Rule 19): drop the same-status check from <class>OcuPilot.Port.EcpPort</class> -- the
/// list's change is sent and this goes red.</p>
Method TestTheSameStatusIsRefusedWithNothingSent()
{
    Set tRows = $ClassMethod(..#PROBE, "UserTaskRows", $Username)
    For tCase = $ListBuild("notconnected", ""), $ListBuild("disabled", "disabled") {
        If $List(tCase, 2) '= "" {
            Set tSC = ..Change($List(tCase, 2), .tAnswer, .tStatus)
            Do $$$AssertEquals(tStatus _ " " _ ..Listed(), "200 Disabled", "the server is set Disabled first: " _ $Extract(tAnswer, 1, 200))
        }
        Do $ClassMethod(..#SEAM, "Clear")
        Set tLabel = $List(tCase, 1)
        Set tSC = ..Change($List(tCase, 1), .tAnswer, .tStatus)
        Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LicenseKey).Violation(tAnswer), "422 Status:" _ ##class(OcuPilot.Api.EcpError).#STATUSSAME, tLabel _ ": the list's change to the current status is refused on Status: " _ $Extract(tAnswer, 1, 200))
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", tLabel _ ": with no SERVERACTION sent")
        Set tSC = $ClassMethod(..#AGENT, "Mint", ..#SEAMTOOL, ..#SERVER, ..Args($List(tCase, 1)), .tProposal, .tHttp, .tProblem)
        Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ ##class(OcuPilot.Api.EcpError).#REASONSTATUSSAME), tLabel _ ": and the agent's is refused at the mint: " _ tProblem)
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", tLabel _ ": with nothing sent")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "UserTaskRows", $Username), tRows, "and no task row is left")
}

/// <p>B5: on an instance whose license enables no ECP, Normal is refused 422 <code>ECP.LICENSE</code>
/// on <code>Status</code> by the list's Change status and at the agent's mint, before any
/// <code>SERVERACTION</code>, with no task row written.</p>
/// <p>Mutation (Rule 19): drop the license check from <class>OcuPilot.Port.EcpPort</class> -- the seam
/// records a <code>SERVERACTION</code> and this goes red.</p>
Method TestNormalIsRefusedWhileTheLicenseLacksEcp()
{
    Do $$$AssertEquals(##class(OcuPilot.Port.EcpPort).NetworkEnabled(), 0, "this instance's license enables no ECP, as every Community instance's")
    Set tRows = $ClassMethod(..#PROBE, "UserTaskRows", $Username)
    Set tSC = ..Change("normal", .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LicenseKey).Violation(tAnswer), "422 Status:" _ ##class(OcuPilot.Api.EcpError).#LICENSE, "the list's Normal is refused on Status: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "with no SERVERACTION sent")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#SEAMTOOL, ..#SERVER, ..Args("normal"), .tProposal, .tHttp, .tProblem)
    Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ ##class(OcuPilot.Api.EcpError).#REASONLICENSE), "and the agent's is refused at the mint: " _ tProblem)
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "with nothing sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "UserTaskRows", $Username), tRows, "and no task row is written")
    Do $$$AssertEquals(..Listed() _ " " _ $ClassMethod(..#PROBE, "ConnState", ..#SERVER), "Not Connected 1", "the server is unchanged")
}

/// <p>B5: on an instance the seam reports licensed, Normal passes the license check on both callers and
/// the seam records exactly one <code>SERVERACTION</code> with <code>Action</code> 3, which never
/// reaches the vendor.</p>
Method TestNormalPassesTheLicenseCheckThroughTheSeam()
{
    Set ^||OcuPilotRemoteLicensed = 1
    Do $ClassMethod(..#SEAM, "Arm", "finished")
    Set tSC = ..Change("normal", .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ..Verdict(tAnswer), "200 nothingSent", "the list's Normal is answered through the seam: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Actions"), "3", "with exactly one SERVERACTION carrying Action 3")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#SEAMTOOL, ..#SERVER, ..Args("normal"), .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's Normal is minted on the seam's license (" _ tProblem _ ")")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $ClassMethod(..#SEAM, "Arm", "finished")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and its confirm is answered through the seam")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Actions"), "3", "with exactly one SERVERACTION carrying Action 3")
    Do $$$AssertEquals(..Listed() _ " " _ $ClassMethod(..#PROBE, "ConnState", ..#SERVER), "Not Connected 1", "and the vendor was never asked: the server is unchanged")
}

/// <p>B4: a change still running at the port's bound has started (AD-26): both callers answer it
/// accepted, with <code>continues</code> and the read-back <code>unchecked</code>
/// (<code>running</code>).</p>
/// <p>Mutation (Rule 19): drop the <code>PORT.TIMEOUT</code> handling from
/// <class>OcuPilot.Port.EcpPort</class> -- the change answers 503 and this goes red.</p>
Method TestAChangePastTheBoundHasStarted()
{
    Do $ClassMethod(..#SEAM, "Arm", "started")
    Set tSC = ..Change("disabled", .tAnswer, .tStatus)
    Set tParsed = ..Parsed(tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the list's change answers: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($Select($IsObject(tParsed): ..Verdict(tParsed) _ " " _ tParsed.%Get("readBack").%Get("reason") _ " " _ tParsed.%Get("continues"), 1: ""), "unchecked running 1", "still running, read back unchecked, and continuing")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Actions"), "2", "the action was sent")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#TOOL, ..#SERVER, ..Args("disabled"), .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's change is minted (" _ tProblem _ ")")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $ClassMethod(..#SEAM, "Arm", "started")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and its confirm answers")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): ..Verdict(tResult) _ " " _ tResult.%Get("readBack").%Get("reason") _ " " _ tResult.%Get("continues"), 1: ""), "unchecked running 1", "still running, read back unchecked, and continuing")
}

/// <p>A task the vendor fails is refused 409 <code>ECP.STATUS.REFUSED</code> on both callers, with
/// nothing reported changed.</p>
Method TestAFailedChangeIsRefusedAndReportsNothingChanged()
{
    Do $ClassMethod(..#SEAM, "Arm", "failed")
    Set tSC = ..Change("disabled", .tAnswer, .tStatus)
    Set tParsed = ..Parsed(tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tParsed): tParsed.%Get("code"), 1: ""), "409 " _ ##class(OcuPilot.Api.EcpError).#STATUSREFUSED, "the list's change is refused: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($Select($IsObject(tParsed): tParsed.%IsDefined("readBack") _ tParsed.%IsDefined("action"), 1: ""), "00", "with nothing reported changed")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#TOOL, ..#SERVER, ..Args("disabled"), .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's change is minted (" _ tProblem _ ")")
    Do $ClassMethod(..#SEAM, "Arm", "failed")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "409 " _ ##class(OcuPilot.Api.EcpError).#STATUSREFUSED, "and its confirm is refused")
    Do $$$AssertEquals(..Listed() _ " " _ $ClassMethod(..#PROBE, "ConnState", ..#SERVER), "Not Connected 1", "and the server is unchanged")
}

/// <p>B6: a status change of a server the instance does not define is refused on both callers with no
/// action sent: the list's 404 and the mint's absence.</p>
Method TestAnAbsentTargetIsRefused()
{
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, {"action": "changestatus", "id": "OCUPROBEECPGONE", "values": {"Status": "disabled"}}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 404, "the list's change of an absent server is 404: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "with nothing sent")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#TOOL, "OCUPROBEECPGONE", {"Name": "OCUPROBEECPGONE", "Status": "disabled"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ "not present"), "and the agent's is refused as absent: " _ tProblem)
}

/// <p>The list's Change status of <parameter>SERVER</parameter> to <var>pValue</var>, through the
/// action fixture.</p>
ClassMethod Change(pValue As %String, Output pAnswer As %String, Output pStatus As %Integer) As %Status
{
    Set tBody = {"action": "changestatus"}
    Do tBody.%Set("id", ..#SERVER, "string")
    Do tBody.%Set("values", {"Status": (pValue)})
    Quit $ClassMethod(..#ACTION, "Act", ..#SCREEN, tBody, .pAnswer, .pStatus)
}

/// <p>The agent's arguments for a change of <parameter>SERVER</parameter> to <var>pStatus</var>.</p>
ClassMethod Args(pStatus As %String) As %DynamicObject
{
    Set tArgs = {}
    Do tArgs.%Set("Name", ..#SERVER, "string")
    Do tArgs.%Set("Status", pStatus, "string")
    Quit tArgs
}

/// <p><parameter>SERVER</parameter>'s status as the list reads it, or <code>(absent)</code>.</p>
ClassMethod Listed() As %String
{
    Set tRow = $ClassMethod(..#PROBE, "ListRow", ..#SERVER)
    If '$IsObject(tRow) Quit "(absent)"
    Quit tRow.%Get("Status")
}

/// <p>A card's rows <var>pRows</var> as <code>field:before&gt;after</code>, comma-joined.</p>
ClassMethod Rows(pRows As %DynamicArray) As %String
{
    If '$IsObject(pRows) Quit ""
    Set tOut = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $IsObject(tRow) Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tRow.%Get("field") _ ":" _ tRow.%Get("before") _ ">" _ tRow.%Get("after")
    }
    Quit tOut
}

/// <p>The read-back verdict an answer carries, the answer an object or its JSON text, or
/// <code>(none)</code>.</p>
ClassMethod Verdict(pAnswer) As %String
{
    Quit ##class(OcuPilot.Test.EcpDataServerWrite).Verdict(pAnswer)
}

/// <p><var>pJson</var> parsed as an object, or <code>""</code>.</p>
ClassMethod Parsed(pJson As %String) As %DynamicObject
{
    Quit ##class(OcuPilot.Test.LicenseKey).Parsed(pJson)
}

}
