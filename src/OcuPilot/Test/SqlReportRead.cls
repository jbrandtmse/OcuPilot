/// <p>Pins Story 21.29's list, reads and refusals (AC1, AC3; AD-4, AD-21, AD-36, AD-51, AD-53, AD-58): the declared shape of the SQL troubleshooting reports
/// list and its three tools, the list's columns equal to the catalog statement's, the port's case and saved-query reads answering the instance's own rows,
/// every value shape refused on both callers before any call (the seam counts calls), a statement that is not a query refused, a statement over
/// OcuPilot's own tables refused, the gates refusing before any read or call, the copy-out scripts, the list's cap reported as truncation, the instance's
/// own status for a row with no plan, and the list's note against the instance's row-level security policy.</p>
/// <p><b>What it needs from the environment:</b> a <code>USER</code> namespace and a calling process that holds <code>%Development:USE</code>, SELECT on
/// <code>%SQL_Manager_QButtons.Base</code> and WRITE on <code>USER</code>'s routines database. It makes <class>OcuPilot.Test.SqlTuningProbe</class>'s report
/// objects and removes every saved query, cached query and table it made when each test ends.</p>
Class OcuPilot.Test.SqlReportRead Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.SqlTuningProbe";

Parameter PORT = "OcuPilot.Port.SqlPort";

Parameter FIXTURE = "OcuPilot.Test.SqlTuningPortFixture";

Parameter SEAM = "OcuPilot.Test.SqlTuningGateSeam";

Parameter ATELIER = "OcuPilot.Port.AtelierPort";

Parameter ERROR = "OcuPilot.Api.AtelierError";

Parameter NAMESPACE = "USER";

Parameter LIST = "OcuPilot.Screen.Descriptor.ExplorerSqlReports";

Parameter SAVE = "OcuPilot.Screen.Tool.ExplorerSqlReportSave";

Parameter DELETE = "OcuPilot.Screen.Tool.ExplorerSqlReportDelete";

Parameter GENERATE = "OcuPilot.Screen.Tool.ExplorerSqlReportGenerate";

Parameter CASE = 2291;

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Set tSC = $ClassMethod(..#PROBE, "MakeReport", ..#NAMESPACE)
    Do $$$AssertStatusOK(tSC, "the probe's table is created in " _ ..#NAMESPACE)
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveReport", ..#NAMESPACE), "the probe's saved queries, cached queries and table are removed")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "ReportLeft", ..#NAMESPACE) _ "|" _ $ClassMethod(..#PROBE, "CachedQueryCount", ..#NAMESPACE, $Parameter(..#PROBE, "REPORTSCHEMA")), "0|0", "and no saved query or cached query of the probe is left")
    Set tTable = $Parameter(..#PROBE, "REPORTTABLE")
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = ..#NAMESPACE
    Set tTable = ##class(%Dictionary.CompiledClass).%ExistsId(tTable)
    Set $NAMESPACE = tOrigNS
    Do $$$AssertEquals(tTable, 0, "and the probe table is dropped")
    Quit $$$OK
}

/// <p>The descriptor declaration of <var>pClass</var>.</p>
ClassMethod Declaration(pClass As %String) As %DynamicObject
{
    Do $ClassMethod(pClass, "DeclarationJson", .tDeclaration)
    Quit tDeclaration
}

/// <p>One query saved for the probe's case through the vendor, as the calling process; the new row's id.</p>
ClassMethod SaveOne(pText As %String = {$Parameter(..#PROBE, "REPORTQUERY")}) As %String
{
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = ..#NAMESPACE
    Set tSC = ##class(%SQL.Manager.QButtons.Base).InsertQuery(pText, ..#CASE, 0, 0)
    Set $NAMESPACE = tOrigNS
    Set tIds = $ClassMethod(..#PROBE, "ReportIds", ..#NAMESPACE)
    Quit $Select($$$ISOK(tSC): $ListGet(tIds, $ListLength(tIds)), 1: "")
}

/// <p>The port's <var>pType</var> of the reports endpoint with <var>pId</var> and the query values <var>pQuery</var>, through <var>pClass</var>:
/// <code>http code</code>, and the answer in <var>pAnswer</var>.</p>
ClassMethod Call(pClass As %String, pType As %String, pId As %String, ByRef pQuery, Output pAnswer, Output pFault) As %String
{
    Set pQuery("namespace") = ..#NAMESPACE
    Set pQuery("id") = pId
    Set tSC = $ClassMethod(pClass, "Invoke", "Reports", pType, .pQuery, "", .pAnswer, .tHttp, .pFault)
    Quit $Get(tHttp) _ " " _ $Select($IsObject($Get(pFault)): pFault.code, 1: "")
}

/// <p>AC1, AC3. The list and its three tools declare their shape: the list's route, position, entity, id and source, the columns the catalog statement
/// answers, the page action and row action ids, and each tool's port, read type, write type, consequence and screen values. Nothing in them offers a mail
/// action.</p>
/// <p>Mutation (Rule 19): the descriptor drops <code>WRCNumber</code> from its fields -> the fields assertion goes red.</p>
Method TestTheScreenDeclaresItsShape()
{
    Set tList = ..Declaration(..#LIST)
    Do $$$AssertEquals(tList.route _ "|" _ tList.sideBarPosition _ "|" _ tList.archetype _ "|" _ tList.entityType _ "|" _ tList.scope _ "|" _ tList.toolIdentifier, "system-explorer/sql-reports|24|list|sql-saved-query|namespace|explorer.sqlreports", "the route, position, archetype, entity, scope and tool identifier")
    Do $$$AssertEquals(tList.id.kind _ "|" _ tList.read.source.port _ "|" _ tList.read.source.endpoint _ "|" _ tList.read.source.type _ "|" _ tList.read.paging _ "|" _ tList.classicPage, "single|atelier|Catalog.SqlReports|LIST|cap|%CSP.UI.Portal.SQL.QButtons.ReportGenerator", "its id is the saved query's, it reads the catalog list capped, and it replaces the classic page")
    Set tFields = ""
    Set tIterator = tList.read.fields.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) {
        Set tFields = tFields _ $Select(tFields = "": "", 1: ",") _ tField
    }
    Do $$$AssertEquals(tFields, "ID,WRCNumber,Saved,Status,DelimitedIdentifiers,Schema,Statement", "it reads the saved query's id, case, time, status, flag, schema and statement")
    Set tActions = ""
    Set tIterator = tList.rowActions.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tAction) {
        Set tActions = tActions _ $Select(tActions = "": "", 1: ",") _ tAction.id
    }
    Do $$$AssertEquals(tActions, "save,generate,generate-browser,delete", "its actions are Save query, Generate report to a server file and to this browser, and Delete, and none sends a report to anyone")
    Set tColumns = $Parameter(..#ATELIER, "CATALOGSQLREPORTSCOLUMNS")
    Do $$$AssertEquals($Length(tColumns, ","), 7, "the catalog answers seven columns")
    Do $$$AssertTrue($Piece(tColumns, ",", 7) = "Statement:STATEMENT:sqltext", "the statement column is cut and masked as every list's statement is")
    For tCase = $ListBuild(..#SAVE, "explorer.sqlreports.save", "SAVEQUERY", "CASE", "EXPLORER.SQLREPORT.SAVE"), $ListBuild(..#DELETE, "explorer.sqlreports.delete", "DELETEQUERY", "SAVEDQUERY", "EXPLORER.SQLREPORT.DELETE"), $ListBuild(..#GENERATE, "explorer.sqlreports.generate", "GENERATE", "CASE", "EXPLORER.SQLREPORT.GENERATE") {
        Set tTool = $List(tCase, 1)
        Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $ClassMethod(tTool, "PortClass") _ "|" _ $ClassMethod(tTool, "Endpoint") _ "|" _ $ClassMethod(tTool, "WriteType") _ "|" _ $ClassMethod(tTool, "ReadType") _ "|" _ $ClassMethod(tTool, "Consequence", {"root": "x"}), $List(tCase, 2) _ "|OcuPilot.Port.SqlPort|Reports|" _ $List(tCase, 3) _ "|" _ $List(tCase, 4) _ "|" _ $List(tCase, 5), $List(tCase, 2) _ ": its port, endpoint, write, read and consequence")
    }
    Do $$$AssertEquals($ClassMethod(..#GENERATE, "Consequence", {}), "", "a report to this browser writes no file and states none")
    Do $$$AssertEquals($Parameter(..#SAVE, "SCREENVALUES") _ "|" _ $Parameter(..#GENERATE, "SCREENVALUES"), "save=Statement:WRCNumber|generate=WRCNumber:root:path,generate-browser=WRCNumber", "the screen's values")
}

/// <p>AC1, AC2, AC3. The port's case read counts the queries the instance shows the caller for a case, and the saved-query read answers one row by its id,
/// each as the vendor's own table holds them; an id no row has is 404, and a hostile one is 400, before any read.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.CASEIDSQUERY</code> drops its case condition -> the count assertion goes red.</p>
Method TestTheCaseAndTheSavedQueryReadTheInstancesRows()
{
    Kill tQuery
    Set tQuery("WRCNumber") = ..#CASE
    Do $$$AssertEquals(..Call(..#PORT, "CASE", "*", .tQuery, .tAnswer, .tFault), "200 ", "the case read answers")
    Do $$$AssertEquals(tAnswer.Saved, 0, "a case with no saved query holds none")
    Set tFirst = ..SaveOne()
    Set tSecond = ..SaveOne($Parameter(..#PROBE, "REPORTQUERY") _ " ORDER BY A")
    Do $$$AssertTrue((tFirst '= "") && (tSecond '= "") && (tFirst '= tSecond), "two queries are saved for the case: " _ tFirst _ ", " _ tSecond)
    Kill tQuery
    Set tQuery("WRCNumber") = ..#CASE
    Set tCode = ..Call(..#PORT, "CASE", "*", .tQuery, .tAnswer, .tFault)
    Do $$$AssertEquals(tCode _ "|" _ tAnswer.Saved _ "|" _ tAnswer.Namespace _ "|" _ tAnswer.WRCNumber, "200 |2|" _ ..#NAMESPACE _ "|" _ ..#CASE, "the case read answers the instance's count: " _ tCode)
    Kill tQuery
    Set tQuery("WRCNumber") = ..#CASE + 1
    Do $$$AssertEquals(..Call(..#PORT, "CASE", "*", .tQuery, .tAnswer, .tFault) _ "|" _ tAnswer.Saved, "200 |0", "another case holds none")
    Kill tQuery
    Do $$$AssertEquals(..Call(..#PORT, "SAVEDQUERY", tFirst, .tQuery, .tAnswer, .tFault) _ "|" _ tAnswer.ID _ "|" _ tAnswer.WRCNumber, "200 |" _ tFirst _ "|" _ ..#CASE, "the saved-query read answers the row")
    Set tText = $ClassMethod(..#PROBE, "ReportStatement", ..#NAMESPACE, tFirst)
    Do $$$AssertEquals(tText, $Parameter(..#PROBE, "REPORTQUERY"), "and the instance holds the statement as it was saved")
    Do $$$AssertEquals(..Call(..#PORT, "SAVEDQUERY", tSecond + 1000000, .tQuery, .tAnswer, .tFault) _ "|" _ $Select($IsObject(tFault): tFault.reason, 1: ""), "404 PORT.NOTFOUND|No query is saved for this support case in this namespace.", "an id no row has is 404 with the ruled sentence")
    For tId = "0", "x", "1 2", "-3", "*", "" {
        Kill tQuery
        Do $$$AssertEquals(..Call(..#PORT, "SAVEDQUERY", tId, .tQuery, .tAnswer, .tFault), "400 PORT.VALIDATION", "the id '" _ tId _ "' is refused")
    }
    Kill tQuery
    Set tQuery("WRCNumber") = ..#CASE
    Set tQuery("Statement") = $Parameter(..#PROBE, "REPORTQUERY")
    Set tCode = ..Call(..#PORT, "CASE", "*", .tQuery, .tAnswer, .tFault)
    Do $$$AssertEquals(tCode _ "|" _ tAnswer.Kind _ "|" _ tAnswer.Tables.%Size() _ "|" _ tAnswer.Saved, "200 |query|1|2", "the case read of a statement answers its kind and tables beside the count: " _ tCode)
}

/// <p>AC3. The generate tool names PathPort's pairs, <code>%Admin_FileSystemAccess:USE</code> and <code>%DB_IRISSYS:READ</code>, when its arguments name a
/// <code>root</code>, and none of them when they name none (a report to this browser).</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Screen.Tool.ExplorerSqlReportGenerate.ArgumentPairs</code> returns the inherited pairs alone -> the root leg goes
/// red.</p>
Method TestAServerFileAddsThePathPairsAndABrowserReportAddsNone()
{
    Set tSystem = $ListBuild("%Admin_FileSystemAccess", "USE")
    Set tIrissys = $ListBuild("%DB_IRISSYS", "READ")
    Set tPairs = $ClassMethod(..#GENERATE, "ArgumentPairs", "", {"WRCNumber": "2291", "root": "x", "path": "y"}, .tResolved)
    Do $$$AssertTrue(tResolved && ''$ListFind(tPairs, tSystem) && ''$ListFind(tPairs, tIrissys), "a server file adds the file-system and routines-database read pairs")
    Set tPairs = $ClassMethod(..#GENERATE, "ArgumentPairs", "", {"WRCNumber": "2291"}, .tResolved)
    Do $$$AssertTrue(tResolved && '$ListFind(tPairs, tSystem) && '$ListFind(tPairs, tIrissys), "a report to this browser adds neither")
}

/// <p>AC1, AC3. Every value shape is refused before any call, on both callers: the port's reads and writes answer 400 with the published sentence for an
/// empty, non-numeric, zero, zero-led, signed, spaced or over-long case number and for an empty or over-long statement, and the tools' own argument checks
/// refuse the same values with the same sentence; a case number of one and of nine digits is admitted. The seam counts no call. The browser report's cap is
/// 3,000,000 characters, the cap of a text the instance reads, and its sentence says so.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.WRCPATTERN</code> allows 10 digits -> the case number legs go red.</p>
Method TestEveryValueShapeIsRefusedBeforeAnyCall()
{
    Set tSentence = $Parameter(..#ERROR, "REASONSQLREPORTWRC")
    For tWrc = "1", "999999999" {
        Kill tQuery
        Set tQuery("WRCNumber") = tWrc
        Do $$$AssertEquals(..Call(..#FIXTURE, "CASE", "*", .tQuery, .tAnswer, .tFault) _ "|" _ $ClassMethod(..#SAVE, "ValueProblem", "WRCNumber", tWrc), "200 |", "the case number '" _ tWrc _ "' is admitted")
    }
    Do $$$AssertEquals($Parameter(..#PORT, "MAXREPORTCHARACTERS") _ "|" _ $Parameter(..#ATELIER, "MAXIMPORTCHARACTERS") _ "|" _ ($Parameter(..#ERROR, "REASONSQLREPORTTOOLONG") [ "3,000,000 characters"), "3000000|3000000|1", "the browser report's cap is the instance's text cap and its sentence names it")
    For tWrc = "", "abc", "12ab", "0", "000", "007", "01", "1234567890", "-5", "1.5", " 12", "1E3", "+7" {
        Kill tQuery
        Set tQuery("WRCNumber") = tWrc
        Set tQuery("Statement") = $Parameter(..#PROBE, "REPORTQUERY")
        If tWrc '= "" Do $$$AssertEquals(..Call(..#FIXTURE, "CASE", "*", .tQuery, .tAnswer, .tFault), "400 " _ $Parameter(..#ERROR, "SQLREPORTWRC"), "the case read refuses '" _ tWrc _ "'")
        For tType = "SAVEQUERY", "GENERATE" {
            Kill tQuery
            Set tQuery("WRCNumber") = tWrc
            Set tQuery("Statement") = $Parameter(..#PROBE, "REPORTQUERY")
            Do $$$AssertEquals(..Call(..#FIXTURE, tType, "*", .tQuery, .tAnswer, .tFault) _ "|" _ $Select($IsObject(tFault): tFault.reason, 1: ""), "400 " _ $Parameter(..#ERROR, "SQLREPORTWRC") _ "|" _ tSentence, tType _ " refuses '" _ tWrc _ "' with the published sentence")
        }
        For tTool = ..#SAVE, ..#GENERATE {
            Set tSC = $ClassMethod(tTool, "ArgumentProblem", "*", {"Statement": ($Parameter(..#PROBE, "REPORTQUERY")), "WRCNumber": (tWrc), "root": "r", "path": "p"}, .tProblem)
            Do $$$AssertEquals(tProblem, tSentence, $Parameter(tTool, "TOOLNAME") _ " refuses '" _ tWrc _ "' for the agent with the same sentence")
        }
    }
    Kill tQuery
    Set tQuery("WRCNumber") = ..#CASE
    Set tQuery("Statement") = ""
    Do $$$AssertEquals(..Call(..#FIXTURE, "SAVEQUERY", "*", .tQuery, .tAnswer, .tFault), "400 PORT.VALIDATION", "an empty statement is refused")
    Set tQuery("Statement") = $Justify("x", 32001)
    Do $$$AssertEquals(..Call(..#FIXTURE, "SAVEQUERY", "*", .tQuery, .tAnswer, .tFault), "400 PORT.VALIDATION", "a statement over the vendor's bound is refused")
    Kill tQuery
    Set tQuery("Statement") = $Justify("x", 32001)
    Do $$$AssertEquals(..Call(..#FIXTURE, "CASE", "*", .tQuery, .tAnswer, .tFault), "400 PORT.VALIDATION", "and so it is at the case read the kernel sends before a case number is known")
    Set tSC = $ClassMethod(..#SAVE, "ArgumentProblem", "*", {"Statement": "", "WRCNumber": "2291"}, .tProblem)
    Do $$$AssertTrue(tProblem '= "", "the agent's empty statement is refused: " _ tProblem)
    Set tSC = $ClassMethod(..#SAVE, "ArgumentProblem", "x", {"Statement": "SELECT 1", "WRCNumber": "2291"}, .tProblem)
    Do $$$AssertTrue(tProblem [ "literal '*'", "any target but the literal '*' is refused: " _ tProblem)
    Set tSC = $ClassMethod(..#GENERATE, "ArgumentProblem", "*", {"WRCNumber": "2291", "root": "", "path": "p"}, .tProblem)
    Do $$$AssertTrue(tProblem [ "'root'", "an empty root is refused for the agent: " _ tProblem)
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 0, "the seam counted no call")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "ReportLeft", ..#NAMESPACE), 0, "and no saved query exists")
}

/// <p>AC1. A statement that is not a query is refused at the case read with the published sentence and nothing is called: an <code>UPDATE</code> of the
/// probe table, a <code>CREATE TABLE</code> and a <code>DELETE</code> are each typed by the instance and refused; the write itself refuses one that reaches it
/// directly. A statement over OcuPilot's own tables is refused by the console's check, and one the instance cannot prepare is refused as the console
/// refuses it.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.ReportWrite</code> skips its kind check -> the direct-write leg goes red (the seam counts a call).</p>
Method TestAStatementThatIsNotAQueryOrIsOcuPilotsOwnIsRefused()
{
    Set tSentence = $Parameter(..#ERROR, "REASONSQLREPORTQUERYONLY")
    For tCase = $ListBuild("UPDATE " _ $Parameter(..#PROBE, "REPORTTABLE") _ " SET B = 'x'", "dml"), $ListBuild("DELETE FROM " _ $Parameter(..#PROBE, "REPORTTABLE"), "dml"), $ListBuild("CREATE TABLE OcuProbe229.Z (A INTEGER)", "ddl") {
        Set tText = $List(tCase, 1)
        Kill tQuery
        Set tQuery("WRCNumber") = ..#CASE
        Set tQuery("Statement") = tText
        Set tFresh = ..Call(..#FIXTURE, "CASE", "*", .tQuery, .tAnswer, .tFault)
        Do $$$AssertEquals(tFresh _ "|" _ $Select($IsObject(tAnswer): tAnswer.Kind, 1: ""), "200 |" _ $List(tCase, 2), "the case read types '" _ $Extract(tText, 1, 20) _ "' as " _ $List(tCase, 2) _ ": " _ tFresh)
        Set tSC = $ClassMethod(..#SAVE, "StateDiff", tAnswer, .tRows, .tProblem)
        Do $$$AssertEquals(tProblem, tSentence, "the save's own state check refuses it with the published sentence, for both callers")
        Kill tQuery
        Set tQuery("WRCNumber") = ..#CASE
        Set tQuery("Statement") = tText
        Do $$$AssertEquals(..Call(..#FIXTURE, "SAVEQUERY", "*", .tQuery, .tAnswer, .tFault) _ "|" _ $Select($IsObject(tFault): tFault.reason, 1: ""), "422 " _ $Parameter(..#ERROR, "SQLREPORTQUERYONLY") _ "|" _ tSentence, "the write refuses it directly with 422")
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 0, "no vendor call was made for any")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "ReportLeft", ..#NAMESPACE), 0, "and no row was saved")
    Kill tQuery
    Set tQuery("WRCNumber") = ..#CASE
    Set tQuery("Statement") = "SELECT COUNT(*) AS Probe229 FROM OcuPilot_Kernel_State.Version"
    Set tCode = ..Call(..#FIXTURE, "SAVEQUERY", "*", .tQuery, .tAnswer, .tFault)
    Do $$$AssertEquals(tCode, "403 PROHIBITED.OCUPILOTSQL", "a query over OcuPilot's own tables is refused by the console's check: " _ tCode)
    Kill tQuery
    Set tQuery("WRCNumber") = ..#CASE
    Set tQuery("Statement") = "SELECT FROM WHERE"
    Set tCode = ..Call(..#FIXTURE, "SAVEQUERY", "*", .tQuery, .tAnswer, .tFault)
    Do $$$AssertEquals(tCode, "422 EXPLORER.SQL.NOTPREPARED", "a statement the instance cannot prepare is refused as the console refuses it: " _ tCode)
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls") _ "|" _ $ClassMethod(..#PROBE, "ReportLeft", ..#NAMESPACE), "0|0", "and neither called the instance or saved a row")
}

/// <p>AC1, AC2, AC3. The gate refuses before any read or call: without <code>%Development:USE</code> every type is 403 naming that pair, and without WRITE
/// on the namespace the reads answer and the three writes are 403, each with the seam asked for no call. A type the endpoint does not serve is 501.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.TuningInvoke</code> gates a report write as a read -> the WRITE leg goes red.</p>
Method TestTheGatesRefuseBeforeAnyReadOrCall()
{
    Set tId = ..SaveOne()
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Deny", "USE")
    For tType = "CASE", "SAVEDQUERY", "SAVEQUERY", "DELETEQUERY", "GENERATE" {
        Kill tQuery
        Set tQuery("WRCNumber") = ..#CASE
        Set tQuery("Statement") = $Parameter(..#PROBE, "REPORTQUERY")
        Set tCode = ..Call(..#FIXTURE, tType, $Select((tType = "SAVEDQUERY") || (tType = "DELETEQUERY"): tId, 1: "*"), .tQuery, .tAnswer, .tFault)
        Do $$$AssertEquals(tCode _ " " _ $Select($IsObject(tFault): tFault.detail.failedPair, 1: ""), "403 " _ ##class(OcuPilot.Kernel.Denial).Code() _ " %Development:USE", tType _ ": refused naming the Explorer's pair")
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 0, "the instance was asked for no call")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Deny", "WRITE")
    For tCase = $ListBuild("CASE", 200), $ListBuild("SAVEDQUERY", 200), $ListBuild("SAVEQUERY", 403), $ListBuild("DELETEQUERY", 403), $ListBuild("GENERATE", 403) {
        Set tType = $List(tCase, 1)
        Kill tQuery
        Set tQuery("WRCNumber") = ..#CASE
        Set tQuery("Statement") = $Parameter(..#PROBE, "REPORTQUERY")
        Set tCode = ..Call(..#FIXTURE, tType, $Select((tType = "SAVEDQUERY") || (tType = "DELETEQUERY"): tId, 1: "*"), .tQuery, .tAnswer, .tFault)
        Do $$$AssertEquals(+tCode, $List(tCase, 2), tType _ ": " _ $Select($List(tCase, 2) = 200: "a read passes without WRITE", 1: "a write is refused without it"))
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls") _ "|" _ $ListLength($ClassMethod(..#PROBE, "ReportIds", ..#NAMESPACE)), "0|1", "no write call was made and the saved query is still there")
    Do $ClassMethod(..#SEAM, "Reset")
    Kill tQuery
    Do $$$AssertEquals(..Call(..#FIXTURE, "LIST", "*", .tQuery, .tAnswer, .tFault), "501 PORT.NOTIMPLEMENTED", "a type the endpoint does not serve is refused")
    Do $$$AssertEquals(..Call(..#FIXTURE, "CASE", "x", .tQuery, .tAnswer, .tFault), "400 PORT.VALIDATION", "and so is a case read whose id is not the literal *")
}

/// <p>AC1, AC2, AC3. Each write's copy-out script (AD-59) is its own vendor call, with every caller value shown as a string literal.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.ReportSnippet</code> shows the statement unquoted -> the literal assertion goes red.</p>
Method TestTheCopyOutScriptsAreTheirVendorCall()
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("WRCNumber") = "2291"
    Set tQuery("Statement") = "SELECT ""x"" FROM T"
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Reports", "SAVEQUERY", .tQuery)
    Do $$$AssertEquals($Select(tSteps.%Size() = 1: tSteps.%Get(0).kind _ "|" _ tSteps.%Get(0).text, 1: tSteps.%ToJSON()), "objectscript| Set $NAMESPACE = ""USER""" _ $Char(10) _ " Set tSC = ##class(%SQL.Manager.QButtons.Base).InsertQuery(""SELECT """"x"""" FROM T"", ""2291"", 0, 0)" _ $Char(10) _ " If $System.Status.IsError(tSC) Do $System.Status.DisplayError(tSC)", "a save is one InsertQuery with the statement as a literal")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = "7"
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Reports", "DELETEQUERY", .tQuery)
    Do $$$AssertTrue(tSteps.%Get(0).text [ "ClearRow(""7"")", "a delete is one ClearRow with the id as a literal")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("WRCNumber") = "2291"
    Set tQuery("root") = "/r/"
    Set tQuery("path") = "r.xml"
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "Reports", "GENERATE", .tQuery)
    Do $$$AssertTrue(tSteps.%Get(0).text [ ("Set tFile = ##class(%File).NormalizeFilename(""r.xml"", ""/r/"")" _ $Char(10) _ " Set tSC = ##class(%SQL.Manager.QButtons.Base).WriteAllToFile(""2291"", tFile)"), "a generate is one WriteAllToFile to the file path names under root, as the reviewed write's: " _ tSteps.%Get(0).text)
    Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", "Reports", "CASE") _ "|" _ $ClassMethod(..#PORT, "SnippetForm", "Reports", "SAVEQUERY"), "|objectscript", "the reads have no script and the writes have one")
}

/// <p>AD-36. The list's read caps its rows at the cap the caller names and reports the cut: two saved queries, a cap of one answers one row with
/// <code>truncated</code> set, and a cap above the count answers both with it unset; each row carries the case, a status of <code>Planned</code> and the
/// statement as saved.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.AtelierPort.CATALOGSQLREPORTSQUERY</code> reads the status from the status column alone -> the status
/// assertion goes red.</p>
Method TestTheListCapsItsRowsAndReportsTheCut()
{
    Set tFirst = ..SaveOne()
    Set tSecond = ..SaveOne($Parameter(..#PROBE, "REPORTQUERY") _ " ORDER BY A")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#LIST, 100000, .tAll, .tHttp, .tFault)
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertEquals($Select($$$ISOK(tSC): tHttp, 1: 0), 200, "the screen's read answers: " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""))
    If $$$ISERR(tSC) || '$IsObject(tAll) Quit
    Set tFound = 0
    Set tIterator = tAll.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If (tRow.ID = tFirst) || (tRow.ID = tSecond) {
            Set tFound = tFound + 1
            Do $$$AssertEquals(tRow.WRCNumber _ "|" _ tRow.Status _ "|" _ (tRow.Statement [ "OcuProbe229.T"), ..#CASE _ "|Planned|1", "row " _ tRow.ID _ ": its case, status and statement")
        }
    }
    Do $$$AssertEquals(tFound, 2, "the list holds both saved queries")
    Do $$$AssertEquals(tAll.truncated, 0, "and reports no cut")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#LIST, 1, .tCut, .tHttp, .tFault)
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertEquals($Select($$$ISOK(tSC) && $IsObject(tCut): tHttp _ "|" _ tCut.rows.%Size() _ "|" _ tCut.truncated, 1: ""), "200|1|1", "a cap of one row is reported as truncation")
}

/// <p>A saved query whose plan is empty, as for an <code>INSERT</code> the instance saves without running it, is listed with the instance's own status
/// for the row, read from the vendor's table, and not as <code>Planned</code>.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.AtelierPort.CATALOGSQLREPORTSQUERY</code> answers <code>Planned</code> for every row -> the status assertion
/// goes red.</p>
Method TestARowWithNoPlanShowsTheInstancesOwnStatus()
{
    Set tId = ..SaveOne("INSERT INTO " _ $Parameter(..#PROBE, "REPORTTABLE") _ " (A, B) VALUES (99, 'zz')")
    Do $$$AssertTrue(tId '= "", "the instance saves an INSERT for the case: " _ tId)
    Set tOrigNS = $NAMESPACE
    Set $NAMESPACE = ..#NAMESPACE
    Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT QueryCompileDecomposedStatus, CASE WHEN QueryPlan IS NULL THEN 1 ELSE 0 END FROM %SQL_Manager_QButtons.Base WHERE ID = ?", tId)
    Set (tOwn, tEmpty) = ""
    If tResult.%Next() Set tOwn = tResult.%GetData(1), tEmpty = tResult.%GetData(2)
    Set tResult = ""
    Set $NAMESPACE = tOrigNS
    Do $$$AssertEquals(tEmpty, 1, "the saved INSERT has no plan")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#LIST, 100000, .tAll, .tHttp, .tFault)
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Set tStatus = "(not listed)"
    If $$$ISOK(tSC) && $IsObject(tAll) {
        Set tIterator = tAll.rows.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            If tRow.ID = tId Set tStatus = tRow.Status
        }
    }
    Do $$$AssertTrue((tStatus '= "Planned") && (tStatus = tOwn), "the list shows the instance's own status, not Planned: '" _ tStatus _ "' against '" _ tOwn _ "'")
}

/// <p>The list's note names who sees a saved query as the instance's own row-level security policy for the vendor's table says: the person who saved it
/// and each role <code>%SQL.Manager.QButtons.Base.%SecurityPolicy</code> answers beside that person, read from the instance, and no other role.</p>
/// <p>Mutation (Rule 19): the note drops <code>%Developer</code> -> the role assertion goes red.</p>
Method TestTheListNoteNamesTheRolesTheInstanceAdmits()
{
    Set tNote = ..Declaration(..#LIST).read.note.text
    Set tPolicy = ##class(%SQL.Manager.QButtons.Base).%SecurityPolicy("OcuProbeUser2129")
    Do $$$AssertEquals($Piece(tPolicy, ",", 1), "OcuProbeUser2129", "the instance's policy admits the user who saved a row")
    Set tRoles = $Piece(tPolicy, ",", 2, *)
    Do $$$AssertTrue(tRoles '= "", "and roles beside that user: " _ tPolicy)
    For tI = 1:1:$Length(tRoles, ",") {
        Do $$$AssertTrue(tNote [ (" " _ $Piece(tRoles, ",", tI)), "the note names the role " _ $Piece(tRoles, ",", tI) _ ": " _ tNote)
    }
    Do $$$AssertTrue(tNote [ "the person who saved it", "and the person who saved it: " _ tNote)
    Do $$$AssertEquals($Length(tNote, "%") - 1, $Length(tRoles, ","), "and no role the policy does not name: " _ tNote)
}

}
