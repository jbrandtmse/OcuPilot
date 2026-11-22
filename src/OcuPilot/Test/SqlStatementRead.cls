/// <p>Pins Story 21.6's reads (AC1, AC4; AD-5, AD-36, AD-51, AD-61): the SQL statements screen's declaration; the namespace's statement index read
/// by the screen and by the agent's <code>explorer.sqlstatements.read</code> as the same capped rows, the probe statement's row carrying its hash,
/// plan state, new plan, plan error and statistics as the instance's information schema holds them; <class>OcuPilot.Port.SqlPort</class>'s
/// <code>STATEMENT</code> and <code>PURGE</code> reads and their shapes, counts, not-found answers and hostile ids; each write's copy-out script;
/// and the gates, refused before any read or write.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, the calling account holding <code>%Development:USE</code> and READ on
/// <code>USER</code>'s code databases, and a <code>USER</code> namespace, where each test makes <class>OcuPilot.Test.SqlTuningProbe</class>'s
/// objects and removes them after. The screen's read runs in process through <method>OcuPilot.Screen.Read.Execute</method>, which the route's
/// handler calls. Live-safe: it changes nothing a person owns.</p>
Class OcuPilot.Test.SqlStatementRead Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.SqlTuningProbe";

Parameter PORT = "OcuPilot.Port.SqlPort";

Parameter FIXTURE = "OcuPilot.Test.SqlTuningPortFixture";

Parameter SEAM = "OcuPilot.Test.SqlTuningGateSeam";

Parameter NAMESPACE = "USER";

Parameter LIST = "OcuPilot.Screen.Descriptor.ExplorerSqlStatementList";

Parameter CACHED = "OcuPilot.Screen.Descriptor.ExplorerSqlCachedQueries";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Reset")
    Set tSC = $ClassMethod(..#PROBE, "Make", ..#NAMESPACE)
    Do $$$AssertStatusOK(tSC, "the probe objects are created in " _ ..#NAMESPACE)
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Reset")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#NAMESPACE), "every probe object is removed")
    Quit $$$OK
}

/// <p>The descriptor declaration of <var>pClass</var>.</p>
ClassMethod Declaration(pClass As %String) As %DynamicObject
{
    Do $ClassMethod(pClass, "DeclarationJson", .tDeclaration)
    Quit tDeclaration
}

/// <p>The statement index's row the probe's <var>pToken</var> statement holds in <var>pAnswer</var>, a screen read's answer, or <code>""</code>.</p>
ClassMethod RowOf(pAnswer As %DynamicObject, pHash As %String) As %DynamicObject
{
    If '$IsObject(pAnswer) || (pAnswer.%GetTypeOf("rows") '= "array") Quit ""
    Set tIterator = pAnswer.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("Hash") = pHash Quit
        Set tRow = ""
    }
    Quit $Get(tRow)
}

/// <p>The statements screen declares the shape the story rules: the route, the position after System Explorer's nineteen, the statement-index entity
/// type, its source and its five row actions; the Cached queries tab's entity type is the cached query's, with its three purge actions.</p>
/// <p>Mutation (Rule 19): drop <code>Hash</code> from the list's read fields -> the fields assertion goes red.</p>
Method TestTheScreenDeclaresItsShape()
{
    Set tList = ..Declaration(..#LIST)
    Do $$$AssertEquals(tList.route _ "|" _ tList.sideBarPosition _ "|" _ tList.archetype _ "|" _ tList.entityType _ "|" _ tList.scope _ "|" _ tList.toolIdentifier, "system-explorer/sql-statements|20|list|statement-index-entry|namespace|explorer.sqlstatements", "its route, position, archetype, entity type, scope and identifier")
    Do $$$AssertEquals(tList.read.source.port _ "|" _ tList.read.source.endpoint _ "|" _ tList.read.source.type, "atelier|Catalog.Statements|LIST", "its read is the statement index's list")
    Do $$$AssertEquals(tList.read.fields.%ToJSON(), "[""Hash"",""Statement"",""Tables"",""PlanState"",""NewPlan"",""PlanError"",""PlanSaved"",""PlanVersion"",""Executions"",""TotalTime"",""AverageTime"",""StdDevTime"",""RowCount"",""Commands"",""FirstSeen"",""Location""]", "it reads the hash, text, tables, plan state, new plan, plan error, plan time, version and statistics")
    Do $$$AssertEquals(tList.read.%GetTypeOf("criteria"), "unassigned", "it declares no criterion")
    Set tActions = ""
    Set tIterator = tList.rowActions.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tAction) {
        Set tActions = tActions _ $Select(tActions = "": "", 1: ",") _ tAction.id
    }
    Do $$$AssertEquals(tActions, "freeze,unfreeze,clear-statistics,clear-error,clean", "its row actions")
    Do $$$AssertEquals(tList.classicPage, "%CSP.UI.Portal.SQL.Home", "it replaces the classic SQL page")
    Do $$$AssertEquals(tList.read.note.key, "explorerSqlStatementsNote", "it carries the statistics note")
    Set tCached = ..Declaration(..#CACHED)
    Set tActions = ""
    Set tIterator = tCached.rowActions.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tAction) {
        Set tActions = tActions _ $Select(tActions = "": "", 1: ",") _ tAction.id
    }
    Do $$$AssertEquals(tCached.entityType _ "|" _ tActions, "cached-query|purge,purge-table,purge-namespace", "the Cached queries tab's entity type and purge actions")
}

/// <p>AC1. The screen's read and the agent's <code>explorer.sqlstatements.read</code> answer the same capped rows, and the probe statement's row
/// carries what the information schema holds for it: its hash, plan state, new plan, plan error, statistics, tables and location. A cap of one row is
/// reported as truncation.</p>
/// <p>Mutation (Rule 19): <code>CATALOGSTATEMENTINDEXQUERY</code> drops <code>s.Error AS PLAN_ERROR</code> -> the plan error assertion goes red;
/// the descriptor drops <code>Hash</code> from its fields -> <code>screen-mirror.test.mjs</code> goes red.</p>
Method TestTheListAndTheAgentsReadAnswerTheSameRows()
{
    Set tTwo = $ClassMethod(..#PROBE, "HashOf", ..#NAMESPACE, "SELECT B FROM")
    Set tOne = $ClassMethod(..#PROBE, "HashOf", ..#NAMESPACE, "SELECT A FROM")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#LIST, 1000, .tScreen, .tHttp, .tFault)
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertEquals($Select($$$ISOK(tSC): tHttp, 1: 0), 200, "the screen's read answers: " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""))
    If $$$ISERR(tSC) || '$IsObject(tScreen) Quit
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a completed turn is seeded")
    Set tUse = {"type": "tool_use", "id": "toolu_sqlstatements"}
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName("explorer.sqlstatements.read"), "string")
    Do tUse.%Set("input", {"filter": "OCUPROBE216", "maxRows": 1000})
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurnKey, $Username, "", [(tUse)], ..#LIMITS, .tResults, .tNames, 0, 0, .tDetails)
    Do $$$AssertStatusOK(tSC, "the agent's read is dispatched")
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    If $$$ISERR(tSC) Quit
    Set tAgent = ##class(%DynamicObject).%FromJSON(tResults.%Get(0).%Get("content"))
    Do $$$AssertEquals(tResults.%Get(0).%Get("is_error"), 0, "and answers rows")
    Set tScreenRow = ..RowOf(tScreen, tOne)
    Set tAgentRow = ..RowOf(tAgent, tOne)
    Do $$$AssertTrue($IsObject(tScreenRow) && $IsObject(tAgentRow), "both answer the probe statement's row")
    If '$IsObject(tScreenRow) || '$IsObject(tAgentRow) Quit
    Do $$$AssertEquals(tScreenRow.%ToJSON(), tAgentRow.%ToJSON(), "the two rows are one")
    Set tView = ##class(OcuPilot.Screen.Read).ApplyView(tScreen.rows, ..Declaration(..#LIST).read, "OCUPROBE216")
    Do $$$AssertEquals(tView.%ToJSON(), tAgent.rows.%ToJSON(), "and the rows the agent's filter keeps are the screen's rows under the same view")
    Set tFacts = $ClassMethod(..#PROBE, "Facts", ..#NAMESPACE, tOne)
    Do $$$AssertEquals(tScreenRow.PlanState _ "|" _ tScreenRow.NewPlan _ "|" _ tScreenRow.PlanError _ "|" _ tScreenRow.Executions _ "|" _ tScreenRow.Tables, tFacts.PlanState _ "|0||" _ tFacts.Executions _ "|OCUPROBE216.T1", "the row's plan state, new plan, plan error, executions and tables are the information schema's")
    Do $$$AssertEquals(tScreenRow.Executions, 3, "its statistics are the three recorded runs")
    Do $$$AssertTrue(($Extract(tScreenRow.Location, 1, 7) = "%sqlcq.") && (tScreenRow.PlanSaved '= "") && (tScreenRow.PlanVersion '= ""), "its location, plan time and plan version are present")
    Do $$$AssertTrue(tScreenRow.Statement [ "OCUPROBE216", "its text is the statement's: " _ tScreenRow.Statement)
    Set tErrorRow = ..RowOf(tScreen, tTwo)
    Do $$$AssertEquals($Select($IsObject(tErrorRow): tErrorRow.PlanError, 1: ""), ##class(OcuPilot.Test.SqlTuningProbe).#PLANERROR, "the statement with the plan error shows it")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#LIST, 1, .tCut, .tHttp, .tFault)
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertEquals($Select($$$ISOK(tSC) && $IsObject(tCut): tHttp _ "|" _ tCut.rows.%Size() _ "|" _ tCut.truncated, 1: ""), "200|1|1", "a cap of one row is reported as truncation")
}

/// <p>AC1, AC4. The port's <code>STATEMENT</code> read answers one statement's <code>{Namespace, Hash, PlanState, NewPlan, PlanError, Executions,
/// AverageTime, Tables}</code> and, for <code>*</code>, the index's statements and stale entries; its <code>PURGE</code> read answers the cached
/// queries the namespace, a table or one class holds, each as the information schema counts them. An absent statement, class or table is 404
/// <code>PORT.NOTFOUND</code>, a hostile id 400 <code>PORT.VALIDATION</code> and any other endpoint or type 501, each before anything is read past
/// the gate.</p>
/// <p>Mutation (Rule 19): the table's count joins no relation (the <code>PURGETABLEQUERY</code> drops its <code>r.Relation = ?</code> condition) -> the
/// table counts go red.</p>
Method TestTheStatementAndPurgeReadsAnswerTheirShapes()
{
    Set tPort = ..#PORT
    Set tOne = $ClassMethod(..#PROBE, "HashOf", ..#NAMESPACE, "SELECT A FROM")
    Set tStale = $ClassMethod(..#PROBE, "HashOf", ..#NAMESPACE, "SELECT A , B FROM")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = tOne
    Set tSC = $ClassMethod(tPort, "Invoke", "Statements", "STATEMENT", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Get(tHttp) _ "|" _ $Select($IsObject($Get(tAnswer)): tAnswer.%ToJSON(), 1: ""), "200|{""Namespace"":""USER"",""Hash"":""" _ tOne _ """,""PlanState"":""Unfrozen"",""NewPlan"":false,""PlanError"":"""",""Executions"":3,""AverageTime"":0.1,""Tables"":[""OCUPROBE216.T1""]}", "a statement's read")
    Set tQuery("id") = tStale
    Set tSC = $ClassMethod(tPort, "Invoke", "Statements", "STATEMENT", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Get(tHttp) _ "|" _ $Select($IsObject($Get(tAnswer)): tAnswer.Executions _ "|" _ tAnswer.PlanError, 1: ""), "200||", "a stale statement reads with no statistics and no plan error")
    Set tQuery("id") = "*"
    Set tSC = $ClassMethod(tPort, "Invoke", "Statements", "STATEMENT", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Get(tHttp) _ "|" _ $Select($IsObject($Get(tAnswer)): (tAnswer.Statements '< 4) _ "|" _ (tAnswer.Stale '< 1) _ "|" _ (tAnswer.Stale '> tAnswer.Statements), 1: ""), "200|1|1|1", "the index's read counts its statements and its stale ones, the probe's among them")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    For tCase = $ListBuild("*", "namespace", "*", 3), $ListBuild(##class(OcuPilot.Test.SqlTuningProbe).#FIRST, "table", "OcuProbe216.T1", 2), $ListBuild("ocuprobe216.t2", "table", "OcuProbe216.T2", 1), $ListBuild($ClassMethod(..#PROBE, "LocationOf", ..#NAMESPACE, tOne), "class", $ClassMethod(..#PROBE, "LocationOf", ..#NAMESPACE, tOne), 1) {
        Set tQuery("id") = $List(tCase, 1)
        Set tSC = $ClassMethod(tPort, "Invoke", "CachedQueries", "PURGE", .tQuery, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertEquals($Get(tHttp) _ "|" _ $Select($IsObject($Get(tAnswer)): tAnswer.Kind _ "|" _ tAnswer.Target _ "|" _ tAnswer.Namespace, 1: ""), "200|" _ $List(tCase, 2) _ "|" _ $List(tCase, 3) _ "|USER", $List(tCase, 1) _ ": the purge read names its kind, its target and its namespace")
        If $IsObject($Get(tAnswer)) && ($List(tCase, 2) '= "namespace") Do $$$AssertEquals(tAnswer.CachedQueries, $List(tCase, 4), $List(tCase, 1) _ ": the cached queries it holds")
        If $IsObject($Get(tAnswer)) && ($List(tCase, 2) = "namespace") Do $$$AssertTrue(tAnswer.CachedQueries '< 3, "the namespace holds at least the probe's three cached queries")
    }
    For tCase = $ListBuild("Statements", "STATEMENT", "bAdHash0123456789abcdefgh=", "404 PORT.NOTFOUND"), $ListBuild("CachedQueries", "PURGE", "%sqlcq.USER.cls987654", "404 PORT.NOTFOUND"), $ListBuild("CachedQueries", "PURGE", "OcuProbe216.Absent", "404 PORT.NOTFOUND"), $ListBuild("CachedQueries", "PURGE", "%sqlcq.OTHERNS.cls1", "400 PORT.VALIDATION"), $ListBuild("Statements", "STATEMENT", "a b", "400 PORT.VALIDATION"), $ListBuild("Statements", "STATEMENT", "", "400 PORT.VALIDATION"), $ListBuild("Statements", "STATEMENT", $Translate($Justify("", 65), " ", "a"), "400 PORT.VALIDATION"), $ListBuild("Statements", "STATEMENT", "abc;DROP", "400 PORT.VALIDATION"), $ListBuild("CachedQueries", "PURGE", "%sqlcq.USER.cls1;x", "400 PORT.VALIDATION"), $ListBuild("CachedQueries", "PURGE", "NoDot", "400 PORT.VALIDATION"), $ListBuild("Statements", "LIST", tOne, "501 PORT.NOTIMPLEMENTED"), $ListBuild("Other", "STATEMENT", tOne, "501 PORT.NOTIMPLEMENTED") {
        Set tQuery("id") = $List(tCase, 3)
        Set tSC = $ClassMethod(tPort, "Invoke", $List(tCase, 1), $List(tCase, 2), .tQuery, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), $List(tCase, 4), $List(tCase, 1) _ "/" _ $List(tCase, 2) _ " " _ $List(tCase, 3) _ ": refused")
    }
    For tCase = $ListBuild("Statements", "bAdHash0123456789abcdefgh=", ##class(OcuPilot.Api.AtelierError).#REASONSTATEMENTNOTFOUND), $ListBuild("CachedQueries", "%sqlcq.USER.cls987654", ##class(OcuPilot.Api.AtelierError).#REASONCACHEDQUERYNOTFOUND), $ListBuild("CachedQueries", "OcuProbe216.Absent", ##class(OcuPilot.Port.AtelierPort).#REASONCATALOGNOTFOUND) {
        Set tQuery("id") = $List(tCase, 2)
        Set tSC = $ClassMethod(tPort, "Invoke", $List(tCase, 1), $Select($List(tCase, 1) = "Statements": "STATEMENT", 1: "PURGE"), .tQuery, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.reason, 1: ""), $List(tCase, 3), $List(tCase, 2) _ ": its absence is stated in the sentence of its own kind")
    }
}

/// <p>The copy-out script of each tuning write (AD-59): its namespace line and its one vendor call, with the hash, or with the qualifiers the
/// purge's target gives, as a literal.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.TuningSnippet</code> renders <code>UnfreezeStatement</code> for <code>FREEZE</code> -> the
/// freeze's script goes red.</p>
Method TestEachWritesScriptIsItsOneVendorCall()
{
    Set tHash = "abc+/0="
    Set tOk = $Char(10) _ " If $System.Status.IsError(tSC) Do $System.Status.DisplayError(tSC)"
    For tCase = $ListBuild("Statements", "FREEZE", tHash, " Set tSC = $SYSTEM.SQL.Statement.FreezeStatement(""abc+/0="")" _ tOk), $ListBuild("Statements", "UNFREEZE", tHash, " Set tSC = $SYSTEM.SQL.Statement.UnfreezeStatement(""abc+/0="")" _ tOk), $ListBuild("Statements", "CLEARSTATISTICS", tHash, " Set tSC = $SYSTEM.SQL.Statement.ClearStatement(""abc+/0="")" _ tOk), $ListBuild("Statements", "CLEARERROR", tHash, " Do UpdateSQLIndex^%SYS.SQLSRV(""abc+/0="", """")"), $ListBuild("Statements", "CLEAN", "*", " Do $SYSTEM.SQL.Statement.Clean()"), $ListBuild("CachedQueries", "PURGEQUERIES", "*", " Set tSC = $SYSTEM.SQL.PurgeQueries({})" _ tOk), $ListBuild("CachedQueries", "PURGEQUERIES", "OcuProbe216.T1", " Set tSC = $SYSTEM.SQL.PurgeQueries({""table"": [""OcuProbe216.T1""]})" _ tOk), $ListBuild("CachedQueries", "PURGEQUERIES", "%sqlcq.USER.cls12", " Set tSC = $SYSTEM.SQL.PurgeQueries({""class"": [""%sqlcq.USER.cls12""]})" _ tOk) {
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("id") = $List(tCase, 3)
        Set tSteps = ##class(OcuPilot.Port.SqlPort).Snippet($List(tCase, 1), $List(tCase, 2), .tQuery)
        Do $$$AssertEquals($Select(tSteps.%Size() = 1: tSteps.%Get(0).kind _ "|" _ tSteps.%Get(0).text, 1: tSteps.%ToJSON()), "objectscript| Set $NAMESPACE = ""USER""" _ $Char(10) _ $List(tCase, 4), $List(tCase, 2) _ " " _ $List(tCase, 3) _ ": the script is its one vendor call")
    }
}

/// <p>The gates. A caller without the Explorer's <code>%Development:USE</code> is refused 403 naming the pair on everyread and write, before any
/// is made; a caller without WRITE on the namespace's routines database reads and is refused 403 on each write, and the instance is asked for
/// none.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.TuningInvoke</code> asks <code>Gate</code> without its write flag -> the write-pair assertions
/// go red.</p>
Method TestTheGatesRefuseBeforeAnyReadOrWrite()
{
    Set tFixture = ..#FIXTURE
    Set tHash = $ClassMethod(..#PROBE, "HashOf", ..#NAMESPACE, "SELECT A FROM")
    Do $ClassMethod(..#SEAM, "Deny", "USE")
    For tCase = $ListBuild("Statements", "STATEMENT", tHash), $ListBuild("CachedQueries", "PURGE", "*"), $ListBuild("Statements", "FREEZE", tHash), $ListBuild("Statements", "CLEAN", "*"), $ListBuild("CachedQueries", "PURGEQUERIES", "*") {
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("id") = $List(tCase, 3)
        Set tSC = $ClassMethod(tFixture, "Invoke", $List(tCase, 1), $List(tCase, 2), .tQuery, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code _ " " _ tFault.detail.failedPair, 1: ""), "403 " _ ##class(OcuPilot.Kernel.Denial).Code() _ " %Development:USE", $List(tCase, 1) _ "/" _ $List(tCase, 2) _ ": refused naming the Explorer's pair")
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 0, "the instance was asked for no call")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Deny", "WRITE")
    For tCase = $ListBuild("Statements", "STATEMENT", tHash, 200), $ListBuild("CachedQueries", "PURGE", "*", 200), $ListBuild("Statements", "FREEZE", tHash, 403), $ListBuild("Statements", "CLEARSTATISTICS", tHash, 403), $ListBuild("Statements", "CLEAN", "*", 403), $ListBuild("CachedQueries", "PURGEQUERIES", "OcuProbe216.T2", 403) {
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("id") = $List(tCase, 3)
        Set tSC = $ClassMethod(tFixture, "Invoke", $List(tCase, 1), $List(tCase, 2), .tQuery, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertEquals(+$Get(tHttp), $List(tCase, 4), $List(tCase, 1) _ "/" _ $List(tCase, 2) _ ": " _ $Select($List(tCase, 4) = 200: "a read passes without WRITE", 1: "a write is refused without it"))
        If $List(tCase, 4) = 403 Do $$$AssertEquals($Piece($Select($IsObject($Get(tFault)): tFault.detail.failedPair, 1: ""), ":", 2), "WRITE", "naming the WRITE pair")
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls") _ "|" _ $ClassMethod(..#PROBE, "Facts", ..#NAMESPACE, tHash).PlanState _ "|" _ $ClassMethod(..#PROBE, "Facts", ..#NAMESPACE, tHash).Present, "0|Unfrozen|1", "no vendor call was made and nothing changed")
    Do $$$AssertEquals(##class(OcuPilot.Test.SqlCachedQueryPurge).Count("OcuProbe216.T2"), 1, "the refused purge left the table's cached query")
}

}
