/// <p>Pins the user copy (AD-27, AD-35, AD-55, AD-58). Over a real HTTP request: <code>POST /users/copy</code>
/// and its refusals and sources, and the password check route <code>POST /users/password-check</code>. In
/// process: the port's source-changed refusal at the write, the composed payload, the copy's prohibited set and
/// privilege classification, the snippet and the tool's input schema. The least-privileged principal, confirm,
/// port-gate and SQL privilege legs are <class>OcuPilot.Test.UserCopyConfirm</class>'s. The probe accounts, the arming and the helpers are
/// <class>OcuPilot.Test.UserCopyTestCase</class>'s.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.UserCopyPort.SameNames</method> answer 1 for any two
/// arrays -- the source-changed leg reddens.</p>
Class OcuPilot.Test.UserCopy Extends OcuPilot.Test.UserCopyTestCase
{

/// <p>The routes this class sends requests to, under the API base.</p>
Parameter COPYPATH = "/users/copy";

Parameter CHECKPATH = "/users/password-check";

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

/// <p>AD-35, AD-55: a password the policy refuses is 422 with one violation, <code>USER.PASSWORD.POLICY</code> on
/// <code>Password</code> carrying the policy's own reason, and nothing is created.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Permissions.UserCreateRules.Validate</method> put a fixed
/// sentence in place of the policy's reason on the <code>Password</code> violation -- the reason leg reddens.</p>
Method TestAWeakPasswordIsRefusedAndCreatesNothing()
{
    Set tReason = ""
    Do $$$AssertTrue('##class(OcuPilot.Kernel.PasswordPolicy).Verdict("a", ..#TARGET, .tReason), "the policy refuses the password")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#COPYPATH, .tStatus, .tBody, ..Body(..#TARGET, "a", ""), "application/json")
    Do $$$AssertStatusOK(tSC, "the refused copy request completes")
    Do $$$AssertEquals(tStatus, 422, "a refused password is 422")
    Set tViolations = ..ViolationsOf($Get(tBody))
    Do $$$AssertEquals($Select($IsObject(tViolations): tViolations.%Size(), 1: 0), 1, "with one violation")
    Set tViolation = $Select($IsObject(tViolations) && (tViolations.%Size() > 0): tViolations.%Get(0), 1: {})
    Do $$$AssertEquals(tViolation.%Get("code"), ##class(OcuPilot.Api.Error).#USERPASSWORDPOLICY, "on the USER.PASSWORD.POLICY code")
    Do $$$AssertEquals(tViolation.%Get("field"), "Password", "naming the Password field")
    Do $$$AssertEquals(tViolation.%Get("reason"), tReason, "with the policy's reason")
    Do $$$AssertTrue('..Exists(..#TARGET), "and no account was created")
}

/// <p>AD-55, AD-58: an absent source, and a body whose <code>CopyFrom</code> is empty or missing, are each 422
/// with the violation on <code>CopyFrom</code> (<code>USERCOPY.SOURCE</code>), and nothing is created.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Area.Permissions.UserCopy.ComposePayload</method> record no
/// violation -- the empty and missing legs go red.</p>
Method TestAnAbsentSourceIsRefusedOnCopyFrom()
{
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#COPYPATH, .tStatus, .tBody, ..Body(..#TARGET, ..#GOODPASSWORD, "OcuProbe1829Nope"), "application/json")
    Do $$$AssertStatusOK(tSC, "the request completes")
    Do $$$AssertEquals(tStatus, 422, "an absent source is 422")
    Do $$$AssertTrue(..Mentions($Get(tBody), "USERCOPY.SOURCE"), "on the USERCOPY.SOURCE code")
    Do $$$AssertEquals(..ViolationReasonOf($Get(tBody)), "Copy from a local user this instance holds, not a directory-service or delegated account.", "with the source sentence as its reason")
    Do $$$AssertTrue('..Exists(..#TARGET), "and no account was created")

    Set tHead = "{""Name"":""" _ ..#TARGET _ ""","
    Set tTail = """FullName"":"""",""Password"":""" _ ..#GOODPASSWORD _ """}"
    For tCase = $ListBuild("an empty", tHead _ """CopyFrom"":""""," _ tTail), $ListBuild("a missing", tHead _ tTail) {
        Kill tBody
        Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", ..#COPYPATH, .tStatus, .tBody, $List(tCase, 2), "application/json")
        Do $$$AssertStatusOK(tSC, "the request with " _ $List(tCase, 1) _ " CopyFrom completes")
        Do $$$AssertEquals(tStatus, 422, $List(tCase, 1) _ " source is 422")
        Set tViolations = ..ViolationsOf($Get(tBody))
        Set tViolation = $Select($IsObject(tViolations) && (tViolations.%Size() = 1): tViolations.%Get(0), 1: {})
        Do $$$AssertEquals(tViolation.%Get("code") _ " " _ tViolation.%Get("field"), "USERCOPY.SOURCE CopyFrom", "with its one violation on CopyFrom, USERCOPY.SOURCE")
        Do $$$AssertTrue('..Exists(..#TARGET), "and no account was created")
    }
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
    Set tSteps = ##class(OcuPilot.Port.UserCopyPort).Snippet(##class(OcuPilot.Port.UserCopyPort).#USERENDPOINT, ##class(OcuPilot.Port.UserCopyPort).#COPYTYPE, .tQuery, tBody)
    Set tText = ""
    If tSteps.%Size() > 0 Set tText = tSteps.%Get(0).%Get("text")
    Set tExpected = "Set tSC = ##class(Security.Users).Copy(""" _ ..#SOURCE _ """, """ _ ..#TARGET _ """, ""Snippet Full"", 1, 1, ""<Password>"")"
    Do $$$AssertTrue(tText [ tExpected, "the snippet renders the copy call with the placeholder: " _ tText)
    Do $$$AssertTrue(tText '[ ..#GOODPASSWORD, "and no literal password")
}

/// <p>Story 18.29, AD-59: the copy tool's input schema names <code>CopyFrom</code> as a required string and drops
/// <code>Roles</code>, and the copy's snippet form is ObjectScript. The tool's <parameter>SOURCECODE</parameter>
/// is <parameter>OcuPilot.Api.UserCopyError.SOURCE</parameter>, and the tool's <parameter>WRITETYPE</parameter> and
/// the port's <parameter>COPYTYPE</parameter> are <parameter>OcuPilot.Kernel.Proposal.Prohibited.COPYWRITETYPE</parameter>.</p>
/// <p>Mutation (Rule 19): remove <code>CopyFrom</code> from the required list in
/// <method>OcuPilot.Screen.Tool.UserCopy.InputSchema</method> -- the required-list leg reddens.</p>
Method TestTheCopyToolPinsItsInputSchemaAndSnippetForm()
{
    Set tSchema = ##class(OcuPilot.Screen.Tool.UserCopy).InputSchema()
    Set tProps = tSchema.%Get("properties")
    Do $$$AssertEquals(tProps.%GetTypeOf("CopyFrom"), "object", "the input schema names CopyFrom as a property")
    Do $$$AssertEquals(tProps.%GetTypeOf("Roles"), "unassigned", "and drops Roles")
    Do $$$AssertTrue(tSchema.%Get("required").%ToJSON() [ """CopyFrom""", "and requires CopyFrom: " _ tSchema.%Get("required").%ToJSON())
    Do $$$AssertEquals(##class(OcuPilot.Port.UserCopyPort).SnippetForm(##class(OcuPilot.Port.UserCopyPort).#USERENDPOINT, ##class(OcuPilot.Port.UserCopyPort).#COPYTYPE), "objectscript", "the copy's snippet is ObjectScript")
    Do $$$AssertEquals(##class(OcuPilot.Screen.Tool.UserCopy).#SOURCECODE, ##class(OcuPilot.Api.UserCopyError).#SOURCE, "and the tool's source violation code is the published one")
    Set tCopyType = ##class(OcuPilot.Kernel.Proposal.Prohibited).#COPYWRITETYPE
    Do $$$AssertEquals(##class(OcuPilot.Screen.Tool.UserCopy).#WRITETYPE _ " " _ ##class(OcuPilot.Port.UserCopyPort).#COPYTYPE, tCopyType _ " " _ tCopyType, "and the tool's write type and the port's copy type are the kernel's copy write type")
    Quit
}

}
