/// <p>Pins Story 18.8's pairs with least-privileged principals (A2; AD-8, AD-29, measured at Task 0): a
/// principal holding exactly Security's two pairs reads the options and the form over the wire, and in process
/// saves a change and the SMTP password and confirms the agent's; without <code>%Admin_Secure:USE</code> both
/// reads, the Save and the confirm are refused naming it and the screen is unavailable; and without
/// <code>%DB_IRISSYS:READ</code> the Save is refused naming it. Every refusal comes before any port call.</p>
/// <p>The in-process legs run in a child process logged in as the principal
/// (<class>OcuPilot.Test.AuthOptionsGateProbe</class>), whose <class>OcuPilot.Test.AuthOptionsSeamPort</class>
/// is armed <code>answer</code>, so no setting changes.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates and deletes probe
/// users and roles (<class>OcuPilot.Test.AuthOptionsProbe</class>) and sets the governance policy. Every probe
/// object is removed, and after each test the authentication facts read as that test found them.</p>
Class OcuPilot.Test.AuthOptionsGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the principals, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.AuthOptionsProbe";

Parameter SCREEN = "security.authoptions";

Parameter TOOL = "OcuPilot.Screen.Tool.AuthOptionsUpdate";

Parameter PASSWORDTOOL = "OcuPilot.Screen.Tool.AuthOptionsSmtpPassword";

Parameter SEAM = "OcuPilot.Test.AuthOptionsSeamPort";

/// <p>The principals' resources beyond the install namespace's code read, by the order of the probe's
/// principal list: the holder holds Security's two pairs; the outsider the file-system pair and the system
/// database's read, without Security's resource; the third Security's resource alone.</p>
Parameter RESOURCES = "%Admin_Secure:U,%DB_IRISSYS:R;%Admin_FileSystemAccess:U,%DB_IRISSYS:R;%Admin_Secure:U";

/// <p>The throwaway principals' password, generated for the run.</p>
Property PreparedPassword As %String;

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

/// <p>The authentication facts before each test.</p>
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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AuthOptionsGate creates and deletes users and roles on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuProbe188Gate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll")
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = $ClassMethod(..#PROBE, "Facts").%ToJSON()
    Kill tSettings
    Set tSettings("security.authoptions.update") = "enabled"
    Set tSettings("security.authoptions.smtppassword") = "enabled"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
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
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts").%ToJSON(), ..PreparedFacts, "no authentication setting moved")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll"))
}

/// <p>The holder reads the options and the form over the wire and a Save that changes nothing answers
/// <code>{}</code>; in process it saves a change and the SMTP password and confirms the agent's change, each
/// write reaching the seam as one <code>PUT</code> or one password write.</p>
Method TestTheDeclaredPairsReadAndWrite()
{
    Set tUser = ..User(1)
    Do $$$AssertEquals(..WireRead("/screens/" _ ..#SCREEN _ "/read?maxRows=1", tUser), "200 ", "the options read answers the holder")
    Do $$$AssertEquals(..WireRead("/authentication-options/form", tUser), "200 ", "and the form read")
    Do $$$AssertEquals(..WireSave(##class(OcuPilot.Test.AuthOptionsWrite).FullBody({}), tUser, 200), "200  ", "over the wire, a Save of the settings as they stand answers and changes nothing")
    Do $$$AssertEquals(..WireSave({"Extra": "x"}, tUser, 400), "400 PORT.FIELD.UNEXPECTED Extra", "and one carrying a key outside the form's is refused before any port call")
    Set tSC = $ClassMethod("OcuPilot.Test.LicenseProbe", "Mint", ..#TOOL, "SYSTEM", {"Name": "SYSTEM", "LoginCookieTimeout": 45}, .tProposal, .tHttp, .tProblem, tUser)
    Do $$$AssertStatusOK(tSC, "the agent's change is minted for the holder (" _ tProblem _ ")")
    Set tPlan = []
    Do tPlan.%Push({"kind": "save", "body": {"LoginCookieTimeout": 30}})
    Do tPlan.%Push({"kind": "save", "body": {"SMTPPassword": "OcuProbe188Pw1"}})
    Do tPlan.%Push({"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))})
    Set tRun = ..RunAs(tUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    For tCase = $ListBuild(1, "Security.WebAuth/PUT", "the Save"), $ListBuild(2, "Security.WebAuth/CHANGESMTPPWD", "the password Save"), $ListBuild(3, "Security.WebAuth/PUT", "the agent's confirm") {
        Set tLeg = ..Leg(tRun, $List(tCase, 1))
        Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http") _ " " _ tLeg.%Get("writes"), 1: ""), "200 " _ $List(tCase, 2), $List(tCase, 3) _ " writes once (" _ ..LegText(tRun, $List(tCase, 1)) _ ")")
    }
}

/// <p>Without <code>%Admin_Secure:USE</code>, both reads and the Save over the wire, and in process the Save
/// and the confirm, are refused naming the pair with zero port calls, and the screen is unavailable.</p>
/// <p>Mutation (Rule 19): let <method>OcuPilot.Area.Security.AuthOptionsSave.Gate</method> pass every caller --
/// the Save legs reach the port and go red.</p>
Method TestWithoutSecuritysResourceEveryReadAndWriteIsRefused()
{
    Set tUser = ..User(2)
    Do $$$AssertEquals(..WireRead("/screens/" _ ..#SCREEN _ "/read?maxRows=1", tUser), "403 %Admin_Secure:USE", "the options read is refused naming the pair")
    Do $$$AssertEquals(..WireRead("/authentication-options/form", tUser), "403 %Admin_Secure:USE", "and the form read")
    Do $$$AssertEquals(..WireSave({"LoginCookieTimeout": 30}, tUser, 403), "403 AUTH.NOPRIVILEGE %Admin_Secure:USE", "and the Save over the wire")
    Set tSC = $ClassMethod("OcuPilot.Test.LicenseProbe", "Mint", ..#TOOL, "SYSTEM", {"Name": "SYSTEM", "LoginCookieTimeout": 45}, .tProposal, .tHttp, .tProblem, tUser)
    Do $$$AssertStatusOK(tSC, "a change is minted for the outsider (" _ tProblem _ ")")
    Set tPlan = []
    Do tPlan.%Push({"kind": "save", "body": {"LoginCookieTimeout": 30}})
    Do tPlan.%Push({"kind": "save", "body": {"SMTPPassword": "OcuProbe188Pw1"}})
    Do tPlan.%Push({"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))})
    Do tPlan.%Push({"kind": "entry", "descriptor": "OcuPilot.Screen.Descriptor.AuthOptions"})
    Set tRun = ..RunAs(tUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    For tI = 1, 2, 3 {
        Do $$$AssertEquals(..LegText(tRun, tI), "403 AUTH.NOPRIVILEGE %Admin_Secure:USE calls=0 writes=", "leg " _ tI _ " is refused naming Security's resource before any port call")
    }
    Set tLeg = ..Leg(tRun, 4)
    Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http") _ " " _ tLeg.%Get("failedPair"), 1: ""), "403 %Admin_Secure:USE", "the screen is unavailable, naming the pair")
}

/// <p>Without <code>%DB_IRISSYS:READ</code>, the Save and the password Save are refused naming it before any
/// port call.</p>
Method TestWithoutTheSystemDatabaseReadTheSaveIsRefused()
{
    Set tUser = ..User(3)
    Set tPlan = []
    Do tPlan.%Push({"kind": "save", "body": {"LoginCookieTimeout": 30}})
    Do tPlan.%Push({"kind": "save", "body": {"SMTPPassword": "OcuProbe188Pw1"}})
    Set tRun = ..RunAs(tUser, tPlan)
    Do $$$AssertEquals(..Ran(tRun), tUser _ " 1", "the child process ran as " _ tUser)
    For tI = 1, 2 {
        Do $$$AssertEquals(..LegText(tRun, tI), "403 AUTH.NOPRIVILEGE %DB_IRISSYS:READ calls=0 writes=", "leg " _ tI _ " is refused naming the system database's read before any port call")
    }
}

/// <p>A Save of <var>pBody</var> over the wire as <var>pUser</var>, which must answer <var>pStatus</var> as
/// JSON, answered as <code>status code why</code>: the failed pair, or the first violation's field. The real
/// port answers this process, so a caller sends only settings the instance holds: a Save that got past a
/// refusal would change nothing.</p>
Method WireSave(pBody As %DynamicObject, pUser As %String, pStatus As %Integer) As %String
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ "/authentication-options", pUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders, pBody.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, pStatus, "PUT /authentication-options answers " _ pStatus _ ": " _ $Extract($Get(tBody), 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Set tAnswer = ##class(%DynamicObject).%FromJSON($Get(tBody, "{}"))
    Set tDetail = tAnswer.%Get("detail")
    Set tWhy = $Select('$IsObject(tDetail): "", tDetail.%Get("failedPair") '= "": tDetail.%Get("failedPair"), (tDetail.%GetTypeOf("violations") = "array") && (tDetail.%Get("violations").%Size() > 0): tDetail.%Get("violations").%Get(0).%Get("field"), 1: "")
    Set tCode = tAnswer.%Get("code")
    If (tCode = "") && $IsObject(tDetail) && (tDetail.%GetTypeOf("violations") = "array") && (tDetail.%Get("violations").%Size() > 0) Set tCode = tDetail.%Get("violations").%Get(0).%Get("code")
    Quit $Get(tStatus) _ " " _ tCode _ " " _ tWhy
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

/// <p>Run <class>OcuPilot.Test.AuthOptionsGateProbe</class> as <var>pUser</var> over <var>pPlan</var> in a
/// child process and answer what it signalled, or an object carrying <code>error</code>.</p>
Method RunAs(pUser As %String, pPlan As %DynamicArray) As %DynamicObject
{
    Set tOut = {}
    Try {
        Do $System.Event.Clear($Job)
        Set tPlan = pPlan.%ToJSON()
        Job ##class(OcuPilot.Test.AuthOptionsGateProbe).Run($Job, pUser, tPlan)::10
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
