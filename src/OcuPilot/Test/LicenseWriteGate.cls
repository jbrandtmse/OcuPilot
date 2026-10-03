/// <p>Pins Story 18.6's pairs with least-privileged principals (AC A6; AD-8, AD-29): a reader holding
/// OS management's two pairs reads License key and License servers, the form and the key check; a
/// principal without <code>%DB_IRISSYS:WRITE</code> is refused 403 naming it on both callers of the three
/// license server tools, with zero port calls; a principal without <code>%Admin_Manage:USE</code> is
/// refused the key check and the activation naming it, with zero port calls; and a principal holding
/// exactly the declared pairs writes on both callers and activates through the seam.</p>
/// <p>The write legs run in a child process logged in as the principal
/// (<class>OcuPilot.Test.LicenseWriteGateProbe</class>), which reports what
/// <class>OcuPilot.Test.LicenseSeamPort</class> was asked; the read legs run over the wire.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and both
/// <parameter>ARMINGVARIABLE</parameter> and <parameter>LICENSEVARIABLE</parameter> reading
/// <code>1</code>, because the class creates and deletes probe users, roles and license servers
/// (<class>OcuPilot.Test.LicenseProbe</class>) and sets the governance policy. Every probe object is
/// removed by exact name, and after each test the license and its servers read as that test found them.</p>
Class OcuPilot.Test.LicenseWriteGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the principals, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The environment variable that arms the license server writes, set there alone too.</p>
Parameter LICENSEVARIABLE = "OCUPILOT_ALLOW_LICENSE_CONFIG";

Parameter PROBE = "OcuPilot.Test.LicenseProbe";

Parameter CREATETOOL = "OcuPilot.Screen.Tool.LicenseServerCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.LicenseServerUpdate";

Parameter DELETETOOL = "OcuPilot.Screen.Tool.LicenseServerDelete";

Parameter DELETEKEY = "osmgmt.licenseservers.delete";

/// <p>The principals, each <code>user:role:pairs</code> beyond the install namespace's code read: the
/// reader holds OS management's two pairs; the writer those with the system database's
/// <code>WRITE</code>; the outsider the system database's <code>READ</code> alone.</p>
Parameter PRINCIPALS = "OCUPROBE186GREADER:OCUPROBE186GREADERROLE:%Admin_Manage:U;%DB_IRISSYS:R,OCUPROBE186GFULL:OCUPROBE186GFULLROLE:%Admin_Manage:U;%DB_IRISSYS:RW,OCUPROBE186GNONE:OCUPROBE186GNONEROLE:%DB_IRISSYS:R";

/// <p>The five routes, relative to the API base.</p>
Parameter VALIDATEPATH = "/license/key/validate";

Parameter FORMPATH = "/license-server/form";

Parameter NAMEPATH = "/license-server/name";

Parameter EDITPATH = "/license-server/:id";

Parameter CREATEPATH = "/license-server";

/// <p>The throwaway principals' password, generated for the run.</p>
Property PreparedPassword As %String;

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

/// <p>The license's facts and license servers before each test
/// (<method>OcuPilot.Test.LicenseProbe.LicenseLines</method>), which the test must leave as found.</p>
Property PreparedLicense As %String(MAXLEN = "");

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedLicense = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#LICENSEVARIABLE) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.LicenseWriteGate creates and deletes users, roles and license servers on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#LICENSEVARIABLE _ " must both read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets them.")
    }
    Set ..PreparedPassword = "OcuProbe186Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

/// <p>Each test runs with the principals and the agent's delete key enabled.</p>
Method OnBeforeOneTest() As %Status
{
    Set ..PreparedLicense = $ClassMethod(..#PROBE, "LicenseLines")
    Kill tSettings
    Set tSettings(..#DELETEKEY) = "enabled"
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
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe object, principals included, is removed by exact name")
    Do $$$AssertTrue(..PreparedLicense [ "license|KeyOrderNumber|", "the license snapshot was taken before the test")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "LicenseLines"), ..PreparedLicense, "the license and the instance's license servers read as before the test")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", .tRemaining))
}

/// <p>A principal holding OS management's two pairs reads License key (without its authorization key),
/// License servers and the form over the wire, and the key check answers it a malformed text's 422 on
/// <code>Key</code>, never a 403; and it activates through the seam, the activation declaring no pair
/// beyond the screen's.</p>
Method TestTheScreensPairsReadTheScreensTheFormAndTheCheck()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tUser = ..User(1)
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/screens/osmgmt.licensekey/read?maxRows=10", tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "License key's read answers the reader: " _ $Extract(tBody, 1, 200))
    Do $$$AssertTrue((tBody [ """OrderNumber""") && (tBody '[ "AuthorizationKey"), "with the key's fields and no authorization key")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/screens/osmgmt.licenseservers/read?maxRows=10", tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "License servers' read answers the reader: " _ $Extract(tBody, 1, 200))
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/license-server/form?name=LOCAL", tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Set tAnswer = ##class(OcuPilot.Test.LicenseKey).Parsed(tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("server")): tAnswer.%Get("server").%Get("Name"), 1: ""), "200 LOCAL", "the form's read answers the reader with the server: " _ $Extract(tBody, 1, 200))
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/license-server/name?name=local", tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Set tAnswer = ##class(OcuPilot.Test.LicenseKey).Parsed(tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("taken"), 1: ""), "200 1", "and the name look-up finds LOCAL in any case: " _ $Extract(tBody, 1, 200))
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ "/license/key/validate", tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders, {"Key": ($Parameter(..#PROBE, "MALFORMEDKEY"))}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LicenseKey).Violation(tBody), "422 Key:LICENSE.KEY.INVALID", "the key check answers the reader on Key: " _ $Extract(tBody, 1, 200))
    ; A3, AD-8: the activation declares the screen's set alone, so the reader, holding exactly that set,
    ; activates through the seam.
    Set tRun = ..RunAs(tUser, [{"kind": "activate", "armed": true, "body": {"Key": "OCUPROBE186 seam key"}}])
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    Set tLeg = ..Leg(tRun, 1)
    Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http") _ " " _ tLeg.%Get("writes"), 1: ""), "200 License.Key/VALIDATE,License.Key/PUT", "the reader activates through the seam (" _ ..LegText(tRun, 1) _ ")")
}

/// <p>Each of the five routes answers JSON over the wire to a principal holding exactly the declared
/// pairs: the form's read with its required fields and rules; the name look-up; the key check's 422 on
/// <code>Key</code> for the malformed text; an update and a create with a port out of range, each
/// refused on <code>Port</code> with nothing written; and an update of a server the instance does not
/// hold, 404 <code>PORT.NOTFOUND</code>.</p>
Method TestEachRouteAnswersJsonOverTheWire()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBE186GW"), "a license server to update")
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tUser = ..User(2)
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ ..#FORMPATH, tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tStatus, 200, "GET " _ ..#FORMPATH _ " answers: " _ $Extract(tBody, 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Do $$$AssertEquals(tAnswer.%GetTypeOf("requiredFields") _ " " _ tAnswer.%GetTypeOf("rules"), "array array", "with its required fields and its rules")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ ..#NAMEPATH _ "?name=local", tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "GET " _ ..#NAMEPATH _ " answers: " _ $Extract(tBody, 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ ..#VALIDATEPATH, tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders, {"Key": ($Parameter(..#PROBE, "MALFORMEDKEY"))}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 422, "POST " _ ..#VALIDATEPATH _ " answers: " _ $Extract(tBody, 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Do $$$AssertEquals(##class(OcuPilot.Test.LicenseKey).Violation(tBody), "Key:" _ ##class(OcuPilot.Api.LicenseError).#KEYINVALID, "refused on Key")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ $Replace(..#EDITPATH, ":id", "OCUPROBE186GW"), tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders, {"Port": 0}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 422, "PUT " _ ..#EDITPATH _ " answers: " _ $Extract(tBody, 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Do $$$AssertEquals(##class(OcuPilot.Test.LicenseKey).Violation(tBody), "Port:" _ ##class(OcuPilot.Api.LicenseError).#SERVERPORT, "an update to port 0 is refused on Port")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", "OCUPROBE186GW", "Port"), $Parameter(..#PROBE, "SERVERPORT"), "and nothing was written")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ ..#CREATEPATH, tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders, {"Name": "OCUPROBE186GN", "Address": "127.0.0.1", "Port": 70000}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 422, "POST " _ ..#CREATEPATH _ " answers: " _ $Extract(tBody, 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Do $$$AssertEquals(##class(OcuPilot.Test.LicenseKey).Violation(tBody), "Port:" _ ##class(OcuPilot.Api.LicenseError).#SERVERPORT, "a create on port 70000 is refused on Port")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "ServerExists", "OCUPROBE186GN"), 0, "and nothing was created")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ $Replace(..#EDITPATH, ":id", "OCUPROBE186GX"), tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders, {"Port": 4998}.%ToJSON(), "application/json")
    Set tAnswer = ##class(OcuPilot.Test.LicenseKey).Parsed(tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "404 " _ ##class(OcuPilot.Api.Error).#PORTNOTFOUND, "an update of a server the instance does not hold is 404: " _ $Extract(tBody, 1, 200))
}

/// <p>Without <code>%DB_IRISSYS:WRITE</code>: the form's create and update, the list's delete and the
/// agent's confirm of each are refused 403 naming the pair, with zero port calls.</p>
/// <p>Mutation (Rule 19): drop <code>%DB_IRISSYS:WRITE</code> from
/// <method>OcuPilot.Screen.Tool.LicenseServerCreate.PrivilegePairs</method> -- the agent's create
/// confirm reaches the port and this goes red.</p>
Method TestTheMissingWritePairIsRefusedBeforeAnyPortCall()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBE186GU"), "a license server to update")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBE186GD"), "and one to delete")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBE186GS"), "and the agent's to update")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBE186GE"), "and to delete")
    Set tUser = ..User(1)
    Set tPlan = []
    Do tPlan.%Push({"kind": "create", "name": "", "body": {"Name": "OCUPROBE186GC", "Address": "127.0.0.1", "Port": 4999}})
    Do tPlan.%Push({"kind": "update", "name": "OCUPROBE186GU", "body": {"Port": 4998}})
    Do tPlan.%Push({"kind": "delete", "name": "OCUPROBE186GD"})
    For tCase = $ListBuild(..#CREATETOOL, "OCUPROBE186GA", {"Name": "OCUPROBE186GA", "Address": "127.0.0.1", "Port": 4997}.%ToJSON()), $ListBuild(..#UPDATETOOL, "OCUPROBE186GS", {"Name": "OCUPROBE186GS", "Port": 4997}.%ToJSON()), $ListBuild(..#DELETETOOL, "OCUPROBE186GE", {"Name": "OCUPROBE186GE"}.%ToJSON()) {
        Set tSC = $ClassMethod(..#PROBE, "Mint", $List(tCase, 1), $List(tCase, 2), ##class(%DynamicObject).%FromJSON($List(tCase, 3)), .tProposal, .tHttp, .tProblem, tUser)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ ": minted for the principal (" _ tProblem _ ")")
        Do tPlan.%Push({"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))})
    }
    Set tRun = ..RunAs(tUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    For tI = 1:1:6 {
        Do $$$AssertEquals(..LegText(tRun, tI), "403 AUTH.NOPRIVILEGE %DB_IRISSYS:WRITE calls=0 writes=", "leg " _ tI _ " is refused naming the write pair before any port call")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "ServerExists", "OCUPROBE186GC") _ $ClassMethod(..#PROBE, "ServerExists", "OCUPROBE186GA"), "00", "no create was written")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", "OCUPROBE186GU", "Port") _ " " _ $ClassMethod(..#PROBE, "Stored", "OCUPROBE186GS", "Port"), "4999 4999", "no update was written")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "ServerExists", "OCUPROBE186GD") _ $ClassMethod(..#PROBE, "ServerExists", "OCUPROBE186GE"), "11", "and nothing was deleted")
}

/// <p>Without <code>%Admin_Manage:USE</code>: the key check and the activation are refused 403 naming
/// it, with zero port calls.</p>
/// <p>Mutation (Rule 19): drop the gate from <method>OcuPilot.Area.OsMgmt.LicenseRules.HandleValidate</method>
/// -- the check reaches the port and this goes red.</p>
Method TestTheKeyCheckAndTheActivationNeedTheScreensPairs()
{
    Set tUser = ..User(3)
    Set tPlan = []
    Do tPlan.%Push({"kind": "validate", "body": {"Key": ($Parameter(..#PROBE, "MALFORMEDKEY"))}})
    Do tPlan.%Push({"kind": "activate", "armed": true, "body": {"Key": "OCUPROBE186 seam key"}})
    Set tRun = ..RunAs(tUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    For tI = 1:1:2 {
        Do $$$AssertEquals(..LegText(tRun, tI), "403 AUTH.NOPRIVILEGE %Admin_Manage:USE calls=0 writes=", "leg " _ tI _ " is refused naming the screen's pair before any port call")
    }
}

/// <p>A principal holding exactly the declared pairs: the form's create and update, the list's delete
/// and the agent's confirm of each succeed through the port, and the activation, through the seam,
/// validates and then writes. This is also the floor under the refusal legs' zero.</p>
Method TestExactlyTheDeclaredPairsWriteOnBothCallers()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBE186FU"), "a license server to update")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBE186FD"), "and one to delete")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBE186FS"), "and the agent's to update")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedServer", "OCUPROBE186FE"), "and to delete")
    Set tUser = ..User(2)
    Set tPlan = []
    Do tPlan.%Push({"kind": "create", "name": "", "body": {"Name": "OCUPROBE186FC", "Address": "127.0.0.1", "Port": 4999}})
    Do tPlan.%Push({"kind": "update", "name": "OCUPROBE186FU", "body": {"Port": 4998}})
    Do tPlan.%Push({"kind": "delete", "name": "OCUPROBE186FD"})
    For tCase = $ListBuild(..#CREATETOOL, "OCUPROBE186FA", {"Name": "OCUPROBE186FA", "Address": "127.0.0.1", "Port": 4997}.%ToJSON()), $ListBuild(..#UPDATETOOL, "OCUPROBE186FS", {"Name": "OCUPROBE186FS", "Port": 4997}.%ToJSON()), $ListBuild(..#DELETETOOL, "OCUPROBE186FE", {"Name": "OCUPROBE186FE"}.%ToJSON()) {
        Set tSC = $ClassMethod(..#PROBE, "Mint", $List(tCase, 1), $List(tCase, 2), ##class(%DynamicObject).%FromJSON($List(tCase, 3)), .tProposal, .tHttp, .tProblem, tUser)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ ": minted for the principal (" _ tProblem _ ")")
        Do tPlan.%Push({"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))})
    }
    Do tPlan.%Push({"kind": "activate", "armed": true, "body": {"Key": "OCUPROBE186 seam key"}})
    Set tRun = ..RunAs(tUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as the principal")
    For tCase = $ListBuild(1, 201, "License.Server/PUT", "the form's create"), $ListBuild(2, 200, "License.Server/PUT", "the form's update"), $ListBuild(3, 200, "License.Server/DELETE", "the list's delete"), $ListBuild(4, 200, "License.Server/PUT", "the agent's create confirm"), $ListBuild(5, 200, "License.Server/PUT", "the agent's update confirm"), $ListBuild(6, 200, "License.Server/DELETE", "the agent's delete confirm"), $ListBuild(7, 200, "License.Key/VALIDATE,License.Key/PUT", "the activation, through the seam") {
        Set tLeg = ..Leg(tRun, $List(tCase, 1))
        Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http") _ " " _ tLeg.%Get("writes"), 1: ""), $List(tCase, 2) _ " " _ $List(tCase, 3), $List(tCase, 4) _ " succeeds (" _ ..LegText(tRun, $List(tCase, 1)) _ ")")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "ServerExists", "OCUPROBE186FC") _ $ClassMethod(..#PROBE, "ServerExists", "OCUPROBE186FA"), "11", "both creates are on the instance")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", "OCUPROBE186FU", "Port") _ " " _ $ClassMethod(..#PROBE, "Stored", "OCUPROBE186FS", "Port"), "4998 4997", "both updates are applied")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "ServerExists", "OCUPROBE186FD") _ $ClassMethod(..#PROBE, "ServerExists", "OCUPROBE186FE"), "00", "and both deletes removed their server")
}

/// <p>The principal of entry <var>pIndex</var> of <parameter>PRINCIPALS</parameter>.</p>
ClassMethod User(pIndex As %Integer) As %String
{
    Quit $Piece($Piece(..#PRINCIPALS, ",", pIndex), ":", 1)
}

/// <p>Run <class>OcuPilot.Test.LicenseWriteGateProbe</class> as <var>pUser</var> over <var>pPlan</var>
/// in a child process and answer what it signalled, or an object carrying <code>error</code>.</p>
ClassMethod RunAs(pUser As %String, pPlan As %DynamicArray) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Set tPlan = pPlan.%ToJSON()
        Job ##class(OcuPilot.Test.LicenseWriteGateProbe).Run($Job, pUser, tPlan)::10
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

}
