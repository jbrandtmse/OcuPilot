/// <p>Pins the SQL catalog's remaining tabs through <class>OcuPilot.Test.AtelierPortFixture</class>'s
/// canned <code>Query</code> route (AD-21, AD-61 rules 1, 2, 3, 6 and 7): each of the nine endpoints
/// resolves its table, view or procedure first and then sends exactly its fixed statement bound with
/// the resolved names, or with the relation key for a SQL statements tab, and its <code>max</code>; a
/// view's information is two calls merged into one row; a table's partitions are not read for a table
/// its resolve reads as not partitioned; the view and procedure resolves refuse none and two; every
/// malformed name, and an instance too old for the query route, is refused before any route; a SQL
/// error answered under 200 is the internal fault, its text logged and never sent; and rows carry
/// exactly the declared fields, a description as plain text and no user name, client or call
/// stack.</p>
/// <p><b>What it needs from the environment:</b> the compiled port and fixture; it reads and writes
/// nothing on the instance.</p>
Class OcuPilot.Test.AtelierPortCatalogTabs Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.AtelierPort";

Method OnBeforeOneTest() As %Status
{
    Do ..ClearFixtures()
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do ..ClearFixtures()
    Quit $$$OK
}

Method ClearFixtures()
{
    Do ##class(OcuPilot.Test.AtelierPortFixture).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.LogProbe).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Clear()
}

/// <p>Arm the vendor with every pair held and the query route answering no rows.</p>
ClassMethod Arm()
{
    Do ##class(OcuPilot.Test.AtelierPortCatalog).ArmCatalog()
}

/// <p>Queue a <code>Query</code> answer whose content is the rows <var>pRows</var>.</p>
ClassMethod Queue(pRows As %String)
{
    Do ##class(OcuPilot.Test.AtelierPortFixture).Queue("Query", "200 OK", ##class(OcuPilot.Test.AtelierPortCatalog).Envelope(pRows))
}

/// <p>The resolve's one row for a <var>pKind</var> named <var>pSchema</var>.<var>pName</var>, a
/// table reading <var>pPartitioned</var> as its partitioning.</p>
ClassMethod ResolvedRow(pKind As %String, pSchema As %String, pName As %String, pPartitioned As %String = "NO") As %String
{
    Set tRow = {}
    Set tPrefix = $Select(pKind = "procedure": "ROUTINE_", 1: "TABLE_")
    Do tRow.%Set(tPrefix _ "SCHEMA", pSchema, "string")
    Do tRow.%Set(tPrefix _ "NAME", pName, "string")
    If pKind = "table" Do tRow.%Set("IS_PARTITIONED", pPartitioned, "string")
    Quit tRow.%ToJSON()
}

/// <p>Invoke <var>pEndpoint</var> through the fixture with the query <var>pQuery</var>, in the install
/// namespace.</p>
ClassMethod Read(pEndpoint As %String, ByRef pQuery, Output pRows, Output pHttp As %Integer, Output pFault) As %Status
{
    Quit ##class(OcuPilot.Test.AtelierPortCatalog).Read(pEndpoint, .pQuery, .pRows, .pHttp, .pFault)
}

/// <p>The body the port's fixed statement <var>pQueryParameter</var> with the values
/// <var>pValues</var> (a <code>%List</code> of strings) would be sent as, by the port's own
/// writer.</p>
ClassMethod Body(pQueryParameter As %String, pValues As %List) As %String
{
    Set tParameters = []
    For tI = 1:1:$ListLength(pValues) {
        Do tParameters.%Push($List(pValues, tI), "string")
    }
    Set tBody = {}
    Do tBody.%Set("query", $Parameter(..#PORT, pQueryParameter), "string")
    Do tBody.%Set("parameters", tParameters)
    Quit tBody.%ToJSON()
}

/// <p>The nine endpoints, each as <code>$ListBuild(endpoint, kind, key)</code>.</p>
ClassMethod Endpoints() As %List
{
    Quit $ListBuild($ListBuild("Catalog.Partitions", "table", "table"), $ListBuild("Catalog.PartitionMappings", "table", "table"), $ListBuild("Catalog.CachedQueries", "table", "table"), $ListBuild("Catalog.TableStatements", "table", "table"), $ListBuild("Catalog.View", "view", "view"), $ListBuild("Catalog.ViewFields", "view", "view"), $ListBuild("Catalog.ViewStatements", "view", "view"), $ListBuild("Catalog.Procedure", "procedure", "procedure"), $ListBuild("Catalog.ProcedureStatements", "procedure", "procedure"))
}

/// <p>AC8, AC5: each tab first sends its kind's resolve with the caller's name bound and
/// <code>max</code> 2, then its own statement bound with the exact schema and name the resolve
/// answered -- here a name holding a dot and a case the caller did not type -- or, for a SQL statements
/// tab, with the relation key, the name's dot read as <code>$Char(1)</code>; each with the read's cap.
/// A view's information sends the information statement and then the text statement, both bound the
/// same way. No caller text reaches a statement.</p>
/// <p>Mutation (Rule 19): splice the relation key into <parameter>OcuPilot.Port.AtelierPort.CATALOGSTATEMENTSQUERY</parameter>'s
/// text in <method>OcuPilot.Port.AtelierPort.CatalogRows</method> -&gt; the three statements legs'
/// exact-body assertions go red.</p>
Method TestEachTabResolvesAndBindsTheResolvedNames()
{
    Set tKey = "OCUPROBE." _ "THING" _ $Char(1) _ "ONE"
    Set tWanted = $ListBuild("CATALOGPARTITIONSQUERY", "CATALOGPARTITIONMAPPINGSQUERY", "CATALOGCACHEDQUERIESQUERY", "CATALOGSTATEMENTSQUERY", "CATALOGVIEWQUERY", "CATALOGVIEWFIELDSQUERY", "CATALOGSTATEMENTSQUERY", "CATALOGPROCEDUREQUERY", "CATALOGSTATEMENTSQUERY")
    Set tEndpoints = ..Endpoints()
    For tI = 1:1:$ListLength(tEndpoints) {
        Set tCase = $List(tEndpoints, tI)
        Set tEndpoint = $List(tCase, 1)
        Set tKind = $List(tCase, 2)
        Do ..ClearFixtures()
        Do ..Arm()
        Do ..Queue(..ResolvedRow(tKind, "OcuProbe", "Thing.One", "YES"))
        If tEndpoint = "Catalog.View" Do ..Queue("{""OWNER"":""_SYSTEM""}")
        Kill tQuery
        Set tQuery("maxRows") = 7
        Set tQuery($List(tCase, 3)) = "ocuprobe.thing.one"
        Set tSC = ..Read(tEndpoint, .tQuery, .tRows, .tHttp, .tFault)
        Set tCalls = $Select(tEndpoint = "Catalog.View": 3, 1: 2)
        Do $$$AssertEquals(tHttp _ " " _ ##class(OcuPilot.Test.AtelierPortFixture).CallCount(), "200 " _ tCalls, tEndpoint _ ": the resolve, then its own read")
        Set tResolve = ##class(OcuPilot.Test.AtelierPortFixture).CallAt(1)
        Set tResolveQuery = $Case(tKind, "view": "CATALOGVIEWRESOLVEQUERY", "procedure": "CATALOGPROCEDURERESOLVEQUERY", : "CATALOGRESOLVEQUERY")
        Do $$$AssertEquals(tResolve.params.%ToJSON() _ " " _ tResolve.body, "{""max"":2} " _ ..Body(tResolveQuery, $ListBuild("ocuprobe.thing.one")), tEndpoint _ ": the " _ tKind _ " resolve, the caller's name bound, max 2")
        Set tRead = ##class(OcuPilot.Test.AtelierPortFixture).CallAt(2)
        Set tValues = $Select($List(tWanted, tI) = "CATALOGSTATEMENTSQUERY": $ListBuild(tKey), 1: $ListBuild("OcuProbe", "Thing.One"))
        Do $$$AssertEquals(tRead.params.%ToJSON(), "{""max"":7}", tEndpoint _ ": its own read with the read's cap")
        Do $$$AssertEquals(tRead.body, ..Body($List(tWanted, tI), tValues), tEndpoint _ ": exactly its fixed statement, bound with the resolved names")
        If tEndpoint = "Catalog.View" {
            Set tText = ##class(OcuPilot.Test.AtelierPortFixture).CallAt(3)
            Do $$$AssertEquals(tText.params.%ToJSON() _ " " _ tText.body, "{""max"":7} " _ ..Body("CATALOGVIEWTEXTQUERY", tValues), tEndpoint _ ": then the text statement, bound the same way")
        }
    }
    Do $$$AssertEquals(##class(OcuPilot.Port.AtelierPort).CatalogRelation("OcuProbe195.A", "B.c"), "OCUPROBE195.A.B" _ $Char(1) _ "C", "the relation key keeps the schema's dot and reads the name's as $Char(1)")
}

/// <p>Matrix (Absent, Ambiguous): a view resolve and a procedure resolve that answer nothing are 404
/// <code>PORT.NOTFOUND</code> with their own reasons, unlogged, and two rows 400
/// <code>PORT.VALIDATION</code> naming the ambiguity; neither reads the tab.</p>
Method TestTheViewAndProcedureResolvesRefuseNoneAndTwo()
{
    For tCase = $ListBuild("Catalog.ViewFields", "view", "REASONCATALOGVIEWNOTFOUND", "REASONCATALOGVIEWAMBIGUOUS"), $ListBuild("Catalog.ProcedureStatements", "procedure", "REASONCATALOGPROCEDURENOTFOUND", "REASONCATALOGPROCEDUREAMBIGUOUS") {
        Set tEndpoint = $List(tCase, 1)
        Do ..ClearFixtures()
        Do ..Arm()
        Kill tQuery
        Set tQuery($List(tCase, 2)) = "OcuProbe.Absent"
        Set tSC = ..Read(tEndpoint, .tQuery, .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code _ " " _ tFault.reason, 1: "") _ " " _ ##class(OcuPilot.Test.AtelierPortFixture).CallCount(), "404 PORT.NOTFOUND " _ $Parameter(..#PORT, $List(tCase, 3)) _ " 1", tEndpoint _ ": none is not found, after the resolve alone")
        Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("message"), "", tEndpoint _ ": and nothing is logged")

        Do ..ClearFixtures()
        Do ..Arm()
        Do ..Queue(..ResolvedRow($List(tCase, 2), "OcuProbe", "A.B") _ "," _ ..ResolvedRow($List(tCase, 2), "OcuProbe.A", "B"))
        Kill tQuery
        Set tQuery($List(tCase, 2)) = "OcuProbe.A.B"
        Set tSC = ..Read(tEndpoint, .tQuery, .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code _ " " _ tFault.reason, 1: "") _ " " _ ##class(OcuPilot.Test.AtelierPortFixture).CallCount(), "400 PORT.VALIDATION " _ $Parameter(..#PORT, $List(tCase, 4)) _ " 1", tEndpoint _ ": two are refused as ambiguous, after the resolve alone")
        Do $$$AssertEquals(tRows, "", tEndpoint _ ": with no rows")
    }
}

/// <p>AC4: for a table its resolve reads as not partitioned, Partitions and Partition mappings answer
/// 200 with no rows and send nothing after the resolve; a partitioned one is read (the first
/// test).</p>
/// <p>Mutation (Rule 19): skip the partitioned check in
/// <method>OcuPilot.Port.AtelierPort.CatalogRows</method> -&gt; each leg sends a second call and goes
/// red.</p>
Method TestPartitionsAreNotReadForATableThatIsNotPartitioned()
{
    For tEndpoint = "Catalog.Partitions", "Catalog.PartitionMappings" {
        For tPartitioned = "NO", "" {
            Do ..ClearFixtures()
            Do ..Arm()
            Do ..Queue(..ResolvedRow("table", "OcuProbe", "Plain", tPartitioned))
            Kill tQuery
            Set tQuery("table") = "OcuProbe.Plain"
            Set tSC = ..Read(tEndpoint, .tQuery, .tRows, .tHttp, .tFault)
            Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tRows): tRows.%ToJSON(), 1: "") _ " " _ ##class(OcuPilot.Test.AtelierPortFixture).CallCount(), "200 [] 1", tEndpoint _ " on a table reading '" _ tPartitioned _ "': no rows, after the resolve alone")
        }
    }
}

/// <p>Matrix (Bad input): a view's or a procedure's name with no dot, over 257 characters, holding a
/// control character or absent, and a new table tab's table with no dot, are each refused 400
/// <code>PORT.VALIDATION</code> with its kind's reason before any route; a name of exactly 257
/// characters is resolved.</p>
Method TestMalformedNamesAreRefusedBeforeAnyRoute()
{
    Do ..Arm()
    Set tLong = "a." _ $Translate($Justify("", 256), " ", "v")
    For tCase = $ListBuild("Catalog.View", "view", "NoDot", "REASONCATALOGVIEW"), $ListBuild("Catalog.ViewFields", "view", tLong, "REASONCATALOGVIEW"), $ListBuild("Catalog.ViewStatements", "view", "a." _ $Char(9) _ "b", "REASONCATALOGVIEW"), $ListBuild("Catalog.Procedure", "procedure", "", "REASONCATALOGPROCEDURE"), $ListBuild("Catalog.ProcedureStatements", "procedure", "NoDot", "REASONCATALOGPROCEDURE"), $ListBuild("Catalog.Partitions", "table", "NoDot", "REASONCATALOGTABLE"), $ListBuild("Catalog.TableStatements", "table", "", "REASONCATALOGTABLE"), $ListBuild("Catalog.CachedQueries", "view", "OcuProbe.Thing", "REASONCATALOGTABLE") {
        Kill tQuery
        If $List(tCase, 3) '= "" Set tQuery($List(tCase, 2)) = $List(tCase, 3)
        Set tSC = ..Read($List(tCase, 1), .tQuery, .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code _ " " _ tFault.reason, 1: ""), "400 PORT.VALIDATION " _ $Parameter(..#PORT, $List(tCase, 4)), $List(tCase, 1) _ " " _ $List(tCase, 2) _ " " _ $Extract($List(tCase, 3), 1, 12) _ " is refused with its reason")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.AtelierPortFixture).CallCount(), 0, "before any route")
    Kill tQuery
    Set tQuery("procedure") = $Extract(tLong, 1, 257)
    Set tSC = ..Read("Catalog.Procedure", .tQuery, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ ##class(OcuPilot.Test.AtelierPortFixture).CallCount(), "404 1", "a procedure of 257 characters, the bound, is resolved")
}

/// <p>Matrix (Old instance), AD-61 rule 2: an instance whose highest version is 5 is refused each of
/// the nine reads 501 naming both versions, before any route.</p>
Method TestTheVersionGateRefusesAllNine()
{
    Do ..Arm()
    Do ##class(OcuPilot.Test.AtelierPortFixture).SetVersion(5)
    Set tWanted = $Replace($Replace($Parameter(..#PORT, "REASONVERSION"), "{highest}", 5), "{needed}", 6)
    Set tEndpoints = ..Endpoints()
    For tI = 1:1:$ListLength(tEndpoints) {
        Set tCase = $List(tEndpoints, tI)
        Kill tQuery
        Set tQuery($List(tCase, 3)) = "OcuProbe.Thing"
        Set tSC = ..Read($List(tCase, 1), .tQuery, .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code _ " " _ tFault.reason, 1: ""), "501 PORT.NOTIMPLEMENTED " _ tWanted, $List(tCase, 1) _ " on a version 5 instance is refused naming both versions")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.AtelierPortFixture).CallCount(), 0, "before any route")
}

/// <p>Matrix (SQL error), AD-61 rule 6: a SQL error the query route answers under 200 -- on a view
/// resolve, on a statements tab's own read, and on a view's text after its information -- is 500
/// <code>INTERNAL</code> with the generic reason and no rows, its vendor text logged and in no field of
/// the fault.</p>
Method TestASqlErrorIsTheInternalFaultWithNothingSent()
{
    Set tError = "{""status"":{""errors"":[{""error"":""ERROR #5540: SQLCODE: -30 Message: Table 'OCUPROBE1914SECRET' not found"",""code"":5540}],""summary"":""""},""console"":[],""result"":{""content"":[{""OWNER"":""x""}]}}"
    For tLeg = $ListBuild("Catalog.ViewFields", "view", 0), $ListBuild("Catalog.TableStatements", "table", 1), $ListBuild("Catalog.View", "view", 2) {
        Do ..ClearFixtures()
        Do ..Arm()
        If $List(tLeg, 3) > 0 Do ..Queue(..ResolvedRow($List(tLeg, 2), "OcuProbe", "Thing"))
        If $List(tLeg, 3) > 1 Do ..Queue("{""OWNER"":""_SYSTEM""}")
        Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("Query", "200 OK", tError)
        Kill tQuery
        Set tQuery($List(tLeg, 2)) = "OcuProbe.Thing"
        Set tSC = ..Read($List(tLeg, 1), .tQuery, .tRows, .tHttp, .tFault)
        Set tWhere = $List(tLeg, 1) _ " (call " _ ($List(tLeg, 3) + 1) _ ")"
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code _ " " _ tFault.reason, 1: "") _ " [" _ tRows _ "]", "500 INTERNAL " _ ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON _ " []", tWhere _ ": the internal fault, no rows")
        Do $$$AssertTrue($Select($IsObject(tFault): tFault.%ToJSON(), 1: "") '[ "OCUPROBE1914SECRET", tWhere _ ": the vendor's text is in no field of the fault")
        Do $$$AssertTrue(##class(OcuPilot.Test.LogProbe).Captured("message") [ "OCUPROBE1914SECRET", tWhere _ ": and is logged")
    }
}

/// <p>AC1, AC2, AC3, AC5: rows carry exactly their declared fields -- a partition's and a partition
/// mapping's counts as numbers, a cached query's source flag as a boolean, a view's information with
/// its text merged in, a view field's stream flag, a procedure's HTML description as plain text beside
/// the second of the vendor's two return-value columns -- and a statement row names no user name, client name, address,
/// application, call stack or plan, whatever the vendor's row carries.</p>
/// <p>Mutation (Rule 19): map <code>Description</code> without <code>plain</code> in
/// <parameter>OcuPilot.Port.AtelierPort.CATALOGPROCEDURECOLUMNS</parameter> -&gt; the procedure row's
/// assertion goes red.</p>
Method TestRowsCarryExactlyTheDeclaredFields()
{
    Set tCases = $ListBuild($ListBuild("Catalog.Partitions", "table", "{""PARTITION_ID"":""202601010000"",""BUCKETS"":""1"",""ROWS"":""2"",""ESTIMATED_SIZE"":""62914"",""LOCATION"":""USER""}", "{""Partition"":""202601010000"",""Buckets"":1,""Rows"":2,""EstimatedSize"":62914,""Location"":""USER""}"),
        $ListBuild("Catalog.PartitionMappings", "table", "{""RULE"":""OcuProbe1914Rule"",""BUCKETS"":""1"",""ROWS"":""2"",""ESTIMATED_SIZE"":""62914"",""LOCATION"":""USER""}", "{""Rule"":""OcuProbe1914Rule"",""Buckets"":1,""Rows"":2,""EstimatedSize"":62914,""Location"":""USER""}"),
        $ListBuild("Catalog.CachedQueries", "table", "{""Routine"":""%sqlcq.USER.cls1"",""Query"":"" SELECT 1"",""CreateTime"":""2026-10-03 10:00:00"",""Source"":0,""QueryType"":8,""QueryTypeExt"":""%SQL.Statement Dynamic SQL"",""Cost"":""9"",""STATEMENT_OPTIONS"":""""}", "{""CachedQuery"":""%sqlcq.USER.cls1"",""Query"":"" SELECT 1"",""Created"":""2026-10-03 10:00:00"",""Source"":false,""QueryType"":""%SQL.Statement Dynamic SQL"",""Features"":""""}"),
        $ListBuild("Catalog.TableStatements", "table", "{""PLAN_STATE"":""Unfrozen"",""FROZEN_DIFF"":false,""EXECUTIONS"":3,""TOTAL_TIME"":0.5,""AVERAGE_TIME"":0.25,""STDDEV_TIME"":0,""ROW_COUNT"":4,""COMMANDS"":40,""FIRST_SEEN"":""2026-10-03"",""STATEMENT"":"" SELECT 1"",""LOCATION"":""%sqlcq.USER.cls1.1"",""USERNAME"":""OcuProbe1914Who"",""CLIENTNAME"":""OcuProbe1914Host"",""CLIENTIP"":""203.0.113.9"",""CLIENTAPP"":""OcuProbe1914App"",""CALLSTACK"":""OcuProbe1914Stack"",""PLAN"":""OcuProbe1914Plan"",""JSONPLAN"":""OcuProbe1914Json""}", "{""Statement"":"" SELECT 1"",""PlanState"":""Unfrozen"",""NewPlan"":false,""Executions"":3,""TotalTime"":0.5,""AverageTime"":0.25,""StdDevTime"":0,""RowCount"":4,""Commands"":40,""FirstSeen"":""2026-10-03"",""Location"":""%sqlcq.USER.cls1.1""}"),
        $ListBuild("Catalog.ViewFields", "view", "{""FIELD_NAME"":""Name"",""DATATYPE"":""%Library.String"",""COLLATION"":""SQLUPPER"",""MAXLEN"":""50"",""MAXVAL"":"""",""MINVAL"":"""",""BLOB"":""No"",""LENGTH"":50,""PRECISION"":50,""SCALE"":0}", "{""Field"":""Name"",""Type"":""%Library.String"",""Collation"":""SQLUPPER"",""MaxLength"":50,""MaxValue"":"""",""MinValue"":"""",""Stream"":false,""Length"":50,""Precision"":50,""Scale"":0}"),
        $ListBuild("Catalog.Procedure", "procedure", "{""CLASS_NAME"":""OcuProbe.Described"",""PROCEDURE_TYPE"":""function"",""METHOD_OR_QUERY_NAME"":""Stamp"",""DESCRIPTION"":""<p>OcuProbe <b>tagged</b> &amp; text</p>\r\n<p>Second.</p>"",""NUMBER_INPUT_PARAMS"":1,""NUMBER_INPUT_OUTPUT_PARAMS"":0,""NUMBER_OUTPUT_PARAMS"":0,""RETURN_VALUE"":""_isc_sp_ret_val INTEGER"",""PROCEDURE_INTERFACE"":""2"",""NUMBER_OF_COLUMNS"":0,""INPUT_PARAMETERS"":""pValue INTEGER"",""INPUT_OUTPUT_PARAMETERS"":"""",""OUTPUT_PARAMETERS"":"""",""RESULTSET_COLUMNS"":""""}", "{""Class"":""OcuProbe.Described"",""Type"":""function"",""Method"":""Stamp"",""Description"":""OcuProbe tagged & text Second."",""Inputs"":1,""InOuts"":0,""Outputs"":0,""Interface"":2,""Columns"":0,""InputParameters"":""pValue INTEGER"",""InOutParameters"":"""",""OutputParameters"":"""",""ResultColumns"":"""",""ReturnValue"":""_isc_sp_ret_val INTEGER""}"))
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Do ..ClearFixtures()
        Do ..Arm()
        Do ..Queue(..ResolvedRow($List(tCase, 2), "OcuProbe", "Thing", "YES"))
        Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("Query", "200 OK", ##class(OcuPilot.Test.AtelierPortCatalog).Envelope($List(tCase, 3)))
        Kill tQuery
        Set tQuery($List(tCase, 2)) = "OcuProbe.Thing"
        Set tSC = ..Read($List(tCase, 1), .tQuery, .tRows, .tHttp, .tFault)
        Do $$$AssertEquals($Select($IsObject(tRows): tRows.%ToJSON(), 1: ""), "[" _ $List(tCase, 4) _ "]", $List(tCase, 1) _ ": its row carries exactly the declared fields")
    }

    Do ..ClearFixtures()
    Do ..Arm()
    Do ..Queue(..ResolvedRow("view", "OcuProbe", "Names"))
    Do ..Queue("{""OWNER"":""_SYSTEM"",""LAST_COMPILED"":""2026-10-03 10:00:00"",""DEFINED_AS_READ_ONLY"":0,""UPDATABLE"":1,""CLASSNAME"":""OcuProbe.Names"",""CHECK_OPTION"":"""",""CLASSTYPE"":""VIEW""}")
    Do ..Queue("{""VIEW_QUERY"":"" SELECT Id FROM OcuProbe.Thing""}")
    Kill tQuery
    Set tQuery("view") = "OcuProbe.Names"
    Set tSC = ..Read("Catalog.View", .tQuery, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject(tRows): tRows.%ToJSON(), 1: ""), "[{""Owner"":""_SYSTEM"",""LastCompiled"":""2026-10-03 10:00:00"",""ReadOnly"":false,""Updatable"":true,""Class"":""OcuProbe.Names"",""CheckOption"":"""",""ClassType"":""VIEW"",""Text"":"" SELECT Id FROM OcuProbe.Thing""}]", "a view's information carries its text, merged from the second call")

    Do ..ClearFixtures()
    Do ..Arm()
    Do ..Queue(..ResolvedRow("view", "OcuProbe", "Gone"))
    Kill tQuery
    Set tQuery("view") = "OcuProbe.Gone"
    Set tSC = ..Read("Catalog.View", .tQuery, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tRows): tRows.%ToJSON(), 1: "") _ " " _ ##class(OcuPilot.Test.AtelierPortFixture).CallCount(), "200 [] 2", "a view whose information answers no row reads no row, and its text is not asked")
}

/// <p>AC5, AD-61 rule 7: the statement each SQL statements tab sends selects no user name, client
/// name, address, application, call stack or plan, and no fixed statement of the port names the
/// vendor's statement index procedure.</p>
/// <p>Mutation (Rule 19): add <code>s.UserName AS USER_NAME</code> to
/// <parameter>OcuPilot.Port.AtelierPort.CATALOGSTATEMENTSQUERY</parameter> and
/// <code>UserName:USER_NAME</code> to its column map -&gt; the sent statement's assertion goes
/// red.</p>
Method TestNoStatementReadSelectsAnIdentifyingColumn()
{
    For tEndpoint = "Catalog.TableStatements", "Catalog.ViewStatements", "Catalog.ProcedureStatements" {
        Do ..ClearFixtures()
        Do ..Arm()
        Set tKind = $Select(tEndpoint [ "View": "view", tEndpoint [ "Procedure": "procedure", 1: "table")
        Do ..Queue(..ResolvedRow(tKind, "OcuProbe", "Thing"))
        Kill tQuery
        Set tQuery(tKind) = "OcuProbe.Thing"
        Set tSC = ..Read(tEndpoint, .tQuery, .tRows, .tHttp, .tFault)
        Set tSent = ##class(OcuPilot.Test.AtelierPortFixture).CallAt(2)
        Set tStatement = $Select($IsObject(tSent): $ZConvert(##class(%DynamicObject).%FromJSON(tSent.body).query, "U"), 1: "")
        Do $$$AssertTrue(tStatement [ "INFORMATION_SCHEMA.STATEMENTS", tEndpoint _ ": it reads the information schema's statements")
        For tColumn = "USERNAME", "USER_NAME", "CLIENTNAME", "CLIENTIP", "CLIENTAPP", "CALLSTACK", "S.PLAN", "JSONPLAN", "STATEMENTINDEX" {
            Do $$$AssertTrue(tStatement '[ tColumn, tEndpoint _ ": the statement it sends names no " _ tColumn)
        }
    }
    Set tNamed = ""
    Set tClass = ##class(%Dictionary.CompiledClass).%OpenId(..#PORT)
    Do $$$AssertTrue($IsObject(tClass), "the port is compiled")
    If '$IsObject(tClass) Quit
    For tI = 1:1:tClass.Parameters.Count() {
        Set tParameter = tClass.Parameters.GetAt(tI)
        If $ZConvert(tParameter.Default, "U") [ "STATEMENTINDEX" Set tNamed = tNamed _ " " _ tParameter.Name
    }
    Do $$$AssertEquals(tNamed, "", "no parameter of the port names the statement index procedure")
}

}
