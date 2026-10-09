/// <p>Pins Story 18.29's password verdict (AD-35): <class>OcuPilot.Kernel.PasswordPolicy</class>'s reason for a
/// pattern refusal, an accepted password, an empty one, and a validation routine's refusal, and the guard
/// <class>OcuPilot.Port.AdminPort</class> runs before a <code>Security.User</code> <code>POST</code> or
/// <code>CHANGEPWD</code> reaches the vendor, and the check route <code>POST /users/password-check</code>.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, an account holding
/// <code>%Admin_Secure</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it
/// creates and deletes accounts with the <code>OcuProbe1829</code> prefix and, for the routine legs, changes the
/// instance's <code>PasswordValidationRoutine</code>. Each test restores that setting and <method>OnAfterAllTests</method>
/// deletes the probe routine.</p>
/// <p>Mutations (Rule 19): make <method>OcuPilot.Kernel.PasswordPolicy.Verdict</method> return the routine's raw
/// text as the reason -- the quoting leg reddens. Remove 845 from <parameter>OcuPilot.Kernel.PasswordPolicy.POLICYCODES</parameter>
/// -- the pattern leg reddens. Drop the reason from the create rules' password violation -- the create leg reddens. Make <method>OcuPilot.Port.AdminPort.InvokeLocated</method> read
/// the account name from the query on a <code>POST</code> -- the body-named leg reddens. Drop <code>"POST"</code>
/// from <method>OcuPilot.Port.AdminPort.IsPasswordType</method> -- the same leg reddens. Remove the guard's call in
/// <method>OcuPilot.Port.AdminPort.InvokeLocated</method> -- the set-password leg reaches the vendor and reddens.</p>
Class OcuPilot.Test.PasswordPolicy Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The account the set-password leg changes, created and removed by this class.</p>
Parameter ACCOUNT = "OcuProbe1829Pwd";

/// <p>The account a <code>POST</code> would create; the vendor must not create it.</p>
Parameter NEWACCOUNT = "OcuProbe1829Named";

/// <p>A password the instance's policy accepts.</p>
Parameter GOODPASSWORD = "Ocu-Probe-1829xyz!";

/// <p>A password the probe routine's entries refuse, because it carries <parameter>MARKER</parameter>.</p>
Parameter MARKEDPASSWORD = "OcuRefuse1829!x";

/// <p>What <parameter>MARKEDPASSWORD</parameter> carries for the probe routine to refuse it.</p>
Parameter MARKER = "OcuRefuse1829";

/// <p>The probe validation routine this class installs in <code>%SYS</code>.</p>
Parameter VALIDATIONROUTINE = "OcuProbe1829Pw";

/// <p>The sentence the probe routine's <code>Refuse</code> entry answers with error 5001.</p>
Parameter REFUSALSENTENCE = "Probe sentence 1829.";

/// <p>The sentence the probe routine's <code>User</code> entry answers when the password carries the account name.</p>
Parameter NAMESENTENCE = "Passwords on this instance may not contain the account name.";

/// <p>The sentence the probe routine's <code>Other</code> entry answers with error 5002, a code the published set does not list.</p>
Parameter OTHERSENTENCE = "Probe sentence 1829 other.";

/// <p>The text the probe routine's <code>Pattern</code> entry gives error 958, the instance's pattern refusal.</p>
Parameter PATTERNTEXT = "Probe pattern 1829";

Parameter CHECKPATH = "/users/password-check";

Parameter CREATEPATH = "/users";

/// <p>The instance's <code>PasswordValidationRoutine</code> as <method>OnBeforeAllTests</method> read it, which
/// every teardown restores.</p>
Property PreparedValidationRoutine As %String;

/// <p>Whether <method>ReadValidationRoutine</method> read the instance's setting. Until it has, there is nothing to restore.</p>
Property PreparedValidationRead As %Boolean [ InitialExpression = 0 ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedValidationRoutine = ""
    Set ..PreparedValidationRead = 0
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.PasswordPolicy creates accounts on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created.")
    }
    Do ..RemoveAccount(..#ACCOUNT)
    Do ..RemoveAccount(..#NEWACCOUNT)
    Set tSC = ..MakeAccount()
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..ReadValidationRoutine()
    If $$$ISERR(tSC) Quit tSC
    Quit ..InstallRoutine()
}

Method OnAfterAllTests() As %Status
{
    Set tSC = ..RestoreValidationRoutine()
    Do ..RemoveRoutine()
    Do ..RemoveAccount(..#ACCOUNT)
    Do ..RemoveAccount(..#NEWACCOUNT)
    Quit tSC
}

/// <p>Restore the validation routine setting and remove the account a test may have created, whatever the test did.</p>
Method OnAfterOneTest() As %Status
{
    Set tSC = ..RestoreValidationRoutine()
    Do ..RemoveAccount(..#NEWACCOUNT)
    Quit tSC
}

/// <p>AD-35: an accepted password answers 1 with no reason; a password the pattern refuses answers 0 with the
/// published sentence, because the vendor's pattern sentence (error 845) contains <code>a</code>, the whole password,
/// so the verdict replaces it; an empty password answers 0 with the required sentence.</p>
Method TestTheVerdictAcceptsAndRefusesAndNeverEmptiesTheReason()
{
    Set tOK = ##class(OcuPilot.Kernel.PasswordPolicy).Verdict(..#GOODPASSWORD, ..#ACCOUNT, .tReason)
    Do $$$AssertEquals(tOK, 1, "a password the policy accepts is accepted")
    Do $$$AssertEquals(tReason, "", "with no reason")

    Set tOK = ##class(OcuPilot.Kernel.PasswordPolicy).Verdict("a", ..#ACCOUNT, .tReason)
    Do $$$AssertEquals(tOK, 0, "a password the pattern refuses is refused")
    Do $$$AssertEquals(tReason, ##class(OcuPilot.Api.Error).#REASONUSERPASSWORDPOLICY, "with the published sentence")

    Set tOK = ##class(OcuPilot.Kernel.PasswordPolicy).Verdict("", ..#ACCOUNT, .tReason)
    Do $$$AssertEquals(tOK, 0, "an empty password is refused")
    Do $$$AssertEquals(tReason, ##class(OcuPilot.Api.Error).#REASONUSERPASSWORDREQUIRED, "with the required sentence")
}

/// <p>AD-35: a routine refusal (5001) whose text quotes the password is answered with the published sentence, and the
/// password appears in no reason.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.PasswordPolicy.Verdict</method> return the routine's raw text
/// as the reason -- this leg reddens.</p>
Method TestARoutineRefusalThatQuotesThePasswordIsReplacedByThePublishedSentence()
{
    Set tSC = ..UseEntry("Quote")
    Do $$$AssertStatusOK(tSC, "the setting names the quoting entry")
    Set tOK = ##class(OcuPilot.Kernel.PasswordPolicy).Verdict(..#MARKEDPASSWORD, ..#ACCOUNT, .tReason)
    Do $$$AssertEquals(tOK, 0, "a password the routine refuses is refused")
    Do $$$AssertEquals(tReason, ##class(OcuPilot.Api.Error).#REASONUSERPASSWORDPOLICY, "with the published sentence")
    Do $$$AssertTrue(tReason '[ ..#MARKER, "and the reason does not quote the password")
}

/// <p>AD-35: a routine refusal (5001) with its own sentence keeps that sentence as the reason.</p>
Method TestARoutineRefusalWithItsOwnSentenceIsKept()
{
    Set tSC = ..UseEntry("Refuse")
    Do $$$AssertStatusOK(tSC, "the setting names the refusing entry")
    Set tOK = ##class(OcuPilot.Kernel.PasswordPolicy).Verdict(..#MARKEDPASSWORD, ..#ACCOUNT, .tReason)
    Do $$$AssertEquals(tOK, 0, "a password the routine refuses is refused")
    Do $$$AssertEquals(tReason, ..#REFUSALSENTENCE, "with the routine's own sentence")
}

/// <p>AD-35: the check route answers <code>{valid, reason}</code> with the published sentence for a password the routine
/// refuses, and the answer carries no byte of the password.</p>
Method TestTheCheckRouteAnswersThePublishedSentenceAndNeverEchoesThePassword()
{
    Set tSC = ..UseEntry("Quote")
    Do $$$AssertStatusOK(tSC, "the setting names the quoting entry")
    Set tBody = "{""name"":""" _ ..#ACCOUNT _ """,""password"":""" _ ..#MARKEDPASSWORD _ """}"
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CHECKPATH, .tStatus, .tAnswer, tBody, "application/json")
    Do $$$AssertStatusOK(tSC, "the check request completes")
    Do $$$AssertEquals(tStatus, 200, "the check answers 200")
    Do $$$AssertEquals($Select($IsObject($Get(tAnswer)): tAnswer.%Get("valid"), 1: 1), 0, "a refused password answers valid false")
    Do $$$AssertEquals($Select($IsObject($Get(tAnswer)): tAnswer.%Get("reason"), 1: ""), ##class(OcuPilot.Api.Error).#REASONUSERPASSWORDPOLICY, "with the published sentence")
    Set tRaw = $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: "")
    Do $$$AssertTrue(tRaw '[ ..#MARKER, "and the answer's raw body carries no part of the password")
}

/// <p>AD-35, AD-2: a <code>POST</code> whose password the routine refuses because it carries the body's <code>Name</code>
/// is 422 <code>USER.PASSWORD.POLICY</code> before the vendor is called, and no account is created. The account is named
/// in the body on a <code>POST</code>, not in the query.</p>
/// <p>Mutation (Rule 19): drop <code>"POST"</code> from <method>OcuPilot.Port.AdminPort.IsPasswordType</method>, or read
/// the name from the query -- this leg reddens.</p>
Method TestAPostIsJudgedByTheAccountNameInItsBody()
{
    Set tSC = ..UseEntry("User")
    Do $$$AssertStatusOK(tSC, "the setting names the account-name entry")
    Kill tQuery
    Set tBody = {}
    Do tBody.%Set("Name", ..#NEWACCOUNT, "string")
    Do tBody.%Set("Password", ..#NEWACCOUNT _ "!x", "string")
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.User", "POST", .tQuery, tBody, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 422, "a password carrying the body's name is 422")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), ##class(OcuPilot.Api.Error).#USERPASSWORDPOLICY, "on USER.PASSWORD.POLICY")
    Do $$$AssertTrue('..Exists(..#NEWACCOUNT), "and no account was created")
}

/// <p>AD-35: a <code>POST</code> whose password the instance's pattern refuses is 422 <code>USER.PASSWORD.POLICY</code> on
/// <code>Password</code>, and no account is created.</p>
Method TestAPostWithAPatternRefusalIsRefusedBeforeTheVendor()
{
    Kill tQuery
    Set tBody = {}
    Do tBody.%Set("Name", ..#NEWACCOUNT, "string")
    Do tBody.%Set("Password", "a", "string")
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.User", "POST", .tQuery, tBody, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 422, "a refused password on POST is 422")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), ##class(OcuPilot.Api.Error).#USERPASSWORDPOLICY, "on USER.PASSWORD.POLICY")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%Get("detail").%Get("violations").%Get(0).%Get("field"), 1: ""), "Password", "naming the Password field")
    Do $$$AssertTrue('..Exists(..#NEWACCOUNT), "and no account was created")
}

/// <p>AD-35, AD-2: a set-password the policy refuses is 422 <code>USER.PASSWORD.POLICY</code> on
/// <code>Password</code>, answered by the port before the vendor is called.</p>
Method TestTheSetPasswordGuardRefusesBeforeTheVendor()
{
    Kill tQuery
    Set tQuery("name") = ..#ACCOUNT
    Set tBody = {}
    Do tBody.%Set("Password", "a", "string")
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.User", "CHANGEPWD", .tQuery, tBody, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 422, "a refused set-password is 422")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), ##class(OcuPilot.Api.Error).#USERPASSWORDPOLICY, "on USER.PASSWORD.POLICY")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%Get("detail").%Get("violations").%Get(0).%Get("field"), 1: ""), "Password", "naming the Password field")
}

/// <p>AD-35: a routine refusal whose error code the published set does not list is answered with the published
/// sentence, never with the routine's own text.</p>
/// <p>Mutation (Rule 19): delete the <code>$ListFind</code> gate in <method>OcuPilot.Kernel.PasswordPolicy.Verdict</method>
/// -- this leg reddens.</p>
Method TestAnUnlistedRefusalCodeIsReplacedByThePublishedSentence()
{
    Set tSC = ..UseEntry("Other")
    Do $$$AssertStatusOK(tSC, "the setting names the unlisted-code entry")
    Set tOK = ##class(OcuPilot.Kernel.PasswordPolicy).Verdict(..#MARKEDPASSWORD, ..#ACCOUNT, .tReason)
    Do $$$AssertEquals(tOK, 0, "a password the routine refuses is refused")
    Do $$$AssertEquals(tReason, ##class(OcuPilot.Api.Error).#REASONUSERPASSWORDPOLICY, "with the published sentence, not the routine's text")
}

/// <p>AD-39: a refusal keeps the validator's own sentence for 845 and 958. <code>Zq</code> is refused by the
/// instance's length and pattern rule (845), whose sentence does not contain it; the probe routine's
/// <code>Pattern</code> entry refuses with 958.</p>
/// <p>Mutation (Rule 19): remove 845 from <parameter>OcuPilot.Kernel.PasswordPolicy.POLICYCODES</parameter> -- the
/// 845 leg reddens.</p>
Method TestThePatternRefusalsKeepTheirOwnSentence()
{
    Set tSC = $System.Security.ValidatePassword("Zq", ..#ACCOUNT)
    Do $$$AssertEquals($Piece($System.Status.GetErrorCodes(tSC), ",", 1), 845, "the instance refuses Zq with 845, its length and pattern refusal")
    Set tOwn = $System.Status.GetOneStatusText(tSC, 1)
    Set tOK = ##class(OcuPilot.Kernel.PasswordPolicy).Verdict("Zq", ..#ACCOUNT, .tReason)
    Do $$$AssertEquals(tOK, 0, "Zq is refused")
    Do $$$AssertEquals(tReason, tOwn, "with the validator's own 845 sentence")
    Do $$$AssertNotEquals(tReason, ##class(OcuPilot.Api.Error).#REASONUSERPASSWORDPOLICY, "not the published sentence")

    Set tSC = ..UseEntry("Pattern")
    Do $$$AssertStatusOK(tSC, "the setting names the 958 entry")
    Set tOK = ##class(OcuPilot.Kernel.PasswordPolicy).Verdict(..#MARKEDPASSWORD, ..#ACCOUNT, .tReason)
    Do $$$AssertEquals(tOK, 0, "a password the routine refuses with 958 is refused")
    Do $$$AssertEquals(tReason, $System.Status.GetOneStatusText($System.Status.Error(958, ..#PATTERNTEXT), 1), "with the 958 refusal's own sentence")
}

/// <p>AD-35, AD-2: a set-password names its account in the query, so a password the routine refuses because it
/// carries that name is 422 <code>USER.PASSWORD.POLICY</code> with the routine's sentence, before the vendor.</p>
/// <p>Mutation (Rule 19): read no account name for a <code>CHANGEPWD</code> in
/// <method>OcuPilot.Port.AdminPort.InvokeLocated</method> -- this leg reddens.</p>
Method TestASetPasswordIsJudgedByTheAccountNameInItsQuery()
{
    Set tSC = ..UseEntry("User")
    Do $$$AssertStatusOK(tSC, "the setting names the account-name entry")
    Kill tQuery
    Set tQuery("name") = ..#ACCOUNT
    Set tBody = {}
    Do tBody.%Set("Password", ..#ACCOUNT _ "!x", "string")
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.User", "CHANGEPWD", .tQuery, tBody, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 422, "a password carrying the query's account name is 422")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), ##class(OcuPilot.Api.Error).#USERPASSWORDPOLICY, "on USER.PASSWORD.POLICY")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%Get("reason"), 1: ""), ..#NAMESENTENCE, "with the routine's own sentence")
}

/// <p>AD-39 (DW-2231): a create through <code>POST /users</code> whose password the routine refuses answers 422 with
/// the routine's own sentence on <code>Password</code>, in one envelope with the request's other broken rule, because
/// the create rules ask the policy before the port is reached. Nothing is created.</p>
/// <p>Mutation (Rule 19): drop the reason from the password violation in
/// <method>OcuPilot.Area.Permissions.UserCreateRules.Validate</method> -- the reason leg reddens.</p>
Method TestACreateRefusalCarriesThePolicysOwnReason()
{
    Set tSC = ..UseEntry("Refuse")
    Do $$$AssertStatusOK(tSC, "the setting names the refusing entry")
    Set tBody = "{""Name"":""" _ ..#NEWACCOUNT _ """,""Password"":""" _ ..#MARKEDPASSWORD _ """,""ExpirationDate"":""2027-02-30""}"
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tAnswer, tBody, "application/json")
    Do $$$AssertStatusOK(tSC, "the create request completes")
    Do $$$AssertEquals(tStatus, 422, "a refused password is 422")
    Set tPasswordReason = ""
    Set tExpiryCode = ""
    If $IsObject($Get(tAnswer)) && $IsObject(tAnswer.%Get("detail")) && $IsObject(tAnswer.%Get("detail").%Get("violations")) {
        Set tIterator = tAnswer.%Get("detail").%Get("violations").%GetIterator()
        While tIterator.%GetNext(.tIndex, .tViolation) {
            If tViolation.%Get("field") = "Password" Set tPasswordReason = tViolation.%Get("reason")
            If tViolation.%Get("field") = "ExpirationDate" Set tExpiryCode = tViolation.%Get("code")
        }
    }
    Do $$$AssertEquals(tPasswordReason, ..#REFUSALSENTENCE, "the password's violation carries the routine's own sentence")
    Do $$$AssertNotEquals(tExpiryCode, "", "beside the expiry date's violation, in the same envelope")
    Do $$$AssertTrue('..Exists(..#NEWACCOUNT), "and no account was created")
}

/// <p>AD-35, AD-2: a refused <code>POST</code> and a refused set-password write no part of the password to the console
/// log. The lines written since before the two refusals are read after a flush, which is asserted first, so an empty
/// read is a read that happened.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.AdminPort.PasswordGuard</method> log the request body before it
/// refuses -- this leg reddens.</p>
Method TestARefusedPostAndSetPasswordWriteNoPasswordToTheLog()
{
    Set tSC = ..UseEntry("Quote")
    Do $$$AssertStatusOK(tSC, "the setting names the quoting entry, so the marked password is refused")
    Set tOffset = ##class(OcuPilot.Test.SslSinks).LogOffset()
    Kill tQuery
    Set tBody = {}
    Do tBody.%Set("Name", ..#NEWACCOUNT, "string")
    Do tBody.%Set("Password", ..#MARKEDPASSWORD, "string")
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.User", "POST", .tQuery, tBody, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 422, "a refused POST is 422")
    Kill tQuery
    Set tQuery("name") = ..#ACCOUNT
    Set tBody = {}
    Do tBody.%Set("Password", ..#MARKEDPASSWORD, "string")
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.User", "CHANGEPWD", .tQuery, tBody, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 422, "a refused set-password is 422")
    Do $$$AssertTrue(##class(OcuPilot.Test.SslSinks).Flush(tOffset), "messages.log is written past the refusals")
    Set tLog = ##class(OcuPilot.Test.SslSinks).LogSince(tOffset)
    Do $$$AssertEquals(tLog [ ..#MARKER, 0, "and no line written since carries the password's marker")
    Do $$$AssertEquals(tLog [ "Security.User failed", 0, "and neither refusal writes a fault line")
}

/// <p>Point the instance's <code>PasswordValidationRoutine</code> at entry <var>pTag</var> of the probe routine, in
/// <code>%SYS</code>.</p>
Method UseEntry(pTag As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        Set tProps("PasswordValidationRoutine") = pTag _ "^" _ ..#VALIDATIONROUTINE
        Set tSC = ##class(Security.System).Modify("SYSTEM", .tProps)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Read the instance's own <code>PasswordValidationRoutine</code> into <property>PreparedValidationRoutine</property>.
/// A probe an interrupted run left configured is not the instance's own setting.</p>
Method ReadValidationRoutine() As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.System).Get("SYSTEM", .tSystem)
        If $$$ISOK(tSC) {
            Set ..PreparedValidationRoutine = $Get(tSystem("PasswordValidationRoutine"))
            If $Piece(..PreparedValidationRoutine, "^", 2) = ..#VALIDATIONROUTINE Set ..PreparedValidationRoutine = ""
            Set ..PreparedValidationRead = 1
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Restore <property>PreparedValidationRoutine</property> as the instance's validation routine setting. When
/// <method>ReadValidationRoutine</method> never read the setting, nothing is written and the answer is an error, so a
/// read that failed cannot restore an empty routine over the instance's own.</p>
Method RestoreValidationRoutine() As %Status
{
    If '..PreparedValidationRead Quit $$$ERROR($$$GeneralError, "the instance's PasswordValidationRoutine was never read, so nothing is restored")
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        Set tProps("PasswordValidationRoutine") = ..PreparedValidationRoutine
        Set tSC = ##class(Security.System).Modify("SYSTEM", .tProps)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Install <parameter>VALIDATIONROUTINE</parameter> in <code>%SYS</code>, compiled, with the entries the legs use.</p>
Method InstallRoutine() As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Do ..RemoveRoutineInSys()
        Set tRoutine = ##class(%Routine).%New(..#VALIDATIONROUTINE _ ".INT")
        Do tRoutine.WriteLine(..#VALIDATIONROUTINE _ " ; OcuPilot.Test.PasswordPolicy: a throwaway password validation routine")
        Do tRoutine.WriteLine("Quote(Username,Password) PUBLIC {")
        Do tRoutine.WriteLine(" If Password [ """ _ ..#MARKER _ """ Quit $System.Status.Error(5001,""The password ""_Password_"" is refused here."")")
        Do tRoutine.WriteLine(" Quit 1")
        Do tRoutine.WriteLine("}")
        Do tRoutine.WriteLine("Refuse(Username,Password) PUBLIC {")
        Do tRoutine.WriteLine(" If Password [ """ _ ..#MARKER _ """ Quit $System.Status.Error(5001,""" _ ..#REFUSALSENTENCE _ """)")
        Do tRoutine.WriteLine(" Quit 1")
        Do tRoutine.WriteLine("}")
        Do tRoutine.WriteLine("User(Username,Password) PUBLIC {")
        Do tRoutine.WriteLine(" If (Username '= """") && ($ZConvert(Password,""L"") [ $ZConvert(Username,""L"")) Quit $System.Status.Error(5001,""" _ ..#NAMESENTENCE _ """)")
        Do tRoutine.WriteLine(" Quit 1")
        Do tRoutine.WriteLine("}")
        Do tRoutine.WriteLine("Pattern(Username,Password) PUBLIC {")
        Do tRoutine.WriteLine(" If Password [ """ _ ..#MARKER _ """ Quit $System.Status.Error(958,""" _ ..#PATTERNTEXT _ """)")
        Do tRoutine.WriteLine(" Quit 1")
        Do tRoutine.WriteLine("}")
        Do tRoutine.WriteLine("Other(Username,Password) PUBLIC {")
        Do tRoutine.WriteLine(" If Password [ """ _ ..#MARKER _ """ Quit $System.Status.Error(5002,""" _ ..#OTHERSENTENCE _ """)")
        Do tRoutine.WriteLine(" Quit 1")
        Do tRoutine.WriteLine("}")
        Set tSC = tRoutine.Save()
        If $$$ISOK(tSC) Set tSC = tRoutine.Compile("-d")
        Set tRoutine = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Delete <parameter>VALIDATIONROUTINE</parameter> from <code>%SYS</code> when it exists.</p>
Method RemoveRoutine() As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Do ..RemoveRoutineInSys()
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Delete the probe routine; the caller is already in <code>%SYS</code>.</p>
Method RemoveRoutineInSys()
{
    If ##class(%Routine).Exists(..#VALIDATIONROUTINE) Set tDeleteSC = ##class(%Routine).Delete(..#VALIDATIONROUTINE _ ".INT", 0, 1)
}

/// <p>Whether account <var>pName</var> exists, read in <code>%SYS</code>.</p>
ClassMethod Exists(pName As %String) As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tExists = 0
    Try {
        Set $NAMESPACE = "%SYS"
        Set tExists = ##class(Security.Users).Exists(pName, .tUser, .tStatus)
    } Catch ex {
    }
    Set $NAMESPACE = tOrigNS
    Quit tExists
}

/// <p>Create the probe account, in <code>%SYS</code> by AD-16's save and restore.</p>
ClassMethod MakeAccount() As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Users).Create(..#ACCOUNT, "%Developer", ..#GOODPASSWORD, "Probe Password")
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove the named probe account, if it exists, in <code>%SYS</code>.</p>
ClassMethod RemoveAccount(pName As %String)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tExists = ##class(Security.Users).Exists(pName, .tUser, .tStatus)
        If tExists Do ##class(Security.Users).Delete(pName)
    } Catch ex {
    }
    Set $NAMESPACE = tOrigNS
}

}
