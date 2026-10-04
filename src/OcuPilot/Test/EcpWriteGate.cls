/// <p>Pins Story 18.20's pairs with least-privileged principals (AC B6; AD-8, AD-29): a reader holding
/// OS management's two pairs reads ECP data servers, the form and the name look-up; a principal without
/// <code>%DB_IRISSYS:WRITE</code> is refused 403 naming it on both callers of the create, update and
/// delete, and one without <code>%Admin_Operate:USE</code> on both callers of the status change, each
/// with zero port calls; a principal without <code>%Admin_Manage:USE</code> is refused every write and
/// both form routes naming it; and principals holding exactly each tool's declared pairs write on both
/// callers.</p>
/// <p>The write legs run in a child process logged in as the principal
/// (<class>OcuPilot.Test.EcpWriteGateProbe</class>), which reports what
/// <class>OcuPilot.Test.EcpSeamPort</class> was asked; the four routes run over the wire.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, room for two data
/// servers under the instance's limit, and both <parameter>ARMINGVARIABLE</parameter> and
/// <parameter>ECPVARIABLE</parameter> reading <code>1</code>, because the class creates and deletes probe
/// users, roles and data servers (<class>OcuPilot.Test.EcpProbe</class>) and sets the governance policy.
/// Every probe object, the principals' task rows included, is removed by exact name; after each test no
/// ECP process runs and the license reads as that test found it.</p>
Class OcuPilot.Test.EcpWriteGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the principals, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The environment variable that arms the data server writes, set there alone too.</p>
Parameter ECPVARIABLE = "OCUPILOT_ALLOW_ECP_CONFIG";

Parameter PROBE = "OcuPilot.Test.EcpProbe";

/// <p>The mint helper, shared with Story 18.6's suites.</p>
Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter CREATETOOL = "OcuPilot.Screen.Tool.EcpDataServerCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.EcpDataServerUpdate";

Parameter DELETETOOL = "OcuPilot.Screen.Tool.EcpDataServerDelete";

Parameter STATUSTOOL = "OcuPilot.Screen.Tool.EcpDataServerChangeStatus";

/// <p>The principals, each <code>user:role:pairs</code> beyond the install namespace's code read: the
/// reader holds OS management's two pairs; the writer those with the system database's
/// <code>WRITE</code>, the create, update and delete's set; the operator those with
/// <code>%Admin_Operate:USE</code>, the status change's set; the outsider the system database's
/// <code>READ</code> and <code>%Admin_Operate:USE</code>, an administrative resource that admits it to
/// the API and is not the screen's.</p>
Parameter PRINCIPALS = "OCUPROBEECPGREADER:OCUPROBEECPGREADERROLE:%Admin_Manage:U;%DB_IRISSYS:R,OCUPROBEECPGWRITER:OCUPROBEECPGWRITERROLE:%Admin_Manage:U;%DB_IRISSYS:RW,OCUPROBEECPGOPERATOR:OCUPROBEECPGOPERATORROLE:%Admin_Manage:U;%DB_IRISSYS:R;%Admin_Operate:U,OCUPROBEECPGNONE:OCUPROBEECPGNONEROLE:%DB_IRISSYS:R;%Admin_Operate:U";

/// <p>The four routes, relative to the API base.</p>
Parameter FORMPATH = "/ecp-data-server/form";

Parameter NAMEPATH = "/ecp-data-server/name";

Parameter EDITPATH = "/ecp-data-server/:id";

Parameter CREATEPATH = "/ecp-data-server";

/// <p>The throwaway principals' password, generated for the run.</p>
Property PreparedPassword As %String;

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

/// <p>The license's facts before each test, which the test must leave as found.</p>
Property PreparedFacts As %String(MAXLEN = "");

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedFacts = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#ECPVARIABLE) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.EcpWriteGate creates and deletes users, roles and ECP data servers on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#ECPVARIABLE _ " must both read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets them.")
    }
    Set ..PreparedPassword = "OcuProbeEcpGate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

/// <p>Each test runs with the principals, and with the agent's delete and status change keys
/// enabled.</p>
Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = ##class(OcuPilot.Test.LicenseProbe).LicenseFacts().%ToJSON()
    Kill tSettings
    Set tSettings("osmgmt.ecpdataservers.delete") = "enabled"
    Set tSettings("osmgmt.ecpdataservers.changestatus") = "enabled"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Length(..#PRINCIPALS, ",") {
        Set tEntry = $Piece(..#PRINCIPALS, ",", tI)
        Set tSC = $ClassMethod(..#PROBE, "SeedPrincipal", $Piece(tEntry, ":", 1), $Piece(tEntry, ":", 2), $Translate($Piece(tEntry, ":", 3, *), ";", ","), ..PreparedPassword)
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe object, principals and their task rows included, is removed by exact name")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "EcpJobs"), 0, "no ECP process runs after the test")
    Do $$$AssertEquals(##class(OcuPilot.Test.LicenseProbe).LicenseFacts().%ToJSON(), ..PreparedFacts, "the license reads as before the test")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", .tRemaining))
}

/// <p>A principal holding OS management's two pairs reads ECP data servers, the form -- a server's,
/// with its listed status and the license's answer, and a new one's on port 1972 -- and the name
/// look-up, over the wire.</p>
Method TestTheScreensPairsReadTheScreenAndTheForm()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBEECPGA"), "a probe data server")
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tUser = ..User(1)
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/screens/osmgmt.ecpdataservers/read?maxRows=50", tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "ECP data servers' read answers the reader: " _ $Extract(tBody, 1, 200))
    Do $$$AssertTrue(tBody [ """OCUPROBEECPGA""", "listing the probe server")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ ..#FORMPATH _ "?name=ocuprobeecpga", tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Set tAnswer = ..Parsed(tBody)
    Do $$$AssertEquals(tStatus, 200, "GET " _ ..#FORMPATH _ " answers the reader: " _ $Extract(tBody, 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Set tServer = $Select($IsObject(tAnswer): tAnswer.%Get("server"), 1: "")
    Do $$$AssertEquals($Select($IsObject(tServer): tServer.%ToJSON(), 1: ""), "{""Name"":""OCUPROBEECPGA"",""Address"":""192.0.2.10"",""Port"":1972,""MirrorConnection"":0,""SSLConfig"":false,""BatchMode"":false,""Status"":""Not Connected""}", "with the server as the instance stores it and its listed status")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%GetTypeOf("requiredFields") _ " " _ tAnswer.%GetTypeOf("rules") _ " " _ tAnswer.%GetTypeOf("licensed") _ " " _ tAnswer.%Get("licensed"), 1: ""), "array array boolean " _ ##class(OcuPilot.Port.EcpPort).NetworkEnabled(), "and its required fields, its rules and whether the license enables ECP")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ ..#FORMPATH, tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Set tAnswer = ..Parsed(tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("server")): tAnswer.%Get("server").%Get("Name") _ "|" _ tAnswer.%Get("server").%Get("Port"), 1: ""), "200 |1972", "a new server's form is empty, on port 1972: " _ $Extract(tBody, 1, 200))
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ ..#NAMEPATH _ "?name=ocuprobeecpga", tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Set tAnswer = ..Parsed(tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("taken"), 1: ""), "200 1", "GET " _ ..#NAMEPATH _ " finds the server in any case: " _ $Extract(tBody, 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ ..#NAMEPATH _ "?name=ocuprobeecpgz", tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Set tAnswer = ..Parsed(tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("taken"), 1: ""), "200 0", "and answers a free name free")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ ..#NAMEPATH _ "?name=" _ $ZConvert("1 a", "O", "URL"), tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LicenseKey).Violation(tBody), "422 Name:" _ ##class(OcuPilot.Api.EcpError).#NAMESHAPE, "and a name of the wrong shape 422 on Name")
}

/// <p>The two Save routes answer JSON over the wire to a principal holding exactly the declared pairs:
/// an update and a create with a port out of range, each refused on <code>Port</code> with nothing
/// written; and an update of a server the instance does not hold, 404 <code>PORT.NOTFOUND</code>.</p>
Method TestTheSaveRoutesAnswerJsonOverTheWire()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBEECPGW"), "a probe data server to update")
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tUser = ..User(2)
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ $Replace(..#EDITPATH, ":id", "OCUPROBEECPGW"), tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders, {"Port": 0}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 422, "PUT " _ ..#EDITPATH _ " answers: " _ $Extract(tBody, 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Do $$$AssertEquals(##class(OcuPilot.Test.LicenseKey).Violation(tBody), "Port:" _ ##class(OcuPilot.Api.EcpError).#PORT, "an update to port 0 is refused on Port")
    Set tStored = $ClassMethod(..#PROBE, "Stored", "OCUPROBEECPGW")
    Do $$$AssertEquals($Select($IsObject(tStored): tStored.%Get("Port"), 1: ""), 1972, "and nothing was written")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ ..#CREATEPATH, tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders, {"Name": "OCUPROBEECPGN", "Address": "192.0.2.10", "Port": 70000}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 422, "POST " _ ..#CREATEPATH _ " answers: " _ $Extract(tBody, 1, 200))
    Do $$$AssertEquals(##class(OcuPilot.Test.LicenseKey).Violation(tBody), "Port:" _ ##class(OcuPilot.Api.EcpError).#PORT, "a create on port 70000 is refused on Port")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", "OCUPROBEECPGN"), 0, "and nothing was created")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ $Replace(..#EDITPATH, ":id", "OCUPROBEECPGX"), tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders, {"Port": 1973}.%ToJSON(), "application/json")
    Set tAnswer = ..Parsed(tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "404 " _ ##class(OcuPilot.Api.Error).#PORTNOTFOUND, "an update of a server the instance does not hold is 404: " _ $Extract(tBody, 1, 200))
}

/// <p>Without <code>%DB_IRISSYS:WRITE</code>: the form's create and update, the list's delete and the
/// agent's confirm of each are refused 403 naming it; without <code>%Admin_Operate:USE</code>: the
/// list's Change status and the agent's confirm of one are refused 403 naming it; each with zero port
/// calls and nothing changed.</p>
/// <p>Mutation (Rule 19): drop <code>%Admin_Operate:USE</code> from
/// <method>OcuPilot.Screen.Tool.EcpDataServerChangeStatus.PrivilegePairs</method>, or
/// <code>%DB_IRISSYS:WRITE</code> from <method>OcuPilot.Screen.Tool.EcpDataServerCreate.PrivilegePairs</method>
/// -- that leg reaches the port and this goes red.</p>
Method TestTheMissingToolPairsAreRefusedBeforeAnyPortCall()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBEECPGU"), "a probe data server to update and change")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBEECPGD"), "and one to delete")
    Set tUser = ..User(1)
    Set tPlan = []
    Do tPlan.%Push({"kind": "create", "name": "", "body": {"Name": "OCUPROBEECPGC", "Address": "192.0.2.10", "Port": 1972}})
    Do tPlan.%Push({"kind": "update", "name": "OCUPROBEECPGU", "body": {"Port": 1973}})
    Do tPlan.%Push({"kind": "delete", "name": "OCUPROBEECPGD"})
    Do tPlan.%Push({"kind": "changestatus", "name": "OCUPROBEECPGU", "status": "disabled", "mode": "started"})
    For tCase = $ListBuild(..#CREATETOOL, "OCUPROBEECPGA", {"Name": "OCUPROBEECPGA", "Address": "192.0.2.10", "Port": 1972}.%ToJSON()), $ListBuild(..#UPDATETOOL, "OCUPROBEECPGU", {"Name": "OCUPROBEECPGU", "Port": 1973}.%ToJSON()), $ListBuild(..#DELETETOOL, "OCUPROBEECPGD", {"Name": "OCUPROBEECPGD"}.%ToJSON()), $ListBuild(..#STATUSTOOL, "OCUPROBEECPGU", {"Name": "OCUPROBEECPGU", "Status": "disabled"}.%ToJSON()) {
        Set tSC = $ClassMethod(..#AGENT, "Mint", $List(tCase, 1), $List(tCase, 2), ##class(%DynamicObject).%FromJSON($List(tCase, 3)), .tProposal, .tHttp, .tProblem, tUser)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ ": minted for the principal (" _ tProblem _ ")")
        Do tPlan.%Push({"kind": "confirm", "mode": "started", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))})
    }
    Set tRun = ..RunAs(tUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    For tI = 1:1:8 {
        Set tPair = $Select((tI = 4) || (tI = 8): "%Admin_Operate:USE", 1: "%DB_IRISSYS:WRITE")
        Do $$$AssertEquals(..LegText(tRun, tI), "403 AUTH.NOPRIVILEGE " _ tPair _ " calls=0 writes=", "leg " _ tI _ " is refused naming " _ tPair _ " before any port call")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", "OCUPROBEECPGC") _ $ClassMethod(..#PROBE, "Holds", "OCUPROBEECPGA"), "00", "no create was written")
    Set tStored = $ClassMethod(..#PROBE, "Stored", "OCUPROBEECPGU")
    Do $$$AssertEquals($Select($IsObject(tStored): tStored.%Get("Port"), 1: "") _ " " _ $ClassMethod(..#PROBE, "ConnState", "OCUPROBEECPGU"), "1972 1", "no update or status change was made")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", "OCUPROBEECPGD"), 1, "and nothing was deleted")
}

/// <p>Without <code>%Admin_Manage:USE</code>: the form's create and update, the list's delete and
/// Change status, and both form routes over the wire are refused 403 naming it, with zero port calls
/// and nothing changed.</p>
/// <p>Mutation (Rule 19): drop the gate from <method>OcuPilot.Area.OsMgmt.EcpRules.HandleForm</method>
/// -- the outsider's form read reaches the port and this goes red.</p>
Method TestEveryCallNeedsTheScreensPairs()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBEECPGU"), "a probe data server to update and change")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBEECPGD"), "and one to delete")
    Set tUser = ..User(4)
    Set tPlan = []
    Do tPlan.%Push({"kind": "create", "name": "", "body": {"Name": "OCUPROBEECPGC", "Address": "192.0.2.10", "Port": 1972}})
    Do tPlan.%Push({"kind": "update", "name": "OCUPROBEECPGU", "body": {"Port": 1973}})
    Do tPlan.%Push({"kind": "delete", "name": "OCUPROBEECPGD"})
    Do tPlan.%Push({"kind": "changestatus", "name": "OCUPROBEECPGU", "status": "disabled", "mode": "started"})
    Set tRun = ..RunAs(tUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    For tI = 1:1:4 {
        Do $$$AssertEquals(..LegText(tRun, tI), "403 AUTH.NOPRIVILEGE %Admin_Manage:USE calls=0 writes=", "leg " _ tI _ " is refused naming the screen's pair before any port call")
    }
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    For tPath = ..#FORMPATH _ "?name=OCUPROBEECPGU", ..#NAMEPATH _ "?name=OCUPROBEECPGU" {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ tPath, tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
        Set tAnswer = ..Parsed(tBody)
        Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code") _ " " _ $Select($IsObject(tAnswer.%Get("detail")): tAnswer.%Get("detail").%Get("failedPair"), 1: ""), 1: ""), "403 AUTH.NOPRIVILEGE %Admin_Manage:USE", "GET " _ tPath _ " is refused naming the screen's pair: " _ $Extract(tBody, 1, 200))
    }
    Set tStored = $ClassMethod(..#PROBE, "Stored", "OCUPROBEECPGU")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", "OCUPROBEECPGC") _ " " _ $Select($IsObject(tStored): tStored.%Get("Port"), 1: "") _ " " _ $ClassMethod(..#PROBE, "ConnState", "OCUPROBEECPGU") _ " " _ $ClassMethod(..#PROBE, "Holds", "OCUPROBEECPGD"), "0 1972 1 1", "and nothing was created, updated, changed or deleted")
}

/// <p>A principal holding exactly the create's declared pairs creates a data server over the wire, through
/// the form and through the agent's confirm.</p>
Method TestExactlyTheDeclaredPairsCreateOnBothCallers()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tUser = ..User(2)
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ ..#CREATEPATH, tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders, {"Name": "ocuprobeecpgc", "Address": "192.0.2.10", "Port": 1972}.%ToJSON(), "application/json")
    Set tAnswer = ..Parsed(tBody)
    Do $$$AssertEquals(tStatus, 201, "POST " _ ..#CREATEPATH _ " creates: " _ $Extract(tBody, 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Do $$$AssertEquals($Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("readBack")): tAnswer.%Get("name") _ " " _ tAnswer.%Get("readBack").%Get("verdict"), 1: ""), "OCUPROBEECPGC matches", "naming the stored server, read back matching")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveServer", "OCUPROBEECPGC"), "the wire's server is removed")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#CREATETOOL, "OCUPROBEECPGA", {"Name": "OCUPROBEECPGA", "Address": "192.0.2.10", "Port": 1972}, .tProposal, .tHttp, .tProblem, tUser)
    Do $$$AssertStatusOK(tSC, "the agent's create is minted for the principal (" _ tProblem _ ")")
    Set tPlan = []
    Do tPlan.%Push({"kind": "create", "name": "", "body": {"Name": "OCUPROBEECPGF", "Address": "192.0.2.10", "Port": 1972}})
    Do tPlan.%Push({"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))})
    Set tRun = ..RunAs(tUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    For tCase = $ListBuild(1, 201, "the form's create"), $ListBuild(2, 200, "the agent's create confirm") {
        Set tLeg = ..Leg(tRun, $List(tCase, 1))
        Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http") _ " " _ tLeg.%Get("writes"), 1: ""), $List(tCase, 2) _ " ECP.DataServer/PUT", $List(tCase, 3) _ " succeeds (" _ ..LegText(tRun, $List(tCase, 1)) _ ")")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", "OCUPROBEECPGF") _ $ClassMethod(..#PROBE, "Holds", "OCUPROBEECPGA"), "11", "both creates are on the instance")
}

/// <p>A principal holding exactly the update and delete's pairs writes through the form and the list's
/// Delete, and through the agent's confirm of each; a principal holding exactly the status change's
/// pairs changes a real status through the list and through a confirm. With
/// <method>TestExactlyTheDeclaredPairsCreateOnBothCallers</method>, the floor under the refusal legs'
/// zero.</p>
Method TestExactlyTheDeclaredPairsWriteOnBothCallers()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBEECPGU"), "a probe data server to update")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBEECPGD"), "and one to delete")
    Set tUser = ..User(2)
    Set tPlan = []
    Do tPlan.%Push({"kind": "update", "name": "OCUPROBEECPGU", "body": {"Port": 1973}})
    Do tPlan.%Push({"kind": "delete", "name": "OCUPROBEECPGD"})
    Set tRun = ..RunAs(tUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    For tCase = $ListBuild(1, 200, "ECP.DataServer/PUT", "the form's update"), $ListBuild(2, 200, "ECP.DataServer/DELETE", "the list's delete") {
        Set tLeg = ..Leg(tRun, $List(tCase, 1))
        Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http") _ " " _ tLeg.%Get("writes"), 1: ""), $List(tCase, 2) _ " " _ $List(tCase, 3), $List(tCase, 4) _ " succeeds (" _ ..LegText(tRun, $List(tCase, 1)) _ ")")
    }
    Set tStored = $ClassMethod(..#PROBE, "Stored", "OCUPROBEECPGU")
    Do $$$AssertEquals($Select($IsObject(tStored): tStored.%Get("Port"), 1: "") _ " " _ $ClassMethod(..#PROBE, "Holds", "OCUPROBEECPGD"), "1973 0", "the update and the delete are on the instance")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBEECPGE"), "the agent's server to delete is seeded")
    Set tPlan = []
    For tCase = $ListBuild(..#UPDATETOOL, "OCUPROBEECPGU", {"Name": "OCUPROBEECPGU", "Port": 1974}.%ToJSON()), $ListBuild(..#DELETETOOL, "OCUPROBEECPGE", {"Name": "OCUPROBEECPGE"}.%ToJSON()) {
        Set tSC = $ClassMethod(..#AGENT, "Mint", $List(tCase, 1), $List(tCase, 2), ##class(%DynamicObject).%FromJSON($List(tCase, 3)), .tProposal, .tHttp, .tProblem, tUser)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ ": minted for the principal (" _ tProblem _ ")")
        Do tPlan.%Push({"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))})
    }
    Set tRun = ..RunAs(tUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    For tCase = $ListBuild(1, "ECP.DataServer/PUT", "the agent's update confirm"), $ListBuild(2, "ECP.DataServer/DELETE", "the agent's delete confirm") {
        Set tLeg = ..Leg(tRun, $List(tCase, 1))
        Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http") _ " " _ tLeg.%Get("writes"), 1: ""), "200 " _ $List(tCase, 2), $List(tCase, 3) _ " succeeds (" _ ..LegText(tRun, $List(tCase, 1)) _ ")")
    }
    Set tStored = $ClassMethod(..#PROBE, "Stored", "OCUPROBEECPGU")
    Do $$$AssertEquals($Select($IsObject(tStored): tStored.%Get("Port"), 1: "") _ " " _ $ClassMethod(..#PROBE, "Holds", "OCUPROBEECPGE"), "1974 0", "the agent's update and delete are on the instance")
    Set tUser = ..User(3)
    Set tRun = ..RunAs(tUser, [{"kind": "changestatus", "name": "OCUPROBEECPGU", "status": "disabled"}])
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    Set tLeg = ..Leg(tRun, 1)
    Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http") _ " " _ tLeg.%Get("writes"), 1: "") _ " " _ $ClassMethod(..#PROBE, "ConnState", "OCUPROBEECPGU"), "200 ECP.DataServer/SERVERACTION 4", "the operator's list Change status to Disabled succeeds (" _ ..LegText(tRun, 1) _ ")")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#STATUSTOOL, "OCUPROBEECPGU", {"Name": "OCUPROBEECPGU", "Status": "notconnected"}, .tProposal, .tHttp, .tProblem, tUser)
    Do $$$AssertStatusOK(tSC, "the operator's change back is minted (" _ tProblem _ ")")
    Set tRun = ..RunAs(tUser, [{"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))}])
    Set tLeg = ..Leg(tRun, 1)
    Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http") _ " " _ tLeg.%Get("writes"), 1: "") _ " " _ $ClassMethod(..#PROBE, "ConnState", "OCUPROBEECPGU"), "200 ECP.DataServer/SERVERACTION 1", "and its confirm back to Not connected succeeds (" _ ..LegText(tRun, 1) _ ")")
}

/// <p>The principal of entry <var>pIndex</var> of <parameter>PRINCIPALS</parameter>.</p>
ClassMethod User(pIndex As %Integer) As %String
{
    Quit $Piece($Piece(..#PRINCIPALS, ",", pIndex), ":", 1)
}

/// <p>Run <class>OcuPilot.Test.EcpWriteGateProbe</class> as <var>pUser</var> over <var>pPlan</var> in
/// a child process and answer what it signalled, or an object carrying <code>error</code>.</p>
ClassMethod RunAs(pUser As %String, pPlan As %DynamicArray) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Set tPlan = pPlan.%ToJSON()
        Job ##class(OcuPilot.Test.EcpWriteGateProbe).Run($Job, pUser, tPlan)::10
        If '$Test {
            Do tOut.%Set("error", "the probe process did not start")
            Quit
        }
        Set tMessage = $System.Event.WaitMsg("", 300)
        If $ListGet(tMessage, 1) '= 1 {
            Do tOut.%Set("error", "the probe process signalled nothing within 300 seconds")
            Quit
        }
        Set tOut = ##class(%DynamicObject).%FromJSON($ListGet(tMessage, 2))
    } Catch ex {
        Set tOut = {}
        Do tOut.%Set("error", ex.DisplayString())
    }
    Quit tOut
}

/// <p>Who the child ran as, <code>username loggedIn</code>, or its error.</p>
ClassMethod Ran(pRun As %DynamicObject) As %String
{
    If '$IsObject(pRun) Quit "no answer"
    If pRun.%IsDefined("error") Quit pRun.%Get("error")
    Quit pRun.%Get("username") _ " " _ pRun.%Get("loggedIn")
}

/// <p>Step <var>pIndex</var> (from 1) of the child's answer <var>pRun</var>, or <code>""</code>.</p>
ClassMethod Leg(pRun As %DynamicObject, pIndex As %Integer) As %DynamicObject
{
    If '$IsObject(pRun) || (pRun.%GetTypeOf("steps") '= "array") Quit ""
    Quit pRun.%Get("steps").%Get(pIndex - 1)
}

/// <p>Step <var>pIndex</var> as <code>http code failedPair calls=n writes=w</code>.</p>
ClassMethod LegText(pRun As %DynamicObject, pIndex As %Integer) As %String
{
    Set tLeg = ..Leg(pRun, pIndex)
    If '$IsObject(tLeg) Quit "absent"
    Quit tLeg.%Get("http") _ " " _ tLeg.%Get("code") _ " " _ tLeg.%Get("failedPair") _ " calls=" _ tLeg.%Get("calls") _ " writes=" _ tLeg.%Get("writes")
}

/// <p><var>pJson</var> parsed as an object, or <code>""</code>.</p>
ClassMethod Parsed(pJson As %String) As %DynamicObject
{
    Quit ##class(OcuPilot.Test.LicenseKey).Parsed(pJson)
}

}
