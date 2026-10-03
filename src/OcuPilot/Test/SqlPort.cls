/// <p>Pins <class>OcuPilot.Port.SqlPort</class>'s pure parts and its tool (Story 19.6): the closed kind
/// table over every statement type number, the DDL privilege table and the instance's knowledge of
/// each name in it, the bounds and the password refusal held before anything
/// is prepared, the endpoint and id it serves, the script form, the self-protection rules of
/// <method>OcuPilot.Kernel.Proposal.Prohibited.SqlStatement</method>,
/// <class>OcuPilot.Screen.Tool.ExplorerSqlRun</class>'s declarations and value parsing, and a source
/// pin that the port names no class of the source code API and calls no other port's
/// <code>Invoke</code>.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed in the namespace it runs in and a
/// <code>USER</code> namespace. It creates nothing; the statements it hands the port are refused before
/// any prepare, and it prepares only <code>%CHECKPRIV</code> itself.</p>
Class OcuPilot.Test.SqlPort Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.SqlPort";

Parameter TOOL = "OcuPilot.Screen.Tool.ExplorerSqlRun";

/// <p>The kind table as the spec's Design Notes state it, typed here apart from the port's own
/// parameters so the two are compared rather than read twice.</p>
Parameter EXPECTEDKINDS = "query=1,28,32,79;dml=2,3,4;ddl=9,10,11,12,13,14,15,17,35,36,37,38,39,40,41,42,43,44,52,54,55,56,57,58,60,61,62,63,64,65,66,67,68,70,71;call=45;other=16,25,27,99;session=5,6,20,21,22,23,24,26,46,47,48,51,53,59,78;administration=7,8,18,19,29,30,31,33,34,49,50;serverfiles=69,72,73,74,75,76,77,80";

/// <p>The DDL privilege table as the SQL reference states it, typed here apart from the port's own
/// parameter so the two are compared rather than read twice.</p>
Parameter EXPECTEDPRIVILEGES = "9:%CREATE_TABLE,10:%ALTER_TABLE,11:%DROP_TABLE,12:%CREATE_VIEW,13:%ALTER_VIEW,15:%ALTER_TABLE,17:%ALTER_TABLE,35:%CREATE_FUNCTION,36:%CREATE_METHOD,37:%CREATE_PROCEDURE,38:%CREATE_QUERY,39:%DROP_FUNCTION,40:%DROP_METHOD,41:%DROP_PROCEDURE,42:%DROP_QUERY,43:%CREATE_TRIGGER,44:%DROP_TRIGGER,52:%ALTER_TABLE,54:%MANAGE_MODEL,55:%MANAGE_MODEL,56:%MANAGE_MODEL,57:%MANAGE_MODEL,58:%USE_MODEL,60:%CREATE_ML_CONFIGURATION,61:%ALTER_ML_CONFIGURATION,62:%DROP_ML_CONFIGURATION,66:%BUILD_INDEX";

/// <p>The kind table maps every type number 1 to 80, and 99, to the kind the spec names, and an
/// unnamed number, an empty type and a non-number to <code>other</code>; only the four runnable
/// kinds other than a query need a confirmation.</p>
/// <p>Mutation (Rule 19): map type 4 to <code>query</code> in <parameter>OcuPilot.Port.SqlPort.TYPESQUERY</parameter>
/// -- the <code>4</code> leg goes red.</p>
Method TestTheKindTableNamesEveryTypeNumber()
{
    Kill tExpected
    For tI = 1:1:$Length(..#EXPECTEDKINDS, ";") {
        Set tGroup = $Piece(..#EXPECTEDKINDS, ";", tI)
        Set tKind = $Piece(tGroup, "=", 1)
        Set tTypes = $Piece(tGroup, "=", 2)
        For tJ = 1:1:$Length(tTypes, ",") Set tExpected(+$Piece(tTypes, ",", tJ)) = tKind
    }
    Set tWrong = ""
    For tType = 1:1:80, 99 {
        Set tKind = $ClassMethod(..#PORT, "KindOf", tType)
        If tKind '= $Get(tExpected(tType), "unnamed") Set tWrong = tWrong _ " " _ tType _ "=" _ tKind
    }
    Do $$$AssertEquals(tWrong, "", "every type number 1 to 80 and 99 has its named kind")
    Do $$$AssertEquals($ClassMethod(..#PORT, "KindOf", 4), "dml", "a DELETE is DML whatever its text says")
    For tUnnamed = 81, 100, "", "x" {
        Do $$$AssertEquals($ClassMethod(..#PORT, "KindOf", tUnnamed), "other", "'" _ tUnnamed _ "' is unclassified")
    }
    Set tMutating = ""
    For tKind = "query", "dml", "ddl", "call", "other", "session", "administration", "serverfiles" {
        If $ClassMethod(..#PORT, "Mutating", tKind) Set tMutating = tMutating _ $ListBuild(tKind)
    }
    Do $$$AssertEquals($ListToString(tMutating), "dml,ddl,call,other", "a DML, DDL, CALL or unclassified statement waits on a confirmation")
    Do $$$AssertEquals($ClassMethod(..#PORT, "Bounded", "query") _ $ClassMethod(..#PORT, "Bounded", "dml") _ $ClassMethod(..#PORT, "Bounded", "ddl") _ $ClassMethod(..#PORT, "Bounded", "call"), "1100", "a query and DML run under the alarm, DDL and a CALL do not")
}

/// <p>The DDL privilege table names, for each statement type number 1 to 81 and 99, the system
/// privilege the SQL reference ties to it, or none; and the instance knows every name it holds:
/// <code>%CHECKPRIV</code> answers each held (0) or not held (100), never an error, which the port
/// would answer as a fault for every caller.</p>
/// <p>Mutation (Rule 19): misspell <code>%CREATE_FUNCTION</code> in
/// <parameter>OcuPilot.Port.SqlPort.DDLPRIVILEGES</parameter> -- the roster leg and the known-name leg
/// go red.</p>
Method TestEveryDdlPrivilegeIsNamedAndKnown()
{
    Kill tExpected, tNames
    For tI = 1:1:$Length(..#EXPECTEDPRIVILEGES, ",") {
        Set tPair = $Piece(..#EXPECTEDPRIVILEGES, ",", tI)
        Set tExpected(+$Piece(tPair, ":", 1)) = $Piece(tPair, ":", 2)
    }
    Set tWrong = ""
    For tType = 1:1:81, 99 {
        Set tPrivilege = $ClassMethod(..#PORT, "PrivilegeFor", tType)
        If tPrivilege '= $Get(tExpected(tType)) Set tWrong = tWrong _ " " _ tType _ "=" _ tPrivilege
        If tPrivilege '= "" Set tNames(tPrivilege) = ""
    }
    Do $$$AssertEquals(tWrong, "", "each type number 1 to 81 and 99 requires the privilege the reference names, or none")
    Do $$$AssertEquals($ClassMethod(..#PORT, "PrivilegeFor", "") _ $ClassMethod(..#PORT, "PrivilegeFor", "x"), "", "an empty or non-numeric type requires none")
    Set tUnknown = ""
    Set tName = $Order(tNames(""))
    While tName '= "" {
        Set tCode = ##class(%SQL.Statement).%ExecDirect(, "%CHECKPRIV " _ tName).%SQLCODE
        If (tCode '= 0) && (tCode '= 100) Set tUnknown = tUnknown _ " " _ tName _ "=" _ tCode
        Set tName = $Order(tNames(tName))
    }
    Do $$$AssertEquals(tUnknown, "", "the instance knows every privilege the table names")
}

/// <p>The bounds: a statement of 1 to 100,000 characters, at most 100 values each a string of at most
/// 32,767 characters, and Max rows from 1 to 1,000; the port refuses anything else 400
/// <code>EXPLORER.SQL.INPUT</code> before any prepare.</p>
Method TestTheBoundsAreHeldBeforeAnyPrepare()
{
    Set tPort = ..#PORT
    Set tOk = $ClassMethod(tPort, "InputProblem", "SELECT 1", ["a", "b"], 1000)
    Do $$$AssertEquals(tOk, "", "a statement, two values and Max rows 1,000 are in bounds")
    Do $$$AssertEquals($ClassMethod(tPort, "InputProblem", ""), "statement", "an empty statement")
    Do $$$AssertEquals($ClassMethod(tPort, "InputProblem", "   "), "statement", "a blank statement")
    Do $$$AssertEquals($ClassMethod(tPort, "InputProblem", $Translate($Justify("", 100001), " ", "x")), "statement", "a statement over 100,000 characters")
    Do $$$AssertEquals($ClassMethod(tPort, "InputProblem", $Translate($Justify("", 100000), " ", "x")), "", "a statement of 100,000 characters")
    Set tMany = []
    For tI = 1:1:101 Do tMany.%Push("v", "string")
    Do $$$AssertEquals($ClassMethod(tPort, "InputProblem", "SELECT 1", tMany), "parameters", "101 values")
    Do $$$AssertEquals($ClassMethod(tPort, "InputProblem", "SELECT 1", [1]), "parameters", "a value that is not a string")
    Set tLong = []
    Do tLong.%Push($Translate($Justify("", 32768), " ", "v"), "string")
    Do $$$AssertEquals($ClassMethod(tPort, "InputProblem", "SELECT 1", tLong), "parameters", "a value over 32,767 characters")
    For tMax = 0, 1001, "x", -1, 1.5 {
        Do $$$AssertEquals($ClassMethod(tPort, "InputProblem", "SELECT 1", "", tMax), "maxRows", "Max rows '" _ tMax _ "'")
    }
    Do $$$AssertEquals($ClassMethod(tPort, "InputProblem", "SELECT 1", "", 1), "", "Max rows 1")
    Set tSC = $ClassMethod(tPort, "Classify", "USER", "", .tGuard, .tHttp, .tFault)
    Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "400 EXPLORER.SQL.INPUT", "the port refuses an empty statement")
    Set tSC = $ClassMethod(tPort, "Run", "USER", "SELECT 1", tMany, 10, "query", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "400 EXPLORER.SQL.INPUT", "and a run with 101 values")
}

/// <p>Text that sets a password is read as text and refused 422 <code>EXPLORER.SQL.PASSWORD</code>, in
/// the three spellings <code>CREATE USER</code> and <code>ALTER USER</code> take: <code>IDENTIFY</code>
/// or <code>IDENTIFIED</code> as whole words in any case, or <code>CREATE</code> or <code>ALTER</code>,
/// <code>USER</code> and <code>PASSWORD</code> in that order, a comment between them included; a column
/// named <code>Password</code> in a query or an UPDATE is not refused.
/// <class>OcuPilot.Test.SqlPortLive</class> pins that nothing reaches the statement index.</p>
/// <p>Mutation (Rule 19): drop the <code>PASSWORD</code> alternative from
/// <parameter>OcuPilot.Port.SqlPort.PASSWORDPATTERN</parameter> -- the three <code>PASSWORD</code> legs go
/// red; reduce it to the bare word <code>PASSWORD</code> -- the two column legs go red.</p>
Method TestAPasswordStatementIsRefusedByItsText()
{
    For tText = "CREATE USER OcuProbe196Nobody IDENTIFY BY 'OcuProbe196NotACredential'", "alter user OcuProbe196Nobody identified by OcuProbe196NotACredential", "CREATE USER OcuProbe196Nobody PASSWORD 'OcuProbe196NotACredential'", "alter user OcuProbe196Nobody with password OcuProbe196NotACredential", "CREATE /* c */ USER OcuProbe196Nobody WITH PASSWORD 'OcuProbe196NotACredential'", "SELECT 1 /* Identify */" {
        Do $$$AssertTrue($ClassMethod(..#PORT, "SetsPassword", tText), "sets a password: " _ tText)
    }
    For tText = "SELECT IDENTITY(1)", "SELECT IdentifyNo FROM OcuProbe196.Granted", "SELECT PasswordHint FROM OcuProbe196.Granted", "SELECT Password FROM OcuProbe196.User", "UPDATE OcuProbe196.User SET Password = ?", "SELECT 1" {
        Do $$$AssertTrue('$ClassMethod(..#PORT, "SetsPassword", tText), "does not: " _ tText)
    }
    Set tSC = $ClassMethod(..#PORT, "Classify", "USER", "CREATE USER OcuProbe196Nobody IDENTIFY BY 'OcuProbe196NotACredential'", .tGuard, .tHttp, .tFault)
    Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code _ " " _ tFault.reason, 1: ""), "422 EXPLORER.SQL.PASSWORD " _ ##class(OcuPilot.Api.AtelierError).#REASONSQLPASSWORD, "the port refuses it with the published sentence")
}

/// <p>The port serves its one endpoint and two types, and its one id, refusing anything else before
/// any call; with no statement its fresh read is the empty guard, every member present.</p>
Method TestInvokeServesOneEndpointTwoTypesAndOneId()
{
    Set tPort = ..#PORT
    Kill tQuery
    Set tQuery("id") = "sql"
    Set tSC = $ClassMethod(tPort, "Invoke", "Other", "GUARD", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($Get(tHttp) _ " " _ tFault.code, "501 PORT.NOTIMPLEMENTED", "another endpoint")
    Set tSC = $ClassMethod(tPort, "Invoke", "Sql", "LIST", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($Get(tHttp) _ " " _ tFault.code, "501 PORT.NOTIMPLEMENTED", "another type")
    Set tQuery("id") = "other"
    Set tSC = $ClassMethod(tPort, "Invoke", "Sql", "GUARD", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($Get(tHttp) _ " " _ tFault.code, "404 PORT.NOTFOUND", "another id")
    Set tQuery("id") = "sql"
    Set tQuery("namespace") = "USER"
    Set tSC = $ClassMethod(tPort, "Invoke", "Sql", "GUARD", .tQuery, "", .tResult, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the empty guard is read")
    Do $$$AssertEquals($Select($IsObject($Get(tResult)): tResult.%ToJSON(), 1: ""), "{""Namespace"":""USER"",""Kind"":"""",""StatementType"":"""",""Tables"":[],""RecordsTables"":false,""Parameters"":0,""Columns"":[],""DefaultSchema"":"""",""statement"":null,""parameters"":null,""maxRows"":null}", "with every member present")
}

/// <p>The script form (AD-59): <code>objectscript</code> for the run alone, a prepare with privilege
/// checks on and each value bound by position, every value a string literal.</p>
Method TestTheScriptPreparesAndBindsLiterals()
{
    Set tPort = ..#PORT
    Do $$$AssertEquals($ClassMethod(tPort, "SnippetForm", "Sql", "RUN") _ "|" _ $ClassMethod(tPort, "SnippetForm", "Sql", "GUARD"), "objectscript|", "the run has a script form and the read none")
    Kill tQuery
    Set tQuery("namespace") = "USER"
    Set tQuery("statement") = "UPDATE OcuProbe196.Granted SET Name = 'a""b' WHERE Num = ?"
    Set tQuery("parameters") = "[""1"",""x\""y""]"
    Set tSteps = $ClassMethod(tPort, "Snippet", "Sql", "RUN", .tQuery)
    Set tText = $Select($IsObject(tSteps) && (tSteps.%Size() = 1): tSteps.%Get(0).text, 1: "")
    Do $$$AssertTrue(tText [ "Set $NAMESPACE = ""USER""", "it names the namespace: " _ tText)
    Do $$$AssertTrue(tText [ "%Prepare(""UPDATE OcuProbe196.Granted SET Name = 'a""""b' WHERE Num = ?"", 1)", "it prepares the statement whole with privilege checks on")
    Do $$$AssertTrue(tText [ "$ListBuild(""1"", ""x""""y"")", "and binds each value as a literal")
    Do $$$AssertEquals($ClassMethod(tPort, "Snippet", "Sql", "GUARD", .tQuery).%Size(), 0, "a read renders no step")
}

/// <p>The source pin: the port names no class of the source code API and calls no other port's
/// <code>Invoke</code>; it reuses only <class>OcuPilot.Port.AtelierPort</class>'s pair set.</p>
Method TestThePortNamesNoSourceCodeApiClass()
{
    Set tSC = ##class(%Compiler.UDL.TextServices).GetTextAsString($NAMESPACE, ..#PORT, .tText)
    Do $$$AssertStatusOK(tSC, "the port's source is read")
    Do $$$AssertTrue($Length(tText) > 1000, "and is not empty")
    Do $$$AssertTrue(tText '[ ("%Api" _ "."), "it names no %Api class")
    Do $$$AssertTrue(tText '[ ("AtelierPort)" _ ".Invoke"), "it calls no AtelierPort.Invoke")
    Do $$$AssertTrue((tText '[ ("%Prepare(pText, " _ "0)")) && (tText '[ ("%ExecDirectNo" _ "Priv")), "it never prepares with privilege checks off")
    Do $$$AssertTrue(tText [ "AtelierPort).Pairs()", "it reuses the source code port's pair set")
}

/// <p>The self-protection rules (AD-10 as amended 2026-10-03): text naming OcuPilot, a recorded table
/// in an OcuPilot schema, and no recorded table under an OcuPilot default schema each refuse
/// <code>PROHIBITED.OCUPILOTSQL</code>; a probe table under the stock default schema does not.</p>
/// <p>Mutation (Rule 19): drop rule (b)'s loop from <method>OcuPilot.Kernel.Proposal.Prohibited.SqlStatement</method>
/// -- the recorded-table leg goes red.</p>
Method TestTheSelfProtectionRules()
{
    Set tProhibited = "OcuPilot.Kernel.Proposal.Prohibited"
    For tCase = $ListBuild("select * from OCUPILOT_x.y", "", 1, "SQLUser", 1, "(a) text"), $ListBuild("SELECT * FROM Probe.V", $ListBuild("PROBE.V", "OCUPILOT_KERNEL_STATE.PROPOSAL"), 1, "SQLUser", 1, "(b) a view's base table"), $ListBuild("DROP TABLE Proposal", "", 0, "OcuPilot_Kernel_State", 1, "(c) no table under an OcuPilot default schema"), $ListBuild("DROP TABLE Proposal", "", 0, "SQLUser", 0, "no table under the stock default schema"), $ListBuild("SELECT * FROM OcuProbe196.Granted", $ListBuild("OCUPROBE196.GRANTED"), 1, "OcuPilot_Kernel_State", 0, "a recorded probe table under an OcuPilot default schema") {
        Set tSC = $ClassMethod(tProhibited, "SqlStatement", $List(tCase, 1), $List(tCase, 2), $List(tCase, 3), .tProhibits, .tCode, $List(tCase, 4))
        Do $$$AssertStatusOK(tSC, $List(tCase, 6) _ ": answered")
        Do $$$AssertEquals(tProhibits _ " " _ tCode, $Select($List(tCase, 5): "1 PROHIBITED.OCUPILOTSQL", 1: "0 "), $List(tCase, 6))
    }
    Do $$$AssertEquals($ClassMethod(tProhibited, "ReasonFor", "PROHIBITED.OCUPILOTSQL"), $Parameter(tProhibited, "OCUPILOTSQLREASON"), "the code carries its published sentence")
    Do $$$AssertTrue($ListFind($ClassMethod(tProhibited, "Codes"), "PROHIBITED.OCUPILOTSQL"), "and is one of the set's codes")
}

/// <p>The confirmed run's tool declares the write path: the console port, unadvertised, a guard read
/// and a run write sending no body, destructive, its three screen values, and a fingerprint over the
/// guard and the values run.</p>
Method TestTheToolDeclaresItsWritePath()
{
    Set tTool = ..#TOOL
    Do $$$AssertEquals($Parameter(tTool, "TOOLNAME"), "explorer.sqlquery.run", "its name")
    Do $$$AssertEquals($ClassMethod(tTool, "PortClass"), ..#PORT, "its port")
    Do $$$AssertEquals($ClassMethod(tTool, "Advertised") _ $ClassMethod(tTool, "SendsBody") _ $ClassMethod(tTool, "Destructive"), "001", "unadvertised, bodyless and destructive")
    Do $$$AssertEquals($ClassMethod(tTool, "ReadType") _ " " _ $ClassMethod(tTool, "WriteType") _ " " _ $ClassMethod(tTool, "ChangeAction"), "GUARD RUN updated", "a guard read and a run write")
    Do $$$AssertEquals($ListToString($ClassMethod(tTool, "ScreenActionValueNames", "run")), "statement,parameters,maxRows", "its three screen values")
    Do $$$AssertEquals($ListToString($ClassMethod(tTool, "FingerprintSubject")), "Namespace,Kind,StatementType,Tables,statement,parameters,maxRows", "its fingerprint subject")
    Do $$$AssertEquals($Parameter(tTool, "CLASSICPAGES"), "", "and no classic page of its own")
}

/// <p>AD-56 (ii): the screen's three values become the tool's arguments -- the statement, the values
/// parsed from JSON array text, Max rows from digits -- and any other spelling is refused; the payload
/// carries them back to the port's query.</p>
Method TestTheScreenValuesAreParsedAndBounded()
{
    Set tTool = ..#TOOL
    Set tSC = $ClassMethod(tTool, "ScreenActionDelta", "run", {"statement": "UPDATE OcuProbe196.Granted SET Num = ?", "parameters": "[\"3\"]", "maxRows": "10"}, {}, .tArgs, .tProblem)
    Do $$$AssertEquals(tProblem, "", "well-formed values are accepted")
    Do $$$AssertEquals($Select($IsObject($Get(tArgs)): tArgs.%ToJSON(), 1: ""), "{""statement"":""UPDATE OcuProbe196.Granted SET Num = ?"",""parameters"":[""3""],""maxRows"":10}", "as the tool's arguments")
    For tCase = $ListBuild("{""statement"":""SELECT 1"",""parameters"":""3"",""maxRows"":""10""}", "values that are not an array"), $ListBuild("{""statement"":""SELECT 1"",""parameters"":""[3]"",""maxRows"":""10""}", "a value that is not a string"), $ListBuild("{""statement"":""SELECT 1"",""parameters"":""[]"",""maxRows"":""0""}", "Max rows 0"), $ListBuild("{""statement"":""SELECT 1"",""parameters"":""[]"",""maxRows"":""1001""}", "Max rows 1,001"), $ListBuild("{""statement"":""SELECT 1"",""parameters"":""[]"",""maxRows"":""ten""}", "Max rows as a word"), $ListBuild("{""statement"":"" "",""parameters"":""[]"",""maxRows"":""10""}", "a blank statement") {
        Set tSC = $ClassMethod(tTool, "ScreenActionDelta", "run", ##class(%DynamicObject).%FromJSON($List(tCase, 1)), {}, .tArgs, .tProblem)
        Do $$$AssertTrue((tProblem '= "") && (tArgs.%Size() = 0), $List(tCase, 2) _ " is refused: " _ tProblem)
    }
    Kill tQuery
    Do $ClassMethod(tTool, "PortQuery", {"Namespace": "USER", "Kind": "dml", "statement": "UPDATE OcuProbe196.Granted SET Num = ?", "parameters": ["3"], "maxRows": 10}, .tQuery)
    Do $$$AssertEquals($Get(tQuery("namespace")) _ "|" _ $Get(tQuery("statement")) _ "|" _ $Get(tQuery("parameters")) _ "|" _ $Get(tQuery("maxRows")), "USER|UPDATE OcuProbe196.Granted SET Num = ?|[""3""]|10", "the payload carries the run to the port's query")
}

}
