/// <p>Pins Story 18.29's user copy (AD-27, AD-35, AD-55, AD-58): <code>POST /users/copy</code> over a real
/// HTTP request, the copy's refusals and its sources, the copy as a least-privileged principal, the password
/// check route <code>POST /users/password-check</code>, the port's source-changed refusal at the write, and the
/// copy's proposal minted and confirmed as that principal.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving, an account holding
/// <code>%Admin_Secure</code>, and <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because it
/// creates and deletes accounts and roles with the <code>OcuProbe1829</code> prefix. <method>OnBeforeAllTests</method>
/// refuses anywhere it does not. Every account and role it creates is removed by its own test's teardown or by
/// <method>OnAfterAllTests</method>.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.UserCopyPort.SameNames</method> answer 1 for any two
/// arrays -- the source-changed leg reddens.</p>
Class OcuPilot.Test.UserCopy Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

/// <p>The source account every copy in this class takes.</p>
Parameter SOURCE = "OcuProbe1829Src";

/// <p>The copy's target, which each test creates and removes.</p>
Parameter TARGET = "OcuProbe1829Dst";

/// <p>The escalation role the source holds, and the one the copy must carry.</p>
Parameter ESCROLE = "%Operator";

/// <p>The probe principals: one holding exactly the copy's pairs, one holding the code-database reads and no
/// <code>%Admin_Secure</code>. Their roles are named the same way.</p>
Parameter PRINCIPAL = "OcuProbe1829Copier";

Parameter NOGATE = "OcuProbe1829NoGate";

Parameter PRINCIPALROLE = "OcuProbe1829CopierRole";

Parameter NOGATEROLE = "OcuProbe1829NoGateRole";

/// <p>A principal that passes the API floor (it holds one administrative resource, <code>%Admin_Manage:U</code>) but
/// not the user form's <code>%Admin_Secure:USE</code>, so the form's own route gate is what refuses it.</p>
Parameter FLOORPRINCIPAL = "OcuProbe1829Floor";

Parameter FLOORROLE = "OcuProbe1829FloorRole";

/// <p>A role that grants <code>%Admin_Operate:U</code>, held by a source first as a role and then as its escalation role.</p>
Parameter ADMINROLE = "OcuProbe1829AdminRole";

/// <p>The two roles the source holds for the case-and-order leg, in the order the leg's payload reverses.</p>
Parameter SOURCEROLES = "%Developer,%Operator";

/// <p>The probe marker written as each probe role's and account's comment or description.</p>
Parameter MARKER = "OcuPilot.Test.UserCopy probe";

/// <p>The directory-service and delegated sources the copy refuses, created with the vendor's flags.</p>
Parameter LDAPSOURCE = "OcuProbe1829Ldap";

Parameter DELEGATEDSOURCE = "OcuProbe1829Dlg";

Parameter LDAPFLAG = 2;

Parameter DELEGATEDFLAG = 4;

/// <p>A password the instance's policy accepts (the throwaway's pattern is the vendor's default).</p>
Parameter GOODPASSWORD = "Ocu-Probe-1829xyz!";

Parameter COPYPATH = "/users/copy";

Parameter CHECKPATH = "/users/password-check";

/// <p>The limits class the proposal mint is given (<class>OcuPilot.Kernel.Agent.Limits</class>).</p>
Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.UserCopy creates and deletes accounts on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Do ..RemoveProbes()
    Set tSC = ..MakeSource()
    If $$$ISERR(tSC) Quit tSC
    Quit ..MakePrincipals()
}

Method OnAfterAllTests() As %Status
{
    Quit ..RemoveProbes()
}

/// <p>Remove the target and the flagged sources, put the source's roles and escalation role back, and remove any
/// proposal the test seeded, whatever the test did. Each restoring step's status is kept and asserted.</p>
Method OnAfterOneTest() As %Status
{
    Set tGrantsSC = ..RemoveSqlGrants()
    Do ..RemoveAccount(..#TARGET)
    Do ..RemoveAccount(..#LDAPSOURCE)
    Do ..RemoveAccount(..#DELEGATEDSOURCE)
    Set tEscalationSC = ..SetSourceEscalation(..#ESCROLE)
    Set tRolesSC = ..SetSourceRoles("%Developer")
    Set tSeededSC = ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tRemaining)
    Do $$$AssertStatusOK(tGrantsSC, "the SQL privileges of the copy and the source are removed")
    Do $$$AssertStatusOK(tEscalationSC, "the source's escalation role is put back")
    Do $$$AssertStatusOK(tRolesSC, "the source's roles are put back")
    Do $$$AssertStatusOK(tSeededSC, "the probe proposals and turns are removed")
    Do $$$AssertEquals(tRemaining, 0, "and none survives the removal")
    Quit $$$OK
}

/// <p>AD-12: the copy route answers one JSON envelope, as <code>application/json</code>, over the absolute
/// request the browser makes. The source's account is removed by the teardown.</p>
Method TestTheCopyRouteAnswersOneJsonEnvelope()
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ ..#COPYPATH, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders, ..Body(..#TARGET, ..#GOODPASSWORD, ""), "application/json")
    Do $$$AssertStatusOK(tSC, "the absolute copy request completes")
    Do $$$AssertTrue($Get(tHeaders("CONTENT-TYPE")) [ "application/json", "as application/json")
    Do $$$AssertEquals(tStatus, 201, "and answers 201")
    Do $$$AssertEquals((tRaw [ "}{"), 0, "with exactly one envelope")
    Set tShape = ##class(%DynamicAbstractObject).%FromJSON(tRaw)
    Do $$$AssertTrue($IsObject(tShape) && (tShape.%GetTypeOf("user") = "object"), "whose body is the account object")
}

/// <p>AD-55, AD-58: a copy over <code>POST /users/copy</code> answers 201 with the new account as the instance
/// holds it: the source's roles and escalation roles, a setting the source holds, the copy's full name and the
/// write's read-back.</p>
Method TestTheCopyRouteCreatesTheAccountWithTheSourcesRoles()
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#COPYPATH, .tStatus, .tBody, ..Body(..#TARGET, ..#GOODPASSWORD, ""), "application/json")
    Do $$$AssertStatusOK(tSC, "the copy request completes")
    Do $$$AssertEquals(tStatus, 201, "a copy answers 201")
    Set tRoles = ""
    If $IsObject($Get(tBody)) && $IsObject(tBody.%Get("user")) Set tRoles = tBody.%Get("user").%ToJSON()
    Do $$$AssertTrue(tRoles [ "%Developer", "the account answered carries the source's role: " _ tRoles)
    Do $$$AssertTrue($IsObject($Get(tBody)) && $IsObject(tBody.%Get("readBack")), "the answer carries the write's read-back")
    Do $$$AssertEquals($Select($IsObject($Get(tBody)) && $IsObject(tBody.%Get("readBack")): tBody.%Get("readBack").%Get("verdict"), 1: ""), "matches", "and the write's read-back matches what was written")
    Do $$$AssertEquals(..Setting(..#TARGET, "EscalationRoles"), ..#ESCROLE, "the stored account holds the source's escalation role")
    Do $$$AssertEquals(..Setting(..#TARGET, "AccountNeverExpires"), "1", "and the source's setting, AccountNeverExpires")
    Do $$$AssertTrue(..Exists(..#TARGET), "the account exists on the instance")
}

/// <p>AD-35, AD-55: a password the policy refuses is 422 <code>USER.PASSWORD.POLICY</code> on
/// <code>Password</code>, and nothing is created.</p>
Method TestAWeakPasswordIsRefusedAndCreatesNothing()
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#COPYPATH, .tStatus, .tBody, ..Body(..#TARGET, "a", ""), "application/json")
    Do $$$AssertStatusOK(tSC, "the refused copy request completes")
    Do $$$AssertEquals(tStatus, 422, "a refused password is 422")
    Do $$$AssertTrue(..Mentions($Get(tBody), "USER.PASSWORD.POLICY"), "on the USER.PASSWORD.POLICY code")
    Do $$$AssertTrue(..Mentions($Get(tBody), "Password"), "naming the Password field")
    Do $$$AssertTrue('..Exists(..#TARGET), "and no account was created")
}

/// <p>AD-55, AD-58: an absent source is 422 with the violation on <code>CopyFrom</code>
/// (<code>USERCOPY.SOURCE</code>), and nothing is created.</p>
Method TestAnAbsentSourceIsRefusedOnCopyFrom()
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#COPYPATH, .tStatus, .tBody, ..Body(..#TARGET, ..#GOODPASSWORD, "OcuProbe1829Nope"), "application/json")
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 422, "an absent source is 422")
    Do $$$AssertTrue(..Mentions($Get(tBody), "USERCOPY.SOURCE"), "on the USERCOPY.SOURCE code")
    Do $$$AssertEquals(..ViolationReasonOf($Get(tBody)), "Copy from a local user this instance holds, not a directory-service or delegated account.", "with the source sentence as its reason")
    Do $$$AssertTrue('..Exists(..#TARGET), "and no account was created")
}

/// <p>AD-39, AD-55: a directory-service (LDAP) account and a delegated account are not copied. Each is 422
/// <code>USERCOPY.SOURCE</code> on <code>CopyFrom</code>, and nothing is created.</p>
Method TestADirectoryOrDelegatedSourceIsRefusedOnCopyFrom()
{
    Set tSC = ..MakeFlaggedSource(..#LDAPSOURCE, ..#LDAPFLAG)
    Do $$$AssertStatusOK(tSC, "the directory-service source is created")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#COPYPATH, .tStatus, .tBody, ..Body(..#TARGET, ..#GOODPASSWORD, ..#LDAPSOURCE), "application/json")
    Do $$$AssertStatusOK(tSC, "the request for a directory-service source completes")
    Do $$$AssertEquals(tStatus, 422, "a directory-service source is 422")
    Do $$$AssertTrue(..Mentions($Get(tBody), "USERCOPY.SOURCE"), "on the USERCOPY.SOURCE code")
    Do $$$AssertTrue('..Exists(..#TARGET), "and no account was created")

    Set tSC = ..MakeFlaggedSource(..#DELEGATEDSOURCE, ..#DELEGATEDFLAG)
    Do $$$AssertStatusOK(tSC, "the delegated source is created")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#COPYPATH, .tStatus, .tBody, ..Body(..#TARGET, ..#GOODPASSWORD, ..#DELEGATEDSOURCE), "application/json")
    Do $$$AssertStatusOK(tSC, "the request for a delegated source completes")
    Do $$$AssertEquals(tStatus, 422, "a delegated source is 422")
    Do $$$AssertTrue(..Mentions($Get(tBody), "USERCOPY.SOURCE"), "on the USERCOPY.SOURCE code")
    Do $$$AssertTrue('..Exists(..#TARGET), "and no account was created")
}

/// <p>AD-35: the password check answers <code>{valid, reason}</code>, a refusal with a sentence, and the whole answer
/// carries none of the password it was given. The marker is short, so the policy refuses it by length and the answer
/// is a refusal, and it is distinctive enough that no key or sentence of the answer contains it.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Permissions.UserCreateRules.HandlePasswordCheck</method> put the
/// password into <code>reason</code> -- the whole-body leg reddens.</p>
Method TestThePasswordCheckAnswersAndNeverEchoesThePassword()
{
    Set tMarker = "Zq"
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#CHECKPATH, .tStatus, .tBody, "{""name"":""" _ ..#TARGET _ """,""password"":""" _ tMarker _ """}", "application/json")
    Do $$$AssertStatusOK(tSC, "the check request completes")
    Do $$$AssertEquals(tStatus, 200, "the check answers 200")
    Do $$$AssertEquals($Select($IsObject($Get(tBody)): tBody.%GetTypeOf("valid"), 1: ""), "boolean", "valid is a boolean")
    Do $$$AssertEquals($Select($IsObject($Get(tBody)): tBody.%Get("valid"), 1: 1), 0, "a refused password answers valid false")
    Do $$$AssertTrue($IsObject($Get(tBody)) && (tBody.%Get("reason") '= ""), "with a reason")
    Do $$$AssertTrue('$IsObject($Get(tBody)) || ('tBody.%IsDefined("password")), "and no password field")
    Do $$$AssertTrue($IsObject($Get(tBody)) && (tBody.%ToJSON() '[ tMarker), "and the whole answer, reason included, carries no part of the password")
}

/// <p>AD-8, AD-44: the user form's own gate refuses the password check to a principal that passes the API floor but
/// lacks the form's <code>%Admin_Secure:USE</code>. The floor admits it (one administrative resource), so the refusal
/// is the check handler's gate, and nothing is judged.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Permissions.UserCreateRules.Gate</method> answer <code>$$$OK</code>
/// without evaluating the form's pairs -- the check answers 200 to this principal and the leg reddens.</p>
Method TestThePasswordCheckIsRefusedToAPrincipalWithTheFloorButNotTheFormsPair()
{
    Set tSC = ..AsPrincipal(..#FLOORPRINCIPAL, "POST", ..#CHECKPATH, "{""name"":""" _ ..#TARGET _ """,""password"":""a""}", .tStatus, .tRaw)
    Do $$$AssertStatusOK(tSC, "the floor-only principal's check request completes")
    Do $$$AssertEquals(tStatus, 403, "the form's gate refuses the check: " _ tRaw)
    Do $$$AssertTrue(tRaw [ "%Admin_Secure", "and names the pair it lacks")
}

/// <p>AD-55, AD-58: a copy whose source's roles changed after the proposal is refused 409
/// <code>USERCOPY.SOURCECHANGED</code> at the write, and nothing is created. The payload names a role the
/// source does not hold.</p>
Method TestTheSourceChangedAtTheWriteIsRefused()
{
    Kill tQuery
    Set tQuery("name") = ..#TARGET
    Set tBody = {}
    Do tBody.%Set("CopyFrom", ..#SOURCE, "string")
    Do tBody.%Set("FullName", "", "string")
    Do tBody.%Set("Roles", ["%Operator"])
    Do tBody.%Set("EscalationRoles", [])
    Do tBody.%Set("Password", ..#GOODPASSWORD, "string")
    Set tSC = ##class(OcuPilot.Port.UserCopyPort).Invoke("Security.User", "COPY", .tQuery, tBody, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 409, "a source whose roles moved is 409")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "USERCOPY.SOURCECHANGED", "on USERCOPY.SOURCECHANGED")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%Get("reason"), 1: ""), "The source user's roles changed after this copy was proposed. Propose the copy again to review them.", "with the source-changed sentence as its reason")
    Do $$$AssertTrue('..Exists(..#TARGET), "and no account was created")
}

/// <p>AD-55, AD-58: the write's source check compares roles as sets, so a copy whose roles alone moved is refused 409
/// <code>USERCOPY.SOURCECHANGED</code>, and the same names in another case and order are admitted. The port answers
/// 200 for the admitted copy, which the route maps to 201.</p>
/// <p>Mutation (Rule 19): remove the Roles clause from the source-changed check in
/// <method>OcuPilot.Port.UserCopyPort.Copy</method> -- the roles-only leg reddens.</p>
Method TestTheRolesAloneChangedIsRefusedAndTheSameNamesInAnotherCaseAndOrderAreAdmitted()
{
    Set tSC = ..SetSourceRoles(..#SOURCEROLES)
    Do $$$AssertStatusOK(tSC, "the source holds two roles for this test")
    If $$$ISERR(tSC) Quit
    Kill tQuery
    Set tQuery("name") = ..#TARGET
    Set tBody = {}
    Do tBody.%Set("CopyFrom", ..#SOURCE, "string")
    Do tBody.%Set("FullName", "", "string")
    Do tBody.%Set("Roles", ["%Developer"])
    Set tEscalation = []
    Do tEscalation.%Push(..#ESCROLE)
    Do tBody.%Set("EscalationRoles", tEscalation)
    Do tBody.%Set("Password", ..#GOODPASSWORD, "string")
    Set tSC = ##class(OcuPilot.Port.UserCopyPort).Invoke("Security.User", "COPY", .tQuery, tBody, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 409, "a source whose roles alone moved is 409")
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "USERCOPY.SOURCECHANGED", "on USERCOPY.SOURCECHANGED")
    Do $$$AssertTrue('..Exists(..#TARGET), "and no account was created")

    Kill tQuery
    Set tQuery("name") = ..#TARGET
    Set tBody = {}
    Do tBody.%Set("CopyFrom", ..#SOURCE, "string")
    Do tBody.%Set("FullName", "", "string")
    Do tBody.%Set("Roles", ["%operator","%DEVELOPER"])
    Set tEscalation = []
    Do tEscalation.%Push("%OPERATOR")
    Do tBody.%Set("EscalationRoles", tEscalation)
    Do tBody.%Set("Password", ..#GOODPASSWORD, "string")
    Set tSC = ##class(OcuPilot.Port.UserCopyPort).Invoke("Security.User", "COPY", .tQuery, tBody, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the same names in another case and order complete")
    Do $$$AssertEquals(tHttp, 200, "and the port answers 200, which the route maps to 201")
    Do $$$AssertTrue(..Exists(..#TARGET), "and the account exists")
}

/// <p>AD-54, AD-10: the copy's composed payload carries the source's roles and escalation roles, the four
/// fields the confirm compares and the prohibited set admits.</p>
/// <p>Mutation (Rule 19): drop <code>EscalationRoles</code> from
/// <method>OcuPilot.Screen.Tool.UserCopy.ComposeCreate</method>'s composition -- the escalation leg reddens.</p>
Method TestTheComposedPayloadCarriesTheSourcesRolesAndEscalationRoles()
{
    Set tArgs = {"Name": (..#TARGET), "CopyFrom": (..#SOURCE)}
    Set tSC = $ClassMethod("OcuPilot.Screen.Tool.UserCopy", "ComposeCreate", tArgs, "Name", $ClassMethod("OcuPilot.Screen.Tool.UserCopy", "SettableFields"), .tPayload, .tDiff, .tUnchanged, .tProblem)
    Do $$$AssertStatusOK(tSC, "the composition completes")
    Do $$$AssertEquals(tProblem, "", "with no problem for an existing source")
    Do $$$AssertEquals(tPayload.%GetTypeOf("EscalationRoles"), "array", "the payload carries EscalationRoles as an array")
    Do $$$AssertEquals(tPayload.%Get("EscalationRoles").%ToJSON(), "[""" _ ..#ESCROLE _ """]", "and the source's escalation roles")
    Do $$$AssertEquals(tPayload.%Get("Roles").%ToJSON(), "[""%Developer""]", "and the source's roles")
}

/// <p>AD-10, Story 18.29: a copy whose source's escalation role grants %All is privileged, so the mint marks it
/// destructive and names the privilege. A user create or a directory-service create carrying the same escalation
/// role is privileged too: both reach the one user branch of the classifier.</p>
/// <p>Mutation (Rule 19): remove the escalation-roles leg from
/// <method>OcuPilot.Kernel.Proposal.Prohibited.GrantsPrivilegeByEffect</method>'s user branch -- this answers 0 and
/// the legs redden.</p>
Method TestAnEscalationRoleThatGrantsAllIsPrivileged()
{
    Set tPayload = {"CopyFrom": "x", "Roles": [], "EscalationRoles": ["%All"]}
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).GrantsPrivilegeByEffect("user", tPayload, {}, .tGrants)
    Do $$$AssertStatusOK(tSC, "the classifier completes")
    Do $$$AssertEquals(tGrants, 1, "an escalation role that grants %All is a privilege grant")

    Set tCreate = {"Name": "x", "Roles": [], "EscalationRoles": ["%All"]}
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).GrantsPrivilegeByEffect("user", tCreate, {}, .tGrants)
    Do $$$AssertStatusOK(tSC, "the classifier completes for a user create")
    Do $$$AssertEquals(tGrants, 1, "a user create whose escalation role grants %All is privileged")

    Set tLdap = {"Name": "x", "Roles": [], "EscalationRoles": ["%All"], "LDAPAttributeFullName": "x"}
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).GrantsPrivilegeByEffect("user", tLdap, {}, .tGrants)
    Do $$$AssertStatusOK(tSC, "the classifier completes for a directory-service create")
    Do $$$AssertEquals(tGrants, 1, "a directory-service create whose escalation role grants %All is privileged")
}

/// <p>AD-10, AD-55: a source holding an <code>%Admin_*</code> privilege, first as a role and then as its escalation
/// role, is proposed destructive and at the privileged consequence, as a source holding <code>%All</code> is.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Proposal.Prohibited.IsPrivilegedRole</method> answer 0 for the
/// <code>%Admin_</code> prefix -- the role leg and the escalation leg both redden.</p>
Method TestAnAdminPrivilegeAsRoleOrEscalationRoleMakesTheCopyPrivileged()
{
    Set tSC = ..SetSourceRoles("%Developer," _ ..#ADMINROLE)
    Do $$$AssertStatusOK(tSC, "the source holds the administrative role as one of its roles")
    If $$$ISERR(tSC) Quit
    Set tSC = ..MintAs(..#PRINCIPAL, ..#TARGET, .tKey, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the copy mints as the principal, for the role leg")
    If $$$ISOK(tSC) {
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "Destructive"), 1, "the role leg is destructive")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "Consequence"), ##class(OcuPilot.Kernel.Proposal.Mint).#CONSEQUENCEPRIVILEGED, "and names the privileged consequence")
    }

    Set tSC = ..SetSourceRoles("%Developer")
    Do $$$AssertStatusOK(tSC, "the source's roles are put back before the escalation leg")
    Set tSC = ..SetSourceEscalation(..#ADMINROLE)
    Do $$$AssertStatusOK(tSC, "the source holds the administrative role as its escalation role")
    If $$$ISERR(tSC) Quit
    Set tSC = ..MintAs(..#PRINCIPAL, ..#TARGET, .tKey, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the copy mints as the principal, for the escalation leg")
    If $$$ISOK(tSC) {
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "Destructive"), 1, "the escalation leg is destructive")
        Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "Consequence"), ##class(OcuPilot.Kernel.Proposal.Mint).#CONSEQUENCEPRIVILEGED, "and names the privileged consequence")
    }
}

/// <p>AD-10: a copy's payload admits its four fields alone, so a field it does not compose is refused
/// <code>PROHIBITED.UNCOVEREDFIELD</code>, and the four alone are not refused.</p>
/// <p>Mutation (Rule 19): delete the <code>Copied</code> arm in <method>OcuPilot.Kernel.Proposal.Prohibited.Prohibits</method>
/// -- the admitted leg reddens.</p>
Method TestACopyPayloadAdmitsItsFourFieldsAlone()
{
    Set tRef = ""
    Set tDescriptor = "OcuPilot.Screen.Descriptor.UserList"
    Set tKeySC = ##class(OcuPilot.Kernel.EntityRef).Key($ClassMethod(tDescriptor, "PrimaryEntityType"), ##class(OcuPilot.Kernel.EntityRef).ScopeFor($ClassMethod(tDescriptor, "Scope")), ..#TARGET, .tRef)
    Do $$$AssertStatusOK(tKeySC, "the target reference resolves")
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits("permissions.users.copy", tRef, {"CopyFrom": "x", "FullName": "", "Roles": [], "EscalationRoles": [], "Routine": "/bin/sh"}.%ToJSON(), "[]", .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the prohibited set completes")
    Do $$$AssertEquals(tCode, "PROHIBITED.UNCOVEREDFIELD", "a field outside the four is refused")

    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits("permissions.users.copy", tRef, {"CopyFrom": "x", "FullName": "", "Roles": [], "EscalationRoles": []}.%ToJSON(), "[]", .tProhibits, .tCode)
    Do $$$AssertStatusOK(tSC, "the prohibited set completes for the four fields alone")
    Do $$$AssertEquals(tCode, "", "the four fields alone are not refused PROHIBITED.UNCOVEREDFIELD or any other code")
    Do $$$AssertEquals(tProhibits, 0, "and the copy is admitted")
}

/// <p>AD-55, AD-58: the least-privileged principal, holding exactly <code>%Admin_Secure:U</code>,
/// <code>%DB_IRISSYS:R</code> and <code>%DB_HSCUSTOM:R</code>, copies over the wire and checks a password; the
/// principal without <code>%Admin_Secure</code> is refused the copy and the check, and nothing is created.</p>
/// <p>The principal without <code>%Admin_Secure</code> holds no administrative resource, so the API floor refuses both
/// its requests before any route gate runs; the form's own gate is pinned by the floor-only principal's test.</p>
Method TestTheLeastPrivilegedPrincipalCopiesAndChecksAndTheOtherIsRefused()
{
    Set tSC = ..AsPrincipal(..#PRINCIPAL, "POST", ..#COPYPATH, ..Body(..#TARGET, ..#GOODPASSWORD, ""), .tStatus, .tRaw)
    Do $$$AssertStatusOK(tSC, "the principal's copy request completes")
    Do $$$AssertEquals(tStatus, 201, "the principal with exactly the copy's pairs copies: " _ tRaw)
    Do $$$AssertTrue(..Exists(..#TARGET), "and the account exists")
    Set tCopy = ##class(%DynamicAbstractObject).%FromJSON(tRaw)
    Do $$$AssertTrue($IsObject(tCopy) && $IsObject(tCopy.%Get("user")) && (tCopy.%Get("user").%ToJSON() [ "%Developer"), "the principal's copy carries the source's roles")
    Do $$$AssertTrue($IsObject(tCopy) && $IsObject(tCopy.%Get("readBack")) && (tCopy.%Get("readBack").%Get("verdict") = "matches"), "and the principal's write reads back as written")
    Do $$$AssertEquals(..Setting(..#TARGET, "EscalationRoles"), ..#ESCROLE, "the stored account holds the source's escalation role")
    Do $$$AssertEquals(..Setting(..#TARGET, "AccountNeverExpires"), "1", "and the source's setting, AccountNeverExpires")

    Set tSC = ..AsPrincipal(..#PRINCIPAL, "POST", ..#CHECKPATH, "{""name"":""" _ ..#TARGET _ """,""password"":""a""}", .tStatus, .tRaw)
    Do $$$AssertStatusOK(tSC, "the principal's check request completes")
    Do $$$AssertEquals(tStatus, 200, "the principal's check answers 200")
    Do $$$AssertTrue(tRaw [ """valid"":false", "and refuses the pattern: " _ tRaw)

    Do ..RemoveAccount(..#TARGET)
    Set tSC = ..AsPrincipal(..#NOGATE, "POST", ..#COPYPATH, ..Body(..#TARGET, ..#GOODPASSWORD, ""), .tStatus, .tRaw)
    Do $$$AssertStatusOK(tSC, "the principal without %Admin_Secure's copy request completes")
    Do $$$AssertEquals(tStatus, 403, "the principal without %Admin_Secure is refused the copy: " _ tRaw)
    Do $$$AssertTrue('..Exists(..#TARGET), "and no account was created")

    Set tSC = ..AsPrincipal(..#NOGATE, "POST", ..#CHECKPATH, "{""name"":""" _ ..#TARGET _ """,""password"":""a""}", .tStatus, .tRaw)
    Do $$$AssertStatusOK(tSC, "the principal without %Admin_Secure's check request completes")
    Do $$$AssertEquals(tStatus, 403, "and is refused the password check by the API floor")
}

/// <p>AD-35, AD-10, AD-55: a copy minted as the principal is destructive when its source's escalation role grants
/// <code>%All</code>, the consequence names the privilege, and the principal's confirm over the route writes the
/// copy. The source's escalation role is restored afterwards.</p>
Method TestAPrivilegedCopyIsProposedDestructiveAndConfirmedAsThePrincipal()
{
    Set tSC = ..SetSourceEscalation("%All")
    Do $$$AssertStatusOK(tSC, "the source's escalation role is set to %All")
    Set tSC = ..MintAs(..#PRINCIPAL, ..#TARGET, .tKey, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the copy mints as the principal")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "ToolName"), "permissions.users.copy", "the proposal names the agent tool permissions.users.copy")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "Destructive"), 1, "the proposal is destructive")
    Do $$$AssertEquals(##class(OcuPilot.Test.ProposalFixture).Field(tKey, "Consequence"), ##class(OcuPilot.Kernel.Proposal.Mint).#CONSEQUENCEPRIVILEGED, "and its consequence is the privileged grant, which the card names as %All or an administrative privilege")

    Set tSC = ..AsPrincipal(..#PRINCIPAL, "POST", "/proposal/" _ tKey _ "/confirm", "{""Password"":""" _ ..#GOODPASSWORD _ """}", .tStatus, .tRaw)
    Do $$$AssertStatusOK(tSC, "the confirm request completes")
    Do $$$AssertEquals(tStatus, 200, "the principal's confirm writes the copy: " _ tRaw)
    Do $$$AssertTrue(..Exists(..#TARGET), "and the account exists")
    Do $$$AssertTrue(..Setting(..#TARGET, "EscalationRoles") [ "%All", "and holds the escalation role the proposal named")
    Do $$$AssertTrue(..Setting(..#TARGET, "Roles") [ "%Developer", "and the source's roles")
    Do $$$AssertEquals(..Setting(..#TARGET, "AccountNeverExpires"), "1", "and the source's setting, AccountNeverExpires")
    Set tAnswer = ""
    Try {
        Set tAnswer = ##class(%DynamicAbstractObject).%FromJSON(tRaw)
    } Catch ex {
        Set tAnswer = ""
    }
    Do $$$AssertEquals($Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("readBack")): tAnswer.%Get("readBack").%Get("verdict"), 1: ""), "matches", "and the confirm's read-back matches what was written")
}

/// <p>AD-55, AD-58: a copy whose source's escalation roles change between the mint and the confirm is refused 409
/// <code>USERCOPY.SOURCECHANGED</code> at the confirm, and nothing is created.</p>
Method TestTheSourceChangedAfterTheMintIsRefusedAtTheConfirm()
{
    Set tSC = ..MintAs(..#PRINCIPAL, ..#TARGET, .tKey, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the copy mints as the principal")
    If $$$ISERR(tSC) Quit
    Set tSC = ..SetSourceEscalation("")
    Do $$$AssertStatusOK(tSC, "the source's escalation role is removed after the mint")

    Set tSC = ..AsPrincipal(..#PRINCIPAL, "POST", "/proposal/" _ tKey _ "/confirm", "{""Password"":""" _ ..#GOODPASSWORD _ """}", .tStatus, .tRaw)
    Do $$$AssertStatusOK(tSC, "the confirm request completes")
    Do $$$AssertEquals(tStatus, 409, "the confirm is refused: " _ tRaw)
    Do $$$AssertTrue(tRaw [ "USERCOPY.SOURCECHANGED", "on USERCOPY.SOURCECHANGED")
    Do $$$AssertTrue('..Exists(..#TARGET), "and no account was created")
}

/// <p>AD-35, AD-2: the agent's confirm of a copy goes through the password guard, so a password the policy refuses
/// is 422 <code>USER.PASSWORD.POLICY</code> at the confirm, and nothing is created.</p>
Method TestTheConfirmOfACopyGoesThroughThePasswordGuard()
{
    Set tSC = ..MintAs(..#PRINCIPAL, ..#TARGET, .tKey, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the copy mints as the principal")
    If $$$ISERR(tSC) Quit
    Set tSC = ..AsPrincipal(..#PRINCIPAL, "POST", "/proposal/" _ tKey _ "/confirm", "{""Password"":""a""}", .tStatus, .tRaw)
    Do $$$AssertStatusOK(tSC, "the confirm request completes")
    Do $$$AssertEquals(tStatus, 422, "a refused password at the confirm is 422: " _ tRaw)
    Do $$$AssertTrue(tRaw [ "USER.PASSWORD.POLICY", "on USER.PASSWORD.POLICY")
    Do $$$AssertTrue('..Exists(..#TARGET), "and no account was created")
}

/// <p>AD-55: a copy minted for the principal without <code>%Admin_Secure</code> and confirmed over the route is
/// refused 403 with no account created. The refusal comes from the confirm's own pair gate
/// (<method>OcuPilot.Kernel.Proposal.Operation.Gate</method>, which runs before the port), not from
/// <method>OcuPilot.Port.UserCopyPort.Copy</method>'s gate.</p>
/// <p>Mutation (Rule 19): none at this leg's level. Removing the port's gate leaves it green (run 78): the confirm's
/// pair gate answers first. The port's gate is pinned by the in-process leg below it.</p>
Method TestTheConfirmOfACopyAsAPrincipalWithoutAdminSecureIsRefusedByTheConfirmPairGate()
{
    Set tSC = ..MintAs(..#NOGATE, ..#TARGET, .tKey, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the copy mints for the principal without %Admin_Secure")
    If $$$ISERR(tSC) Quit
    Set tSC = ..AsPrincipal(..#NOGATE, "POST", "/proposal/" _ tKey _ "/confirm", "{""Password"":""" _ ..#GOODPASSWORD _ """}", .tStatus, .tRaw)
    Do $$$AssertStatusOK(tSC, "the confirm request completes")
    Do $$$AssertEquals(tStatus, 403, "the confirm's pair gate refuses a principal without %Admin_Secure: " _ tRaw)
    Do $$$AssertTrue('..Exists(..#TARGET), "and no account was created")
}

/// <p>AD-55, AD-27: the port's own <code>%Admin_Secure</code> gate, reached in-process through
/// <class>OcuPilot.Test.UserCopyNoGate</class>, whose <code>HoldsResource</code> answers no. Nothing is created.
/// No route and no confirm stands before the port here, so this is the leg the gate's removal reddens.</p>
/// <p>Mutation (Rule 19): remove the gate in <method>OcuPilot.Port.UserCopyPort.Copy</method> -- the copy reaches the
/// vendor, creates the account and this leg reddens.</p>
Method TestThePortRefusesACopyWhoseCallerLacksAdminSecureWhateverTheRoute()
{
    Kill tQuery
    Set tQuery("name") = ..#TARGET
    Set tBody = {}
    Do tBody.%Set("CopyFrom", ..#SOURCE, "string")
    Do tBody.%Set("FullName", "", "string")
    Do tBody.%Set("Roles", ["%Developer"])
    Set tEscalation = []
    Do tEscalation.%Push(..#ESCROLE)
    Do tBody.%Set("EscalationRoles", tEscalation)
    Do tBody.%Set("Password", ..#GOODPASSWORD, "string")
    Set tSC = ##class(OcuPilot.Test.UserCopyNoGate).Invoke("Security.User", "COPY", .tQuery, tBody, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 403, "the port refuses a caller without %Admin_Secure, as an error status: " _ $System.Status.GetErrorText(tSC))
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), ##class(OcuPilot.Api.Error).#PORTACCESSDENIED, "on the access-denied code")
    Do $$$AssertTrue('..Exists(..#TARGET), "and no account was created")
}

/// <p>AD-10, Story 18.29: the copy's <code>Snippet</code> renders <code>Security.Users.Copy</code> with the source,
/// the target, the full name and the placeholder in place of the password, and no literal password.</p>
/// <p>Mutation (Rule 19): change the Copy arguments inside <method>OcuPilot.Port.UserCopyPort.Snippet</method> (the
/// <code>1, 1</code> pair) -- this leg reddens.</p>
Method TestTheSnippetRendersTheCopyWithThePasswordPlaceholder()
{
    Kill tQuery
    Set tQuery("name") = ..#TARGET
    Set tBody = {}
    Do tBody.%Set("CopyFrom", ..#SOURCE, "string")
    Do tBody.%Set("FullName", "Snippet Full", "string")
    Do tBody.%Set("Password", ..#GOODPASSWORD, "string")
    Set tSteps = ##class(OcuPilot.Port.UserCopyPort).Snippet(##class(OcuPilot.Port.UserCopyPort).#USEREndpoint, ##class(OcuPilot.Port.UserCopyPort).#COPYTYPE, .tQuery, tBody)
    Set tText = ""
    If tSteps.%Size() > 0 Set tText = tSteps.%Get(0).%Get("text")
    Set tExpected = "Set tSC = ##class(Security.Users).Copy(""" _ ..#SOURCE _ """, """ _ ..#TARGET _ """, ""Snippet Full"", 1, 1, ""<Password>"")"
    Do $$$AssertTrue(tText [ tExpected, "the snippet renders the copy call with the placeholder: " _ tText)
    Do $$$AssertTrue(tText '[ ..#GOODPASSWORD, "and no literal password")
}

/// <p>AD-35, AD-10: a copy carries the source's SQL privileges (the standard SELECT and the admin privilege
/// <code>%CREATE_TABLE</code>) in <parameter>NAMESPACE</parameter>, as the vendor copies them; the copy's teardown
/// revokes every privilege the copy reproduced and the source's, and no row of an OcuProbe1829 grantee survives.</p>
/// <p>Mutation (Rule 19): pass <code>0</code> for <code>SQLObjPrivs</code> in
/// <method>OcuPilot.Port.UserCopyPort.VendorCopy</method> -- the SELECT leg reddens.</p>
Method TestTheCopyCarriesTheSourcesSqlPrivilegesAndTheTeardownRemovesThem()
{
    Set tSC = ##class(OcuPilot.Test.SqlPrivilegeProbe).Seed()
    Do $$$AssertStatusOK(tSC, "the SQL probe table is made in USER")
    If $$$ISERR(tSC) Quit
    Set tTable = $Parameter("OcuPilot.Test.SqlPrivilegeProbe", "TABLE")
    Set tSC = ##class(OcuPilot.Test.SqlPrivilegeProbe).Grant(..#SOURCE, "TABLE", tTable, "SELECT", 0, "USER")
    Do $$$AssertStatusOK(tSC, "the source is granted SELECT on the probe table")
    Set tSC = ##class(OcuPilot.Test.SqlPrivilegeProbe).GrantAdmin(..#SOURCE, "%CREATE_TABLE")
    Do $$$AssertStatusOK(tSC, "the source is granted %CREATE_TABLE")

    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#COPYPATH, .tStatus, .tBody, ..Body(..#TARGET, ..#GOODPASSWORD, ""), "application/json")
    Do $$$AssertStatusOK(tSC, "the copy request completes")
    Do $$$AssertEquals(tStatus, 201, "the copy answers 201")
    Do $$$AssertTrue(##class(OcuPilot.Test.SqlPrivilegeProbe).Direct(..#TARGET, tTable, "SELECT") > 0, "the copy holds the source's SELECT on the probe table")
    Do $$$AssertEquals(##class(OcuPilot.Test.SqlPrivilegeProbe).AdminDirect(..#TARGET, "%CREATE_TABLE"), 1, "and the source's %CREATE_TABLE admin privilege")

    Do $$$AssertTrue(..SqlGrantsLeft() > 0, "the positive control: the privilege rows are present before the teardown, so a zero after it means removal")
    Set tSC = ..RemoveSqlGrants()
    Do $$$AssertStatusOK(tSC, "the SQL privileges are revoked and their rows swept")
    Do ##class(OcuPilot.Test.SqlPrivilegeProbe).RemoveAll()
    Do $$$AssertEquals(..SqlGrantsLeft(), 0, "the teardown removes every SQL privilege the copy and the source held")
}

/// <p>Revoke every SQL privilege the source and the copy target hold in <parameter>NAMESPACE</parameter> (the standard
/// and admin privileges, through the vendor's own calls), then delete any privilege row of either grantee that is
/// left, as <class>OcuPilot.Test.SqlPrivilegeProbe</class>'s sweep does for its own grantees. Idempotent: a revoke of an
/// absent grant is not an error, so the returned status reports the sweep and any fault that escaped it.</p>
ClassMethod RemoveSqlGrants() As %Status
{
    Set tSC = $$$OK
    Set tTable = $Parameter("OcuPilot.Test.SqlPrivilegeProbe", "TABLE")
    For tGrantee = ..#SOURCE, ..#TARGET {
        Do ##class(OcuPilot.Test.SqlPrivilegeProbe).Revoke(tGrantee, "TABLE", tTable, "SELECT", "USER")
        Do ##class(OcuPilot.Test.SqlPrivilegeProbe).RevokeAdmin("USER", tGrantee)
    }
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tGrantee = ..#SOURCE, ..#TARGET {
            Set tRows = ##class(%SQL.Statement).%ExecDirect(, "SELECT ID FROM Security.SQLPrivileges WHERE Grantee %STARTSWITH ? OR Grantee %STARTSWITH ?", tGrantee, $ZConvert(tGrantee, "L"))
            While tRows.%Next() {
                Set tDeleteSC = ##class(Security.SQLPrivileges).%DeleteId(tRows.%GetData(1))
                Set tSC = $$$ADDSC(tSC, tDeleteSC)
            }
        }
        Do $SYSTEM.Monitor.Clear()
    } Catch ex {
        Set tSC = $$$ADDSC(tSC, ex.AsStatus())
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>How many privilege rows the instance still holds for the source or the copy target, in any namespace.</p>
ClassMethod SqlGrantsLeft() As %Integer
{
    Set tCount = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRows = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*) FROM Security.SQLPrivileges WHERE Grantee %STARTSWITH ? OR Grantee %STARTSWITH ? OR Grantee %STARTSWITH ? OR Grantee %STARTSWITH ?", ..#SOURCE, $ZConvert(..#SOURCE, "L"), ..#TARGET, $ZConvert(..#TARGET, "L"))
        If tRows.%Next() Set tCount = tRows.%GetData(1)
    } Catch {
    }
    Set $NAMESPACE = tOrigNS
    Quit tCount
}

/// <p>Whether the instance holds an account named <var>pName</var>, read in <code>%SYS</code> by AD-16's save
/// and restore.</p>
ClassMethod Exists(pName As %String) As %Boolean
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Users).Get(pName, .tProps)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit $$$ISOK(tSC)
}

/// <p>The value of setting <var>pKey</var> on account <var>pName</var> as the instance holds it, read in
/// <code>%SYS</code>, or <code>""</code> when the account is absent.</p>
ClassMethod Setting(pName As %String, pKey As %String) As %String
{
    Set tOrigNS = $NAMESPACE
    Set tValue = ""
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        If $$$ISOK(##class(Security.Users).Get(pName, .tProps)) Set tValue = $Get(tProps(pKey)) _ ""
    } Catch ex {
    }
    Set $NAMESPACE = tOrigNS
    Quit tValue
}

/// <p>The copy's request body as JSON text.</p>
ClassMethod Body(pName As %String, pPassword As %String, pFrom As %String) As %String
{
    Set tFrom = $Select(pFrom = "": ..#SOURCE, 1: pFrom)
    Quit "{""Name"":""" _ pName _ """,""CopyFrom"":""" _ tFrom _ """,""FullName"":"""",""Password"":""" _ pPassword _ """}"
}

/// <p>The first violation's <code>reason</code> in an answer's <code>detail</code>, given as a JSON text or an object,
/// or <code>""</code> when the answer carries none.</p>
ClassMethod ViolationReasonOf(pBody As %String) As %String
{
    Set tObj = pBody
    If '$IsObject(tObj) {
        Try {
            Set tObj = ##class(%DynamicAbstractObject).%FromJSON(pBody)
        } Catch ex {
            Set tObj = ""
        }
    }
    If '$IsObject(tObj) Quit ""
    If '$IsObject(tObj.%Get("detail")) Quit ""
    Quit tObj.%Get("detail").%Get("violations").%Get(0).%Get("reason")
}

/// <p>Whether <var>pText</var> contains <var>pWord</var>.</p>
ClassMethod Mentions(pText As %String, pWord As %String) As %Boolean
{
    Quit $IsObject(pText) && (pText.%ToJSON() [ pWord) || ('$IsObject(pText) && (pText [ pWord))
}

/// <p>One request as the probe principal <var>pUser</var>, with its password, over the absolute request the
/// browser makes. <var>pRaw</var> is the answer's text.</p>
ClassMethod AsPrincipal(pUser As %String, pMethod As %String, pSuffix As %String, pBody As %String, Output pStatus As %Integer, Output pRaw As %String) As %Status
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Quit ##class(OcuPilot.Test.Http).AbsoluteRequest(pMethod, tBase _ pSuffix, pUser, ..#GOODPASSWORD, .pStatus, .pRaw, .tHeaders, pBody, "application/json")
}

/// <p>Mint a copy of <var>pTarget</var> as <var>pUser</var>, on a turn seeded for that user, through the shipped
/// mint. The password is a secret the confirm supplies, so it is not an argument.</p>
ClassMethod MintAs(pUser As %String, pTarget As %String, Output pKey As %String, Output pHttp As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pKey = ""
    Set pHttp = 0
    Set pFault = ""
    Set tTool = "OcuPilot.Screen.Tool.UserCopy"
    Set tToolName = "permissions.users.copy"
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn(pUser, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Set tArgs = {"Name": (pTarget), "CopyFrom": (..#SOURCE), "FullName": ""}
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Mint).Mint($Parameter(tTool, "DESCRIPTORCLASS"), tToolName, pUser, "", tTurnKey, tArgs, ..#LIMITS, .tProposal, .pHttp, .pFault, $ClassMethod(tTool, "Endpoint"), $ClassMethod(tTool, "IdParam"), pTarget, $ClassMethod(tTool, "IdArgument"), $ClassMethod(tTool, "SettableFields"), tTool)
    If $$$ISOK(tSC) Set pKey = tProposal.%Get("proposalId")
    Quit tSC
}

/// <p>Set the source's escalation roles to <var>pRoles</var> (an empty string removes them), in
/// <code>%SYS</code>.</p>
ClassMethod SetSourceEscalation(pRoles As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        Set tProps("EscalationRoles") = pRoles
        Set tSC = ##class(Security.Users).Modify(..#SOURCE, .tProps)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Set the source's roles to <var>pRoles</var>, a comma list, in <code>%SYS</code>.</p>
ClassMethod SetSourceRoles(pRoles As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Kill tProps
        Set tProps("Roles") = pRoles
        Set tSC = ##class(Security.Users).Modify(..#SOURCE, .tProps)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Create the copy's source account: the roles <code>%Developer</code>, the escalation role
/// <parameter>ESCROLE</parameter> and a setting the copy must carry. In <code>%SYS</code>, by AD-16's save and restore.</p>
ClassMethod MakeSource() As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Users).Create(..#SOURCE, "%Developer", ..#GOODPASSWORD, "Probe Source", "", "", "", 0, 1, ..#MARKER)
        If $$$ISOK(tSC) {
            Kill tProps
            Set tProps("EscalationRoles") = ..#ESCROLE
            Set tProps("AccountNeverExpires") = 1
            Set tSC = ##class(Security.Users).Modify(..#SOURCE, .tProps)
        }
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Create a directory-service or delegated source account, <var>pFlags</var> being the vendor's flag, in
/// <code>%SYS</code>.</p>
ClassMethod MakeFlaggedSource(pName As %String, pFlags As %Integer) As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Users).Create(pName, "%Developer", ..#GOODPASSWORD, "Probe flagged source", "", "", "", 0, 1, ..#MARKER, pFlags)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Create the two least-privileged principals and their roles, in <code>%SYS</code>: the copier, which holds
/// exactly <code>%Admin_Secure:U</code>, <code>%DB_IRISSYS:R</code> and <code>%DB_HSCUSTOM:R</code>, and the one that
/// holds the code-database reads without <code>%Admin_Secure</code>.</p>
ClassMethod MakePrincipals() As %Status
{
    Set tOrigNS = $NAMESPACE
    Set tSC = $$$OK
    Try {
        Set $NAMESPACE = "%SYS"
        Set tSC = ##class(Security.Roles).Create(..#PRINCIPALROLE, ..#MARKER, "%Admin_Secure:U,%DB_IRISSYS:R,%DB_HSCUSTOM:R", "")
        If $$$ISOK(tSC) Set tSC = ##class(Security.Roles).Create(..#NOGATEROLE, ..#MARKER, "%DB_IRISSYS:R,%DB_HSCUSTOM:R", "")
        If $$$ISOK(tSC) Set tSC = ##class(Security.Roles).Create(..#FLOORROLE, ..#MARKER, "%Admin_Manage:U,%DB_IRISSYS:R,%DB_HSCUSTOM:R", "")
        If $$$ISOK(tSC) Set tSC = ##class(Security.Roles).Create(..#ADMINROLE, ..#MARKER, "%Admin_Operate:U", "")
        If $$$ISOK(tSC) Set tSC = ##class(Security.Users).Create(..#PRINCIPAL, ..#PRINCIPALROLE, ..#GOODPASSWORD, "Probe copier", "", "", "", 0, 1, ..#MARKER)
        If $$$ISOK(tSC) Set tSC = ##class(Security.Users).Create(..#NOGATE, ..#NOGATEROLE, ..#GOODPASSWORD, "Probe no gate", "", "", "", 0, 1, ..#MARKER)
        If $$$ISOK(tSC) Set tSC = ##class(Security.Users).Create(..#FLOORPRINCIPAL, ..#FLOORROLE, ..#GOODPASSWORD, "Probe floor only", "", "", "", 0, 1, ..#MARKER)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Remove one account the test created, in <code>%SYS</code>; an absent account is not an error.</p>
ClassMethod RemoveAccount(pName As %String)
{
    If '..Exists(pName) Quit
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Do ##class(Security.Users).Delete(pName)
    } Catch ex {
    }
    Set $NAMESPACE = tOrigNS
}

/// <p>Remove the probe accounts and roles this class creates, in <code>%SYS</code>: the accounts first, so no role
/// is still held when it is deleted.</p>
ClassMethod RemoveProbes() As %Status
{
    Do ..RemoveAccount(..#TARGET)
    Do ..RemoveAccount(..#LDAPSOURCE)
    Do ..RemoveAccount(..#DELEGATEDSOURCE)
    Do ..RemoveAccount(..#PRINCIPAL)
    Do ..RemoveAccount(..#NOGATE)
    Do ..RemoveAccount(..#FLOORPRINCIPAL)
    Do ..RemoveAccount(..#SOURCE)
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        For tRole = ..#PRINCIPALROLE, ..#NOGATEROLE, ..#FLOORROLE, ..#ADMINROLE {
            If ##class(Security.Roles).Exists(tRole) Do ##class(Security.Roles).Delete(tRole)
        }
    } Catch ex {
    }
    Set $NAMESPACE = tOrigNS
    Quit $$$OK
}

/// <p>Story 18.29, AD-59: the copy tool's input schema names <code>CopyFrom</code> as a required string and drops
/// <code>Roles</code>, and the copy's snippet form is ObjectScript.</p>
/// <p>Mutation (Rule 19): remove <code>CopyFrom</code> from the required list in
/// <method>OcuPilot.Screen.Tool.UserCopy.InputSchema</method> -- the required-list leg reddens.</p>
Method TestTheCopyToolPinsItsInputSchemaAndSnippetForm()
{
    Set tSchema = ##class(OcuPilot.Screen.Tool.UserCopy).InputSchema()
    Set tProps = tSchema.%Get("properties")
    Do $$$AssertEquals(tProps.%GetTypeOf("CopyFrom"), "object", "the input schema names CopyFrom as a property")
    Do $$$AssertEquals(tProps.%GetTypeOf("Roles"), "unassigned", "and drops Roles")
    Do $$$AssertTrue(tSchema.%Get("required").%ToJSON() [ """CopyFrom""", "and requires CopyFrom: " _ tSchema.%Get("required").%ToJSON())
    Do $$$AssertEquals(##class(OcuPilot.Port.UserCopyPort).SnippetForm(##class(OcuPilot.Port.UserCopyPort).#USEREndpoint, ##class(OcuPilot.Port.UserCopyPort).#COPYTYPE), "objectscript", "the copy's snippet is ObjectScript")
    Quit
}

}
