/// <p>Pins Story 21.25's reads (AD-5, AD-36, AD-51, AD-61): the table and indices tabs' declarations, <class>OcuPilot.Port.SqlPort</class>'s
/// <code>TABLESTATS</code> and <code>INDEX</code> reads and their shapes as the instance holds them, the indices tab's rows naming their table, the
/// not-found answers and every hostile id, each rebuild's copy-out script, and the gates, refused before any read or write.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, the calling account holding <code>%Development:USE</code> and READ on
/// <code>USER</code>'s code databases, and a <code>USER</code> namespace, where each test makes <class>OcuPilot.Test.SqlTuningProbe</class>'s table
/// and removes it after. It collects, fixes and clears statistics on that table through the instance's own calls and changes nothing else.
/// Live-safe.</p>
Class OcuPilot.Test.SqlTableRead Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.SqlTuningProbe";

Parameter FIXTURE = "OcuPilot.Test.SqlTuningPortFixture";

Parameter SEAM = "OcuPilot.Test.SqlTuningGateSeam";

Parameter NAMESPACE = "USER";

Parameter TABLEDESCRIPTOR = "OcuPilot.Screen.Descriptor.ExplorerSqlTable";

Parameter INDICESDESCRIPTOR = "OcuPilot.Screen.Descriptor.ExplorerSqlIndices";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#SEAM, "Reset")
    Quit $$$OK
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

/// <p>The action ids <var>pDeclaration</var> declares as row actions, comma-separated.</p>
ClassMethod Actions(pDeclaration As %DynamicObject) As %String
{
    Set tActions = ""
    Set tIterator = pDeclaration.rowActions.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tAction) {
        Set tActions = tActions _ $Select(tActions = "": "", 1: ",") _ tAction.id
    }
    Quit tActions
}

/// <p>The port's <var>pType</var> of <code>Tables</code> for <var>pId</var> in <code>USER</code>, through the fixture: the status and code
/// <code>http code</code>, with the answer in <var>pAnswer</var> and the fault in <var>pFault</var>.</p>
ClassMethod Read(pType As %String, pId As %String, Output pAnswer As %DynamicObject, Output pFault As %DynamicObject) As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = pId
    Set tSC = $ClassMethod(..#FIXTURE, "Invoke", "Tables", pType, .tQuery, "", .pAnswer, .tHttp, .pFault)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(pFault)): pFault.code, 1: "")
}

/// <p>The instance's own statistics call <var>pWhat</var> -- <code>collect</code>, <code>fix</code> or <code>clear</code> -- on <var>pTable</var>, made
/// outside the product's write path so a test puts the table in the state a read needs.</p>
ClassMethod Statistics(pWhat As %String, pTable As %String)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        If pWhat = "collect" Do $SYSTEM.SQL.TuneTable(pTable, 1, 0, .tMessage, 0, 0)
        If pWhat = "fix" Do ##class(%SQL.Manager.Catalog).SetTableExtentSize($Piece(pTable, ".", 1), $Piece(pTable, ".", 2), 777, 0)
        If pWhat = "clear" Do $SYSTEM.SQL.Stats.Table.ClearTableStats(pTable)
    } Catch {
    }
    Set $NAMESPACE = tOrigNS
}

/// <p>The two tabs declare the shape the story rules: the table tab's entity type and its page action, and the indices tab's entity type, composite id
/// <code>[Table, Map]</code> with the table among its fields, and its row action.</p>
/// <p>Mutation (Rule 19): the indices tab's id drops <code>Map</code> -> the id assertion goes red.</p>
Method TestTheTabsDeclareTheirShape()
{
    Set tTable = ..Declaration(..#TABLEDESCRIPTOR)
    Do $$$AssertEquals(tTable.entityType _ "|" _ tTable.id.kind _ "|" _ ..Actions(tTable) _ "|" _ tTable.tab.position, "sql-table|single|rebuild-indices,tune,clear-statistics|1", "the table tab's entity type, id and page actions")
    Set tIndices = ..Declaration(..#INDICESDESCRIPTOR)
    Do $$$AssertEquals(tIndices.entityType _ "|" _ tIndices.id.kind _ "|" _ tIndices.id.parts.%ToJSON() _ "|" _ ..Actions(tIndices) _ "|" _ tIndices.tab.position, "sql-index|composite|[""Table"",""Map""]|rebuild|3", "the indices tab's entity type, composite id and row action")
    Do $$$AssertTrue(tIndices.read.fields.%ToJSON() [ """Table"",""Index"",""Map""", "the indices tab reads the table beside the index and its map")
}

/// <p>The indices tab's rows each name the table they belong to, spelled as the instance holds it, which is what its composite id keys them by.</p>
/// <p>Mutation (Rule 19): <code>AtelierPort.CatalogRows</code> stops setting <code>Table</code> -> the assertion goes red.</p>
Method TestTheIndicesRowsNameTheirTable()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tTable), "the probe table is created")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("table") = tTable
    Set tQuery("maxRows") = 100
    Set tSC = ##class(OcuPilot.Port.AtelierPort).Invoke("Catalog.Indices", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals($Select($$$ISOK(tSC): tHttp, 1: 0), 200, "the indices read answers")
    Set tSeen = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tSeen = tSeen _ $Select(tSeen = "": "", 1: ",") _ tRow.Table _ "/" _ tRow.Map
    }
    Do $$$AssertEquals(tSeen, "OcuProbe225.T1/%%DDLBEIndex,OcuProbe225.T1/IDKEY,OcuProbe225.T1/IdxB,OcuProbe225.T1/IdxC", "each row names the table, beside its map")
}

/// <p>The <code>TABLESTATS</code> read answers <code>{Namespace, Table, Class, ExtentSize, StatsKind, CollectedAt, HasFixed}</code> as the instance
/// holds them: a table nobody collected statistics for reads <code>none</code> and the instance's default size, collected statistics read
/// <code>collected</code> with the rows' count and the time they were gathered, and a fixed size reads <code>fixed</code> and overrides the collected
/// one until it is cleared.</p>
/// <p>Mutation (Rule 19): <code>SqlPort.TableFacts</code> reads the collected size for a table with fixed statistics -> the fixed assertions go red.</p>
Method TestTheTableStatisticsAreRead()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tTable), "the probe table is created")
    Set tVerdict = ..Read("TABLESTATS", tTable, .tAnswer, .tFault)
    Do $$$AssertEquals(tVerdict, "200 ", "the read answers")
    If '$IsObject($Get(tAnswer)) Quit
    Do $$$AssertEquals(tAnswer.Namespace _ "|" _ tAnswer.Table _ "|" _ tAnswer.Class _ "|" _ tAnswer.StatsKind _ "|" _ tAnswer.HasFixed _ "|" _ tAnswer.CollectedAt, "USER|OcuProbe225.T1|OcuProbe225.T1|none|0|", "a table with no statistics: its name, class and kind")
    Do $$$AssertEquals(tAnswer.%GetTypeOf("ExtentSize") _ "|" _ tAnswer.%GetTypeOf("HasFixed"), "number|boolean", "the extent size is a number and the fixed flag a boolean")
    Do ..Statistics("collect", tTable)
    Set tVerdict = ..Read("TABLESTATS", tTable, .tAnswer, .tFault)
    Do $$$AssertEquals(tAnswer.StatsKind _ "|" _ tAnswer.ExtentSize _ "|" _ tAnswer.HasFixed, "collected|5|0", "collected statistics read the rows' count")
    Do $$$AssertTrue($Match(tAnswer.CollectedAt, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$") > 0, "and the time they were gathered, in ISO form: " _ tAnswer.CollectedAt)
    Set tCollectedAt = tAnswer.CollectedAt
    Do ..Statistics("fix", tTable)
    Set tVerdict = ..Read("TABLESTATS", tTable, .tAnswer, .tFault)
    Do $$$AssertEquals(tAnswer.StatsKind _ "|" _ tAnswer.ExtentSize _ "|" _ tAnswer.HasFixed _ "|" _ (tAnswer.CollectedAt = tCollectedAt), "fixed|777|1|1", "a fixed size overrides the collected one, which keeps its time")
    Do ..Statistics("clear", tTable)
    Set tVerdict = ..Read("TABLESTATS", tTable, .tAnswer, .tFault)
    Do $$$AssertEquals(tAnswer.HasFixed _ "|" _ (tAnswer.StatsKind '= "fixed"), "0|1", "clearing the fixed statistics leaves none")
    Set tVerdict = ..Read("TABLESTATS", $ZConvert(tTable, "L"), .tAnswer, .tFault)
    Do $$$AssertEquals(tVerdict _ "|" _ tAnswer.Table, "200 |OcuProbe225.T1", "the table is named as the instance spells it whatever case the caller used")
}

/// <p>The <code>INDEX</code> read answers one indices row, <code>{Namespace, Table, Class, Index, Map, Type}</code>, for the composite
/// <code>[Table, Map]</code>: an index reads its type, and the data map reads <code>Data/Master</code>.</p>
/// <p>Mutation (Rule 19): <code>SqlPort.TableFacts</code> takes the first row for any map -> the map assertions go red.</p>
Method TestAnIndexIsRead()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tTable), "the probe table is created")
    Set tSeparator = $Char(1)
    Set tVerdict = ..Read("INDEX", tTable _ tSeparator _ "IdxC", .tAnswer, .tFault)
    Do $$$AssertEquals(tVerdict, "200 ", "an index is read")
    If '$IsObject($Get(tAnswer)) Quit
    Do $$$AssertEquals(tAnswer.Namespace _ "|" _ tAnswer.Table _ "|" _ tAnswer.Class _ "|" _ tAnswer.Index _ "|" _ tAnswer.Map _ "|" _ tAnswer.Type, "USER|OcuProbe225.T1|OcuProbe225.T1|IdxC|IdxC|Index", "its table, class, name, map and type")
    Set tVerdict = ..Read("INDEX", tTable _ tSeparator _ "IDKEY", .tAnswer, .tFault)
    Do $$$AssertEquals(tVerdict _ "|" _ tAnswer.Map _ "|" _ (tAnswer.Type [ "Data"), "200 |IDKEY|1", "the data map is read, its type marking it")
    Set tVerdict = ..Read("INDEX", tTable _ tSeparator _ "%%DDLBEIndex", .tAnswer, .tFault)
    Do $$$AssertEquals(tVerdict _ "|" _ tAnswer.Index _ "|" _ tAnswer.Map _ "|" _ tAnswer.Type, "200 |DDLBEIndex|%%DDLBEIndex|Bitmap Extent", "a map whose name differs from its index's is read under the map, and its index name is the instance's")
}

/// <p>A table the caller's schema does not show is 404 <code>PORT.NOTFOUND</code>, and every id outside the shape, a map the table does not hold
/// among them, is 400 <code>PORT.VALIDATION</code>, before any call: no dot, over the table bound, a control character, an index id that is not a table and a
/// map, an empty part, a map over the name bound, and a request type this endpoint does not serve (501).</p>
/// <p>Mutation (Rule 19): <code>SqlPort.TableTarget</code> answers a row for an absent map -> the absent-map assertion goes red.</p>
Method TestAbsentAndHostileIdsAreRefusedBeforeAnyCall()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tTable), "the probe table is created")
    Set tSeparator = $Char(1)
    Set tLong = $Translate($Justify("", 258), " ", "a")
    Set tVerdict = ..Read("TABLESTATS", "OcuProbe225.Absent", .tAnswer, .tFault)
    Do $$$AssertEquals(tVerdict _ "|" _ tFault.reason, "404 PORT.NOTFOUND|" _ ##class(OcuPilot.Port.AtelierPort).#REASONCATALOGNOTFOUND, "an absent table is not found")
    Set tVerdict = ..Read("INDEX", tTable _ tSeparator _ "NoSuchMap", .tAnswer, .tFault)
    Do $$$AssertEquals(tVerdict _ "|" _ tFault.reason, "400 PORT.VALIDATION|" _ ##class(OcuPilot.Api.Error).#REASONPORTFIELDSHAPE, "a map the table does not hold is refused as a shape error")
    Set tVerdict = ..Read("INDEX", "OcuProbe225.Absent" _ tSeparator _ "IdxB", .tAnswer, .tFault)
    Do $$$AssertEquals(tVerdict, "404 PORT.NOTFOUND", "an index of an absent table is not found")
    For tId = "NoDot", tLong _ ".T", "OcuProbe225.T" _ $Char(7), "" {
        Set tVerdict = ..Read("TABLESTATS", tId, .tAnswer, .tFault)
        Do $$$AssertEquals(tVerdict, "400 PORT.VALIDATION", "a table id outside the shape is refused: '" _ $Extract(tId, 1, 12) _ "'")
    }
    For tId = tTable, tTable _ tSeparator, tSeparator _ "IdxB", tTable _ tSeparator _ "IdxB" _ tSeparator _ "x", tTable _ tSeparator _ $Translate($Justify("", 129), " ", "a"), tTable _ tSeparator _ "Idx" _ $Char(7), "NoDot" _ tSeparator _ "IdxB" {
        Set tVerdict = ..Read("INDEX", tId, .tAnswer, .tFault)
        Do $$$AssertEquals(tVerdict, "400 PORT.VALIDATION", "an index id outside the shape is refused: '" _ $Translate($Extract(tId, 1, 24), $Char(1, 7), "|!") _ "'")
    }
    Set tVerdict = ..Read("COMPACT", tTable, .tAnswer, .tFault)
    Do $$$AssertEquals(tVerdict, "501 PORT.NOTIMPLEMENTED", "a request type the endpoint does not serve is refused")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 0, "the instance was asked for no write")
}

/// <p>Each rebuild's script (AD-59) is its one vendor call, the table's class found from its SQL name and, for one index, the name the instance builds
/// it by read from the table's indices, each name as a string literal, so a name that holds a quote never runs as code.</p>
/// <p>Mutation (Rule 19): <code>SqlPort.TableSnippet</code> renders an empty index list for <code>REBUILD</code> -> the one-index assertion goes red.</p>
Method TestEachRebuildsScriptIsItsOneVendorCall()
{
    Set tPort = ..#FIXTURE
    Set tSeparator = $Char(1)
    Do $$$AssertEquals($ClassMethod(tPort, "SnippetForm", "Tables", "REBUILD") _ "|" _ $ClassMethod(tPort, "SnippetForm", "Tables", "REBUILDALL") _ "|" _ $ClassMethod(tPort, "SnippetForm", "Tables", "TABLESTATS") _ "|" _ $ClassMethod(tPort, "SnippetForm", "Tables", "INDEX"), "objectscript|objectscript||", "the two writes have a script and the two reads none")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = "OcuProbe225.T1" _ tSeparator _ "Idx""B"
    Set tScript = $ClassMethod(tPort, "Snippet", "Tables", "REBUILD", .tQuery).%Get(0).%Get("text")
    Do $$$AssertTrue((tScript [ "FindClassName(""OcuProbe225.T1"")") && (tScript [ "%Execute(""OcuProbe225"", ""T1"")") && (tScript [ "If tResult.%Get(""SQL_MAP_NAME"") = ""Idx""""B"" {") && (tScript [ "RebuildIndices(tClass, $ListBuild(tIndex))"), "one index: its class, its map found among the table's indices with the quote doubled, and the name the instance builds it by: " _ tScript)
    Set tQuery("id") = "OcuProbe225.T1"
    Set tScript = $ClassMethod(tPort, "Snippet", "Tables", "REBUILDALL", .tQuery).%Get(0).%Get("text")
    Do $$$AssertTrue(tScript [ "RebuildIndices(tClass, """")", "every index: an empty index list: " _ tScript)
}

/// <p>The gate refuses before any read or write: without <code>%Development:USE</code> every request type of the endpoint is 403 naming the pair, and
/// without WRITE the reads still answer while each write is refused 403 naming the WRITE pair. No vendor call is made, and no index is rebuilt.</p>
/// <p>Mutation (Rule 19): <code>SqlPort.TablesInvoke</code> gates a write as a read -> the WRITE assertions go red.</p>
Method TestTheGatesRefuseBeforeAnyReadOrWrite()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tTable), "the probe table is created")
    Set tSeparator = $Char(1)
    Do $ClassMethod(..#PROBE, "KillIndex", ..#NAMESPACE, tTable, "IdxB")
    Do $ClassMethod(..#SEAM, "Deny", "USE")
    For tCase = $ListBuild("TABLESTATS", tTable), $ListBuild("INDEX", tTable _ tSeparator _ "IdxB"), $ListBuild("REBUILD", tTable _ tSeparator _ "IdxB"), $ListBuild("REBUILDALL", tTable), $ListBuild("TUNE", tTable), $ListBuild("CLEARSTATS", tTable), $ListBuild("SCHEMA", "OcuProbe225"), $ListBuild("TUNESCHEMA", "OcuProbe225") {
        Set tVerdict = ..Read($List(tCase, 1), $List(tCase, 2), .tAnswer, .tFault)
        Do $$$AssertEquals(tVerdict _ " " _ $Select($IsObject($Get(tFault)): tFault.detail.failedPair, 1: ""), "403 " _ ##class(OcuPilot.Kernel.Denial).Code() _ " %Development:USE", $List(tCase, 1) _ ": refused naming the Explorer's pair")
    }
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Deny", "WRITE")
    For tCase = $ListBuild("TABLESTATS", tTable, 200), $ListBuild("INDEX", tTable _ tSeparator _ "IdxB", 200), $ListBuild("SCHEMA", "OcuProbe225", 200), $ListBuild("REBUILD", tTable _ tSeparator _ "IdxB", 403), $ListBuild("REBUILDALL", tTable, 403), $ListBuild("TUNE", tTable, 403), $ListBuild("CLEARSTATS", tTable, 403), $ListBuild("TUNESCHEMA", "OcuProbe225", 403) {
        Set tVerdict = ..Read($List(tCase, 1), $List(tCase, 2), .tAnswer, .tFault)
        Do $$$AssertEquals(+tVerdict, $List(tCase, 3), $List(tCase, 1) _ ": " _ $Select($List(tCase, 3) = 200: "a read passes without WRITE", 1: "a write is refused without it"))
        If $List(tCase, 3) = 403 Do $$$AssertEquals($Piece($Select($IsObject($Get(tFault)): tFault.detail.failedPair, 1: ""), ":", 2), "WRITE", "naming the WRITE pair")
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls") _ "|" _ $ClassMethod(..#PROBE, "IndexEntries", ..#NAMESPACE, tTable, "IdxB"), "0|0", "no vendor call was made and the killed index is still empty")
}

}
