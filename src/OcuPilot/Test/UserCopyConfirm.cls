/// <p>Pins the user copy as a least-privileged principal (AD-8, AD-35, AD-55, AD-58): the principal holding
/// exactly the copy's pairs copies and checks a password over the wire while the one without
/// <code>%Admin_Secure</code> is refused; a privileged copy is proposed destructive and confirmed; a source that
/// changed after the mint, and a password the policy refuses, are refused at the confirm; the confirm's pair gate
/// and the port's own gate refuse a caller without <code>%Admin_Secure</code>; and the copy carries the source's
/// SQL privileges. The probe accounts, the arming and the helpers are <class>OcuPilot.Test.UserCopyTestCase</class>'s.</p>
Class OcuPilot.Test.UserCopyConfirm Extends OcuPilot.Test.UserCopyTestCase
{

/// <p>The routes this class sends requests to, under the API base.</p>
Parameter COPYPATH = "/users/copy";

Parameter CHECKPATH = "/users/password-check";

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
/// <p>The confirm's pair gate answers first, so the port's gate is pinned by
/// <method>TestThePortRefusesACopyWhoseCallerLacksAdminSecureWhateverTheRoute</method>.</p>
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

}
