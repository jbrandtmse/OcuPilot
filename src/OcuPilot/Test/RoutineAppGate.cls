/// <p>Pins Story 18.31's pairs with least-privileged principals (AD-8, AD-29, measured at plan): a principal holding
/// exactly the Web applications area's two pairs, and read on the install namespace's code database, reads the list and
/// the form, creates, changes and deletes a probe application over the wire, and confirms the agent's change in a process of
/// its own; without <code>%Admin_Secure:USE</code> both reads, every write and the confirm are refused naming it and the
/// screen is unavailable; and without <code>%DB_IRISSYS:READ</code> every write and the confirm are refused naming it.
/// Every refusal leaves the application list as it found it.</p>
/// <p>The agent's confirm runs in a child process logged in as the principal
/// (<method>OcuPilot.Test.RoutineAppProbe.RunAs</method>), which reaches the real port.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates and deletes probe users, roles
/// and applications (<class>OcuPilot.Test.AuthOptionsProbe</class>'s principals) and sets the governance policy. Every probe
/// object is removed, and after each test the application list reads as that test found it.</p>
Class OcuPilot.Test.RoutineAppGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the principals, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The principal helper, which owns the three probe accounts and roles.</p>
Parameter PRINCIPALS = "OcuPilot.Test.AuthOptionsProbe";

Parameter PROBE = "OcuPilot.Test.RoutineAppProbe";

Parameter SCREEN = "webapp.routineapps";

Parameter UPDATETOOL = "OcuPilot.Screen.Tool.RoutineAppUpdate";

Parameter LIST = "OcuPilot.Screen.Descriptor.RoutineAppList";

/// <p>The principals' resources beyond the install namespace's code read, by the order of the probe's principal list:
/// the holder holds the area's two pairs; the outsider the file-system pair and the system database's read, without
/// <code>%Admin_Secure</code>; the third <code>%Admin_Secure</code> alone.</p>
Parameter RESOURCES = "%Admin_Secure:U,%DB_IRISSYS:R;%Admin_FileSystemAccess:U,%DB_IRISSYS:R;%Admin_Secure:U";

/// <p>The throwaway principals' password, generated for the run.</p>
Property PreparedPassword As %String;

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

Property PreparedFacts As %String(MAXLEN = "");

/// <p>The application list once the test's own probe applications were seeded, which every refusal leaves.</p>
Property PreparedSeeded As %String(MAXLEN = "");

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedFacts = ""
    Set ..PreparedSeeded = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.RoutineAppGate creates and deletes users, roles and privileged routine applications on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuProbe1831Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set tSC = $ClassMethod(..#PRINCIPALS, "RemoveAll")
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll"))
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = $ClassMethod(..#PROBE, "Facts")
    Kill tSettings
    Set tSettings("webapp.routineapps.create") = "enabled"
    Set tSettings("webapp.routineapps.update") = "enabled"
    Set tSettings("webapp.routineapps.delete") = "enabled"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
    If $$$ISERR(tSC) Quit tSC
    Set tRoles = $ClassMethod(..#PRINCIPALS, "Roles")
    For tI = 1:1:3 {
        Set tSC = $ClassMethod(..#PRINCIPALS, "SeedPrincipal", ..User(tI), $List(tRoles, tI), $Piece(..#RESOURCES, ";", tI), ..PreparedPassword)
        If $$$ISERR(tSC) Quit
    }
    If $$$ISERR(tSC) Quit tSC
    For tName = "OcuProbe1831A", "OcuProbe1831B" {
        Set tSC = $ClassMethod(..#PROBE, "Seed", "", tName, {"Description": "before", "Enabled": true, "Resource": ""})
        If $$$ISERR(tSC) Quit
    }
    Set ..PreparedSeeded = $ClassMethod(..#PROBE, "Facts")
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PRINCIPALS, "RemoveAll"), "every probe principal is removed")
    Do $$$AssertEquals($ClassMethod(..#PRINCIPALS, "Remaining"), 0, "and none is left")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll"), "every probe application is removed by exact name")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Remaining"), 0, "and none is left")
    Do $$$AssertNotEquals(..PreparedFacts, "unreadable", "the application list was read before the test")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts"), ..PreparedFacts, "the application list reads as before the test")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll"))
    Quit $$$ADDSC(tSC, $ClassMethod(..#PRINCIPALS, "RemoveAll"))
}

/// <p>The holder reads the list and the form, creates, changes and deletes a probe application over the wire, and confirms
/// the agent's change in a process of its own; the side bar lists the screen for it.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.WebApp.DocDbAppSave.Gate</method>, which <class>OcuPilot.Area.WebApp.RoutineAppSave</class> inherits, refuse every caller -- the
/// holder's write legs go red.</p>
Method TestTheDeclaredPairsReadAndWrite()
{
    Set tUser = ..User(1)
    Do $$$AssertEquals(..Wire("GET", "/screens/" _ ..#SCREEN _ "/read?maxRows=10", "", tUser), "200 ", "the applications read answers the holder")
    Do $$$AssertEquals(..Wire("GET", "/routine-application/form?id=" _ $ClassMethod(..#PROBE, "QueryId", $ClassMethod(..#PROBE, "Id", "", "OcuProbe1831A")), "", tUser), "200 ", "and the form read")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, "OcuProbe1831A", {"Name": "OcuProbe1831A", "Description": "agent"}, .tProposal, .tHttp, .tProblem, tUser)
    Do $$$AssertStatusOK(tSC, "the agent's change is minted for the holder (" _ tProblem _ ")")
    Set tPlan = [{"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))}, {"kind": "entry", "descriptor": (..#LIST)}]
    Set tRun = $ClassMethod(..#PROBE, "RunAs", tUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    Do $$$AssertEquals(..Leg(tRun, 1), "200 ", "the holder's confirm of the agent's change is accepted")
    Do $$$AssertEquals(..Leg(tRun, 2), "200 ", "and the side bar lists the screen for it")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredField", "", "OcuProbe1831A", "Description"), "agent", "the instance holds the change")
    Do $$$AssertEquals(..Wire("POST", "/routine-application", {"Name": "OcuProbe1831N", "Description": "holder"}, tUser), "201 ", "the holder's create is accepted")
    Do $$$AssertEquals(..Wire("PUT", "/routine-application/" _ $ClassMethod(..#PROBE, "PathId", $ClassMethod(..#PROBE, "Id", "", "OcuProbe1831N")), {"Description": "changed"}, tUser), "200 ", "and so is its change")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StoredField", "", "OcuProbe1831N", "Description"), "changed", "which the instance holds")
    Do $$$AssertEquals(..Wire("POST", "/screens/" _ ..#SCREEN _ "/action", {"action": "delete", "id": ($ClassMethod(..#PROBE, "Id", "", "OcuProbe1831B"))}, tUser), "200 ", "the holder's delete is accepted")
    Do $$$AssertEquals($IsObject($ClassMethod(..#PROBE, "Stored", "", "OcuProbe1831B")), 0, "and the application is gone")
}

/// <p>Without <code>%Admin_Secure:USE</code>, both reads, the three writes over the wire and the confirm are refused
/// naming the pair, nothing is written, and the screen is unavailable.</p>
/// <p>Mutation (Rule 19): let <method>OcuPilot.Area.WebApp.DocDbAppSave.Gate</method>, which <class>OcuPilot.Area.WebApp.RoutineAppSave</class> inherits, pass every caller -- the create
/// leg writes the application and goes red.</p>
Method TestWithoutTheAreasResourceEveryReadAndWriteIsRefused()
{
    Set tUser = ..User(2)
    Set tPair = "%Admin_Secure:USE"
    Do $$$AssertEquals(..Wire("GET", "/screens/" _ ..#SCREEN _ "/read?maxRows=10", "", tUser), "403 " _ tPair, "the read is refused naming the pair")
    Do $$$AssertEquals(..Wire("GET", "/routine-application/form", "", tUser), "403 " _ tPair, "and the form read")
    Do $$$AssertEquals(..Wire("POST", "/routine-application", {"Name": "OcuProbe1831N"}, tUser), "403 " _ tPair, "and a create")
    Do $$$AssertEquals(..Wire("PUT", "/routine-application/" _ $ClassMethod(..#PROBE, "PathId", $ClassMethod(..#PROBE, "Id", "", "OcuProbe1831A")), {"Description": "outsider"}, tUser), "403 " _ tPair, "and a change")
    Do $$$AssertEquals(..Wire("POST", "/screens/" _ ..#SCREEN _ "/action", {"action": "delete", "id": ($ClassMethod(..#PROBE, "Id", "", "OcuProbe1831B"))}, tUser), "403 " _ tPair, "and a delete")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, "OcuProbe1831A", {"Name": "OcuProbe1831A", "Description": "agent"}, .tProposal, .tHttp, .tProblem, tUser)
    Do $$$AssertStatusOK(tSC, "a change is minted for the outsider (" _ tProblem _ ")")
    Set tPlan = [{"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))}, {"kind": "entry", "descriptor": (..#LIST)}]
    Set tRun = $ClassMethod(..#PROBE, "RunAs", tUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    Do $$$AssertEquals(..Leg(tRun, 1), "403 " _ tPair, "the confirm is refused naming the pair")
    Do $$$AssertEquals(..Leg(tRun, 2), "403 " _ tPair, "and the screen is unavailable, naming it")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts"), ..PreparedSeeded, "nothing was written")
}

/// <p>Without <code>%DB_IRISSYS:READ</code>, every write and the confirm are refused naming it, and nothing is
/// written.</p>
/// <p>Mutation (Rule 19): let <method>OcuPilot.Area.WebApp.DocDbAppSave.Gate</method>, which <class>OcuPilot.Area.WebApp.RoutineAppSave</class> inherits, pass every caller -- its create and
/// change legs go red.</p>
Method TestWithoutTheSystemDatabaseReadEveryWriteIsRefused()
{
    Set tUser = ..User(3)
    Set tPair = "%DB_IRISSYS:READ"
    Do $$$AssertEquals(..Wire("POST", "/routine-application", {"Name": "OcuProbe1831N"}, tUser), "403 " _ tPair, "a create is refused naming the system database's read")
    Do $$$AssertEquals(..Wire("PUT", "/routine-application/" _ $ClassMethod(..#PROBE, "PathId", $ClassMethod(..#PROBE, "Id", "", "OcuProbe1831A")), {"Description": "third"}, tUser), "403 " _ tPair, "and a change")
    Do $$$AssertEquals(..Wire("POST", "/screens/" _ ..#SCREEN _ "/action", {"action": "delete", "id": ($ClassMethod(..#PROBE, "Id", "", "OcuProbe1831B"))}, tUser), "403 " _ tPair, "and a delete")
    Set tSC = $ClassMethod(..#PROBE, "Mint", ..#UPDATETOOL, "OcuProbe1831A", {"Name": "OcuProbe1831A", "Description": "agent"}, .tProposal, .tHttp, .tProblem, tUser)
    Do $$$AssertStatusOK(tSC, "a change is minted for the third principal (" _ tProblem _ ")")
    Set tRun = $ClassMethod(..#PROBE, "RunAs", tUser, [{"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))}])
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    Do $$$AssertEquals(..Leg(tRun, 1), "403 " _ tPair, "the confirm is refused naming it")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts"), ..PreparedSeeded, "nothing was written")
}

/// <p>A request by <var>pMethod</var> to <var>pPath</var> under the API over the wire as <var>pUser</var> with the JSON
/// <var>pBody</var>, answered as <code>status failedPair</code>: the failed pair, or <code>""</code>.</p>
Method Wire(pMethod As %String, pPath As %String, pBody As %DynamicObject, pUser As %String) As %String
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, tBase _ pPath, pUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders, $Select($IsObject(pBody): pBody.%ToJSON(), 1: ""), "application/json")
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
