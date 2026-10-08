/// <p>Pins Story 18.9's pairs with least-privileged principals (AD-8, AD-29, measured at plan): a principal holding
/// exactly Security's two pairs plus READ on <code>USER</code>'s database reads the privileges over the wire, and
/// lists, grants and revokes in <code>USER</code> -- on the screen's row actions in process and, over the wire, the
/// revoke of a row another account granted -- and confirms the agent's grant; the instance's grantor rule refuses
/// a grant by a principal who does not hold the privilege with the grant option, 403 <code>SQLPRIV.GRANTOR</code>;
/// without READ on <code>USER</code>'s database, or without <code>%Admin_Secure:USE</code>, the read, each
/// action and the confirm are refused naming the pair, and in process before any port call.</p>
/// <p>The in-process legs run in a child process logged in as the principal
/// (<class>OcuPilot.Test.SqlPrivilegeGateProbe</class>), whose <class>OcuPilot.Test.SqlPrivilegeSeamPort</class> sends
/// a write for a probe name alone and records it.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates and deletes probe users
/// and roles (<class>OcuPilot.Test.AuthOptionsProbe</class>'s principals and
/// <class>OcuPilot.Test.SqlPrivilegeProbe</class>'s) and a probe schema's objects, sets privileges on them and
/// sets the governance policy. Every probe object is removed, and after each test the probe schema reads as that
/// test found it.</p>
Class OcuPilot.Test.SqlPrivilegeGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the principals, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The principal helper, which owns the three probe accounts and roles.</p>
Parameter PROBE = "OcuPilot.Test.AuthOptionsProbe";

Parameter SQLPROBE = "OcuPilot.Test.SqlPrivilegeProbe";

Parameter SCREEN = "permissions.sqlprivileges";

Parameter USERS = "permissions.users";

/// <p>The principals' resources beyond the install namespace's code read, by the order of the probe's principal
/// list: the holder holds Security's two pairs and READ on <code>USER</code>'s database; the second the same without
/// the database; the third the database and the system database without Security's resource, and
/// <code>%Admin_Operate</code> so that the API's administrative gate admits it.</p>
Parameter RESOURCES = "%Admin_Secure:U,%DB_IRISSYS:R,%DB_USER:R;%Admin_Secure:U,%DB_IRISSYS:R;%Admin_Operate:U,%DB_IRISSYS:R,%DB_USER:R";

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
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlPrivilegeGate creates and deletes users and roles and sets SQL privileges on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuProbe189Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set tSC = $ClassMethod(..#PROBE, "RemoveAll")
    Quit $$$ADDSC(tSC, $ClassMethod(..#SQLPROBE, "RemoveAll"))
}

Method OnBeforeOneTest() As %Status
{
    Kill tSettings
    For tKey = "permissions.users.grantsql", "permissions.users.revokesql", "permissions.roles.grantsql", "permissions.roles.revokesql" Set tSettings(tKey) = "enabled"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#SQLPROBE, "Seed")
    If $$$ISERR(tSC) Quit tSC
    Set tRoles = $ClassMethod(..#PROBE, "Roles")
    For tI = 1:1:3 {
        Set tSC = $ClassMethod(..#PROBE, "SeedPrincipal", ..User(tI), $List(tRoles, tI), $Piece(..#RESOURCES, ";", tI), ..PreparedPassword)
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
    Do $$$AssertStatusOK($ClassMethod(..#SQLPROBE, "RemoveAll"), "every probe SQL object is removed")
    Do $$$AssertEquals($ClassMethod(..#SQLPROBE, "Remaining"), 0, "and none is left")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#SQLPROBE, "RemoveAll"))
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll"))
}

/// <p>The holder reads the privileges over the wire; in process it grants and revokes through the screen's row
/// actions, each reaching the seam as one write, and confirms the agent's grant; over the wire it revokes a row
/// another account granted, which removes it; and a grant by a principal who does not hold the privilege with the
/// grant option is refused 403 <code>SQLPRIV.GRANTOR</code> with nothing stored.</p>
Method TestTheDeclaredPairsReadGrantAndRevoke()
{
    Set tProbe = ..#SQLPROBE
    Set tUser = ..User(1)
    Set tGrantee = $Parameter(tProbe, "USER")
    Set tTable = $Parameter(tProbe, "TABLE")
    Set tTable2 = $Parameter(tProbe, "TABLE2")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "Grant", tUser, "TABLE", tTable, "SELECT", 1), "the holder holds SELECT on the probe table with the grant option")
    Do $$$AssertEquals(..WireRead("/screens/" _ ..#SCREEN _ "/read?grantee=" _ tGrantee _ "&namespace=USER&maxRows=100", tUser), "200 ", "the privileges read answers the holder")
    Set tSC = $ClassMethod(tProbe, "Mint", "OcuPilot.Screen.Tool.UserSqlGrant", tGrantee, ##class(OcuPilot.Test.SqlPrivilegeWrite).Args(tGrantee, "SELECT", 0), .tProposal, .tHttp, .tProblem, tUser)
    Do $$$AssertStatusOK(tSC, "the agent's grant is minted for the holder (" _ tProblem _ ")")
    Set tBody = {"action": "grant-sql", "id": (tGrantee), "values": {"Namespace": "USER", "Type": "TABLE", "Object": (tTable), "Action": "SELECT", "WithGrant": "false"}}
    Set tRevoke = {"action": "revoke-sql", "id": (tGrantee), "values": {"Namespace": "USER", "Type": "TABLE", "Object": (tTable), "Action": "SELECT"}}
    Set tPlan = []
    Do tPlan.%Push({"kind": "action", "screen": (..#USERS), "body": (tBody)})
    Do tPlan.%Push({"kind": "action", "screen": (..#USERS), "body": (tRevoke)})
    Do tPlan.%Push({"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))})
    Set tRun = ..RunAs(tUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    For tCase = $ListBuild(1, "the grant"), $ListBuild(2, "the revoke"), $ListBuild(3, "the agent's confirm") {
        Set tLeg = ..Leg(tRun, $List(tCase, 1))
        Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http"), 1: ""), 200, $List(tCase, 2) _ " answers 200 (" _ ..LegText(tRun, $List(tCase, 1)) _ ")")
    }
    Do $$$AssertEquals($ZConvert(..Leg(tRun, 1).%Get("writes"), "U"), "GRANT:" _ $ZConvert(tGrantee, "U") _ ":", "the grant reached the seam as one write")
    Do $$$AssertEquals($ZConvert(..Leg(tRun, 2).%Get("writes"), "U"), "REVOKE:" _ $ZConvert(tGrantee, "U") _ ":" _ $ZConvert(tUser, "U"), "and the revoke as one, naming the holder as the grantor")
    Do $$$AssertEquals($ZConvert(..Leg(tRun, 3).%Get("writes"), "U"), "GRANT:" _ $ZConvert(tGrantee, "U") _ ":", "and the confirm as one")
    Do $$$AssertEquals($ClassMethod(tProbe, "Direct", tGrantee, tTable, "SELECT"), 1, "the confirmed grant stands")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "Grant", tGrantee, "TABLE", tTable2, "UPDATE"), "a row granted by the running account")
    Set tRevokeOther = {"action": "revoke-sql", "id": (tGrantee), "values": {"Namespace": "USER", "Type": "TABLE", "Object": (tTable2), "Action": "UPDATE"}}
    Do $$$AssertEquals(..WireAction(tUser, tRevokeOther), "200 ", "the holder revokes it over the wire, as a principal who did not grant it")
    Do $$$AssertEquals($ClassMethod(tProbe, "Direct", tGrantee, tTable2, "UPDATE"), 0, "and the row is gone")
    Set tGrantOther = {"action": "grant-sql", "id": (tGrantee), "values": {"Namespace": "USER", "Type": "TABLE", "Object": (tTable2), "Action": "UPDATE", "WithGrant": "false"}}
    Do $$$AssertEquals(..WireAction(tUser, tGrantOther), "403 SQLPRIV.GRANTOR", "a grant of a privilege the holder does not hold with the grant option is refused by the instance's grantor rule")
    Do $$$AssertEquals($ClassMethod(tProbe, "Direct", tGrantee, tTable2, "UPDATE"), 0, "and stores nothing")
}

/// <p>Without READ on <code>USER</code>'s database, the read over the wire and every action and the confirm in
/// process are refused naming it, in process with zero port calls.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.SqlPrivilegeWrite.ArgumentPairs</method> answer none --
/// the action legs reach the port and go red.</p>
Method TestWithoutTheNamespaceDatabaseReadEveryCallIsRefused()
{
    Set tProbe = ..#SQLPROBE
    Set tUser = ..User(2)
    Set tGrantee = $Parameter(tProbe, "USER")
    Do $$$AssertEquals(..WireRead("/screens/" _ ..#SCREEN _ "/read?grantee=" _ tGrantee _ "&namespace=USER&maxRows=100", tUser), "403 %DB_USER:READ", "the read is refused naming the database's pair")
    Set tSC = $ClassMethod(tProbe, "Mint", "OcuPilot.Screen.Tool.UserSqlGrant", tGrantee, ##class(OcuPilot.Test.SqlPrivilegeWrite).Args(tGrantee, "SELECT", 0), .tProposal, .tHttp, .tProblem, tUser)
    Do $$$AssertStatusOK(tSC, "a grant is minted for the principal (" _ tProblem _ ")")
    Set tPlan = ..Plan(tGrantee, $Select($IsObject($Get(tProposal)): tProposal.%Get("proposalId"), 1: ""))
    Set tRun = ..RunAs(tUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    For tI = 1:1:5 {
        Do $$$AssertEquals(..LegText(tRun, tI), "403 AUTH.NOPRIVILEGE %DB_USER:READ calls=0 writes=", "leg " _ tI _ " is refused naming the database's read before any port call")
    }
    Do $$$AssertEquals($ClassMethod(tProbe, "Rows", tGrantee), "", "and nothing was granted")
}

/// <p>Without <code>%Admin_Secure:USE</code>, the read over the wire and every action and the confirm in process are
/// refused naming it, in process with zero port calls, and the screen is unavailable.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.SqlPrivilegeWrite.PrivilegePairs</method> answer none --
/// the legs reach the port and go red.</p>
Method TestWithoutSecuritysResourceEveryCallIsRefused()
{
    Set tProbe = ..#SQLPROBE
    Set tUser = ..User(3)
    Set tGrantee = $Parameter(tProbe, "USER")
    Do $$$AssertEquals(..WireRead("/screens/" _ ..#SCREEN _ "/read?grantee=" _ tGrantee _ "&namespace=USER&maxRows=100", tUser), "403 %Admin_Secure:USE", "the read is refused naming the pair")
    Set tSC = $ClassMethod(tProbe, "Mint", "OcuPilot.Screen.Tool.UserSqlGrant", tGrantee, ##class(OcuPilot.Test.SqlPrivilegeWrite).Args(tGrantee, "SELECT", 0), .tProposal, .tHttp, .tProblem, tUser)
    Do $$$AssertStatusOK(tSC, "a grant is minted for the outsider (" _ tProblem _ ")")
    Set tPlan = ..Plan(tGrantee, $Select($IsObject($Get(tProposal)): tProposal.%Get("proposalId"), 1: ""))
    Do tPlan.%Push({"kind": "entry", "descriptor": "OcuPilot.Screen.Descriptor.SqlPrivilegeList"})
    Set tRun = ..RunAs(tUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    For tI = 1:1:5 {
        Do $$$AssertEquals(..LegText(tRun, tI), "403 AUTH.NOPRIVILEGE %Admin_Secure:USE calls=0 writes=", "leg " _ tI _ " is refused naming Security's resource before any port call")
    }
    Set tLeg = ..Leg(tRun, 6)
    Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http") _ " " _ tLeg.%Get("failedPair"), 1: ""), "403 %Admin_Secure:USE", "the screen is unavailable, naming the pair")
    Do $$$AssertEquals($ClassMethod(tProbe, "Rows", tGrantee), "", "and nothing was granted")
}

/// <p>The plan of the five steps that must be refused: the grant and revoke on the Users list, the same on the
/// Roles list, and the confirm of proposal <var>pProposalId</var>.</p>
ClassMethod Plan(pGrantee As %String, pProposalId As %String) As %DynamicArray
{
    Set tTable = $Parameter(..#SQLPROBE, "TABLE")
    Set tValues = {"Namespace": "USER", "Type": "TABLE", "Object": (tTable), "Action": "SELECT"}
    Set tPlan = []
    Set tGrant = {"Namespace": "USER", "Type": "TABLE", "Object": (tTable), "Action": "SELECT", "WithGrant": "false"}
    Do tPlan.%Push({"kind": "action", "screen": "permissions.users", "body": {"action": "grant-sql", "id": (pGrantee), "values": (tGrant)}})
    Do tPlan.%Push({"kind": "action", "screen": "permissions.users", "body": {"action": "revoke-sql", "id": (pGrantee), "values": (tValues)}})
    Do tPlan.%Push({"kind": "action", "screen": "permissions.roles", "body": {"action": "grant-sql", "id": ($Parameter(..#SQLPROBE, "ROLE")), "values": (tGrant)}})
    Do tPlan.%Push({"kind": "action", "screen": "permissions.roles", "body": {"action": "revoke-sql", "id": ($Parameter(..#SQLPROBE, "ROLE")), "values": (tValues)}})
    Do tPlan.%Push({"kind": "confirm", "proposalId": (pProposalId)})
    Quit tPlan
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

/// <p>The screen action <var>pBody</var> over the wire as <var>pUser</var> to the Users list, answered as
/// <code>status code</code>.</p>
Method WireAction(pUser As %String, pBody As %DynamicObject) As %String
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ "/screens/" _ ..#USERS _ "/action", pUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders, pBody.%ToJSON(), "application/json")
    Set tAnswer = ##class(%DynamicObject).%FromJSON($Get(tBody, "{}"))
    Quit $Get(tStatus) _ " " _ tAnswer.%Get("code")
}

/// <p>An envelope's <code>detail.failedPair</code>.</p>
ClassMethod FailedPair(pText As %String) As %String
{
    Set tAnswer = ##class(OcuPilot.Test.EncryptionProbe).Parsed(pText)
    If '$IsObject(tAnswer) || '$IsObject(tAnswer.%Get("detail")) Quit ""
    Quit tAnswer.%Get("detail").%Get("failedPair")
}

/// <p>Run <class>OcuPilot.Test.SqlPrivilegeGateProbe</class> as <var>pUser</var> over <var>pPlan</var> in a child
/// process and answer what it signalled, or an object carrying <code>error</code>.</p>
Method RunAs(pUser As %String, pPlan As %DynamicArray) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Set tPlan = pPlan.%ToJSON()
        Job ##class(OcuPilot.Test.SqlPrivilegeGateProbe).Run($Job, pUser, tPlan)::10
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
