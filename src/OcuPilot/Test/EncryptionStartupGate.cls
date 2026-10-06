/// <p>Pins Story 18.23's pairs with least-privileged principals (C9; AD-8, AD-29): a principal holding exactly
/// Security's two pairs reads the settings and the form over the wire, and saves a change and confirms the
/// agent's in process; without <code>%Admin_FileSystemAccess:USE</code> a Save naming a key file's location is
/// refused naming that pair; without <code>%Admin_Secure:USE</code> both reads, the Save and the confirm are
/// refused naming it and the screen is unavailable; and without <code>%DB_IRISSYS:READ</code> the Save is
/// refused naming it. Every refusal comes before any port call.</p>
/// <p>The in-process legs run in a child process logged in as the principal
/// (<class>OcuPilot.Test.EncryptionWriteGateProbe</class>), whose
/// <class>OcuPilot.Test.EncryptionSeamPort</class> is armed <code>startup</code>, so no setting changes.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates and deletes probe
/// users and roles (<class>OcuPilot.Test.EncryptionStartupProbe</class>) and sets the governance policy. It
/// creates no key file. Every probe object is removed, and after each test the instance's encryption state
/// and the audit database's identity read as that test found them.</p>
Class OcuPilot.Test.EncryptionStartupGate Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the principals, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.EncryptionStartupProbe";

Parameter SCREEN = "security.encryptionstartup";

Parameter SEAMTOOL = "OcuPilot.Test.SeamEncryptionStartupUpdate";

Parameter GATE = "OcuPilot.Test.EncryptionWriteGate";

/// <p>The principals, each <code>user:role:pairs</code> beyond the install namespace's code read: the holder
/// holds Security's two pairs; the outsider the file-system pair and the system database's read, without
/// Security's resource; the reader-less one Security's resource alone.</p>
Parameter PRINCIPALS = "OCUPROBESTARTGHOLDER:OCUPROBESTARTGHOLDERROLE:%Admin_Secure:U;%DB_IRISSYS:R,OCUPROBESTARTGOUTSIDER:OCUPROBESTARTGOUTSIDERROLE:%Admin_FileSystemAccess:U;%DB_IRISSYS:R,OCUPROBESTARTGNOREAD:OCUPROBESTARTGNOREADROLE:%Admin_Secure:U";

Parameter GOVERNANCEKEY = "security.encryptionstartup.update";

/// <p>The throwaway principals' password, generated for the run.</p>
Property PreparedPassword As %String;

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

/// <p>The encryption facts and the audit database's identity before each test.</p>
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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.EncryptionStartupGate creates and deletes users and roles on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuProbeStartGate" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll", .tRemaining)
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = ##class(OcuPilot.Test.EncryptionStartupWrite).Facts()
    Do ##class(OcuPilot.Test.EncryptionSeamPort).Clear()
    Do ##class(OcuPilot.Test.EncryptionSeamPort).Arm("startup")
    Kill tSettings
    Set tSettings(..#GOVERNANCEKEY) = "enabled"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Length(..#PRINCIPALS, ",") {
        Set tEntry = $Piece(..#PRINCIPALS, ",", tI)
        Set tSC = $ClassMethod(..#PROBE, "SeedPrincipal", $Piece(tEntry, ":", 1), $Piece(tEntry, ":", 2), $Translate($Piece(tEntry, ":", 3, 99), ";", ","), ..PreparedPassword)
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Test.EncryptionSeamPort).Clear()
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll", .tRemaining), "every probe principal is removed")
    Set tFacts = ##class(OcuPilot.Test.EncryptionStartupWrite).Facts()
    Do $$$AssertTrue((tFacts '[ """error"":") && (..PreparedFacts '[ """error"":"), "the facts were read whole before and after the test")
    Do $$$AssertEquals(tFacts, ..PreparedFacts, "no encryption setting moved and the audit database is the one the test found")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll", .tRemaining))
}

/// <p>The holder reads the settings and the form over the wire, and in process confirms the agent's change
/// and saves one back; each write reaches the seam with one <code>PUT</code>.</p>
Method TestTheDeclaredPairsReadAndWrite()
{
    Set tUser = ..User(1)
    Do $$$AssertEquals(..WireRead("/screens/" _ ..#SCREEN _ "/read?maxRows=1", tUser), "200 ", "the settings read answers the holder")
    Do $$$AssertEquals(..WireRead("/encryption-startup/form", tUser), "200 ", "and the form read")
    Do $$$AssertEquals(..WireSave({"DBEncStartMode": (..StoredMode()), "Extra": "x"}, tUser, 400), "400 PORT.FIELD.UNEXPECTED Extra", "over the wire, a Save carrying a key outside the form's is refused before any port call")
    Set tSC = $ClassMethod(..#PROBE, "KeyMint", ..#SEAMTOOL, "", {"DBEncStartMode": "Interactive"}, .tProposal, .tHttp, .tProblem, tUser)
    Do $$$AssertStatusOK(tSC, "the agent's change is minted for the holder (" _ tProblem _ ")")
    Set tPlan = []
    Do tPlan.%Push({"kind": "arm", "mode": "startup"})
    Do tPlan.%Push({"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))})
    Do tPlan.%Push({"kind": "startupsave", "body": {"DBEncStartMode": (..StoredMode())}})
    Set tRun = $ClassMethod(..#GATE, "RunAs", tUser, tPlan)
    Do $$$AssertEquals($ClassMethod(..#GATE, "Ran", tRun), tUser _ " 1", "the child process ran as " _ tUser)
    For tI = 2, 3 {
        Set tLeg = $ClassMethod(..#GATE, "Leg", tRun, tI)
        Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http") _ " " _ ($Length(tLeg.%Get("writes"), "Security.Encryption.Settings/PUT") - 1), 1: ""), "200 1", "leg " _ tI _ " writes one PUT (" _ $ClassMethod(..#GATE, "LegText", tRun, tI) _ ")")
    }
}

/// <p>Without <code>%Admin_FileSystemAccess:USE</code>, a Save naming a key file's location is refused naming
/// the pair before any port call, while one naming none is not.</p>
/// <p>Mutation (Rule 19): drop the Save's argument pair check in
/// <method>OcuPilot.Area.Security.EncryptionStartupSave.HandleUpdate</method> -- the leg reaches the port and
/// goes red.</p>
Method TestWithoutTheFileSystemPairALocationIsRefused()
{
    Set tUser = ..User(1)
    Set tPlan = []
    Do tPlan.%Push({"kind": "arm", "mode": "startup"})
    Do tPlan.%Push({"kind": "startupsave", "body": {"DBEncStartMode": "Unattended", "root": ($ClassMethod(..#PROBE, "Root")), "path": ($ClassMethod(..#PROBE, "RelativeName", "gate.key")), "AdminName": ($Parameter(..#PROBE, "ADMIN")), "AdminPassword": ($ClassMethod(..#PROBE, "NewPassword"))}})
    Set tRun = $ClassMethod(..#GATE, "RunAs", tUser, tPlan)
    Do $$$AssertEquals($ClassMethod(..#GATE, "Ran", tRun), tUser _ " 1", "the child process ran as " _ tUser)
    Do $$$AssertEquals($ClassMethod(..#GATE, "LegText", tRun, 2), "403 AUTH.NOPRIVILEGE %Admin_FileSystemAccess:USE calls=0 writes=", "the location is refused naming the file-system pair before any port call")
}

/// <p>Without <code>%Admin_Secure:USE</code>, both reads over the wire, and in process the Save and the
/// confirm, are refused naming the pair with zero port calls, and the screen is unavailable.</p>
/// <p>Mutation (Rule 19): let <method>OcuPilot.Area.Security.EncryptionStartupSave.Gate</method> pass every
/// caller -- the Save legs reach the port and go red.</p>
Method TestWithoutSecuritysResourceEveryReadAndWriteIsRefused()
{
    Set tUser = ..User(2)
    Do $$$AssertEquals(..WireRead("/screens/" _ ..#SCREEN _ "/read?maxRows=1", tUser), "403 %Admin_Secure:USE", "the settings read is refused naming the pair")
    Do $$$AssertEquals(..WireRead("/encryption-startup/form", tUser), "403 %Admin_Secure:USE", "and the form read")
    Do $$$AssertEquals(..WireSave({"DBEncStartMode": (..StoredMode())}, tUser, 403), "403 AUTH.NOPRIVILEGE %Admin_Secure:USE", "and the Save over the wire")
    Set tSC = $ClassMethod(..#PROBE, "KeyMint", ..#SEAMTOOL, "", {"DBEncStartMode": "Interactive"}, .tProposal, .tHttp, .tProblem, tUser)
    Do $$$AssertStatusOK(tSC, "a change is minted for the outsider (" _ tProblem _ ")")
    Set tPlan = []
    Do tPlan.%Push({"kind": "arm", "mode": "startup"})
    Do tPlan.%Push({"kind": "startupsave", "body": {"DBEncStartMode": "Interactive"}})
    Do tPlan.%Push({"kind": "confirm", "proposalId": ($Select($IsObject(tProposal): tProposal.%Get("proposalId"), 1: ""))})
    Do tPlan.%Push({"kind": "entry", "descriptor": "OcuPilot.Screen.Descriptor.EncryptionStartup"})
    Set tRun = $ClassMethod(..#GATE, "RunAs", tUser, tPlan)
    Do $$$AssertEquals($ClassMethod(..#GATE, "Ran", tRun), tUser _ " 1", "the child process ran as " _ tUser)
    For tI = 2, 3 {
        Do $$$AssertEquals($ClassMethod(..#GATE, "LegText", tRun, tI), "403 AUTH.NOPRIVILEGE %Admin_Secure:USE calls=0 writes=", "leg " _ tI _ " is refused naming Security's resource before any port call")
    }
    Set tLeg = $ClassMethod(..#GATE, "Leg", tRun, 4)
    Do $$$AssertEquals($Select($IsObject(tLeg): tLeg.%Get("http") _ " " _ tLeg.%Get("failedPair"), 1: ""), "403 %Admin_Secure:USE", "the screen is unavailable, naming the pair")
}

/// <p>Without <code>%DB_IRISSYS:READ</code>, the Save is refused naming it before any port call.</p>
Method TestWithoutTheSystemDatabaseReadTheSaveIsRefused()
{
    Set tUser = ..User(3)
    Set tPlan = []
    Do tPlan.%Push({"kind": "arm", "mode": "startup"})
    Do tPlan.%Push({"kind": "startupsave", "body": {"DBEncStartMode": "Interactive"}})
    Set tRun = $ClassMethod(..#GATE, "RunAs", tUser, tPlan)
    Do $$$AssertEquals($ClassMethod(..#GATE, "Ran", tRun), tUser _ " 1", "the child process ran as " _ tUser)
    Do $$$AssertEquals($ClassMethod(..#GATE, "LegText", tRun, 2), "403 AUTH.NOPRIVILEGE %DB_IRISSYS:READ calls=0 writes=", "the Save is refused naming the system database's read before any port call")
}

/// <p>A Save of <var>pBody</var> over the wire as <var>pUser</var>, which must answer <var>pStatus</var> as
/// JSON, answered as <code>status code failedPair</code>, or <code>status code field</code> for a
/// violation. The real port answers this process, so a caller sends only the start mode the instance
/// holds: a Save that got past a refusal would change nothing.</p>
Method WireSave(pBody As %DynamicObject, pUser As %String, pStatus As %Integer) As %String
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("PUT", tBase _ "/encryption-startup", pUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders, pBody.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, pStatus, "PUT /encryption-startup answers " _ pStatus _ ": " _ $Extract($Get(tBody), 1, 200))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Set tAnswer = ##class(%DynamicObject).%FromJSON($Get(tBody, "{}"))
    Set tDetail = tAnswer.%Get("detail")
    Set tWhy = $Select('$IsObject(tDetail): "", tDetail.%Get("failedPair") '= "": tDetail.%Get("failedPair"), (tDetail.%GetTypeOf("violations") = "array") && (tDetail.%Get("violations").%Size() > 0): tDetail.%Get("violations").%Get(0).%Get("field"), 1: "")
    Set tCode = tAnswer.%Get("code")
    If (tCode = "") && $IsObject(tDetail) && (tDetail.%GetTypeOf("violations") = "array") && (tDetail.%Get("violations").%Size() > 0) Set tCode = tDetail.%Get("violations").%Get(0).%Get("code")
    Quit $Get(tStatus) _ " " _ tCode _ " " _ tWhy
}

/// <p>The start mode the instance holds, which the holder's Save puts back after the confirm moved the
/// seam's copy to <code>Interactive</code>.</p>
ClassMethod StoredMode() As %String
{
    Kill tQuery
    Set tSC = ##class(OcuPilot.Port.EncryptionPort).Invoke("Security.Encryption.Settings", "GET", .tQuery, "", .tFresh, .tHttp, .tFault)
    Quit $Select($$$ISOK(tSC) && $IsObject($Get(tFresh)): tFresh.%Get("DBEncStartMode"), 1: "")
}

/// <p>The principal of entry <var>pIndex</var> of <parameter>PRINCIPALS</parameter>.</p>
ClassMethod User(pIndex As %Integer) As %String
{
    Quit $Piece($Piece(..#PRINCIPALS, ",", pIndex), ":", 1)
}

/// <p>A read of <var>pPath</var> under the API over the wire as <var>pUser</var>, answered as
/// <code>status failedPair</code>.</p>
Method WireRead(pPath As %String, pUser As %String) As %String
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ pPath, pUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders)
    Quit $Get(tStatus) _ " " _ $ClassMethod(..#GATE, "FailedPair", $Get(tBody))
}

}
