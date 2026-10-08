/// <p>Pins Story 18.28's column privileges on both callers of each tool: the Users and Roles lists' row actions
/// <code>grant-sql</code> and <code>revoke-sql</code> with a <code>Column</code>, over the wire, and the agent's mint
/// and confirm, for a probe user and a probe role -- a grant stored and read back as a <code>Direct</code> column
/// row, a grant option raised, a revoke that names the grantor of the row it removes (another account's
/// included), an object spelled in any case or a view sent as a table landing on the instance's own spelling and
/// type, a column the instance does not hold or a grantor without the privilege refused as not applied, an unknown
/// grantee refused before the vendor stores a row for it, every Rules case refused, and OcuPilot's own schema and
/// roles refused with a column.</p>
/// <p>Every write is real for a grantee and an object named <code>OcuSqlPrivProbe...</code>.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, a <code>USER</code> namespace, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates and removes a probe user
/// and role, a probe principal and a probe schema's objects and sets the governance policy. Every probe object is
/// removed by exact name before all, after each and after all.</p>
Class OcuPilot.Test.SqlColumnPrivilegeWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the writes, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter PROBE = "OcuPilot.Test.SqlPrivilegeProbe";

Parameter PRINCIPAL = "OcuPilot.Test.AuthOptionsProbe";

Parameter WRITE = "OcuPilot.Test.SqlPrivilegeWrite";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter PORT = "OcuPilot.Port.SqlPrivilegePort";

Parameter USERGRANT = "OcuPilot.Screen.Tool.UserSqlGrant";

Parameter USERREVOKE = "OcuPilot.Screen.Tool.UserSqlRevoke";

Parameter ROLEGRANT = "OcuPilot.Screen.Tool.RoleSqlGrant";

Parameter ROLEREVOKE = "OcuPilot.Screen.Tool.RoleSqlRevoke";

Parameter USERS = "permissions.users";

Parameter ROLES = "permissions.roles";

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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlColumnPrivilegeWrite grants and revokes SQL column privileges for a probe user and role on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuProbe1828Col" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
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
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Remaining"), 0, "and none is left")
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

/// <p>C1: for a probe user and a probe role, on the screen's row action over the wire and on the agent's proposal,
/// a column grant is stored and read back as a <code>Direct</code> column row, a re-grant with the grant option
/// raises it, a grant of what is held is refused, and a revoke removes it; the card names the column.</p>
/// <p>Mutation (Rule 19): remove <code>Column</code> from
/// <method>OcuPilot.Screen.Tool.SqlPrivilegeWrite.PortQuery</method> -- every leg here goes red.</p>
Method TestAColumnGrantAndRevokeRoundTripOnBothCallers()
{
    Set tProbe = ..#PROBE
    Set tObject = $Parameter(tProbe, "TABLE")
    For tCase = $ListBuild(..#USERS, $Parameter(tProbe, "USER"), ..#USERGRANT, ..#USERREVOKE), $ListBuild(..#ROLES, $Parameter(tProbe, "ROLE"), ..#ROLEGRANT, ..#ROLEREVOKE) {
        Set tScreen = $List(tCase, 1)
        Set tGrantee = $List(tCase, 2)
        Do $$$AssertEquals($ClassMethod(tProbe, "ColumnDirect", tGrantee, tObject, "ID", "SELECT"), 0, tGrantee _ " holds no column privilege to begin with")
        Do $$$AssertEquals(..Wire(tScreen, ..Body("grant-sql", tGrantee), .tAnswer), "200 ", tScreen _ "'s grant-sql with a column answers 200: " _ ..Text(tAnswer))
        Do $$$AssertEquals(tAnswer.%Get("action") _ " " _ tAnswer.%Get("target").%Get("type") _ " " _ tAnswer.%Get("readBack").%Get("verdict"), "updated " _ $Select(tScreen [ "users": "user", 1: "role") _ " nothingSent", "an updated change event for the grantee, nothing sent as a body")
        Do $$$AssertEquals($ClassMethod(tProbe, "ColumnDirect", tGrantee, tObject, "ID", "SELECT"), 1, "the column privilege is held directly")
        Do $$$AssertTrue($ClassMethod(tProbe, "ColumnRows", tGrantee, tObject) [ ("ID|SELECT|" _ ##class(OcuPilot.Test.Http).GetTestUsername() _ "|0|Direct"), "granted by the caller: " _ $ClassMethod(tProbe, "ColumnRows", tGrantee, tObject))
        Do $$$AssertEquals($ClassMethod(tProbe, "Direct", tGrantee, tObject, "SELECT"), 0, "and no row of the whole table is made")
        Do $$$AssertEquals(..Wire(tScreen, ..Body("grant-sql", tGrantee), .tAnswer), "409 SQLPRIV.HELD", "a grant of what is held is refused")
        Do $$$AssertEquals(..Wire(tScreen, ..Body("grant-sql", tGrantee, "SELECT", "true"), .tAnswer), "200 ", "a re-grant with the grant option is made: " _ ..Text(tAnswer))
        Do $$$AssertEquals($ClassMethod(tProbe, "ColumnDirect", tGrantee, tObject, "ID", "SELECT"), 2, "and raises the grant option")
        Do $$$AssertEquals(..Wire(tScreen, ..Body("revoke-sql", tGrantee), .tAnswer), "200 ", tScreen _ "'s revoke-sql answers 200: " _ ..Text(tAnswer))
        Do $$$AssertEquals($ClassMethod(tProbe, "ColumnDirect", tGrantee, tObject, "ID", "SELECT"), 0, "and the row is gone")
        Do $$$AssertEquals(..Wire(tScreen, ..Body("revoke-sql", tGrantee), .tAnswer), "409 SQLPRIV.NOTHELD", "a second revoke finds nothing direct")

        Set tSC = $ClassMethod(tProbe, "Mint", $List(tCase, 3), tGrantee, ..ColumnArgs(tGrantee, 1), .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusOK(tSC, "the agent's column grant with the grant option is minted (" _ tProblem _ ")")
        Do $$$AssertEquals($Select($IsObject($Get(tProposal)): tProposal.%Get("changed").%Size() _ " " _ tProposal.%Get("changed").%Get(0).%Get("field") _ "|" _ tProposal.%Get("changed").%Get(0).%Get("before") _ "|" _ tProposal.%Get("changed").%Get(0).%Get("after"), 1: ""), "1 Privilege|Not held|SELECT on column ID of table " _ tObject _ " in USER, with the grant option", "whose card names the column")
        Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and confirmed")
        Do $$$AssertEquals($ClassMethod(tProbe, "ColumnDirect", tGrantee, tObject, "ID", "SELECT"), 2, "the column privilege is held directly with the grant option")
        Set tSC = $ClassMethod(tProbe, "Mint", $List(tCase, 4), tGrantee, ..ColumnArgs(tGrantee, 0), .tProposal, .tHttp, .tProblem)
        Do $$$AssertStatusOK(tSC, "the agent's revoke is minted (" _ tProblem _ ")")
        Do $$$AssertTrue(tProposal.%Get("changed").%Get(0).%Get("before") [ ("SELECT on column ID of table " _ tObject _ " in USER, granted by " _ $Username), "its card names the column and the grantor: " _ tProposal.%Get("changed").%Get(0).%Get("before"))
        Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and confirmed")
        Do $$$AssertEquals($ClassMethod(tProbe, "ColumnDirect", tGrantee, tObject, "ID", "SELECT"), 0, "the row is gone")
    }
    Do $$$AssertEquals($ClassMethod(tProbe, "ColumnRows", $Parameter(tProbe, "USER"), tObject), "", "nothing is left of the column rows")
}

/// <p>C1: the object and the column are matched in any letter case; the object is sent as the instance spells it,
/// and a view sent as a table lands on the view -- on the wire and on the agent's proposal.</p>
/// <p>Mutation (Rule 19): send the object as given in <method>OcuPilot.Port.SqlPrivilegePort.ColumnTally</method>
/// -- the lower-case revoke leg goes red (the instance's column revoke matches the object's case).</p>
Method TestTheObjectIsSpelledAndTypedByTheInstance()
{
    Set tProbe = ..#PROBE
    Set tUser = $Parameter(tProbe, "USER")
    Set tTable = $Parameter(tProbe, "TABLE")
    Set tLower = $ZConvert(tTable, "L")
    Set tBody = ..Body("grant-sql", tUser, "SELECT", "false", tLower, "id")
    Do $$$AssertEquals(..Wire(..#USERS, tBody, .tAnswer), "200 ", "a grant naming the table and the column in lower case is made: " _ ..Text(tAnswer))
    Do $$$AssertEquals($ClassMethod(tProbe, "ColumnDirect", tUser, tTable, "ID", "SELECT"), 1, "and stored under the instance's spelling")
    Do $$$AssertEquals(..Wire(..#USERS, tBody, .tAnswer), "409 SQLPRIV.HELD", "so the same grant again reads as held, whatever the case")
    Set tRevoke = ..Body("revoke-sql", tUser, "SELECT", "false", tLower, "id")
    Do $$$AssertEquals(..Wire(..#USERS, tRevoke, .tAnswer), "200 ", "and a revoke in lower case removes it: " _ ..Text(tAnswer))
    Do $$$AssertEquals($ClassMethod(tProbe, "ColumnDirect", tUser, tTable, "ID", "SELECT"), 0, "the row is gone")
    Set tSC = $ClassMethod(tProbe, "Mint", ..#USERGRANT, tUser, ..ColumnArgs(tUser, 0, tLower, "id"), .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's grant in lower case is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and confirmed")
    Do $$$AssertEquals($ClassMethod(tProbe, "ColumnDirect", tUser, tTable, "ID", "SELECT"), 1, "it lands on the table")
    Set tSC = $ClassMethod(tProbe, "Mint", ..#USERREVOKE, tUser, ..ColumnArgs(tUser, 0, tLower, "id"), .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "200 ", "and its lower-case revoke is confirmed")
    Do $$$AssertEquals($ClassMethod(tProbe, "ColumnDirect", tUser, tTable, "ID", "SELECT"), 0, "and removes it")

    Set tView = $Parameter(tProbe, "VIEW")
    Set tBody = ..Body("grant-sql", tUser, "SELECT", "false", tView, "ID")
    Do $$$AssertEquals(tBody.values.%Get("Type"), "TABLE", "a view is sent as a TABLE")
    Do $$$AssertEquals(..Wire(..#USERS, tBody, .tAnswer), "200 ", "and the grant is made: " _ ..Text(tAnswer))
    Do $$$AssertEquals($ClassMethod(tProbe, "ColumnDirect", tUser, tView, "ID", "SELECT") _ $ClassMethod(tProbe, "ColumnDirect", tUser, tTable, "ID", "SELECT"), "10", "on the view, and not on the table the view selects from")
    Do $$$AssertEquals(..Wire(..#USERS, ..Body("revoke-sql", tUser, "SELECT", "false", tView, "ID"), .tAnswer), "200 ", "and the revoke, sent as a table too, removes it: " _ ..Text(tAnswer))
    Do $$$AssertEquals($ClassMethod(tProbe, "ColumnRows", tUser, tView), "", "the view's column rows are gone")
}

/// <p>C1: a column privilege another account granted is revoked over the wire by a caller who is not its grantor,
/// the revoke naming that grantor; a grantor that holds nothing on the table has its grant refused as not
/// applied, and stores nothing.</p>
/// <p>Mutation (Rule 19): drop <code>asGrantor</code> from the column branch of
/// <method>OcuPilot.Port.SqlPrivilegePort.WriteQuery</method> -- the revoke leg goes red.</p>
Method TestARevokeNamesAnotherGrantor()
{
    Set tProbe = ..#PROBE
    Set tUser = $Parameter(tProbe, "USER")
    Set tTable = $Parameter(tProbe, "TABLE")
    Set tPrincipal = $List($ClassMethod(..#PRINCIPAL, "Users"), 1)
    Set tSC = $ClassMethod(..#PRINCIPAL, "SeedPrincipal", tPrincipal, $List($ClassMethod(..#PRINCIPAL, "Roles"), 1), ..#RESOURCES, ..PreparedPassword)
    Do $$$AssertStatusOK(tSC, "the probe principal is made")
    Set tBody = ..Body("grant-sql", tUser)
    Do $$$AssertEquals(..WireAs(tPrincipal, ..#USERS, tBody), "409 SQLPRIV.NOTAPPLIED", "a principal who holds nothing on the table has its grant refused as not applied")
    Do $$$AssertEquals($ClassMethod(tProbe, "ColumnRows", tUser, tTable), "", "and nothing is stored")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "Grant", tPrincipal, "TABLE", tTable, "SELECT", 1), "the principal is given SELECT on the table with the grant option")
    Do $$$AssertEquals(..WireAs(tPrincipal, ..#USERS, tBody), "200 ", "and now grants the column")
    Do $$$AssertEquals($ZConvert($ClassMethod(tProbe, "ColumnRows", tUser, tTable), "U"), "ID|SELECT|" _ $ZConvert(tPrincipal, "U") _ "|0|DIRECT", "the row is the principal's")
    Do $$$AssertEquals(..Wire(..#USERS, ..Body("revoke-sql", tUser), .tAnswer), "200 ", "the wire's account, who did not grant it, revokes it: " _ ..Text(tAnswer))
    Do $$$AssertEquals($ClassMethod(tProbe, "ColumnRows", tUser, tTable), "", "and the row is gone")
}

/// <p>C1: a column the table does not hold, and a table the namespace does not hold, are refused as not applied
/// and store nothing; a column grant to a grantee the instance does not hold is refused before the vendor stores a
/// row for it (the instance does store one, which the control leg shows).</p>
/// <p>Mutation (Rule 19): skip the grantee check in <method>OcuPilot.Port.SqlPrivilegePort.Facts</method> -- the
/// unknown-grantee legs go red.</p>
Method TestAnAbsentColumnOrGranteeIsRefusedAndNothingIsStored()
{
    Set tProbe = ..#PROBE
    Set tUser = $Parameter(tProbe, "USER")
    Set tTable = $Parameter(tProbe, "TABLE")
    Do $$$AssertEquals(..Wire(..#USERS, ..Body("grant-sql", tUser, "SELECT", "false", tTable, "NoSuchColumn"), .tAnswer), "409 SQLPRIV.NOTAPPLIED", "an absent column is refused as not applied")
    Do $$$AssertEquals(..Wire(..#USERS, ..Body("grant-sql", tUser, "SELECT", "false", $Parameter(tProbe, "SCHEMA") _ ".NoSuchTable", "ID"), .tAnswer), "409 SQLPRIV.NOTAPPLIED", "and so is an absent table")
    Do $$$AssertEquals($ClassMethod(tProbe, "ColumnRows", tUser, tTable), "", "and nothing is stored")
    Set tNobody = $Parameter(tProbe, "PREFIX") _ "NoSuchGrantee"
    Do $$$AssertEquals(..Wire(..#USERS, ..Body("grant-sql", tNobody), .tAnswer), "404 SQLPRIV.NOGRANTEE", "a column grant to a grantee the instance does not hold is refused naming it")
    Set tSC = $ClassMethod(tProbe, "Mint", ..#USERGRANT, tNobody, ..ColumnArgs(tNobody, 0), .tProposal, .tHttp, .tProblem)
    Do $$$AssertEquals(tHttp, 400, "and the agent's mint reads the port's 404 as an absent target: " _ tProblem)
    Do $$$AssertEquals($ClassMethod(tProbe, "RemainingPrivileges"), 0, "no row is stored for the name")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("grantee") = tNobody
    Set tQuery("type") = "TABLE"
    Set tQuery("object") = tTable
    Set tQuery("action") = "SELECT"
    Set tQuery("column") = "ID"
    Set tSC = ##class(OcuPilot.Port.AdminPort).Invoke("Security.SQLPrivilege.Column", "GRANT", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp, 200, "the control: the instance's own column call, sent to that name, answers 200")
    Do $$$AssertEquals($ClassMethod(tProbe, "RemainingPrivileges"), 1, "and stores a row that no list shows -- the row the port's check keeps from being made")
}

/// <p>C1: a column privilege held through a role is listed with no direct row, so a revoke finds nothing to
/// remove; a column grant for a user whose role holds it is a grant of a direct row.</p>
/// <p>Mutation (Rule 19): count a role's row as a direct one in <method>OcuPilot.Port.SqlPrivilegePort.ColumnTally</method>
/// -- the revoke leg goes red.</p>
Method TestAColumnHeldThroughARoleIsNoDirectRow()
{
    Set tProbe = ..#PROBE
    Set tUser = $Parameter(tProbe, "USER")
    Set tRole = $Parameter(tProbe, "ROLE")
    Set tTable = $Parameter(tProbe, "TABLE")
    Do $$$AssertEquals(..Wire(..#ROLES, ..Body("grant-sql", tRole), .tAnswer), "200 ", "the role is granted the column: " _ ..Text(tAnswer))
    Do $$$AssertStatusOK($ClassMethod(tProbe, "GiveRole"), "and given to the user")
    Do $$$AssertEquals($ClassMethod(tProbe, "ColumnDirect", tUser, tTable, "ID", "SELECT"), 0, "the user holds no direct row")
    Do $$$AssertTrue($ZConvert($ClassMethod(tProbe, "ColumnRows", tUser, tTable), "U") [ ("ID|SELECT|" _ $ZConvert(##class(OcuPilot.Test.Http).GetTestUsername(), "U") _ "|0|ROLE:" _ $ZConvert(tRole, "U")), "but the column is listed, held through the role: " _ $ClassMethod(tProbe, "ColumnRows", tUser, tTable))
    Do $$$AssertEquals(..Wire(..#USERS, ..Body("revoke-sql", tUser), .tAnswer), "409 SQLPRIV.NOTHELD", "so a revoke from the user finds nothing direct")
    Do $$$AssertEquals(..Wire(..#USERS, ..Body("grant-sql", tUser), .tAnswer), "200 ", "and a grant to the user makes a direct row: " _ ..Text(tAnswer))
    Do $$$AssertEquals($ClassMethod(tProbe, "ColumnDirect", tUser, tTable, "ID", "SELECT"), 1, "which is held")
}

/// <p>C3, C4: every column Rules case is refused 422 <code>SQLPRIV.COLUMN</code> on the <code>Column</code> field by
/// the screen's route and by the agent's mint, with nothing granted; a list or a wildcard in the column is refused
/// by the Rules (a wildcard is not a name); OcuPilot's own schema is refused under the schema arm with a column, and
/// OcuPilot's own roles under the role arm, from both callers and with nothing sent.</p>
/// <p>Mutation (Rule 19): make <method>OcuPilot.Kernel.Proposal.Prohibited.SqlPrivilege</method> skip
/// <method>IsOcuPilotCode</method> -- the schema legs go red.</p>
Method TestTheColumnRulesAndOcuPilotsOwnAreRefusedOnBothCallers()
{
    Set tProbe = ..#PROBE
    Set tUser = $Parameter(tProbe, "USER")
    For tCase = $ListBuild("Action", "DELETE"), $ListBuild("Action", "%ALTER"), $ListBuild("Column", "A.B"), $ListBuild("Column", "I D"), $ListBuild("Column", "*"), $ListBuild("Type", "SCHEMA") {
        Set tBody = ..Body("grant-sql", tUser)
        Do tBody.values.%Set($List(tCase, 1), $List(tCase, 2))
        If $List(tCase, 1) = "Type" Do tBody.values.%Set("Object", $Parameter(tProbe, "SCHEMA"))
        Do $$$AssertEquals(..Wire(..#USERS, tBody, .tAnswer), "422 SQLPRIV.VALIDATION", "the route refuses " _ $List(tCase, 1) _ " " _ $List(tCase, 2) _ " with a column")
        Set tViolation = $Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("detail")): tAnswer.%Get("detail").%Get("violations").%Get(0), 1: {})
        Do $$$AssertEquals(tViolation.%Get("field") _ " " _ tViolation.%Get("code"), "Column SQLPRIV.COLUMN", "on the Column field")
        Set tArgs = ..ColumnArgs(tUser, 0)
        Do tArgs.%Set($List(tCase, 1), $List(tCase, 2))
        If $List(tCase, 1) = "Type" Do tArgs.%Set("Object", $Parameter(tProbe, "SCHEMA"))
        Set tSC = $ClassMethod(tProbe, "Mint", ..#USERGRANT, tUser, tArgs, .tProposal, .tHttp, .tProblem)
        Do $$$AssertEquals(tHttp _ " " _ tProblem, "422 SQLPRIV.VALIDATION", "the agent's mint refuses it too")
    }
    Do $$$AssertEquals($ClassMethod(tProbe, "ColumnRows", tUser, $Parameter(tProbe, "TABLE")), "", "nothing was granted along the way")

    Set tNamespace = ##class(OcuPilot.Install.Installer).ResolveNamespace()
    Set tTable = "OcuPilot_Kernel_State.Turn"
    Set tBody = ..Body("grant-sql", tUser, "SELECT", "false", tTable, "Turn")
    Do tBody.values.%Set("Namespace", tNamespace)
    Do $$$AssertEquals(..Wire(..#USERS, tBody, .tAnswer), "403 PROHIBITED.OCUPILOTSQLPRIVILEGE", "a column grant on OcuPilot's own table is refused by the route")
    Set tArgs = ..ColumnArgs(tUser, 0, tTable, "Turn")
    Do tArgs.%Set("Namespace", tNamespace)
    Set tSC = $ClassMethod(tProbe, "Mint", ..#USERGRANT, tUser, tArgs, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's column grant on it is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "403 PROHIBITED.OCUPILOTSQLPRIVILEGE", "and its confirm is refused under the schema arm")
    Do $$$AssertEquals(..Wire(..#ROLES, ..Body("grant-sql", "%DB_OCUPILOT"), .tAnswer), "403 PROHIBITED.OCUPILOTROLE", "a column grant for %DB_OCUPILOT is refused under the role arm")
    Do $$$AssertEquals(..Wire(..#ROLES, ..Body("grant-sql", "OcuPilotAdmin"), .tAnswer), "403 PROHIBITED.OCUPILOTROLE", "and for OcuPilot's administrative role")
    Set tSC = $ClassMethod(tProbe, "Mint", ..#ROLEGRANT, "OcuPilotAdmin", ..ColumnArgs("OcuPilotAdmin", 0), .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the agent's column grant for OcuPilot's administrative role is minted (" _ tProblem _ ")")
    Do $$$AssertEquals($ClassMethod(..#AGENT, "Confirm", tProposal, .tResult), "403 PROHIBITED.OCUPILOTROLE", "and its confirm is refused under the role arm")
}

/// <p>The body of the screen action <var>pAction</var> for the grantee <var>pGrantee</var>: the column
/// <var>pColumn</var> of <var>pObject</var> in <code>USER</code> with <var>pPrivilege</var>, and on a grant the
/// grant option <var>pWithGrant</var> (<code>true</code> or <code>false</code>).</p>
ClassMethod Body(pAction As %String, pGrantee As %String, pPrivilege As %String = "SELECT", pWithGrant As %String = "false", pObject As %String = {$Parameter(..#PROBE, "TABLE")}, pColumn As %String = "ID") As %DynamicObject
{
    Set tValues = {"Namespace": "USER", "Type": "TABLE", "Object": (pObject), "Action": (pPrivilege), "Column": (pColumn)}
    If pAction = "grant-sql" Do tValues.%Set("WithGrant", pWithGrant)
    Quit {"action": (pAction), "id": (pGrantee), "values": (tValues)}
}

/// <p>The agent's arguments for a column of the probe table: <var>pWithGrant</var> adds the grant option.</p>
ClassMethod ColumnArgs(pGrantee As %String, pWithGrant As %Boolean, pObject As %String = {$Parameter(..#PROBE, "TABLE")}, pColumn As %String = "ID") As %DynamicObject
{
    Set tArgs = $ClassMethod(..#PROBE, "ColumnArgs", pGrantee, pColumn, "SELECT", pObject)
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
