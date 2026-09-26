/// <p><code>POST /account/password</code> over the wire (Story 15.1, AD-49): the four outcomes the
/// route publishes, each asserted on status, content type and body shape, as a principal that is
/// not the suite's own account.</p>
/// <p><b>It changes a password, so it needs an account of its own.</b> One throwaway user and its
/// role are created in <method>OnBeforeAllTests</method> and deleted in
/// <method>OnAfterAllTests</method>; the role holds read on the install namespace's code database
/// (without which IRIS cannot load the dispatch class for that request) and
/// <code>%Admin_Operate:USE</code> (which clears the API's own administrative gate). Both
/// passwords are generated for the run and never written to source.</p>
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

/// <p>The account's password as it stands right now: the generated one until the happy-path leg
/// changes it, the replacement afterwards.</p>
Property PreparedPassword As %String;

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
