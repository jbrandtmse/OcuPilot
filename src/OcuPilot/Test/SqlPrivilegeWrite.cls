/// <p>Pins Story 18.9's writes on both callers of each tool (C1 to C5): the Users and Roles lists' row actions
/// <code>grant-sql</code> and <code>revoke-sql</code> over the wire, and the agent's mint and confirm
/// (<class>OcuPilot.Test.DatabaseConfirm</class>), for a probe user and a probe role -- a grant stored and read back
/// as a <code>Direct</code> row, a grant option raised, a revoke that names every grantor of the direct rows it
/// removes and leaves the rows held through a role, the preconditions refused before anything is sent and a moved
/// target closed, a write the vendor answers 200 and does not make refused as not applied, the vendor's own
/// refusals in OcuPilot's words, every Rules case refused before the vendor is reached, OcuPilot's own schema and
/// roles refused from both callers with the installer's grant intact, and the routes' closed bodies.</p>
/// <p>Every write is real for a grantee and an object named <code>OcuSqlPrivProbe...</code>; the seam
/// (<class>OcuPilot.Test.SqlPrivilegeSeamPort</class>) records the port's calls and refuses any other write.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, a <code>USER</code> namespace, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates and removes a probe user and
/// role and a probe schema's objects and sets the governance policy. Every probe object is removed by exact name
/// before all, after each and after all, and the install namespace's grants of OcuPilot's own schema read as they
/// were.</p>
Class OcuPilot.Test.SqlPrivilegeWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the writes, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.SqlPrivilegeProbe";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter SEAM = "OcuPilot.Test.SqlPrivilegeSeamPort";

Parameter PORT = "OcuPilot.Port.SqlPrivilegePort";

Parameter USERGRANT = "OcuPilot.Screen.Tool.UserSqlGrant";

Parameter USERREVOKE = "OcuPilot.Screen.Tool.UserSqlRevoke";

Parameter ROLEGRANT = "OcuPilot.Screen.Tool.RoleSqlGrant";

Parameter ROLEREVOKE = "OcuPilot.Screen.Tool.RoleSqlRevoke";

Parameter ENDPOINT = "Security.SQLPrivilege.Standard";

/// <p>The governance policy as it stood before the class ran.</p>
Property PreparedPolicy [ MultiDimensional ];

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlPrivilegeWrite grants and revokes SQL privileges for a probe user and role on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Quit $ClassMethod(..#PROBE, "RemoveAll")
}

Method OnBeforeOneTest() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Seed")
    If $$$ISERR(tSC) Quit tSC
    Do $ClassMethod(..#SEAM, "Clear")
    Set ^||OcuPilotDatabaseWritePort = ..#PORT
    Do ##class(OcuPilot.Test.ProposalFixture).ArmProhibited("")
    Kill tSettings
    For tKey = "permissions.users.grantsql", "permissions.users.revokesql", "permissions.roles.grantsql", "permissions.roles.revokesql" Set tSettings(tKey) = "enabled"
    Quit ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
}

Method OnAfterOneTest() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Do $ClassMethod(..#SEAM, "Clear")
    Merge tRows = ..PreparedPolicy
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows), "the governance policy is restored")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll"), "every probe object is removed by exact name")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Remaining"), 0, "and none is left")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Kill ^||OcuPilotDatabaseWritePort
    Merge tRows = ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemoveAll"))
}

/// <p>C1: for a probe user and a probe role, on the screen's row action over the wire and on the agent's
/// proposal, a grant is stored and read back as a <code>Direct</code> row granted by the caller, a grant with the
/// grant option raises it, and a revoke removes the direct row; the card names the privilege.</p>
/// <p>Mutation (Rule 19): send the vendor's <code>REVOKE</code> without <code>asGrantor</code> -- the revoke legs
/// of a row another account granted go red (see <method>TestARevokeNamesEveryGrantor</method>).</p>
Method TestAGrantAndARevokeRoundTripOnBothCallers()
{
    Set tProbe = ..#PROBE
    Set tObject = $Parameter(tProbe, "TABLE")
    For tCase = $ListBuild("permissions.users", $Parameter(tProbe, "USER"), ..#USERGRANT, ..#USERREVOKE), $ListBuild("permissions.roles", $Parameter(tProbe, "ROLE"), ..#ROLEGRANT, ..#ROLEREVOKE) {
        Set tScreen = $List(tCase, 1)
        Set tGrantee = $List(tCase, 2)
        Do $$$AssertEquals($ClassMethod(tProbe, "Direct", tGrantee, tObject, "SELECT"), 0, tGrantee _ " holds nothing to begin with")
        Do $$$AssertEquals(..Wire(tScreen, ..Body("grant-sql", tGrantee), .tAnswer), "200 ", tScreen _ "'s grant-sql answers 200: " _ ..Text(tAnswer))
        Do $$$AssertEquals(tAnswer.%Get("action") _ " " _ tAnswer.%Get("target").%Get("type") _ " " _ tAnswer.%Get("readBack").%Get("verdict"), "updated " _ $Select(tScreen [ "users": "user", 1: "role") _ " nothingSent", "an updated change event for the grantee, nothing sent as a body")
        Do $$$AssertEquals($ClassMethod(tProbe, "Direct", tGrantee, tObject, "SELECT"), 1, "the privilege is held directly")
        Do $$$AssertTrue($ClassMethod(tProbe, "Rows", tGrantee) [ ("|" _ ##class(OcuPilot.Test.Http).GetTestUsername() _ "|0|Direct"), "granted by the caller: " _ $ClassMethod(tProbe, "Rows", tGrantee))
        Do $$$AssertEquals(..Wire(tScreen, ..Body("revoke-sql", tGrantee), .tAnswer), "200 ", tScreen _ "'s revoke-sql answers 200: " _ ..Text(tAnswer))
        Do $$$AssertEquals($ClassMethod(tProbe, "Direct", tGrantee, tObject, "SELECT"), 0, "and the row is gone")

        Set tSC = $ClassMethod(tProbe, "Mint", $List(tCase, 3), tGrantee, ..Args(tGrantee, "SELECT", 1), .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusOK(tSC, "the agent's grant with the grant option is minted (" _ tProblem _ ")")
        Do $$$AssertEquals($Select($IsObject($Get(tProposal)): tProposal.%Get("changed").%Size() _ " " _ tProposal.%Get("changed").%Get(0).%Get("field") _ "|" _ tProposal.%Get("changed").%Get(0).%Get("before") _ "|" _ tProposal.%Get("changed").%Get(0).%Get("after"), 1: ""), "1 Privilege|Not held|SELECT on table " _ tObject _ " in USER, with the grant option", "whose card names the privilege")
        Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and confirmed")
        Do $$$AssertEquals($ClassMethod(tProbe, "Direct", tGrantee, tObject, "SELECT"), 2, "the privilege is held directly with the grant option")
        Set tSC = $ClassMethod(tProbe, "Mint", $List(tCase, 4), tGrantee, ..Args(tGrantee, "SELECT", 0), .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusOK(tSC, "the agent's revoke is minted (" _ tProblem _ ")")
        Do $$$AssertTrue(tProposal.%Get("changed").%Get(0).%Get("before") [ "granted by " _ $Username, "its card names the grantor: " _ tProposal.%Get("changed").%Get(0).%Get("before"))
        Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and confirmed")
        Do $$$AssertEquals($ClassMethod(tProbe, "Direct", tGrantee, tObject, "SELECT"), 0, "the row is gone")
    }
}

/// <p>C2: a direct privilege another account granted is revoked, over the wire, by a caller who is not its
/// grantor, the revoke naming that grantor; a privilege the instance reads as granted by several accounts is
/// revoked once for each, in order, with <code>asGrantor</code> naming it; and a privilege held through a role
/// stays, shown with no revoke offered.</p>
/// <p>Mutation (Rule 19): drop <code>asGrantor</code> from the port's revoke -- the first leg goes red.</p>
Method TestARevokeNamesEveryGrantor()
{
    Set tProbe = ..#PROBE
    Set tUser = $Parameter(tProbe, "USER")
    Set tObject = $Parameter(tProbe, "TABLE")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "Grant", tUser, "TABLE", tObject, "SELECT"), "a direct privilege granted by the running account")
    Do $$$AssertTrue($ClassMethod(tProbe, "Rows", tUser) [ ("|" _ $Username _ "|0|Direct"), "listed as granted by it")
    Do $$$AssertEquals(..Wire("permissions.users", ..Body("grant-sql", tUser), .tAnswer), "409 SQLPRIV.HELD", "another grant of it is refused as held")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "Grant", $Parameter(tProbe, "ROLE"), "TABLE", tObject, "SELECT"), "and the role holds it")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "GiveRole"), "given to the user")
    Do $$$AssertEquals(..Wire("permissions.users", ..Body("revoke-sql", tUser), .tAnswer), "200 ", "the wire's account, who did not grant it, revokes it: " _ ..Text(tAnswer))
    Do $$$AssertEquals($ClassMethod(tProbe, "Direct", tUser, tObject, "SELECT"), 0, "no direct row is left")
    Do $$$AssertTrue($ZConvert($ClassMethod(tProbe, "Rows", tUser), "U") [ ("|ROLE:" _ $ZConvert($Parameter(tProbe, "ROLE"), "U")), "and the role's row stays, held through the role")
    Do $$$AssertEquals(..Wire("permissions.users", ..Body("revoke-sql", tUser), .tAnswer), "409 SQLPRIV.NOTHELD", "so a revoke of it finds nothing direct")

    Set tSeam = ..#SEAM
    Do $ClassMethod(tSeam, "Clear")
    Do $ClassMethod(tSeam, "ArmRows", [{"Type": "TABLE", "Object": (tObject), "Action": "SELECT", "GrantedBy": "OcuSqlPrivProbeGrantorB", "GrantOption": false, "GrantedVia": "Direct"}, {"Type": "VIEW", "Object": (tObject), "Action": "SELECT", "GrantedBy": "OcuSqlPrivProbeGrantorA", "GrantOption": true, "GrantedVia": "Direct"}, {"Type": "TABLE", "Object": (tObject), "Action": "SELECT", "GrantedBy": "OcuSqlPrivProbeGrantorC", "GrantOption": false, "GrantedVia": "Role:OcuSqlPrivProbeR"}])
    Kill tQuery
    Set tQuery("grantee") = tUser
    Set tQuery("namespace") = "USER"
    Set tQuery("type") = "TABLE"
    Set tQuery("object") = tObject
    Set tQuery("action") = "SELECT"
    Set tSC = $ClassMethod(tSeam, "Invoke", ..#ENDPOINT, "REVOKESTATE", .tQuery, "", .tState, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tState.%Get("Rows") _ " " _ tState.%Get("GrantOption") _ " " _ tState.%Get("GrantedBy"), "200 2 1 OcuSqlPrivProbeGrantorA,OcuSqlPrivProbeGrantorB", "two direct rows, a table and a view counted alike, their distinct grantors sorted; the role's row is no grantor of one")
    Set tSC = $ClassMethod(tSeam, "Invoke", ..#ENDPOINT, "REVOKE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the revoke is sent")
    Do $$$AssertEquals($ClassMethod(tSeam, "Writes"), "REVOKE:" _ tUser _ ":OcuSqlPrivProbeGrantorA,REVOKE:" _ tUser _ ":OcuSqlPrivProbeGrantorB", "once for each grantor, in order, naming it")
}

/// <p>The matrix's Preconditions row: a grant already held, a revoke with nothing direct and a grantee holding
/// <code>%All</code> are refused on both callers with their own codes and nothing sent; a proposal minted and
/// then overtaken is closed as a moved target.</p>
/// <p>Mutation (Rule 19): drop <code>PRECONDITIONCODES</code> from <class>OcuPilot.Screen.Tool.UserSqlGrant</class>
/// -- the moved-target leg goes red.</p>
Method TestThePreconditionsAreRefusedBeforeAnythingIsSent()
{
    Set tProbe = ..#PROBE
    Set tUser = $Parameter(tProbe, "USER")
    Set tObject = $Parameter(tProbe, "TABLE")
    Do $$$AssertEquals(..Wire("permissions.users", ..Body("revoke-sql", tUser), .tAnswer), "409 SQLPRIV.NOTHELD", "a revoke of what is not held is refused")
    Set tSC = $ClassMethod(tProbe, "Mint", ..#USERREVOKE, tUser, ..Args(tUser, "SELECT", 0), .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals(tHttp _ " " _ tProblem, "409 SQLPRIV.NOTHELD", "and the agent's mint of it")
    Set tSC = $ClassMethod(tProbe, "Mint", ..#USERGRANT, tUser, ..Args(tUser, "SELECT", 0), .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "a grant is minted")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "Grant", tUser, "TABLE", tObject, "SELECT"), "and the privilege is granted before it is confirmed")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "409 " _ ##class(OcuPilot.Kernel.Proposal.Write).#TARGETCHANGED, "the confirm closes it as a moved target")
    Do $$$AssertEquals(..Wire("permissions.users", ..Body("grant-sql", tUser), .tAnswer), "409 SQLPRIV.HELD", "a grant of what is held is refused")
    Set tSC = $ClassMethod(tProbe, "Mint", ..#USERGRANT, tUser, ..Args(tUser, "SELECT", 0), .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals(tHttp _ " " _ tProblem, "409 SQLPRIV.HELD", "and the agent's mint of it")
    Do $$$AssertEquals(..Wire("permissions.users", ..Body("grant-sql", tUser, "SELECT", "true"), .tAnswer), "200 ", "a grant with the option on top is not refused")
    Do $$$AssertEquals($ClassMethod(tProbe, "Direct", tUser, tObject, "SELECT"), 2, "and raises the grant option")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "GiveAll", 1), "the grantee is given %All")
    Do $$$AssertEquals(..Wire("permissions.users", ..Body("grant-sql", tUser, "INSERT"), .tAnswer), "409 SQLPRIV.SUPERUSER", "a grant to an %All holder is refused")
    Do $$$AssertEquals(..Wire("permissions.users", ..Body("revoke-sql", tUser), .tAnswer), "409 SQLPRIV.SUPERUSER", "and a revoke from one")
    Set tSC = $ClassMethod(tProbe, "Mint", ..#USERGRANT, tUser, ..Args(tUser, "INSERT", 0), .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals(tHttp _ " " _ tProblem, "409 SQLPRIV.SUPERUSER", "and the agent's mint")
    Do $ClassMethod(tProbe, "GiveAll", 0)
}

/// <p>A schema grant is judged by the schema's rows for the action: it lists as one row for each object that
/// takes the action, a revoke removes them, and a vendor answer that moved nothing is refused as not applied.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Port.SqlPrivilegePort.Facts</method> count a schema's
/// <code>Direct</code> rows instead of its <code>Schema Privilege</code> rows -- the wire grant leg goes red.</p>
Method TestASchemaGrantIsJudgedByItsRows()
{
    Set tProbe = ..#PROBE
    Set tUser = $Parameter(tProbe, "USER")
    Set tSchema = $Parameter(tProbe, "SCHEMA")
    Set tBody = ..Body("grant-sql", tUser, "UPDATE")
    Do tBody.values.%Set("Type", "SCHEMA")
    Do tBody.values.%Set("Object", tSchema)
    Do $$$AssertEquals(..Wire("permissions.users", tBody, .tAnswer), "200 ", "a schema grant is made: " _ ..Text(tAnswer))
    Set tRows = $ZConvert($ClassMethod(tProbe, "Rows", tUser), "U")
    Do $$$AssertTrue((tRows [ "|UPDATE|") && (tRows [ "|SCHEMA PRIVILEGE"), "and lists as the schema's rows: " _ tRows)
    Set tRevoke = ..Body("revoke-sql", tUser, "UPDATE")
    Do tRevoke.values.%Set("Type", "SCHEMA")
    Do tRevoke.values.%Set("Object", tSchema)
    Do $$$AssertEquals(..Wire("permissions.users", tRevoke, .tAnswer), "200 ", "a schema revoke removes them: " _ ..Text(tAnswer))
    Do $$$AssertTrue($ZConvert($ClassMethod(tProbe, "Rows", tUser), "U") '[ "|UPDATE|", "none is left")
    Do $ClassMethod(..#SEAM, "ArmNoop", "GRANT")
    Kill tQuery
    Set tQuery("grantee") = tUser
    Set tQuery("namespace") = "USER"
    Set tQuery("type") = "SCHEMA"
    Set tQuery("object") = tSchema
    Set tQuery("action") = "UPDATE"
    Set tSC = $ClassMethod(..#SEAM, "Invoke", ..#ENDPOINT, "GRANT", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "409 SQLPRIV.NOTAPPLIED", "a schema grant the vendor answers 200 and does not make is not applied")
}

/// <p>C3: a grant or revoke the vendor answers 200 and does not make reads 409 <code>SQLPRIV.NOTAPPLIED</code>,
/// never applied, and the seam refuses any write outside the probe; the vendor's own refusals -- an absent object, an
/// absent grantee, an absent procedure -- are 404s in OcuPilot's words with the vendor's text unsent.</p>
/// <p>Mutation (Rule 19): skip the second read in <method>OcuPilot.Port.SqlPrivilegePort.Grant</method> -- the
/// no-op legs go red.</p>
Method TestAWriteThatMovedNothingIsRefusedAsNotApplied()
{
    Set tProbe = ..#PROBE
    Set tSeam = ..#SEAM
    Set tUser = $Parameter(tProbe, "USER")
    Set tObject = $Parameter(tProbe, "TABLE")
    Kill tQuery
    Set tQuery("grantee") = tUser
    Set tQuery("namespace") = "USER"
    Set tQuery("type") = "TABLE"
    Set tQuery("object") = tObject
    Set tQuery("action") = "SELECT"
    Do $ClassMethod(tSeam, "ArmNoop", "GRANT")
    Set tSC = $ClassMethod(tSeam, "Invoke", ..#ENDPOINT, "GRANT", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tFault.%Get("code"), "409 SQLPRIV.NOTAPPLIED", "a grant the vendor answers 200 and does not make is not applied")
    Do $$$AssertEquals($ClassMethod(tSeam, "Writes"), "GRANT:" _ tUser _ ":", "after exactly one vendor call")
    Do $$$AssertEquals($Get(^||OcuPilotSqlPrivSeam("includeSystem")), 1, "the state is read with system objects included, so a grant on a system schema's object reads back")
    Do $$$AssertEquals($ClassMethod(tProbe, "Direct", tUser, tObject, "SELECT"), 0, "and nothing was granted")
    Kill ^||OcuPilotSqlPrivSeam("noop")
    Set tSC = $ClassMethod(tSeam, "Invoke", ..#ENDPOINT, "GRANT", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the same grant, sent for real, is made")
    Do $ClassMethod(tSeam, "ArmNoop", "REVOKE")
    Set tSC = $ClassMethod(tSeam, "Invoke", ..#ENDPOINT, "REVOKE", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tFault.%Get("code"), "409 SQLPRIV.NOTAPPLIED", "a revoke the vendor answers 200 and does not make is not applied")
    Do $$$AssertEquals($ClassMethod(tProbe, "Direct", tUser, tObject, "SELECT"), 1, "and the row stays")
    Kill ^||OcuPilotSqlPrivSeam("noop")
    Set tQuery("object") = "OcuPilot_Kernel_State.Turn"
    Set tSC = $ClassMethod(tSeam, "Invoke", ..#ENDPOINT, "GRANT", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), "409 " _ $Parameter(tSeam, "GUARDCODE"), "the seam sends no write outside the probe")
    Do $$$AssertTrue($ClassMethod(tSeam, "Refused"), "and marks that it refused one")
    Set tQuery("object") = $Parameter(tProbe, "SCHEMA") _ ".NoSuchTable"
    Set tSC = $ClassMethod(tSeam, "Invoke", ..#ENDPOINT, "GRANT", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tFault.%Get("code"), "404 SQLPRIV.NOOBJECT", "a table the instance does not hold is refused in OcuPilot's words")
    Do $$$AssertTrue($IsObject(tFault) && (tFault.%ToJSON() '[ "SQLCODE"), "without the vendor's text")
    Set tQuery("object") = $Parameter(tProbe, "SCHEMA") _ ".NoSuchProc"
    Set tQuery("type") = "STORED PROCEDURE"
    Set tQuery("action") = "EXECUTE"
    Set tSC = $ClassMethod(tSeam, "Invoke", ..#ENDPOINT, "GRANT", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tFault.%Get("code"), "404 SQLPRIV.NOOBJECT", "and a procedure it does not hold")
    Set tQuery("grantee") = "OcuSqlPrivProbeNoSuchGrantee"
    Set tQuery("type") = "TABLE"
    Set tQuery("object") = tObject
    Set tQuery("action") = "SELECT"
    Set tSC = $ClassMethod(tSeam, "Invoke", ..#ENDPOINT, "GRANT", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ tFault.%Get("code"), "404 SQLPRIV.NOGRANTEE", "and a grantee it does not hold")
}

/// <p>C4: every Rules case is refused 422 <code>SQLPRIV.VALIDATION</code> on the field it is about, by the screen's
/// route and by the agent's mint, with nothing granted; a grant option that is not boolean is refused by the
/// route's value handling; an undefined namespace is refused on its field.</p>
/// <p>Mutation (Rule 19): drop the namespace check from <method>OcuPilot.Port.SqlPrivilegePort.Violations</method>
/// -- the namespace leg goes red.</p>
Method TestTheRulesAreRefusedOnBothCallersBeforeAnythingIsSent()
{
    Set tProbe = ..#PROBE
    Set tUser = $Parameter(tProbe, "USER")
    For tCase = $ListBuild("Namespace", "NoSuchNs", "SQLPRIV.NAMESPACE"), $ListBuild("Type", "COLUMN", "SQLPRIV.TYPE"), $ListBuild("Object", $Parameter(tProbe, "SCHEMA") _ ".*", "SQLPRIV.OBJECT"), $ListBuild("Object", $Parameter(tProbe, "TABLE") _ ",T2", "SQLPRIV.OBJECT"), $ListBuild("Action", "SELECT,INSERT", "SQLPRIV.ACTION"), $ListBuild("Action", "ALTER", "SQLPRIV.ACTION") {
        Set tBody = ..Body("grant-sql", tUser)
        Do tBody.values.%Set($List(tCase, 1), $List(tCase, 2))
        Do $$$AssertEquals(..Wire("permissions.users", tBody, .tAnswer), "422 SQLPRIV.VALIDATION", "the route refuses " _ $List(tCase, 1) _ " " _ $List(tCase, 2))
        Set tViolation = $Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("detail")): tAnswer.%Get("detail").%Get("violations").%Get(0), 1: {})
        Do $$$AssertEquals(tViolation.%Get("field") _ " " _ tViolation.%Get("code"), $List(tCase, 1) _ " " _ $List(tCase, 3), "on the field it is about")
        Set tArgs = ..Args(tUser, "SELECT", 0)
        Do tArgs.%Set($List(tCase, 1), $List(tCase, 2))
        Set tSC = $ClassMethod(tProbe, "Mint", ..#USERGRANT, tUser, tArgs, .tProposal, .tHttp, .tProblem)
        Do $$$AssertEquals(tHttp _ " " _ tProblem, "422 SQLPRIV.VALIDATION", "the agent's mint refuses it too")
    }
    Set tBody = ..Body("grant-sql", tUser, "SELECT", "maybe")
    Do $$$AssertEquals(..Wire("permissions.users", tBody, .tAnswer), "400 TOOL.ARGUMENTS", "a grant option that is not true or false is refused by the route")
    Do $$$AssertEquals($ClassMethod(tProbe, "Rows", tUser), "", "nothing was granted along the way")
    Set tSchema = $ClassMethod(..#USERGRANT, "InputSchema")
    Set tArgs = ..Args(tUser, "SELECT", 0)
    Do tArgs.%Set("Type", "COLUMN")
    Do $$$AssertStatusNotOK(##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(tSchema, tArgs, .tProblem), "a type outside the six is refused by the tool's own schema before a mint")
    Do tArgs.%Set("Type", "TABLE")
    Do tArgs.%Set("Column", "ID")
    Do $$$AssertStatusNotOK(##class(OcuPilot.Screen.Tool.Registry).ValidateArguments(tSchema, tArgs, .tProblem), "and so is an argument it does not declare")
}

/// <p>C5, AD-10 (DW-236): a grant or revoke on an object of OcuPilot's own schema, or for one of OcuPilot's own
/// roles or <code>%DB_OCUPILOT</code>, is refused by code on both callers and nothing is sent; the installer's
/// grants of OcuPilot's own tables to <code>%DB_OCUPILOT</code> read as they did.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Proposal.Prohibited.SqlPrivilege</method> skip
/// <method>IsOcuPilotCode</method> -- the object legs go red.</p>
Method TestOcuPilotsOwnSchemaAndRolesAreRefusedOnBothCallers()
{
    Set tProbe = ..#PROBE
    Set tUser = $Parameter(tProbe, "USER")
    Set tNamespace = ##class(OcuPilot.Install.Installer).ResolveNamespace()
    Set tOwn = "OcuPilot_Kernel_State"
    Set tTable = tOwn _ ".Turn"
    Set tBefore = $ClassMethod(tProbe, "RowsOf", "%DB_OCUPILOT", tNamespace, tOwn)
    Do $$$AssertTrue((tBefore '= "") && (tBefore '= "unreadable"), "the installer's grants of OcuPilot's own tables to %DB_OCUPILOT are listed: " _ $Extract(tBefore, 1, 160))
    ; The probe user is made to hold a direct privilege on OcuPilot's own table by the running account, so that a
    ; revoke gets as far as the prohibited set; it is revoked again below.
    Do $$$AssertStatusOK($ClassMethod(tProbe, "Grant", tUser, "TABLE", tTable, "SELECT", 0, tNamespace), "the probe user holds a direct privilege on OcuPilot's own table")
    Set tBody = ..Body("revoke-sql", tUser)
    Do tBody.values.%Set("Namespace", tNamespace)
    Do tBody.values.%Set("Object", tTable)
    Do $$$AssertEquals(..Wire("permissions.users", tBody, .tAnswer), "403 PROHIBITED.OCUPILOTSQLPRIVILEGE", "a revoke on OcuPilot's own table is refused by the route")
    Set tBody = ..Body("grant-sql", tUser, "UPDATE")
    Do tBody.values.%Set("Namespace", tNamespace)
    Do tBody.values.%Set("Object", tTable)
    Do $$$AssertEquals(..Wire("permissions.users", tBody, .tAnswer), "403 PROHIBITED.OCUPILOTSQLPRIVILEGE", "and so is a grant")
    Set tBody = ..Body("grant-sql", "%DB_OCUPILOT")
    Do $$$AssertEquals(..Wire("permissions.roles", tBody, .tAnswer), "403 PROHIBITED.OCUPILOTROLE", "a grant for %DB_OCUPILOT is refused under the role arm")
    Set tBody = ..Body("grant-sql", "OcuPilotAdmin")
    Do $$$AssertEquals(..Wire("permissions.roles", tBody, .tAnswer), "403 PROHIBITED.OCUPILOTROLE", "and for OcuPilot's administrative role")
    Set tArgs = ..Args("%DB_OCUPILOT", "SELECT", 0)
    Do tArgs.%Set("Type", "SCHEMA")
    Do tArgs.%Set("Namespace", tNamespace)
    Do tArgs.%Set("Object", tOwn)
    Set tSC = $ClassMethod(tProbe, "Mint", ..#ROLEREVOKE, "%DB_OCUPILOT", tArgs, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's revoke of the installer's schema grant is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "403 PROHIBITED.OCUPILOTROLE", "and its confirm is refused under the role arm")
    Set tArgs = ..Args(tUser, "SELECT", 0)
    Do tArgs.%Set("Namespace", tNamespace)
    Do tArgs.%Set("Object", tTable)
    Set tSC = $ClassMethod(tProbe, "Mint", ..#USERREVOKE, tUser, tArgs, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's revoke of the probe user's privilege on OcuPilot's own table is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "403 PROHIBITED.OCUPILOTSQLPRIVILEGE", "and its confirm is refused under the schema arm")
    Do $$$AssertEquals($ClassMethod(tProbe, "RowsOf", "%DB_OCUPILOT", tNamespace, tOwn), tBefore, "the installer's grants read back unchanged")
    Do $$$AssertTrue($ClassMethod(tProbe, "RowsOf", tUser, tNamespace, tOwn) [ "|SELECT|", "and the probe user's own privilege stays")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "Revoke", tUser, "TABLE", tTable, "SELECT", tNamespace), "revoked by the running account")
    Do $$$AssertEquals($ClassMethod(tProbe, "RowsOf", tUser, tNamespace, tOwn), "", "and none is left")
}

/// <p>Integration: the route's body is closed -- an unknown action, a missing value, an extra value and a value that
/// is not a string are each refused before anything is read -- and the two lists answer the action over the wire for
/// a grantee the list does not hold as a 404.</p>
Method TestTheRoutesAnswerAndKeepTheirBodiesClosed()
{
    Set tProbe = ..#PROBE
    Set tUser = $Parameter(tProbe, "USER")
    Do $$$AssertEquals(..Wire("permissions.users", {"action": "grant-columns", "id": (tUser), "values": {}}, .tAnswer), "404 ROUTE.NOTFOUND", "an action the list does not declare is not a route")
    Set tBody = ..Body("grant-sql", tUser)
    Do tBody.values.%Remove("Action")
    Do $$$AssertEquals(..Wire("permissions.users", tBody, .tAnswer), "400 TOOL.ARGUMENTS", "a missing value is refused")
    Set tBody = ..Body("grant-sql", tUser)
    Do tBody.values.%Set("Grantor", "SYS")
    Do $$$AssertEquals(..Wire("permissions.users", tBody, .tAnswer), "400 TOOL.ARGUMENTS", "an extra value is refused")
    Set tBody = ..Body("revoke-sql", tUser)
    Do tBody.values.%Set("WithGrant", "true")
    Do $$$AssertEquals(..Wire("permissions.users", tBody, .tAnswer), "400 TOOL.ARGUMENTS", "a revoke takes no grant option")
    Set tBody = ..Body("grant-sql", tUser)
    Do tBody.values.%Set("Namespace", 5, "number")
    Do $$$AssertEquals(..Wire("permissions.users", tBody, .tAnswer), "400 TOOL.ARGUMENTS", "a value that is not a string is refused")
    Do $$$AssertEquals(..Wire("permissions.users", ..Body("grant-sql", "OcuSqlPrivProbeNoSuchUser"), .tAnswer), "404 SQLPRIV.NOGRANTEE", "a grantee the instance does not hold is 404")
    Do $$$AssertEquals(..Wire("permissions.roles", ..Body("grant-sql", $Parameter(tProbe, "ROLE")), .tAnswer), "200 ", "a probe role is granted through the Roles list")
    Do $$$AssertEquals($ClassMethod(tProbe, "Rows", tUser), "", "the probe user holds nothing of it")
}

/// <p>The body of the screen action <var>pAction</var> for the grantee <var>pGrantee</var>: the probe table in
/// <code>USER</code> with <var>pPrivilege</var>, and on a grant the grant option <var>pWithGrant</var>
/// (<code>true</code> or <code>false</code>).</p>
ClassMethod Body(pAction As %String, pGrantee As %String, pPrivilege As %String = "SELECT", pWithGrant As %String = "false") As %DynamicObject
{
    Set tValues = {"Namespace": "USER", "Type": "TABLE", "Object": ($Parameter(..#PROBE, "TABLE")), "Action": (pPrivilege)}
    If pAction = "grant-sql" Do tValues.%Set("WithGrant", pWithGrant)
    Quit {"action": (pAction), "id": (pGrantee), "values": (tValues)}
}

/// <p>The agent's arguments for the probe table: <var>pPrivilege</var>, and the grant option <var>pWithGrant</var>
/// (a revoke's schema admits none, so it is left out where <code>0</code> and the tool is a revoke's by
/// the caller).</p>
ClassMethod Args(pGrantee As %String, pPrivilege As %String, pWithGrant As %Boolean) As %DynamicObject
{
    Set tArgs = $ClassMethod(..#PROBE, "Args", pGrantee, $Parameter(..#PROBE, "TABLE"), pPrivilege)
    If pWithGrant Do tArgs.%Set("WithGrant", 1, "boolean")
    Quit tArgs
}

/// <p>POST <var>pBody</var> to the screen <var>pScreen</var>'s action route over the wire, answered as
/// <code>status code</code>, with the parsed answer in <var>pAnswer</var>.</p>
ClassMethod Wire(pScreen As %String, pBody As %DynamicObject, Output pAnswer As %DynamicObject) As %String
{
    Set pAnswer = ""
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/screens/" _ pScreen _ "/action", .tStatus, .pAnswer, pBody.%ToJSON(), "application/json")
    Quit $Get(tStatus) _ " " _ $Select($IsObject($Get(pAnswer)): pAnswer.%Get("code"), 1: "")
}

/// <p>An answer's JSON, trimmed, for a failure message.</p>
ClassMethod Text(pAnswer As %DynamicObject) As %String
{
    Quit $Select($IsObject(pAnswer): $Extract(pAnswer.%ToJSON(), 1, 300), 1: "")
}

}
