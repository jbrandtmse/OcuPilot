/// <p>Pins Story 18.16's pairs with least-privileged principals (AD-8, AD-29): a reader holding the
/// Remote databases screens' two pairs reads the list, the form and the listing route; a principal
/// without <code>%DB_IRISSYS:WRITE</code> is refused 403 naming it on both callers of all three tools,
/// with zero port calls and no listing; a Save sending <code>MountRequired</code> true without
/// <code>%Admin_Operate:USE</code> is refused naming it; and a principal holding exactly the declared
/// pairs creates, re-points and deletes on both callers, and is answered JSON by each of the four
/// routes over the wire.</p>
/// <p>The write legs run in a child process logged in as the principal
/// (<class>OcuPilot.Test.RemoteDatabaseWriteGateProbe</class>), which reports what
/// <class>OcuPilot.Test.RemoteDatabaseListingPort</class> was asked; the read legs run over the wire.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and both
/// <parameter>ARMINGVARIABLE</parameter> and <parameter>DATABASEVARIABLE</parameter> reading
/// <code>1</code>, because the class creates and deletes probe users and roles, probe remote
/// databases and a probe data server definition (<class>OcuPilot.Test.RemoteDatabaseProbe</class>), and
/// sets the governance policy. Every probe object is removed by exact name.</p>
Class OcuPilot.Test.RemoteDatabaseWriteGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the principals, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The environment variable that arms the database writes, set there alone too.</p>
Parameter DATABASEVARIABLE = "OCUPILOT_ALLOW_DATABASE_CONFIG";

Parameter PROBE = "OcuPilot.Test.RemoteDatabaseProbe";

Parameter CREATETOOL = "OcuPilot.Screen.Tool.RemoteDatabaseCreate";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.RemoteDatabaseUpdate";

Parameter DELETETOOL = "OcuPilot.Screen.Tool.RemoteDatabaseDelete";

Parameter DELETEKEY = "osmgmt.remotedatabases.delete";

Parameter SERVER = "OCUPROBE1816SRV";

/// <p>The principals, each <code>user:role:pairs</code> beyond the install namespace's code read: the
/// reader holds the screens' two pairs; the second those and <code>%Admin_Operate:USE</code>, lacking
/// the write pair; the third those and the system database's <code>WRITE</code>.</p>
Parameter PRINCIPALS = "OCUPROBE1816GREADER:OCUPROBE1816GREADERROLE:%Admin_Manage:U;%DB_IRISSYS:R,OCUPROBE1816GNOWRITE:OCUPROBE1816GNOWRITEROLE:%Admin_Manage:U;%DB_IRISSYS:R;%Admin_Operate:U,OCUPROBE1816GFULL:OCUPROBE1816GFULLROLE:%Admin_Manage:U;%DB_IRISSYS:RW";

/// <p>The four routes, relative to the API base.</p>
Parameter FORMPATH = "/remote-database/form";

Parameter DIRECTORIESPATH = "/remote-database/directories";

Parameter EDITPATH = "/remote-database/:id";

Parameter CREATEPATH = "/remote-database";

/// <p>The throwaway principals' password, generated for the run.</p>
Property PreparedPassword As %String;

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If ($System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1) || ($System.Util.GetEnviron(..#DATABASEVARIABLE) '= 1) {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.RemoteDatabaseWriteGate creates and deletes users, roles and remote databases on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " and " _ ..#DATABASEVARIABLE _ " must both read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets them.")
    }
    Set ..PreparedPassword = "OcuProbe1816Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

/// <p>Each test runs with the principals, the probe data server and the agent's delete key
/// enabled.</p>
Method OnBeforeOneTest() As %Status
{
    Kill tSettings
    Set tSettings(..#DELETEKEY) = "enabled"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "SeedServer")
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
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", .tRemaining))
}

/// <p>A principal holding the screens' two pairs alone reads the Remote databases list, the form
/// (its data servers and the listing's bound) and the listing route over the wire; the listing,
/// on this license, answers <code>DATABASE.SERVER.UNREACHABLE</code> on Server, never a 403.</p>
Method TestTheScreensPairsReadTheListTheFormAndTheListing()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedRemote", "OCUPROBE1816R"), "a probe remote database")
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tUser = ..User(1)
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/screens/osmgmt.remotedatabases/read?maxRows=1000", tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the list's read answers the reader: " _ $Extract(tBody, 1, 200))
    Do $$$AssertTrue(tBody [ """Name"":""OCUPROBE1816R""", "with the probe remote database")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/remote-database/form?name=OCUPROBE1816R", tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Set tAnswer = ..Parsed(tBody)
    Do $$$AssertEquals(tStatus, 200, "the form's read answers the reader: " _ $Extract(tBody, 1, 200))
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("listSeconds") _ "|" _ (tBody [ """Name"":""OCUPROBE1816SRV""") _ "|" _ tAnswer.%Get("configuration").%Get("Directory"), 1: ""), $Parameter("OcuPilot.Port.RemoteDatabasePort", "LISTSECONDS") _ "|1|/ocuprobe1816r/", "with the bound, the data servers and the configuration")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/remote-database/directories?server=" _ ..#SERVER, tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Set tAnswer = ..Parsed(tBody)
    Set tViolation = ""
    If $IsObject(tAnswer) && $IsObject(tAnswer.%Get("detail")) && (tAnswer.detail.%GetTypeOf("violations") = "array") Set tViolation = tAnswer.detail.violations.%Get(0).%Get("field") _ ":" _ tAnswer.detail.violations.%Get(0).%Get("code")
    Do $$$AssertEquals(tStatus _ " " _ tViolation, "422 Server:DATABASE.SERVER.UNREACHABLE", "and the listing route is answered on Server: " _ $Extract(tBody, 1, 200))
}

/// <p>Each of the four routes over the wire for a principal holding exactly the declared pairs: its
/// status, a JSON content type and its body's shape. The form answers its required fields, the
/// listing's bound and the data servers; the listing answers <code>DATABASE.SERVER.UNREACHABLE</code>
/// on Server on this license; a create and a re-point naming no directory are refused on Directory
/// before anything is listed or written; and a re-point of a configuration the instance does not hold
/// is 404 <code>DATABASE.NAME.ABSENT</code>.</p>
Method TestEachRouteAnswersJsonOverTheWire()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedRemote", "OCUPROBE1816GW"), "a remote database to re-point")
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tUser = ..User(3)
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ ..#FORMPATH, tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Set tAnswer = ..Parsed(tBody)
    Do $$$AssertEquals(tStatus, 200, "GET " _ ..#FORMPATH _ " answers: " _ $Extract(tBody, 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%GetTypeOf("requiredFields") _ " " _ tAnswer.%GetTypeOf("servers") _ " " _ tAnswer.%Get("listSeconds"), 1: ""), "array array " _ $Parameter("OcuPilot.Port.RemoteDatabasePort", "LISTSECONDS"), "with its required fields, its data servers and the listing's bound")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ ..#DIRECTORIESPATH _ "?server=" _ ..#SERVER, tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Do $$$AssertEquals(tStatus, 422, "GET " _ ..#DIRECTORIESPATH _ " answers: " _ $Extract(tBody, 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Do $$$AssertEquals(..Violation(tBody), "Server:" _ ##class(OcuPilot.Api.DatabaseError).#SERVERUNREACHABLE, "refused on Server, this license carrying no ECP")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ $Replace(..#EDITPATH, ":id", "OCUPROBE1816GW"), tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders, {"Directory": ""}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 422, "PUT " _ ..#EDITPATH _ " answers: " _ $Extract(tBody, 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Do $$$AssertEquals(..Violation(tBody), "Directory:" _ ##class(OcuPilot.Api.DatabaseError).#REMOTEDIRECTORYNONE, "a re-point naming no directory is refused on Directory")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", "OCUPROBE1816GW", "Directory"), "/ocuprobe1816gw/", "and nothing was written")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ ..#CREATEPATH, tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders, {"Name": "OCUPROBE1816GN", "Server": (..#SERVER), "Directory": ""}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 422, "POST " _ ..#CREATEPATH _ " answers: " _ $Extract(tBody, 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Do $$$AssertEquals(..Violation(tBody), "Directory:" _ ##class(OcuPilot.Api.DatabaseError).#REMOTEDIRECTORYNONE, "a create naming no directory is refused on Directory")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", "OCUPROBE1816GN"), 0, "and nothing was created")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ $Replace(..#EDITPATH, ":id", "OCUPROBE1816GX"), tUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders, {"Directory": "/ocuprobe1816x/"}.%ToJSON(), "application/json")
    Set tAnswer = ..Parsed(tBody)
    Do $$$AssertEquals(tStatus _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code"), 1: ""), "404 " _ ##class(OcuPilot.Api.DatabaseError).#NAMEABSENT, "a re-point of a configuration the instance does not hold is 404: " _ $Extract(tBody, 1, 200))
}

/// <p>Without <code>%DB_IRISSYS:WRITE</code>: the form's create and re-point, the row action's delete,
/// and the agent's confirm of each are refused 403 naming the pair, with nothing sent through the seam
/// and nothing listed. A re-point's <code>MountRequired</code> pair check reads the stored configuration
/// through the shipped port first, which the seam does not record.</p>
/// <p>Mutation (Rule 19): drop <code>%DB_IRISSYS:WRITE</code> from
/// <method>OcuPilot.Screen.Tool.RemoteDatabaseCreate.PrivilegePairs</method> -> the create legs reach
/// the port and this goes red.</p>
Method TestTheMissingWritePairIsRefusedBeforeAnyPortCall()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedRemote", "OCUPROBE1816GR"), "a remote database to re-point")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedRemote", "OCUPROBE1816GD"), "and one to delete")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedRemote", "OCUPROBE1816GS"), "and the agent's to re-point")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedRemote", "OCUPROBE1816GE"), "and to delete")
    Set tUser = ..User(2)
    Set tPlan = []
    Do tPlan.%Push({"kind": "create", "name": "OCUPROBE1816GC", "body": {"Name": "OCUPROBE1816GC", "Server": (..#SERVER), "Directory": "/ocuprobe1816x/"}})
    Do tPlan.%Push({"kind": "update", "name": "OCUPROBE1816GR", "body": {"Directory": "/ocuprobe1816x/"}})
    Do tPlan.%Push({"kind": "delete", "name": "OCUPROBE1816GD"})
    For tCase = $ListBuild(..#CREATETOOL, "OCUPROBE1816GA", {"Name": "OCUPROBE1816GA", "Server": (..#SERVER), "Directory": "/ocuprobe1816y/"}.%ToJSON()), $ListBuild(..#UPDATETOOL, "OCUPROBE1816GS", {"Name": "OCUPROBE1816GS", "Directory": "/ocuprobe1816y/"}.%ToJSON()), $ListBuild(..#DELETETOOL, "OCUPROBE1816GE", {"Name": "OCUPROBE1816GE"}.%ToJSON()) {
        Set tSC = $ClassMethod(..#PROBE, "Mint", $List(tCase, 1), $List(tCase, 2), ##class(%DynamicObject).%FromJSON($List(tCase, 3)), .tProposal, .tHttp, .tProblem, tUser)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ ": minted for the principal (" _ tProblem _ ")")
        Do tPlan.%Push({"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))})
    }
    Set tRun = ..RunAs(tUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    For tI = 1:1:6 {
        Do $$$AssertEquals(..LegText(tRun, tI), "403 AUTH.NOPRIVILEGE %DB_IRISSYS:WRITE calls=0 types= listings=0", "leg " _ tI _ " is refused naming the write pair before any port call")
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", "OCUPROBE1816GC") _ $ClassMethod(..#PROBE, "Holds", "OCUPROBE1816GA"), "00", "no create was written")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", "OCUPROBE1816GR", "Directory") _ " " _ $ClassMethod(..#PROBE, "Stored", "OCUPROBE1816GS", "Directory"), "/ocuprobe1816gr/ /ocuprobe1816gs/", "no re-point was written")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", "OCUPROBE1816GD") _ $ClassMethod(..#PROBE, "Holds", "OCUPROBE1816GE"), "11", "and nothing was deleted")
}

/// <p>A Save whose set sends <code>MountRequired</code> true needs <code>%Admin_Operate:USE</code>
/// (<method>OcuPilot.Screen.Tool.RemoteDatabaseUpdate.ArgumentPairs</method>): a principal holding the
/// write pair but not it is refused 403 naming it with zero port calls; a stored true, which the
/// vendor refuses for a remote database (#430, Task 0), would add it too.</p>
Method TestAMountRequiredSetNeedsTheOperatePair()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedRemote", "OCUPROBE1816GM"), "a remote database")
    Set tUser = ..User(3)
    Set tPlan = [{"kind": "update", "name": "OCUPROBE1816GM", "body": {"Directory": "/ocuprobe1816x/", "MountRequired": true}}]
    Set tRun = ..RunAs(tUser, tPlan)
    Do $$$AssertEquals(..LegText(tRun, 1), "403 AUTH.NOPRIVILEGE %Admin_Operate:USE calls=0 types= listings=0", "the form's re-point sending MountRequired true is refused naming the pair")
    Set tPairs = $ClassMethod(..#UPDATETOOL, "ArgumentPairs", "", {"Name": "OCUPROBE1816GM", "MountRequired": true}, .tResolved)
    Do $$$AssertEquals($ListLength(tPairs) _ " " _ $ListToString($ListGet(tPairs, 1), ":"), "1 %Admin_Operate:USE", "the argument pairs name it")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", "OCUPROBE1816GM", "Directory"), "/ocuprobe1816gm/", "and nothing was written")
}

/// <p>A principal holding exactly the declared pairs: the form's create and re-point, the row action's
/// delete and the agent's confirm of each succeed through the port, each write after its listing
/// (AD-29). This is also the floor under the refusal legs' zero.</p>
Method TestExactlyTheDeclaredPairsWriteOnBothCallers()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedRemote", "OCUPROBE1816FR"), "a remote database to re-point")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedRemote", "OCUPROBE1816FD"), "and one to delete")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedRemote", "OCUPROBE1816FS"), "and the agent's to re-point")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "SeedRemote", "OCUPROBE1816FE"), "and to delete")
    Set tUser = ..User(3)
    Set tPlan = []
    Do tPlan.%Push({"kind": "create", "name": "OCUPROBE1816FC", "body": {"Name": "OCUPROBE1816FC", "Server": (..#SERVER), "Directory": "/ocuprobe1816x/"}})
    Do tPlan.%Push({"kind": "update", "name": "OCUPROBE1816FR", "body": {"Directory": "/ocuprobe1816x/"}})
    Do tPlan.%Push({"kind": "delete", "name": "OCUPROBE1816FD"})
    For tCase = $ListBuild(..#CREATETOOL, "OCUPROBE1816FA", {"Name": "OCUPROBE1816FA", "Server": (..#SERVER), "Directory": "/ocuprobe1816y/"}.%ToJSON()), $ListBuild(..#UPDATETOOL, "OCUPROBE1816FS", {"Name": "OCUPROBE1816FS", "Directory": "/ocuprobe1816y/"}.%ToJSON()), $ListBuild(..#DELETETOOL, "OCUPROBE1816FE", {"Name": "OCUPROBE1816FE"}.%ToJSON()) {
        Set tSC = $ClassMethod(..#PROBE, "Mint", $List(tCase, 1), $List(tCase, 2), ##class(%DynamicObject).%FromJSON($List(tCase, 3)), .tProposal, .tHttp, .tProblem, tUser)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ ": minted for the principal (" _ tProblem _ ")")
        Do tPlan.%Push({"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))})
    }
    Set tRun = ..RunAs(tUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as the principal")
    For tCase = $ListBuild(1, 201, "Database.ConfigCRUD/PUT", 1, "the form's create"), $ListBuild(2, 200, "Database.ConfigCRUD/PUT", 1, "the form's re-point"), $ListBuild(3, 200, "Database.ConfigCRUD/DELETE", 0, "the row action's delete"), $ListBuild(4, 200, "Database.ConfigCRUD/PUT", 1, "the agent's create confirm"), $ListBuild(5, 200, "Database.ConfigCRUD/PUT", 1, "the agent's re-point confirm"), $ListBuild(6, 200, "Database.ConfigCRUD/DELETE", 0, "the agent's delete confirm") {
        Set tLeg = ..Leg(tRun, $List(tCase, 1))
        Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http") _ " " _ tLeg.%Get("listings"), 1: ""), $List(tCase, 2) _ " " _ $List(tCase, 4), $List(tCase, 5) _ " succeeds after its listings (" _ ..LegText(tRun, $List(tCase, 1)) _ ")")
        Do $$$AssertTrue($IsObject(tLeg) && $ListFind($ListFromString(tLeg.%Get("types")), $List(tCase, 3)), $List(tCase, 5) _ " reaches the port's " _ $List(tCase, 3))
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", "OCUPROBE1816FC") _ $ClassMethod(..#PROBE, "Holds", "OCUPROBE1816FA"), "11", "both creates are on the instance")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Stored", "OCUPROBE1816FR", "Directory") _ " " _ $ClassMethod(..#PROBE, "Stored", "OCUPROBE1816FS", "Directory"), "/ocuprobe1816x/ /ocuprobe1816y/", "both re-points are applied")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Holds", "OCUPROBE1816FD") _ $ClassMethod(..#PROBE, "Holds", "OCUPROBE1816FE"), "00", "and both deletes removed their configuration")
}

/// <p>The principal of entry <var>pIndex</var> of <parameter>PRINCIPALS</parameter>.</p>
ClassMethod User(pIndex As %Integer) As %String
{
    Quit $Piece($Piece(..#PRINCIPALS, ",", pIndex), ":", 1)
}

/// <p>Run <class>OcuPilot.Test.RemoteDatabaseWriteGateProbe</class> as <var>pUser</var> over
/// <var>pPlan</var> in a child process and answer what it signalled, or an object carrying
/// <code>error</code>.</p>
ClassMethod RunAs(pUser As %String, pPlan As %DynamicArray) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Set tPlan = pPlan.%ToJSON()
        Job ##class(OcuPilot.Test.RemoteDatabaseWriteGateProbe).Run($Job, pUser, tPlan)::10
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

/// <p>Step <var>pIndex</var> as <code>http code failedPair calls=n types=t listings=l</code>.</p>
ClassMethod LegText(pRun As %DynamicObject, pIndex As %Integer) As %String
{
    Set tLeg = ..Leg(pRun, pIndex)
    If '$IsObject(tLeg) Quit "absent"
    Quit tLeg.%Get("http") _ " " _ tLeg.%Get("code") _ " " _ tLeg.%Get("failedPair") _ " calls=" _ tLeg.%Get("calls") _ " types=" _ tLeg.%Get("types") _ " listings=" _ tLeg.%Get("listings")
}

/// <p>The first violation of the 422 envelope <var>pJson</var>, <code>field:code</code>, or
/// <code>""</code>.</p>
ClassMethod Violation(pJson As %String) As %String
{
    Set tAnswer = ..Parsed(pJson)
    If '$IsObject(tAnswer) || '$IsObject(tAnswer.%Get("detail")) || (tAnswer.detail.%GetTypeOf("violations") '= "array") Quit ""
    Set tFirst = tAnswer.detail.violations.%Get(0)
    If '$IsObject(tFirst) Quit ""
    Quit tFirst.%Get("field") _ ":" _ tFirst.%Get("code")
}

/// <p><var>pJson</var> parsed as an object, or <code>""</code>.</p>
ClassMethod Parsed(pJson As %String) As %DynamicObject
{
    Set tObject = ""
    Try { If pJson '= "" Set tObject = ##class(%DynamicObject).%FromJSON(pJson) } Catch {}
    Quit tObject
}

}
