/// <p>Pins Story 18.21's ECP application servers on both callers (AC C4, C5, C6, C7; AD-51, AD-53): both
/// tabs' reads on screen and tool, and the SSL/TLS authorizations' Authorize, Reject and Delete through
/// the tab's row actions (<class>OcuPilot.Test.EcpActionFixture</class>) and the agent's mint and confirm
/// (<class>OcuPilot.Test.DatabaseConfirm</class>) -- the matrix's list, delete, wrong-state, pending and
/// absent-name legs -- and DW-2006: a data server's SSL/TLS over a disabled <code>%ECPClient</code>.</p>
/// <p>A seeded authorized name is real (<method>OcuPilot.Test.EcpProbe.SeedAuthorized</method>), and its
/// delete reaches the vendor. A pending request exists only after a real SSL/TLS ECP connection, so every
/// pending row comes from <class>OcuPilot.Test.EcpSeamPort</class>'s <code>pending</code> mode, which
/// records its actions and never sends them.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, a license without ECP
/// (every instance here), no <code>%ECPClient</code> SSL/TLS configuration (a stock instance has none),
/// and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class authorizes and
/// deletes probe SSL/TLS computer names, seeds a probe <code>%ECPClient</code> configuration and sets the
/// governance policy. Every probe name and the marked configuration are removed by exact name; after each
/// test no ECP process runs and the license reads as that test found it.</p>
Class OcuPilot.Test.EcpSslConnectionWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the ECP writes, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_ECP_CONFIG";

Parameter PROBE = "OcuPilot.Test.EcpProbe";

/// <p>The mint helper, shared with Story 18.6's suites.</p>
Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter SEAM = "OcuPilot.Test.EcpSeamPort";

Parameter ACTION = "OcuPilot.Test.EcpActionFixture";

Parameter SCREEN = "osmgmt.ecpsslconnections";

Parameter SSLTAB = "OcuPilot.Screen.Descriptor.EcpSslConnectionTab";

Parameter APPTAB = "OcuPilot.Screen.Descriptor.EcpAppServerTab";

Parameter AUTHORIZETOOL = "OcuPilot.Screen.Tool.EcpSslConnectionAuthorize";

Parameter REJECTTOOL = "OcuPilot.Screen.Tool.EcpSslConnectionReject";

Parameter DELETETOOL = "OcuPilot.Screen.Tool.EcpSslConnectionDelete";

/// <p>The two probe names this class authorizes, and the seam's pending one.</p>
Parameter NAMEA = "CN=OCUPROBEECPA";

Parameter NAMEB = "CN=OCUPROBEECPB";

Parameter PENDING = "CN=OCUPROBEECPP";

Parameter ENDPOINT = "ECP.AppServerSSLConnection";

/// <p>The governance policy as it stood before the class ran, restored after each test.</p>
Property PreparedPolicy [ MultiDimensional ];

/// <p>The license's facts before each test, which the test must leave as found.</p>
Property PreparedFacts As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.EcpSslConnectionWrite authorizes and deletes probe ECP SSL/TLS names and seeds an %ECPClient SSL/TLS configuration on this instance, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " must read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

/// <p>Every test records through the seam, unarmed, with the agent's three keys enabled over the
/// snapshot, the delete's baseline disabled among them.</p>
Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = ##class(OcuPilot.Test.LicenseProbe).LicenseFacts().%ToJSON()
    Do $ClassMethod(..#SEAM, "Clear")
    Set ^||OcuPilotDatabaseWritePort = ..#SEAM
    Kill tSettings
    For tKey = "osmgmt.ecpsslconnections.authorize", "osmgmt.ecpsslconnections.reject", "osmgmt.ecpsslconnections.delete" Set tSettings(tKey) = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Do $ClassMethod(..#SEAM, "Clear")
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe name and marked configuration is removed by exact name")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "EcpJobs"), 0, "no ECP process runs after the test")
    Do $$$AssertEquals(##class(OcuPilot.Test.LicenseProbe).LicenseFacts().%ToJSON(), ..PreparedFacts, "the license reads as before the test")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", .tRemaining))
}

/// <p>C4: a seeded authorized name is answered by the SSL/TLS tab's declared read and by
/// <code>osmgmt.ecpsslconnections.read</code> as the same row; Connections' read and
/// <code>osmgmt.ecpappservers.read</code> answer the same rows, none on a license without ECP, and the
/// read tool states the status note.</p>
Method TestBothTabsAndTheirReadToolsAnswerTheSameRows()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedAuthorized", ..#NAMEA), "a probe name is authorized")
    Set tExpected = "{""SSLComputerName"":""" _ ..#NAMEA _ """,""ClientIP"":"""",""Status"":""Authorized""}"
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#SSLTAB, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the SSL/TLS tab's read answers")
    Set tScreen = ..ProbeRows($Select($IsObject($Get(tResult)): tResult.%Get("rows"), 1: ""))
    Do $$$AssertEquals(tScreen, tExpected, "one Authorized row with no client address")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("osmgmt.ecpsslconnections.read", .tTool)
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {"maxRows": 200}, 200, .tToolResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "osmgmt.ecpsslconnections.read answers")
    Do $$$AssertEquals(..ProbeRows($Select($IsObject($Get(tToolResult)): tToolResult.%Get("rows"), 1: "")), tScreen, "with the same row")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#APPTAB, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "Connections' read answers")
    Set tScreen = $Select($IsObject($Get(tResult)) && $IsObject(tResult.%Get("rows")): tResult.%Get("rows").%ToJSON(), 1: "")
    Kill tTool
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("osmgmt.ecpappservers.read", .tTool)
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {"maxRows": 200}, 200, .tToolResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "osmgmt.ecpappservers.read answers")
    Do $$$AssertEquals($Select($IsObject($Get(tToolResult)) && $IsObject(tToolResult.%Get("rows")): tToolResult.%Get("rows").%ToJSON(), 1: ""), tScreen, "with the same rows")
    Do $$$AssertEquals(##class(OcuPilot.Port.EcpPort).NetworkEnabled() _ " " _ tScreen, "0 []", "and on a license without ECP no application server is connected")
    Set tDescription = ##class(OcuPilot.Screen.Tool.Read).Description(..#APPTAB)
    Do $$$AssertTrue($Extract(tDescription, *-$Length(##class(OcuPilot.Test.EcpDescriptor).#NOTE)+1, *) = ##class(OcuPilot.Test.EcpDescriptor).#NOTE, "the read tool's description ends with the status note: " _ tDescription)
}

/// <p>C5: a delete on both callers sends one <code>DELETE</code> naming the authorized name exactly; the
/// name leaves the list and the read-back reads it absent. The agent's card lists the name it
/// removes.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.EcpSslConnectionDelete.StateDiff</method> refuses
/// an <code>Authorized</code> row -- both deletes are refused and this goes red.</p>
Method TestADeleteRemovesTheNameOnBothCallers()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedAuthorized", ..#NAMEA), "a probe name is authorized")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedAuthorized", ..#NAMEB), "and the agent's")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, {"action": "delete", "id": (..#NAMEA)}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the tab's delete answers 200: " _ $Extract(tAnswer, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes") _ " " _ $ClassMethod(..#SEAM, "NameOf", ..#ENDPOINT _ "/DELETE"), ..#ENDPOINT _ "/DELETE " _ ..#NAMEA, "sending one DELETE naming the name exactly")
    Set tParsed = ..Parsed(tAnswer)
    Do $$$AssertEquals($Select($IsObject(tParsed): tParsed.%Get("action") _ " " _ ..Verdict(tParsed), 1: ""), "deleted notFound", "answering the delete, read back absent")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#DELETETOOL, ..#NAMEB, {"SSLComputerName": (..#NAMEB)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's delete is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($Select($IsObject(tProposal): ..Rows(tProposal.%Get("changed")) _ " " _ tProposal.%Get("target").%Get("id"), 1: ""), "SSLComputerName=" _ ..#NAMEB _ " " _ ..#NAMEB, "its card lists the name it removes, its target the name kept exactly (AD-13)")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and its confirm deletes")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), ..#ENDPOINT _ "/DELETE", "one DELETE")
    Do $$$AssertEquals(..Verdict($Get(tResult)), "notFound", "read back absent")
    Set tNames = $ListToString($ClassMethod(..#PROBE, "AuthorizedNames"))
    Do $$$AssertTrue('(("," _ tNames _ ",") [ ("," _ ..#NAMEA _ ",")) && '(("," _ tNames _ ",") [ ("," _ ..#NAMEB _ ",")), "neither name is authorized any more: " _ tNames)
}

/// <p>C5: on an <code>Authorized</code> row, Authorize and Reject are refused on both callers with the
/// not-waiting sentence and nothing is sent; on a <code>Pending</code> row (the seam's), Delete is refused
/// with the not-authorized sentence. Each refusal is the tool's <code>StateDiff</code>, because the vendor
/// answers OK for any name.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.EcpSslConnectionAuthorize.StateDiff</method>
/// accepts an <code>Authorized</code> row -- an <code>AUTHORIZE</code> is sent and this goes red.</p>
Method TestTheWrongStateIsRefusedOnBothCallersWithNothingSent()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedAuthorized", ..#NAMEA), "a probe name is authorized")
    For tCase = $ListBuild("authorize", ..#AUTHORIZETOOL), $ListBuild("reject", ..#REJECTTOOL) {
        Do $ClassMethod(..#SEAM, "Clear")
        Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, {"action": ($List(tCase, 1)), "id": (..#NAMEA)}, .tAnswer, .tStatus)
        Do $$$AssertEquals(tStatus _ " " _ ..Problem(tAnswer), "400 " _ ##class(OcuPilot.Api.EcpError).#REASONSSLNOTPENDING, $List(tCase, 1) _ " on an Authorized row: the tab's action is refused with the published sentence: " _ $Extract(tAnswer, 1, 300))
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", $List(tCase, 1) _ ": with nothing sent")
        Set tSC = $ClassMethod(..#AGENT, "Mint", $List(tCase, 2), ..#NAMEA, {"SSLComputerName": (..#NAMEA)}, .tProposal, .tHttp, .tProblem)
        Do $$$AssertTrue('$IsObject(tProposal) && (tProblem = ##class(OcuPilot.Api.EcpError).#REASONSSLNOTPENDING), $List(tCase, 1) _ ": and the agent's is refused with it: " _ tProblem)
    }
    Do $$$AssertTrue(("," _ $ListToString($ClassMethod(..#PROBE, "AuthorizedNames")) _ ",") [ ("," _ ..#NAMEA _ ","), "the name is still authorized")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $ClassMethod(..#SEAM, "Arm", "pending")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, {"action": "delete", "id": (..#PENDING)}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ..Problem(tAnswer) _ " " _ $ClassMethod(..#SEAM, "Writes"), "400 " _ ##class(OcuPilot.Api.EcpError).#REASONSSLNOTAUTHORIZED _ " ", "delete on a Pending row: the tab's delete is refused with the published sentence and nothing sent: " _ $Extract(tAnswer, 1, 300))
    Set tSC = $ClassMethod(..#AGENT, "Mint", "OcuPilot.Test.SeamEcpSslConnectionDelete", ..#PENDING, {"SSLComputerName": (..#PENDING)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertTrue('$IsObject(tProposal) && (tProblem = ##class(OcuPilot.Api.EcpError).#REASONSSLNOTAUTHORIZED), "and the agent's is refused with it: " _ tProblem)
}

/// <p>C5: a pending request (the seam's) is authorized and rejected on both callers, each one call
/// recorded and never sent, the agent's card stating the action's consequence and the read-back saying
/// nothing was sent.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Screen.Tool.EcpSslConnectionReject.WRITETYPE</parameter>
/// <code>AUTHORIZE</code> -- the reject leg records an <code>AUTHORIZE</code> and this goes red.</p>
Method TestAPendingRequestIsAuthorizedAndRejectedOnBothCallers()
{
    For tCase = $ListBuild("authorize", "AUTHORIZE", "OcuPilot.Test.SeamEcpSslConnectionAuthorize", "ECP.SSL.AUTHORIZE"), $ListBuild("reject", "REJECT", "OcuPilot.Test.SeamEcpSslConnectionReject", "ECP.SSL.REJECT") {
        Do $ClassMethod(..#SEAM, "Clear")
        Do $ClassMethod(..#SEAM, "Arm", "pending")
        Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, {"action": ($List(tCase, 1)), "id": (..#PENDING)}, .tAnswer, .tStatus)
        Do $$$AssertEquals(tStatus, 200, $List(tCase, 1) _ ": the tab's action answers 200: " _ $Extract(tAnswer, 1, 300))
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes") _ " " _ $ClassMethod(..#SEAM, "NameOf", ..#ENDPOINT _ "/" _ $List(tCase, 2)), ..#ENDPOINT _ "/" _ $List(tCase, 2) _ " " _ ..#PENDING, $List(tCase, 1) _ ": one call naming the request, recorded by the seam")
        Do $$$AssertEquals(..Verdict(tAnswer), "nothingSent", $List(tCase, 1) _ ": and its read-back says nothing was sent")
        Set tSC = $ClassMethod(..#AGENT, "Mint", $List(tCase, 3), ..#PENDING, {"SSLComputerName": (..#PENDING)}, .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ ": the agent's is minted (" _ tProblem _ ")")
        Do $$$AssertEquals(..Consequence(tProposal), $List(tCase, 4), $List(tCase, 1) _ ": its card states the consequence")
        Do $ClassMethod(..#SEAM, "Clear")
        Do $ClassMethod(..#SEAM, "Arm", "pending")
        Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", $List(tCase, 1) _ ": and its confirm answers")
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes") _ " " _ $ClassMethod(..#SEAM, "NameOf", ..#ENDPOINT _ "/" _ $List(tCase, 2)), ..#ENDPOINT _ "/" _ $List(tCase, 2) _ " " _ ..#PENDING, $List(tCase, 1) _ ": with one call recorded, naming the request")
    }
    Do $$$AssertEquals($ListLength($ClassMethod(..#PROBE, "PendingNames")) _ " " _ $ListLength($ClassMethod(..#PROBE, "ProbeDns")), "0 0", "and the instance holds no pending request and no probe name")
}

/// <p>C6: a name the instance does not list is refused on both callers with nothing sent: the tab's
/// actions 404, the agent's mint as not present, and the agent's confirm of a name deleted since its mint
/// as a changed target.</p>
Method TestAnAbsentNameIsRefusedAndNothingIsSent()
{
    For tAction = "authorize", "reject", "delete" {
        Do $ClassMethod(..#SEAM, "Clear")
        Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, {"action": (tAction), "id": "CN=OCUPROBEECPGONE"}, .tAnswer, .tStatus)
        Do $$$AssertEquals(tStatus _ " " _ ..Code(tAnswer) _ " " _ $ClassMethod(..#SEAM, "Writes"), "404 " _ ##class(OcuPilot.Api.Error).#PORTNOTFOUND _ " ", tAction _ " of an absent name: the tab's action is 404 with nothing sent: " _ $Extract(tAnswer, 1, 300))
    }
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#DELETETOOL, "CN=OCUPROBEECPGONE", {"SSLComputerName": "CN=OCUPROBEECPGONE"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ "not present"), "the agent's delete of an absent name is refused as not present: " _ tProblem)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedAuthorized", ..#NAMEA), "a probe name is authorized")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#DELETETOOL, ..#NAMEA, {"SSLComputerName": (..#NAMEA)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's delete is minted (" _ tProblem _ ")")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAuthorized", ..#NAMEA), "and the name is removed since")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "its confirm is refused as a changed target")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "with nothing sent")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedAuthorized", "cn=OcuProbeEcpC"), "a name stored in another case")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, {"action": "delete", "id": "CN=OCUPROBEECPC"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#SEAM, "Writes"), "404 ", "is not found under another spelling, the vendor matching exactly (AD-13)")
}

/// <p>C7 (DW-2006): with a disabled <code>%ECPClient</code> SSL/TLS configuration, a data server create
/// with SSL/TLS is refused <code>ECP.DATASERVER.SSLCLIENT</code> on <code>SSLConfig</code>, the vendor's
/// #1454 mapped by <class>OcuPilot.Port.EcpPort</class>, with nothing stored (measured at Task 0); and
/// enabled, the configuration reads <code>enabled</code> through <method>OcuPilot.Port.EcpPort.SslState</method>
/// from the instance's own answer.</p>
/// <p>Mutation (Rule 19): drop the <code>SSLCLIENT</code> branch from
/// <method>OcuPilot.Port.EcpPort.Put</method> -- the create answers 500 and this goes red; or misname
/// <parameter>OcuPilot.Port.EcpPort.SSLENABLEDFIELD</parameter> -- the enabled leg reads disabled and this
/// goes red.</p>
Method TestSslOverADisabledClientConfigurationIsRefusedOnItsField()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedSsl", "%ECPClient", 0, 0), "a disabled %ECPClient SSL/TLS configuration is seeded")
    Set tSC = ##class(OcuPilot.Port.EcpPort).SslState("%ECPClient", .tState, .tHttp, .tFault)
    Do $$$AssertEquals(tState, "disabled", "and reads disabled")
    Set tSC = ##class(OcuPilot.Test.EcpSaveFixture).Handle("create", "", {"Name": "ocuprobeecpsslc", "Address": "192.0.2.10", "Port": 1972, "SSLConfig": 1}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LicenseKey).Violation(tAnswer), "422 SSLConfig:" _ ##class(OcuPilot.Api.EcpError).#SSLCLIENT, "the form's create is refused on SSLConfig: " _ $Extract(tAnswer, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", "OCUPROBEECPSSLC"), 0, "and nothing is stored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnableSsl", "%ECPClient", 1), "the probe %ECPClient configuration is enabled")
    Set tSC = ##class(OcuPilot.Port.EcpPort).SslState("%ECPClient", .tState, .tHttp, .tFault)
    Do $$$AssertEquals($$$ISOK(tSC) _ " " _ tState, "1 enabled", "and reads enabled from the instance's own answer")
}

/// <p>The rows of <var>pRows</var> whose <code>SSLComputerName</code> is a probe name, each as JSON,
/// sorted by name and newline-joined.</p>
ClassMethod ProbeRows(pRows As %DynamicArray) As %String
{
    If '$IsObject(pRows) Quit "(no rows)"
    Kill tByName
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) || '##class(OcuPilot.Test.EcpProbe).IsProbeDn(tRow.%Get("SSLComputerName")) Continue
        Set tByName(tRow.%Get("SSLComputerName")) = tRow.%ToJSON()
    }
    Set tOut = ""
    Set tName = ""
    For {
        Set tName = $Order(tByName(tName))
        If tName = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: $Char(10)) _ tByName(tName)
    }
    Quit tOut
}

/// <p>A card's rows <var>pRows</var> as <code>field=before</code>, comma-joined.</p>
ClassMethod Rows(pRows As %DynamicArray) As %String
{
    If '$IsObject(pRows) Quit ""
    Set tOut = ""
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If $IsObject(tRow) Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tRow.%Get("field") _ "=" _ tRow.%Get("before")
    }
    Quit tOut
}

/// <p>The consequence code the stored proposal <var>pProposal</var> carries, or <code>""</code>.</p>
ClassMethod Consequence(pProposal) As %String
{
    Quit ##class(OcuPilot.Test.EcpSettingsWrite).Consequence(pProposal)
}

/// <p>The <code>detail.problem</code> an answer's JSON text carries, or <code>""</code>.</p>
ClassMethod Problem(pJson As %String) As %String
{
    Set tAnswer = ..Parsed(pJson)
    If '$IsObject(tAnswer) || (tAnswer.%GetTypeOf("detail") '= "object") Quit ""
    Quit tAnswer.%Get("detail").%Get("problem")
}

/// <p>The read-back verdict an answer carries, or <code>(none)</code>.</p>
ClassMethod Verdict(pAnswer) As %String
{
    Quit ##class(OcuPilot.Test.EcpSettingsWrite).Verdict(pAnswer)
}

/// <p>The envelope code an answer's JSON text carries, or <code>""</code>.</p>
ClassMethod Code(pJson As %String) As %String
{
    Quit ##class(OcuPilot.Test.EcpSettingsWrite).Code(pJson)
}

/// <p><var>pJson</var> parsed as an object, or <code>""</code>.</p>
ClassMethod Parsed(pJson As %String) As %DynamicObject
{
    Quit ##class(OcuPilot.Test.LicenseKey).Parsed(pJson)
}

}
