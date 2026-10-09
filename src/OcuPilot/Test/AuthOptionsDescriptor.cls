/// <p>Pins Story 18.8's declarations (A1, A4, A5, A6): the authentication options descriptor, its two tools'
/// kinds, pairs and declared secret, the entity type's singleton rule, the reviewed classification
/// (<code>SMTPPassword</code> secret, <code>AutheLoginToken</code> not masked), the two baseline keys shipped
/// enabled, <class>OcuPilot.Api.WebAuthError</class>'s codes and sentences, the two kernel refusals and their
/// sentences, the merge's treatment of <code>AutheKB</code>, the sign-out consequence, the sign-in
/// predicate over the flags and masks a write leaves, and the audit mask over the vendor's SMTP password
/// row.</p>
/// <p><b>Reads only.</b> Every leg is a pure question to a class or reads the instance's own settings; the
/// mask legs run through <class>OcuPilot.Test.AuthOptionsSeamPort</class>, which sends nothing.</p>
Class OcuPilot.Test.AuthOptionsDescriptor Extends %UnitTest.TestCase
{

Parameter SCREEN = "OcuPilot.Screen.Descriptor.AuthOptions";

Parameter TOOL = "OcuPilot.Screen.Tool.AuthOptionsUpdate";

Parameter PASSWORDTOOL = "OcuPilot.Screen.Tool.AuthOptionsSmtpPassword";

Parameter SEAM = "OcuPilot.Test.AuthOptionsSeamPort";

Parameter ERRORS = "OcuPilot.Api.WebAuthError";

Parameter PROHIBITED = "OcuPilot.Kernel.Proposal.Prohibited";

/// <p>The twenty-one settings, in the vendor template's order.</p>
Parameter FIELDS = "AutheUnauthenticated,AutheOS,AutheOSDelegated,AutheOSLDAP,AutheCache,AutheDelegated,AutheAlwaysTryDelegated,AutheKB,AutheLDAP,AutheLDAPCache,AutheOAuth2,AutheLoginToken,AutheTwoFactorSMS,AutheTwoFactorPW,LoginCookieTimeout,SMTPServer,SMTPUsername,TwoFactorFrom,TwoFactorTimeout,JWTIssuer,JWTSigAlg";

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#SEAM, "Clear")
    Quit $$$OK
}

/// <p>A1, A6: the screen is Security's eleventh listed <code>form-page</code> over the settings read, with
/// Security's two pairs and no own pair, the SMTP password the one declared secret, three prompts, no refresh
/// and the classic Authentication page; its read and its context carry the twenty-one settings and never the
/// password.</p>
/// <p>Mutation (Rule 19): add <code>SMTPPassword</code> to the descriptor's read fields -- the secret leg goes
/// red.</p>
Method TestTheScreenIsDeclaredAsTheSpecPlacesIt()
{
    Set tClass = ..#SCREEN
    Do $$$AssertEquals($ClassMethod(tClass, "Route"), "security/authentication", "the route")
    Do $$$AssertEquals($ClassMethod(tClass, "AreaKey") _ " " _ $ClassMethod(tClass, "SideBarPosition"), "security 11", "Security's eleventh listed screen")
    Do $$$AssertEquals($ClassMethod(tClass, "Archetype"), "form-page", "a form page")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "classicPage"), "%CSP.UI.Portal.Authentication", "the classic page")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "toolIdentifier"), "security.authoptions", "the tool identifier")
    Do $$$AssertEquals($ClassMethod(tClass, "PrimaryEntityType") _ " " _ $ClassMethod(tClass, "Scope"), "authentication-options instance", "the singleton entity")
    Do $$$AssertEquals($ClassMethod(tClass, "Field", "id").%Get("kind"), "single", "one id")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tClass, "PrivilegePairs")), "%Admin_Secure:USE,%DB_IRISSYS:READ", "Security's two pairs")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tClass, "OwnPrivilegePairs")), "", "and no own pair")
    Do $$$AssertEquals($ListToString($ClassMethod(tClass, "SecretArguments")), "SMTPPassword", "the SMTP password is the declared secret")
    Set tPrompts = $ClassMethod(tClass, "Field", "suggestedPrompts")
    Do $$$AssertEquals(tPrompts.%Size(), 3, "three prompts")
    Do $$$AssertEquals(+$ClassMethod(tClass, "Field", "refreshes"), 0, "no auto-refresh")
    Set tRead = $ClassMethod(tClass, "Read")
    Do $$$AssertEquals(tRead.%Get("source").%Get("port") _ " " _ tRead.%Get("source").%Get("endpoint") _ " " _ tRead.%Get("source").%Get("type"), "admin Security.WebAuth GET", "the options read")
    Set tReadFields = ##class(OcuPilot.Test.EncryptionKeyRead).Joined(tRead.%Get("fields"))
    Do $$$AssertEquals(tReadFields, ..#FIELDS, "the twenty-one settings")
    Set tContext = ##class(OcuPilot.Test.EncryptionKeyRead).Joined($ClassMethod(tClass, "Field", "context").%Get("fields"))
    Do $$$AssertEquals(tContext, ..#FIELDS, "the context carries the same twenty-one")
    Do $$$AssertTrue((tReadFields '[ "SMTPPassword") && (tContext '[ "SMTPPassword") && ($ClassMethod(tClass, "Field", "context").%Get("secretFields").%Size() = 0), "and neither names the password")
}

/// <p>A1, A2: the update is an advertised merge write on the admin port over Security's two pairs, its
/// settable fields the twenty-one and never the password; the password tool is a secret-only action write
/// whose one declared secret clears on an empty value, which the confirm channel is open to and its schema
/// never carries.</p>
/// <p>Mutation (Rule 19): drop <code>CLEARABLESECRETS</code> from the password tool -- the clear leg goes
/// red.</p>
Method TestTheToolsDeclareTheirKindPortPairsAndSecret()
{
    Set tTool = ..#TOOL
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("security.authoptions.update", .tEntry)
    Do $$$AssertTrue($IsObject($Get(tEntry)), "the update is registered")
    Do $$$AssertEquals($Parameter(tTool, "KIND") _ " " _ $ClassMethod(tTool, "Advertised"), "write 1", "an advertised write")
    Do $$$AssertEquals($ClassMethod(tTool, "PortClass") _ " " _ $ClassMethod(tTool, "ReadType") _ " " _ $ClassMethod(tTool, "WriteType") _ " " _ $ClassMethod(tTool, "SendsBody"), "OcuPilot.Port.AdminPort GET PUT 1", "a merge write through the admin port")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tTool, "PrivilegePairs", "", .tResolved)), "%Admin_Secure:USE,%DB_IRISSYS:READ", "Security's two pairs and no other")
    Do $$$AssertEquals($ListToString($ClassMethod(tTool, "SettableFields")), ..#FIELDS, "the twenty-one settable fields")
    Do $$$AssertEquals($ListToString($ClassMethod(tTool, "PermittedFields")), ..#FIELDS, "which it declares as its permitted fields")
    Do $$$AssertEquals($ListToString($ClassMethod(..#PROHIBITED, "PermittedChangeFields", "authentication-options")), ..#FIELDS, "the kernel's reviewed few are the same twenty-one")
    Set tProperties = $ClassMethod(tTool, "InputSchema").%Get("properties")
    Do $$$AssertEquals(tProperties.%IsDefined("SMTPPassword") _ tProperties.%IsDefined("AutheKB") _ tProperties.%IsDefined("JWTSigAlg"), "011", "its schema carries no password")
    Do $$$AssertEquals($ListToString($ClassMethod(tTool, "ChannelSecretNames", "", .tDeclared)), "", "and its confirm channel is open to nothing")

    Set tPassword = ..#PASSWORDTOOL
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve("security.authoptions.smtppassword", .tEntry)
    Do $$$AssertTrue($IsObject($Get(tEntry)), "the password tool is registered")
    Do $$$AssertEquals($Parameter(tPassword, "KIND") _ " " _ $ClassMethod(tPassword, "Advertised"), "write 1", "an advertised write")
    Do $$$AssertEquals($ClassMethod(tPassword, "WriteType") _ " " _ $ClassMethod(tPassword, "SendsBody") _ " " _ $Parameter(tPassword, "SECRETBODY") _ " " _ $Parameter(tPassword, "CLEARABLESECRETS"), "CHANGESMTPPWD 0 SMTPPassword SMTPPassword", "the vendor's own type, no merge body, one declared secret that clears")
    Do $$$AssertEquals($ListToString($ClassMethod(tPassword, "ChannelSecretNames", "", .tDeclared)), "SMTPPassword", "the confirm channel is open to the password alone")
    Do $$$AssertEquals($ListToString($ClassMethod(tPassword, "SettableFields")), "", "no settable field")
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionDescriptor).Pairs($ClassMethod(tPassword, "PrivilegePairs", "", .tResolved)), "%Admin_Secure:USE,%DB_IRISSYS:READ", "Security's two pairs")
    Set tProperties = $ClassMethod(tPassword, "InputSchema").%Get("properties")
    Do $$$AssertEquals(tProperties.%IsDefined("SMTPPassword"), 0, "its schema never carries the password")
}

/// <p>AD-3, Conventions &#8250; Secrets: the generated field list holds the twenty-one rows classified
/// ordinary for the update, and the password tool authors <code>SMTPPassword</code> secret; the credential
/// pattern masks the password's name and holds <code>AutheLoginToken</code>, a boolean flag, an
/// exception.</p>
/// <p>Mutation (Rule 19): drop <code>authelogintoken</code> from
/// <parameter>OcuPilot.Kernel.Audit.Log.CREDENTIALEXCEPTIONS</parameter> -- the exception leg goes red.</p>
Method TestTheClassificationIsReviewed()
{
    Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen("OcuPilot.Screen.Tool.ToolFields", "Tools")
    Do tXData.Data.Rewind()
    Set tTools = ##class(%DynamicObject).%FromJSON(tXData.Data)
    Set tRows = ..Rows(tTools.%Get("security.authoptions.update"))
    Do $$$AssertEquals(tRows, ..Classified(..#FIELDS, "ordinary"), "the update's rows are the twenty-one, each ordinary")
    Set tRows = ..Rows(tTools.%Get("security.authoptions.smtppassword"))
    Do $$$AssertEquals(tRows, ..Classified(..#FIELDS, "ordinary") _ ",SMTPPassword:secret", "the password tool's rows are the same and SMTPPassword, secret")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Audit.Log).IsCredentialName("SMTPPassword"), 1, "the credential pattern masks the password's name")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.Audit.Log).IsCredentialName("AutheLoginToken"), 0, "and not the Allow creation of Login Cookies flag")
}

/// <p>A6, AD-13: <code>authentication-options</code> is a known entity type and a singleton, and the kernel
/// covers it.</p>
Method TestTheEntityTypeIsASingletonTheKernelCovers()
{
    Do $$$AssertTrue(##class(OcuPilot.Kernel.EntityType).IsKnown("authentication-options"), "a known entity type")
    Do $$$AssertEquals(##class(OcuPilot.Kernel.EntityRef).NormalizedId("authentication-options", "anything") _ " " _ ##class(OcuPilot.Kernel.EntityRef).NormalizedId("authentication-options", ""), "SYSTEM SYSTEM", "every spelling of its id reads as the singleton")
    Do $$$AssertTrue($ListFind($ClassMethod(..#PROHIBITED, "CoveredTypes"), "authentication-options") > 0, "the prohibited set covers it")
}

/// <p>A6, AD-22: both keys are in the baseline and enabled.</p>
/// <p>Mutation (Rule 19): drop <code>security.authoptions.update</code> from the baseline -- this goes
/// red.</p>
Method TestBothBaselineKeysShipEnabled()
{
    For tKey = "security.authoptions.update", "security.authoptions.smtppassword" {
        Set tValue = ##class(OcuPilot.Kernel.Governance.Baseline).Seed(tKey, .tListed)
        Do $$$AssertEquals(tListed _ " " _ tValue, "1 1", tKey _ " is listed and enabled")
    }
}

/// <p>AD-39: every <code>WEBAUTH.*</code> code answers its one sentence through the class and through
/// <class>OcuPilot.Api.Error</class>'s two dispatches; each violation code names its field; the two kernel
/// refusals answer their parameters, name no caller and are the set's twenty-ninth and thirtieth codes; the
/// sign-out consequence is the class's.</p>
Method TestTheCodesAnswerTheirSentences()
{
    Set tClass = ..#ERRORS
    Set tCodes = $ClassMethod(tClass, "Codes")
    Do $$$AssertEquals($ListLength(tCodes), 10, "ten codes")
    For tI = 1:1:$ListLength(tCodes) {
        Set tCode = $List(tCodes, tI)
        Set tReason = $ClassMethod(tClass, "ReasonFor", tCode)
        Do $$$AssertNotEquals(tReason, "", tCode _ " carries a sentence")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForViolation(tCode), tReason, tCode _ " answers it through the violation dispatch")
        Do $$$AssertEquals(##class(OcuPilot.Api.Error).ReasonForToolCode(tCode), tReason, tCode _ " answers it through the tool dispatch")
    }
    Set tViolations = $ClassMethod(tClass, "ViolationCodes")
    Do $$$AssertEquals($ListLength(tViolations), 8, "eight of them are field codes")
    For tI = 1:1:$ListLength(tViolations) {
        Do $$$AssertNotEquals($ClassMethod(tClass, "FieldOf", $List(tViolations, tI)), "", $List(tViolations, tI) _ " names its field")
    }
    Do $$$AssertEquals($Parameter(..#PROHIBITED, "EFFECTTOKENSIGNOUT"), $Parameter(tClass, "SIGNOUT"), "the kernel's token effect is the class's sign-out code")
    Set tProhibited = ..#PROHIBITED
    For tCode = "PROHIBITED.OCUPILOTSIGNIN", "PROHIBITED.OCUPILOTSTART" {
        Set tReason = $ClassMethod(tProhibited, "ReasonFor", tCode)
        Do $$$AssertNotEquals(tReason, "", tCode _ " carries a sentence")
        Do $$$AssertTrue($ZConvert(tReason, "L") '[ "the agent", tCode _ " names no caller")
        Do $$$AssertTrue($ListFind($ClassMethod(tProhibited, "Codes"), tCode) > 0, tCode _ " is one of the set's codes")
    }
    Do $$$AssertEquals($ListLength($ClassMethod(tProhibited, "Codes")), 34, "thirty-four codes")
}

/// <p>A2, AD-4: the merge leaves an <code>AutheKB</code> the call does not change out of the payload, and
/// carries one it does; the payload otherwise holds the other twenty settings, the unchanged count their
/// number, and a violation of a rule over the payload is the problem.</p>
/// <p>Mutation (Rule 19): keep an unchanged <code>AutheKB</code> in
/// <method>OcuPilot.Screen.Tool.AuthOptionsUpdate.MergeRaw</method> -- the first leg goes red.</p>
Method TestTheMergeLeavesAnUnchangedKerberosOut()
{
    Set tTool = ..#TOOL
    Set tFresh = ..Fresh()
    Set tSettable = $ClassMethod(tTool, "SettableFields")
    Set tSC = $ClassMethod(tTool, "MergeUpdate", tFresh, {"Name": "SYSTEM", "LoginCookieTimeout": 30}, "Name", tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertStatusOK(tSC, "an ordinary change merges (" _ $Get(tProblem) _ ")")
    Do $$$AssertEquals(tPayload.%IsDefined("AutheKB") _ " " _ tPayload.%Get("LoginCookieTimeout") _ " " _ ##class(OcuPilot.Test.EncryptionStartupDescriptor).Fields(tDiff) _ " " _ tUnchanged, "0 30 LoginCookieTimeout 19", "its payload leaves AutheKB out and carries the change; nineteen unchanged")
    Set tSC = $ClassMethod(tTool, "MergeUpdate", tFresh, {"Name": "SYSTEM", "AutheKB": true, "LoginCookieTimeout": 30}, "Name", tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertEquals(tPayload.%IsDefined("AutheKB") _ " " _ ##class(OcuPilot.Test.EncryptionStartupDescriptor).Fields(tDiff), "0 LoginCookieTimeout", "AutheKB sent equal to the instance's is left out")
    Set tSC = $ClassMethod(tTool, "MergeUpdate", tFresh, {"Name": "SYSTEM", "AutheKB": false}, "Name", tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertEquals(tPayload.%IsDefined("AutheKB") _ " " _ tPayload.%Get("AutheKB") _ " " _ ##class(OcuPilot.Test.EncryptionStartupDescriptor).Fields(tDiff), "1 0 AutheKB", "a changed AutheKB is carried and is a row")
    Set tSC = $ClassMethod(tTool, "MergeUpdate", tFresh, {"Name": "SYSTEM", "AutheAlwaysTryDelegated": true}, "Name", tSettable, .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertTrue(tProblem [ "'AutheAlwaysTryDelegated': " _ $Parameter(..#ERRORS, "REASONDELEGATED"), "a change the rules refuse is the problem, with its sentence: " _ tProblem)
}

/// <p>A5, AD-10: a changed <code>JWTIssuer</code> or <code>JWTSigAlg</code> is the sign-out effect; no other
/// change, and none that leaves both as held, is.</p>
/// <p>Mutation (Rule 19): answer <code>""</code> for <code>JWTSigAlg</code> in
/// <method>OcuPilot.Kernel.Proposal.Prohibited.ChangesTokenFields</method> -- the algorithm leg goes red.</p>
Method TestAChangedTokenSettingIsTheSignOutEffect()
{
    Set tHeld = ..Fresh()
    Set tType = "authentication-options"
    For tCase = $ListBuild("{""JWTIssuer"":""probe""}", "WEBAUTH.SIGNOUT"), $ListBuild("{""JWTSigAlg"":""RS256""}", "WEBAUTH.SIGNOUT"), $ListBuild("{""JWTSigAlg"":""ES256"",""JWTIssuer"":""""}", ""), $ListBuild("{""LoginCookieTimeout"":30}", ""), $ListBuild("{""AutheLoginToken"":true}", "") {
        Set tPayload = ##class(%DynamicObject).%FromJSON($List(tCase, 1))
        Set tSC = $ClassMethod(..#PROHIBITED, "WeakensByEffect", tType, tPayload, tHeld, .tEffect)
        Do $$$AssertStatusOK(tSC, $List(tCase, 1) _ " is judged")
        Do $$$AssertEquals(tEffect, $List(tCase, 2), $List(tCase, 1) _ " has effect '" _ $List(tCase, 2) _ "'")
    }
}

/// <p>A4: the flags a write leaves, as the vendor's bits (<code>AutheKB</code> seven of them), and the sign-in
/// predicate over masks the seam answers: turning off the method an application holds alone is a cut, turning
/// off one it holds with another is not, a Login Cookie or two-factor bit beside it is no other method, a
/// method already off is not a cut, and a read that fails is, for the arm and for the form's locks.</p>
/// <p>Mutation (Rule 19): answer <code>0</code> from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.CutsOffSignIn</method> on a failed read -- the failed-read leg
/// goes red.</p>
Method TestTheSignInPredicateJudgesTheMasks()
{
    Set tP = ..#PROHIBITED
    Set tHeld = ..Fresh()
    Set tOld = $ClassMethod(tP, "AuthFlags", tHeld, "")
    Do $$$AssertEquals(tOld, 128 + 256 + 512 + 1 + 2 + 4 + 8 + 16 + 32 + 64, "the stock flags are Unauthenticated, O/S, Password and the seven Kerberos bits")
    Set tNewNoPassword = $ClassMethod(tP, "AuthFlags", tHeld, {"AutheCache": false})
    Do $$$AssertEquals(tOld - tNewNoPassword, 32, "turning Password off takes its one bit")
    Do $$$AssertEquals($ClassMethod(tP, "AuthFlags", tHeld, {"AutheKB": false}), tOld - 911, "and Kerberos its seven")
    Set tSeam = ..#SEAM
    Do $ClassMethod(tSeam, "ArmMask", "WebApp.App", "/ocupilot", 64)
    Do $ClassMethod(tSeam, "ArmMask", "WebApp.App", "/api/ocupilot", 32)
    Do $ClassMethod(tSeam, "ArmMask", "WebApp.App", "/api/ocupilot/readiness", 64)
    Do $ClassMethod(tSeam, "ArmMask", "Security.Service", "%Service_WebGateway", 32)
    Do $$$AssertTrue($ClassMethod(tP, "CutsOffSignIn", tSeam, tOld, tNewNoPassword), "Password off leaves the API and the gateway with no method")
    Set tNewNoUnauth = $ClassMethod(tP, "AuthFlags", tHeld, {"AutheUnauthenticated": false})
    Do $$$AssertTrue($ClassMethod(tP, "CutsOffSignIn", tSeam, tOld, tNewNoUnauth), "Unauthenticated off leaves the shell and readiness with no method")
    Set tNewNoOs = $ClassMethod(tP, "AuthFlags", tHeld, {"AutheOS": false})
    Do $$$AssertTrue('$ClassMethod(tP, "CutsOffSignIn", tSeam, tOld, tNewNoOs), "O/S off leaves every mask a method (its own refusal is the start arm's)")
    Do $ClassMethod(tSeam, "ArmMask", "WebApp.App", "/api/ocupilot", 32 + 8192)
    Do $ClassMethod(tSeam, "ArmMask", "Security.Service", "%Service_WebGateway", 32 + 8192)
    Set tWithDelegated = $ZBoolean(tOld, 8192, 7)
    Do $$$AssertTrue('$ClassMethod(tP, "CutsOffSignIn", tSeam, tWithDelegated, $ZBoolean(tWithDelegated, 32, 2)), "an application widened to password and delegated is not cut by Password off while Delegated stays on")
    Do $$$AssertTrue($ClassMethod(tP, "CutsOffSignIn", tSeam, tWithDelegated, $ZBoolean($ZBoolean(tWithDelegated, 32, 2), 8192, 2)), "and is cut when both go")
    Do $ClassMethod(tSeam, "ArmMask", "WebApp.App", "/api/ocupilot", 32 + 16384 + 2097152)
    Do $ClassMethod(tSeam, "ArmMask", "Security.Service", "%Service_WebGateway", 32 + 16384 + 2097152)
    Set tWithModifiers = $ZBoolean(tOld, 16384 + 2097152, 7)
    Do $$$AssertTrue($ClassMethod(tP, "CutsOffSignIn", tSeam, tWithModifiers, $ZBoolean(tWithModifiers, 32, 2)), "Login Cookie and two-factor are no method of their own: Password off still cuts an application holding them beside it")
    Do $$$AssertTrue('$ClassMethod(tP, "CutsOffSignIn", tSeam, tNewNoPassword, tNewNoPassword), "a method already off is not turned off again")
    For tEndpoint = "WebApp.App", "Security.Service" {
        Do $ClassMethod(tSeam, "Clear")
        Do $ClassMethod(tSeam, "ArmFail", tEndpoint)
        Do $$$AssertTrue($ClassMethod(tP, "CutsOffSignIn", tSeam, tOld, tOld), "a failed " _ tEndpoint _ " read refuses")
    }
    For tEndpoint = "Security.WebAuth", "WebApp.App" {
        Do $ClassMethod(tSeam, "Clear")
        Do $ClassMethod(tSeam, "ArmFail", tEndpoint)
        Set tSC = $ClassMethod(tP, "SignInLocks", tSeam, .tFields)
        Do $$$AssertTrue($$$ISERR(tSC) && (tFields.%Size() = 0), "the form's locks are an error naming no field when the " _ tEndpoint _ " read fails")
    }
}

/// <p>AD-35: the vendor's "Modify System" row carries the SMTP password a <code>CHANGESMTPPWD</code> writes in
/// clear on its <code>New value</code> line (measured on <code>ocupilot-ci</code>, 2026-10-07); the audit
/// read's mask answers it masked and keeps the row's other lines, and the same text under another vendor
/// event is unchanged.</p>
/// <p>Mutation (Rule 19): empty <parameter>OcuPilot.Port.AuditPort.VENDORSYSTEMSECRETS</parameter> -- the
/// masked leg goes red.</p>
Method TestTheVendorSystemChangeRowReadsTheSmtpPasswordMasked()
{
    Set tCrlf = $Char(13, 10)
    Set tData = "Modify System: SYSTEM" _ tCrlf _ tCrlf _ "SMTP Password modified:" _ tCrlf _ "  New value: ocupilotmaskprobe188*****" _ tCrlf _ "  Old value: *****" _ tCrlf _ tCrlf _ "Current values:" _ tCrlf _ "SMTP Server:                                   smtp.example.test" _ tCrlf _ "SMTP Password:                                 *****"
    Set tRows = []
    Do tRows.%Push(##class(OcuPilot.Test.AuditVendorSecrets).Row("%System", "%Security", "SystemChange", "Modify System SYSTEM", tData))
    Do tRows.%Push(##class(OcuPilot.Test.AuditVendorSecrets).Row("%System", "%Security", "UserChange", "Modify System SYSTEM", tData))
    Do ##class(OcuPilot.Port.AuditPort).MaskVendorSecrets(tRows)
    Set tMasked = tRows.%Get(0).%Get("EventData")
    Do $$$AssertTrue((tMasked '[ "ocupilotmaskprobe188") && (tMasked [ "  New value: *****") && (tMasked [ "smtp.example.test"), "the password reads masked and the row's other lines are kept: " _ tMasked)
    Do $$$AssertEquals(tRows.%Get(1).%Get("EventData"), tData, "the same text under another vendor event is unchanged")
}

/// <p>The twenty-one settings as the vendor's <code>GET</code> reads them on a stock instance: Unauthenticated,
/// Password, O/S and Kerberos on.</p>
ClassMethod Fresh() As %DynamicObject
{
    Quit {"AutheAlwaysTryDelegated": false, "AutheCache": true, "AutheDelegated": false, "AutheKB": true, "AutheLDAP": false, "AutheLDAPCache": false, "AutheLoginToken": false, "AutheOAuth2": false, "AutheOS": true, "AutheOSDelegated": false, "AutheOSLDAP": false, "AutheTwoFactorPW": false, "AutheTwoFactorSMS": false, "AutheUnauthenticated": true, "LoginCookieTimeout": 0, "SMTPServer": "", "SMTPUsername": "", "TwoFactorFrom": "", "TwoFactorTimeout": 180, "JWTIssuer": "", "JWTSigAlg": "ES256"}
}

/// <p>A tool's field rows as <code>path:class</code>, comma-joined in the entry's order.</p>
ClassMethod Rows(pEntry As %DynamicObject) As %String
{
    If '$IsObject(pEntry) Quit "(no entry)"
    Set tOut = ""
    Set tIterator = pEntry.%Get("fields").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ tRow.%Get("path") _ ":" _ tRow.%Get("class")
    }
    Quit tOut
}

/// <p><var>pFields</var>, comma-separated, each as <code>name:class</code>.</p>
ClassMethod Classified(pFields As %String, pClass As %String) As %String
{
    Set tOut = ""
    For tI = 1:1:$Length(pFields, ",") {
        Set tOut = tOut _ $Select(tOut = "": "", 1: ",") _ $Piece(pFields, ",", tI) _ ":" _ pClass
    }
    Quit tOut
}

}
