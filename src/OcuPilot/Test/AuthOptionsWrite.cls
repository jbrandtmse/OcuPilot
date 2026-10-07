/// <p>Pins Story 18.8's write on both callers of <class>OcuPilot.Screen.Tool.AuthOptionsUpdate</class> (A2,
/// A3; AD-4, AD-53, AD-55, AD-56): the form's Save (<class>OcuPilot.Test.AuthOptionsSaveFixture</class>) and
/// the agent's mint and confirm (<class>OcuPilot.Test.DatabaseConfirm</class>) -- the ordinary change, the
/// Kerberos flag, each rule, the SMTP password's write and clear, and the moved and busy target.</p>
/// <p>The vendor's writes are real only for the settings a test can restore exactly, the login cookie and
/// two-factor timeouts and the SMTP password. Every sign-in, start or token change goes to the seam, which records it and
/// never sends it: the seam's guard refuses one sent any other way, and <code>answer</code> mode records
/// every settings <code>PUT</code> without the vendor.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, a stock authentication
/// state, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class changes the
/// instance's authentication options. Each test reads the state it starts from, writes only what it can
/// restore, and puts every value back by <class>OcuPilot.Test.AuthOptionsProbe</class>; after each test the
/// facts read as before it, the governance policy is restored and every proposal row is removed.</p>
Class OcuPilot.Test.AuthOptionsWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the authentication writes, set by
/// <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_SERVICE_CONFIG";

Parameter PROBE = "OcuPilot.Test.AuthOptionsProbe";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter SEAM = "OcuPilot.Test.AuthOptionsSeamPort";

Parameter SAVE = "OcuPilot.Test.AuthOptionsSaveFixture";

Parameter TOOL = "OcuPilot.Screen.Tool.AuthOptionsUpdate";

Parameter PASSWORDTOOL = "OcuPilot.Screen.Tool.AuthOptionsSmtpPassword";

Parameter PUT = "Security.WebAuth/PUT";

Parameter PASSWORDPUT = "Security.WebAuth/CHANGESMTPPWD";

/// <p>The governance policy as it stood before the class ran, restored after each test.</p>
Property PreparedPolicy [ MultiDimensional ];

/// <p>The authentication facts before each test, which the test must leave as found.</p>
Property PreparedFacts As %String(MAXLEN = "") [ InitialExpression = "" ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AuthOptionsWrite changes this instance's authentication options, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " must read 1 here, so nothing was changed. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $$$OK
}

/// <p>Every test records through the seam, unarmed, with the agent's two keys enabled over the
/// snapshot.</p>
Method OnBeforeOneTest() As %Status
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "EnsureKeys"), "the instance holds its signing keys before the snapshot")
    Set ..PreparedFacts = $ClassMethod(..#PROBE, "Facts").%ToJSON()
    Do $ClassMethod(..#SEAM, "Clear")
    Set ^||OcuPilotDatabaseWritePort = ..#SEAM
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("OcuPilot.Test.AuthOptionsSet")
    Kill tSettings
    Set tSettings("security.authoptions.update") = "enabled"
    Set tSettings("security.authoptions.smtppassword") = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Do $ClassMethod(..#SEAM, "Clear")
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("")
    Set tPrepared = ##class(%DynamicObject).%FromJSON(..PreparedFacts)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Restore", tPrepared), "the authentication options are restored")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts").%ToJSON(), ..PreparedFacts, "and read as before the test")
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Merge tRows = ..PreparedPolicy
    Quit ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
}

/// <p>A2: a change on both callers sends one <code>PUT</code> of the settings read fresh with the change
/// applied, less an unchanged <code>AutheKB</code> -- twenty keys, no query -- the agent's with one diff row;
/// each read-back matches, the instance stores the change, the raw <code>AutheEnabled</code> is not moved by a
/// single bit, no consequence is stated, and a Save that changes nothing sends nothing.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.AuthOptionsUpdate.MergeRaw</method> keeps an unchanged
/// <code>AutheKB</code> -- the body's shape grows to twenty-one and the raw bits move, and this goes
/// red.</p>
Method TestAnOrdinaryChangeIsOnePutLessAnUnchangedKerberosOnBothCallers()
{
    Set tBefore = $ClassMethod(..#PROBE, "Facts")
    Set tSaved = ..FullBody({"LoginCookieTimeout": 30})
    Set tSC = $ClassMethod(..#SAVE, "Handle", tSaved, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the form's Save of the complete set answers 200: " _ $Extract(tAnswer, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), ..#PUT, "sending one PUT")
    Set tSent = ##class(OcuPilot.Test.LicenseKey).Parsed($ClassMethod(..#SEAM, "BodyOf", ..#PUT))
    Do $$$AssertEquals($ListLength($ListFromString(##class(OcuPilot.Test.LicenseKey).Keys(tSent))) _ " " _ tSent.%IsDefined("AutheKB") _ " " _ tSent.%Get("LoginCookieTimeout"), "20 0 30", "of twenty keys, no AutheKB, the change applied")
    Set tParsed = ##class(OcuPilot.Test.LicenseKey).Parsed(tAnswer)
    Do $$$AssertEquals(..Verdict(tParsed) _ "|" _ tParsed.%GetTypeOf("consequence"), "matches|unassigned", "its read-back matches, and it states no consequence")
    Set tAfter = $ClassMethod(..#PROBE, "Facts")
    Do $$$AssertEquals(tAfter.%Get("LoginCookieTimeout") _ " " _ tAfter.%Get("raw") _ " " _ tAfter.%Get("privateKeys"), "30 " _ tBefore.%Get("raw") _ " " _ tBefore.%Get("privateKeys"), "the instance stores the change, no Kerberos bit moved and the key sets are kept")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#SAVE, "Handle", ..FullBody({"LoginCookieTimeout": 30}), .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ tAnswer _ " " _ $ClassMethod(..#SEAM, "Writes"), "200 {} ", "a Save that changes nothing answers {} and sends nothing")

    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#TOOL, "SYSTEM", {"Name": "SYSTEM", "LoginCookieTimeout": 45}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's change is minted (" _ tProblem _ ")")
    Do $$$AssertEquals(..Rows(tProposal), "LoginCookieTimeout 30 45", "with one diff row")
    Do $$$AssertEquals($Select($IsObject(tProposal): tProposal.%Get("unchangedCount") _ " " _ tProposal.%Get("target").%Get("id"), 1: ""), "19 SYSTEM", "nineteen settings sent unchanged, on the singleton (AD-13)")
    Do $$$AssertEquals(..Consequence(tProposal), "", "and no consequence")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "its confirm writes")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), ..#PUT, "one PUT")
    Set tSent = ##class(OcuPilot.Test.LicenseKey).Parsed($ClassMethod(..#SEAM, "BodyOf", ..#PUT))
    Do $$$AssertEquals(tSent.%IsDefined("AutheKB") _ " " _ tSent.%Get("LoginCookieTimeout"), "0 45", "less AutheKB, the change applied over the values read fresh at the confirm")
    Do $$$AssertEquals(..Verdict($Get(tResult)), "matches", "its read-back matches")
    Set tAfter = $ClassMethod(..#PROBE, "Facts")
    Do $$$AssertEquals(tAfter.%Get("LoginCookieTimeout") _ " " _ tAfter.%Get("raw"), "45 " _ tBefore.%Get("raw"), "and the instance stores it with its raw bits unchanged")
}

/// <p>A2, AD-4: a changed <code>AutheKB</code> is sent on both callers, as the vendor sets or clears all seven
/// Kerberos bits for it; the seam records it and never sends it.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Screen.Tool.AuthOptionsUpdate.MergeRaw</method> drops a changed
/// <code>AutheKB</code> -- the body leaves it out and this goes red.</p>
Method TestAChangedKerberosFlagIsSent()
{
    Do $ClassMethod(..#SEAM, "Arm", "answer")
    Set tSC = $ClassMethod(..#SAVE, "Handle", ..FullBody({"AutheKB": false}), .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus, 200, "the form's Save answers 200: " _ $Extract(tAnswer, 1, 300))
    Set tSent = ##class(OcuPilot.Test.LicenseKey).Parsed($ClassMethod(..#SEAM, "BodyOf", ..#PUT))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes") _ " " _ tSent.%IsDefined("AutheKB") _ " " _ tSent.%Get("AutheKB"), ..#PUT _ " 1 0", "one PUT carrying AutheKB false")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $ClassMethod(..#SEAM, "Arm", "answer")
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#TOOL, "SYSTEM", {"Name": "SYSTEM", "AutheKB": false}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's change is minted (" _ tProblem _ ")")
    Do $$$AssertEquals(..Rows(tProposal), "AutheKB true false", "with one row naming it")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "its confirm writes")
    Set tSent = ##class(OcuPilot.Test.LicenseKey).Parsed($ClassMethod(..#SEAM, "BodyOf", ..#PUT))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes") _ " " _ tSent.%Get("AutheKB"), ..#PUT _ " 0", "one PUT carrying it")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts").%Get("raw"), ##class(%DynamicObject).%FromJSON(..PreparedFacts).%Get("raw"), "and the instance keeps its bits")
}

/// <p>A2, AD-39: on both callers, each setting the rules refuse -- Always try Delegated without Delegated, LDAP
/// cache without LDAP, two-factor SMS without a server or a from address, a timeout that is not a whole number
/// from 0, an algorithm outside the six, an issuer over 1,024 characters and a setting of the wrong kind -- is
/// refused on its field with its published sentence before any vendor write, and the instance keeps its
/// values.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.AuthOptionsRules.Check</method> drops the SMS rule --
/// the two-factor leg is sent to the seam and this goes red.</p>
Method TestEachRuleIsRefusedOnItsFieldBeforeAnyWrite()
{
    Set tBefore = ..PreparedFacts
    Set tLong = $Translate($Justify("", 1025), " ", "x")
    Set tCases = $ListBuild($ListBuild("AutheAlwaysTryDelegated", 1, "boolean", "AutheAlwaysTryDelegated", "WEBAUTH.DELEGATED.REQUIRED"))
    Set tCases = tCases _ $ListBuild($ListBuild("AutheLDAPCache", 1, "boolean", "AutheLDAPCache", "WEBAUTH.LDAPCACHE.REQUIRED"), $ListBuild("AutheTwoFactorSMS", 1, "boolean", "SMTPServer", "WEBAUTH.SMS.SERVER"))
    Set tCases = tCases _ $ListBuild($ListBuild("LoginCookieTimeout", -1, "number", "LoginCookieTimeout", "WEBAUTH.COOKIETIMEOUT"), $ListBuild("LoginCookieTimeout", 1.5, "number", "LoginCookieTimeout", "WEBAUTH.COOKIETIMEOUT"), $ListBuild("LoginCookieTimeout", "x", "string", "LoginCookieTimeout", "WEBAUTH.COOKIETIMEOUT"))
    Set tCases = tCases _ $ListBuild($ListBuild("TwoFactorTimeout", -1, "number", "TwoFactorTimeout", "WEBAUTH.TWOFACTORTIMEOUT"), $ListBuild("JWTSigAlg", "XX999", "string", "JWTSigAlg", "WEBAUTH.JWTSIGALG"), $ListBuild("JWTIssuer", tLong, "string", "JWTIssuer", "WEBAUTH.JWTISSUER.LENGTH"))
    Set tCases = tCases _ $ListBuild($ListBuild("AutheLDAP", "yes", "string", "AutheLDAP", "PORT.FIELD.SHAPE"), $ListBuild("SMTPServer", 5, "number", "SMTPServer", "PORT.FIELD.SHAPE"))
    For tC = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tC)
        Do $ClassMethod(..#SEAM, "Clear")
        Set tLabel = $List(tCase, 1) _ " " _ $Extract($List(tCase, 2), 1, 12)
        Set tBody = {}
        Do tBody.%Set($List(tCase, 1), $List(tCase, 2), $List(tCase, 3))
        Set tSC = $ClassMethod(..#SAVE, "Handle", tBody, .tAnswer, .tStatus)
        Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LicenseKey).Violation(tAnswer), "422 " _ $List(tCase, 4) _ ":" _ $List(tCase, 5), tLabel _ ": the form's Save is refused on its field")
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", tLabel _ ": before any vendor write")
        Set tProblem = ""
        Set tBody = {"Name": "SYSTEM"}
        Do tBody.%Set($List(tCase, 1), $List(tCase, 2), $List(tCase, 3))
        If ($List(tCase, 5) '[ "WEBAUTH") && ($List(tCase, 3) = "string" || ($List(tCase, 5) = "PORT.FIELD.SHAPE")) {
            Set tSC = ##class(OcuPilot.Screen.Tool.Registry).ValidateArguments($ClassMethod(..#TOOL, "InputSchema"), tBody, .tProblem)
            Do $$$AssertTrue($$$ISERR(tSC) && (tProblem [ $List(tCase, 1)), tLabel _ ": and the agent's schema refuses a value of the wrong kind: " _ tProblem)
        }
        If $List(tCase, 5) [ "WEBAUTH" {
            Set tSC = $ClassMethod(..#AGENT, "Mint", ..#TOOL, "SYSTEM", tBody, .tProposal, .tHttp, .tProblem)
            Set tSentence = $Select($List(tCase, 3) = "string" && ($List(tCase, 1) [ "Timeout"): "'" _ $List(tCase, 4) _ "'", 1: "'" _ $List(tCase, 4) _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation($List(tCase, 5)))
            Do $$$AssertTrue('$IsObject(tProposal) && (tProblem [ tSentence), tLabel _ ": and the agent's mint is refused, with the same sentence where the argument has its kind: " _ tProblem)
        }
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts").%ToJSON(), tBefore, "the instance keeps every value")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#SAVE, "Handle", {"AutheTwoFactorSMS": true, "SMTPServer": "smtp.example.test"}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LicenseKey).Violation(tAnswer), "422 TwoFactorFrom:WEBAUTH.SMS.FROM", "an SMTP server without a from address is refused on the from address")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#SAVE, "Handle", {"Other": 1}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.EncryptionProbe).Refusal(tAnswer) _ " " _ $ClassMethod(..#SEAM, "Writes"), "400 Other:PORT.FIELD.UNEXPECTED ", "a key the tool does not admit is refused as unexpected")
}

/// <p>A3, AD-35, AD-56: a password sent by the Save, and one typed at the agent's confirm, is written, and each
/// read-back reads <code>written</code>; <code>""</code> clears it; a Save refused by a rule or by the
/// prohibited set writes no password, and a password write that fails is answered <code>secretsRefused</code>,
/// never <code>written</code>; the value appears in no answer, proposal, ledger row, seam record, script or
/// line of <code>messages.log</code> and <code>alerts.log</code>. A Save of the password alone sends no
/// settings <code>PUT</code>, and the password write's own body is recorded as present, never as its
/// value.</p>
/// <p>A control line written to <code>messages.log</code> after the writes must be found by the same scan, so a
/// scan that reads nothing cannot pass for one that found no marker.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Area.Security.AuthOptionsSave.Update</method> keeps
/// <code>SMTPPassword</code> in the merge body -- the Save is refused for the unexpected key and this goes
/// red.</p>
Method TestTheSmtpPasswordIsWrittenClearedAndReachesNoRecord()
{
    Set tMarker = "Ocu188" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(12)), "+/=", "xyz")
    Set tMessages = ##class(OcuPilot.Test.EncryptionProbe).LineCount("messages.log")
    Set tAlerts = ##class(OcuPilot.Test.EncryptionProbe).LineCount("alerts.log")
    Set tAnswers = ""
    Set tSC = $ClassMethod(..#SAVE, "Handle", {"SMTPPassword": (tMarker)}, .tAnswer, .tStatus)
    Set tAnswers = tAnswers _ tAnswer
    Do $$$AssertEquals(tStatus _ " " _ ..Verdict(##class(OcuPilot.Test.LicenseKey).Parsed(tAnswer)), "200 written", "the Save of the password alone answers written: " _ $Extract(tAnswer, 1, 300))
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), ..#PASSWORDPUT, "sending the password write alone")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts").%Get("smtpPasswordLength"), $Length(tMarker), "the instance stores it")
    Do $$$AssertEquals(##class(OcuPilot.Test.LicenseKey).Parsed($ClassMethod(..#SEAM, "BodyOf", ..#PASSWORDPUT)).%Get("SMTPPassword"), "<recorded as present>", "the seam records it as present, never its value")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#SAVE, "Handle", {"SMTPPassword": ""}, .tAnswer, .tStatus)
    Set tAnswers = tAnswers _ tAnswer
    Do $$$AssertEquals(tStatus _ " " _ ..Verdict(##class(OcuPilot.Test.LicenseKey).Parsed(tAnswer)) _ " " _ $ClassMethod(..#PROBE, "Facts").%Get("smtpPasswordLength"), "200 written 0", "an empty password clears the stored one")
    Set tSC = $ClassMethod(..#SAVE, "Handle", {"SMTPPassword": 5}, .tAnswer, .tStatus)
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LicenseKey).Violation(tAnswer), "422 SMTPPassword:PORT.FIELD.SHAPE", "a password that is not text is refused on its field")
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#SAVE, "Handle", {"LoginCookieTimeout": -1, "SMTPPassword": (tMarker)}, .tAnswer, .tStatus)
    Set tAnswers = tAnswers _ tAnswer
    Do $$$AssertEquals(tStatus _ " " _ ##class(OcuPilot.Test.LicenseKey).Violation(tAnswer) _ "|" _ $ClassMethod(..#SEAM, "Writes") _ "|" _ $ClassMethod(..#PROBE, "Facts").%Get("smtpPasswordLength"), "422 LoginCookieTimeout:WEBAUTH.COOKIETIMEOUT||0", "a Save refused on a setting writes no password")
    Set tSC = $ClassMethod(..#SAVE, "Handle", ..FullBody({"AutheCache": false, "SMTPPassword": (tMarker)}), .tAnswer, .tStatus)
    Set tAnswers = tAnswers _ tAnswer
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#SEAM, "Writes") _ "|" _ $ClassMethod(..#PROBE, "Facts").%Get("smtpPasswordLength"), "403||0", "and neither does one the prohibited set refuses")
    Do $ClassMethod(..#SEAM, "Clear")
    Do $ClassMethod(..#SEAM, "ArmFail", ..#PASSWORDPUT)
    Set tSC = $ClassMethod(..#SAVE, "Handle", {"SMTPPassword": (tMarker)}, .tAnswer, .tStatus)
    Set tAnswers = tAnswers _ tAnswer
    Set tParsed = ##class(OcuPilot.Test.LicenseKey).Parsed(tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ (tParsed.%Get("secretsRefused") '= "") _ "|" _ ..Verdict(tParsed) _ "|" _ $ClassMethod(..#PROBE, "Facts").%Get("smtpPasswordLength"), "200|1|(none)|0", "a password write that fails is answered refused, never written: " _ $Extract(tAnswer, 1, 200))
    Do $ClassMethod(..#SEAM, "Clear")
    Set tSC = $ClassMethod(..#SAVE, "Handle", ..FullBody({"LoginCookieTimeout": 31, "SMTPPassword": (tMarker)}), .tAnswer, .tStatus)
    Set tAnswers = tAnswers _ tAnswer
    Do $$$AssertEquals(tStatus _ " " _ $ClassMethod(..#SEAM, "Writes"), "200 " _ ..#PUT _ "," _ ..#PASSWORDPUT, "a Save of a setting and the password sends the merge, then the password: " _ $Extract(tAnswer, 1, 200))
    Do $$$AssertEquals(##class(OcuPilot.Test.LicenseKey).Keys(##class(OcuPilot.Test.LicenseKey).Parsed($ClassMethod(..#SEAM, "BodyOf", ..#PUT))) [ "SMTPPassword", 0, "the merge body carries no password")
    Do $ClassMethod(..#PROBE, "Restore", ##class(%DynamicObject).%FromJSON(..PreparedFacts))
    Do $ClassMethod(..#SEAM, "Clear")

    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#PASSWORDTOOL, "SYSTEM", {"Name": "SYSTEM"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's password change is minted (" _ tProblem _ ")")
    Do $$$AssertEquals(..Rows(tProposal), "SMTPPassword  ", "its one row names the secret and carries no value")
    Set tDraft = ##class(OcuPilot.Test.EncryptionKeyWrite).Draft(tProposal, .tSteps)
    Do $$$AssertTrue((tDraft [ "<SMTPPassword>") && (tDraft '[ tMarker), "its script renders the placeholder: " _ $Extract(tDraft, 1, 300))
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#PASSWORDTOOL, "SYSTEM", {"Name": "SYSTEM"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals(##class(OcuPilot.Test.EncryptionProbe).Confirm(tProposal, {"SMTPPassword": (tMarker)}, .tResult), "200 ", "and confirmed with the marker")
    Set tAnswers = tAnswers _ $Select($IsObject($Get(tResult)): tResult.%ToJSON(), 1: "") _ tDraft
    Do $$$AssertEquals(..Verdict($Get(tResult)), "written", "its read-back reads written")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts").%Get("smtpPasswordLength"), $Length(tMarker), "and the instance stores it")
    Do $$$AssertTrue(tAnswers '[ tMarker, "no answer or script carries the marker")
    Set tControl = "OCUPROBE188 log control " _ $ZTimeStamp
    Do ##class(%SYS.System).WriteToConsoleLog(tControl, 0, 0)
    Set tLines = ##class(OcuPilot.Test.EncryptionProbe).LinesAfter("messages.log", tMessages).%ToJSON() _ ##class(OcuPilot.Test.EncryptionProbe).LinesAfter("alerts.log", tAlerts).%ToJSON()
    Do $$$AssertTrue(tLines [ tControl, "the log scan reads the lines written since the test began")
    Do $$$AssertTrue(tLines '[ tMarker, "messages.log and alerts.log carry no marker")
    Set tStored = ##class(OcuPilot.Test.EncryptionKeyFileWrite).StoredText(tProposal.%Get("proposalId"))
    Do $$$AssertTrue((tStored '= "") && (tStored '[ tMarker), "the proposal row and its ledger rows carry no marker")
    Do $$$AssertEquals(..SeamHolds(tMarker), 0, "and no seam record carries it")
}

/// <p>AD-6, AD-34: a field moved between the mint and the confirm refuses the confirm as a changed target and
/// sends nothing; a Save on a target another write holds waits out the claim lock and answers 409
/// <code>WRITE.TARGETBUSY</code> over the wire, writing nothing, and the same Save answers 200 once the hold is
/// released. This process plays the other write.</p>
/// <p>Mutation (Rule 19): drop <code>HoldTool</code> from
/// <method>OcuPilot.Area.Security.AuthOptionsSave.HandleUpdate</method> -- the held Save answers 200 and this
/// goes red.</p>
Method TestAMovedTargetAndABusyTargetAreRefused()
{
    Set tSC = $ClassMethod(..#AGENT, "Mint", ..#TOOL, "SYSTEM", {"Name": "SYSTEM", "LoginCookieTimeout": 45}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "a change is minted (" _ tProblem _ ")")
    Set tMoved = $ClassMethod(..#PROBE, "Facts")
    Do $ClassMethod(..#PROBE, "Restore", ..Moved(tMoved, "TwoFactorTimeout", 200))
    Do $ClassMethod(..#SEAM, "Clear")
    Set tConfirmed = $ClassMethod(..#AGENT, "Confirm", tProposal, .tResult)
    Do $$$AssertEquals(tConfirmed, "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "a setting the payload carries, moved since the mint, refuses the confirm as a changed target: " _ tConfirmed)
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Writes"), "", "and nothing is sent")

    Do ##class(OcuPilot.Kernel.EntityRef).Key("authentication-options", "instance", "SYSTEM", .tRef)
    Set tLockKey = ##class(OcuPilot.Kernel.State.Propose).TargetHoldKey(tRef)
    Do $$$AssertNotEquals(tLockKey, "", "the options name a lock")
    Lock +^OcuPilotProposalTarget(tLockKey):5
    Set tHeld = $Test
    Do $$$AssertTrue(tHeld, "which this process holds, as another write's hold does")
    If 'tHeld Quit
    Set tStatus = 0
    Set tBody = ""
    Try {
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/authentication-options", .tStatus, .tBody, {"LoginCookieTimeout": 33}.%ToJSON(), "application/json")
    } Catch {
    }
    Lock -^OcuPilotProposalTarget(tLockKey)
    Set tAnswer = tStatus _ " " _ $Select($IsObject(tBody): tBody.%Get("code") _ " " _ tBody.%Get("reason"), 1: tBody)
    Do $$$AssertEquals(tAnswer, "409 WRITE.TARGETBUSY " _ ##class(OcuPilot.Api.Error).#REASONWRITETARGETBUSY, "the held Save is refused busy, with the published reason")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts").%Get("LoginCookieTimeout"), tMoved.%Get("LoginCookieTimeout"), "and the cookie timeout is as it was")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("PUT", "/authentication-options", .tStatus, .tBody, {"LoginCookieTimeout": 33}.%ToJSON(), "application/json")
    Do $$$AssertEquals(tStatus, 200, "released, the same Save answers 200: " _ $Select($IsObject($Get(tBody)): tBody.%ToJSON(), 1: ""))
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts").%Get("LoginCookieTimeout"), 33, "and stores it")
}

/// <p>Whether any record of the seam holds <var>pText</var>.</p>
ClassMethod SeamHolds(pText As %String) As %Boolean
{
    Set tFound = 0
    Set tRef = "^||OcuPilotAuthSeam"
    Set tNext = $Query(@tRef)
    While tNext '= "" {
        If $QSubscript(tNext, 1) '= "" {
            If (tNext [ pText) || ($Get(@tNext) [ pText) Set tFound = 1
        }
        Set tNext = $Query(@tNext)
    }
    Quit tFound
}

/// <p>The complete set the form would send, the stock instance's twenty-one settings as the instance reads
/// them now, with <var>pChanges</var> applied.</p>
ClassMethod FullBody(pChanges As %DynamicObject) As %DynamicObject
{
    Kill tQuery
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.WebAuth", "GET", .tQuery, "", .tHeld, .tHttp, .tFault)
    Set tBody = ##class(%DynamicObject).%FromJSON(tHeld.%ToJSON())
    Set tIterator = pChanges.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Do tBody.%Set(tKey, tValue, pChanges.%GetTypeOf(tKey))
    }
    Quit tBody
}

/// <p>The facts <var>pFacts</var> with <var>pName</var> set to <var>pValue</var>, for
/// <method>OcuPilot.Test.AuthOptionsProbe.Restore</method>.</p>
ClassMethod Moved(pFacts As %DynamicObject, pName As %String, pValue As %String) As %DynamicObject
{
    Set tMoved = ##class(%DynamicObject).%FromJSON(pFacts.%ToJSON())
    Do tMoved.%Set(pName, pValue, "number")
    Quit tMoved
}

/// <p>A proposal's rows as <code>field before after</code>, one row expected.</p>
ClassMethod Rows(pProposal) As %String
{
    If '$IsObject(pProposal) Quit "(no proposal)"
    Set tRows = pProposal.%Get("changed")
    If '$IsObject(tRows) || (tRows.%Size() '= 1) Quit $Select($IsObject(tRows): tRows.%ToJSON(), 1: "")
    Set tRow = tRows.%Get(0)
    Quit tRow.%Get("field") _ " " _ tRow.%Get("before") _ " " _ tRow.%Get("after")
}

/// <p>The consequence code the stored proposal <var>pProposal</var> carries, or <code>""</code>.</p>
ClassMethod Consequence(pProposal) As %String
{
    If '$IsObject(pProposal) Quit ""
    Set tSC = ##class(OcuPilot.Kernel.State.Propose).GuardedByKey(pProposal.%Get("proposalId"), .tFound, .tValues)
    If $$$ISERR(tSC) || '$Get(tFound) Quit ""
    Quit $Get(tValues("consequence"))
}

/// <p>The read-back verdict an answer carries, the answer an object, or <code>(none)</code>.</p>
ClassMethod Verdict(pAnswer) As %String
{
    If '$IsObject(pAnswer) || (pAnswer.%GetTypeOf("readBack") '= "object") Quit "(none)"
    Quit pAnswer.%Get("readBack").%Get("verdict")
}

}
