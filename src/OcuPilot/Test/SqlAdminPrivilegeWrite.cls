/// <p>Pins Story 18.28's SQL admin privileges on both callers of each tool: the Users and Roles lists' row actions
/// <code>grant-sql</code> and <code>revoke-sql</code> with the type <code>ADMIN</code> and the privilege in
/// <code>Action</code>, over the wire, and the agent's mint and confirm, for a probe user and a probe role -- a grant
/// stored and read back as a <code>Direct</code> row, an admin option raised, a revoke, a grantee that holds
/// <code>%All</code> refused, the instance's grantor rule (status 516, SQLCODE -99) answered 403
/// <code>SQLPRIV.GRANTOR</code> on both verbs, an unknown grantee refused before anything is sent, every Rules case
/// refused, and OcuPilot's own roles refused with an admin privilege.</p>
/// <p>Every write is real for a grantee named <code>OcuSqlPrivProbe...</code> in <code>USER</code>.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, a <code>USER</code> namespace, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates and removes a probe user
/// and role, a probe principal and a probe schema's objects and sets the governance policy. Every probe object and
/// admin privilege set is removed by exact name before all, after each and after all.</p>
Class OcuPilot.Test.SqlAdminPrivilegeWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the writes, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.SqlPrivilegeProbe";

Parameter PRINCIPAL = "OcuPilot.Test.AuthOptionsProbe";

Parameter WRITE = "OcuPilot.Test.SqlPrivilegeWrite";

Parameter PORT = "OcuPilot.Port.SqlPrivilegePort";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter USERGRANT = "OcuPilot.Screen.Tool.UserSqlGrant";

Parameter USERREVOKE = "OcuPilot.Screen.Tool.UserSqlRevoke";

Parameter ROLEGRANT = "OcuPilot.Screen.Tool.RoleSqlGrant";

Parameter ROLEREVOKE = "OcuPilot.Screen.Tool.RoleSqlRevoke";

Parameter USERS = "permissions.users";

Parameter ROLES = "permissions.roles";

Parameter PRIVILEGE = "%CREATE_TABLE";

/// <p>The probe principal's resources: Security's two pairs and READ on <code>USER</code>'s database.</p>
Parameter RESOURCES = "%Admin_Secure:U,%DB_IRISSYS:R,%DB_USER:R";

/// <p>The throwaway principal's password, generated for the run.</p>
Property PreparedPassword As %String;

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlAdminPrivilegeWrite grants and revokes SQL admin privileges for a probe user and role on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuProbe1828Adm" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set tSC = $ClassMethod(..#PRINCIPAL, "RemoveAll")
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll"))
}

Method OnBeforeOneTest() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Seed")
    If $$$ISERR(tSC) Quit tSC
    Set ^||OcuPilotDatabaseWritePort = ..#PORT
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("")
    Kill tSettings
    For tKey = "permissions.users.grantsql", "permissions.users.revokesql", "permissions.roles.grantsql", "permissions.roles.revokesql" Set tSettings(tKey) = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PRINCIPAL, "RemoveAll"), "every probe principal is removed")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll"), "every probe object is removed by exact name")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Remaining"), 0, "and none is left, the admin privilege sets included")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Set tSC = $$$ADDSC(tSC, $ClassMethod(..#PRINCIPAL, "RemoveAll"))
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll"))
}

/// <p>C2: for a probe user and a probe role, on the screen's row action over the wire and on the agent's proposal,
/// an admin grant is stored and read back as a <code>Direct</code> row, a grant of what is held is refused, a
/// re-grant with the admin option upgrades it, and a revoke removes it; each card names the privilege.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.SqlPrivilegePort.WriteQuery</method> send an admin write to
/// the standard endpoint -- every leg goes red; drop the grantor-less row from
/// <method>OcuPilot.Screen.Tool.SqlPrivilegeWrite.StateDiff</method> -- the revoke card leg goes red; make
/// <method>OcuPilot.Api.ScreenAction.Values</method> require every declared value -- the route legs go red.</p>
Method TestAnAdminGrantAndRevokeRoundTripOnBothCallers()
{
    Set tProbe = ..#PROBE
    Set tPrivilege = ..#PRIVILEGE
    For tCase = $ListBuild(..#USERS, $Parameter(tProbe, "USER"), ..#USERGRANT, ..#USERREVOKE), $ListBuild(..#ROLES, $Parameter(tProbe, "ROLE"), ..#ROLEGRANT, ..#ROLEREVOKE) {
        Set tScreen = $List(tCase, 1)
        Set tGrantee = $List(tCase, 2)
        Do $$$AssertEquals($ClassMethod(tProbe, "AdminDirect", tGrantee, tPrivilege), 0, tGrantee _ " holds no admin privilege to begin with")
        Do $$$AssertEquals(..Wire(tScreen, ..Body("grant-sql", tGrantee), .tAnswer), "200 ", tScreen _ "'s grant-sql of an admin privilege answers 200: " _ ..Text(tAnswer))
        Do $$$AssertEquals(tAnswer.%Get("action") _ " " _ tAnswer.%Get("target").%Get("type") _ " " _ tAnswer.%Get("readBack").%Get("verdict"), "updated " _ $Select(tScreen [ "users": "user", 1: "role") _ " nothingSent", "an updated change event for the grantee, nothing sent as a body")
        Do $$$AssertEquals($ClassMethod(tProbe, "AdminDirect", tGrantee, tPrivilege), 1, "the admin privilege is held directly")
        Do $$$AssertEquals(..Wire(tScreen, ..Body("grant-sql", tGrantee), .tAnswer), "409 SQLPRIV.HELD", "a grant of what is held is refused")
        Do $$$AssertEquals(..Wire(tScreen, ..Body("grant-sql", tGrantee, "true"), .tAnswer), "200 ", "a re-grant with the admin option is made: " _ ..Text(tAnswer))
        Do $$$AssertEquals($ClassMethod(tProbe, "AdminDirect", tGrantee, tPrivilege), 2, "and upgrades it")
        Do $$$AssertEquals(..Wire(tScreen, ..Body("revoke-sql", tGrantee), .tAnswer), "200 ", tScreen _ "'s revoke-sql answers 200: " _ ..Text(tAnswer))
        Do $$$AssertEquals($ClassMethod(tProbe, "AdminDirect", tGrantee, tPrivilege), 0, "and the row is gone")
        Do $$$AssertEquals(..Wire(tScreen, ..Body("revoke-sql", tGrantee), .tAnswer), "409 SQLPRIV.NOTHELD", "a second revoke finds nothing direct")

        Set tSC = $ClassMethod(tProbe, "Mint", $List(tCase, 3), tGrantee, ..AdminArgs(tGrantee, 1), .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusOK(tSC, "the agent's admin grant with the admin option is minted (" _ tProblem _ ")")
        Do $$$AssertEquals($Select($IsObject($Get(tProposal)): tProposal.%Get("changed").%Size() _ " " _ tProposal.%Get("changed").%Get(0).%Get("field") _ "|" _ tProposal.%Get("changed").%Get(0).%Get("before") _ "|" _ tProposal.%Get("changed").%Get(0).%Get("after"), 1: ""), "1 Privilege|Not held|" _ tPrivilege _ " admin privilege in USER, with the grant option", "whose card names the privilege")
        Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and confirmed")
        Do $$$AssertEquals($ClassMethod(tProbe, "AdminDirect", tGrantee, tPrivilege), 2, "the admin privilege is held directly with the admin option")
        Set tSC = $ClassMethod(tProbe, "Mint", $List(tCase, 4), tGrantee, ..AdminArgs(tGrantee, 0), .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusOK(tSC, "the agent's revoke is minted (" _ tProblem _ ")")
        Do $$$AssertEquals($Select('$IsObject($Get(tProposal)): "", tProposal.%Get("changed").%Size() = 0: "0 ", 1: tProposal.%Get("changed").%Size() _ " " _ tProposal.%Get("changed").%Get(0).%Get("field") _ "|" _ tProposal.%Get("changed").%Get(0).%Get("before") _ "|" _ tProposal.%Get("changed").%Get(0).%Get("after")), "1 Privilege|" _ tPrivilege _ " admin privilege in USER|Revoked", "whose card names the privilege, with no grantor")
        Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and confirmed")
        Do $$$AssertEquals($ClassMethod(tProbe, "AdminDirect", tGrantee, tPrivilege), 0, "the row is gone")
    }
}

/// <p>C2: an admin privilege held through a role is listed with no direct row, so a revoke finds nothing to
/// remove; a grantee that holds <code>%All</code> is refused on both verbs and both callers, with nothing sent.</p>
/// <p>Mutation (Rule 19): count a role's row as a direct one in <method>OcuPilot.Port.SqlPrivilegePort.AdminTally</method>
/// -- the role leg goes red.</p>
Method TestAnAdminPrivilegeThroughARoleAndAnAllHolderAreNoDirectRows()
{
    Set tProbe = ..#PROBE
    Set tUser = $Parameter(tProbe, "USER")
    Set tRole = $Parameter(tProbe, "ROLE")
    Do $$$AssertEquals(..Wire(..#ROLES, ..Body("grant-sql", tRole), .tAnswer), "200 ", "the role is granted the privilege: " _ ..Text(tAnswer))
    Do $$$AssertStatusOK($ClassMethod(tProbe, "GiveRole"), "and given to the user")
    Do $$$AssertEquals($ClassMethod(tProbe, "AdminDirect", tUser, ..#PRIVILEGE), 0, "the user holds no direct row")
    Do $$$AssertEquals(..Wire(..#USERS, ..Body("revoke-sql", tUser), .tAnswer), "409 SQLPRIV.NOTHELD", "so a revoke from the user finds nothing direct")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "GiveAll", 1), "the user is given %All")
    Do $$$AssertEquals(..Wire(..#USERS, ..Body("grant-sql", tUser), .tAnswer), "409 SQLPRIV.SUPERUSER", "a grant to an %All holder is refused")
    Do $$$AssertEquals(..Wire(..#USERS, ..Body("revoke-sql", tUser), .tAnswer), "409 SQLPRIV.SUPERUSER", "and a revoke from one")
    Set tSC = $ClassMethod(tProbe, "Mint", ..#USERGRANT, tUser, ..AdminArgs(tUser, 0), .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals(tHttp _ " " _ tProblem, "409 SQLPRIV.SUPERUSER", "and the agent's mint")
    Do $ClassMethod(tProbe, "GiveAll", 0)
}

/// <p>C2: every admin privilege the Rules take (<method>OcuPilot.Port.SqlPrivilegePort.ActionsFor</method>
/// <code>ADMIN</code>) is one the instance takes: the port grants each to the probe user, the admin list reads it
/// back as a <code>Direct</code> row, and the port revokes it.</p>
/// <p>Mutation (Rule 19): misspell one name in <parameter>OcuPilot.Port.SqlPrivilegePort.ADMINPRIVILEGES</parameter>
/// -- that name's legs go red.</p>
Method TestEveryAdminPrivilegeTheRulesTakeIsGrantedAndRevoked()
{
    Set tProbe = ..#PROBE
    Set tUser = $Parameter(tProbe, "USER")
    Set tNames = $ClassMethod(..#PORT, "ActionsFor", "ADMIN")
    Do $$$AssertTrue($ListLength(tNames) > 0, "the Rules take admin privileges")
    For tI = 1:1:$ListLength(tNames) {
        Set tName = $List(tNames, tI)
        For tType = "GRANT", "REVOKE" {
            Kill tQuery, tResult, tHttp, tFault
            Set tQuery("namespace") = "USER"
            Set tQuery("grantee") = tUser
            Set tQuery("type") = "ADMIN"
            Set tQuery("action") = tName
            Set tSC = $ClassMethod(..#PORT, "Invoke", "Security.SQLPrivilege.Standard", tType, .tQuery, "", .tResult, .tHttp, .tFault)
            Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "200 ", "the port's " _ tType _ " of " _ tName _ " is applied")
            Do $$$AssertEquals($ClassMethod(tProbe, "AdminDirect", tUser, tName), $Select(tType = "GRANT": 1, 1: 0), "and the admin list reads " _ tName _ " " _ $Select(tType = "GRANT": "held directly", 1: "gone"))
        }
    }
}

/// <p>C2: the instance's grantor rule -- an admin grant or revoke by a principal who does not hold the privilege
/// with the admin option, which the vendor answers 500 with status 516 and SQLCODE -99 -- is 403
/// <code>SQLPRIV.GRANTOR</code> on both verbs, and stores or removes nothing.</p>
/// <p>Mutation (Rule 19): drop <code>Security.SQLPrivilege.Admin|-99</code> from
/// <parameter>OcuPilot.Port.AdminPort.SQLCODEFAULTS</parameter> -- both legs go red.</p>
Method TestTheGrantorRuleIsRefusedOnBothVerbs()
{
    Set tProbe = ..#PROBE
    Set tUser = $Parameter(tProbe, "USER")
    Set tPrivilege = ..#PRIVILEGE
    Set tPrincipal = $List($ClassMethod(..#PRINCIPAL, "Users"), 1)
    Set tSC = $ClassMethod(..#PRINCIPAL, "SeedPrincipal", tPrincipal, $List($ClassMethod(..#PRINCIPAL, "Roles"), 1), ..#RESOURCES, ..PreparedPassword)
    Do $$$AssertStatusOK(tSC, "the probe principal is made")
    Do $$$AssertEquals(..WireAs(tPrincipal, ..#USERS, ..Body("grant-sql", tUser)), "403 SQLPRIV.GRANTOR", "a grant by a principal without the admin option is the grantor rule's refusal")
    Do $$$AssertEquals($ClassMethod(tProbe, "AdminDirect", tUser, tPrivilege), 0, "and stores nothing")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "GrantAdmin", tUser, tPrivilege), "the running account gives the user the privilege")
    Do $$$AssertEquals(..WireAs(tPrincipal, ..#USERS, ..Body("revoke-sql", tUser)), "403 SQLPRIV.GRANTOR", "a revoke by that principal is refused the same way")
    Do $$$AssertEquals($ClassMethod(tProbe, "AdminDirect", tUser, tPrivilege), 1, "and removes nothing")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "GrantAdmin", tPrincipal, tPrivilege, 1), "the principal is given the privilege with the admin option")
    Do $$$AssertEquals(..WireAs(tPrincipal, ..#USERS, ..Body("revoke-sql", tUser)), "200 ", "and then revokes another's grant of it")
    Do $$$AssertEquals($ClassMethod(tProbe, "AdminDirect", tUser, tPrivilege), 0, "which is gone")
}

/// <p>C2: an admin grant to a grantee the instance does not hold is refused before anything is sent -- naming it
/// on the screen's route, and as an absent target (400) by the agent's mint; every Rules case -- a privilege outside the list (<code>%DEFER</code> among them), in lower case, an object, a column -- is
/// refused 422 on the field it is about; OcuPilot's own roles are refused with an admin privilege under the role
/// arm from both callers.</p>
/// <p>Mutation (Rule 19): make the Rules ignore a privilege's case in
/// <method>OcuPilot.Port.SqlPrivilegePort.Violations</method> (compare upper-cased) -- the lower-case leg goes red.</p>
Method TestTheRulesAndOcuPilotsOwnRolesAreRefusedOnBothCallers()
{
    Set tProbe = ..#PROBE
    Set tUser = $Parameter(tProbe, "USER")
    Set tNobody = $Parameter(tProbe, "PREFIX") _ "NoSuchGrantee"
    Do $$$AssertEquals(..Wire(..#USERS, ..Body("grant-sql", tNobody), .tAnswer), "404 SQLPRIV.NOGRANTEE", "an admin grant to a grantee the instance does not hold is refused naming it")
    Set tSC = $ClassMethod(tProbe, "Mint", ..#USERGRANT, tNobody, ..AdminArgs(tNobody, 0), .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals(tHttp, 400, "and the agent's mint reads the port's 404 as an absent target: " _ tProblem)
    Do $$$AssertEquals($ClassMethod(tProbe, "RemainingAdminSets"), 0, "and no admin privilege set is stored for the name")
    For tCase = $ListBuild("Action", "%create_table", "Action", "SQLPRIV.ACTION"), $ListBuild("Action", "%CREATE_DATABASE", "Action", "SQLPRIV.ACTION"), $ListBuild("Action", "%DEFER", "Action", "SQLPRIV.ACTION"), $ListBuild("Action", "SELECT", "Action", "SQLPRIV.ACTION"), $ListBuild("Object", $Parameter(tProbe, "TABLE"), "Object", "SQLPRIV.OBJECT"), $ListBuild("Column", "ID", "Column", "SQLPRIV.COLUMN") {
        Set tBody = ..Body("grant-sql", tUser)
        Do tBody.values.%Set($List(tCase, 1), $List(tCase, 2))
        Do $$$AssertEquals(..Wire(..#USERS, tBody, .tAnswer), "422 SQLPRIV.VALIDATION", "the route refuses " _ $List(tCase, 1) _ " " _ $List(tCase, 2) _ " on an admin privilege")
        Set tViolation = $Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("detail")): tAnswer.%Get("detail").%Get("violations").%Get(0), 1: {})
        Do $$$AssertEquals(tViolation.%Get("field") _ " " _ tViolation.%Get("code"), $List(tCase, 3) _ " " _ $List(tCase, 4), "on the field it is about")
        Set tArgs = ..AdminArgs(tUser, 0)
        Do tArgs.%Set($List(tCase, 1), $List(tCase, 2))
        Set tSC = $ClassMethod(tProbe, "Mint", ..#USERGRANT, tUser, tArgs, .tProposal, .tHttp, .tProblem)
        Do $$$AssertEquals(tHttp _ " " _ tProblem, "422 SQLPRIV.VALIDATION", "the agent's mint refuses it too")
    }
    Do $$$AssertEquals($ClassMethod(tProbe, "AdminDirect", tUser, ..#PRIVILEGE), 0, "nothing was granted along the way")
    Do $$$AssertEquals(..Wire(..#ROLES, ..Body("grant-sql", "%DB_OCUPILOT"), .tAnswer), "403 PROHIBITED.OCUPILOTROLE", "an admin grant for %DB_OCUPILOT is refused under the role arm")
    Do $$$AssertEquals(..Wire(..#ROLES, ..Body("grant-sql", "OcuPilotAdmin"), .tAnswer), "403 PROHIBITED.OCUPILOTROLE", "and for OcuPilot's administrative role")
    Set tSC = $ClassMethod(tProbe, "Mint", ..#ROLEGRANT, "OcuPilotAdmin", ..AdminArgs("OcuPilotAdmin", 0), .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's admin grant for OcuPilot's administrative role is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "403 PROHIBITED.OCUPILOTROLE", "and its confirm is refused under the role arm")
}

/// <p>The body of the screen action <var>pAction</var> for the grantee <var>pGrantee</var>: the admin privilege
/// <code>%CREATE_TABLE</code> in <code>USER</code> (type <code>ADMIN</code>, no object), and on a grant the admin
/// option <var>pWithGrant</var> (<code>true</code> or <code>false</code>).</p>
ClassMethod Body(pAction As %String, pGrantee As %String, pWithGrant As %String = "false") As %DynamicObject
{
    Set tValues = {"Namespace": "USER", "Type": "ADMIN", "Action": (..#PRIVILEGE)}
    If pAction = "grant-sql" Do tValues.%Set("WithGrant", pWithGrant)
    Quit {"action": (pAction), "id": (pGrantee), "values": (tValues)}
}

/// <p>The agent's arguments for the admin privilege: <var>pWithGrant</var> adds the admin option.</p>
ClassMethod AdminArgs(pGrantee As %String, pWithGrant As %Boolean) As %DynamicObject
{
    Set tArgs = $ClassMethod(..#PROBE, "AdminArgs", pGrantee, ..#PRIVILEGE)
    If pWithGrant Do tArgs.%Set("WithGrant", 1, "boolean")
    Quit tArgs
}

/// <p>POST <var>pBody</var> to the screen <var>pScreen</var>'s action route over the wire as the test account,
/// answered as <code>status code</code>, the parsed answer in <var>pAnswer</var>.</p>
ClassMethod Wire(pScreen As %String, pBody As %DynamicObject, Output pAnswer As %DynamicObject) As %String
{
    Quit $ClassMethod(..#WRITE, "Wire", pScreen, pBody, .pAnswer)
}

/// <p>An answer's JSON, trimmed, for a failure message.</p>
ClassMethod Text(pAnswer As %DynamicObject) As %String
{
    Quit $ClassMethod(..#WRITE, "Text", pAnswer)
}

/// <p>The screen action <var>pBody</var> over the wire as <var>pUser</var> to <var>pScreen</var>, answered as
/// <code>status code</code>.</p>
Method WireAs(pUser As %String, pScreen As %String, pBody As %DynamicObject) As %String
{
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tBase _ "/screens/" _ pScreen _ "/action", pUser, ..PreparedPassword, .tStatus, .tBody, .tHeaders, pBody.%ToJSON(), "application/json")
    Set tAnswer = ##class(%DynamicObject).%FromJSON($Get(tBody, "{}"))
    Quit $Get(tStatus) _ " " _ tAnswer.%Get("code")
}

}
