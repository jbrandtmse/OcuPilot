/// <p>Pins Story 18.26's reads: the screen's declared read and <code>security.mftconnections.read</code> answer the
/// same rows from one read; <code>GET /mft-connection/form</code> answers a connection's five fields and a new
/// connection's empty ones; a name the instance does not hold, or holds in another capitalization, is 404; and
/// <class>OcuPilot.Port.MftPort</class> composes the revoke's read and renders its script.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates probe connections
/// (<class>OcuPilot.Test.MftProbe</class>) and removes them by exact name before all, after each and after all.
/// After each test the connection list reads as that test found it.</p>
Class OcuPilot.Test.MftConnectionRead Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the writes, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter SCREEN = "security.mftconnections";

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.MftConnectionList";

Parameter PROBE = "OcuPilot.Test.MftProbe";

Parameter SEAM = "OcuPilot.Test.MftSeamPort";

Property PreparedFacts As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.MftConnectionRead creates probe connections on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $ClassMethod(..#PROBE, "RemoveAll")
}

Method OnBeforeOneTest() As %Status
{
    Set ..PreparedFacts = $ClassMethod(..#PROBE, "Facts")
    Do $ClassMethod(..#SEAM, "Clear")
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#SEAM, "Clear")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll"), "every probe object is removed by exact name")
    Do $$$AssertNotEquals(..PreparedFacts, "unreadable", "the connection list was read before the test")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts"), ..PreparedFacts, "the connection list reads as before the test")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#PROBE, "RemoveAll")
}

/// <p>C1: the screen and the tool answer the same rows, each carrying the three list fields, and a probe
/// connection that holds no token reads "Not Authorized".</p>
/// <p>Mutation (Rule 19): drop <code>IsAuthorized</code> from the descriptor's read fields -- the key set leg goes
/// red.</p>
Method TestTheScreenAndTheReadToolAnswerTheSameRows()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "OcuMftProbeA"), "a first probe connection")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "OcuMftProbeB", {"Service": "Dropbox"}), "and a second")
    Kill tCriteria
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, 100, .tRead, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the screen's read answers (" _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: "") _ ")")
    Set tRows = $Select($IsObject($Get(tRead)): tRead.%Get("rows"), 1: [])
    Set tSeen = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tRow), "IsAuthorized,Name,Service", "row " _ tIndex _ " carries the three list fields and nothing else")
        If tRow.%Get("Name") [ "OcuMftProbe" Set tSeen = tSeen _ $Select(tSeen = "": "", 1: ",") _ tRow.%Get("Name") _ ":" _ tRow.%Get("Service") _ ":" _ tRow.%Get("IsAuthorized")
    }
    Do $$$AssertEquals(tSeen, "OcuMftProbeA:Box:Not Authorized,OcuMftProbeB:Dropbox:Not Authorized", "both probes are listed, neither authorized")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(..#SCREEN _ ".read", .tTool)
    Do $$$AssertStatusOK(tSC, "security.mftconnections.read resolves")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {"maxRows": 100}, 100, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "and answers")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("rows").%ToJSON(), 1: ""), tRows.%ToJSON(), "the screen's rows")
}

/// <p>C1: over the wire the form read answers 200 as JSON for a probe connection: <code>Name</code> and its five
/// fields; a name in another capitalization, and a name the instance does not hold, are 404; a new connection's
/// form carries every field empty.</p>
/// <p>Mutation (Rule 19): lower-case the id in <method>OcuPilot.Area.Security.MftConnectionRules.HandleForm</method>
/// -- the exactness leg goes red.</p>
Method TestTheFormReadAnswersTheFiveFields()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "OcuMftProbeA", {"Username": "form@ocumftprobe.invalid"}), "a probe connection")
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/mft-connection/form?id=OcuMftProbeA", tUser, tPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "GET /mft-connection/form answers: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Set tForm = ##class(%DynamicObject).%FromJSON(tRaw)
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tForm), "row", "the form answers one member")
    Set tRow = tForm.%Get("row")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tRow), "ApplicationName,Name,SSLConfiguration,Service,URL,Username", "the row carries the name and the five fields")
    Do $$$AssertEquals(tRow.%Get("Name") _ "|" _ tRow.%Get("Service") _ "|" _ tRow.%Get("SSLConfiguration") _ "|" _ tRow.%Get("Username") _ "|" _ tRow.%Get("ApplicationName"), "OcuMftProbeA|Box|BFC_SSL|form@ocumftprobe.invalid|OcuMftProbeAApp", "as the instance stores them")
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/mft-connection/form?id=ocumftprobea", tUser, tPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 404, "the same name in another capitalization is 404: " _ $Extract(tRaw, 1, 200))
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/mft-connection/form?id=OcuMftProbeZ", tUser, tPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ ##class(%DynamicObject).%FromJSON(tRaw).%Get("code"), "404 PORT.NOTFOUND", "a name the instance does not hold is 404 PORT.NOTFOUND")
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/mft-connection/form", tUser, tPassword, .tStatus, .tRaw, .tHeaders)
    Set tNew = ##class(%DynamicObject).%FromJSON(tRaw).%Get("row")
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tNew) _ " " _ tNew.%Get("Name") _ tNew.%Get("Service") _ tNew.%Get("URL") _ tNew.%Get("SSLConfiguration") _ tNew.%Get("Username") _ tNew.%Get("ApplicationName"), "200 ApplicationName,Name,SSLConfiguration,Service,URL,Username ", "a new connection's form carries the same members, every one empty")
}

/// <p>AD-51, C4: the port's composed <code>STATE</code> read answers the connection's five fields with
/// <code>IsAuthorized</code> from its list row, refuses a connection that is not authorized 409
/// <code>MFT.TOKEN.NONE</code>, answers 404 for a name no row holds or holds in another capitalization, and
/// answers the connection as authorized when the seam reads its row so.</p>
/// <p>Mutation (Rule 19): stop <method>OcuPilot.Port.MftPort.State</method> refusing "Not Authorized" -- the refusal
/// leg goes red.</p>
Method TestTheStateReadComposesTheConnectionAndItsAuthorization()
{
    Set tSeam = ..#SEAM
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Seed", "OcuMftProbeA"), "a probe connection")
    Kill tQuery
    Set tQuery("connection") = "OcuMftProbeA"
    Set tSC = $ClassMethod(tSeam, "Invoke", "Security.MFT", "STATE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "409 MFT.TOKEN.NONE", "a connection that is not authorized is refused")
    Do $$$AssertStatusNotOK(tSC, "as an error status")
    Do $$$AssertEquals($ClassMethod(tSeam, "Calls"), "Security.MFT/GET,Security.MFT/LIST", "after one GET and one LIST")
    Do $ClassMethod(tSeam, "ArmAuthorized", "OcuMftProbeA")
    Kill tQuery
    Set tQuery("connection") = "OcuMftProbeA"
    Set tSC = $ClassMethod(tSeam, "Invoke", "Security.MFT", "STATE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "an authorized connection is read")
    Do $$$AssertEquals(tHttp _ " " _ ##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tResult), "200 ApplicationName,IsAuthorized,SSLConfiguration,Service,URL,Username", "carrying the five fields and IsAuthorized")
    Do $$$AssertEquals(tResult.%Get("IsAuthorized") _ "|" _ tResult.%Get("ApplicationName"), "Authorized|OcuMftProbeAApp", "authorized, naming its client configuration")
    For tName = "OcuMftProbeZ", "ocumftprobea" {
        Kill tQuery
        Set tQuery("connection") = tName
        Set tSC = $ClassMethod(tSeam, "Invoke", "Security.MFT", "STATE", .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "404 PORT.NOTFOUND", tName _ " names no connection")
    }
}

/// <p>AD-59: the copy-out script of a delete is the vendor call and a comment naming the re-read that follows an
/// error; a revoke's and a <code>PUT</code>'s are the one vendor call.</p>
/// <p>Mutation (Rule 19): drop the comment step from <method>OcuPilot.Port.MftPort.Snippet</method> -- the delete leg
/// goes red.</p>
Method TestTheScriptRendersTheCallsAndTheReRead()
{
    Set tPort = "OcuPilot.Port.MftPort"
    Kill tQuery
    Set tQuery("connection") = "OcuMftProbeA"
    Set tSteps = $ClassMethod(tPort, "Snippet", "Security.MFT", "DELETE", .tQuery, "", "")
    Do $$$AssertEquals(tSteps.%Size() _ " " _ tSteps.%Get(0).%Get("kind") _ " " _ tSteps.%Get(1).%Get("kind"), "2 rest comment", "a delete is a vendor call and a comment")
    Do $$$AssertTrue(tSteps.%Get(0).%Get("text") [ "-X DELETE '/api/admin/v2/security/mft/connection?connection=OcuMftProbeA'", "the call: " _ tSteps.%Get(0).%Get("text"))
    Do $$$AssertEquals(tSteps.%Get(1).%Get("text"), $Parameter(tPort, "DELETENOTE"), "and the comment is the port's note")
    Set tSteps = $ClassMethod(tPort, "Snippet", "Security.MFT", "REVOKE", .tQuery, "", "")
    Do $$$AssertEquals(tSteps.%Size(), 1, "a revoke is one step")
    Do $$$AssertTrue(tSteps.%Get(0).%Get("text") [ "-X DELETE '/api/admin/v2/security/mft/connection/token?connection=OcuMftProbeA'", "the token route: " _ tSteps.%Get(0).%Get("text"))
    Set tSteps = $ClassMethod(tPort, "Snippet", "Security.MFT", "PUT", .tQuery, {"URL": "https://x.invalid/"}, "")
    Do $$$AssertEquals(tSteps.%Size(), 1, "a PUT is one step")
    Do $$$AssertTrue(tSteps.%Get(0).%Get("text") [ """URL"":""https://x.invalid/""", "carrying the body")
}

}
