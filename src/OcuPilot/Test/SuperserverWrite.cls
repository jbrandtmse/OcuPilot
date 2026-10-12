/// <p>Pins Story 18.25's writes on both callers of each tool (B2, B3, B4): the form's Save
/// (<class>OcuPilot.Test.SuperserverSaveFixture</class>) and the list's Delete
/// (<class>OcuPilot.Test.SuperserverActionFixture</class>), and the agent's mint and confirm
/// (<class>OcuPilot.Test.DatabaseConfirm</class>) -- a create, a change that sends the complete set less
/// <code>SystemDefault</code>, a delete, every row of the rules refused before any <code>PUT</code>, a taken name,
/// a moved target, a held lock and a taken port, and a probe superserver the serving port names.</p>
/// <p>The vendor's writes are real for ports 21825 to 21829 and refused for any other:
/// <class>OcuPilot.Test.SuperserverSeamPort</class> records every call and forwards a write for a probe port
/// alone. The success path of a server SSL/TLS configuration is a seam answer: the vendor refuses to create one
/// without certificate and key files (#982), so no real one exists.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, a stock instance whose one
/// superserver is 1972, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class
/// creates, changes and deletes probe superservers and sets the governance policy. Every probe superserver is
/// removed by exact port before all, after each and after all, and after each test the superserver list reads as
/// that test found it.</p>
Class OcuPilot.Test.SuperserverWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the writes, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_SERVICE_CONFIG";

Parameter PROBE = "OcuPilot.Test.SuperserverProbe";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter SEAM = "OcuPilot.Test.SuperserverSeamPort";

Parameter SAVE = "OcuPilot.Test.SuperserverSaveFixture";

Parameter ACTION = "OcuPilot.Test.SuperserverActionFixture";

Parameter CREATETOOL = "OcuPilot.Test.SeamSuperserverCreate";

Parameter UPDATETOOL = "OcuPilot.Test.SeamSuperserverUpdate";

Parameter DELETETOOL = "OcuPilot.Test.SeamSuperserverDelete";

Parameter SCREEN = "security.superservers";

Parameter PUT = "Security.Superserver/PUT";

/// <p>The fifteen keys a change sends, sorted: the complete set less <code>SystemDefault</code>.</p>
Parameter FIFTEENKEYS = "Description,EnableCSP,EnableCacheDirect,EnableClients,EnableDataCheck,EnableECP,EnableMirror,EnableNodeJS,EnableSNMP,EnableShadows,EnableSharding,EnableWebLink,Enabled,SSLConfig,SSLSupportLevel";

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

Property PreparedFacts As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SuperserverWrite creates, changes and deletes probe superservers on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll")
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = $ClassMethod(..#PROBE, "Facts")
    Do $ClassMethod(..#SEAM, "Clear")
    Kill ^||OcuPilotSuperserverServing, ^||OcuPilotSuperserverWindows
    Set ^||OcuPilotDatabaseWritePort = ..#SEAM
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("OcuPilot.Test.SuperserverSet")
    Kill tSettings
    Set tSettings("security.superservers.create") = "enabled"
    Set tSettings("security.superservers.update") = "enabled"
    Set tSettings("security.superservers.delete") = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort, ^||OcuPilotSuperserverServing, ^||OcuPilotSuperserverWindows
    Do $ClassMethod(..#SEAM, "Clear")
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("")
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll"), "every probe superserver is removed by exact port")
    Do $$$AssertNotEquals(..PreparedFacts, "unreadable", "the superserver list was read before the test")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts"), ..PreparedFacts, "the superserver list reads as before the test")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll"))
}

/// <p>B2: a create on both callers sends one <code>PUT</code> carrying only the settings supplied and never
/// <code>SystemDefault</code>; the instance listens on the port at once, the id is the canonical composite, and
/// the read-back matches.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.SuperserverPort.SplitId</method> drop the port -- both
/// legs reach the vendor with no port and go red.</p>
Method TestACreateSendsOnlyTheSuppliedSettingsOnBothCallers()
{
    Set tSC = $ClassMethod(..#SAVE, "Handle", "", {"Port": "21825", "BindAddress": "", "EnableCSP": true, "Description": "a probe"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 201, "the form's create answers 201: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "PUT:21825", "sending one PUT")
    Set tSent = ##class(OcuPilot.Test.LicenseKey).Parsed($ClassMethod(..#SEAM, "BodyOf", ..#PUT))
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tSent), "Description,EnableCSP", "carrying the two settings supplied and no SystemDefault")
    Set tParsed = ##class(OcuPilot.Test.LicenseKey).Parsed(tAnswer)
    Do $$$AssertEquals($Select($IsObject(tParsed) && $IsObject(tParsed.%Get("readBack")): tParsed.%Get("id") _ " " _ tParsed.%Get("readBack").%Get("verdict"), 1: ""), $ClassMethod(..#PROBE, "Id", 21825) _ " matches", "the canonical id, and the read-back matches")
    Set tStored = $ClassMethod(..#PROBE, "Stored", 21825)
    Do $$$AssertEquals($Select($IsObject(tStored): tStored.%Get("EnableCSP") _ tStored.%Get("Enabled") _ tStored.%Get("Description"), 1: ""), "11a probe", "the instance stores it, listening")

    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, {"Port": "21826", "BindAddress": "", "EnableCSP": true}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's create is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and confirmed")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "PUT:21826", "sending one PUT")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(##class(OcuPilot.Test.LicenseKey).Parsed($ClassMethod(..#SEAM, "BodyOf", ..#PUT))), "EnableCSP", "carrying the one setting supplied")
    Do $$$AssertEquals(..Verdict($Get(tResult)), "matches", "its read-back matches")
    Do $$$AssertTrue($IsObject($ClassMethod(..#PROBE, "Stored", 21826)), "and the instance holds it")
}

/// <p>B2: a change on both callers sends the complete set less <code>SystemDefault</code> -- fifteen keys, the
/// others as the instance held them -- and nothing else moves; the form's own change of nothing sends nothing.</p>
/// <p>Mutation (Rule 19): drop <code>SystemDefault</code> from
/// <parameter>OcuPilot.Screen.Tool.SuperserverUpdate.UNSENTFIELDS</parameter> -- both legs send it and go
/// red.</p>
Method TestAChangeSendsTheCompleteSetLessSystemDefaultOnBothCallers()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", 21825, {"EnableCSP": true, "Description": "before"}), "a probe superserver")
    Set tId = $ClassMethod(..#PROBE, "Id", 21825)
    Set tSC = $ClassMethod(..#SAVE, "Handle", tId, {"Description": "by the form"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the form's change answers 200: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "PUT:21825", "sending one PUT")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(##class(OcuPilot.Test.LicenseKey).Parsed($ClassMethod(..#SEAM, "BodyOf", ..#PUT))), ..Sorted(..#FIFTEENKEYS), "carrying the fifteen keys and no SystemDefault")
    Do $$$AssertEquals(..Verdict(##class(OcuPilot.Test.LicenseKey).Parsed(tAnswer)), "matches", "the read-back matches")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", 21825).%Get("Description") _ $ClassMethod(..#PROBE, "Stored", 21825).%Get("EnableCSP"), "by the form1", "the instance holds the change and kept every other setting")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#SAVE, "Handle", tId, {"Description": "by the form"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#SEAM, "Writes"), "200 ", "a change that changes nothing sends nothing")

    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, {"Port": "21825", "BindAddress": "0.0.0.0", "Description": "by the agent"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's change is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and confirmed")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "PUT:21825", "sending one PUT")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(##class(OcuPilot.Test.LicenseKey).Parsed($ClassMethod(..#SEAM, "BodyOf", ..#PUT))), ..Sorted(..#FIFTEENKEYS), "carrying the same fifteen keys")
    Do $$$AssertEquals(..Verdict($Get(tResult)), "matches", "its read-back matches")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", 21825).%Get("Description"), "by the agent", "and the instance holds it")
}

/// <p>B2: a delete on both callers removes the superserver and its listener, reads back absent, and a delete of
/// one the instance does not hold is 404 <code>PORT.NOTFOUND</code> with no write.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.SuperserverPort.SplitId</method> drop the port -- the vendor
/// refuses the delete and both legs go red.</p>
Method TestADeleteRemovesTheSuperserverOnBothCallers()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", 21825), "a probe superserver")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, {"action": "delete", "id": ($ClassMethod(..#PROBE, "Id", 21825))}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the list's Delete answers 200: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "DELETE:21825", "sending one DELETE")
    Do $$$AssertEquals($IsObject($ClassMethod(..#PROBE, "Stored", 21825)), 0, "and the instance no longer holds it")
    Do $$$AssertEquals(..Verdict(##class(OcuPilot.Test.LicenseKey).Parsed(tAnswer)), "notFound", "its read-back reads notFound: " _ $Extract(tAnswer, 1, 200))
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, {"action": "delete", "id": ($ClassMethod(..#PROBE, "Id", 21829))}, .tAnswer, .tStatus)
    Set tParsed = ##class(OcuPilot.Test.LicenseKey).Parsed(tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ tParsed.%Get("code") _ " " _ $ClassMethod(..#SEAM, "Writes"), "404 PORT.NOTFOUND ", "a superserver the instance does not hold is 404 with no write: " _ $Extract(tAnswer, 1, 200))

    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", 21826), "a second probe superserver")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#DELETETOOL, {"Port": "21826", "BindAddress": ""}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's delete is minted (" _ tProblem _ ")")
    Do $$$AssertEquals(##class(OcuPilot.Test.SuperserverProhibited).Stored(tProposal, "destructive"), 1, "destructive")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and confirmed")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "DELETE:21826", "sending one DELETE")
    Do $$$AssertEquals($IsObject($ClassMethod(..#PROBE, "Stored", 21826)), 0, "and the instance no longer holds it")
}

/// <p>B3: every row of the rules is refused on its field before any <code>PUT</code>, by the form's Save as a
/// 422 <code>SUPERSERVER.VALIDATION</code> carrying the violation and by the agent's mint as its problem, naming
/// the field and the published sentence.</p>
/// <p>Mutation (Rule 19): drop the <code>SYSTEMONLY</code> rule from
/// <method>OcuPilot.Area.Security.SuperserverRules.Check</method> -- its three legs send the <code>PUT</code> and
/// go red; drop the bind address rule -- the bind address legs go red.</p>
Method TestEveryRulesRowIsRefusedBeforeAnyPutOnBothCallers()
{
    Set tTooLong = $Translate($Justify("", 257), " ", "x")
    Set tErrors = "OcuPilot.Api.SuperserverError"
    Set tShape = ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE
    Set tCases = ""
    Set tCases = tCases _ $ListBuild($ListBuild("port 99", "{""Port"": ""99""}", "Port", $Parameter(tErrors, "PORT")))
    Set tCases = tCases _ $ListBuild($ListBuild("port 65536", "{""Port"": ""65536""}", "Port", $Parameter(tErrors, "PORT")))
    Set tCases = tCases _ $ListBuild($ListBuild("port abc", "{""Port"": ""abc""}", "Port", $Parameter(tErrors, "PORT")))
    Set tCases = tCases _ $ListBuild($ListBuild("port 12.5", "{""Port"": ""12.5""}", "Port", $Parameter(tErrors, "PORT")))
    Set tCases = tCases _ $ListBuild($ListBuild("description over 256", "{""Port"": ""21825"", ""Description"": """ _ tTooLong _ """}", "Description", $Parameter(tErrors, "DESCRIPTION")))
    Set tCases = tCases _ $ListBuild($ListBuild("level 3", "{""Port"": ""21825"", ""SSLSupportLevel"": 3}", "SSLSupportLevel", $Parameter(tErrors, "SSLLEVEL")))
    Set tCases = tCases _ $ListBuild($ListBuild("level x", "{""Port"": ""21825"", ""SSLSupportLevel"": ""x""}", "SSLSupportLevel", $Parameter(tErrors, "SSLLEVEL")))
    Set tCases = tCases _ $ListBuild($ListBuild("level 1, no configuration", "{""Port"": ""21825"", ""SSLSupportLevel"": 1}", "SSLConfig", $Parameter(tErrors, "SSLCONFIG")))
    Set tCases = tCases _ $ListBuild($ListBuild("level 1, absent configuration", "{""Port"": ""21825"", ""SSLSupportLevel"": 1, ""SSLConfig"": ""OcuNoSuchTLS""}", "SSLConfig", $Parameter(tErrors, "SSLCONFIG")))
    Set tCases = tCases _ $ListBuild($ListBuild("level 2, client configuration", "{""Port"": ""21825"", ""SSLSupportLevel"": 2, ""SSLConfig"": ""OcuPilotDemoTLS""}", "SSLConfig", $Parameter(tErrors, "SSLCONFIG")))
    Set tCases = tCases _ $ListBuild($ListBuild("level 0, absent configuration named", "{""Port"": ""21825"", ""SSLConfig"": ""OcuNoSuchTLS""}", "SSLConfig", $Parameter(tErrors, "SSLCONFIG")))
    Set tCases = tCases _ $ListBuild($ListBuild("ECP on a probe", "{""Port"": ""21825"", ""EnableECP"": true}", "EnableECP", $Parameter(tErrors, "SYSTEMONLY")))
    Set tCases = tCases _ $ListBuild($ListBuild("mirroring on a probe", "{""Port"": ""21825"", ""EnableMirror"": true}", "EnableMirror", $Parameter(tErrors, "SYSTEMONLY")))
    Set tCases = tCases _ $ListBuild($ListBuild("sharding on a probe", "{""Port"": ""21825"", ""EnableSharding"": true}", "EnableSharding", $Parameter(tErrors, "SYSTEMONLY")))
    Set tCases = tCases _ $ListBuild($ListBuild("SNMP off Windows", "{""Port"": ""21825"", ""EnableSNMP"": true}", "EnableSNMP", $Parameter(tErrors, "SNMP")))
    Set tCases = tCases _ $ListBuild($ListBuild("a flag that is not true or false", "{""Port"": ""21825"", ""EnableCSP"": ""maybe""}", "EnableCSP", tShape))
    Set ^||OcuPilotSuperserverWindows = 0
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tBody = ##class(%DynamicObject).%FromJSON($List(tCase, 2))
        Do $ClassMethod(..#SEAM, "Clear")
        Set tSC = $ClassMethod(..#SAVE, "Handle", "", tBody, .tAnswer, .tStatus)
        Set tWhy = ..ViolationOf(tAnswer, $List(tCase, 3))
        Do $$$AssertEquals(tStatus _ " " _ tWhy, "422 " _ $List(tCase, 4), $List(tCase, 1) _ ": the Save is refused on " _ $List(tCase, 3) _ ": " _ $Extract(tAnswer, 1, 200))
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", $List(tCase, 1) _ ": before any PUT")
        Set tMinted = ##class(%DynamicObject).%FromJSON($List(tCase, 2))
        Do tMinted.%Set("BindAddress", "")
        Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, tMinted, .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusNotOK(tSC, $List(tCase, 1) _ ": the agent's mint is refused")
        Do $$$AssertTrue(tProblem [ ("'" _ $List(tCase, 3) _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation($List(tCase, 4))), $List(tCase, 1) _ ": naming the field and the published sentence: " _ tProblem)
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", $List(tCase, 1) _ ": and no PUT")
    }
    Set tBindReason = ##class(OcuPilot.Api.Error).ReasonForViolation($Parameter(tErrors, "BINDADDRESS"))
    For tBind = "local host", "localhost:21825", "host!name", "a" _ $Char(2) _ "b" {
        Do $ClassMethod(..#SEAM, "Clear")
        Set tSC = $ClassMethod(..#SAVE, "Handle", "", {"Port": "21825", "BindAddress": (tBind)}, .tAnswer, .tStatus)
        Do $$$AssertEquals(tStatus _ " " _ ..ViolationOf(tAnswer, "BindAddress") _ " " _ $ClassMethod(..#SEAM, "Calls"), "422 " _ $Parameter(tErrors, "BINDADDRESS") _ " ", "bind address " _ $ZConvert(tBind, "O", "JSON") _ ": the Save is refused on BindAddress before any call: " _ $Extract(tAnswer, 1, 200))
        Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, {"Port": "21825", "BindAddress": (tBind)}, .tProposal, .tHttp, .tProblem)
        Do $$$AssertTrue(tProblem [ ("'BindAddress': " _ tBindReason), "bind address " _ $ZConvert(tBind, "O", "JSON") _ ": the agent's mint is refused naming it: " _ tProblem)
    }
    Set tSC = $ClassMethod(..#SAVE, "Handle", "", {"Port": "21825", "BindAddress": 127}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ..ViolationOf(tAnswer, "BindAddress"), "422 " _ tShape, "a bind address that is not text is refused on its field: " _ $Extract(tAnswer, 1, 200))
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, {"Port": "21825", "BindAddress": 127}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertTrue($$$ISERR(tSC) && (tProblem [ "'BindAddress'"), "and the agent's mint of it is refused: " _ tProblem)
    For tBind = "", "0.0.0.0", "127.0.0.1", "LOCALHOST", "probe-host.example.com", "::1" {
        Do $$$AssertTrue(##class(OcuPilot.Area.Security.SuperserverRules).IsBindAddress(tBind), "'" _ tBind _ "' is an address the instance takes")
    }
    For tBind = "1.2.3.4.5", $Translate($Justify("", 256), " ", "h") {
        Do $$$AssertTrue('##class(OcuPilot.Area.Security.SuperserverRules).IsBindAddress(tBind), "'" _ $Extract(tBind, 1, 20) _ "' is not")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Remaining"), 0, "no probe superserver was created")
}

/// <p>B3: the rules that read the superserver refuse a change on a probe -- ECP, level 1 with no configuration
/// and a configuration naming no server one -- on both callers before any <code>PUT</code>; a level of 1 with a
/// configuration the seam answers as a server configuration is sent.</p>
/// <p>Lowering the level to 0 never reads a configuration it does not change.</p>
/// <p>Mutation (Rule 19): skip the SSL rules in <method>OcuPilot.Area.Security.SuperserverRules.SslRules</method>
/// -- the refusal legs send the <code>PUT</code> and go red; check a sent configuration that did not change -- the
/// level 0 leg goes red.</p>
Method TestTheRulesThatReadTheSuperserverRefuseAChange()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", 21825), "a probe superserver")
    Set tId = $ClassMethod(..#PROBE, "Id", 21825)
    Set tErrors = "OcuPilot.Api.SuperserverError"
    Set tShapes = ""
    Set tShapes = tShapes _ $ListBuild($ListBuild("ECP", "{""EnableECP"":true}", "EnableECP", $Parameter(tErrors, "SYSTEMONLY")))
    Set tShapes = tShapes _ $ListBuild($ListBuild("level 1, no configuration", "{""SSLSupportLevel"":1}", "SSLConfig", $Parameter(tErrors, "SSLCONFIG")))
    Set tShapes = tShapes _ $ListBuild($ListBuild("a configuration naming no server one", "{""SSLConfig"":""OcuPilotDemoTLS""}", "SSLConfig", $Parameter(tErrors, "SSLCONFIG")))
    For tI = 1:1:$ListLength(tShapes) {
        Set tCase = $List(tShapes, tI)
        Do $ClassMethod(..#SEAM, "Clear")
        Set tSC = $ClassMethod(..#SAVE, "Handle", tId, ##class(%DynamicObject).%FromJSON($List(tCase, 2)), .tAnswer, .tStatus)
        Do $$$AssertEquals(tStatus _ " " _ ..ViolationOf(tAnswer, $List(tCase, 3)), "422 " _ $List(tCase, 4), $List(tCase, 1) _ ": the Save is refused: " _ $Extract(tAnswer, 1, 200))
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", $List(tCase, 1) _ ": before any PUT")
        Set tArgs = ##class(%DynamicObject).%FromJSON($List(tCase, 2))
        Do tArgs.%Set("Port", "21825")
        Do tArgs.%Set("BindAddress", "")
        Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, tArgs, .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusNotOK(tSC, $List(tCase, 1) _ ": the agent's mint is refused (" _ tProblem _ ")")
        Do $$$AssertTrue(tProblem [ ("'" _ $List(tCase, 3) _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation($List(tCase, 4))), $List(tCase, 1) _ ": naming the field and the sentence")
    }
    Do $ClassMethod(..#SEAM, "Clear")
    Do $ClassMethod(..#SEAM, "Arm", "answer")
    Set tSC = $ClassMethod(..#SAVE, "Handle", tId, {"SSLSupportLevel": 1, "SSLConfig": "OcuProbeServerTLS"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#SEAM, "Writes"), "200 PUT:21825", "level 1 with a server configuration is sent: " _ $Extract(tAnswer, 1, 200))
    Set tSent = ##class(OcuPilot.Test.LicenseKey).Parsed($ClassMethod(..#SEAM, "BodyOf", ..#PUT))
    Do $$$AssertEquals(tSent.%Get("SSLSupportLevel") _ " " _ tSent.%Get("SSLConfig"), "1 OcuProbeServerTLS", "carrying both")
    Do $$$AssertEquals($IsObject($ClassMethod(..#PROBE, "Stored", 21825)) && ($ClassMethod(..#PROBE, "Stored", 21825).%Get("SSLSupportLevel") = 0), 1, "and the instance, which the seam did not write, is unchanged")
    Set tSC = ##class(OcuPilot.Test.SuperserverRulesSeam).Check("", {"SSLSupportLevel": 0, "SSLConfig": "OcuNoSuchTLS"}, {"SSLSupportLevel": 1, "SSLConfig": "OcuNoSuchTLS", "SystemDefault": false}, "update", ..#SEAM, .tViolations, 1)
    Do $$$AssertEquals($System.Status.IsOK(tSC) _ " " _ tViolations, "1 0", "lowering the level to 0 keeps a stored configuration the instance no longer holds unread")
}

/// <p>B2: a name taken since is refused by the absence fingerprint and by the Save's own look-up, a target moved
/// since the mint refuses the confirm as changed, and a target another write holds answers 409
/// <code>WRITE.TARGETBUSY</code> after the wait, with no write.</p>
/// <p>Mutation (Rule 19): drop the <code>HoldTool</code> from
/// <method>OcuPilot.Area.Security.SuperserverSave.HandleUpdate</method> -- the busy leg writes and goes red; let
/// a create's confirm re-read match whatever it finds -- the taken-since leg writes and goes red.</p>
Method TestATakenNameAMovedTargetAndABusyTargetAreRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", 21825, {"Description": "first", "EnableCSP": true}), "a probe superserver")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#SAVE, "Handle", "", {"Port": "21825", "BindAddress": "0.0.0.0"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ..ViolationOf(tAnswer, "Port") _ " " _ $ClassMethod(..#SEAM, "Writes"), "422 " _ $Parameter("OcuPilot.Api.SuperserverError", "TAKEN") _ " ", "a create of a taken port and address is refused on Port with no write: " _ $Extract(tAnswer, 1, 200))
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, {"Port": "21825", "BindAddress": ""}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusNotOK(tSC, "the agent's create of it is refused at the mint: " _ tProblem)
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, {"Port": "21827", "BindAddress": ""}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "a create of a free port is minted (" _ tProblem _ ")")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", 21827), "and the port and address are taken since")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "its confirm is refused by the absence fingerprint")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "with no write")

    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, {"Port": "21825", "Description": "second"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "a change is minted (" _ tProblem _ ")")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", 21825, {"EnableCSP": false}), "and a setting the payload carries moves")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "its confirm is refused as a changed target")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "with no write")

    Set tId = $ClassMethod(..#PROBE, "Id", 21825)
    Do ##class(OcuPilot.Kernel.EntityRef).Key("superserver", "instance", tId, .tRef)
    Set tLockKey = ##class(OcuPilot.Kernel.State.Propose).TargetHoldKey(tRef)
    Do $$$AssertNotEquals(tLockKey, "", "the superserver names a lock")
    Lock +^OcuPilotProposalTarget(tLockKey):5
    Set tHeld = $Test
    Do $$$AssertTrue(tHeld, "which this process holds, as another write's hold does")
    If 'tHeld Quit
    Set tStatus = 0
    Set tBody = ""
    Try {
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/superserver/" _ ##class(OcuPilot.Kernel.EntityId).Encode(tId), .tStatus, .tBody, {"Description": "busy"}.%ToJSON(), "application/json")
    } Catch {
    }
    Lock -^OcuPilotProposalTarget(tLockKey)
    Set tAnswer = tStatus _ " " _ $Select($IsObject(tBody): tBody.%Get("code") _ " " _ tBody.%Get("reason"), 1: tBody)
    Do $$$AssertEquals(tAnswer, "409 WRITE.TARGETBUSY " _ ##class(OcuPilot.Api.Error).#REASONWRITETARGETBUSY, "the held Save is refused busy, with the published reason")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", 21825).%Get("Description"), "first", "and nothing was written")
}

/// <p>B2: a write that would start a listener on a taken port is refused 409
/// <code>SUPERSERVER.PORT.INUSE</code> on <code>Port</code> -- a create, and <code>Enabled</code> turned on --
/// with nothing stored; any other write the vendor refuses with the same code stays the vendor's fault. The
/// vendor's measured <code>#5001</code> answer is the seam's, so no port is actually taken.</p>
/// <p>Mutation (Rule 19): answer 1 for any write once the stored row reads in
/// <method>OcuPilot.Port.SuperserverPort.StartsListener</method> -- the other-fault leg goes red; keep the
/// mapped row on a call that is not a <code>PUT</code> -- the delete leg goes red.</p>
Method TestATakenPortIsRefusedOnItsFieldWhenTheWriteStartsAListener()
{
    Do $ClassMethod(..#SEAM, "Arm", "inuse")
    Set tSC = $ClassMethod(..#SAVE, "Handle", "", {"Port": "21825", "BindAddress": ""}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ..ViolationOf(tAnswer, "Port"), "409 " _ $Parameter("OcuPilot.Api.SuperserverError", "INUSE"), "a create on a taken port is 409 on Port: " _ $Extract(tAnswer, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes") _ " " _ $ClassMethod(..#PROBE, "Remaining"), "PUT:21825 0", "the PUT was answered by the seam and nothing is stored")
    Do $$$AssertEquals($Piece(tAnswer, "vendor", 2), "", "no vendor text reaches the answer")

    Do $ClassMethod(..#SEAM, "Arm", "")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", 21826, {"Enabled": false}), "a disabled probe superserver")
    Do $ClassMethod(..#SEAM, "Arm", "inuse")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $ClassMethod(..#SEAM, "Arm", "inuse")
    Set tId = $ClassMethod(..#PROBE, "Id", 21826)
    Set tSC = $ClassMethod(..#SAVE, "Handle", tId, {"Enabled": true}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ..ViolationOf(tAnswer, "Port"), "409 " _ $Parameter("OcuPilot.Api.SuperserverError", "INUSE"), "turning Enabled on is 409 on Port: " _ $Extract(tAnswer, 1, 300))

    Kill tQuery
    Set tQuery("port") = tId
    Set tBodyOther = {"Description": "other"}
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Security.Superserver", "PUT", .tQuery, tBodyOther, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ ..FaultHasViolations($Get(tFault)), "500 0", "any other write the vendor refuses for the same code is its 500, without the mapped row")
    Set tSC = $ClassMethod(..#SEAM, "Invoke", "Security.Superserver", "DELETE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ ..FaultHasViolations($Get(tFault)), "500 0", "and so is a delete the vendor refuses with that code")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", 21826).%Get("Enabled"), 0, "and the disabled probe is as it was")
}

/// <p>B4: the form read answers a probe as not serving, with nothing locked; with the serving request's port
/// naming it, it is serving, <code>Enabled</code> and <code>EnableCSP</code> are locked and the prohibited set
/// refuses turning either off, deleting it and requiring SSL/TLS of it, from the Save and the confirm, with no
/// write; any other change to it is permitted, and an SSL/TLS change answers its consequence.</p>
/// <p>Mutation (Rule 19): answer 0 for a port that matches the serving port in
/// <method>OcuPilot.Kernel.Proposal.Prohibited.IsServingSuperserver</method> -- the serving legs go red; drop the
/// Save's effect read -- the consequence leg goes red.</p>
Method TestAProbeOnTheServingPortIsRefusedTheSameFourChanges()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", 21826, {"EnableCSP": true}), "a probe superserver")
    Set tId = $ClassMethod(..#PROBE, "Id", 21826)
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/superserver/form?id=" _ ##class(OcuPilot.Test.SuperserverProbe).QueryId(tId), ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders)
    Set tForm = ##class(OcuPilot.Test.LicenseKey).Parsed(tRaw)
    Do $$$AssertEquals(tStatus _ " " _ tForm.%Get("serving") _ " " _ tForm.%Get("locked").%Size() _ " " _ tForm.%Get("row").%Get("Port") _ " " _ tForm.%Get("row").%Get("SystemDefault"), "200 0 0 21826 0", "a probe is not serving and locks nothing: " _ $Extract(tRaw, 1, 200))

    Set tCode = $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "SERVINGSUPERSERVER")
    Set ^||OcuPilotSuperserverServing = 21826
    Do $ClassMethod(..#SEAM, "Clear")
    For tBody = {"Enabled": false}, {"EnableCSP": false}, {"SSLSupportLevel": 2, "SSLConfig": "OcuProbeServerTLS"} {
        Set tSC = $ClassMethod(..#SAVE, "Handle", tId, tBody, .tAnswer, .tStatus)
        Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LicenseKey).Parsed(tAnswer).%Get("code"), "403 " _ tCode, tBody.%ToJSON() _ " on the serving port is refused: " _ $Extract(tAnswer, 1, 200))
    }
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, {"action": "delete", "id": (tId)}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LicenseKey).Parsed(tAnswer).%Get("code"), "403 " _ tCode, "and so is the delete")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, {"Port": "21826", "Enabled": false}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "403 " _ tCode, "and the agent's confirm of turning Enabled off")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "with no write")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", 21826).%Get("Enabled") _ $ClassMethod(..#PROBE, "Stored", 21826).%Get("EnableCSP"), "11", "and the probe is as it was")
    Set tSC = $ClassMethod(..#SAVE, "Handle", tId, {"Description": "still permitted"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#SEAM, "Writes"), "200 PUT:21826", "any other change to it is permitted: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals(##class(OcuPilot.Test.LicenseKey).Parsed(tAnswer).%GetTypeOf("consequence"), "unassigned", "and answers no consequence")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $ClassMethod(..#SEAM, "Arm", "answer")
    Set tSC = $ClassMethod(..#SAVE, "Handle", tId, {"SSLSupportLevel": 1, "SSLConfig": "OcuProbeServerTLS"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LicenseKey).Parsed(tAnswer).%Get("consequence"), "200 " _ $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "EFFECTSERVINGSUPERSERVER"), "an SSL/TLS change to it is permitted and answers its consequence: " _ $Extract(tAnswer, 1, 200))
}

/// <p>The two write routes answer over the wire as JSON: <code>POST /superserver</code> creates a probe
/// superserver with 201 and <code>PUT /superserver/:id</code> changes it with 200, each answering the
/// canonical id and the read-back, and a body key outside the settings is 400
/// <code>PORT.FIELD.UNEXPECTED</code>. The write reaches the real port, for a probe port alone.</p>
/// <p>Mutation (Rule 19): stop <method>OcuPilot.Area.Security.SuperserverSave.HandleUpdate</method> decoding the
/// id -- the change answers 404 and this goes red.</p>
Method TestTheWriteRoutesAnswerOverTheWire()
{
    Set tId = $ClassMethod(..#PROBE, "Id", 21825)
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/superserver", .tStatus, .tBody, {"Port": "21825", "BindAddress": "", "Description": "wire"}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 201, "POST /superserver answers 201")
    Do $$$AssertEquals($Select($IsObject(tBody): tBody.%Get("id") _ " " _ ..Verdict(tBody), 1: ""), tId _ " matches", "with the canonical id and the read-back")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", 21825).%Get("Description"), "wire", "and the instance holds it")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/superserver/" _ ##class(OcuPilot.Kernel.EntityId).Encode(tId), ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tChangeStatus, .tChangeRaw, .tHeaders, {"Description": "wire changed"}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tChangeStatus, 200, "PUT /superserver/:id answers 200: " _ $Extract(tChangeRaw, 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Do $$$AssertEquals(..Verdict(##class(OcuPilot.Test.LicenseKey).Parsed(tChangeRaw)), "matches", "with its read-back")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", 21825).%Get("Description"), "wire changed", "and the instance holds the change")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/superserver/" _ ##class(OcuPilot.Kernel.EntityId).Encode(tId), .tUnexpectedStatus, .tUnexpected, {"SystemDefault": true}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tUnexpectedStatus _ " " _ $Select($IsObject(tUnexpected): tUnexpected.%Get("code"), 1: ""), "400 PORT.FIELD.UNEXPECTED", "a body naming SystemDefault is refused before anything is read")
}

/// <p>The read-back verdict of <var>pAnswer</var>, or <code>(none)</code>.</p>
ClassMethod Verdict(pAnswer) As %String
{
    If '$IsObject(pAnswer) || (pAnswer.%GetTypeOf("readBack") '= "object") Quit "(none)"
    Quit pAnswer.%Get("readBack").%Get("verdict")
}

/// <p>The code of the violation on <var>pField</var> in the envelope text <var>pAnswer</var>, or
/// <code>""</code>.</p>
ClassMethod ViolationOf(pAnswer As %String, pField As %String) As %String
{
    Set tAnswer = ##class(OcuPilot.Test.LicenseKey).Parsed(pAnswer)
    If '$IsObject(tAnswer) || '$IsObject(tAnswer.%Get("detail")) || (tAnswer.%Get("detail").%GetTypeOf("violations") '= "array") Quit ""
    Set tIterator = tAnswer.%Get("detail").%Get("violations").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("field") = pField Quit
        Set tRow = ""
    }
    Quit $Select($IsObject($Get(tRow)): tRow.%Get("code"), 1: "")
}

/// <p>Whether <var>pFault</var> carries any violation row.</p>
ClassMethod FaultHasViolations(pFault As %DynamicObject) As %Boolean
{
    Quit $IsObject(pFault) && (pFault.%GetTypeOf("detail") = "object") && (pFault.%Get("detail").%GetTypeOf("violations") = "array") && (pFault.%Get("detail").%Get("violations").%Size() > 0)
}

/// <p><var>pFields</var>, comma-separated, sorted.</p>
ClassMethod Sorted(pFields As %String) As %String
{
    For tI = 1:1:$Length(pFields, ",") {
        Set tNames($Piece(pFields, ",", tI)) = ""
    }
    Set tOut = ""
    Set tName = ""
    For {
        Set tName = $Order(tNames(tName))
        If tName = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tName
    }
    Quit tOut
}

}
