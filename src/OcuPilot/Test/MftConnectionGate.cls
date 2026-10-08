/// <p>Pins Story 18.26's pairs with least-privileged principals (AD-8, AD-29, measured at plan): a principal
/// holding exactly Security's two pairs reads the list and the form over the wire, and in process creates, changes,
/// revokes the token of and deletes a probe connection -- the delete removing the client configuration and
/// description it names, which the principal cannot list -- and confirms the agent's change; without
/// <code>%Admin_Secure:USE</code> both reads, every write and the confirm are refused naming it and the screen is
/// unavailable; and without <code>%DB_IRISSYS:READ</code> every write is refused naming it. Every refusal comes
/// before any port call.</p>
/// <p>The in-process legs run in a child process logged in as the principal
/// (<class>OcuPilot.Test.MftGateProbe</class>), whose <class>OcuPilot.Test.MftSeamPort</class> sends a write for a
/// probe name and records it.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates and deletes probe users
/// and roles (<class>OcuPilot.Test.AuthOptionsProbe</class>'s principals), connections, client configurations,
/// descriptions and the probe's client SSL/TLS configuration and sets the governance policy. Every probe object is removed, and after each test the connection
/// list reads as that test found it.</p>
Class OcuPilot.Test.MftConnectionGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the principals, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The principal helper, which owns the three probe accounts and roles.</p>
Parameter PROBE = "OcuPilot.Test.AuthOptionsProbe";

Parameter CONNECTIONS = "OcuPilot.Test.MftProbe";

Parameter SCREEN = "security.mftconnections";

Parameter UPDATETOOL = "OcuPilot.Test.SeamMftConnectionUpdate";

/// <p>The principals' resources beyond the install namespace's code read, by the order of the probe's principal
/// list: the holder holds Security's two pairs; the outsider the file-system pair and the system database's read,
/// without Security's resource; the third Security's resource alone.</p>
Parameter RESOURCES = "%Admin_Secure:U,%DB_IRISSYS:R;%Admin_FileSystemAccess:U,%DB_IRISSYS:R;%Admin_Secure:U";

/// <p>The throwaway principals' password, generated for the run.</p>
Property PreparedPassword As %String;

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

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
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.MftConnectionGate creates and deletes users, roles and connections on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuProbe188Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll")
    Quit $$$ADDSC(tSC, $ClassMethod(..#CONNECTIONS, "RemoveAll"))
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = $ClassMethod(..#CONNECTIONS, "Facts")
    Kill tSettings
    Set tSettings("security.mftconnections.create") = "enabled"
    Set tSettings("security.mftconnections.update") = "enabled"
    Set tSettings("security.mftconnections.delete") = "enabled"
    Set tSettings("security.mftconnections.revoketoken") = "enabled"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
    If $$$ISERR(tSC) Quit tSC
    Set tRoles = $ClassMethod(..#PROBE, "Roles")
    For tI = 1:1:3 {
        Set tSC = $ClassMethod(..#PROBE, "SeedPrincipal", ..User(tI), $List(tRoles, tI), $Piece(..#RESOURCES, ";", tI), ..PreparedPassword)
        If $$$ISERR(tSC) Quit
    }
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#CONNECTIONS, "AddClient", "OcuMftProbeBApp")
    If $$$ISERR(tSC) Quit tSC
    For tName = "OcuMftProbeA", "OcuMftProbeB", "OcuMftProbeRev" {
        Set tSC = $ClassMethod(..#CONNECTIONS, "Seed", tName)
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll"), "every probe principal is removed")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Remaining"), 0, "and none is left")
    Do $$$AssertStatusOK($ClassMethod(..#CONNECTIONS, "RemoveAll"), "every probe connection, client configuration and description is removed")
    Do $$$AssertEquals($ClassMethod(..#CONNECTIONS, "HoldsSsl"), 0, "and the probe's client SSL/TLS configuration")
    Do $$$AssertNotEquals(..PreparedFacts, "unreadable", "the connection list was read before the test")
    Do $$$AssertEquals($ClassMethod(..#CONNECTIONS, "Facts"), ..PreparedFacts, "the connection list reads as before the test")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#CONNECTIONS, "RemoveAll"))
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll"))
}

/// <p>The holder reads the list and the form over the wire; in process it creates, changes, revokes and deletes a
/// probe connection -- the delete taking the client configuration and description it cannot list -- and confirms
/// the agent's change, each write reaching the seam as one <code>PUT</code>, <code>REVOKE</code> or
/// <code>DELETE</code> on a probe name.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Security.MftConnectionSave.Gate</method> refuse every caller --
/// the holder's write legs go red.</p>
Method TestTheDeclaredPairsReadAndWrite()
{
    Set tUser = ..User(1)
    Do $$$AssertEquals(..WireRead("/screens/" _ ..#SCREEN _ "/read?maxRows=10", tUser), "200 ", "the connections read answers the holder")
    Do $$$AssertEquals(..WireRead("/mft-connection/form?id=OcuMftProbeA", tUser), "200 ", "and the form read")
    Set tSC = $ClassMethod(..#CONNECTIONS, "Mint", ..#UPDATETOOL, "OcuMftProbeA", {"Name": "OcuMftProbeA", "Username": "agent@ocumftprobe.invalid"}, .tProposal, .tHttp, .tProblem, tUser)
    Do $$$AssertStatusOK(tSC, "the agent's change is minted for the holder (" _ tProblem _ ")")
    Set tCreate = $ClassMethod(..#CONNECTIONS, "Body", "OcuMftProbeN")
    Do tCreate.%Set("Name", "OcuMftProbeN")
    Set tPlan = []
    Do tPlan.%Push({"kind": "create", "body": (tCreate)})
    Do tPlan.%Push({"kind": "update", "id": "OcuMftProbeA", "body": {"Username": "form@ocumftprobe.invalid"}})
    Do tPlan.%Push({"kind": "revoke", "id": "OcuMftProbeRev"})
    Do tPlan.%Push({"kind": "delete", "id": "OcuMftProbeB"})
    Do tPlan.%Push({"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))})
    Set tRun = ..RunAs(tUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    For tCase = $ListBuild(1, "201 PUT:OcuMftProbeN", "the create"), $ListBuild(2, "200 PUT:OcuMftProbeA", "the change"), $ListBuild(3, "200 REVOKE:OcuMftProbeRev", "the revoke"), $ListBuild(4, "200 DELETE:OcuMftProbeB", "the delete"), $ListBuild(5, "200 PUT:OcuMftProbeA", "the agent's confirm") {
        Set tLeg = ..Leg(tRun, $List(tCase, 1))
        Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http") _ " " _ tLeg.%Get("writes"), 1: ""), $List(tCase, 2), $List(tCase, 3) _ " writes once (" _ ..LegText(tRun, $List(tCase, 1)) _ ")")
    }
    Do $$$AssertEquals($ClassMethod(..#CONNECTIONS, "HoldsClient", "OcuMftProbeBApp") _ $IsObject($ClassMethod(..#CONNECTIONS, "Stored", "OcuMftProbeB")), "00", "the delete took the client configuration, which the holder cannot list, with it")
}

/// <p>Without <code>%Admin_Secure:USE</code>, both reads and the Save over the wire, and in process every write and
/// the confirm, are refused naming the pair with zero port calls, and the screen is unavailable.</p>
/// <p>Mutation (Rule 19): let <method>OcuPilot.Area.Security.MftConnectionSave.Gate</method> pass every caller --
/// the Save legs reach the port and go red.</p>
Method TestWithoutSecuritysResourceEveryReadAndWriteIsRefused()
{
    Set tUser = ..User(2)
    Do $$$AssertEquals(..WireRead("/screens/" _ ..#SCREEN _ "/read?maxRows=10", tUser), "403 %Admin_Secure:USE", "the read is refused naming the pair")
    Do $$$AssertEquals(..WireRead("/mft-connection/form", tUser), "403 %Admin_Secure:USE", "and the form read")
    Do $$$AssertEquals(..WireSave("/mft-connection", "POST", {"Name": "OcuMftProbeN"}, tUser), "403 AUTH.NOPRIVILEGE %Admin_Secure:USE", "and a create over the wire")
    Set tSC = $ClassMethod(..#CONNECTIONS, "Mint", ..#UPDATETOOL, "OcuMftProbeA", {"Name": "OcuMftProbeA", "Username": "agent@ocumftprobe.invalid"}, .tProposal, .tHttp, .tProblem, tUser)
    Do $$$AssertStatusOK(tSC, "a change is minted for the outsider (" _ tProblem _ ")")
    Set tPlan = []
    Do tPlan.%Push({"kind": "create", "body": {"Name": "OcuMftProbeN"}})
    Do tPlan.%Push({"kind": "update", "id": "OcuMftProbeA", "body": {"Username": "form@ocumftprobe.invalid"}})
    Do tPlan.%Push({"kind": "revoke", "id": "OcuMftProbeRev"})
    Do tPlan.%Push({"kind": "delete", "id": "OcuMftProbeB"})
    Do tPlan.%Push({"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))})
    Do tPlan.%Push({"kind": "entry", "descriptor": "OcuPilot.Screen.Descriptor.MftConnectionList"})
    Set tRun = ..RunAs(tUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    For tI = 1:1:5 {
        Do $$$AssertEquals(..LegText(tRun, tI), "403 AUTH.NOPRIVILEGE %Admin_Secure:USE calls=0 writes=", "leg " _ tI _ " is refused naming Security's resource before any port call")
    }
    Set tLeg = ..Leg(tRun, 6)
    Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http") _ " " _ tLeg.%Get("failedPair"), 1: ""), "403 %Admin_Secure:USE", "the screen is unavailable, naming the pair")
}

/// <p>Without <code>%DB_IRISSYS:READ</code>, every write is refused naming it before any port call.</p>
Method TestWithoutTheSystemDatabaseReadEveryWriteIsRefused()
{
    Set tUser = ..User(3)
    Set tPlan = []
    Do tPlan.%Push({"kind": "create", "body": {"Name": "OcuMftProbeN"}})
    Do tPlan.%Push({"kind": "update", "id": "OcuMftProbeA", "body": {"Username": "form@ocumftprobe.invalid"}})
    Do tPlan.%Push({"kind": "revoke", "id": "OcuMftProbeRev"})
    Do tPlan.%Push({"kind": "delete", "id": "OcuMftProbeB"})
    Set tRun = ..RunAs(tUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    For tI = 1:1:4 {
        Do $$$AssertEquals(..LegText(tRun, tI), "403 AUTH.NOPRIVILEGE %DB_IRISSYS:READ calls=0 writes=", "leg " _ tI _ " is refused naming the system database's read before any port call")
    }
}

/// <p>A write of <var>pBody</var> by <var>pMethod</var> to <var>pPath</var> over the wire as <var>pUser</var>,
/// answered as <code>status code why</code>: the failed pair, or the first violation's field.</p>
Method WireSave(pPath As %String, pMethod As %String, pBody As %DynamicObject, pUser As %String) As %String
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, tBase _ pPath, pUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders, pBody.%ToJSON(), "application/json")
    Set tAnswer = ##class(%DynamicObject).%FromJSON($Get(tBody, "{}"))
    Set tDetail = tAnswer.%Get("detail")
    Set tWhy = $Select('$IsObject(tDetail): "", 1: tDetail.%Get("failedPair"))
    Quit $Get(tStatus) _ " " _ tAnswer.%Get("code") _ " " _ tWhy
}

/// <p>The principal of entry <var>pIndex</var> of the probe's principal list.</p>
ClassMethod User(pIndex As %Integer) As %String
{
    Quit $List($ClassMethod(..#PROBE, "Users"), pIndex)
}

/// <p>A read of <var>pPath</var> under the API over the wire as <var>pUser</var>, answered as
/// <code>status failedPair</code>.</p>
Method WireRead(pPath As %String, pUser As %String) As %String
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ pPath, pUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Quit $Get(tStatus) _ " " _ ..FailedPair($Get(tBody))
}

/// <p>An envelope's <code>detail.failedPair</code>.</p>
ClassMethod FailedPair(pText As %String) As %String
{
    Set tAnswer = ##class(OcuPilot.Test.EncryptionProbe).Parsed(pText)
    If '$IsObject(tAnswer) || '$IsObject(tAnswer.%Get("detail")) Quit ""
    Quit tAnswer.%Get("detail").%Get("failedPair")
}

/// <p>Run <class>OcuPilot.Test.MftGateProbe</class> as <var>pUser</var> over <var>pPlan</var> in a child
/// process and answer what it signalled, or an object carrying <code>error</code>.</p>
Method RunAs(pUser As %String, pPlan As %DynamicArray) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Set tPlan = pPlan.%ToJSON()
        Job ##class(OcuPilot.Test.MftGateProbe).Run($Job, pUser, tPlan)::10
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
    If '$IsObject(tLeg) Quit "no leg"
    If tLeg.%Get("http") = 200 Quit "200  calls="
    Quit tLeg.%Get("http") _ " " _ tLeg.%Get("code") _ " " _ tLeg.%Get("failedPair") _ " calls=" _ tLeg.%Get("calls") _ " writes=" _ tLeg.%Get("writes")
}

}
