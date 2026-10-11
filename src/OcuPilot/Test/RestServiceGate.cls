/// <p>Pins Story 18.32's pairs with least-privileged principals (AD-8, AD-29): a principal holding exactly the REST API
/// explorer's two pairs, <code>%Development:USE</code>, <code>%DB_USER:RW</code> and read on the install namespace's code
/// database confirms the agent's create in <code>USER</code> in a process of its own and deletes a probe service through the
/// explorer's action; without <code>%Development:USE</code> both writes are refused naming it, and holding
/// <code>%DB_USER:READ</code> without WRITE both are refused naming <code>%DB_USER:WRITE</code> -- each before the
/// management API port is reached, so nothing is built or deleted.</p>
/// <p>The agent's confirm runs in a child process logged in as the principal
/// (<method>OcuPilot.Test.RestServiceProbe.RunAs</method>), which reaches the real port.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, a <code>USER</code> namespace, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates and deletes probe users, roles
/// and services (<class>OcuPilot.Test.AuthOptionsProbe</class>'s principals) and sets the governance policy. Every probe
/// object is removed, and after each test the probe state reads as that test found it.</p>
Class OcuPilot.Test.RestServiceGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the principals, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The principal helper, which owns the three probe accounts and roles.</p>
Parameter PRINCIPALS = "OcuPilot.Test.AuthOptionsProbe";

Parameter PROBE = "OcuPilot.Test.RestServiceProbe";

Parameter CREATETOOL = "OcuPilot.Screen.Tool.RestServiceCreate";

Parameter NAMESPACE = "USER";

/// <p>The explorer's action route, relative to the API base.</p>
Parameter ACTIONPATH = "/screens/webapp.restapis/action";

/// <p>The principals' resources beyond the install namespace's code read, by the order of the probe's principal list: the
/// holder holds the screen's two pairs, the code editors' resource and read and write on <code>USER</code>'s database;
/// the second lacks the code editors' resource; the third holds only read on <code>USER</code>'s database.</p>
Parameter RESOURCES = "%Admin_Secure:U,%DB_IRISSYS:R,%Development:U,%DB_USER:RW;%Admin_Secure:U,%DB_IRISSYS:R,%DB_USER:RW;%Admin_Secure:U,%DB_IRISSYS:R,%Development:U,%DB_USER:R";

/// <p>The throwaway principals' password, generated for the run.</p>
Property PreparedPassword As %String;

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

/// <p>The probe state once the test's own probe services were built, which every refusal leaves.</p>
Property PreparedSeeded As %String(MAXLEN = "");

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedSeeded = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, $ClassName() _ " creates and deletes users, roles and REST services on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuRestGate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set tSC = $ClassMethod(..#PRINCIPALS, "RemoveAll")
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", ..#NAMESPACE))
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Kill tSettings
    Set tSettings("webapp.restapis.create") = "enabled"
    Set tSettings("webapp.restapis.delete") = "enabled"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
    If $$$ISERR(tSC) Quit tSC
    Set tRoles = $ClassMethod(..#PRINCIPALS, "Roles")
    For tI = 1:1:3 {
        Set tSC = $ClassMethod(..#PRINCIPALS, "SeedPrincipal", ..User(tI), $List(tRoles, tI), $Piece(..#RESOURCES, ";", tI), ..PreparedPassword)
        If $$$ISERR(tSC) Quit
    }
    If $$$ISERR(tSC) Quit tSC
    For tName = "OcuProbe1832A", "OcuProbe1832B" {
        Set tSC = $ClassMethod(..#PROBE, "Seed", ..#NAMESPACE, tName)
        If $$$ISERR(tSC) Quit
    }
    Set ..PreparedSeeded = $ClassMethod(..#PROBE, "Facts", ..#NAMESPACE)
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PRINCIPALS, "RemoveAll"), "every probe principal is removed")
    Do $$$AssertEquals($ClassMethod(..#PRINCIPALS, "Remaining"), 0, "and none is left")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", ..#NAMESPACE), "every probe service is removed")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Remaining", ..#NAMESPACE), 0, "and none is left")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", ..#NAMESPACE))
    Quit $$$ADDSC(tSC, $ClassMethod(..#PRINCIPALS, "RemoveAll"))
}

/// <p>The holder confirms the agent's create of a new probe service in a process of its own, and deletes another through
/// the explorer's action over the wire; the instance holds the first and no longer lists the second.</p>
/// <p>Mutation (Rule 19): add <code>%Admin_Manage:USE</code> to <parameter>OcuPilot.Port.MgmntPort.WRITEPAIRS</parameter> --
/// the holder lacks it, the port refuses both legs and this goes red.</p>
Method TestTheDeclaredPairsCreateAndDelete()
{
    Set tUser = ..User(1)
    Set tSC = ..MintCreate("OcuProbe1832N", tUser, .tProposal)
    Do $$$AssertStatusOK(tSC, "the agent's create is minted for the holder")
    Set tRun = $ClassMethod(..#PROBE, "RunAs", tUser, [{"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))}])
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    Do $$$AssertEquals(..Leg(tRun, 1), "200 ", "the holder's confirm of the agent's create is accepted")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Classes", ..#NAMESPACE, "OcuProbe1832N"), "111", "the instance holds the new service")
    Do $$$AssertEquals(..Wire("POST", ..#ACTIONPATH, {"action": "delete", "id": "OcuProbe1832B"}, tUser), "200 ", "the holder's delete is accepted")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Classes", ..#NAMESPACE, "OcuProbe1832B"), "001", "and the service's specification and dispatch classes are gone")
}

/// <p>Without <code>%Development:USE</code>, the delete over the wire and the confirm of the agent's create are each
/// refused 403 naming the pair, and nothing is built or deleted.</p>
/// <p>Mutation (Rule 19): drop the added pair from <method>OcuPilot.Screen.Tool.RestServiceWrite.PrivilegePairs</method> and
/// name <code>%Admin_Secure:USE</code> in <parameter>OcuPilot.Port.MgmntPort.WRITEPAIRS</parameter> -- both legs write and
/// go red.</p>
Method TestWithoutTheCodeEditorsResourceEveryWriteIsRefused()
{
    Do ..AssertRefused(..User(2), "%Development:USE")
}

/// <p>Holding <code>%DB_USER:READ</code> without WRITE, the delete over the wire and the confirm of the agent's create are
/// each refused 403 naming <code>%DB_USER:WRITE</code>, and nothing is built or deleted.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Screen.Tool.RestServiceWrite.ArgumentPairs</method> answer no pair -- the
/// confirm leg goes red (the port's own write pairs still refuse the delete).</p>
Method TestWithReadButNotWriteOnTheCodeDatabaseEveryWriteIsRefused()
{
    Do ..AssertRefused(..User(3), "%DB_USER:WRITE")
}

/// <p>Both writes as principal <var>pUser</var> are refused 403 naming <var>pPair</var>, and the probe state is as it
/// was.</p>
Method AssertRefused(pUser As %String, pPair As %String)
{
    Do $$$AssertEquals(..Wire("POST", ..#ACTIONPATH, {"action": "delete", "id": "OcuProbe1832B"}, pUser), "403 " _ pPair, "a delete is refused naming the pair")
    Set tSC = ..MintCreate("OcuProbe1832N", pUser, .tProposal)
    Do $$$AssertStatusOK(tSC, "a create is minted for " _ pUser)
    Set tRun = $ClassMethod(..#PROBE, "RunAs", pUser, [{"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))}])
    Do $$$AssertEquals(..Ran(tRun), pUser _ " 1", "the child process ran as " _ pUser)
    Do $$$AssertEquals(..Leg(tRun, 1), "403 " _ pPair, "the confirm is refused naming the pair")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts", ..#NAMESPACE), ..PreparedSeeded, "nothing was built or deleted")
}

/// <p>Mint the agent's create of <var>pName</var> for <var>pUser</var> in <parameter>NAMESPACE</parameter>.</p>
Method MintCreate(pName As %String, pUser As %String, Output pProposal As %DynamicObject) As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tArgs = {"Name": (pName), "Document": ($ClassMethod(..#PROBE, "Document"))}
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#CREATETOOL, pName, tArgs, .pProposal, .tHttp, .tProblem, pUser)
    Quit tSC
}

/// <p>A request by <var>pMethod</var> to <var>pPath</var> under the API over the wire as <var>pUser</var> with the JSON
/// <var>pBody</var>, scoped to <parameter>NAMESPACE</parameter>, answered as <code>status failedPair</code>: the failed pair,
/// or <code>""</code>.</p>
Method Wire(pMethod As %String, pPath As %String, pBody As %DynamicObject, pUser As %String) As %String
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, tBase _ pPath _ "?ns=" _ ..#NAMESPACE, pUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders, $Select($IsObject(pBody): pBody.%ToJSON(), 1: ""), "application/json")
    Set tAnswer = ""
    Try { Set tAnswer = ##class(%DynamicObject).%FromJSON($Get(tBody, "{}")) } Catch {}
    Set tDetail = $Select($IsObject(tAnswer): tAnswer.%Get("detail"), 1: "")
    Quit $Get(tStatus) _ " " _ $Select($IsObject(tDetail): tDetail.%Get("failedPair"), 1: "")
}

/// <p>The principal of entry <var>pIndex</var> of the probe's principal list.</p>
ClassMethod User(pIndex As %Integer) As %String
{
    Quit $List($ClassMethod(..#PRINCIPALS, "Users"), pIndex)
}

/// <p>Who the child ran as, <code>username loggedIn</code>, or its error
/// (<method>OcuPilot.Test.NamespaceWriteGate.Ran</method>).</p>
ClassMethod Ran(pRun As %DynamicObject) As %String
{
    Quit ##class(OcuPilot.Test.NamespaceWriteGate).Ran(pRun)
}

/// <p>Step <var>pIndex</var> (from 1) of the child's answer <var>pRun</var> as <code>http failedPair</code>, or
/// <code>no leg</code>.</p>
ClassMethod Leg(pRun As %DynamicObject, pIndex As %Integer) As %String
{
    If '$IsObject(pRun) || (pRun.%GetTypeOf("steps") '= "array") Quit "no leg"
    Set tLeg = pRun.%Get("steps").%Get(pIndex - 1)
    If '$IsObject(tLeg) Quit "no leg"
    Quit tLeg.%Get("http") _ " " _ tLeg.%Get("failedPair")
}

}
