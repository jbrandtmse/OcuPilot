/// <p>Pins Story 18.8's reads (A1, A4): the screen's declared read and <code>security.authoptions.read</code>
/// answer the same one row of the twenty-one settings the write's fresh read holds, and neither, nor the form
/// read, carries the SMTP password; <code>GET /authentication-options/form</code> answers the flags whose
/// turning off OcuPilot refuses and the signature algorithms the instance offers.</p>
/// <p><b>Reads only.</b> It needs a stock instance: Unauthenticated and Password on, which OcuPilot's own
/// applications and the web gateway rely on. Nothing is changed.</p>
Class OcuPilot.Test.AuthOptionsRead Extends %UnitTest.TestCase
{

Parameter SCREEN = "security.authoptions";

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.AuthOptions";

Parameter FIELDS = "AutheUnauthenticated,AutheOS,AutheOSDelegated,AutheOSLDAP,AutheCache,AutheDelegated,AutheAlwaysTryDelegated,AutheKB,AutheLDAP,AutheLDAPCache,AutheOAuth2,AutheLoginToken,AutheTwoFactorSMS,AutheTwoFactorPW,LoginCookieTimeout,SMTPServer,SMTPUsername,TwoFactorFrom,TwoFactorTimeout,JWTIssuer,JWTSigAlg";

/// <p>A1: the screen and the tool answer one row of the twenty-one settings, equal to the write's fresh
/// read, with no <code>SMTPPassword</code>.</p>
/// <p>Mutation (Rule 19): the descriptor's read declares <code>SMTPPassword</code> -- the key set leg goes
/// red.</p>
Method TestTheScreenAndTheReadToolAnswerTheSameTwentyOneSettings()
{
    Kill tCriteria
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, 1, .tRead, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the screen's read answers (" _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: "") _ ")")
    Set tRows = $Select($IsObject($Get(tRead)): tRead.%Get("rows"), 1: [])
    Do $$$AssertEquals(tRows.%Size(), 1, "one row")
    Set tRow = tRows.%Get(0)
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tRow), ..Sorted(..#FIELDS), "of the twenty-one settings and nothing else")
    Do $$$AssertEquals(tRow.%IsDefined("SMTPPassword"), 0, "never the SMTP password")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("security.authoptions.read", .tTool)
    Do $$$AssertTrue($IsObject($Get(tTool)), "security.authoptions.read is registered")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {}, 10, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "security.authoptions.read answers")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%Get("rows").%ToJSON(), 1: ""), tRows.%ToJSON(), "the screen's row")
    Kill tQuery
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.WebAuth", "GET", .tQuery, "", .tFresh, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the write's fresh read answers")
    For tI = 1:1:$Length(..#FIELDS, ",") {
        Set tField = $Piece(..#FIELDS, ",", tI)
        Do $$$AssertEquals(##class(OcuPilot.Kernel.Proposal.Mint).Display(tFresh.%Get(tField), tFresh.%GetTypeOf(tField)), ##class(OcuPilot.Kernel.Proposal.Mint).Display(tRow.%Get(tField), tRow.%GetTypeOf(tField)), tField _ " reads the same on the screen and at the write")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tFresh), ..Sorted(..#FIELDS), "and the fresh read carries the twenty-one settings alone")
    Set tJson = tRows.%ToJSON()
    Do $$$AssertTrue(tJson '[ "SMTPPassword", "no answer names the password")
}

/// <p>A4: over the wire the screen's read and the form read answer 200 as JSON; on a stock instance the form
/// locks Unauthenticated and Password, each with the sign-in refusal's sentence, and offers the six signature
/// algorithms; no answer carries a password.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Proposal.Prohibited.SignInLocks</method> answer no
/// field -- the locked leg goes red.</p>
Method TestTheFormLocksTheMethodsOcuPilotSignsInThrough()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/screens/security.authoptions/read?maxRows=1", tUser, tPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "the screen's read answers over the wire: " _ $Extract(tRaw, 1, 200))
    Do $$$AssertTrue(tRaw '[ "SMTPPassword", "carrying no password")
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/authentication-options/form", tUser, tPassword, .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "GET /authentication-options/form answers: " _ $Extract(tRaw, 1, 300))
    Do $$$AssertTrue($ZConvert($Get(tHeaders("CONTENT-TYPE")), "L") [ "application/json", "as JSON")
    Set tForm = ##class(%DynamicObject).%FromJSON(tRaw)
    Set tFields = ""
    Set tIterator = tForm.%Get("locked").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tLock) {
        Set tFields = tFields _ $Select(tFields = "": "", 1: ",") _ tLock.%Get("field")
        Do $$$AssertEquals(tLock.%Get("code") _ "|" _ tLock.%Get("reason"), "PROHIBITED.OCUPILOTSIGNIN|" _ $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "OCUPILOTSIGNINREASON"), tLock.%Get("field") _ " carries the sign-in refusal and its sentence")
    }
    Do $$$AssertEquals(tFields, "AutheUnauthenticated,AutheCache", "a stock instance locks Unauthenticated and Password")
    Do $$$AssertEquals(tForm.%Get("sigAlgs").%ToJSON(), "[""RS256"",""RS384"",""RS512"",""ES256"",""ES384"",""ES512""]", "and offers the six signature algorithms")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionStartupDescriptor).Keys(tForm), "locked,sigAlgs", "and the form answers nothing else")
}

/// <p><var>pFields</var>, comma-separated, sorted.</p>
ClassMethod Sorted(pFields As %String) As %String
{
    For tI = 1:1:$Length(pFields, ",") {
        Set tNames($Piece(pFields, ",", tI)) = ""
    }
    Set tOut = ""
    Set tName = ""
    For {
        Set tName = $Order(tNames(tName))
        If tName = "" Quit
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tName
    }
    Quit tOut
}

}
