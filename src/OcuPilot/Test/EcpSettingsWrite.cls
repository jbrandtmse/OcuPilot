/// <p>Pins Story 18.21's ECP settings read and write on both callers of
/// <class>OcuPilot.Screen.Tool.EcpSettingsUpdate</class> (AC C1, C2, C3; AD-4, AD-53, AD-55): the form's
/// Save (<class>OcuPilot.Test.EcpSettingsSaveFixture</class>) and the agent's mint and confirm
/// (<class>OcuPilot.Test.DatabaseConfirm</class>) -- the matrix's read, change, restart, bad-value,
/// unexpected-key, <code>%ECPServer</code> and data-server-count legs.</p>
/// <p>The vendor's writes are real, except where the test arms <class>OcuPilot.Test.EcpSeamPort</class>'s
/// <code>ecpserver</code> mode: every <code>MaxServerConn</code> change and every SSL/TLS write runs
/// there, recorded and never sent, because a real <code>MaxServerConn</code> change leaves the instance
/// pending a restart that no restore clears (measured at Task 0); the seam's guard refuses one sent any
/// other way.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, no
/// <code>%ECPServer</code> SSL/TLS configuration (a stock instance has none), room for two data servers
/// under the instance's limit (two on a stock instance), and <parameter>ARMINGVARIABLE</parameter> reading
/// <code>1</code>, because the class changes the ECP settings, creates probe data servers
/// (<class>OcuPilot.Test.EcpProbe</class>) and sets the governance policy. Each test reads the settings
/// it starts from and restores them; every probe object is removed by exact name; after each test no ECP
/// process runs and the license reads as that test found it.</p>
Class OcuPilot.Test.EcpSettingsWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the ECP writes, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_ECP_CONFIG";

Parameter PROBE = "OcuPilot.Test.EcpProbe";

/// <p>The mint helper, shared with Story 18.6's suites.</p>
Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter SEAM = "OcuPilot.Test.EcpSeamPort";

Parameter SAVE = "OcuPilot.Test.EcpSettingsSaveFixture";

Parameter TOOL = "OcuPilot.Screen.Tool.EcpSettingsUpdate";

Parameter SEAMTOOL = "OcuPilot.Test.SeamEcpSettingsUpdate";

Parameter SCREEN = "OcuPilot.Screen.Descriptor.EcpSettings";

Parameter KEY = "osmgmt.ecpsettings.update";

Parameter PUT = "ECP.Settings/PUT";

/// <p>The nested body's two objects and six members, as <code>Object{members}</code>, sorted.</p>
Parameter SHAPE = "AppServerSettings{ClientReconnectDuration,ClientReconnectInterval,MaxServers},DataServerSettings{MaxServerConn,SSLECPServer,ServerTroubleDuration}";

/// <p>The governance policy as it stood before the class ran, restored after each test.</p>
Property PreparedPolicy [ MultiDimensional ];

/// <p>The ECP settings and the license's facts before each test, which the test must leave as
/// found.</p>
Property PreparedSettings As %String(MAXLEN = "") [ InitialExpression = "" ];

Property PreparedFacts As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.EcpSettingsWrite changes this instance's ECP settings and creates probe ECP data servers, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " must read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

/// <p>Every test records through the seam, unarmed, with the agent's settings key enabled over the
/// snapshot.</p>
Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = ##class(OcuPilot.Test.LicenseProbe).LicenseFacts().%ToJSON()
    Set ..PreparedSettings = $ClassMethod(..#PROBE, "Settings").%ToJSON()
    Do $ClassMethod(..#SEAM, "Clear")
    Set ^||OcuPilotDatabaseWritePort = ..#SEAM
    Kill tSettings
    Set tSettings(..#KEY) = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Do $ClassMethod(..#SEAM, "Clear")
    Set tPrepared = ##class(%DynamicObject).%FromJSON(..PreparedSettings)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RestoreSettings", tPrepared), "the ECP settings are restored")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Settings").%ToJSON(), ..PreparedSettings, "and read as before the test")
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
    Kill ^||OcuPilotDatabaseWritePort
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", .tRemaining))
}

/// <p>C1: the screen's declared read and <code>osmgmt.ecpsettings.read</code> answer the same one row of
/// the six members, as the instance stores them; and <code>GET /ecp-settings/form</code> answers, as
/// JSON, whether the license enables ECP and that the <code>%ECPServer</code> configuration is
/// absent.</p>
Method TestTheFormAndTheReadToolAnswerTheSameSixMembers()
{
    Set tStored = $ClassMethod(..#PROBE, "Settings")
    Set tExpected = "{""AppServerSettings.MaxServers"":" _ tStored.MaxServers _ ",""AppServerSettings.ClientReconnectDuration"":" _ tStored.ClientReconnectDuration _ ",""AppServerSettings.ClientReconnectInterval"":" _ tStored.ClientReconnectInterval _ ",""DataServerSettings.MaxServerConn"":" _ tStored.MaxServerConn _ ",""DataServerSettings.ServerTroubleDuration"":" _ tStored.ServerTroubleDuration _ ",""DataServerSettings.SSLECPServer"":" _ tStored.SSLECPServer _ "}"
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#SCREEN, 10, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the screen's read answers")
    Set tRows = $Select($IsObject($Get(tResult)): tResult.%Get("rows"), 1: "")
    Do $$$AssertEquals($Select($IsObject(tRows): tRows.%ToJSON(), 1: ""), "[" _ tExpected _ "]", "one row of the six members, each a number, as the instance stores them")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("osmgmt.ecpsettings.read", .tTool)
    Do $$$AssertStatusOK(tSC, "the read tool resolves")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {"maxRows": 10}, 10, .tToolResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "osmgmt.ecpsettings.read answers")
    Do $$$AssertEquals($Select($IsObject($Get(tToolResult)) && $IsObject(tToolResult.%Get("rows")): tToolResult.%Get("rows").%ToJSON(), 1: ""), "[" _ tExpected _ "]", "with the same row")
    Set tSC = ##class(OcuPilot.Port.EcpPort).SslState("%ECPServer", .tState, .tHttp, .tFault)
    Do $$$AssertEquals($$$ISOK(tSC) _ " " _ tState, "1 absent", "this instance holds no %ECPServer SSL/TLS configuration, as a stock instance does")
    Set tPath = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/ecp-settings/form"
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "GET /ecp-settings/form answers: " _ $Extract(tRaw, 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Set tForm = ..Parsed(tRaw)
    Do $$$AssertEquals($Select($IsObject(tForm): tForm.%ToJSON(), 1: ""), "{""licensed"":" _ $Select(##class(OcuPilot.Port.EcpPort).NetworkEnabled(): "true", 1: "false") _ ",""serverSsl"":""absent""}", "whether the license enables ECP, and that %ECPServer is absent")
}

/// <p>C2: a change on both callers sends one <code>PUT</code> of the nested body read fresh with the
/// change applied -- both objects complete, no query -- the agent's with one
/// <code>&lt;Object&gt;.&lt;member&gt;</code> diff row; each read-back matches, the instance stores the
/// change, no consequence is stated, and a Save that changes nothing sends nothing.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.EcpSettingsUpdate.MergeUpdate</method> sends
/// only the changed object -- the body's shape shrinks and this goes red.</p>
Method TestAChangeSendsTheNestedBodyOnBothCallers()
{
    Set tBefore = $ClassMethod(..#PROBE, "Settings")
    Set tInterval = $Select(tBefore.ClientReconnectInterval < 60: tBefore.ClientReconnectInterval + 1, 1: tBefore.ClientReconnectInterval - 1)
    Set tSC = $ClassMethod(..#SAVE, "Handle", {"AppServerSettings": {"ClientReconnectInterval": (tInterval)}}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the form's Save answers 200: " _ $Extract(tAnswer, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), ..#PUT, "sending one PUT")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "NameOf", ..#PUT), "", "with no query")
    Set tSent = ..Parsed($ClassMethod(..#SEAM, "BodyOf", ..#PUT))
    Do $$$AssertEquals(..Shape(tSent), ..#SHAPE, "carrying both objects complete")
    Do $$$AssertEquals(..Member(tSent, "AppServerSettings", "ClientReconnectInterval") _ " " _ ..Member(tSent, "AppServerSettings", "MaxServers") _ " " _ ..Member(tSent, "DataServerSettings", "MaxServerConn"), tInterval _ " " _ tBefore.MaxServers _ " " _ tBefore.MaxServerConn, "the change applied over the values read fresh")
    Set tParsed = ..Parsed(tAnswer)
    Do $$$AssertEquals(..Verdict(tParsed) _ "|" _ $Select($IsObject(tParsed): tParsed.%GetTypeOf("consequence"), 1: ""), "matches|unassigned", "its read-back matches, and it states no consequence")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Settings").ClientReconnectInterval, tInterval, "the instance stores the change")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#SAVE, "Handle", {"AppServerSettings": {"ClientReconnectInterval": (tInterval)}}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ tAnswer _ " " _ $ClassMethod(..#SEAM, "Writes"), "200 {} ", "a Save that changes nothing answers {} and sends nothing")
    Set tDuration = $Select(tBefore.ClientReconnectDuration < 65535: tBefore.ClientReconnectDuration + 1, 1: tBefore.ClientReconnectDuration - 1)
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#TOOL, "SYSTEM", {"Name": "SYSTEM", "AppServerSettings": {"ClientReconnectDuration": (tDuration)}}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's change is minted (" _ tProblem _ ")")
    Do $$$AssertEquals(..Rows(tProposal), "AppServerSettings.ClientReconnectDuration " _ tBefore.ClientReconnectDuration _ " " _ tDuration, "with one diff row naming the object and its member")
    Do $$$AssertEquals($Select($IsObject(tProposal): tProposal.%Get("unchangedCount") _ " " _ tProposal.%Get("target").%Get("id"), 1: ""), "1 SYSTEM", "the other object sent unchanged, on the singleton (AD-13)")
    Do $$$AssertEquals(..Consequence(tProposal), "", "and no consequence")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "its confirm writes")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), ..#PUT, "one PUT")
    Set tSent = ..Parsed($ClassMethod(..#SEAM, "BodyOf", ..#PUT))
    Do $$$AssertEquals(..Shape(tSent), ..#SHAPE, "of both objects complete")
    Do $$$AssertEquals(..Member(tSent, "AppServerSettings", "ClientReconnectDuration") _ " " _ ..Member(tSent, "AppServerSettings", "ClientReconnectInterval"), tDuration _ " " _ tInterval, "the change applied over the values read fresh at the confirm")
    Do $$$AssertEquals(..Verdict($Get(tResult)), "matches", "its read-back matches")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Settings").ClientReconnectDuration, tDuration, "and the instance stores it")
}

/// <p>C2: a changed <code>MaxServerConn</code>, through the seam's <code>ecpserver</code> mode on both
/// callers, states <parameter>OcuPilot.Api.EcpError.SETTINGSRESTART</parameter> -- on the Save's answer
/// and on the agent's card -- and is recorded, never sent: the instance keeps its value. Sent unarmed,
/// the seam's guard refuses it.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.EcpSettingsUpdate.Consequence</method> answers
/// <code>""</code> -- both consequence legs go red.</p>
Method TestARestartSettingIsStatedAndNeverSentForReal()
{
    Set tBefore = $ClassMethod(..#PROBE, "Settings")
    Set tConn = $Select(tBefore.MaxServerConn < 254: tBefore.MaxServerConn + 1, 1: tBefore.MaxServerConn - 1)
    Do $ClassMethod(..#SEAM, "Arm", "ecpserver")
    Set tSC = $ClassMethod(..#SAVE, "Handle", {"DataServerSettings": {"MaxServerConn": (tConn)}}, .tAnswer, .tStatus)
    Set tParsed = ..Parsed(tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tParsed): tParsed.%Get("consequence"), 1: ""), "200 " _ ##class(OcuPilot.Api.EcpError).#SETTINGSRESTART, "the form's Save states the restart consequence: " _ $Extract(tAnswer, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes") _ " " _ ..Member(..Parsed($ClassMethod(..#SEAM, "BodyOf", ..#PUT)), "DataServerSettings", "MaxServerConn"), ..#PUT _ " " _ tConn, "its one PUT carries the new number, recorded by the seam")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Settings").MaxServerConn, tBefore.MaxServerConn, "and never reaches the vendor")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#TOOL, "SYSTEM", {"Name": "SYSTEM", "DataServerSettings": {"MaxServerConn": (tConn)}}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's change is minted (" _ tProblem _ ")")
    Do $$$AssertEquals(..Rows(tProposal) _ "|" _ ..Consequence(tProposal), "DataServerSettings.MaxServerConn " _ tBefore.MaxServerConn _ " " _ tConn _ "|" _ ##class(OcuPilot.Api.EcpError).#SETTINGSRESTART, "its card names the member and states the restart consequence")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $ClassMethod(..#SEAM, "Arm", "ecpserver")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "its confirm, through the seam, answers")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes") _ " " _ $ClassMethod(..#PROBE, "Settings").MaxServerConn, ..#PUT _ " " _ tBefore.MaxServerConn, "one PUT, recorded and never sent")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#SAVE, "Handle", {"DataServerSettings": {"MaxServerConn": (tConn)}}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#SEAM, "RefusedMaxServerConn") _ " " _ $ClassMethod(..#PROBE, "Settings").MaxServerConn, "409 1 " _ tBefore.MaxServerConn, "unarmed, the seam's guard refuses it and the instance keeps its value")
}

/// <p>C3: on both callers, each value out of range or not a whole number, a member neither object names,
/// a non-object and a third top-level key is refused on its field before any vendor call, and the
/// settings stay as they were.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.OsMgmt.EcpSettingsRules.Validate</method> admits
/// <code>ClientReconnectInterval</code> 61 -- that leg is written and this goes red.</p>
Method TestBadValuesAreRefusedOnTheirFieldBeforeAnyWrite()
{
    Set tBefore = $ClassMethod(..#PROBE, "Settings").%ToJSON()
    Set tCases = $ListBuild($ListBuild("AppServerSettings", "MaxServers", 255, "number", "ECP.SETTINGS.COUNT"), $ListBuild("AppServerSettings", "MaxServers", -1, "number", "ECP.SETTINGS.COUNT"), $ListBuild("AppServerSettings", "MaxServers", 1.5, "number", "ECP.SETTINGS.COUNT"), $ListBuild("AppServerSettings", "MaxServers", "x", "string", "ECP.SETTINGS.COUNT"))
    Set tCases = tCases _ $ListBuild($ListBuild("AppServerSettings", "ClientReconnectDuration", 9, "number", "ECP.SETTINGS.RECOVERY"), $ListBuild("AppServerSettings", "ClientReconnectInterval", 61, "number", "ECP.SETTINGS.INTERVAL"), $ListBuild("AppServerSettings", "ClientReconnectInterval", 0, "number", "ECP.SETTINGS.INTERVAL"), $ListBuild("DataServerSettings", "ServerTroubleDuration", 19, "number", "ECP.SETTINGS.TROUBLE"), $ListBuild("DataServerSettings", "SSLECPServer", 3, "number", "ECP.SETTINGS.SSL.SHAPE"), $ListBuild("DataServerSettings", "MaxServerConn", 255, "number", "ECP.SETTINGS.COUNT"))
    For tC = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tC)
        Do $ClassMethod(..#SEAM, "Clear")
        Set tLabel = $List(tCase, 1) _ "." _ $List(tCase, 2) _ " " _ $List(tCase, 3)
        Set tObject = {}
        Do tObject.%Set($List(tCase, 2), $List(tCase, 3), $List(tCase, 4))
        Set tBody = {}
        Do tBody.%Set($List(tCase, 1), tObject)
        Set tSC = $ClassMethod(..#SAVE, "Handle", tBody, .tAnswer, .tStatus)
        Do $$$AssertEquals(tStatus _ " " _ ..Code(tAnswer) _ " " _ ##class(OcuPilot.Test.LicenseKey).Violation(tAnswer), "422 " _ ##class(OcuPilot.Api.EcpError).#SETTINGSVALIDATION _ " " _ $List(tCase, 1) _ "." _ $List(tCase, 2) _ ":" _ $List(tCase, 5), tLabel _ ": the form's Save is refused on its field")
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", tLabel _ ": before any vendor write")
        Do tBody.%Set("Name", "SYSTEM", "string")
        Set tSC = $ClassMethod(..#AGENT, "Mint", ..#TOOL, "SYSTEM", tBody, .tProposal, .tHttp, .tProblem)
        Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ ("'" _ $List(tCase, 1) _ "." _ $List(tCase, 2) _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation($List(tCase, 5)))), tLabel _ ": and the agent's is refused with the same sentence: " _ tProblem)
    }
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#SAVE, "Handle", {"AppServerSettings": 5}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LicenseKey).Violation(tAnswer), "422 AppServerSettings:" _ ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE, "an object that is not an object is refused on its name")
    For tCase = $ListBuild({"AppServerSettings": {"MaxServers": 2, "Foo": 1}}.%ToJSON(), "AppServerSettings.Foo"), $ListBuild({"Other": 1}.%ToJSON(), "Other") {
        Set tSC = $ClassMethod(..#SAVE, "Handle", ##class(%DynamicObject).%FromJSON($List(tCase, 1)), .tAnswer, .tStatus)
        Do $$$AssertEquals(tStatus _ " " _ ..Code(tAnswer) _ " " _ ##class(OcuPilot.Test.LicenseKey).Violation(tAnswer), "400 " _ ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED _ " " _ $List(tCase, 2) _ ":" _ ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, $List(tCase, 2) _ ": the form's Save is refused as unexpected")
    }
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#TOOL, "SYSTEM", {"Name": "SYSTEM", "AppServerSettings": {"Foo": 1}}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ "'AppServerSettings.Foo'"), "the agent's member neither object names is refused naming it: " _ tProblem)
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments($ClassMethod(..#TOOL, "InputSchema"), {"Name": "SYSTEM", "Other": 1}, .tProblem)
    Do $$$AssertTrue($$$ISERR(tSC) && (tProblem [ "Other"), "and its third top-level key is refused at dispatch: " _ tProblem)
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "nothing was written")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Settings").%ToJSON(), tBefore, "and the settings are as they were")
}

/// <p>C3: SSL/TLS support Enabled or Required while <code>%ECPServer</code> is absent (the instance's
/// own state) or disabled (the seam's) is refused on <code>DataServerSettings.SSLECPServer</code> on both
/// callers with no <code>PUT</code>; with <code>%ECPServer</code> enabled (the seam's) each caller's
/// change is sent, recorded and never stored.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.EcpPort.SettingsRefusal</method> skips its
/// <code>%ECPServer</code> check -- the absent leg's <code>PUT</code> is recorded and this goes red.</p>
Method TestSslNeedsAnEnabledServerConfiguration()
{
    For tValue = 1, 2 {
        Do $ClassMethod(..#SEAM, "Clear")
        Set tSC = $ClassMethod(..#SAVE, "Handle", {"DataServerSettings": {"SSLECPServer": (tValue)}}, .tAnswer, .tStatus)
        Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LicenseKey).Violation(tAnswer) _ " " _ $ClassMethod(..#SEAM, "Writes"), "422 DataServerSettings.SSLECPServer:" _ ##class(OcuPilot.Api.EcpError).#SETTINGSSSLSERVER _ " ", "SSL/TLS " _ tValue _ " with %ECPServer absent: the form's Save is refused on its field with no PUT: " _ $Extract(tAnswer, 1, 300))
        Set tSC = $ClassMethod(..#AGENT, "Mint", ..#TOOL, "SYSTEM", {"Name": "SYSTEM", "DataServerSettings": {"SSLECPServer": (tValue)}}, .tProposal, .tHttp, .tProblem)
        Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ ##class(OcuPilot.Api.EcpError).#REASONSETTINGSSSLSERVER), "SSL/TLS " _ tValue _ ": and the agent's is refused with its sentence: " _ tProblem)
    }
    Do $ClassMethod(..#SEAM, "Clear")
    Do $ClassMethod(..#SEAM, "ArmServerSsl", 0)
    Set tSC = $ClassMethod(..#SAVE, "Handle", {"DataServerSettings": {"SSLECPServer": 1}}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LicenseKey).Violation(tAnswer) _ " " _ $ClassMethod(..#SEAM, "Writes"), "422 DataServerSettings.SSLECPServer:" _ ##class(OcuPilot.Api.EcpError).#SETTINGSSSLSERVER _ " ", "with %ECPServer disabled, the same refusal with no PUT")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $ClassMethod(..#SEAM, "ArmServerSsl", 1)
    Set tSC = $ClassMethod(..#SAVE, "Handle", {"DataServerSettings": {"SSLECPServer": 1}}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#SEAM, "Writes") _ " " _ ..Member(..Parsed($ClassMethod(..#SEAM, "BodyOf", ..#PUT)), "DataServerSettings", "SSLECPServer"), "200 " _ ..#PUT _ " 1", "with %ECPServer enabled, the form's Save sends SSL/TLS 1: " _ $Extract(tAnswer, 1, 300))
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#SEAMTOOL, "SYSTEM", {"Name": "SYSTEM", "DataServerSettings": {"SSLECPServer": 2}}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "and the agent's Required is minted (" _ tProblem _ ")")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $ClassMethod(..#SEAM, "ArmServerSsl", 1)
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "its confirm answers")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes") _ " " _ ..Member(..Parsed($ClassMethod(..#SEAM, "BodyOf", ..#PUT)), "DataServerSettings", "SSLECPServer"), ..#PUT _ " 2", "sending SSL/TLS 2")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Settings").SSLECPServer, 0, "each recorded by the seam, and the instance's SSL/TLS support stays Disabled")
}

/// <p>A maximum number of data servers below the data servers the instance defines is refused on
/// <code>AppServerSettings.MaxServers</code> on both callers before any vendor call, so a change sent
/// beside it is not stored either, where the vendor would store it and then refuse the number (#456,
/// measured at Task 0).</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.EcpPort.SettingsRefusal</method> skips its data server
/// count -- the <code>PUT</code> is sent and this goes red.</p>
Method TestAMaximumBelowTheDataServersIsRefusedBeforeAnyWrite()
{
    Set tBefore = $ClassMethod(..#PROBE, "Settings")
    If tBefore.MaxServers < 2 {
        Do $$$AssertTrue(0, "this instance allows " _ tBefore.MaxServers _ " data servers, and the test needs room for two (a stock instance's MaxServers is 2)")
        Quit
    }
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBEECPS1"), "a probe data server")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBEECPS2"), "and a second")
    Set tDefined = $ClassMethod(..#PROBE, "ServerCount")
    Set tInterval = $Select(tBefore.ClientReconnectInterval < 60: tBefore.ClientReconnectInterval + 1, 1: tBefore.ClientReconnectInterval - 1)
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#SAVE, "Handle", {"AppServerSettings": {"MaxServers": (tDefined - 1), "ClientReconnectInterval": (tInterval)}}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LicenseKey).Violation(tAnswer) _ " " _ $ClassMethod(..#SEAM, "Writes"), "422 AppServerSettings.MaxServers:" _ ##class(OcuPilot.Api.EcpError).#SETTINGSSERVERS _ " ", "the form's Save is refused on MaxServers with no PUT: " _ $Extract(tAnswer, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Settings").ClientReconnectInterval, tBefore.ClientReconnectInterval, "and the change beside it is not stored")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#TOOL, "SYSTEM", {"Name": "SYSTEM", "AppServerSettings": {"MaxServers": (tDefined - 1)}}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ ##class(OcuPilot.Api.EcpError).#REASONSETTINGSSERVERS), "the agent's is refused with its sentence: " _ tProblem)
}

/// <p>The nested body <var>pBody</var>'s shape, as <parameter>SHAPE</parameter> spells it.</p>
ClassMethod Shape(pBody) As %String
{
    If '$IsObject(pBody) Quit ""
    Kill tGroups
    Set tIterator = pBody.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tGroups(tKey) = ##class(OcuPilot.Test.LicenseKey).Keys($Select($IsObject(tValue): tValue, 1: ""))
    }
    Set tOut = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tGroups(tKey))
        If tKey = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tKey _ "{" _ tGroups(tKey) _ "}"
    }
    Quit tOut
}

/// <p><var>pBody</var>'s member <var>pMember</var> of its object <var>pGroup</var>, or
/// <code>""</code>.</p>
ClassMethod Member(pBody, pGroup As %String, pMember As %String) As %String
{
    If '$IsObject(pBody) || (pBody.%GetTypeOf(pGroup) '= "object") Quit ""
    Quit pBody.%Get(pGroup).%Get(pMember)
}

/// <p>A proposal's rows as <code>field before after</code>, one row expected.</p>
ClassMethod Rows(pProposal) As %String
{
    If '$IsObject(pProposal) Quit "(no proposal)"
    Set tRows = pProposal.%Get("changed")
    If '$IsObject(tRows) || (tRows.%Size() '= 1) Quit $Select($IsObject(tRows): tRows.%ToJSON(), 1: "")
    Set tRow = tRows.%Get(0)
    Quit tRow.%Get("field") _ " " _ tRow.%Get("before") _ " " _ tRow.%Get("after")
}

/// <p>The consequence code the stored proposal <var>pProposal</var> carries, or <code>""</code>.</p>
ClassMethod Consequence(pProposal) As %String
{
    If '$IsObject(pProposal) Quit ""
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(pProposal.%Get("proposalId"), .tFound, .tValues)
    If $$$ISERR(tSC) || '$Get(tFound) Quit ""
    Quit $Get(tValues("consequence"))
}

/// <p>The read-back verdict an answer carries, the answer an object or its JSON text, or
/// <code>(none)</code>.</p>
ClassMethod Verdict(pAnswer) As %String
{
    Set tAnswer = pAnswer
    If '$IsObject(tAnswer) Set tAnswer = ..Parsed(tAnswer)
    If '$IsObject(tAnswer) || (tAnswer.%GetTypeOf("readBack") '= "object") Quit "(none)"
    Quit tAnswer.%Get("readBack").%Get("verdict")
}

/// <p>The envelope code an answer's JSON text carries, or <code>""</code>.</p>
ClassMethod Code(pJson As %String) As %String
{
    Set tAnswer = ..Parsed(pJson)
    If '$IsObject(tAnswer) Quit ""
    Quit tAnswer.%Get("code")
}

/// <p><var>pJson</var> parsed as an object, or <code>""</code>.</p>
ClassMethod Parsed(pJson As %String) As %DynamicObject
{
    Quit ##class(OcuPilot.Test.LicenseKey).Parsed(pJson)
}

}
