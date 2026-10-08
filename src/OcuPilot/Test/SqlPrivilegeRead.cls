/// <p>Pins Story 18.9's reads: the SQL privileges screen's declared read and <code>permissions.sqlprivileges.read</code>
/// answer one set of rows from one read, over the wire as in process; the instance lists a probe user's privileges
/// as <code>Direct</code>, <code>Role:&lt;name&gt;</code>, <code>Schema Privilege</code> and
/// <code>Owner Privilege</code> rows; <class>OcuPilot.Port.AdminPort</class>'s guard refuses an undefined
/// namespace, a missing grantee and a list or wildcard, the read included; and
/// <class>OcuPilot.Port.SqlPrivilegePort</class> composes the state a grant or revoke reads, counting a table and a
/// view alike, a schema's rows, the distinct grantors, and the grantee that holds <code>%All</code>.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the class creates and removes a probe user
/// and role and a probe schema's objects in <code>USER</code> (<class>OcuPilot.Test.SqlPrivilegeProbe</class>). Every
/// probe object is removed by exact name before all, after each and after all, and the probe schema's rows read as
/// before each test.</p>
Class OcuPilot.Test.SqlPrivilegeRead Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms the writes, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS";

Parameter SCREEN = "permissions.sqlprivileges";

Parameter DESCRIPTOR = "OcuPilot.Screen.Descriptor.SqlPrivilegeList";

Parameter PROBE = "OcuPilot.Test.SqlPrivilegeProbe";

Parameter SEAM = "OcuPilot.Test.SqlPrivilegeSeamPort";

Parameter ENDPOINT = "Security.SQLPrivilege.Standard";

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlPrivilegeRead creates a probe user, role and schema on this instance and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Quit $ClassMethod(..#PROBE, "RemoveAll")
}

Method OnBeforeOneTest() As %Status
{
    Do $ClassMethod(..#SEAM, "Clear")
    Quit $ClassMethod(..#PROBE, "Seed")
}

Method OnAfterOneTest() As %Status
{
    Do $ClassMethod(..#SEAM, "Clear")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAll"), "every probe object is removed by exact name")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Remaining"), 0, "and none is left")
    Quit $$$OK
}

Method OnAfterAllTests() As %Status
{
    Quit $ClassMethod(..#PROBE, "RemoveAll")
}

/// <p>C1: a probe user holds a table privilege directly with the grant option, a table privilege through a role,
/// every table and view of the schema through a schema grant, and the four procedure rows every grantee owns; the
/// instance lists each by how it is held, and the grant option as a boolean.</p>
/// <p>Mutation (Rule 19): drop <code>GrantedVia</code> from the descriptor's read fields -- the kind legs go
/// red.</p>
Method TestTheFourKindsOfRowAreListed()
{
    Set tProbe = ..#PROBE
    Set tUser = $Parameter(tProbe, "USER")
    Set tRole = $Parameter(tProbe, "ROLE")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "Grant", tUser, "TABLE", $Parameter(tProbe, "TABLE"), "SELECT", 1), "a direct table grant with the grant option")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "Grant", tRole, "TABLE", $Parameter(tProbe, "TABLE2"), "UPDATE"), "a table grant to the role")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "GiveRole"), "the role given to the user")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "Grant", tUser, "SCHEMA", $Parameter(tProbe, "SCHEMA"), "DELETE"), "and a schema grant")
    Set tRows = ..ScreenRows(tUser)
    Set tLines = ""
    For tI = 1:1:tRows.%Size() {
        Set tRow = tRows.%Get(tI - 1)
        Set tLines = tLines _ ";" _ tRow.%Get("Type") _ "|" _ tRow.%Get("Object") _ "|" _ tRow.%Get("Action") _ "|" _ tRow.%Get("GrantedBy") _ "|" _ tRow.%Get("GrantOption") _ "|" _ tRow.%Get("GrantedVia")
    }
    Set tUpper = $ZConvert(tLines, "U")
    Do $$$AssertTrue(tUpper [ (";TABLE|" _ $ZConvert($Parameter(tProbe, "TABLE"), "U") _ "|SELECT|" _ $ZConvert($Username, "U") _ "|1|DIRECT"), "the direct row, granted by the running account, with the grant option: " _ tLines)
    Do $$$AssertTrue(tUpper [ ("|" _ $ZConvert($Parameter(tProbe, "TABLE2"), "U") _ "|UPDATE|"), "the role's table row is listed")
    Do $$$AssertTrue(tUpper [ ("|ROLE:" _ $ZConvert(tRole, "U")), "held through the role: " _ tLines)
    Do $$$AssertTrue(tUpper [ "|DELETE|", "the schema grant lists as per-object DELETE rows")
    Do $$$AssertTrue(tUpper [ "|SCHEMA PRIVILEGE", "held through the schema")
    Do $$$AssertTrue(tUpper [ "|OWNER PRIVILEGE", "and the procedures every grantee owns")
    Set tViaEmpty = 0
    For tI = 1:1:tRows.%Size() {
        If tRows.%Get(tI - 1).%Get("GrantedVia") = "" Set tViaEmpty = 1
    }
    Do $$$AssertEquals(tViaEmpty, 0, "no row is listed without how it is held")
    Do $$$AssertEquals(tRows.%Get(0).%GetTypeOf("GrantOption"), "boolean", "the grant option is a boolean")
}

/// <p>C1: the screen's declared read and the read tool answer the same rows; over the wire the screen's route
/// answers the same rows; a read with no namespace is refused naming it.</p>
/// <p>Mutation (Rule 19): make the tool read pass a different <code>includeSystem</code> than the screen -- the
/// rows leg goes red.</p>
Method TestTheScreenAndTheReadToolAnswerTheSameRows()
{
    Set tProbe = ..#PROBE
    Set tUser = $Parameter(tProbe, "USER")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "Grant", tUser, "TABLE", $Parameter(tProbe, "TABLE"), "SELECT"), "a direct table grant")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "Grant", tUser, "STORED PROCEDURE", $Parameter(tProbe, "PROCEDURE"), "EXECUTE"), "and a direct procedure grant")
    Set tRows = ..ScreenRows(tUser)
    Do $$$AssertTrue(tRows.%Size() > 2, "the screen lists the rows (" _ tRows.%Size() _ ")")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).Resolve(..#SCREEN _ ".read", .tTool)
    Do $$$AssertStatusOK(tSC, "permissions.sqlprivileges.read resolves")
    Set tSC = ##class(OcuPilot.Screen.Tool.Registry).InvokeTool(tTool, {"grantee": (tUser), "namespace": "USER", "maxRows": 1000}, 1000, .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "and answers (" _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: "") _ ")")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): ..Canonical(tResult.%Get("rows")), 1: ""), ..Canonical(tRows), "the tool's rows are the screen's")
    Set tBase = $Parameter("OcuPilot.Test.Http", "BASEPATH")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/screens/" _ ..#SCREEN _ "/read?grantee=" _ tUser _ "&namespace=USER&maxRows=1000", ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus, 200, "over the wire the route answers: " _ $Extract(tRaw, 1, 200))
    Do $$$AssertEquals(..Canonical(##class(%DynamicObject).%FromJSON(tRaw).%Get("rows")), ..Canonical(tRows), "the same rows")
    Set tSC = ##class(OcuPilot.Test.Http).AbsoluteRequest("GET", tBase _ "/screens/" _ ..#SCREEN _ "/read?grantee=" _ tUser, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tRaw, .tHeaders)
    Do $$$AssertEquals(tStatus _ " " _ ##class(%DynamicObject).%FromJSON(tRaw).%Get("code"), "404 SQLPRIV.NAMESPACE", "a read naming no namespace is refused naming it")
}

/// <p>C4, AD-2: <class>OcuPilot.Port.AdminPort</class>'s guard refuses an undefined namespace (404), a missing grantee (400) and a list or wildcard in
/// the grantee, object or action (400), on the list as on a write, with the product's own code; a defined namespace
/// and one grantee are not refused.</p>
/// <p>Mutation (Rule 19): drop the namespace check from <method>OcuPilot.Port.AdminPort.SqlPrivilegeGuard</method> --
/// the namespace legs go red.</p>
Method TestTheGuardRefusesBeforeTheVendorIsReached()
{
    Set tSeam = "OcuPilot.Port.AdminPort"
    Set tGrantee = $Parameter(..#PROBE, "USER")
    For tCase = $ListBuild("LIST", "namespace=NoSuchNs|grantee=" _ tGrantee, "404 SQLPRIV.NAMESPACE"), $ListBuild("LIST", "namespace=|grantee=" _ tGrantee, "404 SQLPRIV.NAMESPACE"), $ListBuild("LIST", "namespace=^^/tmp|grantee=" _ tGrantee, "404 SQLPRIV.NAMESPACE"), $ListBuild("LIST", "namespace=USER", "400 SQLPRIV.GRANTEE"), $ListBuild("LIST", "namespace=USER|grantee=" _ $Extract(tGrantee, 1, 8) _ "*", "400 SQLPRIV.LIST"), $ListBuild("LIST", "namespace=USER|grantee=a,b", "400 SQLPRIV.LIST"), $ListBuild("GRANT", "namespace=USER|grantee=" _ tGrantee _ "|type=TABLE|object=" _ $Parameter(..#PROBE, "SCHEMA") _ ".*|action=SELECT", "400 SQLPRIV.LIST"), $ListBuild("GRANT", "namespace=USER|grantee=" _ tGrantee _ "|type=TABLE|object=" _ $Parameter(..#PROBE, "TABLE") _ "|action=SELECT,INSERT", "400 SQLPRIV.LIST"), $ListBuild("REVOKE", "namespace=NoSuchNs|grantee=" _ tGrantee _ "|type=TABLE|object=" _ $Parameter(..#PROBE, "TABLE") _ "|action=SELECT", "404 SQLPRIV.NAMESPACE"), $ListBuild("LIST", "namespace=USER|grantee=" _ tGrantee, "200 ") {
        Kill tQuery
        For tI = 1:1:$Length($List(tCase, 2), "|") {
            Set tPair = $Piece($List(tCase, 2), "|", tI)
            Set tQuery($Piece(tPair, "=", 1)) = $Piece(tPair, "=", 2, *)
        }
        Set tSC = $ClassMethod(tSeam, "Invoke", ..#ENDPOINT, $List(tCase, 1), .tQuery, "", .tResult, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: ""), $List(tCase, 3), $List(tCase, 1) _ " " _ $List(tCase, 2) _ " is answered " _ $List(tCase, 3))
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Rows", tGrantee), "", "nothing was granted along the way")
}

/// <p>AD-51: the composed state counts a table and a view alike, a schema grant's rows for the action, and the
/// distinct grantors sorted; it answers the arguments back, the grant option as asked, and refuses as the matrix's
/// Preconditions row: a grant already held (with the grant option asked for or more), a revoke with nothing direct,
/// and a grantee holding <code>%All</code>.</p>
/// <p>Mutation (Rule 19): count a role's row as a direct one in <method>OcuPilot.Port.SqlPrivilegePort.Facts</method>
/// -- the role leg goes red.</p>
Method TestTheStateReadComposesTheDirectRows()
{
    Set tProbe = ..#PROBE
    Set tUser = $Parameter(tProbe, "USER")
    Set tBase = "namespace=USER|grantee=" _ tUser _ "|"
    Set tTable = $Parameter(tProbe, "TABLE")
    Set tSC = ..State("GRANTSTATE", tBase _ "type=TABLE|object=" _ tTable _ "|action=SELECT", .tHttp, .tAnswer)
    Do $$$AssertEquals(tHttp _ " " _ tAnswer.%Get("Held") _ tAnswer.%Get("GrantOption") _ tAnswer.%Get("Rows") _ "|" _ tAnswer.%Get("GrantedBy") _ "|" _ tAnswer.%Get("WithGrant"), "200 000||0", "a privilege not held reads Held false, no rows, no grantor and the grant option not asked")
    Do $$$AssertEquals(tAnswer.%Get("Namespace") _ " " _ tAnswer.%Get("Type") _ " " _ tAnswer.%Get("Object") _ " " _ tAnswer.%Get("Action"), "USER TABLE " _ tTable _ " SELECT", "the read answers the arguments back")
    Set tSC = ..State("REVOKESTATE", tBase _ "type=TABLE|object=" _ tTable _ "|action=SELECT", .tHttp, .tAnswer, .tCode)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "409 SQLPRIV.NOTHELD", "a revoke of what is not held is refused")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "Grant", tUser, "TABLE", tTable, "SELECT"), "a direct grant without the option")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "Grant", $Parameter(tProbe, "ROLE"), "TABLE", tTable, "INSERT"), "and a role's grant")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "GiveRole"), "given to the user")
    Set tSC = ..State("GRANTSTATE", tBase _ "type=TABLE|object=" _ $ZConvert(tTable, "L") _ "|action=SELECT", .tHttp, .tAnswer, .tCode)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "409 SQLPRIV.HELD", "a grant of what is held is refused, whatever case the object is spelled in")
    Set tSC = ..State("GRANTSTATE", tBase _ "type=TABLE|object=" _ tTable _ "|action=SELECT|withGrant=1", .tHttp, .tAnswer, .tCode)
    Do $$$AssertEquals(tHttp _ " " _ tAnswer.%Get("Held") _ tAnswer.%Get("GrantOption") _ "|" _ tAnswer.%Get("WithGrant"), "200 10|1", "but one asking the grant option too is read, as an upgrade")
    Set tSC = ..State("GRANTSTATE", tBase _ "type=TABLE|object=" _ tTable _ "|action=INSERT", .tHttp, .tAnswer, .tCode)
    Do $$$AssertEquals(tHttp _ " " _ tAnswer.%Get("Held") _ tAnswer.%Get("Rows"), "200 00", "a privilege held only through a role is not a direct row")
    Set tSC = ..State("REVOKESTATE", tBase _ "type=TABLE|object=" _ tTable _ "|action=INSERT", .tHttp, .tAnswer, .tCode)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "409 SQLPRIV.NOTHELD", "so a revoke of it finds nothing direct")
    Set tSC = ..State("REVOKESTATE", tBase _ "type=VIEW|object=" _ tTable _ "|action=SELECT", .tHttp, .tAnswer, .tCode)
    Do $$$AssertEquals(tHttp _ " " _ tAnswer.%Get("Held") _ tAnswer.%Get("Rows") _ "|" _ tAnswer.%Get("GrantedBy"), "200 11|" _ $Username, "a table and a view are counted alike; the grantor is named")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "Grant", tUser, "SCHEMA", $Parameter(tProbe, "SCHEMA"), "UPDATE"), "a schema grant")
    Set tSC = ..State("REVOKESTATE", tBase _ "type=SCHEMA|object=" _ $Parameter(tProbe, "SCHEMA") _ "|action=UPDATE", .tHttp, .tAnswer, .tCode)
    Do $$$AssertEquals(tHttp _ " " _ tAnswer.%Get("Held") _ "|" _ (tAnswer.%Get("Rows") > 0), "200 1|1", "a schema grant reads as its objects' rows")
    Do $$$AssertStatusOK($ClassMethod(tProbe, "GiveRole"), "")
    Set tSC = $ClassMethod(tProbe, "GiveAll", 1)
    Set tSC = ..State("GRANTSTATE", tBase _ "type=TABLE|object=" _ $Parameter(tProbe, "TABLE2") _ "|action=SELECT", .tHttp, .tAnswer, .tCode)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "409 SQLPRIV.SUPERUSER", "a grantee holding %All is refused for a grant")
    Set tSC = ..State("REVOKESTATE", tBase _ "type=TABLE|object=" _ tTable _ "|action=SELECT", .tHttp, .tAnswer, .tCode)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "409 SQLPRIV.SUPERUSER", "and for a revoke")
    Do $ClassMethod(tProbe, "GiveAll", 0)
    Set tSC = ..State("GRANTSTATE", tBase _ "type=TABLE|object=" _ $Parameter(tProbe, "TABLE2") _ "|action=SELECT", .tHttp, .tAnswer, .tCode)
    Do $$$AssertEquals(tHttp, 200, "and once it holds %All no longer, the read answers again")
    Set tSC = ..State("GRANTSTATE", "namespace=USER|grantee=" _ tUser _ "|type=TABLE|object=" _ tTable _ "|action=FROB", .tHttp, .tAnswer, .tCode)
    Do $$$AssertEquals(tHttp _ " " _ tCode, "422 SQLPRIV.VALIDATION", "an action the type does not take is refused 422 before any list")
}

/// <p>The composed read <var>pType</var> over the query <var>pLine</var> (<code>key=value</code> pairs joined by
/// <code>|</code>) through the real privilege port: the status in <var>pHttp</var>, the answer in
/// <var>pAnswer</var> and the fault's code in <var>pCode</var>.</p>
ClassMethod State(pType As %String, pLine As %String, Output pHttp As %Integer, Output pAnswer As %DynamicObject, Output pCode As %String) As %Status
{
    Kill tQuery
    For tI = 1:1:$Length(pLine, "|") {
        Set tPair = $Piece(pLine, "|", tI)
        Set tQuery($Piece(tPair, "=", 1)) = $Piece(tPair, "=", 2, *)
    }
    Set tSC = $ClassMethod(..#PORT, "Invoke", ..#ENDPOINT, pType, .tQuery, "", .pAnswer, .pHttp, .tFault)
    Set pCode = $Select($IsObject($Get(tFault)): tFault.%Get("code"), 1: "")
    If '$IsObject($Get(pAnswer)) Set pAnswer = {}
    Quit tSC
}

Parameter PORT = "OcuPilot.Port.SqlPrivilegePort";

/// <p>The rows <var>pRows</var> as JSON texts, sorted and <code>;</code>-joined: the declared read lists the
/// instance's order and the read tool sorts, so the two are compared as sets.</p>
ClassMethod Canonical(pRows As %DynamicArray) As %String
{
    Kill tSorted
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tSorted(tRow.%ToJSON()) = ""
    }
    Set tText = ""
    Set tKey = ""
    For {
        Set tKey = $Order(tSorted(tKey))
        If tKey = "" Quit
        Set tText = tText _ ";" _ tKey
    }
    Quit tText
}

/// <p>The screen's declared read of <var>pGrantee</var>'s privileges in <code>USER</code>, as its rows.</p>
Method ScreenRows(pGrantee As %String) As %DynamicArray
{
    Kill tCriteria
    Set tCriteria("grantee") = pGrantee
    Set tCriteria("namespace") = "USER"
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#DESCRIPTOR, 1000, .tRead, .tHttp, .tFault, .tCriteria)
    Do $$$AssertStatusOK(tSC, "the screen's read answers (" _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: "") _ ")")
    Quit $Select($IsObject($Get(tRead)): tRead.%Get("rows"), 1: [])
}

}
