/// <p>Pins Story 18.20's data server reads and writes on both callers of each tool (AC B1, B2, B3, B6;
/// AD-53, AD-55): the form's Save (<class>OcuPilot.Test.EcpSaveFixture</class>) and the list's Delete
/// (<class>OcuPilot.Test.EcpActionFixture</class>), and the agent's mint and confirm
/// (<class>OcuPilot.Test.DatabaseConfirm</class>) -- the matrix's list, create, update, refusal, SSL,
/// delete, in-use, limit and absent-target legs and the stored upper-case name.</p>
/// <p>The vendor's writes are real; <class>OcuPilot.Test.EcpSeamPort</class> records every call and
/// sends it, so a refusal shows as a recorded write or none.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, room for two data
/// servers under the instance's data server limit, and both <parameter>ARMINGVARIABLE</parameter> and
/// <parameter>DATABASEVARIABLE</parameter> reading <code>1</code>, because the class creates and deletes
/// probe data servers and a probe remote database (<class>OcuPilot.Test.EcpProbe</class>) and sets the
/// governance policy. Every probe object is removed by exact name before all, after each and after all;
/// after each test no ECP process runs and the license reads as that test found it.</p>
Class OcuPilot.Test.EcpDataServerWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the data server writes, set by
/// <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_ECP_CONFIG";

/// <p>The environment variable that arms the probe remote database, set there alone too.</p>
Parameter DATABASEVARIABLE = "OCUPILOT_ALLOW_DATABASE_CONFIG";

Parameter PROBE = "OcuPilot.Test.EcpProbe";

/// <p>The mint, confirm and list helpers, shared with Story 18.6's suites.</p>
Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter SEAM = "OcuPilot.Test.EcpSeamPort";

Parameter SAVE = "OcuPilot.Test.EcpSaveFixture";

Parameter ACTION = "OcuPilot.Test.EcpActionFixture";

Parameter CREATETOOL = "OcuPilot.Screen.Tool.EcpDataServerCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.EcpDataServerUpdate";

Parameter DELETETOOL = "OcuPilot.Screen.Tool.EcpDataServerDelete";

Parameter SCREEN = "osmgmt.ecpdataservers";

Parameter LIST = "OcuPilot.Screen.Descriptor.EcpDataServerList";

Parameter DELETEKEY = "osmgmt.ecpdataservers.delete";

/// <p>The five keys every data server write sends, sorted.</p>
Parameter FIVEKEYS = "Address,BatchMode,MirrorConnection,Port,SSLConfig";

/// <p>The governance policy as it stood before the class ran, restored after each test.</p>
Property PreparedPolicy [ MultiDimensional ];

/// <p>The license's facts before each test, which the test must leave as found.</p>
Property PreparedFacts As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#DATABASEVARIABLE) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.EcpDataServerWrite creates and deletes probe ECP data servers and a probe remote database on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#DATABASEVARIABLE _ " must both read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets them.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

/// <p>Every test records through the seam, with the agent's delete key enabled over the snapshot.</p>
Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = ##class(OcuPilot.Test.LicenseProbe).LicenseFacts().%ToJSON()
    Do $ClassMethod(..#SEAM, "Clear")
    Kill ^||OcuPilotRemoteLicensed
    Set ^||OcuPilotDatabaseWritePort = ..#SEAM
    Kill tSettings
    Set tSettings(..#DELETEKEY) = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
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

/// <p>B1: two probe data servers are answered by the screen's declared read and by
/// <code>osmgmt.ecpdataservers.read</code> as the same rows -- Not Connected, at the probe address and
/// port, the port a number and the three flags booleans.</p>
Method TestTheListAndTheReadToolAnswerTheSameRows()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBEECPA"), "a probe data server")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBEECPB"), "and a second")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#LIST, 1000, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the screen's read answers")
    Set tScreen = ..ProbeRows($Select($IsObject($Get(tResult)): tResult.%Get("rows"), 1: ""))
    Set tExpected = "{""Name"":""OCUPROBEECPA"",""RemoteAddress"":""192.0.2.10"",""RemotePort"":1972,""Status"":""Not Connected"",""MirrorConnection"":false,""SSLConfig"":false,""BatchMode"":false}" _ $Char(10) _ "{""Name"":""OCUPROBEECPB"",""RemoteAddress"":""192.0.2.10"",""RemotePort"":1972,""Status"":""Not Connected"",""MirrorConnection"":false,""SSLConfig"":false,""BatchMode"":false}"
    Do $$$AssertEquals(tScreen, tExpected, "both probe servers, Not Connected, with a numeric port and boolean flags")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(..#SCREEN _ ".read", .tTool)
    Do $$$AssertStatusOK(tSC, "the read tool resolves")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {"maxRows": 200}, 200, .tToolResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "osmgmt.ecpdataservers.read answers")
    Do $$$AssertEquals(..ProbeRows($Select($IsObject($Get(tToolResult)): tToolResult.%Get("rows"), 1: "")), tScreen, "with the same rows")
}

/// <p>B2: a create on both callers sends one <code>PUT</code> carrying the five keys, the last three at
/// their defaults 0, 0 and false; the instance stores the name upper-cased, the list shows it, and the
/// read-back matches; a create of a name held in another case is refused on both callers.</p>
Method TestACreateSendsTheFiveKeysOnBothCallers()
{
    Set tSC = $ClassMethod(..#SAVE, "Handle", "create", "", {"Name": "ocuprobeecpc", "Address": "192.0.2.10", "Port": "1972"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 201, "the form's create answers 201: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "ECP.DataServer/PUT", "sending one PUT")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "NameOf", "ECP.DataServer/PUT"), "ocuprobeecpc", "naming the server as given")
    Set tSent = ..Parsed($ClassMethod(..#SEAM, "BodyOf", "ECP.DataServer/PUT"))
    Do $$$AssertEquals(##class(OcuPilot.Test.LicenseKey).Keys(tSent), ..#FIVEKEYS, "carrying the five keys")
    Do $$$AssertEquals($Select($IsObject(tSent): tSent.%ToJSON(), 1: ""), "{""Address"":""192.0.2.10"",""Port"":1972,""MirrorConnection"":0,""SSLConfig"":0,""BatchMode"":false}", "the port a number, and mirror connection, SSL/TLS and batch mode at their defaults")
    Set tParsed = ..Parsed(tAnswer)
    Do $$$AssertEquals($Select($IsObject(tParsed) && $IsObject(tParsed.%Get("readBack")): tParsed.%Get("name") _ " " _ tParsed.%Get("readBack").%Get("verdict"), 1: ""), "OCUPROBEECPC matches", "naming the stored server, and its read-back matches")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#CREATETOOL, "ocuprobeecpd", {"Name": "ocuprobeecpd", "Address": "192.0.2.10", "Port": 1972}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's create is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($Select($IsObject(tProposal): tProposal.%Get("target").%Get("id"), 1: ""), ##class(OcuPilot.Kernel.EntityRef).NormalizedId("ecp-data-server", "OCUPROBEECPD"), "its target is the canonical foldcase id (AD-13)")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and its confirm writes")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "ECP.DataServer/PUT", "one PUT")
    Do $$$AssertEquals(##class(OcuPilot.Test.LicenseKey).Keys(..Parsed($ClassMethod(..#SEAM, "BodyOf", "ECP.DataServer/PUT"))), ..#FIVEKEYS, "carrying the five keys")
    Do $$$AssertEquals(..Verdict($Get(tResult)), "matches", "and its read-back matches")
    Set tListed = $ClassMethod(..#AGENT, "ListText", ..#LIST, "Name")
    Do $$$AssertTrue((tListed [ ",OCUPROBEECPC,") && (tListed [ ",OCUPROBEECPD,"), "both are listed upper-cased: " _ tListed)
    Set tStored = $ClassMethod(..#PROBE, "Stored", "ocuprobeecpc")
    Do $$$AssertEquals($Select($IsObject(tStored): tStored.%ToJSON(), 1: ""), "{""Address"":""192.0.2.10"",""BatchMode"":false,""MirrorConnection"":0,""SSLConfig"":false,""Port"":1972}", "and stored as sent, resolved in any case")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#SAVE, "Handle", "create", "", {"Name": "OcuProbeEcpC", "Address": "192.0.2.10", "Port": 1972}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LicenseKey).Violation(tAnswer), "422 Name:" _ ##class(OcuPilot.Api.EcpError).#NAMETAKEN, "the form's create of a name held in another case is refused on Name")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#CREATETOOL, "OcuProbeEcpD", {"Name": "OcuProbeEcpD", "Address": "192.0.2.10", "Port": 1972}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ "already present"), "and the agent's is refused as present: " _ tProblem)
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "with nothing sent")
}

/// <p>B2: an update on both callers sends the complete set read fresh, the agent's with two diff rows;
/// a stored non-zero mirror connection is sent unchanged and kept.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.EcpDataServerUpdate.MergeUpdate</method> sends
/// only the changed fields -- the body's keys shrink and this goes red.</p>
Method TestAnUpdateSendsTheCompleteSetAndKeepsAStoredMirror()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBEECPA"), "a probe data server")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBEECPM", "192.0.2.10", 1972, 1), "and one with its mirror connection set")
    Set tSC = $ClassMethod(..#SAVE, "Handle", "update", "OCUPROBEECPA", {"Port": 1973, "BatchMode": true}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the form's update answers 200: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "ECP.DataServer/PUT", "sending one PUT")
    Set tSent = ..Parsed($ClassMethod(..#SEAM, "BodyOf", "ECP.DataServer/PUT"))
    Do $$$AssertEquals(##class(OcuPilot.Test.LicenseKey).Keys(tSent), ..#FIVEKEYS, "sending the complete set")
    Do $$$AssertEquals($Select($IsObject(tSent): tSent.%Get("Address") _ " " _ tSent.%Get("Port") _ " " _ tSent.%Get("MirrorConnection") _ " " _ tSent.%Get("BatchMode"), 1: ""), "192.0.2.10 1973 0 1", "the stored values with the two changes applied")
    Do $$$AssertEquals(..Verdict($Get(tAnswer)), "matches", "and its read-back matches")
    Set tStored = $ClassMethod(..#PROBE, "Stored", "OCUPROBEECPA")
    Do $$$AssertEquals($Select($IsObject(tStored): tStored.%Get("Port") _ " " _ tStored.%Get("BatchMode"), 1: ""), "1973 1", "the port and batch mode are written")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#UPDATETOOL, "OCUPROBEECPM", {"Name": "OCUPROBEECPM", "Port": 1973, "BatchMode": true}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's update is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($Select($IsObject(tProposal): tProposal.%Get("changed").%Size(), 1: -1), 2, "with two diff rows")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and its confirm writes")
    Set tSent = ..Parsed($ClassMethod(..#SEAM, "BodyOf", "ECP.DataServer/PUT"))
    Do $$$AssertEquals(##class(OcuPilot.Test.LicenseKey).Keys(tSent), ..#FIVEKEYS, "the complete set")
    Do $$$AssertEquals($Select($IsObject(tSent): tSent.%Get("MirrorConnection"), 1: ""), 1, "with the stored mirror connection sent unchanged")
    Do $$$AssertEquals(..Verdict($Get(tResult)), "matches", "and its read-back matches")
    Set tStored = $ClassMethod(..#PROBE, "Stored", "OCUPROBEECPM")
    Do $$$AssertEquals($Select($IsObject(tStored): tStored.%Get("Port") _ " " _ tStored.%Get("MirrorConnection"), 1: ""), "1973 1", "the port is written and the mirror connection kept")
}

/// <p>B2: on both callers' create, a name of the wrong shape, an address that is empty or one
/// <class>Config.Host</class> refuses, a port of 0, above 65535 or not a number, a mirror connection of
/// 2, an SSL/TLS of 2 and a batch mode that is not a boolean are each refused on their field before any
/// vendor write.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.OsMgmt.EcpRules.Validate</method> admits port 0 -- the
/// port 0 create is written and this goes red.</p>
Method TestBadCreateFieldsAreRefusedBeforeAnyWrite()
{
    Set tLong = "OCUPROBEECP" _ $Translate($Justify("", 54), " ", "A")
    For tCase = $ListBuild("1 a", "192.0.2.10", "1972", "", "Name:ECP.DATASERVER.NAME.SHAPE"), $ListBuild("a.b", "192.0.2.10", "1972", "", "Name:ECP.DATASERVER.NAME.SHAPE"), $ListBuild(tLong, "192.0.2.10", "1972", "", "Name:ECP.DATASERVER.NAME.SHAPE"), $ListBuild("ocuprobeecpr", "", "1972", "", "Address:ECP.DATASERVER.ADDRESS"), $ListBuild("ocuprobeecpr", "my host", "1972", "", "Address:ECP.DATASERVER.ADDRESS"), $ListBuild("ocuprobeecpr", "192.0.2.10", "0", "", "Port:ECP.DATASERVER.PORT"), $ListBuild("ocuprobeecpr", "192.0.2.10", "65536", "", "Port:ECP.DATASERVER.PORT"), $ListBuild("ocuprobeecpr", "192.0.2.10", "70000", "", "Port:ECP.DATASERVER.PORT"), $ListBuild("ocuprobeecpr", "192.0.2.10", "x", "", "Port:ECP.DATASERVER.PORT"), $ListBuild("ocuprobeecpr", "192.0.2.10", "1972", 2, "MirrorConnection:ECP.DATASERVER.MIRROR") {
        Do $ClassMethod(..#SEAM, "Clear")
        Set tLabel = $ListToString(tCase, " ")
        Set tBody = {}
        Do tBody.%Set("Name", $List(tCase, 1), "string")
        Do tBody.%Set("Address", $List(tCase, 2), "string")
        Do tBody.%Set("Port", $List(tCase, 3), "string")
        If $List(tCase, 4) '= "" Do tBody.%Set("MirrorConnection", $List(tCase, 4), "number")
        Set tSC = $ClassMethod(..#SAVE, "Handle", "create", "", tBody, .tAnswer, .tStatus)
        Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LicenseKey).Violation(tAnswer), "422 " _ $List(tCase, 5), tLabel _ ": the form's create is refused on its field")
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", tLabel _ ": before any vendor write")
        Set tSC = $ClassMethod(..#AGENT, "Mint", ..#CREATETOOL, $List(tCase, 1), tBody, .tProposal, .tHttp, .tProblem)
        Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ ##class(OcuPilot.Api.Error).ReasonForViolation($Piece($List(tCase, 5), ":", 2))), tLabel _ ": and the agent's is refused with the same sentence: " _ tProblem)
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", tLabel _ ": with nothing written")
    }
    For tCase = $ListBuild("SSLConfig", 2, "number"), $ListBuild("BatchMode", "x", "string") {
        Do $ClassMethod(..#SEAM, "Clear")
        Set tLabel = $ListToString(tCase, " ")
        Set tBody = {"Name": "ocuprobeecpr", "Address": "192.0.2.10", "Port": 1972}
        Do tBody.%Set($List(tCase, 1), $List(tCase, 2), $List(tCase, 3))
        Set tSC = $ClassMethod(..#SAVE, "Handle", "create", "", tBody, .tAnswer, .tStatus)
        Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LicenseKey).Violation(tAnswer), "422 " _ $List(tCase, 1) _ ":" _ ##class(OcuPilot.Api.Error).#PORTFIELDSHAPE, tLabel _ ": the form's create is refused on its field")
        Set tSC = $ClassMethod(..#AGENT, "Mint", ..#CREATETOOL, "ocuprobeecpr", tBody, .tProposal, .tHttp, .tProblem)
        Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ ("'" _ $List(tCase, 1) _ "'")), tLabel _ ": and the agent's is refused naming the field: " _ tProblem)
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", tLabel _ ": with nothing written")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Remaining"), 0, "no probe server was created")
}

/// <p>B2: on both callers' update, a port of 0, above 65535 or not a number, an empty address or one
/// <class>Config.Host</class> refuses, a mirror connection of 2, and 0 over a stored 1, an SSL/TLS of 2
/// and a batch mode that is not a boolean, are each refused on their field before any vendor write, and
/// the servers stay as seeded.</p>
/// <p>Mutation (Rule 19): drop the <code>MIRROR</code> check from
/// <method>OcuPilot.Area.OsMgmt.EcpRules.Validate</method> -- the stored mirror connection is turned off
/// and this goes red.</p>
Method TestBadUpdateFieldsAreRefusedBeforeAnyWrite()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBEECPW"), "a probe data server to update")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBEECPM", "192.0.2.10", 1972, 1), "and one with its mirror connection set")
    For tCase = $ListBuild("OCUPROBEECPW", "Port", 0, "number", "Port:ECP.DATASERVER.PORT"), $ListBuild("OCUPROBEECPW", "Port", 65536, "number", "Port:ECP.DATASERVER.PORT"), $ListBuild("OCUPROBEECPW", "Port", "x", "string", "Port:ECP.DATASERVER.PORT", "'Port' is number on this instance"), $ListBuild("OCUPROBEECPW", "Address", "", "string", "Address:ECP.DATASERVER.ADDRESS"), $ListBuild("OCUPROBEECPW", "Address", "my host", "string", "Address:ECP.DATASERVER.ADDRESS"), $ListBuild("OCUPROBEECPW", "MirrorConnection", 2, "number", "MirrorConnection:ECP.DATASERVER.MIRROR"), $ListBuild("OCUPROBEECPM", "MirrorConnection", 0, "number", "MirrorConnection:ECP.DATASERVER.MIRROR"), $ListBuild("OCUPROBEECPW", "SSLConfig", 2, "number", "SSLConfig:PORT.FIELD.SHAPE", "'SSLConfig' is boolean on this instance"), $ListBuild("OCUPROBEECPW", "BatchMode", "x", "string", "BatchMode:PORT.FIELD.SHAPE", "'BatchMode' is boolean on this instance") {
        Do $ClassMethod(..#SEAM, "Clear")
        Set tLabel = $ListToString(tCase, " ")
        Set tBody = {}
        Do tBody.%Set($List(tCase, 2), $List(tCase, 3), $List(tCase, 4))
        Set tSC = $ClassMethod(..#SAVE, "Handle", "update", $List(tCase, 1), tBody, .tAnswer, .tStatus)
        Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LicenseKey).Violation(tAnswer), "422 " _ $List(tCase, 5), tLabel _ ": the form's update is refused on its field")
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", tLabel _ ": before any vendor write")
        Do tBody.%Set("Name", $List(tCase, 1), "string")
        Set tSC = $ClassMethod(..#AGENT, "Mint", ..#UPDATETOOL, $List(tCase, 1), tBody, .tProposal, .tHttp, .tProblem)
        ; A value of the wrong type is refused by the kernel's merge, on its field, before the tool's
        ; rules run; every other value by the rules, with the form's sentence.
        Set tExpected = $ListGet(tCase, 6, ##class(OcuPilot.Api.Error).ReasonForViolation($Piece($List(tCase, 5), ":", 2)))
        Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ tExpected), tLabel _ ": and the agent's update is refused on its field: " _ tProblem)
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", tLabel _ ": with nothing written")
    }
    Set tW = $ClassMethod(..#PROBE, "Stored", "OCUPROBEECPW")
    Set tM = $ClassMethod(..#PROBE, "Stored", "OCUPROBEECPM")
    Do $$$AssertEquals($Select($IsObject(tW) && $IsObject(tM): tW.%Get("Address") _ ":" _ tW.%Get("Port") _ ":" _ tW.%Get("MirrorConnection") _ " " _ tM.%Get("MirrorConnection"), 1: ""), "192.0.2.10:1972:0 1", "and both servers are as seeded")
}

/// <p>B2: SSL/TLS while the <code>%ECPClient</code> SSL/TLS configuration is absent is refused on
/// <code>SSLConfig</code> on both callers' create and on the form's update, with nothing stored and the
/// update's other change not applied.</p>
Method TestSslWithoutTheClientConfigurationIsRefusedOnItsField()
{
    Do $$$AssertEquals($ClassMethod(..#PROBE, "ClientConfigured"), 0, "the instance holds no %ECPClient SSL/TLS configuration, as a stock instance does")
    Set tSC = $ClassMethod(..#SAVE, "Handle", "create", "", {"Name": "ocuprobeecps", "Address": "192.0.2.10", "Port": 1972, "SSLConfig": 1}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LicenseKey).Violation(tAnswer), "422 SSLConfig:" _ ##class(OcuPilot.Api.EcpError).#SSLCLIENT, "the form's create is refused on SSLConfig: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", "OCUPROBEECPS"), 0, "and nothing is stored")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#CREATETOOL, "ocuprobeecpt", {"Name": "ocuprobeecpt", "Address": "192.0.2.10", "Port": 1972, "SSLConfig": 1}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's create is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "422 " _ ##class(OcuPilot.Api.EcpError).#SSLCLIENT, "and its confirm is refused on SSLConfig")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", "OCUPROBEECPT"), 0, "with nothing stored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBEECPU"), "a probe data server to update")
    Set tSC = $ClassMethod(..#SAVE, "Handle", "update", "OCUPROBEECPU", {"Port": 1973, "SSLConfig": 1}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LicenseKey).Violation(tAnswer), "422 SSLConfig:" _ ##class(OcuPilot.Api.EcpError).#SSLCLIENT, "the form's update is refused on SSLConfig: " _ $Extract(tAnswer, 1, 200))
    Set tStored = $ClassMethod(..#PROBE, "Stored", "OCUPROBEECPU")
    Do $$$AssertEquals($Select($IsObject(tStored): tStored.%Get("Port") _ " " _ tStored.%Get("SSLConfig"), 1: ""), "1972 0", "and neither the port nor SSL/TLS is applied")
}

/// <p>B3: a delete on both callers sends <code>DELETE</code>; the server leaves the list and the
/// read-back reads it absent.</p>
Method TestADeleteRemovesTheServerOnBothCallers()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBEECPD"), "a probe data server")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBEECPE"), "and the agent's")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, {"action": "delete", "id": "OCUPROBEECPD"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the list's delete answers 200: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "ECP.DataServer/DELETE", "sending one DELETE")
    Set tParsed = ..Parsed(tAnswer)
    Do $$$AssertEquals($Select($IsObject(tParsed): tParsed.%Get("action") _ " " _ ..Verdict(tParsed), 1: ""), "deleted notFound", "answering the delete, read back absent")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#DELETETOOL, "OCUPROBEECPE", {"Name": "OCUPROBEECPE"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's delete is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($Select($IsObject(tProposal): ..Rows(tProposal.%Get("changed")), 1: ""), "Address=192.0.2.10,Port=1972", "its card lists the address and port it removes")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and its confirm deletes")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "ECP.DataServer/DELETE", "one DELETE")
    Do $$$AssertEquals(..Verdict($Get(tResult)), "notFound", "read back absent")
    Set tListed = $ClassMethod(..#AGENT, "ListText", ..#LIST, "Name")
    Do $$$AssertTrue((tListed '= "") && '(tListed [ ",OCUPROBEECPD,") && '(tListed [ ",OCUPROBEECPE,"), "neither is listed: " _ tListed)
}

/// <p>B3: a data server a remote database uses -- its impact names that remote database first, on the
/// dialog's route and on the agent's proposal, and its delete is refused
/// <code>ECP.DATASERVER.INUSE</code> on both callers with the server kept.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Kernel.Proposal.Impact.KindOf</method> omits the data server
/// delete -- no impact is answered and this goes red.</p>
Method TestADataServerInUseNamesItsRemoteDatabaseAndIsRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedRemote", "OCUPROBEECPR", "OCUPROBEECPA"), "a probe remote database on a probe data server")
    Set tExpected = "ecp-data-server-delete||remoteDatabases:1|OCUPROBEECPR|"
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("ecp-data-server", "instance", "OCUPROBEECPA", .tRef)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Said", ##class(OcuPilot.Kernel.Proposal.Impact).Of(..#DELETEKEY, tRef, "{}", "{}", "[]")), tExpected, "Impact.Of names the remote database")
    Set tPath = $Parameter("OcuPilot.Test.Http", "BASEPATH") _ "/screens/" _ ..#SCREEN _ "/impact?action=delete&id=OCUPROBEECPA"
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tPath, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders)
    Set tRoute = ..Parsed(tRaw)
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#PROBE, "Said", $Select($IsObject(tRoute): tRoute.%Get("impact"), 1: "")), "200 " _ tExpected, "and so does the dialog's route: " _ $Extract(tRaw, 1, 200))
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#DELETETOOL, "OCUPROBEECPA", {"Name": "OCUPROBEECPA"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's delete is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Said", $ClassMethod(..#PROBE, "ProposalImpact", $Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))), tExpected, "and so does the agent's proposal")
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, {"action": "delete", "id": "OCUPROBEECPA"}, .tAnswer, .tStatus)
    Set tParsed = ..Parsed(tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tParsed): tParsed.%Get("code"), 1: ""), "409 " _ ##class(OcuPilot.Api.EcpError).#INUSE, "the list's delete is refused in use: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "409 " _ ##class(OcuPilot.Api.EcpError).#INUSE, "and so is the agent's confirm")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", "OCUPROBEECPA"), 1, "and the server is kept")
}

/// <p>The data server limit for a caller holding <code>%Admin_Secure:USE</code> (AD-52), as the test's
/// own account does: with the configured data servers at <code>AppServerSettings.MaxServers</code> read
/// from the instance, a create is refused 409 <code>ECP.SERVER.LIMIT</code> on both callers with a
/// sentence naming the limit, no <code>PUT</code> sent, no audit event and no log line; an update at the
/// limit is written.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.EcpPort.Put</method> skips its check -- the
/// <code>PUT</code> is sent and this goes red.</p>
Method TestACreatePastTheLimitIsRefusedBeforeAnyWrite()
{
    Do $$$AssertTrue(##class(OcuPilot.Port.EcpPort).HoldsPair($Parameter("OcuPilot.Port.EcpPort", "LIMITPAIR")), "the test's account holds %Admin_Secure:USE, so the port reads the limit itself")
    Set tSC = ##class(OcuPilot.Port.EcpPort).MaxServers(.tMaximum, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the instance's data server limit is read")
    Set tHave = $ClassMethod(..#PROBE, "ServerCount")
    Set tRoom = tMaximum - tHave
    If tRoom > 2 {
        Do $$$AssertTrue(0, "this instance allows " _ tRoom _ " more data servers, and a test holds at most two probe servers, so the limit cannot be reached here (a stock instance's MaxServers is 2)")
        Quit
    }
    For tI = 1:1:tRoom Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBEECPL" _ tI), "probe data server " _ tI _ " fills the limit")
    Set tSince = $ZDateTime($ZTimeStamp, 3, 1)
    Set tLines = $ClassMethod(..#PROBE, "LineCount", "messages.log")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#SAVE, "Handle", "create", "", {"Name": "ocuprobeecpl9", "Address": "192.0.2.10", "Port": 1972}, .tAnswer, .tStatus)
    Set tParsed = ..Parsed(tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tParsed): tParsed.%Get("code"), 1: ""), "409 " _ ##class(OcuPilot.Api.EcpError).#SERVERLIMIT, "the form's create is refused at the limit: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($Select($IsObject(tParsed): tParsed.%Get("reason"), 1: ""), ##class(OcuPilot.Api.EcpError).Limit(tMaximum), "naming the limit")
    Do $$$AssertTrue($Select($IsObject(tParsed): tParsed.%Get("reason"), 1: "") [ ("at most " _ tMaximum _ " ECP data server"), "as the instance's own number")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "with no PUT sent")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#CREATETOOL, "ocuprobeecpl9", {"Name": "ocuprobeecpl9", "Address": "192.0.2.10", "Port": 1972}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's create is minted (" _ tProblem _ ")")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "409 " _ ##class(OcuPilot.Api.EcpError).#SERVERLIMIT, "and its confirm is refused at the limit")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "with no PUT sent")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", "OCUPROBEECPL9"), 0, "nothing is stored")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "CreateEvents", "OCUPROBEECPL9", tSince), 0, "no create audit event is recorded")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LineCount", "messages.log"), tLines, "and messages.log gains no line")
    If tRoom < 1 Quit
    Set tSC = $ClassMethod(..#SAVE, "Handle", "update", "OCUPROBEECPL1", {"Port": 1973}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "an update at the limit is written: " _ $Extract(tAnswer, 1, 200))
}

/// <p>B2: a body key the tools do not admit is refused on both callers before anything is sent: the Save
/// 400 <code>PORT.FIELD.UNEXPECTED</code>, the agent's arguments by the tool's closed schema at
/// dispatch.</p>
/// <p>Mutation (Rule 19): drop the <method>OcuPilot.Area.OsMgmt.EcpDataServerSave.Unexpected</method> call
/// from the Save's create and update -- the update is written and this goes red.</p>
Method TestAKeyTheToolsDoNotAdmitIsNeverSent()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBEECPK"), "a probe data server")
    For tCase = $ListBuild("create", "", {"Name": "ocuprobeecpn", "Address": "192.0.2.10", "Port": 1972, "Status": "Disabled"}.%ToJSON()), $ListBuild("update", "OCUPROBEECPK", {"Port": 1973, "Status": "Disabled"}.%ToJSON()) {
        Do $ClassMethod(..#SEAM, "Clear")
        Set tSC = $ClassMethod(..#SAVE, "Handle", $List(tCase, 1), $List(tCase, 2), ##class(%DynamicObject).%FromJSON($List(tCase, 3)), .tAnswer, .tStatus)
        Set tParsed = ..Parsed(tAnswer)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tParsed): tParsed.%Get("code"), 1: ""), "400 " _ ##class(OcuPilot.Api.Error).#PORTFIELDUNEXPECTED, "the form's " _ $List(tCase, 1) _ " carrying Status is refused: " _ $Extract(tAnswer, 1, 200))
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "the form's " _ $List(tCase, 1) _ ": with nothing sent")
    }
    For tCase = $ListBuild(..#CREATETOOL, {"Name": "ocuprobeecpn", "Address": "192.0.2.10", "Port": 1972, "Status": "Disabled"}.%ToJSON()), $ListBuild(..#UPDATETOOL, {"Name": "OCUPROBEECPK", "Port": 1973, "Status": "Disabled"}.%ToJSON()) {
        Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments($ClassMethod($List(tCase, 1), "InputSchema"), ##class(%DynamicObject).%FromJSON($List(tCase, 2)), .tProblem)
        Do $$$AssertTrue($$$ISERR(tSC) && (tProblem [ "Status"), $List(tCase, 1) _ ": the agent's arguments carrying Status are refused at dispatch: " _ tProblem)
    }
    Set tStored = $ClassMethod(..#PROBE, "Stored", "OCUPROBEECPK")
    Do $$$AssertEquals($Select($IsObject(tStored): tStored.%Get("Port"), 1: "") _ " " _ $ClassMethod(..#PROBE, "Holds", "OCUPROBEECPN"), "1972 0", "the server is as seeded and nothing was created")
}

/// <p>B6: an update or delete of a server the instance no longer defines sends nothing: the Save and the
/// list's delete answer 404, and the agent's confirm of a server deleted since its mint is refused as a
/// changed target.</p>
Method TestAnAbsentTargetIsRefusedAndNothingIsSent()
{
    Set tSC = $ClassMethod(..#SAVE, "Handle", "update", "OCUPROBEECPGONE", {"Port": 1973}, .tAnswer, .tStatus)
    Set tParsed = ..Parsed(tAnswer)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tParsed): tParsed.%Get("code"), 1: ""), "404 " _ ##class(OcuPilot.Api.Error).#PORTNOTFOUND, "the form's update of an absent server is 404: " _ $Extract(tAnswer, 1, 200))
    Set tSC = $ClassMethod(..#ACTION, "Act", ..#SCREEN, {"action": "delete", "id": "OCUPROBEECPGONE"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 404, "and the list's delete is 404: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "with nothing sent")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBEECPX"), "a probe data server")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#UPDATETOOL, "OCUPROBEECPX", {"Name": "OCUPROBEECPX", "Port": 1973}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's update is minted (" _ tProblem _ ")")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveServer", "OCUPROBEECPX"), "and the server is deleted since")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "its confirm is refused as a changed target")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes") _ "|" _ $ClassMethod(..#PROBE, "Holds", "OCUPROBEECPX"), "|0", "with nothing sent and nothing re-created")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBEECPY"), "a probe data server for the agent's delete")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#DELETETOOL, "OCUPROBEECPY", {"Name": "OCUPROBEECPY"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's delete is minted (" _ tProblem _ ")")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveServer", "OCUPROBEECPY"), "and the server is deleted since")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "its confirm is refused as a changed target")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "with nothing sent")
}

/// <p>The rows of <var>pRows</var> whose <code>Name</code> is a probe name, each as JSON, sorted by
/// name and newline-joined.</p>
ClassMethod ProbeRows(pRows As %DynamicArray) As %String
{
    If '$IsObject(pRows) Quit "(no rows)"
    Kill tByName
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) || '##class(OcuPilot.Test.EcpProbe).IsProbe(tRow.%Get("Name")) Continue
        Set tByName(tRow.%Get("Name")) = tRow.%ToJSON()
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

/// <p>The read-back verdict an answer carries, the answer an object or its JSON text, or
/// <code>(none)</code>.</p>
ClassMethod Verdict(pAnswer) As %String
{
    Set tAnswer = pAnswer
    If '$IsObject(tAnswer) Set tAnswer = ..Parsed(tAnswer)
    If '$IsObject(tAnswer) || (tAnswer.%GetTypeOf("readBack") '= "object") Quit "(none)"
    Quit tAnswer.%Get("readBack").%Get("verdict")
}

/// <p><var>pJson</var> parsed as an object, or <code>""</code>.</p>
ClassMethod Parsed(pJson As %String) As %DynamicObject
{
    Quit ##class(OcuPilot.Test.LicenseKey).Parsed(pJson)
}

}
