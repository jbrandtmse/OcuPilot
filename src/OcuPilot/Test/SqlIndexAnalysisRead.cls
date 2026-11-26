/// <p>Pins Story 21.27's reads and the shapes its writes refuse before any call (AC1, AC2; AD-5, AD-21, AD-29, AD-35, AD-36, AD-51): the SQL index
/// analyzer list's declaration, the three tools' names, ports, request types, values and consequence codes, the fixed statement behind the list and its
/// row map, the rows it maps, the cap it reports, <class>OcuPilot.Port.SqlPort</class>'s <code>ANALYSIS</code> read, the gates and every id and value shape on
/// both callers, the copy-out scripts, that a vendor call made under the null device leaves the process's device and namespace as it found them, and the
/// shape of a checked read's refusal for want of the SQL SELECT privilege and of any other refusal (the refusal against a real principal is
/// <class>OcuPilot.Test.SqlSelectPrivilege</class>'s).</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, the calling account holding <code>%Development:USE</code> and READ and WRITE on
/// <code>USER</code>'s code databases, a <code>USER</code> namespace, and the fixture's procedure compiled in the namespace it runs in. Live-safe: it changes no store, gathers nothing and runs no report; the rows it
/// maps are canned through <class>OcuPilot.Test.AtelierPortFixture</class>.</p>
Class OcuPilot.Test.SqlIndexAnalysisRead Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.SqlPort";

Parameter FIXTURE = "OcuPilot.Test.SqlTuningPortFixture";

Parameter SEAM = "OcuPilot.Test.SqlTuningGateSeam";

Parameter ATELIER = "OcuPilot.Port.AtelierPort";

Parameter CATALOG = "OcuPilot.Test.AtelierPortCatalog";

Parameter NAMESPACE = "USER";

Parameter LIST = "OcuPilot.Screen.Descriptor.ExplorerSqlIndexAnalysis";

Parameter GATHER = "OcuPilot.Screen.Tool.ExplorerSqlIndexAnalysisGather";

Parameter RUN = "OcuPilot.Screen.Tool.ExplorerSqlIndexAnalysisRun";

Parameter PURGE = "OcuPilot.Screen.Tool.ExplorerSqlIndexAnalysisPurge";

Parameter ERROR = "OcuPilot.Api.AtelierError";

/// <p>The fields the list's row map names, in order.</p>
Parameter FIELDS = "Report,Counter,Schema,Table,Index,UsageCount,StatementType,ClassOrRoutine,Module,MapType,IndexFields,DataFields,IndexNeeded,Match,OutlierField,ExtentSize,BlockCount,Statement";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Test.AtelierPortFixture).Clear()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Test.AtelierPortFixture).Clear()
    Quit $$$OK
}

/// <p>The descriptor declaration of <var>pClass</var>.</p>
ClassMethod Declaration(pClass As %String) As %DynamicObject
{
    Do $ClassMethod(pClass, "DeclarationJson", .tDeclaration)
    Quit tDeclaration
}

/// <p>The screen declares the shape the story rules: route, position after the runtime statistics lists, entity type, composite id, source, the three page
/// actions and the classic page it replaces. The three tools name their port, endpoint and request types, take the values they declare and state their
/// consequence codes, the gather's naming the system classes when they are included.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Screen.Tool.ExplorerSqlIndexAnalysisGather.Consequence</code> ignores <code>SkipSystem</code> -> the system-classes
/// consequence assertion goes red; <code>OcuPilot.Api.AtelierError.ReasonFor</code> drops the gather's row -> the gather's sentence assertion goes red.</p>
Method TestTheScreenAndTheToolsDeclareTheirShape()
{
    Set tList = ..Declaration(..#LIST)
    Do $$$AssertEquals(tList.route _ "|" _ tList.sideBarPosition _ "|" _ tList.archetype _ "|" _ tList.entityType _ "|" _ tList.scope _ "|" _ tList.toolIdentifier, "system-explorer/sql-index-analysis|23|list|sql-index-analysis|namespace|explorer.sqlindexanalysis", "the list's route, position, archetype, entity type, scope and identifier")
    Do $$$AssertEquals(tList.id.kind _ "|" _ tList.id.parts.%ToJSON() _ "|" _ tList.read.source.port _ "|" _ tList.read.source.endpoint _ "|" _ tList.read.source.type _ "|" _ tList.read.paging, "composite|[""Report"",""Counter""]|atelier|Catalog.IndexAnalysis|LIST|cap", "its id is the report and the row's number, and its read the catalog's index analysis, capped")
    Set tActions = ""
    Set tIterator = tList.rowActions.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tAction) {
        Set tActions = tActions _ $Select(tActions = "": "", 1: ",") _ tAction.id
    }
    Do $$$AssertEquals(tActions _ "|" _ tList.classicPage _ "|" _ tList.privileges.%ToJSON(), "gather,run,purge|%CSP.UI.Portal.SQL.QButtons.IndexAnalyzer|[{""resource"":""%Development"",""permission"":""USE""}]", "it offers the three actions and replaces the classic page, whose resource it holds")
    Set tFields = ""
    Set tIterator = tList.read.fields.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) {
        Set tFields = tFields _ $Select(tFields = "": "", 1: ",") _ tField
    }
    Do $$$AssertEquals(tFields, ..#FIELDS, "it reads the report, the row's number, the table, the index, the statement and the report's own columns")
    Do $$$AssertEquals($Parameter(..#GATHER, "TOOLNAME") _ "|" _ $ClassMethod(..#GATHER, "PortClass") _ "|" _ $ClassMethod(..#GATHER, "Endpoint") _ "|" _ $ClassMethod(..#GATHER, "ReadType") _ "|" _ $ClassMethod(..#GATHER, "WriteType"), "explorer.sqlindexanalysis.gather|OcuPilot.Port.SqlPort|IndexAnalysis|ANALYSIS|GATHER", "the gather tool's name, port, endpoint and request types")
    Do $$$AssertEquals($Parameter(..#RUN, "TOOLNAME") _ "|" _ $ClassMethod(..#RUN, "WriteType") _ "|" _ $ClassMethod(..#RUN, "ReadType"), "explorer.sqlindexanalysis.run|RUNREPORT|ANALYSIS", "the run tool's name and request types")
    Do $$$AssertEquals($Parameter(..#PURGE, "TOOLNAME") _ "|" _ $ClassMethod(..#PURGE, "WriteType") _ "|" _ $ClassMethod(..#PURGE, "ReadType"), "explorer.sqlindexanalysis.purge|PURGEANALYSIS|ANALYSIS", "the purge tool's name and request types")
    Do $$$AssertEquals($ListToString($ClassMethod(..#GATHER, "SettableFields")) _ "|" _ $ListToString($ClassMethod(..#RUN, "SettableFields")) _ "|" _ ($ClassMethod(..#PURGE, "SettableFields") = ""), "SkipSystem,SkipInserts|Report,SkipSystem,SkipInserts,SkipIdKeys|1", "each tool declares the values it takes, and the purge none")
    Do $$$AssertEquals($ListToString($ClassMethod(..#GATHER, "RequiredFields")) _ "|" _ $ListToString($ClassMethod(..#RUN, "RequiredFields")), "|Report", "no gather value is required and the run requires its report")
    Do $$$AssertEquals($ClassMethod(..#GATHER, "Consequence", {}) _ "|" _ $ClassMethod(..#GATHER, "Consequence", {"SkipSystem": true}) _ "|" _ $ClassMethod(..#GATHER, "Consequence", {"SkipSystem": false}) _ "|" _ $ClassMethod(..#RUN, "Consequence", {}) _ "|" _ $ClassMethod(..#PURGE, "Consequence", {}), "SQL.INDEXANALYSIS.GATHER|SQL.INDEXANALYSIS.GATHER|SQL.INDEXANALYSIS.GATHERSYSTEM|SQL.INDEXANALYSIS.RUN|SQL.INDEXANALYSIS.PURGE", "a gather states the system classes' sentence only when they are included")
    Set tGather = "A new gathering of this namespace's cached queries, class methods, class queries and routines replaces its gathered statements and every report's results, and rebuilds its class dependency data."
    Do $$$AssertEquals($ClassMethod(..#PORT, "ReasonFor", "SQL.INDEXANALYSIS.GATHER"), tGather, "the gather's sentence is the ruled one")
    Do $$$AssertEquals($ClassMethod(..#PORT, "ReasonFor", "SQL.INDEXANALYSIS.GATHERSYSTEM"), tGather _ " Gathering system classes and routines can take longer than the page waits; the list shows the result when it finishes.", "the system classes' sentence is the plain one with the gathering outlasting the page said after it")
    Do $$$AssertEquals($ClassMethod(..#PORT, "ReasonFor", "SQL.INDEXANALYSIS.RUN"), "This report's earlier results in this namespace are replaced.", "the run's sentence is the ruled one")
    Do $$$AssertEquals($ClassMethod(..#PORT, "ReasonFor", "SQL.INDEXANALYSIS.PURGE"), "This namespace's gathered statements and every report's results are removed. Gather statements again before running a report.", "the purge's sentence is the ruled one")
}

/// <p>AD-35, AD-61 rule 7. The statement the list sends reads the vendor's result table with its statement joined through the pointer, binds nothing,
/// leaves a join or outlier row with an exact match out, maps each report and each match to its ruled name inside the text and selects every column
/// its row map reads; the row map names exactly the fields the screen shows, and the statement's text is masked.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Port.AtelierPort.CATALOGINDEXANALYSISQUERY</parameter> drops <code>JoinIndexFlag &lt; 4</code> -> the
/// exact-match assertion goes red; the row map drops <code>sqltext</code> from the statement -> the masking assertion goes red.</p>
Method TestTheListsStatementAndRowMapAreFixed()
{
    Set tQuery = $ZConvert($Parameter(..#ATELIER, "CATALOGINDEXANALYSISQUERY"), "U")
    Do $$$AssertTrue(tQuery [ "FROM %SYS_PTOOLS.UTILSQLANALYSISDB A LEFT OUTER JOIN %SYS_PTOOLS.UTILSQLSTATEMENTS S ON A.SQLPOINTER = S.ID", "it reads the result table and joins each row's statement through its pointer")
    Do $$$AssertTrue((tQuery [ "A.JOININDEXFLAG < 4") && (tQuery [ "A.OUTLIERINDEXFLAG < 4"), "a join or outlier row with an exact match is left out")
    Do $$$AssertTrue(tQuery '[ "?", "it binds nothing: the vendor keeps its rows per namespace")
    For tName = "INDEX USAGE", "TABLE SCAN", "TEMPORARY INDEX", "MISSING JOIN INDEX", "OUTLIER INDEX", "NO MATCH", "PARTIAL", "CONTAINS", "LEADING" {
        Do $$$AssertTrue(tQuery [ ("'" _ tName _ "'"), "it maps " _ tName _ " inside the statement")
    }
    Set tColumns = $Parameter(..#ATELIER, "CATALOGINDEXANALYSISCOLUMNS")
    Set tFields = ""
    For tI = 1:1:$Length(tColumns, ",") {
        Set tEntry = $Piece(tColumns, ",", tI)
        Set tFields = tFields _ $Select(tFields = "": "", 1: ",") _ $Piece(tEntry, ":", 1)
        Do $$$AssertTrue(tQuery [ (" AS " _ $Piece(tEntry, ":", 2) _ $Select($Piece(tEntry, ":", 2) = "STATEMENT": " FROM", 1: ",")), $Piece(tEntry, ":", 2) _ ": a column the statement selects")
    }
    Do $$$AssertEquals(tFields, ..#FIELDS, "the row map names the screen's fields and no other")
    Do $$$AssertEquals($Piece($Piece(tColumns, ",", 18), ":", 3), "sqltext", "the statement's text is masked as every statement text is")
    Do $$$AssertEquals($ClassMethod(..#ATELIER, "IsCatalog", "Catalog.IndexAnalysis"), 1, "the endpoint is one of the catalog's")
}

/// <p>The rows the list maps from the vendor's, through the fixture's canned query route: each column under its own field, the counter and the sizes as
/// numbers, the report and the match as the names the statement mapped, and a statement carrying a credential masked. The route is sent the list's fixed
/// statement with no value and the cap, and the read is capped at the cap the caller names (AD-36): three canned rows read at a cap of two answer two.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.AtelierPort.CatalogRows</code> binds the namespace for this endpoint -> the bound-values assertion goes red;
/// its row loop drops the cap test -> the cap assertion goes red.</p>
Method TestTheListMapsTheVendorsRowsAndKeepsToTheCap()
{
    Set tPlanted = "SELECT * FROM T WHERE X = 'a' /* CREATE USER u IDENTIFY BY 'secret1' */"
    Set tRow = {"REPORT_NAME": "Missing join index", "COUNTER": 11, "SCHEMA_NAME": "OcuProbe227", "TABLE_NAME": "T", "INDEX_NAME": "IDKEY", "USAGE_COUNT": 0, "STATEMENT_TYPE": "Class Method", "CLASS_OR_ROUTINE": "OcuProbe227.Scan", "MODULE_NAME": "", "MAP_TYPE": "master map ", "INDEX_FIELDS": "ID", "DATA_FIELDS": "", "INDEX_NEEDED": "B", "MATCH_NAME": "No match", "OUTLIER_FIELD": "", "EXTENT_SIZE": 100000, "BLOCK_COUNT": 3201}
    Do tRow.%Set("STATEMENT", tPlanted, "string")
    Do ##class(OcuPilot.Test.AtelierPortFixture).Clear()
    Do $ClassMethod(..#CATALOG, "ArmCatalog")
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("Query", "200 OK", $ClassMethod(..#CATALOG, "Envelope", tRow.%ToJSON() _ "," _ tRow.%ToJSON() _ "," _ tRow.%ToJSON()))
    Kill tQuery
    Set tQuery("maxRows") = 2
    Set tSC = $ClassMethod(..#CATALOG, "Read", "Catalog.IndexAnalysis", .tQuery, .tRows, .tHttp, .tFault)
    Set tCall = ##class(OcuPilot.Test.AtelierPortFixture).CallAt(1)
    Do $$$AssertEquals(tHttp _ " " _ ##class(OcuPilot.Test.AtelierPortFixture).CallCount() _ " " _ tCall.method _ " " _ tCall.params.%ToJSON(), "200 1 Query {""max"":2}", "one query call, sent the cap")
    Do $$$AssertEquals(tCall.body, $ClassMethod(..#CATALOG, "Body", "CATALOGINDEXANALYSISQUERY", "[]"), "exactly its fixed statement, with no value bound")
    If '$IsObject($Get(tRows)) Quit
    Do $$$AssertEquals(tRows.%Size(), 2, "three rows at a cap of two answer two")
    Set tMapped = tRows.%Get(0)
    Do $$$AssertEquals(tMapped.Report _ "|" _ tMapped.Counter _ "|" _ tMapped.Schema _ "|" _ tMapped.Table _ "|" _ tMapped.Index _ "|" _ tMapped.ClassOrRoutine _ "|" _ tMapped.IndexNeeded _ "|" _ tMapped.Match _ "|" _ tMapped.ExtentSize _ "|" _ tMapped.BlockCount, "Missing join index|11|OcuProbe227|T|IDKEY|OcuProbe227.Scan|B|No match|100000|3201", "each column is under its own field")
    Do $$$AssertEquals(tMapped.%GetTypeOf("Counter") _ "|" _ tMapped.%GetTypeOf("ExtentSize") _ "|" _ tMapped.%GetTypeOf("Report"), "number|number|string", "the counter and the sizes are numbers")
    Do $$$AssertTrue(tMapped.Statement '[ "secret1", "the credential is in no cell")
    Do $$$AssertTrue(tMapped.Statement [ ("IDENTIFY BY " _ $Parameter(..#PORT, "CREDENTIALMASK")), "the statement is there with its value masked: " _ tMapped.Statement)
}

/// <p>The gates, the ids and the values, before any call. A caller without <code>%Development:USE</code> is refused 403 naming the pair on the read and on
/// each write; one without WRITE on the namespace's routines database reads and is refused each write, with no vendor call made; the read and every write
/// name <code>*</code> alone, any other id is 400 <code>PORT.VALIDATION</code>, a type the endpoint does not serve is 501; a report outside the five answers
/// 400 <code>SQL.INDEXANALYSIS.REPORT</code> and a flag that is not <code>true</code> or <code>false</code> 400 <code>PORT.VALIDATION</code>, each with the
/// instance asked for no call.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.TuningInvoke</code> gates an analysis write as a read -> the WRITE assertions go red;
/// <code>OcuPilot.Port.SqlPort.AnalysisValues</code> sends a report unchecked -> the report assertion goes red.</p>
Method TestTheGatesAndShapesRefuseBeforeAnyCall()
{
    Set tFixture = ..#FIXTURE
    Do $ClassMethod(..#SEAM, "Deny", "USE")
    For tType = "ANALYSIS", "GATHER", "RUNREPORT", "PURGEANALYSIS" {
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("id") = "*"
        Set tQuery("Report") = "TS"
        Set tSC = $ClassMethod(tFixture, "Invoke", "IndexAnalysis", tType, .tQuery, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code _ " " _ tFault.detail.failedPair, 1: ""), "403 " _ ##class(OcuPilot.Kernel.Denial).Code() _ " %Development:USE", tType _ ": refused naming the Explorer's pair")
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 0, "the instance was asked for no call")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Deny", "WRITE")
    For tCase = $ListBuild("ANALYSIS", 200), $ListBuild("GATHER", 403), $ListBuild("RUNREPORT", 403), $ListBuild("PURGEANALYSIS", 403) {
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("id") = "*"
        Set tQuery("Report") = "TS"
        Set tSC = $ClassMethod(tFixture, "Invoke", "IndexAnalysis", $List(tCase, 1), .tQuery, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertEquals(+$Get(tHttp), $List(tCase, 2), $List(tCase, 1) _ ": " _ $Select($List(tCase, 2) = 200: "a read passes without WRITE", 1: "a write is refused without it"))
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 0, "no write call was made")
    Do $ClassMethod(..#SEAM, "Reset")
    For tCase = $ListBuild("ANALYSIS", "x"), $ListBuild("ANALYSIS", ""), $ListBuild("GATHER", "a b"), $ListBuild("RUNREPORT", "USER"), $ListBuild("PURGEANALYSIS", "%sqlcq.USER.cls1") {
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("id") = $List(tCase, 2)
        Set tQuery("Report") = "TS"
        Set tSC = $ClassMethod(tFixture, "Invoke", "IndexAnalysis", $List(tCase, 1), .tQuery, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "400 PORT.VALIDATION", $List(tCase, 1) _ " " _ $List(tCase, 2) _ ": refused")
    }
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = "*"
    Set tSC = $ClassMethod(tFixture, "Invoke", "IndexAnalysis", "LIST", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "501 PORT.NOTIMPLEMENTED", "a type the endpoint does not serve is refused")
    For tCase = $ListBuild("ZZ"), $ListBuild("iu"), $ListBuild(""), $ListBuild("IU,TS") {
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("id") = "*"
        Set tQuery("Report") = $List(tCase, 1)
        Set tSC = $ClassMethod(tFixture, "Invoke", "IndexAnalysis", "RUNREPORT", .tQuery, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code _ " " _ tFault.reason, 1: ""), "400 SQL.INDEXANALYSIS.REPORT " _ $Parameter(..#ERROR, "REASONINDEXANALYSISREPORT"), "the report '" _ $List(tCase, 1) _ "' is refused with the ruled sentence")
    }
    For tFlag = "SkipSystem", "SkipInserts", "SkipIdKeys" {
        For tValue = "maybe", "1", "TRUE", "yes" {
            Kill tQuery
            Set tQuery("namespace") = ..#NAMESPACE
            Set tQuery("id") = "*"
            Set tQuery("Report") = "IU"
            Set tQuery(tFlag) = tValue
            Set tSC = $ClassMethod(tFixture, "Invoke", "IndexAnalysis", "RUNREPORT", .tQuery, "", .tAnswer, .tHttp, .tFault)
            Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "400 PORT.VALIDATION", tFlag _ " " _ tValue _ ": refused")
        }
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 0, "and none of these refusals asked the instance for a call")
}

/// <p>The same values, judged for both callers before anything is stored: the agent's mint (<code>ArgumentProblem</code>) and the screen's action
/// (<code>ScreenActionDelta</code>) refuse a report outside the five with the port's published sentence and a flag that is not a boolean with its own,
/// and a run that names no report; a gather leaves both skip choices out, and a valid set becomes the arguments the port is sent.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Screen.Tool.SqlIndexAnalysisAction.ValueProblem</code> answers <code>""</code> -> the report assertions go red.</p>
Method TestBothCallersRefuseABadValueBeforeAnythingIsStored()
{
    Set tReason = $Parameter(..#ERROR, "REASONINDEXANALYSISREPORT")
    Do $ClassMethod(..#RUN, "ArgumentProblem", "*", {"Report": "ZZ"}, .tProblem)
    Do $$$AssertEquals(tProblem, tReason, "the mint refuses a report outside the five")
    Do $ClassMethod(..#RUN, "ArgumentProblem", "*", {}, .tProblem)
    Do $$$AssertTrue(tProblem '= "", "and a run that names no report: " _ tProblem)
    Do $ClassMethod(..#RUN, "ArgumentProblem", "*", {"Report": "TS", "SkipIdKeys": "yes"}, .tProblem)
    Do $$$AssertEquals(tProblem, "'SkipIdKeys' is true or false", "and a flag that is not a boolean")
    Do $ClassMethod(..#RUN, "ArgumentProblem", "*", {"Report": "TS", "SkipIdKeys": false}, .tProblem)
    Do $$$AssertEquals(tProblem, "", "a report and a boolean pass")
    Do $ClassMethod(..#GATHER, "ArgumentProblem", "*", {}, .tProblem)
    Do $$$AssertEquals(tProblem, "", "a gather needs no value")
    Do $ClassMethod(..#GATHER, "ArgumentProblem", "x", {}, .tProblem)
    Do $$$AssertTrue(tProblem [ "must be the literal '*'", "and a target other than * is refused: " _ tProblem)
    Do $ClassMethod(..#RUN, "ScreenActionDelta", "run", {"Target": "*", "Report": "ZZ", "SkipSystem": "true", "SkipInserts": "true", "SkipIdKeys": "true"}, {}, .tArgs, .tProblem)
    Do $$$AssertEquals(tProblem, tReason, "the screen refuses the same report with the same sentence")
    Do $ClassMethod(..#RUN, "ScreenActionDelta", "run", {"Target": "*", "Report": "IU", "SkipSystem": "true", "SkipInserts": "maybe", "SkipIdKeys": "true"}, {}, .tArgs, .tProblem)
    Do $$$AssertEquals(tProblem, "'SkipInserts' is true or false", "and a flag the screen sent in any other spelling")
    Do $ClassMethod(..#RUN, "ScreenActionDelta", "run", {"Target": "*", "Report": "IU", "SkipSystem": "false", "SkipInserts": "true", "SkipIdKeys": "false"}, {}, .tArgs, .tProblem)
    Do $$$AssertEquals(tProblem _ "|" _ tArgs.%ToJSON(), "|{""Report"":""IU"",""SkipSystem"":false,""SkipInserts"":true,""SkipIdKeys"":false}", "a valid set becomes the arguments, each of its kind")
    Do $ClassMethod(..#GATHER, "ScreenActionDelta", "gather", {"Target": "*", "SkipSystem": "true", "SkipInserts": "false"}, {}, .tArgs, .tProblem)
    Do $$$AssertEquals(tProblem _ "|" _ tArgs.%ToJSON(), "|{""SkipSystem"":true,""SkipInserts"":false}", "and so does the gather's")
    Kill tQuery
    Do $ClassMethod(..#RUN, "PortQuery", {"Namespace": "USER", "Report": "TI", "SkipSystem": false, "SkipInserts": true, "SkipIdKeys": true}, .tQuery)
    Do $$$AssertEquals($Get(tQuery("namespace")) _ "|" _ $Get(tQuery("Report")) _ "|" _ $Get(tQuery("SkipSystem")) _ "|" _ $Get(tQuery("SkipInserts")) _ "|" _ $Get(tQuery("SkipIdKeys")), "USER|TI|false|true|true", "the values reach the port in its query, the booleans as true or false")
}

/// <p>The copy-out scripts (AD-59): a gather is the two clears and the gathering, a report its one vendor call with the classic page's arguments, and a purge
/// the two clears, each in the namespace the query names, each flag as 1 unless the query carries <code>false</code>, and a report outside the five renders
/// no script. The three writes have a script form, and the read has none.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.AnalysisSnippet</code> names <code>tableScans</code> for every report -> the report scripts go red.</p>
Method TestTheCopyOutScriptsAreTheVendorCalls()
{
    Set tHead = " Set $NAMESPACE = ""USER"""
    Set tShow = $Char(10) _ " If $System.Status.IsError(tSC) Do $System.Status.DisplayError(tSC)"
    Set tClass = "##class(%SYS.PTools.UtilSQLAnalysis)."
    Set tClears = $Char(10) _ " Set tSC = " _ tClass _ "clearSQLStatements(""USER"")" _ tShow _ $Char(10) _ " Set tSC = " _ tClass _ "clearSQLAnalysisDB(""USER"")" _ tShow
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = "*"
    Set tQuery("SkipSystem") = "true"
    Set tQuery("SkipInserts") = "false"
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "IndexAnalysis", "GATHER", .tQuery)
    Do $$$AssertEquals($Select(tSteps.%Size() = 1: tSteps.%Get(0).kind _ "|" _ tSteps.%Get(0).text, 1: tSteps.%ToJSON()), "objectscript|" _ tHead _ tClears _ $Char(10) _ " Set tSC = " _ tClass _ "getAllSQLStmts(1, 1, 0, 0, 0)" _ tShow, "the gather's script is the two clears and the gathering with the choices sent")
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "IndexAnalysis", "PURGEANALYSIS", .tQuery)
    Do $$$AssertEquals($Select(tSteps.%Size() = 1: tSteps.%Get(0).text, 1: tSteps.%ToJSON()), tHead _ tClears, "the purge's script is the two clears")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = "*"
    For tCase = $ListBuild("IU", "indexUsage(1, 1, 0, 1, 0, 1, 0)"), $ListBuild("TS", "tableScans(1, 0, 1, 1, 0)"), $ListBuild("TI", "tempIndices(1, 0, 1, 1, 0)"), $ListBuild("JI", "joinIndices(1, 0, 1, 1, 0)"), $ListBuild("OI", "outlierIndices(1, 0, 1, 1, 0)") {
        Set tQuery("Report") = $List(tCase, 1)
        Set tQuery("SkipIdKeys") = "false"
        Set tSteps = $ClassMethod(..#PORT, "Snippet", "IndexAnalysis", "RUNREPORT", .tQuery)
        Do $$$AssertEquals($Select(tSteps.%Size() = 1: tSteps.%Get(0).text, 1: tSteps.%ToJSON()), tHead _ $Char(10) _ " Set tSC = " _ tClass _ $List(tCase, 2) _ tShow, $List(tCase, 1) _ ": the report's one vendor call with the classic page's arguments")
    }
    Set tQuery("Report") = "ZZ"
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "IndexAnalysis", "RUNREPORT", .tQuery)
    Do $$$AssertEquals(tSteps.%Size(), 0, "a report outside the five renders no script")
    Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", "IndexAnalysis", "ANALYSIS") _ "|" _ $ClassMethod(..#PORT, "SnippetForm", "IndexAnalysis", "GATHER") _ "|" _ $ClassMethod(..#PORT, "SnippetForm", "IndexAnalysis", "RUNREPORT") _ "|" _ $ClassMethod(..#PORT, "SnippetForm", "IndexAnalysis", "PURGEANALYSIS"), "|objectscript|objectscript|objectscript", "the three writes have a script form and the read has none")
}

/// <p>A vendor call made under the null device (<method>OcuPilot.Kernel.Utils.CallWithNullDevice</method>): what the call writes is discarded and the call's
/// value is answered, the call runs in the namespace named and the process's namespace is the caller's after, and a call that raises answers its failure
/// as a status with the device, its mnemonic space and the namespace as the caller left them, and the null device closed again where the call opened it.
/// The caller's device here is a file, so output that reached it would be written to it.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Kernel.Utils.CallWithNullDevice</code> restores the device only after a call that returned -> the raised-call
/// assertions go red.</p>
Method TestAVendorCallUnderTheNullDeviceLeavesTheProcessAsItWasFound()
{
    Set tFile = ##class(%File).TempFilename("txt")
    Set tOrigNS = $NAMESPACE
    Set tNull = ##class(%Library.Device).GetNullDevice()
    Set tNullOpenBefore = ##class(OcuPilot.Kernel.Utils).DeviceIsOpen(tNull)
    Set tCurrent = $IO
    Open tFile:"WS":5
    Set tOpened = $Test
    Do $$$AssertTrue(tOpened, "a file is opened to stand for the caller's device")
    If 'tOpened Quit
    Use tFile::("^%X364")
    Set tMnemonic = ##class(%Library.Device).GetMnemonicRoutine()
    Set tSC = ##class(OcuPilot.Kernel.Utils).CallWithNullDevice(..#NAMESPACE, "%SYSTEM.OBJ", "ShowFlags", 0, .tResult)
    Set tAfterDevice = $IO
    Set tAfterNS = $NAMESPACE
    Set tSC2 = ##class(OcuPilot.Kernel.Utils).CallWithNullDevice(..#NAMESPACE, "%SYSTEM.Process", "NameSpace", 1, .tValue)
    Set tSC3 = ##class(OcuPilot.Kernel.Utils).CallWithNullDevice(..#NAMESPACE, "%SYSTEM.Process", "NoSuchMethod", 1, .tRaised)
    Set tRaisedDevice = $IO
    Set tRaisedMnemonic = ##class(%Library.Device).GetMnemonicRoutine()
    Set tRaisedNS = $NAMESPACE
    Set tRaisedNullOpen = ##class(OcuPilot.Kernel.Utils).DeviceIsOpen(tNull)
    Use tCurrent
    Close tFile
    Set tBytes = ##class(%File).GetFileSize(tFile)
    Do ##class(%File).Delete(tFile)
    Do $$$AssertStatusOK(tSC, "a call that writes answers its status")
    Do $$$AssertEquals(tBytes, 0, "and what it wrote did not reach the caller's device")
    Do $$$AssertEquals(tAfterDevice, tFile, "the caller's device is current again")
    Do $$$AssertEquals(tAfterNS, tOrigNS, "and so is its namespace")
    Do $$$AssertEquals($$$ISOK(tSC2) _ "|" _ tValue, "1|" _ ..#NAMESPACE, "a call that answers a value answers it, made in the namespace named")
    Do $$$AssertEquals($$$ISERR(tSC3) _ "|" _ tRaised, "1|", "a call that raises answers its failure and no value")
    Do $$$AssertEquals(tRaisedDevice _ "|" _ tRaisedNS, tFile _ "|" _ tOrigNS, "with the device and the namespace as the caller left them")
    Do $$$AssertEquals(tRaisedNullOpen, tNullOpenBefore, "and the null device as it was found")
    Do $$$AssertEquals(tRaisedMnemonic, tMnemonic, "and the caller's device keeps its mnemonic space")
    Do $$$AssertTrue(tMnemonic '= "", "which the caller's device was given: " _ tMnemonic)
    Do $$$AssertEquals($NAMESPACE _ "|" _ $IO, tOrigNS _ "|" _ tCurrent, "the process ends where it began")
}

/// <p>The tables a refused read names are the port's own list, equal to the tables its fixed statement selects from; the refusal is 403
/// <code>SQL.SELECT.PRIVILEGE</code> with the ruled sentence, listing several tables joined by <code>and</code>, the same sentence in
/// <code>detail.reason</code> beside <code>detail.tables</code>, and nothing of the instance's own error.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Port.SqlPort.ANALYSISTABLES</parameter> drops <code>%SYS_PTools.UtilSQLAnalysisDB</code> -> the list leg goes
/// red; <method>OcuPilot.Port.SqlPort.SelectRefusal</method> answers 500 -> the refusal leg goes red.</p>
Method TestARefusedReadNamesItsOwnTablesInTheRuledSentence()
{
    For tCase = $ListBuild("STATSCOUNTQUERY", "STATSTABLES"), $ListBuild("ANALYSISCOUNTQUERY", "ANALYSISTABLES"), $ListBuild("ADVICECLASSQUERY", "ADVICECLASSTABLES"), $ListBuild("ADVICEINDEXQUERY", "ADVICEINDEXTABLES") {
        Set tText = $Parameter(..#PORT, $List(tCase, 1))
        Set tFrom = ""
        Set tPosition = 1
        While $Locate(tText, "FROM [^ )]+", tPosition, tEnd, tMatch) {
            Set tFrom = tFrom _ $Select(tFrom = "": "", 1: ",") _ $Piece(tMatch, " ", 2)
            Set tPosition = tEnd
        }
        Set tTables = $Parameter(..#PORT, $List(tCase, 2))
        Do $$$AssertEquals($ListToString($ListFromString(tFrom)), tTables, $List(tCase, 2) _ " lists the tables " _ $List(tCase, 1) _ " selects from")
    }
    Set tSentence = "Reading this needs the SQL SELECT privilege on %1."
    Do $$$AssertEquals($ClassMethod(..#PORT, "ReasonFor", ##class(OcuPilot.Api.AtelierError).#SQLSELECTPRIVILEGE), tSentence, "the sentence is the ruled one")
    Do $$$AssertEquals(##class(OcuPilot.Api.AtelierError).#SQLSELECTPRIVILEGE, "SQL.SELECT.PRIVILEGE", "under the ruled code")
    Set tSC = $ClassMethod(..#FIXTURE, "RefusalOf", $Parameter(..#PORT, "ANALYSISTABLES"), .tHttp, .tFault)
    Do $$$AssertStatusNotOK(tSC, "a refusal is an error status")
    Do $$$AssertEquals(tHttp, 403, "answered 403")
    Do $$$AssertEquals(tFault.%Get("code"), "SQL.SELECT.PRIVILEGE", "with the ruled code")
    Do $$$AssertEquals(tFault.%Get("error"), ##class(OcuPilot.Api.Error).#FORBIDDEN, "on the forbidden slug")
    Set tReason = "Reading this needs the SQL SELECT privilege on %SYS_PTools.UtilSQLStatements and %SYS_PTools.UtilSQLAnalysisDB."
    Do $$$AssertEquals(tFault.%Get("reason"), tReason, "naming both tables, joined by and")
    Do $$$AssertEquals(tFault.detail.%Get("reason") _ "|" _ tFault.detail.%Get("tables"), tReason _ "|%SYS_PTools.UtilSQLStatements and %SYS_PTools.UtilSQLAnalysisDB", "and the tool result's detail carries the same sentence and the tables")
    Do $$$AssertEquals(tFault.detail.%Size(), 2, "and nothing else")
    Set tSC = $ClassMethod(..#FIXTURE, "RefusalOf", $Parameter(..#PORT, "STATSTABLES"), .tHttp, .tFault)
    Do $$$AssertEquals(tFault.%Get("reason"), "Reading this needs the SQL SELECT privilege on %SYS_PTools.StatsSQL.", "one table is named alone")
}

/// <p>A checked read the instance refuses with any other negative SQLCODE, at prepare (an unknown table, -30), at execute (-400 from the fixture's
/// procedure, in the namespace it is compiled in) or at fetch (a division by zero, -400), is the internal fault as before: 500 with the generic code
/// and reason, no <code>detail</code>, and nothing of the statement or the instance's message in the answer.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.SqlPort.CheckedRows</method> and <method>CheckedRow</method> treat every negative SQLCODE as a privilege
/// refusal -> every leg goes red answering 403; they leave the fetch's SQLCODE unread -> the fetch legs go red answering 200.</p>
Method TestAnotherNegativeSqlcodeStaysTheInternalFault()
{
    For tCase = $ListBuild("prepare", ..#NAMESPACE, "SELECT A FROM OcuProbe2127Missing.Nothing"), $ListBuild("execute", $NAMESPACE, "CALL OcuPilot_Test.OcuProbe2127Code(-400)"), $ListBuild("fetch", ..#NAMESPACE, "SELECT TOP 3 1/(ID-ID) FROM %Dictionary.CompiledClass") {
        For tMethod = "RowsOf", "RowOf" {
            Kill tFault
            Set tLeg = tMethod _ " at " _ $List(tCase, 1)
            Set tSC = $ClassMethod(..#FIXTURE, tMethod, $List(tCase, 2), $List(tCase, 3), "%SYS_PTools.StatsSQL", .tHttp, .tFault)
            Do $$$AssertStatusNotOK(tSC, tLeg _ ": a refused read is an error status")
            Do $$$AssertEquals($Get(tHttp) _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code") _ "|" _ tFault.%Get("reason"), 1: ""), "500|" _ ##class(OcuPilot.Api.Error).#INTERNAL _ "|" _ ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, tLeg _ ": the internal fault")
            Continue:'$IsObject($Get(tFault))
            Do $$$AssertEquals(tFault.%GetTypeOf("detail"), "unassigned", tLeg _ ": with no detail")
            Do $$$AssertTrue((tFault.%ToJSON() '[ "Nothing") && (tFault.%ToJSON() '[ "OcuProbe2127Code") && (tFault.%ToJSON() '[ "DIVIDE"), tLeg _ ": and nothing of the statement or the instance's message")
        }
    }
}

/// <p>A checked read whose prepare succeeds and whose execute the instance answers SQLCODE -99 is the same 403 <code>SQL.SELECT.PRIVILEGE</code> as a
/// refused prepare, naming the tables the caller passed and nothing of the statement, through both helpers.</p>
/// <p>Mutation (Rule 19): <method>OcuPilot.Port.SqlPort.CheckedRows</method> and <method>CheckedRow</method> take the refusal from the prepare alone -> both
/// legs go red answering 500.</p>
Method TestAnExecuteTimeRefusalIsTheSelectRefusal()
{
    Set tReason = "Reading this needs the SQL SELECT privilege on %SYS_PTools.StatsSQL."
    For tMethod = "RowsOf", "RowOf" {
        Kill tFault
        Set tSC = $ClassMethod(..#FIXTURE, tMethod, $NAMESPACE, "CALL OcuPilot_Test.OcuProbe2127Code(-99)", "%SYS_PTools.StatsSQL", .tHttp, .tFault)
        Do $$$AssertStatusNotOK(tSC, tMethod _ ": a refused read is an error status")
        Do $$$AssertEquals($Get(tHttp) _ "|" _ $Select($IsObject($Get(tFault)): tFault.%Get("code") _ "|" _ tFault.%Get("reason"), 1: ""), "403|SQL.SELECT.PRIVILEGE|" _ tReason, tMethod _ ": an execute-time -99 is the privilege refusal")
        Continue:'$IsObject($Get(tFault))
        Do $$$AssertTrue(tFault.%ToJSON() '[ "OcuProbe2127Code", tMethod _ ": and nothing of the statement")
    }
}

}
