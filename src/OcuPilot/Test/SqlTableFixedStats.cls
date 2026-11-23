/// <p>Pins Story 21.31's fixed-statistics writes on both permitted callers (AC1 to AC3; AD-6, AD-7, AD-10, AD-21, AD-51, AD-53, AD-56, AD-58): a table's extent
/// size, a field's selectivity and a map's size, each set by the screen's action and by the agent's confirmed proposal and read back; collected statistics
/// saved as fixed first and an outlier value, outlier selectivity or average size not sent kept; every value outside its shape, and an outlier value the
/// instance would run as code, refused before any call; a failed set saying so; a changed target closed; and a table of OcuPilot's own refused.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, which holds
/// <code>%Development:USE</code> and WRITE on <code>USER</code>'s and the install namespace's routines databases, and a <code>USER</code> namespace, where
/// each test makes its own <class>OcuPilot.Test.SqlTuningProbe</class> tables and removes them after, each fixed statistic through Clear fixed statistics.
/// It snapshots the stored governance policy before and puts it back after. Live-safe.</p>
Class OcuPilot.Test.SqlTableFixedStats Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.SqlTuningProbe";

Parameter FIXTURE = "OcuPilot.Test.SqlTuningPortFixture";

Parameter SEAM = "OcuPilot.Test.SqlTuningGateSeam";

Parameter TUNE = "OcuPilot.Test.SqlTableTune";

Parameter READS = "OcuPilot.Test.SqlTableRead";

Parameter HELPERS = "OcuPilot.Test.SqlIndexRebuild";

Parameter NAMESPACE = "USER";

Parameter OWNNAMESPACE = "HSCUSTOM";

Parameter OWNTABLE = "OcuPilot_Kernel_State.Convo";

Parameter EXTENTTOOL = "OcuPilot.Screen.Tool.ExplorerSqlTableSetExtentSize";

Parameter MAPTOOL = "OcuPilot.Screen.Tool.ExplorerSqlIndexSetMapSize";

Parameter FIELDTOOL = "OcuPilot.Screen.Tool.ExplorerSqlFieldSetSelectivity";

Parameter CLEARTOOL = "OcuPilot.Screen.Tool.ExplorerSqlTableClearStatistics";

Parameter TABLESCREEN = "explorer.sqltable";

Parameter INDEXSCREEN = "explorer.sqlindices";

Parameter FIELDSCREEN = "explorer.sqlfieldstatistics";

Property PreparedPolicy [ MultiDimensional ];

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#PROBE, "Remove", ..#NAMESPACE)
    Kill ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Clear()
    If $$$ISERR(tSC) Quit tSC
    Kill tSettings
    For tTool = ..#EXTENTTOOL, ..#MAPTOOL, ..#FIELDTOOL, ..#CLEARTOOL {
        Set tSettings($Parameter(tTool, "TOOLNAME")) = "enabled"
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
    Do $$$AssertStatusOK(tSC, "the three setters and Clear fixed statistics, whose keys ship disabled, are enabled through their stored settings")
    Kill ^|"USER"|OcuPilotSqlProbeRan
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#NAMESPACE), "every probe object is removed")
    Kill ^|"USER"|OcuPilotSqlProbeRan
    Do $ClassMethod(..#SEAM, "Reset")
    Kill ^||OcuPilotDatabaseWritePort
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Kill tRows
    Merge tRows = ..PreparedPolicy
    Quit ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
}

/// <p>The screen action <var>pAction</var> of <var>pScreen</var> on <var>pId</var> with the string values <var>pValues</var>: <class>OcuPilot.Test.SqlTableTune</class>'s.</p>
ClassMethod Act(pScreen As %String, pAction As %String, pId As %String, pValues As %DynamicObject, pNamespace As %String = {..#NAMESPACE}, Output pAnswer As %DynamicObject) As %Integer
{
    Quit $ClassMethod(..#TUNE, "Act", pScreen, pAction, pId, pValues, pNamespace, .pAnswer)
}

/// <p>The agent's proposal of <var>pTool</var> for <var>pId</var> (a composite target's map or field, with <code>Table</code> in <var>pArgs</var>) and its
/// confirm through <var>pPort</var>: <class>OcuPilot.Test.SqlTableTune</class>'s.</p>
ClassMethod Agent(pTool As %String, pId As %String, pArgs As %DynamicObject, Output pResult As %DynamicObject, pPort As %String = "", pNamespace As %String = {..#NAMESPACE}) As %String
{
    Quit $ClassMethod(..#TUNE, "Agent", pTool, pId, pArgs, pNamespace, .tProposal, .pResult, pPort)
}

/// <p>The port's <var>pType</var> of <code>Tables</code> for <var>pId</var> with <var>pValues</var>, through the fixture: <code>http code</code>.</p>
ClassMethod Invoke(pType As %String, pId As %String, pValues As %DynamicObject, Output pFault As %DynamicObject) As %String
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = pId
    Set tIterator = pValues.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tQuery(tKey) = tValue
    }
    Set tSC = $ClassMethod(..#FIXTURE, "Invoke", "Tables", pType, .tQuery, "", .tAnswer, .tHttp, .pFault)
    Quit +$Get(tHttp) _ " " _ $Select($IsObject($Get(pFault)): pFault.code, 1: "")
}

/// <p>The composite id of the map or field <var>pSecond</var> of <var>pTable</var>.</p>
ClassMethod Id(pTable As %String, pSecond As %String) As %String
{
    Quit pTable _ $Char(1) _ pSecond
}

/// <p>The table <var>pTable</var>'s statistics as the port reads them: <code>kind size fixed</code>.</p>
ClassMethod Stats(pTable As %String) As %String
{
    Quit $ClassMethod(..#TUNE, "Stats", pTable)
}

/// <p>Field <var>pField</var>'s fixed values read directly: <code>selectivity|outlier selectivity|outlier value|average size</code>.</p>
ClassMethod Fixed(pTable As %String, pField As %String) As %String
{
    Quit $ClassMethod(..#PROBE, "FixedField", ..#NAMESPACE, pTable, pField)
}

/// <p>Whether the selectivity text <var>pRead</var> is within a thousandth of <var>pExpected</var> percent: the instance reads one back rounded.</p>
ClassMethod Near(pRead As %String, pExpected As %String) As %Boolean
{
    Quit $Select(pRead = "": 0, 1: ($ZAbs($Translate(pRead, "%") - pExpected) < 0.001))
}

/// <p>Collect <var>pTable</var>'s statistics through the instance's own call.</p>
ClassMethod Collect(pTable As %String)
{
    Do $ClassMethod(..#READS, "Statistics", "collect", pTable)
}

/// <p>Remove <var>pTable</var>'s fixed statistics through the product's Clear fixed statistics tool: its <code>confirm http</code>.</p>
ClassMethod Restore(pTable As %String) As %String
{
    Quit ..Agent(..#CLEARTOOL, pTable, {})
}

/// <p>The three tools declare what the story rules: names, port, endpoint, request types, that none is destructive or sends a body, the screen action and
/// value, the governance keys (disabled), the consequence codes, the values each admits and requires, and the target each takes.</p>
/// <p>Mutation (Rule 19): set <code>DESTRUCTIVE</code> 1 on <class>OcuPilot.Screen.Tool.SqlStatementAction</class> -> the destructive assertion goes red.</p>
Method TestTheToolsDeclareTheirWritePath()
{
    For tCase = $ListBuild(..#EXTENTTOOL, "explorer.sqltable.setextentsize", "TABLESTATS", "SETEXTENT", "set-extent-size", "set-extent-size=ExtentSize", "SQL.TABLE.SETEXTENTSIZE", "ExtentSize", "ExtentSize"), $ListBuild(..#MAPTOOL, "explorer.sqlindices.setmapsize", "INDEX", "SETMAPSIZE", "set-map-size", "set-map-size=SizeMB", "SQL.TABLE.SETMAPSIZE", "SizeMB", "SizeMB"), $ListBuild(..#FIELDTOOL, "explorer.sqlfieldstatistics.setselectivity", "FIELDSTATS", "SETSELECTIVITY", "set-selectivity", "set-selectivity=Selectivity", "SQL.TABLE.SETSELECTIVITY", "Selectivity,OutlierSelectivity,OutlierValue,AverageFieldSize", "Selectivity") {
        Set tTool = $List(tCase, 1)
        Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $ClassMethod(tTool, "PortClass") _ "|" _ $ClassMethod(tTool, "Endpoint") _ "|" _ $ClassMethod(tTool, "ReadType") _ "|" _ $ClassMethod(tTool, "WriteType"), $List(tCase, 2) _ "|OcuPilot.Port.SqlPort|Tables|" _ $List(tCase, 3) _ "|" _ $List(tCase, 4), $List(tCase, 2) _ ": name, port, endpoint and request types")
        Do $$$AssertEquals($ClassMethod(tTool, "Advertised") _ $ClassMethod(tTool, "Destructive") _ $ClassMethod(tTool, "SendsBody") _ "|" _ $ListToString($ClassMethod(tTool, "ScreenActionIds")) _ "|" _ $Parameter(tTool, "SCREENVALUES"), "100|" _ $List(tCase, 5) _ "|" _ $List(tCase, 6), $List(tCase, 2) _ ": advertised, not destructive, no body, its screen action and value")
        Set tSeeded = ##class(OcuPilot.Kernel.Governance.Baseline).Seed($List(tCase, 2), .tListed)
        Do $$$AssertEquals(tListed _ " " _ tSeeded, "1 0", $List(tCase, 2) _ ": its key is in the baseline and ships disabled")
        Do $$$AssertEquals($ClassMethod(tTool, "Consequence", {}) _ "|" _ $ListToString($ClassMethod(tTool, "SettableFields")) _ "|" _ $ListToString($ClassMethod(tTool, "RequiredFields")), $List(tCase, 7) _ "|" _ $List(tCase, 8) _ "|" _ $List(tCase, 9), $List(tCase, 2) _ ": its consequence code and the values it admits and requires")
        Set tPairs = $ClassMethod(tTool, "PrivilegePairs", "", .tResolved)
        Do $$$AssertTrue(tResolved && ($ListFind(tPairs, $ListBuild("%Development", "USE")) > 0), $List(tCase, 2) _ ": its pairs hold the Explorer's")
        Set tSC = $ClassMethod(tTool, "StateDiff", {"StatsKind": "collected", "Type": "Index"}, .tRows, .tProblem)
        Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ tRows.%Size() _ "|" _ tProblem, "1|0|", $List(tCase, 2) _ ": the card shows no state row beside the value's old and new")
    }
    Do $$$AssertEquals(##class(OcuPilot.Api.AtelierError).#REASONTABLESET, ##class(OcuPilot.Port.SqlPort).ReasonFor("SQL.TABLE.SETMAPSIZE"), "the three consequence codes carry one sentence")
    Do $$$AssertEquals($ClassMethod(..#EXTENTTOOL, "IdProblem", "OcuProbe225.T1") _ "|" _ ($ClassMethod(..#EXTENTTOOL, "IdProblem", "NoDot") '= "") _ "|" _ ($ClassMethod(..#MAPTOOL, "IdProblem", ..Id("OcuProbe225.T1", "IdxB")) = "") _ "|" _ ($ClassMethod(..#MAPTOOL, "IdProblem", "OcuProbe225.T1") '= "") _ "|" _ ($ClassMethod(..#FIELDTOOL, "IdProblem", ..Id("NoDot", "B")) '= ""), "|1|1|1|1", "the extent size takes a table name, and the map and field setters the composite [Table, second]")
    Do $$$AssertEquals($ClassMethod(..#MAPTOOL, "MintClass") _ "|" _ $ClassMethod(..#FIELDTOOL, "MintClass"), "OcuPilot.Screen.Tool.SqlIndexMint|OcuPilot.Screen.Tool.SqlFieldMint", "each composite target is built through its mint")
}

/// <p>AC4's read and AD-36: <code>FIELDSTATS</code> answers one field's statistics, each value the one in use (the collected one while the table has no
/// fixed statistics, the fixed one once it has), and <code>INDEX</code> answers the map's size in MB; a field the table does not hold, or spelled in another
/// case, is 400 <code>PORT.VALIDATION</code>.</p>
/// <p>Mutation (Rule 19): <code>SqlPort.TableAnswer</code> answers a field's collected values for a table with fixed statistics -> the fixed assertions go red.</p>
Method TestTheFieldStatisticsAndTheMapSizeAreReadAsInUse()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tTable), "the probe table is created")
    Do ..Collect(tTable)
    Set tVerdict = $ClassMethod(..#READS, "Read", "FIELDSTATS", ..Id(tTable, "B"), .tAnswer, .tFault)
    Do $$$AssertEquals(tVerdict, "200 ", "the read answers")
    If '$IsObject($Get(tAnswer)) Quit
    Do $$$AssertEquals(tAnswer.Table _ "|" _ tAnswer.Field _ "|" _ tAnswer.StatsKind _ "|" _ tAnswer.HasFixed _ "|" _ tAnswer.Selectivity _ "|" _ tAnswer.%GetTypeOf("AverageFieldSize"), tTable _ "|B|collected|0|20.0000%|number", "an unfixed table answers the collected values")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "FixField", ..#NAMESPACE, tTable, "B", "40%", "10%", """q""", 9), "field B is fixed at 40% with an outlier of ""q"" at 10% and an average size of 9")
    Set tVerdict = $ClassMethod(..#READS, "Read", "FIELDSTATS", ..Id(tTable, "B"), .tAnswer, .tFault)
    Do $$$AssertEquals(tAnswer.StatsKind _ "|" _ tAnswer.HasFixed _ "|" _ tAnswer.Selectivity _ "|" _ tAnswer.OutlierSelectivity _ "|" _ tAnswer.OutlierValue _ "|" _ tAnswer.AverageFieldSize, "fixed|1|40.0000%|10%|""q""|9", "a fixed table answers the fixed ones")
    Set tVerdict = $ClassMethod(..#READS, "Read", "FIELDSTATS", ..Id(tTable, "A"), .tAnswer, .tFault)
    Do $$$AssertEquals(tAnswer.OutlierValue _ "|" _ tAnswer.OutlierSelectivity, "|", "a field with no outlier answers none, not the instance's <Null> text")
    For tId = ..Id(tTable, "b"), ..Id(tTable, "NoSuchField"), tTable {
        Set tVerdict = $ClassMethod(..#READS, "Read", "FIELDSTATS", tId, .tAnswer, .tFault)
        Do $$$AssertEquals(tVerdict, "400 PORT.VALIDATION", "a field the table does not hold is refused: " _ $Piece(tId, $Char(1), 2))
    }
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "FixMap", ..#NAMESPACE, tTable, "IdxB", 1536), "map IdxB is fixed at 1536 blocks")
    Set tVerdict = $ClassMethod(..#READS, "Read", "INDEX", ..Id(tTable, "IdxB"), .tAnswer, .tFault)
    Do $$$AssertEquals(tVerdict _ "|" _ tAnswer.SizeMB, "200 |3", "the map's size reads 3 MB")
    Do $$$AssertEquals(..Restore(tTable) _ "|" _ ..Stats(tTable), "200 |collected 5 0", "Clear fixed statistics restores the table")
}

/// <p>AC1. A table's extent size is set by the agent's confirmed proposal and by the screen's page action: with its statistics collected they are saved as
/// fixed first, so the other fields keep their measured selectivity, and the size reads as sent when the confirm answers, its read-back reading
/// <code>matches</code>. A table with no statistics has none saved. The largest size is accepted, one over it is not.</p>
/// <p>Mutation (Rule 19): <code>SqlPort.TableCall</code> passes the old extent size to the setter -> the read-back assertions go red on both callers;
/// <code>SqlPort.SettingCall</code> skips <code>FixTableStats</code> -> the other fields' fixed selectivity reads empty.</p>
Method TestTheExtentSizeIsSetOnBothCallers()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tCollected), "the first probe table is created")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 2, 7, .tPlain), "the second is created")
    Do ..Collect(tCollected)
    Set tConfirm = ..Agent(..#EXTENTTOOL, tCollected, {"ExtentSize": 5000}, .tResult, ..#FIXTURE)
    Do $$$AssertEquals(tConfirm _ "|" _ $ClassMethod(..#SEAM, "TableCalls") _ "|" _ ..Stats(tCollected), "200 |SETEXTENT|{""ExtentSize"":""5000"",""StatsKind"":""collected""}|fixed 5000 1", "the agent's set reaches the instance as one call after the statistics were collected: " _ tConfirm)
    Do $$$AssertEquals(##class(OcuPilot.Test.EcpDataServerWrite).Verdict($Get(tResult)) _ "|" _ ($Piece(..Fixed(tCollected, "B"), "|", 1) '= ""), "matches|1", "its read-back reads matches, and field B kept its measured selectivity as a fixed one")
    Do $$$AssertEquals(..Restore(tCollected) _ "|" _ ..Stats(tCollected), "200 |collected 5 0", "the extent size is restored")
    Set tStatus = ..Act(..#TABLESCREEN, "set-extent-size", tCollected, {"ExtentSize": "7000"}, , .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ##class(OcuPilot.Test.EcpDataServerWrite).Verdict(tAnswer) _ "|" _ ..Stats(tCollected), "200|matches|fixed 7000 1", "the screen's set reads back as sent")
    Do ..Restore(tCollected)
    Do $ClassMethod(..#SEAM, "Reset")
    Set tConfirm = ..Agent(..#EXTENTTOOL, tPlain, {"ExtentSize": 9}, , ..#FIXTURE)
    Do $$$AssertEquals(tConfirm _ "|" _ $ClassMethod(..#SEAM, "TableCalls") _ "|" _ ..Stats(tPlain) _ "|" _ ($Piece(..Fixed(tPlain, "B"), "|", 1) = ""), "200 |SETEXTENT|{""ExtentSize"":""9"",""StatsKind"":""none""}|fixed 9 1|1", "a table with no statistics has the size set and nothing saved first: " _ tConfirm)
    Set tLimit = ##class(OcuPilot.Port.SqlPort).#MAXEXTENTSIZE
    Do $$$AssertEquals(##class(OcuPilot.Port.SqlPort).ValueProblem("ExtentSize", tLimit) _ "|" _ (##class(OcuPilot.Port.SqlPort).ValueProblem("ExtentSize", tLimit + 1) = ##class(OcuPilot.Api.AtelierError).#REASONTABLEEXTENTSIZE), "|1", "the bound's own value is accepted and one over it refused with the published sentence")
    Set tConfirm = ..Agent(..#EXTENTTOOL, tPlain, {"ExtentSize": (tLimit)})
    Do $$$AssertEquals(tConfirm _ "|" _ ..Stats(tPlain), "200 |fixed " _ tLimit _ " 1", "the largest size is set: " _ tConfirm)
    Set tConfirm = ..Agent(..#EXTENTTOOL, tPlain, {"ExtentSize": (tLimit + 1)})
    Do $$$AssertEquals(tConfirm _ "|" _ ..Stats(tPlain), "mint 400 " _ ##class(OcuPilot.Api.AtelierError).#REASONTABLEEXTENTSIZE _ "|fixed " _ tLimit _ " 1", "one over it is refused at the mint with the published sentence: " _ tConfirm)
    Do ..Restore(tPlain)
}

/// <p>AC1. A field's selectivity is set by the agent's confirmed proposal and by the screen's row action, which sends the selectivity alone: an outlier
/// value, outlier selectivity or average size not sent keeps the field's own, a bare number is a percentage and <code>1</code> a unique field's.</p>
/// <p>Mutation (Rule 19): <code>SqlPort.SettingCall</code> passes the empty string for an outlier value not sent -> the kept-value assertions go red;
/// the selectivity is sent without its percent sign -> the percentage assertions go red.</p>
Method TestASelectivityIsSetOnBothCallersAndAnOmittedOutlierIsKept()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tTable), "the probe table is created")
    Do ..Collect(tTable)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "FixField", ..#NAMESPACE, tTable, "B", "40%", "10%", """q""", 9), "field B is fixed at 40% with an outlier of ""q"" at 10% and an average size of 9")
    Set tConfirm = ..Agent(..#FIELDTOOL, "B", {"Table": (tTable), "Selectivity": "25%"}, .tResult, ..#FIXTURE)
    Set tFixed = ..Fixed(tTable, "B")
    Do $$$AssertEquals(tConfirm _ "|" _ $ClassMethod(..#SEAM, "TableCalls") _ "|" _ $Piece(tFixed, "|", 2, 4) _ "|" _ ..Near($Piece(tFixed, "|", 1), 25), "200 |SETSELECTIVITY|{""Selectivity"":""25%"",""StatsKind"":""fixed"",""Field"":""B""}|10%|""q""|9|1", "the agent's set changes the selectivity and keeps the outlier values: " _ tConfirm _ " " _ $ClassMethod(..#SEAM, "TableCalls") _ " " _ tFixed)
    Set tStatus = ..Act(..#FIELDSCREEN, "set-selectivity", ..Id(tTable, "B"), {"Selectivity": "1"}, , .tAnswer)
    Set tFixed = ..Fixed(tTable, "B")
    Do $$$AssertEquals(tStatus _ "|" _ $Piece(tFixed, "|", 1) _ "|" _ $Piece(tFixed, "|", 2, 4), "200|1|10%|""q""|9", "the screen's set of 1 reads 1, a unique field's, and keeps them too")
    Set tConfirm = ..Agent(..#FIELDTOOL, "B", {"Table": (tTable), "Selectivity": "30", "OutlierSelectivity": "5%", "OutlierValue": "42", "AverageFieldSize": 11})
    Set tFixed = ..Fixed(tTable, "B")
    Do $$$AssertEquals(tConfirm _ "|" _ $Piece(tFixed, "|", 2, 4) _ "|" _ ..Near($Piece(tFixed, "|", 1), 30), "200 |5%|42|11|1", "every value sent is set, and a bare 30 is 30%: " _ tConfirm _ " " _ tFixed)
    Do $$$AssertEquals(..Restore(tTable) _ "|" _ ..Stats(tTable), "200 |collected 5 0", "Clear fixed statistics restores the table")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 2, 12, .tWide), "a second table of 12 rows, whose fields' average sizes are fractions, is created")
    Do ..Collect(tWide)
    Set tStatus = ..Act(..#FIELDSCREEN, "set-selectivity", ..Id(tWide, "C"), {"Selectivity": "25%"}, , .tAnswer)
    Set tFixed = ..Fixed(tWide, "C")
    Do $$$AssertEquals(tStatus _ "|" _ ..Stats(tWide) _ "|" _ ($Piece(..Fixed(tWide, "A"), "|", 1) '= "") _ "|" _ ..Near($Piece(tFixed, "|", 1), 25) _ "|" _ ($Piece(tFixed, "|", 4) [ "."), "200|fixed 12 1|1|1|1", "the screen's set on a collected table saves the measured statistics as fixed: the extent size, field A and the field's own fractional average size keep their measured values: " _ tStatus _ " " _ ..Stats(tWide) _ " " _ tFixed _ " " _ tAnswer.%ToJSON())
    Do ..Restore(tWide)
}

/// <p>AC1. A map's size is set by the agent's confirmed proposal and by the screen's row action, in MB, sent to the instance as blocks of 2 KB (512 to the
/// MB), and the map reads that size when the confirm answers, its read-back reading <code>matches</code>.</p>
/// <p>Mutation (Rule 19): <code>SqlPort.SettingCall</code> passes the MB as the block count -> the size assertions go red on both callers.</p>
Method TestAMapSizeIsSetOnBothCallers()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tTable), "the probe table is created")
    Do ..Collect(tTable)
    Set tConfirm = ..Agent(..#MAPTOOL, "IdxB", {"Table": (tTable), "SizeMB": 3}, .tResult, ..#FIXTURE)
    Set tVerdict = $ClassMethod(..#READS, "Read", "INDEX", ..Id(tTable, "IdxB"), .tAnswer, .tFault)
    Do $$$AssertEquals(tConfirm _ "|" _ $ClassMethod(..#SEAM, "TableCalls") _ "|" _ ##class(OcuPilot.Test.EcpDataServerWrite).Verdict($Get(tResult)) _ "|" _ tAnswer.SizeMB, "200 |SETMAPSIZE|{""SizeMB"":""3"",""StatsKind"":""collected"",""Map"":""IdxB""}|matches|3", "the agent's set reads 3 MB and its read-back matches: " _ tConfirm)
    Set tStatus = ..Act(..#INDEXSCREEN, "set-map-size", ..Id(tTable, "IdxC"), {"SizeMB": "2"}, , .tAnswer)
    Set tVerdict = $ClassMethod(..#READS, "Read", "INDEX", ..Id(tTable, "IdxC"), .tAnswer, .tFault)
    Do $$$AssertEquals(tStatus _ "|" _ tAnswer.SizeMB, "200|2", "the screen's set of another map reads 2 MB")
    Set tVerdict = $ClassMethod(..#READS, "Read", "INDEX", ..Id(tTable, "IdxB"), .tAnswer, .tFault)
    Do $$$AssertEquals(tAnswer.SizeMB, 3, "and leaves the first map as it was")
    Do $$$AssertEquals(..Restore(tTable) _ "|" _ ..Stats(tTable), "200 |collected 5 0", "Clear fixed statistics restores the table")
}

/// <p>AC2. A value outside its shape (an extent size over the bound, fractional, text or empty; a selectivity of 0, over 99.999%, negative or text; a map size
/// or average size that is not a whole number; an outlier value too long or with a control character) is refused with the published sentence before any
/// call, by the port, the screen's action and the agent's mint, and leaves the collected statistics unfixed.</p>
/// <p>Mutation (Rule 19): <code>SqlPort.PercentValid</code> accepts anything -> the selectivity legs go red.</p>
Method TestAValueOutsideItsShapeIsRefusedBeforeAnyCall()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tTable), "the probe table is created")
    Do ..Collect(tTable)
    Set tError = "OcuPilot.Api.AtelierError"
    Set tLong = """" _ $Translate($Justify("", 127), " ", "a") _ """"
    For tCase = $ListBuild("SETEXTENT", tTable, "ExtentSize", "-1", "TABLEEXTENTSIZE"), $ListBuild("SETEXTENT", tTable, "ExtentSize", "2.5", "TABLEEXTENTSIZE"), $ListBuild("SETEXTENT", tTable, "ExtentSize", "abc", "TABLEEXTENTSIZE"), $ListBuild("SETEXTENT", tTable, "ExtentSize", "", "TABLEEXTENTSIZE"), $ListBuild("SETEXTENT", tTable, "ExtentSize", "1000000000001", "TABLEEXTENTSIZE"), $ListBuild("SETSELECTIVITY", ..Id(tTable, "B"), "Selectivity", "0%", "TABLESELECTIVITY"), $ListBuild("SETSELECTIVITY", ..Id(tTable, "B"), "Selectivity", "0", "TABLESELECTIVITY"), $ListBuild("SETSELECTIVITY", ..Id(tTable, "B"), "Selectivity", "100%", "TABLESELECTIVITY"), $ListBuild("SETSELECTIVITY", ..Id(tTable, "B"), "Selectivity", "-5%", "TABLESELECTIVITY"), $ListBuild("SETSELECTIVITY", ..Id(tTable, "B"), "Selectivity", "abc", "TABLESELECTIVITY"), $ListBuild("SETSELECTIVITY", ..Id(tTable, "B"), "Selectivity", "", "TABLESELECTIVITY"), $ListBuild("SETSELECTIVITY", ..Id(tTable, "B"), "OutlierSelectivity", "abc", "TABLESELECTIVITY"), $ListBuild("SETMAPSIZE", ..Id(tTable, "IdxB"), "SizeMB", "-1", "TABLEWHOLENUMBER"), $ListBuild("SETMAPSIZE", ..Id(tTable, "IdxB"), "SizeMB", "2.5", "TABLEWHOLENUMBER"), $ListBuild("SETSELECTIVITY", ..Id(tTable, "B"), "AverageFieldSize", "-1", "TABLEWHOLENUMBER"), $ListBuild("SETSELECTIVITY", ..Id(tTable, "B"), "OutlierValue", tLong _ "x", "TABLEOUTLIERVALUE"), $ListBuild("SETSELECTIVITY", ..Id(tTable, "B"), "OutlierValue", """a" _ $Char(7) _ """", "PORTVALIDATION") {
        Kill tValues
        Set tValues = {}
        If $List(tCase, 1) = "SETSELECTIVITY" Do tValues.%Set("Selectivity", "25%")
        Do tValues.%Set($List(tCase, 3), $List(tCase, 4))
        Set tVerdict = ..Invoke($List(tCase, 1), $List(tCase, 2), tValues, .tFault)
        Set tSentence = $Select($List(tCase, 5) = "PORTVALIDATION": ##class(OcuPilot.Api.Error).#REASONPORTFIELDSHAPE, 1: $ClassMethod(tError, "SqlReasonFor", $Parameter(tError, $List(tCase, 5))))
        Do $$$AssertEquals(tVerdict _ "|" _ $Select($IsObject($Get(tFault)): tFault.reason, 1: ""), "400 " _ $Select($List(tCase, 5) = "PORTVALIDATION": "PORT.VALIDATION", 1: $Parameter(tError, $List(tCase, 5))) _ "|" _ tSentence, $List(tCase, 1) _ " " _ $List(tCase, 3) _ " [" _ $Translate($Extract($List(tCase, 4), 1, 12), $Char(7), "!") _ "]: refused by the port with its sentence")
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls") _ "|" _ ..Stats(tTable), "0|collected 5 0", "no call was made, and the collected statistics are not fixed")
    For tCase = $ListBuild("-1", ##class(OcuPilot.Api.AtelierError).#REASONTABLEEXTENTSIZE), $ListBuild("1000000000001", ##class(OcuPilot.Api.AtelierError).#REASONTABLEEXTENTSIZE), $ListBuild("abc", ##class(OcuPilot.Api.AtelierError).#REASONTABLEEXTENTSIZE) {
        Set tStatus = ..Act(..#TABLESCREEN, "set-extent-size", tTable, {"ExtentSize": ($List(tCase, 1))}, , .tAnswer)
        Do $$$AssertEquals($ClassMethod(..#HELPERS, "Verdict", tStatus, tAnswer) _ "|" _ $ClassMethod(..#HELPERS, "Problem", tAnswer), "400 TOOL.ARGUMENTS|" _ $List(tCase, 2), "the screen's extent size '" _ $List(tCase, 1) _ "' is refused with the published sentence")
    }
    For tCase = $ListBuild(..#FIELDSCREEN, "set-selectivity", ..Id(tTable, "B"), "Selectivity", "0%", ##class(OcuPilot.Api.AtelierError).#REASONTABLESELECTIVITY), $ListBuild(..#FIELDSCREEN, "set-selectivity", ..Id(tTable, "B"), "Selectivity", "101%", ##class(OcuPilot.Api.AtelierError).#REASONTABLESELECTIVITY), $ListBuild(..#INDEXSCREEN, "set-map-size", ..Id(tTable, "IdxB"), "SizeMB", "-1", ##class(OcuPilot.Api.AtelierError).#REASONTABLEWHOLENUMBER), $ListBuild(..#INDEXSCREEN, "set-map-size", ..Id(tTable, "IdxB"), "SizeMB", "2.5", ##class(OcuPilot.Api.AtelierError).#REASONTABLEWHOLENUMBER) {
        Set tStatus = ..Act($List(tCase, 1), $List(tCase, 2), $List(tCase, 3), ##class(%DynamicAbstractObject).%FromJSON("{""" _ $List(tCase, 4) _ """:""" _ $List(tCase, 5) _ """}"), , .tAnswer)
        Do $$$AssertEquals($ClassMethod(..#HELPERS, "Verdict", tStatus, tAnswer) _ "|" _ $ClassMethod(..#HELPERS, "Problem", tAnswer), "400 TOOL.ARGUMENTS|" _ $List(tCase, 6), "the screen's " _ $List(tCase, 4) _ " '" _ $List(tCase, 5) _ "' is refused with the published sentence")
    }
    Set tConfirm = ..Agent(..#FIELDTOOL, "B", {"Table": (tTable), "Selectivity": "0%"}, , ..#FIXTURE)
    Do $$$AssertEquals(tConfirm, "mint 400 " _ ##class(OcuPilot.Api.AtelierError).#REASONTABLESELECTIVITY, "the agent's selectivity of 0% is refused at the mint with the published sentence")
    Set tConfirm = ..Agent(..#EXTENTTOOL, tTable, {"ExtentSize": -1}, , ..#FIXTURE)
    Do $$$AssertTrue(tConfirm [ "mint 400", "and its negative extent size: " _ tConfirm)
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls") _ "|" _ ..Stats(tTable), "0|collected 5 0", "the screen's and the agent's refusals made no call and fixed nothing")
}

/// <p>AC2. The instance runs an outlier value as an ObjectScript expression, so only a number or double-quoted text reaches it: a value that would run
/// code is refused by the port and by the agent's mint and runs nothing, while text holding quotes and parentheses inside double quotes is stored as data.</p>
/// <p>Mutation (Rule 19): <code>SqlPort.OutlierLiteral</code> answers 1 -> the code legs go red and the marker is set.</p>
Method TestAnOutlierValueIsNeverRun()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tTable), "the probe table is created")
    Do ..Collect(tTable)
    For tCode = "1 Set ^OcuPilotSqlProbeRan=1", "$Increment(^OcuPilotSqlProbeRan)", """x"") Set ^OcuPilotSqlProbeRan=1 //", "'q'" {
        Set tVerdict = ..Invoke("SETSELECTIVITY", ..Id(tTable, "B"), {"Selectivity": "25%", "OutlierSelectivity": "5%", "OutlierValue": (tCode)}, .tFault)
        Set tConfirm = ..Agent(..#FIELDTOOL, "B", {"Table": (tTable), "Selectivity": "25%", "OutlierSelectivity": "5%", "OutlierValue": (tCode)}, , ..#FIXTURE)
        Do $$$AssertEquals(tVerdict _ "|" _ ($Extract(tConfirm, 1, 8) = "mint 400") _ "|" _ $Get(^|"USER"|OcuPilotSqlProbeRan, "unset"), "400 PORT.VALIDATION|1|unset", "'" _ tCode _ "' is refused by the port and the mint and runs nothing")
    }
    Set tText = """a""""b(c)); Set ^OcuPilotSqlProbeRan=1 ;"""
    Set tConfirm = ..Agent(..#FIELDTOOL, "B", {"Table": (tTable), "Selectivity": "25%", "OutlierSelectivity": "5%", "OutlierValue": (tText)})
    Do $$$AssertEquals(tConfirm _ "|" _ $Piece(..Fixed(tTable, "B"), "|", 3) _ "|" _ $Get(^|"USER"|OcuPilotSqlProbeRan, "unset"), "200 |" _ tText _ "|unset", "text in double quotes holding a quote, parentheses and code is stored as data: " _ tConfirm)
    Do ..Restore(tTable)
}

/// <p>AD-6, AD-34. A proposal whose table's statistics were collected after it was minted, and one whose table's statistics were fixed after it was minted,
/// are refused <code>PROPOSAL.TARGETCHANGED</code> at their confirm, and nothing is set. The digest covers the merged payload, so a declared value is
/// the one reviewed and a change to the old value alone is not seen.</p>
Method TestAChangedTargetIsRefusedTargetChanged()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tTable), "the probe table is created")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set ^||OcuPilotDatabaseWritePort = $Parameter(..#EXTENTTOOL, "PORTCLASS")
    Set tSC = $ClassMethod(..#HELPERS, "Mint", ..#EXTENTTOOL, tTable, {"Table": (tTable), "ExtentSize": 5000}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the extent size's proposal is minted: " _ $Get(tProblem))
    If '$IsObject($Get(tProposal)) Quit
    Do ..Collect(tTable)
    Set tConfirm = $ClassMethod("OcuPilot.Test.LicenseProbe", "Confirm", tProposal, .tResult)
    Do $$$AssertEquals(tConfirm _ "|" _ ..Stats(tTable), "409 PROPOSAL.TARGETCHANGED|collected 5 0", "the confirm after the statistics were collected is refused, and the statistics are not fixed: " _ tConfirm)
    Set tSC = $ClassMethod(..#HELPERS, "Mint", ..#FIELDTOOL, "B", {"Table": (tTable), "Field": "B", "Selectivity": "25%"}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the selectivity's proposal is minted on the collected table: " _ $Get(tProblem))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "FixField", ..#NAMESPACE, tTable, "B", "30%"), "the table's statistics are fixed after the proposal")
    Set tConfirm = $ClassMethod("OcuPilot.Test.LicenseProbe", "Confirm", tProposal, .tResult)
    Do $$$AssertEquals(tConfirm _ "|" _ ..Near($Piece(..Fixed(tTable, "B"), "|", 1), 30), "409 PROPOSAL.TARGETCHANGED|1", "its confirm is refused too, and the selectivity is still 30%: " _ tConfirm)
    Do ..Restore(tTable)
}

/// <p>The gate refuses before any read or write: without USE the field read and each setter are 403 naming the pair; without WRITE the read answers and each
/// setter is refused 403 naming it. No call is made.</p>
/// <p>Mutation (Rule 19): <code>SqlPort.TablesInvoke</code> gates a setter as a read -> the WRITE assertions go red.</p>
Method TestTheGatesRefuseBeforeAnyReadOrWrite()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tTable), "the probe table is created")
    Set tCases = $ListBuild($ListBuild("FIELDSTATS", ..Id(tTable, "B"), "{}"), $ListBuild("SETEXTENT", tTable, "{""ExtentSize"":""5""}"), $ListBuild("SETSELECTIVITY", ..Id(tTable, "B"), "{""Selectivity"":""25%""}"), $ListBuild("SETMAPSIZE", ..Id(tTable, "IdxB"), "{""SizeMB"":""1""}"))
    Do $ClassMethod(..#SEAM, "Deny", "USE")
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tVerdict = ..Invoke($List(tCase, 1), $List(tCase, 2), ##class(%DynamicAbstractObject).%FromJSON($List(tCase, 3)), .tFault)
        Do $$$AssertEquals(tVerdict _ " " _ $Select($IsObject($Get(tFault)): tFault.detail.failedPair, 1: ""), "403 " _ ##class(OcuPilot.Kernel.Denial).Code() _ " %Development:USE", $List(tCase, 1) _ ": refused naming the Explorer's pair")
    }
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Deny", "WRITE")
    For tI = 1:1:$ListLength(tCases) {
        Set tCase = $List(tCases, tI)
        Set tVerdict = ..Invoke($List(tCase, 1), $List(tCase, 2), ##class(%DynamicAbstractObject).%FromJSON($List(tCase, 3)), .tFault)
        Do $$$AssertEquals(+tVerdict, $Select(tI = 1: 200, 1: 403), $List(tCase, 1) _ ": " _ $Select(tI = 1: "the read passes without WRITE", 1: "a setter is refused without it"))
        If tI > 1 Do $$$AssertEquals($Piece($Select($IsObject($Get(tFault)): tFault.detail.failedPair, 1: ""), ":", 2), "WRITE", "naming the WRITE pair")
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls") _ "|" _ ..Stats(tTable), "0|none 100000 0", "no call was made and nothing is fixed")
}

/// <p>A set the instance refuses after the collected statistics were saved as fixed answers 409 <code>SQL.TABLE.VENDOR</code> with the message and
/// <code>statisticsFixed</code> in <code>detail</code>, and the table then reads fixed.</p>
/// <p>Mutation (Rule 19): <code>SqlPort.TableWritten</code> leaves <code>statisticsFixed</code> out -> the detail assertion goes red.</p>
Method TestASetThatFailsAfterTheStatisticsWereSavedSaysSo()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tTable), "the probe table is created")
    Do ..Collect(tTable)
    Do $ClassMethod(..#SEAM, "BadMap")
    Set tVerdict = ..Invoke("SETMAPSIZE", ..Id(tTable, "IdxB"), {"SizeMB": "3"}, .tFault)
    Do $$$AssertEquals(tVerdict _ "|" _ $Select($IsObject($Get(tFault)): tFault.detail.statisticsFixed _ "|" _ (tFault.detail.message '= ""), 1: ""), "409 SQL.TABLE.VENDOR|1|1", "the refusal says the statistics were saved, with the instance's message")
    Do $$$AssertEquals(..Stats(tTable), "fixed 5 1", "and the table's collected statistics are its fixed ones now")
    Do ..Restore(tTable)
}

/// <p>Each setter's script (AD-59) saves the collected statistics where the table has them and no fixed ones, makes the setter's one vendor call with the
/// values sent, and does what the write does when it is run: the extent size, the map's size in MB and the field's selectivity with its kept outlier values.</p>
/// <p>Mutation (Rule 19): <code>SqlPort.SettingSnippet</code> leaves the <code>FixTableStats</code> line out -> the extent size assertion goes red.</p>
Method TestEachSettersScriptDoesWhatTheWriteDoes()
{
    Set tPort = ..#FIXTURE
    Do $$$AssertEquals($ClassMethod(tPort, "SnippetForm", "Tables", "SETEXTENT") _ "|" _ $ClassMethod(tPort, "SnippetForm", "Tables", "SETSELECTIVITY") _ "|" _ $ClassMethod(tPort, "SnippetForm", "Tables", "SETMAPSIZE") _ "|" _ $ClassMethod(tPort, "SnippetForm", "Tables", "FIELDSTATS"), "objectscript|objectscript|objectscript|", "the three setters have a script and the read none")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tTable), "the probe table is created")
    Do ..Collect(tTable)
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = tTable
    Set tQuery("ExtentSize") = "5000"
    Set tScript = $ClassMethod(tPort, "Snippet", "Tables", "SETEXTENT", .tQuery).%Get(0).%Get("text")
    Do $$$AssertTrue((tScript [ "FixTableStats(""" _ tTable _ """)") && (tScript [ "SetTableExtentSize(""OcuProbe225"", ""T1"", ""5000"", 0)"), "the extent size's script: " _ tScript)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RunScript", ..#NAMESPACE, tScript), "it runs")
    Do $$$AssertEquals(..Stats(tTable) _ "|" _ ($Piece(..Fixed(tTable, "B"), "|", 1) '= ""), "fixed 5000 1|1", "and sets the size after saving the measured statistics")
    Do ..Restore(tTable)
    Set tQuery("id") = ..Id(tTable, "IdxB")
    Kill tQuery("ExtentSize")
    Set tQuery("SizeMB") = "3"
    Set tScript = $ClassMethod(tPort, "Snippet", "Tables", "SETMAPSIZE", .tQuery).%Get(0).%Get("text")
    Do $$$AssertTrue(tScript [ "SetMapBlockCount(""OcuProbe225"", ""T1"", ""IdxB"", ""3"" * 512, 0)", "the map's script sends the MB as blocks: " _ tScript)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RunScript", ..#NAMESPACE, tScript), "it runs")
    Set tVerdict = $ClassMethod(..#READS, "Read", "INDEX", ..Id(tTable, "IdxB"), .tAnswer, .tFault)
    Do $$$AssertEquals(tAnswer.SizeMB, 3, "and sets the map to 3 MB")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "FixField", ..#NAMESPACE, tTable, "B", "40%", "10%", """q""", 9), "field B is fixed at 40% with an outlier of ""q"" at 10% and an average size of 9")
    Set tQuery("id") = ..Id(tTable, "B")
    Kill tQuery("SizeMB")
    Set tQuery("Selectivity") = "25"
    Set tScript = $ClassMethod(tPort, "Snippet", "Tables", "SETSELECTIVITY", .tQuery).%Get(0).%Get("text")
    Do $$$AssertTrue((tScript [ "SetFieldSelectivity(""OcuProbe225"", ""T1"", ""B"", ""25%"", 0, tOutlierSelectivity, tOutlierValue, tAverage)") && (tScript [ "FieldCurrentSelectivity"), "the selectivity's script reads the kept values and sends 25 as a percentage: " _ tScript)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RunScript", ..#NAMESPACE, tScript), "it runs")
    Set tFixed = ..Fixed(tTable, "B")
    Do $$$AssertEquals($Piece(tFixed, "|", 2, 4) _ "|" _ ..Near($Piece(tFixed, "|", 1), 25), "10%|""q""|9|1", "and sets the selectivity, keeping the outlier values: " _ tFixed)
    Do ..Restore(tTable)
}

/// <p>AC1. A table whose schema and name need delimiting, <parameter>OcuPilot.Test.SqlTuningProbe.DELIMITEDSCHEMA</parameter> and <code>Probe Table</code>,
/// has each setter round-trip through both callers, the instance being handed the names as it holds them.</p>
/// <p>Mutation (Rule 19): <code>SqlPort.SettingCall</code> quotes the schema it hands the setters -> the instance refuses it and the assertions go red.</p>
Method TestATableWithADelimitedNameIsSetOnBothCallers()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 0, 4, .tTable, "Probe Table"), "a table named with a space is made in the schema named with one")
    Do ..Collect(tTable)
    Set tConfirm = ..Agent(..#EXTENTTOOL, tTable, {"ExtentSize": 4000})
    Do $$$AssertEquals(tConfirm _ "|" _ ..Stats(tTable), "200 |fixed 4000 1", "the agent's extent size: " _ tConfirm)
    Set tStatus = ..Act(..#TABLESCREEN, "set-extent-size", tTable, {"ExtentSize": "6000"}, , .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..Stats(tTable), "200|fixed 6000 1", "the screen's extent size")
    Set tConfirm = ..Agent(..#MAPTOOL, "IdxB", {"Table": (tTable), "SizeMB": 4})
    Set tVerdict = $ClassMethod(..#READS, "Read", "INDEX", ..Id(tTable, "IdxB"), .tAnswer, .tFault)
    Do $$$AssertEquals(tConfirm _ "|" _ tAnswer.SizeMB, "200 |4", "the agent's map size: " _ tConfirm)
    Set tStatus = ..Act(..#FIELDSCREEN, "set-selectivity", ..Id(tTable, "B"), {"Selectivity": "25%"}, , .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..Near($Piece(..Fixed(tTable, "B"), "|", 1), 25), "200|1", "the screen's selectivity")
    Do $$$AssertEquals(..Restore(tTable) _ "|" _ ..Stats(tTable), "200 |collected 4 0", "Clear fixed statistics restores the table")
}

/// <p>AC3. A table of OcuPilot's own, <code>OcuPilot_Kernel_State.Convo</code>, its field and its map, are refused <code>PROHIBITED.OCUPILOTTABLE</code> with the
/// published sentence by the screen's three actions and by the agent's three confirmed proposals, before any write: the agent's run through the instrumented
/// port, which counts no call, and the table's extent size unchanged.</p>
/// <p>Mutation (Rule 19): <code>SqlTableAction.RefusedBeforeState</code> answers 0 and <code>Prohibited.Prohibits</code> does not send <code>sql-field</code>
/// to <code>TableEntry</code> -> the field legs go red on both callers; either alone leaves them green, the arm's own pin being <code>Test.Prohibited</code>'s.</p>
Method TestATableOfOcuPilotsOwnIsRefusedOnBothCallers()
{
    Set tOwn = ..#OWNTABLE
    Set tMap = $ClassMethod(..#HELPERS, "OwnMap", ..#OWNNAMESPACE, tOwn)
    Do $$$AssertTrue(tMap '= "", "OcuPilot's own table holds an index that is not its data map: " _ tMap)
    If tMap = "" Quit
    Set tReason = ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor("PROHIBITED.OCUPILOTTABLE")
    Set tField = ..OwnField()
    Do $$$AssertTrue(tField '= "", "and a field: " _ tField)
    If tField = "" Quit
    Set tBefore = ..OwnExtent()
    For tCase = $ListBuild(..#TABLESCREEN, "set-extent-size", tOwn, "{""ExtentSize"":""5""}"), $ListBuild(..#INDEXSCREEN, "set-map-size", ..Id(tOwn, tMap), "{""SizeMB"":""1""}"), $ListBuild(..#FIELDSCREEN, "set-selectivity", ..Id(tOwn, tField), "{""Selectivity"":""25%""}") {
        Set tStatus = ..Act($List(tCase, 1), $List(tCase, 2), $List(tCase, 3), ##class(%DynamicAbstractObject).%FromJSON($List(tCase, 4)), ..#OWNNAMESPACE, .tAnswer)
        Do $$$AssertEquals($ClassMethod(..#HELPERS, "Verdict", tStatus, tAnswer) _ "|" _ $Select($IsObject(tAnswer): tAnswer.reason, 1: ""), "403 PROHIBITED.OCUPILOTTABLE|" _ tReason, "the screen's " _ $List(tCase, 2) _ " is refused with the published sentence")
    }
    For tCase = $ListBuild(..#EXTENTTOOL, tOwn, "{""ExtentSize"":5}"), $ListBuild(..#MAPTOOL, tMap, "{""Table"":""" _ tOwn _ """,""SizeMB"":1}"), $ListBuild(..#FIELDTOOL, tField, "{""Table"":""" _ tOwn _ """,""Selectivity"":""25%""}") {
        Set tConfirm = ..Agent($List(tCase, 1), $List(tCase, 2), ##class(%DynamicAbstractObject).%FromJSON($List(tCase, 3)), , ..#FIXTURE, ..#OWNNAMESPACE)
        Do $$$AssertTrue(tConfirm [ "PROHIBITED.OCUPILOTTABLE", "the agent's " _ $Parameter($List(tCase, 1), "TOOLNAME") _ " is refused: " _ tConfirm)
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls") _ "|" _ (..OwnExtent() = tBefore), "0|1", "no call was made and the own table's extent size is the one it was")
}

/// <p>A field of OcuPilot's own table that is not its row id, or <code>""</code>.</p>
ClassMethod OwnField() As %String
{
    Set tOrigNS = $NAMESPACE
    Set tField = ""
    Try {
        Set $NAMESPACE = ..#OWNNAMESPACE
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tSC = tStatement.%Prepare("SELECT TOP 1 COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND COLUMN_NAME <> 'ID' ORDER BY ORDINAL_POSITION")
        Set tResult = tStatement.%Execute($Piece(..#OWNTABLE, ".", 1), $Piece(..#OWNTABLE, ".", 2))
        If tResult.%Next() Set tField = tResult.%GetData(1)
    } Catch {
    }
    Set $NAMESPACE = tOrigNS
    Quit tField
}

/// <p>The extent size and fixed flag the instance holds for OcuPilot's own table.</p>
ClassMethod OwnExtent() As %String
{
    Set tOrigNS = $NAMESPACE
    Set tSize = "unread"
    Try {
        Set $NAMESPACE = ..#OWNNAMESPACE
        Set tSize = ##class(%SQL.Manager.Catalog).GetCurrentTableExtentSize($Piece(..#OWNTABLE, ".", 1), $Piece(..#OWNTABLE, ".", 2)) _ "|" _ ##class(%SQL.Manager.Catalog).HasFixedStats($Piece(..#OWNTABLE, ".", 1), $Piece(..#OWNTABLE, ".", 2))
    } Catch {
    }
    Set $NAMESPACE = tOrigNS
    Quit tSize
}

}
