/// <p>The three user-create routes over the wire (AD-12, AD-35, AD-39, AD-55): the form's bootstrap
/// read, the name look-up and the create, and the port's wrapper against the vendor itself.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, an account holding
/// the screen's own pairs, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code> --
/// because the create leg creates a real account. <method>OnBeforeAllTests</method> refuses anywhere
/// it does not, and refuses to adopt a probe name the instance already holds;
/// <method>OnAfterOneTest</method> deletes the probe names by exact name, never by prefix.</p>
Class OcuPilot.Test.UserCreateWire Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file>
/// alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter FORMPATH = "/users/form";

Parameter NAMEPATH = "/users/name";

Parameter CREATEPATH = "/users";

/// <p>The account the create leg makes, and the one the port legs name and never create.</p>
Parameter PROBEUSER = "ocupilotprobeuserwire";

Parameter PORTPROBE = "ocupilotprobeuserport";

/// <p>A password that meets this build's policy and appears nowhere else.</p>
Parameter PROBEPASSWORD = "Ocu8Wire-Secret";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.UserCreateWire creates and deletes an account on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    If ..Exists(..#PROBEUSER) || ..Exists(..#PORTPROBE) {
        Quit $$$ERROR($$$GeneralError, "a probe account of OcuPilot.Test.UserCreateWire already exists on this instance, and this class deletes what it creates -- it will not adopt one it did not make.")
    }
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..Remove(..#PROBEUSER)
    Do ..Remove(..#PORTPROBE)
    Do $$$AssertEquals(..Exists(..#PROBEUSER) + ..Exists(..#PORTPROBE), 0, "the probe accounts are gone")
    Quit $$$OK
}

/// <p><code>GET /users/form</code> publishes the rules with the server's own sentences, and the
/// roles with the privileged ones pre-marked by the sentence the refusal carries.</p>
/// <p>Mutation: make <method>OcuPilot.Kernel.Proposal.Prohibited.RoleGrantsAdministrativePrivilege</method>
/// answer 0 -> the pre-mark assertions go red.</p>
Method TestTheFormReadPublishesTheRulesAndMarksThePrivilegedRoles()
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#FORMPATH, .tStatus, .tBody)
    Do $$$AssertStatusOK(tSC, "the form read answers")
    Do $$$AssertEquals(tStatus, 200, "at 200")
    If '$IsObject($Get(tBody)) Quit
    Do $$$AssertEquals(tBody.%Get("rolesReason"), ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor($Parameter("OcuPilot.Kernel.Proposal.Prohibited", "PRIVILEGEGRANT")), "it ships the Roles sentence")
    Do $$$AssertTrue(tBody.%Get("requiredFields").%Size() = 2, "and the two required fields")
    Set tIterator = tBody.%Get("rules").%GetIterator()
    Set tRules = 0
    While tIterator.%GetNext(.tIndex, .tRule) {
        Set tRules = tRules + 1
        Do $$$AssertEquals(tRule.%Get("reason"), ##class(OcuPilot.Api.Error).ReasonForViolation(tRule.%Get("code")), "the rule on " _ tRule.%Get("field") _ " carries the server's sentence")
    }
    Do $$$AssertTrue(tRules > 0, "it publishes rules")
    Kill tMarked
    Set tIterator = tBody.%Get("roles").%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRole) {
        Set tMarked(tRole.%Get("name")) = tRole.%Get("privileged")
    }
    Do $$$AssertEquals($Get(tMarked("%All"), "absent"), 1, "%All is pre-marked")
    Do $$$AssertEquals($Get(tMarked("%Manager"), "absent"), 1, "and %Manager, which carries an administrative resource")
    Do $$$AssertEquals($Get(tMarked("%Developer"), "absent"), 0, "and an ordinary role is not")
}

/// <p><code>POST /users</code> creates the account with the sent fields, the name look-up then
/// reads it as taken, and neither the Users read nor the vendor's <code>GET</code> carries the
/// password.</p>
/// <p>Mutation: remove <code>Security.User/POST</code> from
/// <parameter>OcuPilot.Port.AdminPort.WRAPPEDTYPES</parameter> -> the vendor refuses the flat body
/// and the create leg goes red.</p>
Method TestTheCreateMakesTheAccountAndNoReadCarriesThePassword()
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#NAMEPATH _ "?name=" _ ..#PROBEUSER, .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the name look-up answers")
    If $IsObject($Get(tBody)) Do $$$AssertEquals(tBody.%Get("available"), 1, "and the probe name is free")

    Set tRequest = {"Name": (..#PROBEUSER), "Password": (..#PROBEPASSWORD), "FullName": "OcuPilot wire probe", "NameSpace": ($Namespace), "Roles": ["%Developer"]}
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tBody, tRequest.%ToJSON(), "application/json")
    Do $$$AssertStatusOK(tSC, "the create answers")
    Do $$$AssertEquals(tStatus, 201, "at 201")
    If tStatus '= 201 Quit
    Do $$$AssertEquals(..Exists(..#PROBEUSER), 1, "and the instance holds the account")
    Do $$$AssertEquals(..Property(..#PROBEUSER, "FullName"), "OcuPilot wire probe", "with the full name sent")
    Do $$$AssertTrue(("," _ ..Property(..#PROBEUSER, "Roles") _ ",") [ ",%Developer,", "and the role sent")
    Do $$$AssertTrue('(tBody.%ToJSON() [ ..#PROBEPASSWORD), "the create's own answer does not echo the password")

    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", ..#NAMEPATH _ "?name=" _ $ZConvert(..#PROBEUSER, "U"), .tStatus, .tBody)
    If $IsObject($Get(tBody)) {
        Do $$$AssertEquals(tBody.%Get("available"), 0, "the name is taken now, in any case")
        Do $$$AssertEquals(tBody.%Get("reason"), ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#USERNAMETAKEN), "with the server's sentence")
    }

    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("GET", "/screens/permissions.users/read?maxRows=1000", .tStatus, .tBody)
    Do $$$AssertEquals(tStatus, 200, "the Users read answers")
    If $IsObject($Get(tBody)) {
        Set tText = tBody.%ToJSON()
        Do $$$AssertTrue(tText [ ..#PROBEUSER, "and lists the new account")
        Do $$$AssertTrue('(tText [ ..#PROBEPASSWORD), "and carries no password value")
        Do $$$AssertTrue('(tText [ """Password"":"), "and no Password key")
    }

    Kill tQuery
    Set tQuery("name") = ..#PROBEUSER
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.User", "GET", .tQuery, "", .tRead, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the vendor's GET answers")
    If $IsObject($Get(tRead)) {
        Do $$$AssertEquals(tRead.%GetTypeOf("Password"), "unassigned", "with no Password key")
        Do $$$AssertTrue('(tRead.%ToJSON() [ ..#PROBEPASSWORD), "and no password value")
    }
}

/// <p>A vendor refusal of the wrapped body lands on the flat field the caller sent: the wrapper's
/// <code>User.</code> segment is stripped, and a missing outer password is named as itself. Nothing
/// is created -- the vendor refuses before it runs.</p>
/// <p>Mutation: drop the strip from <method>OcuPilot.Port.AdminPort.Fail</method> -> the first
/// field reads <code>User.OcuPilotNotAField</code> and this goes red.</p>
Method TestAVendorRefusalOfTheWrappedBodyLandsOnTheFlatField()
{
    Kill tQuery
    Set tQuery("name") = ..#PORTPROBE
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.User", "POST", .tQuery, {"Password": (..#PROBEPASSWORD), "OcuPilotNotAField": "x"}, .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "the vendor refuses a field its template does not declare")
    Do $$$AssertEquals(tHttp, 400, "at 400")
    Do $$$AssertEquals(..FirstViolationField(tFault), "OcuPilotNotAField", "on the flat field the caller sent")

    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.User", "POST", .tQuery, {"FullName": "x"}, .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "and refuses a body carrying no password")
    Do $$$AssertEquals(..FirstViolationField(tFault), "Password", "on the password")
    Do $$$AssertEquals(..Exists(..#PORTPROBE), 0, "and neither refusal created an account")
}

/// <p>AD-10 over the wire: a role that grants <code>%All</code> only through its nested roles is
/// refused on the Roles field, and no account is created.</p>
/// <p>Mutation: make <method>OcuPilot.Kernel.Proposal.Prohibited.RoleEscalates</method> ignore
/// the recursed role set -> the nested role passes and this goes red.</p>
Method TestARoleReachingAllThroughItsNestedRolesIsRefused()
{
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).EnsureAllRole(.tCreated)
    Do $$$AssertStatusOK(tSC, "a probe role granting %All through a nested role is created")
    If $$$ISERR(tSC) Quit
    Try {
        Set tRole = $Parameter("OcuPilot.Test.ProposalFixture", "USERALLROLE")
        Set tRequest = {"Name": (..#PROBEUSER), "Password": (..#PROBEPASSWORD), "Roles": [(tRole)]}
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CREATEPATH, .tStatus, .tBody, tRequest.%ToJSON(), "application/json")
        Do $$$AssertEquals(tStatus, 422, "the create is refused at 422")
        If $IsObject($Get(tBody)) {
            Set tRow = tBody.%Get("detail").%Get("violations").%Get(0)
            Do $$$AssertEquals(tRow.%Get("field"), "Roles", "on the Roles field")
            Do $$$AssertEquals(tRow.%Get("code"), $Parameter("OcuPilot.Kernel.Proposal.Prohibited", "PRIVILEGEGRANT"), "as a privilege grant")
            Do $$$AssertEquals(tRow.%Get("reason"), ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor($Parameter("OcuPilot.Kernel.Proposal.Prohibited", "PRIVILEGEGRANT")), "with the server's sentence")
        }
        Do $$$AssertEquals(..Exists(..#PROBEUSER), 0, "and no account was created")
    } Catch ex {
        Do $$$AssertStatusOK(ex.AsStatus(), "the nested-role leg ran")
    }
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveAllRole()
}

/// <p>AD-12: each of the three routes answers exactly one JSON envelope, read with its own headers
/// over a real HTTP request, and a create naming nothing is refused on its own envelope code.</p>
/// <p>Mutation: make <method>OcuPilot.Api.Response.JSON</method> write the body twice -> the
/// one-envelope assertion goes red on both reads.</p>
Method TestEachRouteAnswersOneJsonEnvelopeOverTheWire()
{
    Set tUser = ##class(OcuPilot.Test.Http).GetTestUsername()
    Set tPassword = ##class(OcuPilot.Test.Http).GetTestPassword()
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    For tPath = tBase _ ..#FORMPATH, tBase _ ..#NAMEPATH _ "?name=" _ ..#PROBEUSER {
        Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tPath, tUser, tPassword, .tStatus, .tBody, .tHeaders)
        Do $$$AssertStatusOK(tSC, tPath _ ": the request completes")
        Do $$$AssertEquals(tStatus, 200, tPath _ ": at 200")
        Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", tPath _ ": as application/json")
        Do $$$AssertEquals((tBody [ "}{"), 0, tPath _ ": exactly one envelope")
        Do $$$AssertTrue($IsObject(##class(%DynamicObject).%FromJSON(tBody)), tPath _ ": whose body parses as one object")
    }
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ ..#CREATEPATH, tUser, tPassword, .tStatus, .tBody, .tHeaders, "{}", "application/json")
    Do $$$AssertStatusOK(tSC, "the create request completes")
    Do $$$AssertEquals(tStatus, 422, "a body naming nothing is refused at 422")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals((tBody [ "}{"), 0, "exactly one envelope")
    Set tParsed = ##class(%DynamicObject).%FromJSON(tBody)
    Do $$$AssertEquals(tParsed.code, ##class(OcuPilot.Api.Error).#USERVALIDATION, "with the create's own envelope code")
    Do $$$AssertEquals(..Exists(..#PROBEUSER), 0, "and nothing was created")
}

/// <p>The first <code>detail.violations</code> field <var>pFault</var> carries, or <code>""</code>.</p>
ClassMethod FirstViolationField(pFault As %DynamicObject) As %String
{
    If '$IsObject(pFault) Quit ""
    Set tDetail = pFault.%Get("detail")
    If '$IsObject(tDetail) || '$IsObject(tDetail.%Get("violations")) Quit ""
    Set tRow = tDetail.%Get("violations").%Get(0)
    If '$IsObject(tRow) Quit ""
    Quit tRow.%Get("field")
}

/// <p>Whether the instance holds an account named exactly <var>pName</var>.</p>
ClassMethod Exists(pName As %String) As %Boolean
{
    Set tExists = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tExists = ''##class(Security.Users).Exists(pName)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tExists = 0
    }
    Quit tExists
}

/// <p>Account <var>pName</var>'s property <var>pProperty</var> as <method>Security.Users.Get</method>
/// answers it, or <code>""</code>.</p>
ClassMethod Property(pName As %String, pProperty As %String) As %String
{
    Set tValue = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        If $$$ISOK(##class(Security.Users).Get(pName, .tProps)) Set tValue = $Get(tProps(pProperty))
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
        Set tValue = ""
    }
    Quit tValue
}

/// <p>Delete the account named exactly <var>pName</var>, if there is one.</p>
ClassMethod Remove(pName As %String)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        If ##class(Security.Users).Exists(pName) Do ##class(Security.Users).Delete(pName)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

}
