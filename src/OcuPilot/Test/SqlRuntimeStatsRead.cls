/// <p>Pins Story 21.26's reads (AC1, AC5; AD-5, AD-29, AD-35, AD-36, AD-51): the SQL runtime statistics list read by the screen and by the agent's
/// <code>explorer.sqlruntimestats.read</code> as the same rows, the probe statement's summary row and one row per module carrying what the vendor's
/// own <code>ViewStatsSQLDetails</code> averages, and no user, client, process or parameter column; the Runtime statistics collection rows
/// (<code>explorer.sqlruntimestatssettings.read</code>) as the instance's flag reports them; <class>OcuPilot.Port.SqlPort</class>'s
/// <code>STATS</code> count and its id shapes; and the gates, refused before any read or write.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, the calling account holding <code>%Development:USE</code>, READ and WRITE on
/// <code>USER</code>'s code databases and <code>%DB_IRISSYS:READ</code>, and a <code>USER</code> namespace, where each test makes
/// <class>OcuPilot.Test.SqlTuningProbe</class>'s objects, records its own statement's statistics in its own process only and removes both by routine
/// after. Live-safe: it changes no setting and removes no row it did not record.</p>
Class OcuPilot.Test.SqlRuntimeStatsRead Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.SqlTuningProbe";

Parameter PORT = "OcuPilot.Port.SqlPort";

Parameter FIXTURE = "OcuPilot.Test.SqlTuningPortFixture";

Parameter SEAM = "OcuPilot.Test.SqlTuningGateSeam";

Parameter CONFIGPORT = "OcuPilot.Port.ConfigPort";

Parameter CONFIGSEAM = "OcuPilot.Test.ConfigGateSeam";

Parameter ATELIER = "OcuPilot.Port.AtelierPort";

Parameter NAMESPACE = "USER";

Parameter LIST = "OcuPilot.Screen.Descriptor.ExplorerSqlRuntimeStats";

Parameter SETTINGS = "OcuPilot.Screen.Descriptor.ExplorerSqlRuntimeStatsSettings";

Parameter PURGE = "OcuPilot.Screen.Tool.ExplorerSqlRuntimeStatsPurge";

Parameter SETTINGSET = "OcuPilot.Screen.Tool.ExplorerSqlRuntimeStatsSettingSet";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The columns the list's read selects and the user, client, process and parameter columns it never does (AD-35).</p>
Parameter SELECTED = "Routine,Cursor,Module,Runs,AverageRows,AverageGlobalRefs,AverageCommands,AverageDiskWait,AverageTime,ModuleRuns,Statement";

Parameter EXCLUDED = "USERNAME,EXENAME,MACHINENAME,IPADDRESS,PID,PARAMETERS";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#CONFIGSEAM, "Reset")
    Set tSC = $ClassMethod(..#PROBE, "Make", ..#NAMESPACE)
    Do $$$AssertStatusOK(tSC, "the probe objects are created in " _ ..#NAMESPACE)
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#CONFIGSEAM, "Reset")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#NAMESPACE), "every probe object is removed")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StatsRowCount", ..#NAMESPACE), 0, "and none of the probe's statistics rows is left")
    Quit $$$OK
}

/// <p>The descriptor declaration of <var>pClass</var>.</p>
ClassMethod Declaration(pClass As %String) As %DynamicObject
{
    Do $ClassMethod(pClass, "DeclarationJson", .tDeclaration)
    Quit tDeclaration
}

/// <p>The rows of <var>pAnswer</var>, a screen read's answer, whose statement carries the probe's token, as one JSON array text.</p>
ClassMethod ProbeRows(pAnswer As %DynamicObject) As %DynamicArray
{
    Set tRows = []
    If '$IsObject(pAnswer) || (pAnswer.%GetTypeOf("rows") '= "array") Quit tRows
    Set tIterator = pAnswer.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("Statement") [ ##class(OcuPilot.Test.SqlTuningProbe).#STATSTOKEN Do tRows.%Push(tRow)
    }
    Quit tRows
}

/// <p>The vendor's own details of the cursor <var>pCursor</var> of the routine <var>pRoutine</var> in <code>USER</code>, <code>ViewStatsSQLDetails</code>, as
/// the number of rows of each value, in <var>pCounts</var> keyed by <code>module|runs|module runs|rows|global references|commands|disk wait|time</code>
/// (a statement run twice holds each module twice, once per recorded run); the rows read.</p>
ClassMethod VendorDetails(pCursor As %String, pRoutine As %String, Output pCounts) As %Integer
{
    Kill pCounts
    Set tRead = 0
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tSC = tStatement.%Prepare("SELECT ModuleName, RunCount, AvgModCount, AvgRows, AvgGlobalRefs, AvgCommands, AvgDiskWait, AvgTime FROM %SYS_PTools.StatsSQL_ViewStatsSQLDetails(?, ?)")
        Set tResult = tStatement.%Execute(pCursor, pRoutine)
        While tResult.%Next() {
            Set tKey = tResult.%GetData(1) _ "|" _ (+tResult.%GetData(2)) _ "|" _ (+tResult.%GetData(3)) _ "|" _ (+tResult.%GetData(4)) _ "|" _ (+tResult.%GetData(5)) _ "|" _ (+tResult.%GetData(6)) _ "|" _ (+tResult.%GetData(7)) _ "|" _ (+tResult.%GetData(8))
            Set pCounts(tKey) = $Get(pCounts(tKey)) + 1
            Set tRead = tRead + 1
        }
        Set (tResult, tStatement) = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tRead
}

/// <p>The two screens declare the shape the story rules: routes, positions after SQL statements, entity types, ids, sources, actions and classic pages, and
/// the two tools name their port, endpoint and request types.</p>
/// <p>Mutation (Rule 19): the list's read source names <code>Catalog.Statements</code> -> the source assertion goes red.</p>
Method TestTheScreensDeclareTheirShape()
{
    Set tList = ..Declaration(..#LIST)
    Do $$$AssertEquals(tList.route _ "|" _ tList.sideBarPosition _ "|" _ tList.archetype _ "|" _ tList.entityType _ "|" _ tList.scope _ "|" _ tList.toolIdentifier, "system-explorer/sql-runtime-stats|21|list|sql-runtime-stat|namespace|explorer.sqlruntimestats", "the list's route, position, archetype, entity type, scope and identifier")
    Do $$$AssertEquals(tList.id.kind _ "|" _ tList.id.parts.%ToJSON() _ "|" _ tList.read.source.port _ "|" _ tList.read.source.endpoint _ "|" _ tList.read.source.type, "composite|[""Routine"",""Cursor"",""Module""]|atelier|Catalog.RuntimeStats|LIST", "its id is the routine, cursor and module, and its read the catalog's runtime statistics")
    Do $$$AssertEquals(tList.read.sort.default _ "|" _ tList.read.sort.direction _ "|" _ tList.rowActions.%Get(0).id _ "|" _ tList.classicPage, "AverageTime|desc|purge|%CSP.UI.Portal.SQL.QButtons.RuntimeStats", "it sorts by the average time, offers Purge statistics and replaces the classic page")
    Set tFields = ""
    Set tIterator = tList.read.fields.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tField) {
        Set tFields = tFields _ $Select(tFields = "": "", 1: ",") _ tField
    }
    Do $$$AssertEquals(tFields, ..#SELECTED, "it reads the routine, cursor, module, runs, averages and the statement")
    Set tSettings = ..Declaration(..#SETTINGS)
    Do $$$AssertEquals(tSettings.route _ "|" _ tSettings.sideBarPosition _ "|" _ tSettings.entityType _ "|" _ tSettings.scope _ "|" _ tSettings.toolIdentifier _ "|" _ tSettings.classicPage, "system-explorer/sql-runtime-stats-settings|22|sql-runtime-stats-setting|instance|explorer.sqlruntimestatssettings|%CSP.UI.Portal.SQL.QButtons.RuntimeStatsSettings", "the settings list's route, position, entity type, scope, identifier and classic page")
    Do $$$AssertEquals(tSettings.read.source.port _ "|" _ tSettings.read.source.endpoint _ "|" _ tSettings.rowActions.%Get(0).id _ "|" _ tSettings.privileges.%ToJSON(), "config|SQLStats|set|[{""resource"":""%Development"",""permission"":""USE""},{""resource"":""%DB_IRISSYS"",""permission"":""READ""}]", "its read is the SQLStats rows, its action Set value and its pairs the classic page's and the system database's")
    Do $$$AssertEquals($Parameter(..#PURGE, "TOOLNAME") _ "|" _ $ClassMethod(..#PURGE, "PortClass") _ "|" _ $ClassMethod(..#PURGE, "Endpoint") _ "|" _ $ClassMethod(..#PURGE, "ReadType") _ "|" _ $ClassMethod(..#PURGE, "WriteType"), "explorer.sqlruntimestats.purge|OcuPilot.Port.SqlPort|RuntimeStats|STATS|PURGESTATS", "the purge tool's name, port, endpoint and request types")
    Do $$$AssertEquals($Parameter(..#SETTINGSET, "TOOLNAME") _ "|" _ $ClassMethod(..#SETTINGSET, "PortClass") _ "|" _ $ClassMethod(..#SETTINGSET, "Endpoint") _ "|" _ $ClassMethod(..#SETTINGSET, "WriteType"), "explorer.sqlruntimestatssettings.set|OcuPilot.Port.ConfigPort|SQLStats|SET", "the setting tool's name, port, endpoint and request type")
    Do $$$AssertEquals($ClassMethod(..#SETTINGSET, "Consequence", {"Name": "StopAfterMinutes"}) _ "|" _ $ClassMethod(..#PURGE, "Consequence", {}), "SQL.RUNTIMESTATS.SET|SQL.RUNTIMESTATS.PURGE", "each states its consequence code, the set's for every row")
}

/// <p>AC1. The screen's read and the agent's <code>explorer.sqlruntimestats.read</code> answer the same rows. The probe's statement, run twice with
/// statistics on in this process, holds one summary row (module <code>INFO</code>) and one row per module, each carrying the runs and the averages
/// the vendor's own <code>ViewStatsSQLDetails</code> reads for it, and the row count is the instance's own.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.AtelierPort.CATALOGRUNTIMESTATSQUERY</code> divides no summary total by <code>RunCount</code> -> the averages
/// assertion goes red; the descriptor drops <code>Module</code> from its fields -> the fields assertion in <method>TestTheScreensDeclareTheirShape</method>
/// goes red.</p>
Method TestTheListAndTheAgentsReadAnswerTheSameRows()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RecordStats", ..#NAMESPACE), "the probe's statement is run once with statistics on")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RecordStats", ..#NAMESPACE), "and a second time")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#LIST, 1000, .tScreen, .tHttp, .tFault)
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertEquals($Select($$$ISOK(tSC): tHttp, 1: 0), 200, "the screen's read answers: " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""))
    If $$$ISERR(tSC) || '$IsObject(tScreen) Quit
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a completed turn is seeded")
    Set tUse = {"type": "tool_use", "id": "toolu_sqlruntimestats"}
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName("explorer.sqlruntimestats.read"), "string")
    Do tUse.%Set("input", {"filter": (##class(OcuPilot.Test.SqlTuningProbe).#STATSTOKEN), "maxRows": 1000})
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurnKey, $Username, "", [(tUse)], ..#LIMITS, .tResults, .tNames, 0, 0, .tDetails)
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK(tSC, "the agent's read is dispatched")
    If $$$ISERR(tSC) Quit
    Set tAgent = ##class(%DynamicObject).%FromJSON(tResults.%Get(0).%Get("content"))
    Do $$$AssertEquals(tResults.%Get(0).%Get("is_error"), 0, "and answers rows")
    Set tView = ##class(OcuPilot.Screen.Read).ApplyView(tScreen.rows, ..Declaration(..#LIST).read, ##class(OcuPilot.Test.SqlTuningProbe).#STATSTOKEN)
    Do $$$AssertEquals(tView.%ToJSON(), tAgent.rows.%ToJSON(), "the rows the agent's filter keeps are the screen's rows under the same view")
    Set tRows = ..ProbeRows(tScreen)
    Kill tSeen
    Set tModules = ""
    Set tSummaries = 0
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.Module = "INFO" Set tSummaries = tSummaries + 1
        Set tSeen(tRow.Module) = ""
        Set tModules = tModules _ $ListBuild(tRow.Module)
    }
    Set tDistinct = 0
    Set tModule = ""
    For {
        Set tModule = $Order(tSeen(tModule))
        If tModule = "" Quit
        Set tDistinct = tDistinct + 1
    }
    Do $$$AssertEquals(tSummaries _ "|" _ (tRows.%Size() > 1), "1|1", "the probe holds one summary row and a row for each module of each run: " _ $ListToString(tModules))
    Do $$$AssertEquals(tRows.%Size(), $ClassMethod(..#PROBE, "StatsRowCount", ..#NAMESPACE), "and as many rows as the instance's own view counts for its statement")
    If tRows.%Size() = 0 Quit
    Set tFirst = tRows.%Get(0)
    Set tRead = ..VendorDetails(tFirst.Cursor, tFirst.Routine, .tVendor)
    Do $$$AssertEquals(tRead, tRows.%Size(), "the vendor's own details read as many rows")
    Kill tOurs
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tKey = tRow.Module _ "|" _ tRow.Runs _ "|" _ tRow.ModuleRuns _ "|" _ tRow.AverageRows _ "|" _ tRow.AverageGlobalRefs _ "|" _ tRow.AverageCommands _ "|" _ tRow.AverageDiskWait _ "|" _ tRow.AverageTime
        Set tOurs(tKey) = $Get(tOurs(tKey)) + 1
    }
    Set tAlike = 1
    Set tKey = ""
    For {
        Set tKey = $Order(tOurs(tKey))
        If tKey = "" Quit
        If $Get(tVendor(tKey)) '= tOurs(tKey) {
            Set tAlike = 0
            Do $$$AssertTrue(0, "the row " _ tKey _ " is the vendor's own: " _ $Get(tVendor(tKey)) _ " there, " _ tOurs(tKey) _ " here")
        }
    }
    Do $$$AssertTrue(tAlike, "every row's runs, module runs and averages are the vendor's own")
    Set tInfoRow = ""
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.Module = "INFO" Set tInfoRow = tRow
    }
    Do $$$AssertEquals($Select($IsObject(tInfoRow): tInfoRow.Runs _ "|" _ tInfoRow.AverageRows, 1: ""), "2|1", "the summary row counts the two runs and averages the one row each returned")
    Do $$$AssertTrue(tFirst.Statement [ ##class(OcuPilot.Test.SqlTuningProbe).#STATSTOKEN, "the row carries the statement's text")
}

/// <p>AD-35, AD-61 rule 7. The statement the list sends reads the runtime statistics view for one bound namespace, names no user, client, process or
/// parameter column, and selects every column its row map reads; the row map names exactly the fields the screen shows.</p>
/// <p>Mutation (Rule 19): add <code>UserName AS USER_NAME</code> to <parameter>OcuPilot.Port.AtelierPort.CATALOGRUNTIMESTATSQUERY</parameter> -> the excluded-column
/// assertion goes red.</p>
Method TestTheListSelectsNoIdentifyingColumn()
{
    Set tQuery = $ZConvert($Parameter(..#ATELIER, "CATALOGRUNTIMESTATSQUERY"), "U")
    Do $$$AssertTrue(tQuery [ "FROM %SYS_PTOOLS.STATSSQLVIEW WHERE NAMESPACE = ?", "it reads the runtime statistics view with the namespace bound")
    For tI = 1:1:$Length(..#EXCLUDED, ",") {
        Set tName = $Piece(..#EXCLUDED, ",", tI)
        Do $$$AssertTrue(tQuery '[ tName, "the statement names no " _ tName)
    }
    Set tColumns = $Parameter(..#ATELIER, "CATALOGRUNTIMESTATSCOLUMNS")
    Set tFields = ""
    For tI = 1:1:$Length(tColumns, ",") {
        Set tEntry = $Piece(tColumns, ",", tI)
        Set tFields = tFields _ $Select(tFields = "": "", 1: ",") _ $Piece(tEntry, ":", 1)
        Do $$$AssertTrue(tQuery [ (" AS " _ $Piece(tEntry, ":", 2) _ $Select($Piece(tEntry, ":", 2) = "STATEMENT": " FROM", 1: ",")), "the row map's " _ $Piece(tEntry, ":", 2) _ " is a column the statement selects")
    }
    Do $$$AssertEquals(tFields, ..#SELECTED, "the row map names the screen's fields and no other")
    Do $$$AssertEquals($Piece($Piece(tColumns, ",", 11), ":", 3), "sqltext", "the statement's text is masked as every statement text is")
}

/// <p>The Runtime statistics collection rows: <code>CollectionLevel</code>, <code>StopAfterMinutes</code>, <code>LevelAfterStop</code> and
/// <code>StopsAt</code> as <code>{Name, Value, Accepts, ReadOnly}</code>, equal to what the instance's flag reports, only <code>StopsAt</code> read only, and
/// the agent's <code>explorer.sqlruntimestatssettings.read</code> the screen's rows. <code>OcuPilot.Port.SqlPort</code>'s <code>STATS</code> read answers
/// the namespace's row count as the instance's own table counts it.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.ConfigPort.SqlStatsState</code> reads the stop whatever the level -> the stop rows assertion goes red where
/// collection is off; <code>STATSCOUNTQUERY</code> counts every namespace -> the count assertion goes red.</p>
Method TestTheSettingsRowsAndTheStatsCountAreTheInstancesOwn()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RecordStats", ..#NAMESPACE), "the probe's statement is run with statistics on")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#SETTINGS, "", .tScreen, .tHttp, .tFault)
    Do $$$AssertEquals($Select($$$ISOK(tSC): tHttp, 1: 0), 200, "the settings screen's read answers")
    If $$$ISERR(tSC) || '$IsObject(tScreen) Quit
    Set tCount = ##class(OcuPilot.Test.ConfigSettingRead).RowsByName(tScreen, .tRows)
    Do $$$AssertEquals(tCount, 4, "it lists four rows")
    Set tNames = ""
    Set tName = ""
    For {
        Set tName = $Order(tRows(tName))
        If tName = "" Quit
        Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tName
        Set tRow = tRows(tName)
        Do $$$AssertEquals(tRow.%Get("ReadOnly"), (tName = "StopsAt"), tName _ ": only StopsAt is read only")
    }
    Do $$$AssertEquals(tNames, "CollectionLevel,LevelAfterStop,StopAfterMinutes,StopsAt", "the rows' names")
    Do $$$AssertEquals(tRows("CollectionLevel").Accepts, "One of Off, Off with collection code, On for open and close, On for all modules.", "the level accepts the four ruled names")
    Do $$$AssertEquals(tRows("StopAfterMinutes").Accepts _ "|" _ tRows("LevelAfterStop").Accepts _ "|" _ tRows("StopsAt").Accepts, "A whole number from 1 to 99999.|One of Off, Off with collection code.|Shown here and never changed here.", "the stop, the level after it and the read-only row each state what they accept")
    Set tFlag = ##class(%SYS.PTools.StatsSQL).GetSQLStatsFlag(0, 0, .tInfo)
    Set tLevel = $Piece(tFlag, ":", 1)
    Do $$$AssertEquals(tRows("CollectionLevel").Value, $Case(tLevel, 0: "Off", 1: "Off with collection code", 2: "On for open and close", 3: "On for all modules"), "the level row is the instance's flag's level")
    If tLevel < 2 {
        Do $$$AssertEquals(tRows("StopAfterMinutes").Value _ "|" _ tRows("LevelAfterStop").Value _ "|" _ tRows("StopsAt").Value, "||", "while collection is off the stop rows read empty")
    } Else {
        Do $$$AssertEquals(tRows("StopAfterMinutes").Value, $Get(tInfo("terminate", "mins")), "while collection is on the stop reads the instance's own minutes")
        Do $$$AssertTrue($Match(tRows("StopsAt").Value, "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$") || (tRows("StopsAt").Value = ""), "and the stop's time reads as ISO-8601 UTC")
    }
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Set tUse = {"type": "tool_use", "id": "toolu_sqlruntimestatssettings"}
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName("explorer.sqlruntimestatssettings.read"), "string")
    Do tUse.%Set("input", {"maxRows": 100})
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurnKey, $Username, "", [(tUse)], ..#LIMITS, .tResults, .tNames2, 0, 0, .tDetails)
    Do $$$AssertStatusOK(tSC, "the agent's read of the settings is dispatched")
    If $$$ISOK(tSC) {
        Set tAgent = ##class(%DynamicObject).%FromJSON(tResults.%Get(0).%Get("content"))
        Do $$$AssertEquals(tAgent.rows.%ToJSON(), ##class(OcuPilot.Screen.Read).ApplyView(tScreen.rows, ..Declaration(..#SETTINGS).read, "").%ToJSON(), "the agent's rows are the screen's")
    }
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = "*"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "RuntimeStats", "STATS", .tQuery, "", .tStats, .tHttp, .tFault)
    Set tDirect = ..DirectCount(..#NAMESPACE)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tStats)): tStats.Namespace _ "|" _ tStats.Rows, 1: ""), "200|" _ ..#NAMESPACE _ "|" _ tDirect, "the STATS read answers the namespace's row count as the instance's own table counts it")
    Do $$$AssertTrue(tDirect '< $ClassMethod(..#PROBE, "StatsRowCount", ..#NAMESPACE), "and the count holds at least the probe's rows")
}

/// <p>The copy-out scripts (AD-59): the purge is its one <code>clearStatsSQL</code> call in the namespace the query names, and a collection set is its
/// one <code>SetSQLStats</code> call with the level and the stop the port would send, each value a string literal; a stop row set while collection is
/// off, or a name the roster does not settle, renders none.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.TuningSnippet</code> names <code>clearStatsSQLAllNS</code> -> the purge's script goes red.</p>
Method TestTheCopyOutScriptsAreTheirOneVendorCall()
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = "*"
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "RuntimeStats", "PURGESTATS", .tQuery)
    Do $$$AssertEquals($Select(tSteps.%Size() = 1: tSteps.%Get(0).kind _ "|" _ tSteps.%Get(0).text, 1: tSteps.%ToJSON()), "objectscript| Set $NAMESPACE = ""USER""" _ $Char(10) _ " Set tRemoved = ##class(%SYS.PTools.StatsSQL).clearStatsSQL(""USER"", """", 0, 1, 0, 1)" _ $Char(10) _ " If '$Match(tRemoved, ""^[0-9]+$"") Do $System.Status.DisplayError(tRemoved)", "the purge's script is its one vendor call")
    Do $$$AssertEquals($ClassMethod(..#PORT, "SnippetForm", "RuntimeStats", "STATS"), "", "and the count has no script")
    Kill tQuery
    Set tQuery("name") = "CollectionLevel"
    Set tSteps = $ClassMethod(..#CONFIGPORT, "Snippet", "SQLStats", "SET", .tQuery, {"Value": "On for all modules"})
    Set tText = $Select(tSteps.%Size() = 1: tSteps.%Get(0).text, 1: "")
    Do $$$AssertTrue(tText [ "##class(%SYS.PTools.StatsSQL).SetSQLStats(3, 1, """", ""M:", "a level of 3 is one SetSQLStats call with a stop: " _ tText)
    Set tQuery("name") = "StopsAt"
    Set tSteps = $ClassMethod(..#CONFIGPORT, "Snippet", "SQLStats", "SET", .tQuery, {"Value": "x"})
    Do $$$AssertEquals(tSteps.%Size(), 0, "the read-only row renders no script")
}

/// <p>The runtime statistics rows <var>pNamespace</var> holds, counted directly from the instance's own table.</p>
ClassMethod DirectCount(pNamespace As %String) As %Integer
{
    Set tCount = -1
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tSC = tStatement.%Prepare("SELECT COUNT(*) FROM %SYS_PTools.StatsSQL WHERE NameSpace = ?")
        If $$$ISOK(tSC) {
            Set tResult = tStatement.%Execute($ZConvert(pNamespace, "U"))
            If tResult.%Next() Set tCount = tResult.%GetData(1)
        }
        Set (tResult, tStatement) = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tCount
}

/// <p>The first column of the first row of <var>pText</var> run in <code>USER</code> as the caller, <code>""</code> when it answers none.</p>
ClassMethod ScalarIn(pText As %String) As %String
{
    Set tValue = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, pText)
        If tResult.%Next() Set tValue = tResult.%GetData(1)
        Set tResult = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tValue
}

/// <p>AC4. Plan with statistics on a query answers the plan with each module's statistics, which the plan without them does not, and the run's rows
/// reach the list as the instance's own view counts them. The plan without statistics records no row.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.Explained</code> ignores <var>pStats</var> -> the statistics and the recorded-rows assertions go red.</p>
Method TestPlanWithStatisticsCarriesModuleStatisticsAndRecordsItsRows()
{
    Set tPort = ..#PORT
    Set tStatement = $Parameter(..#PROBE, "QUERYSTATS")
    Set tSC = $ClassMethod(tPort, "Plan", ..#NAMESPACE, tStatement, .tPlain, .tHttp, .tFault)
    Do $$$AssertEquals($Select($$$ISOK(tSC) && $IsObject(tPlain): tPlain.%Get("outcome") _ "|" _ (tPlain.%Get("plan") [ "Stats:"), 1: ""), "plan|0", "the plan without statistics carries none")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StatsRowCount", ..#NAMESPACE), 0, "and records no row")
    Set tSC = $ClassMethod(tPort, "Plan", ..#NAMESPACE, tStatement, .tAnswer, .tHttp, .tFault, 1, [])
    Do $$$AssertStatusOK(tSC, "Plan with statistics answers")
    If $$$ISERR(tSC) || '$IsObject(tAnswer) Quit
    Do $$$AssertEquals(tAnswer.%Get("outcome") _ "|" _ tAnswer.%Get("kind"), "plan|query", "it keeps the plan outcome")
    Set tPlan = tAnswer.%Get("plan")
    Do $$$AssertTrue((tPlan [ "Module:") && (tPlan [ "Performance:") && (tPlan [ "Global Refs:") && (tPlan [ "Commands Exec:"), "the plan carries each module's statistics")
    Do $$$AssertTrue(tPlan [ "Rows Returned:  1", "and the one row the probe table holds as returned")
    Set tRecorded = $ClassMethod(..#PROBE, "StatsRowCount", ..#NAMESPACE)
    Do $$$AssertTrue(tRecorded > 1, "the run's rows are recorded: " _ tRecorded)
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#LIST, 1000, .tScreen, .tListHttp, .tListFault)
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertEquals(..ProbeRows(tScreen).%Size(), tRecorded, "and the list shows every one")
}

/// <p>AC4. Plan with statistics runs the statement, so a statement that is not a query is refused 422 <code>EXPLORER.SQL.PLANSTATS</code> with the
/// published sentence before anything runs: an UPDATE changes no row, a CREATE TABLE creates no table and no statistics row is recorded. The same
/// statements still answer their plan without statistics.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.Plan</code> skips its query-only check -> the refusal and the nothing-ran assertions go red.</p>
Method TestPlanWithStatisticsTakesAQueryOnly()
{
    Set tPort = ..#PORT
    Set tFirst = $Parameter(..#PROBE, "FIRST")
    For tText = "UPDATE " _ tFirst _ " SET B = 'y'", "CREATE TABLE OcuProbe226.Never (A INTEGER)" {
        Set tSC = $ClassMethod(tPort, "Plan", ..#NAMESPACE, tText, .tAnswer, .tHttp, .tFault, 1, [])
        Do $$$AssertEquals($Select($$$ISERR(tSC): 1, 1: 0) _ "|" _ $Get(tHttp) _ "|" _ $Select($IsObject($Get(tFault)): tFault.code _ "|" _ tFault.reason, 1: ""), "1|422|EXPLORER.SQL.PLANSTATS|" _ ##class(OcuPilot.Api.AtelierError).#REASONSQLPLANSTATS, tText _ ": refused with the published sentence")
        Do $$$AssertEquals($IsObject($Get(tAnswer)), 0, "no answer is built")
    }
    Do $$$AssertEquals(..ScalarIn("SELECT COUNT(*) FROM " _ tFirst _ " WHERE B = 'x'"), 1, "the UPDATE changed no row")
    Do $$$AssertEquals(..ScalarIn("SELECT COUNT(*) FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'OcuProbe226'"), 0, "the CREATE TABLE created nothing")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "StatsRowCount", ..#NAMESPACE), 0, "and nothing was recorded")
    Set tSC = $ClassMethod(tPort, "Plan", ..#NAMESPACE, "UPDATE " _ tFirst _ " SET B = 'y'", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Select($$$ISOK(tSC) && $IsObject(tAnswer): tAnswer.%Get("outcome") _ "|" _ tAnswer.%Get("kind"), 1: ""), "plan|dml", "without statistics the UPDATE's plan is still answered")
}

/// <p>The gates and the id shapes. A caller without <code>%Development:USE</code> is refused 403 naming the pair on the count and the purge, and one without
/// WRITE on the namespace's routines database reads and is refused the purge, the instance asked for no call; a count and a purge name <code>*</code>
/// alone, any other id is 400 <code>PORT.VALIDATION</code> and any other type 501. The collection setting's own pairs replace the settings port's:
/// a caller holding <code>%Admin_Manage:USE</code> and the system database but not <code>%Development:USE</code> is refused a read, one holding it but not
/// <code>%DB_IRISSYS:READ</code> is refused a read, and one short of <code>%DB_IRISSYS:WRITE</code> a set, before any call.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.ConfigPort.Admit</code> drops its <code>SQLSTATS</code> branch -> the pair assertions go red;
/// <code>OcuPilot.Port.SqlPort.TuningInvoke</code> drops its <code>*</code> check -> the shape assertions go red.</p>
Method TestTheGatesAndIdShapesRefuseBeforeAnyCall()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RecordStats", ..#NAMESPACE), "the probe's statement is run with statistics on")
    Set tBefore = $ClassMethod(..#PROBE, "StatsRowCount", ..#NAMESPACE)
    Set tFixture = ..#FIXTURE
    Do $ClassMethod(..#SEAM, "Deny", "USE")
    For tCase = $ListBuild("STATS"), $ListBuild("PURGESTATS") {
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("id") = "*"
        Set tSC = $ClassMethod(tFixture, "Invoke", "RuntimeStats", $List(tCase, 1), .tQuery, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code _ " " _ tFault.detail.failedPair, 1: ""), "403 " _ ##class(OcuPilot.Kernel.Denial).Code() _ " %Development:USE", $List(tCase, 1) _ ": refused naming the Explorer's pair")
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 0, "the instance was asked for no call")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Deny", "WRITE")
    For tCase = $ListBuild("STATS", 200), $ListBuild("PURGESTATS", 403) {
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("id") = "*"
        Set tSC = $ClassMethod(tFixture, "Invoke", "RuntimeStats", $List(tCase, 1), .tQuery, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertEquals(+$Get(tHttp), $List(tCase, 2), $List(tCase, 1) _ ": " _ $Select($List(tCase, 2) = 200: "a read passes without WRITE", 1: "the purge is refused without it"))
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls") _ "|" _ $ClassMethod(..#PROBE, "StatsRowCount", ..#NAMESPACE), "0|" _ tBefore, "no purge call was made and the probe's rows are still there")
    Do $ClassMethod(..#SEAM, "Reset")
    For tCase = $ListBuild("STATS", "x"), $ListBuild("STATS", ""), $ListBuild("PURGESTATS", "a b"), $ListBuild("PURGESTATS", "%sqlcq.USER.cls1"), $ListBuild("PURGESTATS", "USER") {
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("id") = $List(tCase, 2)
        Set tSC = $ClassMethod(tFixture, "Invoke", "RuntimeStats", $List(tCase, 1), .tQuery, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "400 PORT.VALIDATION", $List(tCase, 1) _ " " _ $List(tCase, 2) _ ": refused")
    }
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = "*"
    Set tSC = $ClassMethod(tFixture, "Invoke", "RuntimeStats", "LIST", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "501 PORT.NOTIMPLEMENTED", "a type the endpoint does not serve is refused")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls") _ "|" _ $ClassMethod(..#PROBE, "StatsRowCount", ..#NAMESPACE), "0|" _ tBefore, "and none of these refusals asked the instance for a call or removed a row")
    Do ..SettingsGates()
}

/// <p>The collection setting's pairs, driven through the settings port with the held set a test declares (<class>OcuPilot.Test.ScreenGate</class>).</p>
Method SettingsGates()
{
    Set tSeam = ..#CONFIGSEAM
    Set tDenial = ##class(OcuPilot.Kernel.Denial).Code()
    Set tStatus = ##class(OcuPilot.Kernel.Denial).#STATUS
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Admin_Manage", "USE")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "WRITE")
    Kill tQuery
    Set tSC = $ClassMethod(tSeam, "Invoke", "SQLStats", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.code _ "|" _ tFault.detail.failedPair, 1: ""), tStatus _ "|" _ tDenial _ "|%Development:USE", "a caller holding the settings port's own pairs but not %Development:USE is refused a read naming it")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%Development", "USE")
    Set tSC = $ClassMethod(tSeam, "Invoke", "SQLStats", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.code _ "|" _ tFault.detail.failedPair, 1: ""), tStatus _ "|" _ tDenial _ "|%DB_IRISSYS:READ", "a caller holding %Development:USE alone is refused a read naming %DB_IRISSYS:READ")
    Do ##class(OcuPilot.Test.ScreenGate).Hold("%DB_IRISSYS", "READ")
    Set tSC = $ClassMethod(tSeam, "Invoke", "SQLStats", "LIST", .tQuery, "", .tRows, .tHttp, .tFault)
    Do $$$AssertEquals(+$Get(tHttp), 200, "and one holding both read pairs reads")
    Set tQuery("name") = "CollectionLevel"
    Set tSC = $ClassMethod(tSeam, "Invoke", "SQLStats", "SET", .tQuery, {"Value": "Off"}, .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(tHttp _ "|" _ $Select($IsObject($Get(tFault)): tFault.code _ "|" _ tFault.detail.failedPair, 1: "") _ "|" _ $ClassMethod(tSeam, "Modifies"), tStatus _ "|" _ tDenial _ "|%DB_IRISSYS:WRITE|", "a set is refused naming %DB_IRISSYS:WRITE, and no call is recorded")
    Do $ClassMethod(tSeam, "Reset")
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
}

}
