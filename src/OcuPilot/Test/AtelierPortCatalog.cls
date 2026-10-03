/// <p>Pins the source code API port's SQL catalog family through
/// <class>OcuPilot.Test.AtelierPortFixture</class>'s canned <code>Query</code> route (AD-21, AD-61
/// rules 1, 2, 3, 6 and 7): each of the nine endpoints sends exactly its fixed statement with every
/// caller value bound in <code>parameters</code> and its <code>max</code>; a tab resolves its table
/// first and binds the exact names the resolve answers; rows carry exactly the declared fields, flags
/// read as booleans and no column outside the map; every malformed argument, the gate and an instance
/// too old for the query route are refused before any route; a resolve answering none or two tables
/// is refused; and a SQL error answered under 200 is the internal fault, its text logged and never
/// sent.</p>
/// <p><b>What it needs from the environment:</b> the compiled port and fixture; it reads and writes
/// nothing on the instance.</p>
Class OcuPilot.Test.AtelierPortCatalog Extends %UnitTest.TestCase
{

Parameter FIXTURE = "OcuPilot.Test.AtelierPortFixture";

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

/// <p>A <code>Query</code> envelope whose content is the rows <var>pRows</var>, comma-separated JSON
/// objects.</p>
ClassMethod Envelope(pRows As %String) As %String
{
    Quit "{""status"":{""errors"":[],""summary"":""""},""console"":[],""result"":{""content"":[" _ pRows _ "]}}"
}

/// <p>The resolve's answer naming one table.</p>
ClassMethod Resolved(pSchema As %String, pName As %String) As %String
{
    Quit ..Envelope("{""TABLE_SCHEMA"":""" _ pSchema _ """,""TABLE_NAME"":""" _ pName _ """}")
}

/// <p>Arm the vendor with every pair held and the query route answering no rows.</p>
ClassMethod ArmCatalog()
{
    Do ##class(OcuPilot.Test.AtelierPort).ArmVendor()
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("Query", "200 OK", ..Envelope(""))
}

/// <p>Invoke catalog endpoint <var>pEndpoint</var> through the fixture with the query
/// <var>pQuery</var>, in the install namespace.</p>
ClassMethod Read(pEndpoint As %String, ByRef pQuery, Output pRows, Output pHttp As %Integer, Output pFault) As %Status
{
    If '$Data(pQuery("namespace")) Set pQuery("namespace") = $Namespace
    Set pFault = ""
    Quit ##class(OcuPilot.Test.AtelierPortFixture).Invoke(pEndpoint, "LIST", .pQuery, "", .pRows, .pHttp, .pFault)
}

/// <p>The body <var>pQueryParameter</var>'s statement with <var>pParameters</var> (a JSON array) would
/// be sent as, by the port's own writer.</p>
ClassMethod Body(pQueryParameter As %String, pParameters As %String) As %String
{
    Set tBody = {}
    Do tBody.%Set("query", $Parameter(..#PORT, pQueryParameter), "string")
    Do tBody.%Set("parameters", ##class(%DynamicArray).%FromJSON(pParameters))
    Quit tBody.%ToJSON()
}

/// <p>AC3: each list sends the query route exactly its fixed statement, with <code>system</code> as
/// its flag (the table type for the tables) and the schema twice where it takes one, an omitted one
/// empty, and <code>max</code> the read's cap; nothing else, and the body as
/// <code>application/json</code>.</p>
/// <p>Mutation (Rule 19): splice the schema into <parameter>OcuPilot.Port.AtelierPort.CATALOGTABLESQUERY</parameter>'s
/// text in <method>OcuPilot.Port.AtelierPort.CatalogRows</method> -&gt; the exact-body assertion goes
/// red.</p>
Method TestEachListSendsItsFixedStatementAndBoundValues()
{
    For tCase = $ListBuild("Catalog.Schemas", "", "", "CATALOGSCHEMASQUERY", "[0]"), $ListBuild("Catalog.Schemas", "yes", "", "CATALOGSCHEMASQUERY", "[1]"), $ListBuild("Catalog.Tables", "", "", "CATALOGTABLESQUERY", "[""BASE TABLE"","""",""""]"), $ListBuild("Catalog.Tables", "yes", "Probe_Schema' OR 1=1", "CATALOGTABLESQUERY", "[""SYSTEM TABLE"",""Probe_Schema' OR 1=1"",""Probe_Schema' OR 1=1""]"), $ListBuild("Catalog.Views", "no", "Probe", "CATALOGVIEWSQUERY", "[0,""Probe"",""Probe""]"), $ListBuild("Catalog.Procedures", "yes", "", "CATALOGPROCEDURESQUERY", "[1,"""",""""]") {
        Do ..ClearFixtures()
        Do ..ArmCatalog()
        Kill tQuery
        Set tQuery("maxRows") = 7
        If $List(tCase, 2) '= "" Set tQuery("system") = $List(tCase, 2)
        If $List(tCase, 3) '= "" Set tQuery("schema") = $List(tCase, 3)
        Set tSC = ..Read($List(tCase, 1), .tQuery, .tRows, .tHttp, .tFault)
        Set tCall = ##class(OcuPilot.Test.AtelierPortFixture).CallAt(1)
        Set tWhere = $List(tCase, 1) _ " system=" _ $List(tCase, 2) _ " schema=" _ $List(tCase, 3)
        Do $$$AssertEquals(tHttp _ " " _ ##class(OcuPilot.Test.AtelierPortFixture).CallCount() _ " " _ tCall.method _ " " _ tCall.params.%ToJSON() _ " " _ tCall.contentType, "200 1 Query {""max"":7} application/json", tWhere _ ": one query call, sent max alone")
        Do $$$AssertEquals(tCall.body, ..Body($List(tCase, 4), $List(tCase, 5)), tWhere _ ": exactly its fixed statement, every caller value bound")
    }
    Do ..ClearFixtures()
    Do ..ArmCatalog()
    Kill tQuery
    Set tSC = ..Read("Catalog.Views", .tQuery, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(##class(OcuPilot.Test.AtelierPortFixture).CallAt(1).params.%ToJSON(), "{""max"":" _ $Parameter(..#PORT, "CATALOGMAX") _ "}", "a read naming no cap asks for the port's own bound")
}

/// <p>AC2, AC3: each tab first sends the resolve with the caller's name bound and <code>max</code> 2,
/// then its own statement bound with the exact schema and name the resolve answered -- here a name
/// holding a dot and a case the caller did not type -- each with the read's own cap, except the table
/// information, which lists the whole schema and sends 5,000.</p>
/// <p>Mutation (Rule 19): skip the resolve for <code>Catalog.Triggers</code>, binding the caller's
/// own spelling split at its first dot, in <method>OcuPilot.Port.AtelierPort.CatalogRows</method>
/// -&gt; the Triggers leg's assertions go red.</p>
Method TestEachTabResolvesItsTableAndBindsTheResolvedNames()
{
    For tCase = $ListBuild("Catalog.Table", "CATALOGTABLEQUERY", "[""OcuProbe""]", 5000), $ListBuild("Catalog.Fields", "CATALOGFIELDSQUERY", "[""OcuProbe"",""Thing.One""]", 7), $ListBuild("Catalog.Indices", "CATALOGINDICESQUERY", "[""OcuProbe"",""Thing.One""]", 7), $ListBuild("Catalog.Triggers", "CATALOGTRIGGERSQUERY", "[""OcuProbe"",""Thing.One""]", 7), $ListBuild("Catalog.Constraints", "CATALOGCONSTRAINTSQUERY", "[""OcuProbe"",""Thing.One""]", 7) {
        Do ..ClearFixtures()
        Do ..ArmCatalog()
        Do ##class(OcuPilot.Test.AtelierPortFixture).Queue("Query", "200 OK", ..Resolved("OcuProbe", "Thing.One"))
        Kill tQuery
        Set tQuery("maxRows") = 7
        Set tQuery("table") = "ocuprobe.thing.one"
        Set tSC = ..Read($List(tCase, 1), .tQuery, .tRows, .tHttp, .tFault)
        Set tResolve = ##class(OcuPilot.Test.AtelierPortFixture).CallAt(1)
        Set tRead = ##class(OcuPilot.Test.AtelierPortFixture).CallAt(2)
        Do $$$AssertEquals(tHttp _ " " _ ##class(OcuPilot.Test.AtelierPortFixture).CallCount(), "200 2", $List(tCase, 1) _ ": two query calls")
        Do $$$AssertEquals(tResolve.params.%ToJSON() _ " " _ tResolve.body, "{""max"":2} " _ ..Body("CATALOGRESOLVEQUERY", "[""ocuprobe.thing.one""]"), $List(tCase, 1) _ ": the resolve, the caller's name bound and max 2")
        Do $$$AssertEquals(tRead.params.%ToJSON(), "{""max"":" _ $List(tCase, 4) _ "}", $List(tCase, 1) _ ": then its own read with its bound")
        Do $$$AssertEquals(tRead.body, ..Body($List(tCase, 2), $List(tCase, 3)), $List(tCase, 1) _ ": bound with the resolved schema and name")
    }
}

/// <p>AC1, AC2: a row carries exactly its endpoint's declared fields: flags of <code>1</code>,
/// <code>0</code>, <code>Yes</code>, <code>No</code> and <code>NO</code> read as booleans, a column
/// number as a number, a value the vendor parsed as JSON as its text, and no column outside the map
/// -- never the cached-query flag, nor <code>Fields</code>' outlier value or histogram. The table
/// information keeps the resolved table's row alone, and a list is cut at the cap.</p>
Method TestRowsCarryExactlyTheDeclaredFields()
{
    Do ..ArmCatalog()
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("Query", "200 OK", ..Envelope("{""SCHEMA_NAME"":""Probe"",""TABLE_EXISTS"":""1"",""VIEW_EXISTS"":""0"",""PROCEDURE_EXISTS"":""1"",""CACHED_QUERY_EXISTS"":""1""}"))
    Kill tQuery
    Set tSC = ..Read("Catalog.Schemas", .tQuery, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject(tRows): tRows.%ToJSON(), 1: ""), "[{""Schema"":""Probe"",""Tables"":true,""Views"":false,""Procedures"":true}]", "a schema row")

    Do ..ClearFixtures()
    Do ..ArmCatalog()
    Do ##class(OcuPilot.Test.AtelierPortFixture).Queue("Query", "200 OK", ..Resolved("OcuProbe", "Thing"))
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("Query", "200 OK", ..Envelope("{""FIELD_NAME"":""Code"",""DATATYPE"":""%Library.String"",""COLLECTION_TYPE"":"""",""COLUMN_NUMBER"":""3"",""REQUIRED"":""Yes"",""UNIQUE"":""No"",""COLLATION_FUNCTION"":""SQLUPPER"",""HIDDEN"":""No"",""MAXLEN"":""20"",""MAXVAL"":"""",""MINVAL"":"""",""BLOB"":""No"",""CONTAINER_FIELD"":"""",""XDBC_TYPENAME"":""VARCHAR"",""REFERENCE_TO"":"""",""VERSION_COLUMN"":""No"",""SELECTIVITY"":""1"",""OUTLIER_SELECTIVITY"":""50%"",""OUTLIER_VALUE"":""OcuProbe195OutlierValue"",""AVERAGE_FIELD_SIZE"":""4"",""HISTOGRAM"":""OcuProbe195Histogram""}"))
    Kill tQuery
    Set tQuery("table") = "OcuProbe.Thing"
    Set tSC = ..Read("Catalog.Fields", .tQuery, .tRows, .tHttp, .tFault)
    Set tText = $Select($IsObject(tRows): tRows.%ToJSON(), 1: "")
    Do $$$AssertEquals(tText, "[{""Field"":""Code"",""Type"":""%Library.String"",""Column"":3,""Required"":true,""Unique"":false,""Collation"":""SQLUPPER"",""Hidden"":false,""MaxLength"":20,""MinValue"":"""",""MaxValue"":"""",""Stream"":false,""XdbcType"":""VARCHAR"",""ReferenceTo"":"""",""VersionColumn"":false,""Selectivity"":""1""}]", "a field row, its flags and numbers read")
    Do $$$AssertTrue((tText '[ "OcuProbe195OutlierValue") && (tText '[ "OcuProbe195Histogram"), "and no data value")

    Do ..ClearFixtures()
    Do ..ArmCatalog()
    Do ##class(OcuPilot.Test.AtelierPortFixture).Queue("Query", "200 OK", ..Resolved("OcuProbe", "Thing"))
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("Query", "200 OK", ..Envelope("{""TRIGGER_NAME"":""Stamp"",""TIME_EVENT"":""before insert"",""ORDER"":""1"",""CODE"":{""looks"":""like JSON""}}"))
    Kill tQuery
    Set tQuery("table") = "OcuProbe.Thing"
    Set tSC = ..Read("Catalog.Triggers", .tQuery, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject(tRows): tRows.%ToJSON(), 1: ""), "[{""Trigger"":""Stamp"",""Event"":""before insert"",""Order"":1,""Code"":""{\""looks\"":\""like JSON\""}""}]", "a trigger row, code the vendor parsed as JSON kept as its text")

    Do ..ClearFixtures()
    Do ..ArmCatalog()
    Do ##class(OcuPilot.Test.AtelierPortFixture).Queue("Query", "200 OK", ..Resolved("OcuProbe", "Thing"))
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("Query", "200 OK", ..Envelope("{""NAME"":""Other"",""OWNER"":""a"",""LAST_COMPILED"":"""",""EXTERNAL"":""0"",""READ_ONLY"":""0"",""PARTITIONED"":""0"",""CLASSNAME"":""OcuProbe.Other"",""ALLOW_DROP"":""1"",""EXTENTSIZE"":""1"",""EXTERNAL_TYPE"":""""},{""NAME"":""Thing"",""OWNER"":""_SYSTEM"",""LAST_COMPILED"":""2026-10-02 10:00:00"",""EXTERNAL"":""0"",""READ_ONLY"":""1"",""PARTITIONED"":""0"",""CLASSNAME"":""OcuProbe.Thing"",""ALLOW_DROP"":""1"",""EXTENTSIZE"":""100000"",""EXTERNAL_TYPE"":""""}"))
    Kill tQuery
    Set tQuery("table") = "OcuProbe.Thing"
    Set tSC = ..Read("Catalog.Table", .tQuery, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject(tRows): tRows.%ToJSON(), 1: ""), "[{""Name"":""Thing"",""Owner"":""_SYSTEM"",""LastCompiled"":""2026-10-02 10:00:00"",""External"":false,""ReadOnly"":true,""Partitioned"":false,""Class"":""OcuProbe.Thing"",""ExtentSize"":100000,""ExternalType"":""""}]", "the table information keeps the resolved table's row alone")

    Do ..ClearFixtures()
    Do ..ArmCatalog()
    Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("Query", "200 OK", ..Envelope("{""TABLE_SCHEMA"":""A"",""TABLE_NAME"":""One"",""CLASSNAME"":""A.One"",""OWNER"":""x"",""IS_SHARDED"":""NO"",""IS_PARTITIONED"":""YES""},{""TABLE_SCHEMA"":""A"",""TABLE_NAME"":""Two"",""CLASSNAME"":""A.Two"",""OWNER"":""x"",""IS_SHARDED"":""NO"",""IS_PARTITIONED"":""NO""},{""TABLE_SCHEMA"":""A"",""TABLE_NAME"":""Three"",""CLASSNAME"":""A.Three"",""OWNER"":""x"",""IS_SHARDED"":""NO"",""IS_PARTITIONED"":""NO""}"))
    Kill tQuery
    Set tQuery("maxRows") = 2
    Set tSC = ..Read("Catalog.Tables", .tQuery, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tRows.%Size() _ " " _ tRows.%Get(0).%ToJSON(), "2 {""Table"":""A.One"",""Schema"":""A"",""Name"":""One"",""Class"":""A.One"",""Owner"":""x"",""Sharded"":false,""Partitioned"":true}", "a table row, its qualified name joined, cut at the cap")
}

/// <p>Matrix: a list's schema over 128 characters or holding a control character, a system choice
/// that is neither yes nor no, and a tab's table with no dot, over 257 characters, holding a control
/// character or absent are each refused 400 <code>PORT.VALIDATION</code> with its own reason before
/// any route; a schema of exactly 128 and a table of exactly 257 characters are read.</p>
Method TestMalformedArgumentsAreRefusedBeforeAnyRoute()
{
    Do ..ArmCatalog()
    Set tLong = $Translate($Justify("", 129), " ", "s")
    For tCase = $ListBuild("Catalog.Tables", "schema", tLong, "REASONCATALOGSCHEMA"), $ListBuild("Catalog.Views", "schema", "a" _ $Char(10) _ "b", "REASONCATALOGSCHEMA"), $ListBuild("Catalog.Schemas", "system", "maybe", "REASONCATALOGSYSTEM"), $ListBuild("Catalog.Procedures", "system", "YES", "REASONCATALOGSYSTEM"), $ListBuild("Catalog.Fields", "table", "NoDot", "REASONCATALOGTABLE"), $ListBuild("Catalog.Triggers", "table", "", "REASONCATALOGTABLE"), $ListBuild("Catalog.Table", "table", "a." _ $Translate($Justify("", 256), " ", "t"), "REASONCATALOGTABLE"), $ListBuild("Catalog.Constraints", "table", "a." _ $Char(0) _ "b", "REASONCATALOGTABLE") {
        Kill tQuery
        If $List(tCase, 3) '= "" Set tQuery($List(tCase, 2)) = $List(tCase, 3)
        Set tSC = ..Read($List(tCase, 1), .tQuery, .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code _ " " _ tFault.reason, 1: ""), "400 PORT.VALIDATION " _ $Parameter(..#PORT, $List(tCase, 4)), $List(tCase, 1) _ " " _ $List(tCase, 2) _ " " _ $Extract($List(tCase, 3), 1, 12) _ " is refused with its reason")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.AtelierPortFixture).CallCount(), 0, "before any route")
    Kill tQuery
    Set tQuery("schema") = $Extract(tLong, 1, 128)
    Set tSC = ..Read("Catalog.Tables", .tQuery, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ ##class(OcuPilot.Test.AtelierPortFixture).CallCount(), "200 1", "a schema of 128 characters, the bound, is read")
    Do ##class(OcuPilot.Test.AtelierPortFixture).Clear()
    Do ..ArmCatalog()
    Kill tQuery
    Set tQuery("table") = "a." _ $Translate($Justify("", 255), " ", "t")
    Set tSC = ..Read("Catalog.Fields", .tQuery, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ ##class(OcuPilot.Test.AtelierPortFixture).CallCount(), "404 1", "a table of 257 characters, the bound, is resolved")
}

/// <p>Matrix: a resolve that answers no table is 404 <code>PORT.NOTFOUND</code> with the port's own
/// reason, unlogged, and two tables 400 <code>PORT.VALIDATION</code> naming the ambiguity; neither
/// reads the tab.</p>
/// <p>Mutation (Rule 19): log the absence in <method>OcuPilot.Port.AtelierPort.CatalogResolve</method>
/// -&gt; the unlogged assertion goes red.</p>
Method TestTheResolveRefusesNoneAndTwoTables()
{
    Do ..ArmCatalog()
    Kill tQuery
    Set tQuery("table") = "OcuProbe.Absent"
    Set tSC = ..Read("Catalog.Triggers", .tQuery, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code _ " " _ tFault.reason, 1: "") _ " " _ ##class(OcuPilot.Test.AtelierPortFixture).CallCount(), "404 PORT.NOTFOUND " _ $Parameter(..#PORT, "REASONCATALOGNOTFOUND") _ " 1", "no table is not found, after the resolve alone")
    Do $$$AssertEquals(##class(OcuPilot.Test.LogProbe).Captured("message"), "", "and nothing is logged")

    Do ..ClearFixtures()
    Do ..ArmCatalog()
    Do ##class(OcuPilot.Test.AtelierPortFixture).Queue("Query", "200 OK", ..Envelope("{""TABLE_SCHEMA"":""OcuProbe"",""TABLE_NAME"":""A.B""},{""TABLE_SCHEMA"":""OcuProbe.A"",""TABLE_NAME"":""B""}"))
    Kill tQuery
    Set tQuery("table") = "OcuProbe.A.B"
    Set tSC = ..Read("Catalog.Fields", .tQuery, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code _ " " _ tFault.reason, 1: "") _ " " _ ##class(OcuPilot.Test.AtelierPortFixture).CallCount(), "400 PORT.VALIDATION " _ $Parameter(..#PORT, "REASONCATALOGAMBIGUOUS") _ " 1", "two tables are refused as ambiguous, after the resolve alone")
    Do $$$AssertEquals(tRows, "", "with no rows")
}

/// <p>Matrix: the gate runs first -- without <code>%Development:USE</code>, or without READ on the
/// namespace's routines database, a catalog read is refused 403 naming the pair, before any
/// route.</p>
Method TestTheGateRefusesBeforeAnyRoute()
{
    Do ..ArmCatalog()
    Do ##class(OcuPilot.Test.AtelierPortFixture).SetGateClass("OcuPilot.Test.ScreenGate")
    For tLeg = $ListBuild("", "%Development:USE", "Catalog.Tables"), $ListBuild("%Development", "%DB_PROBEHOME:READ", "Catalog.Triggers") {
        If $List(tLeg, 1) '= "" Do ##class(OcuPilot.Test.ScreenGate).Hold($List(tLeg, 1), "USE")
        Kill tQuery
        Set tQuery("table") = "OcuProbe.Thing"
        Set tSC = ..Read($List(tLeg, 3), .tQuery, .tRows, .tHttp, .tFault)
        Set tPair = $Select($IsObject(tFault) && $IsObject(tFault.%Get("detail")): tFault.detail.failedPair, 1: "")
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code, 1: "") _ " " _ tPair, "403 AUTH.NOPRIVILEGE " _ $List(tLeg, 2), $List(tLeg, 3) _ ": a caller short of " _ $List(tLeg, 2) _ " is refused naming it")
    }
    Do $$$AssertEquals(##class(OcuPilot.Test.AtelierPortFixture).CallCount(), 0, "before any route")
}

/// <p>Matrix, AD-61 rule 2: an instance whose highest version is 5 is refused every catalog read 501
/// naming both versions before any route, and a catalog endpoint serves no request type but
/// <code>LIST</code>.</p>
/// <p>Mutation (Rule 19): drop <code>Query:6</code> from
/// <parameter>OcuPilot.Port.AtelierPort.MINVERSIONS</parameter> -&gt; every refusal here goes
/// red.</p>
Method TestTheVersionGateRefusesEveryCatalogRead()
{
    Do ..ArmCatalog()
    Do ##class(OcuPilot.Test.AtelierPortFixture).SetVersion(5)
    Set tWanted = $Replace($Replace($Parameter(..#PORT, "REASONVERSION"), "{highest}", 5), "{needed}", 6)
    For tEndpoint = "Catalog.Schemas", "Catalog.Tables", "Catalog.Views", "Catalog.Procedures", "Catalog.Table", "Catalog.Fields", "Catalog.Indices", "Catalog.Triggers", "Catalog.Constraints" {
        Kill tQuery
        Set tQuery("table") = "OcuProbe.Thing"
        Set tSC = ..Read(tEndpoint, .tQuery, .tRows, .tHttp, .tFault)
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code _ " " _ tFault.reason, 1: ""), "501 PORT.NOTIMPLEMENTED " _ tWanted, tEndpoint _ " on a version 5 instance is refused naming both versions")
    }
    Do ##class(OcuPilot.Test.AtelierPortFixture).SetVersion(6)
    Kill tQuery
    Set tSC = ..Read("Catalog.Schemas", .tQuery, .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ ##class(OcuPilot.Test.AtelierPortFixture).ImplVersion(), "200 6", "version 6 reads, at version 6")
    Kill tQuery
    Set tQuery("namespace") = $Namespace
    Set tSC = ##class(OcuPilot.Test.AtelierPortFixture).Invoke("Catalog.Tables", "COMPILE", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code, 1: ""), "501 PORT.NOTIMPLEMENTED", "a request type other than LIST is not served")
    Do $$$AssertEquals(##class(OcuPilot.Test.AtelierPortFixture).CallCount(), 1, "and only the version 6 read reached a route")
}

/// <p>Matrix, AD-61 rule 6: a SQL error the query route answers under 200 -- on a list, on a tab's
/// resolve and on a tab's own read -- is 500 <code>INTERNAL</code> with the generic reason and no
/// rows, its vendor text logged and in no field of the fault.</p>
/// <p>Mutation (Rule 19): drop the envelope's errors from
/// <method>OcuPilot.Port.AtelierPort.Outcome</method>'s soft-error test -&gt; the rows read as an
/// answer and this goes red.</p>
Method TestASqlErrorIsTheInternalFaultWithNothingSent()
{
    Set tError = "{""status"":{""errors"":[{""error"":""ERROR #5540: SQLCODE: -30 Message: Table 'OCUPROBE195SECRET' not found"",""code"":5540}],""summary"":""""},""console"":[],""result"":{""content"":[{""SCHEMA_NAME"":""Probe""}]}}"
    For tLeg = $ListBuild("Catalog.Schemas", 0), $ListBuild("Catalog.Fields", 0), $ListBuild("Catalog.Fields", 1) {
        Do ..ClearFixtures()
        Do ..ArmCatalog()
        If $List(tLeg, 2) Do ##class(OcuPilot.Test.AtelierPortFixture).Queue("Query", "200 OK", ..Resolved("OcuProbe", "Thing"))
        Do ##class(OcuPilot.Test.AtelierPortFixture).Arm("Query", "200 OK", tError)
        Kill tQuery
        Set tQuery("table") = "OcuProbe.Thing"
        Set tSC = ..Read($List(tLeg, 1), .tQuery, .tRows, .tHttp, .tFault)
        Set tWhere = $List(tLeg, 1) _ $Select($List(tLeg, 2): " (its own read)", $List(tLeg, 1) = "Catalog.Fields": " (its resolve)", 1: "")
        Do $$$AssertEquals(tHttp _ " " _ $Select($IsObject(tFault): tFault.code _ " " _ tFault.reason, 1: "") _ " [" _ tRows _ "]", "500 INTERNAL " _ ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON _ " []", tWhere _ ": the internal fault, no rows")
        Do $$$AssertTrue($Select($IsObject(tFault): tFault.%ToJSON(), 1: "") '[ "OCUPROBE195SECRET", tWhere _ ": the vendor's text is in no field of the fault")
        Do $$$AssertTrue(##class(OcuPilot.Test.LogProbe).Captured("message") [ "OCUPROBE195SECRET", tWhere _ ": and is logged")
    }
}

}
