/// <p><code>POST /account/password</code> over the wire (Story 15.1, AD-49): the four outcomes the
/// route publishes, each asserted on status, content type and body shape, as a principal that is
/// not the suite's own account.</p>
/// <p><b>It changes a password, so it needs an account of its own.</b> One throwaway user and its
/// role are created in <method>OnBeforeAllTests</method> and deleted in
/// <method>OnAfterAllTests</method>; the role holds read on the install namespace's code database
/// (without which IRIS cannot load the dispatch class for that request) and
/// <code>%Admin_Operate:USE</code> (which clears the API's own administrative gate). Both
/// passwords are generated for the run and never written to source.</p>
/// <p><b>One leg sets the instance-wide password validation routine</b> to a routine it installs
/// in <code>%SYS</code>. The leg restores the setting and deletes the routine itself, and
/// <method>OnAfterOneTest</method> repeats both after every method and fails the class if either
/// survives.</p>
/// <p><b>It creates security principals, so it runs on a throwaway container only</b>
/// (<file>scripts/ci-throwaway.sh</file>), and <method>OnBeforeAllTests</method> refuses anywhere
/// <parameter>ARMINGVARIABLE</parameter> does not arm it.</p>
Class OcuPilot.Test.AccountPasswordWire Extends %UnitTest.TestCase
{

/// <p>The route under test.</p>
Parameter PASSWORDPATH = "/api/ocupilot/account/password";

/// <p>A route the same principal can read, used to show the tab is still authorized after a
/// change (AD-28: authorization is Bearer-only, and Basic here stands in for it).</p>
Parameter INSTANCEPATH = "/api/ocupilot/instance";

/// <p>The environment variable that arms this class, and the one value that arms it:
/// <code>1</code>. Only <file>scripts/ci-throwaway.sh</file> sets it.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The throwaway account whose own password this class changes.</p>
Parameter PROBEUSER = "OcuPilotAccountProbe";

/// <p>See <parameter>PROBEUSER</parameter>.</p>
Parameter PROBEROLE = "OcuPilotAccountProbeRole";

/// <p>A new password shorter than the shortest this build's <code>PasswordPattern</code> admits
/// (<code>3.255ANP</code>), which is what makes the policy leg fire on an unmodified instance.</p>
Parameter TOOSHORTPASSWORD = "ab";

/// <p>The routine this class installs in <code>%SYS</code> as the instance's password validation
/// routine. Its entry points refuse a new password carrying <parameter>REFUSEDMARKER</parameter>
/// and admit every other: <code>Refuse</code> with <parameter>REFUSALSENTENCE</parameter>,
/// <code>Quote</code> with a sentence that quotes the password, <code>Empty</code> with no
/// sentence, <code>Pattern</code> with a 958 whose text quotes it, and <code>Both</code> with a
/// status that leads with a 5002 before its refusal; <code>Boom</code> raises
/// <code>&lt;DIVIDE&gt;</code> instead. <code>User</code> refuses a new password containing the
/// account's name, which the instance passes in lower case, with
/// <parameter>USERREFUSALSENTENCE</parameter>.</p>
Parameter VALIDATIONROUTINE = "OcuPilotPwProbe";

/// <p>What a new password carries for the probe routine to refuse it.</p>
Parameter REFUSEDMARKER = "OcuRefuse";

/// <p>The sentence <code>Refuse</code> answers, and the oracle the routine leg asserts.</p>
Parameter REFUSALSENTENCE = "Passwords on this instance may not carry the probe marker.";

/// <p>The sentence <code>User</code> answers, the oracle for the account name the validator is
/// given.</p>
Parameter USERREFUSALSENTENCE = "Passwords on this instance may not contain the account name.";

/// <p>The account's password as it stands right now: the generated one until the happy-path leg
/// changes it, the replacement afterwards.</p>
Property PreparedPassword As %String;

/// <p>The instance's <code>PasswordValidationRoutine</code> as <method>OnBeforeAllTests</method>
/// read it, which every teardown restores.</p>
Property PreparedValidationRoutine As %String;

/// <p>The replacement the happy-path leg sets, generated for the run.</p>
Property PreparedNextPassword As %String;

/// <p>Whether <method>OnBeforeAllTests</method> read back that the account holds the pairs it is
/// meant to.</p>
Property PreparedSetupOk As %Boolean [ InitialExpression = 0 ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Set ..PreparedNextPassword = ""
    Set ..PreparedSetupOk = 0
    Set ..PreparedValidationRoutine = ""
    Quit $$$OK
}

/// <p>Refuse to run at all unless this instance is armed for throwaway principals, then create the
/// one account and role this class changes the password of.</p>
Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AccountPasswordWire creates an IRIS user and role and changes that user's password, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so no principal was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tInstallNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()
        Set ..PreparedPassword = ..GeneratePassword()
        Set ..PreparedNextPassword = ..GeneratePassword()

        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit

        Set tNsObj = ##class(Config.Namespaces).Open(tInstallNs)
        If '$IsObject(tNsObj) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open namespace configuration for " _ tInstallNs)
            Quit
        }
        Set tDbObj = ##class(Config.Databases).Open(tNsObj.Routines)
        If '$IsObject(tDbObj) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open the routine database " _ tNsObj.Routines)
            Quit
        }
        Set tSysDb = ##class(SYS.Database).%OpenId(tDbObj.Directory)
        If '$IsObject(tSysDb) {
            Set tSC = $$$ERROR($$$GeneralError, "Could not open SYS.Database for the routine database directory")
            Quit
        }

        Set tSC = ..EnsurePrincipal(tSysDb.ResourceName _ ":R,%Admin_Operate:U")
        If $$$ISERR(tSC) Quit

        Set tSC = ##class(Security.System).Get("SYSTEM", .tSystem)
        If $$$ISERR(tSC) Quit
        Set ..PreparedValidationRoutine = $Get(tSystem("PasswordValidationRoutine"))
        ; A probe an interrupted run left configured is not the instance's own setting.
        If $Piece(..PreparedValidationRoutine, "^", 2) = ..#VALIDATIONROUTINE Set ..PreparedValidationRoutine = ""
        Do ..RemoveValidationProbe()

        Set ..PreparedSetupOk = ($SYSTEM.Security.CheckUserPermission(..#PROBEUSER, "%Admin_Operate", "USE") = 1)
        If '..PreparedSetupOk {
            Set tSC = $$$ERROR($$$GeneralError, "Setup could not confirm the probe principal's %Admin_Operate:USE")
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove the account and its role, and <b>return a failing status</b> if either survives.</p>
Method OnAfterAllTests() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tLeft = ""
        If ##class(Security.Users).Exists(..#PROBEUSER, .tU, .tUS) Do ##class(Security.Users).Delete(..#PROBEUSER)
        If ##class(Security.Users).Exists(..#PROBEUSER, .tU2, .tUS2) Set tLeft = "user " _ ..#PROBEUSER
        If ##class(Security.Roles).Exists(..#PROBEROLE, .tR, .tRS) Do ##class(Security.Roles).Delete(..#PROBEROLE)
        If ##class(Security.Roles).Exists(..#PROBEROLE, .tR2, .tRS2) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: ", ") _ "role " _ ..#PROBEROLE
        If tLeft '= "" {
            Set tSC = $$$ERROR($$$GeneralError, "OcuPilot.Test.AccountPasswordWire teardown left throwaway objects on the instance: " _ tLeft)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Restore the validation routine setting and delete the probe routine whatever a method did,
/// and fail this teardown rather than a later class when either survives. The assertion is on the
/// reading taken before the repair: the routine leg removes its probe itself, so a leftover here
/// says that removal did not run.</p>
Method OnAfterOneTest() As %Status
{
    Set tBefore = ..ValidationProbeLeft()
    Do ..RemoveValidationProbe()
    Set tAfter = ..ValidationProbeLeft()
    Do $$$AssertEquals(tBefore, "", "the method removed its validation probe itself, so this teardown had nothing to repair")
    If tAfter '= "" Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.AccountPasswordWire teardown left " _ tAfter _ " on this instance")
    Quit $$$OK
}

/// <p>Install <parameter>VALIDATIONROUTINE</parameter> in <code>%SYS</code>, compiled.</p>
Method InstallValidationRoutine() As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Set tMarker = ..#REFUSEDMARKER
        Set tRoutine = ##class(%Routine).%New(..#VALIDATIONROUTINE _ ".INT")
        Do tRoutine.WriteLine(..#VALIDATIONROUTINE _ " ; OcuPilot.Test.AccountPasswordWire: a throwaway password validation routine")
        Do tRoutine.WriteLine("Refuse(Username,Password) PUBLIC {")
        Do tRoutine.WriteLine(" If Password [ """ _ tMarker _ """ Quit $System.Status.Error(5001,""" _ ..#REFUSALSENTENCE _ """)")
        Do tRoutine.WriteLine(" Quit 1")
        Do tRoutine.WriteLine("}")
        Do tRoutine.WriteLine("Quote(Username,Password) PUBLIC {")
        Do tRoutine.WriteLine(" If Password [ """ _ tMarker _ """ Quit $System.Status.Error(5001,""The password ""_Password_"" is refused here."")")
        Do tRoutine.WriteLine(" Quit 1")
        Do tRoutine.WriteLine("}")
        Do tRoutine.WriteLine("Empty(Username,Password) PUBLIC {")
        Do tRoutine.WriteLine(" If Password [ """ _ tMarker _ """ Quit $System.Status.Error(5001,"""")")
        Do tRoutine.WriteLine(" Quit 1")
        Do tRoutine.WriteLine("}")
        Do tRoutine.WriteLine("Boom(Username,Password) PUBLIC {")
        Do tRoutine.WriteLine(" If Password [ """ _ tMarker _ """ Set x = 1/0")
        Do tRoutine.WriteLine(" Quit 1")
        Do tRoutine.WriteLine("}")
        Do tRoutine.WriteLine("Pattern(Username,Password) PUBLIC {")
        Do tRoutine.WriteLine(" If Password [ """ _ tMarker _ """ Quit $System.Status.Error(958,Password)")
        Do tRoutine.WriteLine(" Quit 1")
        Do tRoutine.WriteLine("}")
        Do tRoutine.WriteLine("Both(Username,Password) PUBLIC {")
        Do tRoutine.WriteLine(" If Password [ """ _ tMarker _ """ Quit $System.Status.AppendStatus($System.Status.Error(5002,""OcuProbeInternal""),$System.Status.Error(5001,""" _ ..#REFUSALSENTENCE _ """))")
        Do tRoutine.WriteLine(" Quit 1")
        Do tRoutine.WriteLine("}")
        Do tRoutine.WriteLine("User(Username,Password) PUBLIC {")
        Do tRoutine.WriteLine(" If $ZConvert(Password,""L"") [ Username Quit $System.Status.Error(5001,""" _ ..#USERREFUSALSENTENCE _ """)")
        Do tRoutine.WriteLine(" Quit 1")
        Do tRoutine.WriteLine("}")
        Set tSC = tRoutine.Save()
        If $$$ISERR(tSC) Quit
        Set tSC = tRoutine.Compile("-d")
        Set tRoutine = ""
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Make entry point <var>pTag</var> of <parameter>VALIDATIONROUTINE</parameter> the instance's
/// password validation routine.</p>
Method UseValidationEntry(pTag As %String) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) Quit
        Kill tProps
        Set tProps("PasswordValidationRoutine") = pTag _ "^" _ ..#VALIDATIONROUTINE
        Set tSC = ##class(Security.System).Modify("SYSTEM", .tProps)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Restore <property>PreparedValidationRoutine</property>, then delete
/// <parameter>VALIDATIONROUTINE</parameter>, each only when it is needed. The setting goes first, so
/// no password change meets a validation routine that is gone. <method>ValidationProbeLeft</method>
/// reads the outcome back.</p>
Method RemoveValidationProbe()
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISOK(tSC) {
            Kill tSystem
            Set tGetSC = ##class(Security.System).Get("SYSTEM", .tSystem)
            If $$$ISERR(tGetSC) || ($Get(tSystem("PasswordValidationRoutine")) '= ..PreparedValidationRoutine) {
                Kill tProps
                Set tProps("PasswordValidationRoutine") = ..PreparedValidationRoutine
                Set tModifySC = ##class(Security.System).Modify("SYSTEM", .tProps)
            }
            If ##class(%Routine).Exists(..#VALIDATIONROUTINE) Set tDeleteSC = ##class(%Routine).Delete(..#VALIDATIONROUTINE _ ".INT", 0, 1)
        }
    } Catch ex {
        Set $NAMESPACE = tOrigNS
    }
    Set $NAMESPACE = tOrigNS
}

/// <p>What of the validation probe is still on the instance -- the setting when it differs from
/// <property>PreparedValidationRoutine</property> or cannot be read, and the routine when it
/// exists -- or <code>""</code> when neither.</p>
Method ValidationProbeLeft() As %String
{
    Set tLeft = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set tSC = ##class(OcuPilot.Kernel.Utils).SwitchNamespace("%SYS", .tOrigNS)
        If $$$ISERR(tSC) {
            Set tLeft = "a validation probe this teardown could not read"
            Quit
        }
        Kill tSystem
        Set tGetSC = ##class(Security.System).Get("SYSTEM", .tSystem)
        If $$$ISERR(tGetSC) || ($Get(tSystem("PasswordValidationRoutine")) '= ..PreparedValidationRoutine) Set tLeft = "the PasswordValidationRoutine setting"
        If ##class(%Routine).Exists(..#VALIDATIONROUTINE) Set tLeft = tLeft _ $Select(tLeft = "": "", 1: " and ") _ "routine " _ ..#VALIDATIONROUTINE
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tLeft = "a validation probe this teardown could not read"
    }
    Set $NAMESPACE = tOrigNS
    Quit tLeft
}

/// <p>A password for this run, generated rather than written down, and long enough for any
/// plausible pattern.</p>
ClassMethod GeneratePassword() As %String
{
    Quit "OcuAcct" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "9Zq"
}

/// <p>Create (or re-grant) the throwaway role and the account that holds it.
/// <b>Caller contract:</b> <code>$NAMESPACE</code> must already be <code>%SYS</code>.</p>
Method EnsurePrincipal(pResources As %String) As %Status
{
    Set tSC = $$$OK
    If ##class(Security.Roles).Exists(..#PROBEROLE, .tR, .tRS) {
        Set tModProps("Resources") = pResources
        Set tModProps("GrantedRoles") = ""
        Set tModProps("ForceSave") = 2
        Set tSC = ##class(Security.Roles).Modify(..#PROBEROLE, .tModProps)
    } Else {
        Set tSC = ##class(Security.Roles).Create(..#PROBEROLE, "OcuPilot test: account password principal role (throwaway)", pResources, "")
    }
    If $$$ISERR(tSC) Quit tSC
    If ##class(Security.Users).Exists(..#PROBEUSER, .tU, .tUS) {
        Set tSC = ##class(Security.Users).Delete(..#PROBEUSER)
        If $$$ISERR(tSC) Quit tSC
    }
    Quit ##class(Security.Users).Create(..#PROBEUSER, ..#PROBEROLE, ..PreparedPassword, "OcuPilot account password test principal (throwaway)", "", "", "", 0, 1, "Created by OcuPilot.Test.AccountPasswordWire; deleted in OnAfterAllTests")
}

/// <p>One <code>POST</code> to the route as the probe account, with <var>pBody</var> sent verbatim
/// as <code>application/json</code>.</p>
Method Post(pBody As %String, Output pStatus As %Integer, Output pBodyText As %String, Output pHeaders) As %Status
{
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", ..#PASSWORDPATH, ..#PROBEUSER, ..PreparedPassword, .pStatus, .pBodyText, .pHeaders, pBody, "application/json")
}

/// <p>The JSON body for a change request. Built here so no test method spells the two member
/// names twice.</p>
ClassMethod Payload(pCurrent As %String, pNew As %String) As %String
{
    Set tBody = {}
    Do tBody.%Set("currentPassword", pCurrent, "string")
    Do tBody.%Set("newPassword", pNew, "string")
    Quit tBody.%ToJSON()
}

/// <p>AC5 -- a wrong current password is a <b>422 violation on
/// <code>currentPassword</code></b>, never a 401.</p>
/// <p>Mutation: change <parameter>OcuPilot.Api.Account.WRONGPASSWORDCODE</parameter> from 952 to
/// 953 -&gt; the refusal falls through to the 500 arm and every assertion below goes red.</p>
Method TestAWrongCurrentPasswordIsAViolationOnThatField()
{
    Do $$$AssertTrue(..PreparedSetupOk, "the probe principal was prepared")
    Set tSC = ..Post(..Payload("NotTheCurrentPassword9Z", ..PreparedNextPassword), .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 422, "the change is refused as a validation failure, not a 401")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    Set tFault = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tFault.error, "validation_failed", "on the validation slug")
    Do $$$AssertEquals(tFault.code, "ACCOUNT.VALIDATION", "and this route's own envelope code")
    Do $$$AssertTrue($IsObject(tFault.detail), "carrying a detail object")
    If '$IsObject(tFault.detail) Quit
    Do $$$AssertEquals(tFault.detail.violations.%Size(), 1, "with one violation")
    Set tViolation = tFault.detail.violations.%Get(0)
    Do $$$AssertEquals(tViolation.field, "currentPassword", "on the field the caller can correct")
    Do $$$AssertEquals(tViolation.code, "ACCOUNT.PASSWORD.CURRENT", "with the published code")
    Do $$$AssertEquals(tViolation.reason, ##class(OcuPilot.Api.Error).#REASONACCOUNTPASSWORDCURRENT, "and the sentence written once on the server")
    Do $$$AssertEquals((tBody [ ..PreparedNextPassword), 0, "and no password value is anywhere in the response")
}

/// <p>AC4 -- a new password this instance's policy refuses is a 422 violation on
/// <code>newPassword</code> carrying <b>the instance's own text</b>.</p>
/// <p>Needs nothing of the instance beyond its shipped <code>PasswordPattern</code>: a
/// two-character password is shorter than the three <code>3.255ANP</code> admits.</p>
/// <p>Mutation: drop <code>845</code> from
/// <parameter>OcuPilot.Api.Account.POLICYCODES</parameter> -&gt; the refusal falls through to the
/// 500 arm and every assertion below goes red.</p>
Method TestAPolicyRefusalCarriesTheInstancesOwnText()
{
    Do $$$AssertTrue(..PreparedSetupOk, "the probe principal was prepared")
    Set tSC = ..Post(..Payload(..PreparedPassword, ..#TOOSHORTPASSWORD), .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 422, "the policy refusal is a validation failure")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    Set tFault = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tFault.code, "ACCOUNT.VALIDATION", "on this route's envelope code")
    Do $$$AssertTrue($IsObject(tFault.detail), "carrying a detail object")
    If '$IsObject(tFault.detail) Quit
    Do $$$AssertEquals(tFault.detail.violations.%Size(), 1, "with one violation")
    Set tViolation = tFault.detail.violations.%Get(0)
    Do $$$AssertEquals(tViolation.field, "newPassword", "on the field that was refused")
    Do $$$AssertEquals(tViolation.code, "ACCOUNT.PASSWORD.POLICY", "with the published code")
    ; The instance's own sentence, not OcuPilot's fallback: the same words $System.Security
    ; reports for this build's pattern, taken from a status raised here rather than transcribed.
    Set tProbe = $System.Security.ChangePassword(..#PROBEUSER, ..#TOOSHORTPASSWORD, ..PreparedPassword, .tProbeSC)
    Do $$$AssertEquals(tProbe, 0, "the probe call is refused too, so its status is the same refusal")
    Do $$$AssertEquals(tViolation.reason, $System.Status.GetOneStatusText(tProbeSC, 2), "and the instance's own policy sentence")
    Do $$$AssertNotEquals(tViolation.reason, ##class(OcuPilot.Api.Error).#REASONACCOUNTPASSWORDPOLICY, "rather than OcuPilot's fallback wording")
    Do $$$AssertEquals((tBody [ ..PreparedPassword), 0, "and no password value is anywhere in the response")
}

/// <p>A new password the instance's password validation routine refuses is a 422 violation on
/// <code>newPassword</code> carrying <b>the routine's own sentence</b>
/// (<parameter>REFUSALSENTENCE</parameter>, the oracle). A routine whose sentence quotes the password,
/// or that gives none, has it replaced by the published one, and so does a 958 whose text quotes
/// it; a wrong current password is still answered on <code>currentPassword</code> with the
/// routine configured, and a routine that reads the account name refuses the same password when
/// the validator asks. A routine that raises an error, or leads its refusal with another error,
/// confirms no refusal: the change is a 500 naming neither the error nor the routine.</p>
/// <p>Needs <code>%SYS</code> write for the routine and the setting, which the arming variable
/// keeps to a throwaway.</p>
/// <p>Mutation (Rule 19): delete the <method>%SYSTEM.Security.ValidatePassword</method> arm from
/// <method>OcuPilot.Api.Account.ClassifyRefusal</method> -&gt; the refusals answer 500 and this goes
/// red. Call the validator without the account name -&gt; the account-name leg answers 500. Accept
/// a refusal code anywhere in the validator's status -&gt; the composed-status leg answers 422 with
/// the other error's text. Drop the policy arm's quote check -&gt; the pattern leg renders the
/// password.</p>
Method TestAValidationRoutineRefusalCarriesTheRoutinesSentence()
{
    Do $$$AssertTrue(..PreparedSetupOk, "the probe principal was prepared")
    Set tRefused = ..#REFUSEDMARKER _ ..GeneratePassword()
    Try {
        Set tSC = ..InstallValidationRoutine()
        Do $$$AssertStatusOK(tSC, "the probe routine is installed")
        If $$$ISERR(tSC) Quit
        Set tSC = ..UseValidationEntry("Refuse")
        Do $$$AssertStatusOK(tSC, "and set as the instance's password validation routine")
        If $$$ISERR(tSC) Quit

        Set tSC = ..Post(..Payload(..PreparedPassword, tRefused), .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, "the request completes")
        Do ..AssertNewPasswordRefusal(tStatus, tBody, .tHeaders, ..#REFUSALSENTENCE, "the routine's own sentence")
        Do $$$AssertEquals((tBody [ tRefused), 0, "and no password value is anywhere in the response")

        Set tSC = ..Post(..Payload("NotTheCurrentPassword9Z", tRefused), .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, "the wrong-current request completes")
        Do $$$AssertEquals(tStatus, 422, "a wrong current password is refused as a validation failure with the routine configured")
        Set tFault = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tFault.detail.violations.%Get(0).field, "currentPassword", "and on the current password, which the instance checks first")

        Set tSC = ..UseValidationEntry("Quote")
        Do $$$AssertStatusOK(tSC, "the quoting entry point is set")
        If $$$ISERR(tSC) Quit
        Set tSC = ..Post(..Payload(..PreparedPassword, tRefused), .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, "the quoted-refusal request completes")
        Do ..AssertNewPasswordRefusal(tStatus, tBody, .tHeaders, ##class(OcuPilot.Api.Error).#REASONACCOUNTPASSWORDPOLICY, "the published sentence, because the routine's quotes the password")
        Do $$$AssertEquals((tBody [ tRefused), 0, "and the quoted password is nowhere in the response")

        Set tSC = ..UseValidationEntry("Empty")
        Do $$$AssertStatusOK(tSC, "the empty-sentence entry point is set")
        If $$$ISERR(tSC) Quit
        Set tSC = ..Post(..Payload(..PreparedPassword, tRefused), .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, "the empty-sentence request completes")
        Do ..AssertNewPasswordRefusal(tStatus, tBody, .tHeaders, ##class(OcuPilot.Api.Error).#REASONACCOUNTPASSWORDPOLICY, "the published sentence, because the routine gave none")

        ; The instance hands the routine the account's name, so the validator's reading of the
        ; same password must be given it too.
        Set tSC = ..UseValidationEntry("User")
        Do $$$AssertStatusOK(tSC, "the account-name entry point is set")
        If $$$ISERR(tSC) Quit
        Set tSC = ..Post(..Payload(..PreparedPassword, ..#PROBEUSER _ ..GeneratePassword()), .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, "the account-name request completes")
        Do ..AssertNewPasswordRefusal(tStatus, tBody, .tHeaders, ..#USERREFUSALSENTENCE, "the sentence of a routine that reads the account name")

        Set tSC = ..UseValidationEntry("Pattern")
        Do $$$AssertStatusOK(tSC, "the pattern entry point is set")
        If $$$ISERR(tSC) Quit
        Set tSC = ..Post(..Payload(..PreparedPassword, tRefused), .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, "the pattern-refusal request completes")
        Do ..AssertNewPasswordRefusal(tStatus, tBody, .tHeaders, ##class(OcuPilot.Api.Error).#REASONACCOUNTPASSWORDPOLICY, "the published sentence, because the policy code's text quotes the password")
        Do $$$AssertEquals((tBody [ tRefused), 0, "and the quoted password is nowhere in the response")

        ; A status the routine composes confirms a refusal only when the refusal comes first, so
        ; the error ahead of it never reaches the wire.
        Set tSC = ..UseValidationEntry("Both")
        Do $$$AssertStatusOK(tSC, "the composed-status entry point is set")
        If $$$ISERR(tSC) Quit
        Set tSC = ..Post(..Payload(..PreparedPassword, tRefused), .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, "the composed-status request completes")
        Do $$$AssertEquals(tStatus, 500, "a refusal behind another error is an internal error")
        Do $$$AssertEquals((tBody [ "OcuProbeInternal"), 0, "whose body carries neither error's text: " _ tBody)

        ; A routine that raises an error has refused nothing: its error names the routine's own
        ; line, which neither the classifier nor the wire may carry.
        Set tSC = ..UseValidationEntry("Boom")
        Do $$$AssertStatusOK(tSC, "the raising entry point is set")
        If $$$ISERR(tSC) Quit
        Set tUnconfirmed = $System.Status.AppendStatus($System.Status.Error(1446), $System.Status.Error(5001, "refused"))
        Set tHttp = ##class(OcuPilot.Api.Account).ClassifyRefusal(tUnconfirmed, ..PreparedPassword, tRefused, ..#PROBEUSER, .tField, .tCode, .tReason, .tLogged)
        Do $$$AssertEquals(tHttp _ "|" _ tReason, "500|", "a validator that raised an error confirms no refusal, and no reason carries its text")
        Set tSC = ..Post(..Payload(..PreparedPassword, tRefused), .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, "the raising-routine request completes")
        Do $$$AssertEquals(tStatus, 500, "a change the routine's error stopped is an internal error")
        Do $$$AssertEquals((tBody [ "DIVIDE") || (tBody [ ..#VALIDATIONROUTINE), 0, "whose body names neither the error nor the routine: " _ tBody)
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the routine leg ran without raising")
    }
    Do ..RemoveValidationProbe()
    Do $$$AssertEquals(..ValidationProbeLeft(), "", "the leg restored the setting and deleted its routine")
}

/// <p>A refusal the password validator does not confirm stays a 500 whose logged status is the
/// change's own, and one naming an account the change could not find is a 500 whatever the
/// validator would say. A logged status that quotes a password is replaced, and so is a validator
/// sentence that contains the current password.</p>
/// <p>Runs <method>OcuPilot.Api.Account.ClassifyRefusal</method> over constructed statuses and needs
/// no validation routine: the validator admits the generated password under this build's shipped
/// pattern and refuses <parameter>TOOSHORTPASSWORD</parameter>.</p>
/// <p>Mutation (Rule 19): drop the <parameter>OcuPilot.Api.Account.NOSUCHUSERCODE</parameter>
/// test from <method>OcuPilot.Api.Account.ClassifyRefusal</method> -&gt; the validator refuses the
/// two-character password, the 838 leg answers 422 and goes red.</p>
Method TestAnUnconfirmedRefusalStaysAnInternalError()
{
    Set tNew = ..GeneratePassword()
    Set tUnconfirmed = $System.Status.AppendStatus($System.Status.Error(1446), $System.Status.Error(5001, "refused by a routine the validator does not agree with"))
    Do $$$AssertEquals($System.Status.GetErrorCodes(tUnconfirmed), "1446,5001", "the constructed refusal carries the codes a routine's refusal carries")
    Set tHttp = ##class(OcuPilot.Api.Account).ClassifyRefusal(tUnconfirmed, ..PreparedPassword, tNew, ..#PROBEUSER, .tField, .tCode, .tReason, .tLogged)
    Do $$$AssertEquals(tHttp, 500, "a 5001 the validator does not confirm stays a 500")
    Do $$$AssertEquals(tField _ tCode _ tReason, "", "with no violation")
    Do $$$AssertEquals($System.Status.GetErrorText(tLogged), $System.Status.GetErrorText(tUnconfirmed), "and the change's own status is what the log receives")

    Set tQuoting = $System.Status.AppendStatus($System.Status.Error(1446), $System.Status.Error(5001, "the password " _ tNew _ " is refused"))
    Set tHttp = ##class(OcuPilot.Api.Account).ClassifyRefusal(tQuoting, ..PreparedPassword, tNew, ..#PROBEUSER, .tField, .tCode, .tReason, .tLogged)
    Do $$$AssertEquals(tHttp, 500, "an unconfirmed refusal that quotes the password stays a 500")
    Do $$$AssertEquals(($System.Status.GetErrorText(tLogged) [ tNew), 0, "and its logged status no longer carries the password")

    Set tNoUser = $System.Status.AppendStatus($System.Status.Error(1446), $System.Status.Error(838, ..#PROBEUSER))
    Set tHttp = ##class(OcuPilot.Api.Account).ClassifyRefusal(tNoUser, ..PreparedPassword, ..#TOOSHORTPASSWORD, ..#PROBEUSER, .tField, .tCode, .tReason, .tLogged)
    Do $$$AssertEquals(tHttp, 500, "an account the change could not find is a 500, though the validator refuses this password")

    ; The validator's own sentence for the two-character password, then that sentence with a
    ; current password it happens to contain: the fallback replaces it.
    Set tHttp = ##class(OcuPilot.Api.Account).ClassifyRefusal(tUnconfirmed, "", ..#TOOSHORTPASSWORD, ..#PROBEUSER, .tField, .tCode, .tReason, .tLogged)
    Do $$$AssertEquals(tHttp _ "|" _ tField, "422|newPassword", "the validator refuses the two-character password on the new password")
    Set tSentence = tReason
    Do $$$AssertTrue($Length(tSentence) > 12, "with a sentence of its own: " _ tSentence)
    Set tHttp = ##class(OcuPilot.Api.Account).ClassifyRefusal(tUnconfirmed, $Extract(tSentence, 1, 12), ..#TOOSHORTPASSWORD, ..#PROBEUSER, .tField, .tCode, .tReason, .tLogged)
    Do $$$AssertEquals(tHttp _ "|" _ tReason, "422|", "a sentence containing the current password gives way to the published one")
}

/// <p>Assert one answer is a 422 <code>ACCOUNT.VALIDATION</code> with one
/// <code>newPassword</code> violation whose reason is <var>pReason</var>.</p>
Method AssertNewPasswordRefusal(pStatus As %Integer, pBody As %String, ByRef pHeaders, pReason As %String, pWhat As %String)
{
    Do $$$AssertEquals(pStatus, 422, "the refusal is a validation failure")
    Do $$$AssertTrue($Get(pHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((pBody [ "}{"), 0, "exactly one envelope")
    If pStatus '= 422 Quit
    Set tFault = ##class(%DynamicObject).%FromJSON(pBody)
    Do $$$AssertEquals(tFault.code, "ACCOUNT.VALIDATION", "on this route's envelope code")
    Do $$$AssertTrue($IsObject(tFault.detail), "carrying a detail object")
    If '$IsObject(tFault.detail) Quit
    Do $$$AssertEquals(tFault.detail.violations.%Size(), 1, "with one violation")
    Set tViolation = tFault.detail.violations.%Get(0)
    Do $$$AssertEquals(tViolation.field, "newPassword", "on the field that was refused")
    Do $$$AssertEquals(tViolation.code, "ACCOUNT.PASSWORD.POLICY", "with the published code")
    Do $$$AssertEquals(tViolation.reason, pReason, "and " _ pWhat)
}

/// <p>AC-matrix "Malformed body" -- a body that is not exactly the two string members is one 422
/// naming the two members and no value, before anything is attempted.</p>
/// <p>Mutation: delete the <code>tExtra</code> test from
/// <method>OcuPilot.Api.Account.HandlePasswordChange</method> -&gt; the extra-member leg goes
/// red.</p>
Method TestAMalformedBodyIsOneRefusalNamingNoValue()
{
    Do $$$AssertTrue(..PreparedSetupOk, "the probe principal was prepared")
    Set tBodies = $ListBuild("not json at all", "[]", "{}", "{""currentPassword"":""x""}", "{""currentPassword"":""x"",""newPassword"":1}", "{""currentPassword"":""x"",""newPassword"":""y"",""userName"":""_SYSTEM""}")
    For tI = 1:1:$ListLength(tBodies) {
        Set tSent = $List(tBodies, tI)
        Set tSC = ..Post(tSent, .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, "the request completes: " _ tSent)
        Do $$$AssertEquals(tStatus, 422, "refused: " _ tSent)
        Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json: " _ tSent)
        Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope: " _ tSent)
        Set tFault = ##class(%DynamicObject).%FromJSON(tBody)
        Do $$$AssertEquals(tFault.error, "validation_failed", "on the validation slug: " _ tSent)
        Do $$$AssertEquals(tFault.code, "ACCOUNT.PASSWORD.BODY", "with the body code: " _ tSent)
        Do $$$AssertEquals(tFault.reason, ##class(OcuPilot.Api.Error).#REASONACCOUNTPASSWORDBODY, "and the published sentence: " _ tSent)
        Do $$$AssertEquals(tFault.%IsDefined("detail"), 0, "and no violations list, because no field was reached: " _ tSent)
    }
}

/// <p>AC2, AC3 -- a correct change answers <code>200 {}</code>, the new password authenticates,
/// the old one no longer does, and the account is still authorized for the next API call.</p>
/// <p>Runs last by name, because it replaces the password every other method here signs in
/// with; <method>Post</method> reads <property>PreparedPassword</property>, which this method
/// moves only after the change has landed.</p>
/// <p>Mutation: make <method>OcuPilot.Api.Account.HandlePasswordChange</method> pass
/// <code>tCurrent</code> as the new password -&gt; the new password no longer authenticates and
/// this goes red.</p>
Method TestZCorrectChangeSucceedsAndLeavesTheAccountAuthorized()
{
    Do $$$AssertTrue(..PreparedSetupOk, "the probe principal was prepared")
    Set tOld = ..PreparedPassword
    Set tSC = ..Post(..Payload(tOld, ..PreparedNextPassword), .tStatus, .tBody, .tHeaders)
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 200, "the change is applied")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Set tAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tAnswer.%ToJSON(), "{}", "answering an empty object and nothing about the account")
    If tStatus = 200 Set ..PreparedPassword = ..PreparedNextPassword

    ; The change really moved: the new password reaches an ordinary read, the old one does not.
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", ..#INSTANCEPATH, ..#PROBEUSER, ..PreparedNextPassword, .tNewStatus, .tNewBody, .tNewHeaders)
    Do $$$AssertStatusOK(tSC, "the follow-up request completes")
    Do $$$AssertEquals(tNewStatus, 200, "the account is still authorized with the new password")
    Do $$$AssertTrue($Get(tNewHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Set tInstance = ##class(%DynamicObject).%FromJSON(tNewBody)
    Do $$$AssertNotEquals(tInstance.%GetTypeOf("instanceVersion"), "unassigned", "and the read answers its own body shape")

    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", ..#INSTANCEPATH, ..#PROBEUSER, tOld, .tOldStatus, .tOldBody, .tOldHeaders)
    Do $$$AssertStatusOK(tSC, "the stale-credential request completes")
    Do $$$AssertEquals(tOldStatus, 401, "and the old password no longer authenticates")
}

}
