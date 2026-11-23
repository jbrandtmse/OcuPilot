/// <p>Pins Story 21.25's statistics writes on both permitted callers (AC1, AC3, AC5; AD-6, AD-7, AD-10, AD-22, AD-51, AD-53, AD-56, AD-58): the collection of
/// a table's statistics, which leaves its class definition as it was, the removal of fixed statistics, and the collection of every table's in a schema, each
/// made by the screen's action and by the agent's confirmed proposal and answered only once the statistics read as the rows; the declared values reaching the
/// instance as sent; a table with no fixed statistics refused before any write; a proposal whose table changed after it was minted closed target-changed;
/// a table or schema of OcuPilot's own refused <code>PROHIBITED.OCUPILOTTABLE</code> on both callers before any write; the schema read and every hostile id
/// or value; and the Field statistics tab answering the rows of a direct bound select and the agent's read.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, which holds
/// <code>%Development:USE</code> and WRITE on <code>USER</code>'s and the install namespace's routines databases, and a <code>USER</code> namespace, where
/// each test makes <class>OcuPilot.Test.SqlTuningProbe</class>'s tables and removes them after. Each fixed statistic a test sets it removes through the same
/// tool. The own-table tests only ask for writes on OcuPilot's own table in the install namespace, which a mutation that lets one through would run. It
/// snapshots the stored governance policy before and puts it back after.</p>
Class OcuPilot.Test.SqlTableTune Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.SqlTuningProbe";

Parameter FIXTURE = "OcuPilot.Test.SqlTuningPortFixture";

Parameter SEAM = "OcuPilot.Test.SqlTuningGateSeam";

Parameter READS = "OcuPilot.Test.SqlTableRead";

Parameter HELPERS = "OcuPilot.Test.SqlIndexRebuild";

Parameter NAMESPACE = "USER";

Parameter OWNNAMESPACE = "HSCUSTOM";

Parameter OWNTABLE = "OcuPilot_Kernel_State.Convo";

Parameter OWNSCHEMA = "OcuPilot_Kernel_State";

Parameter SCHEMA = "OcuProbe225";

Parameter TUNETOOL = "OcuPilot.Screen.Tool.ExplorerSqlTableTune";

Parameter CLEARTOOL = "OcuPilot.Screen.Tool.ExplorerSqlTableClearStatistics";

Parameter SCHEMATOOL = "OcuPilot.Screen.Tool.ExplorerSqlSchemaTune";

Parameter TABLESCREEN = "explorer.sqltable";

Parameter SCHEMASCREEN = "explorer.sqlschematables";

Parameter STATISTICSDESCRIPTOR = "OcuPilot.Screen.Descriptor.ExplorerSqlFieldStatistics";

Property PreparedPolicy [ MultiDimensional ];

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do $ClassMethod(..#SEAM, "Reset")
    Kill ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Clear()
    If $$$ISERR(tSC) Quit tSC
    Kill tSettings
    For tTool = ..#TUNETOOL, ..#CLEARTOOL, ..#SCHEMATOOL {
        Set tSettings($Parameter(tTool, "TOOLNAME")) = "enabled"
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
    Do $$$AssertStatusOK(tSC, "the three statistics writes, two of whose keys ship disabled, are enabled through their stored settings")
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#NAMESPACE), "every probe object is removed")
    Do $ClassMethod(..#SEAM, "Reset")
    Kill ^||OcuPilotDatabaseWritePort
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Kill tRows
    Merge tRows = ..PreparedPolicy
    Quit ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
}

/// <p>The screen action <var>pAction</var> of screen <var>pScreen</var> on <var>pId</var> with the string values <var>pValues</var> over HTTP, as the
/// suite's account: the status, and the parsed answer in <var>pAnswer</var>.</p>
ClassMethod Act(pScreen As %String, pAction As %String, pId As %String, pValues As %DynamicObject, pNamespace As %String = {..#NAMESPACE}, Output pAnswer As %DynamicObject) As %Integer
{
    Set tBody = {"action": (pAction)}
    Do tBody.%Set("id", pId, "string")
    If $IsObject(pValues) Do tBody.%Set("values", pValues)
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/screens/" _ pScreen _ "/action?ns=" _ pNamespace, .tStatus, .pAnswer, tBody.%ToJSON())
    Quit $Select($$$ISOK(tSC): tStatus, 1: 0)
}

/// <p>The agent's proposal of <var>pTool</var> for <var>pId</var> with the arguments <var>pArgs</var> beside the target, minted and confirmed in
/// <var>pNamespace</var> through <var>pPort</var> (the tool's own where empty): <code>mint &lt;http&gt; &lt;problem&gt;</code> when the mint refused, else
/// the confirm's <code>http code</code>. The proposal is in <var>pProposal</var> and the confirm's answer in <var>pResult</var>.</p>
ClassMethod Agent(pTool As %String, pId As %String, pArgs As %DynamicObject, pNamespace As %String = {..#NAMESPACE}, Output pProposal As %DynamicObject, Output pResult As %DynamicObject, pPort As %String = "") As %String
{
    Do ##class(OcuPilot.Kernel.Scope).Set(pNamespace)
    Set ^||OcuPilotDatabaseWritePort = $Select(pPort '= "": pPort, 1: $Parameter(pTool, "PORTCLASS"))
    Set tArgs = $Select($IsObject(pArgs): pArgs, 1: {})
    Do tArgs.%Set($ClassMethod(pTool, "IdArgument"), pId, "string")
    Set tSC = $ClassMethod(..#HELPERS, "Mint", pTool, pId, tArgs, .pProposal, .tHttp, .tProblem)
    If $$$ISERR(tSC) Quit "mint " _ tHttp _ " " _ tProblem
    Quit $ClassMethod("OcuPilot.Test.LicenseProbe", "Confirm", pProposal, .pResult)
}

/// <p>The table <var>pTable</var>'s statistics as the port reads them: <code>kind size fixed</code>.</p>
ClassMethod Stats(pTable As %String) As %String
{
    Set tVerdict = $ClassMethod(..#READS, "Read", "TABLESTATS", pTable, .tAnswer, .tFault)
    If '$IsObject($Get(tAnswer)) Quit "unread " _ tVerdict
    Quit tAnswer.StatsKind _ " " _ tAnswer.ExtentSize _ " " _ tAnswer.HasFixed
}

/// <p>What the table <var>pTable</var>'s class holds that a change to the class would move, in the <code>USER</code> namespace: the time its source
/// changed, the time its compiled form records, whether it is up to date, and its storage's extent size.</p>
ClassMethod ClassState(pTable As %String) As %String
{
    Set tState = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tClass = ##class(%Dictionary.ClassDefinition).%OpenId(pTable)
        Set tCompiled = ##class(%Dictionary.CompiledClass).%OpenId(pTable)
        Set tStorage = ##class(%Dictionary.StorageDefinition).%OpenId(pTable _ "||Default")
        Set tState = tClass.TimeChanged _ "|" _ tCompiled.TimeCreated _ "|" _ $SYSTEM.OBJ.IsUpToDate(pTable) _ "|" _ $Select($IsObject(tStorage): tStorage.ExtentSize, 1: "no storage")
    } Catch ex {
        Set tState = "unread " _ ex.Name
    }
    Set $NAMESPACE = tOrigNS
    Quit tState
}

/// <p>Store a fixed extent size in <var>pTable</var>'s class definition in <code>USER</code>, through the instance's own call with the class kept up to
/// date, so the class holds a stored statistic a collection could touch.</p>
ClassMethod StoreInClass(pTable As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = ##class(%SQL.Manager.Catalog).SetTableExtentSize($Piece(pTable, ".", 1), $Piece(pTable, ".", 2), 777, 1)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>Fix the collected statistics of <var>pTable</var> in <code>USER</code>, then field <code>B</code>'s selectivity at <code>2.5%</code>, through the
/// instance's own calls.</p>
ClassMethod FixFieldB(pTable As %String) As %Status
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tSC = $SYSTEM.SQL.Stats.Table.FixTableStats(pTable)
        If $$$ISOK(tSC) Set tSC = ##class(%SQL.Manager.Catalog).SetFieldSelectivity($Piece(pTable, ".", 1), $Piece(pTable, ".", 2), "B", "2.5%", 0)
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The rows the classic join answers for <var>pTable</var> in <code>USER</code>, read directly with its schema and name bound, as
/// <var>pRows</var>(<var>field</var>) = the eight statistics joined by <code>|</code>.</p>
ClassMethod DirectRows(pTable As %String, Output pRows) As %Status
{
    Kill pRows
    Set tText = $Parameter("OcuPilot.Port.AtelierPort", "CATALOGFIELDSTATISTICSQUERY")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tSC = tStatement.%Prepare(tText)
        If $$$ISOK(tSC) {
            Set tResult = tStatement.%Execute($Piece(pTable, ".", 1), $Piece(pTable, ".", 2))
            While tResult.%Next() {
                Set pRows(tResult.%Get("FIELD_NAME")) = tResult.%Get("COLLECTED_SELECTIVITY") _ "|" _ tResult.%Get("COLLECTED_OUTLIER_VALUE") _ "|" _ tResult.%Get("COLLECTED_OUTLIER_SELECTIVITY") _ "|" _ tResult.%Get("COLLECTED_AVG_FIELD_SIZE") _ "|" _ tResult.%Get("FIXED_SELECTIVITY") _ "|" _ tResult.%Get("FIXED_OUTLIER_VALUE") _ "|" _ tResult.%Get("FIXED_OUTLIER_SELECTIVITY") _ "|" _ tResult.%Get("FIXED_AVG_FIELD_SIZE")
            }
        }
        Set tResult = ""
        Set tStatement = ""
    } Catch ex {
        Set tSC = ex.AsStatus()
    }
    Set $NAMESPACE = tOrigNS
    Quit tSC
}

/// <p>The three tools declare what the story rules: names, the one port and endpoint, request types, who reaches each, that none is destructive and none
/// sends a body, the screen action and the values each carries, the governance keys, which ship enabled for the collection and disabled for the other two,
/// the consequence codes, the precondition of the removal, and the target each takes. The cards show no state row.</p>
/// <p>Mutation (Rule 19): set <code>DESTRUCTIVE</code> 1 on the schema tune -> the destructive assertion goes red.</p>
Method TestTheToolsDeclareTheirWritePath()
{
    For tCase = $ListBuild(..#TUNETOOL, "explorer.sqltable.tune", "TABLESTATS", "TUNE", "tune", "", "SQL.TABLE.TUNE", 1), $ListBuild(..#CLEARTOOL, "explorer.sqltable.clearstatistics", "TABLESTATS", "CLEARSTATS", "clear-statistics", "", "SQL.TABLE.CLEARSTATISTICS", 0), $ListBuild(..#SCHEMATOOL, "explorer.sqlschematables.tune", "SCHEMA", "TUNESCHEMA", "tune", "tune=ClearValues", "SQL.TABLE.TUNESCHEMA", 0) {
        Set tTool = $List(tCase, 1)
        Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $ClassMethod(tTool, "PortClass") _ "|" _ $ClassMethod(tTool, "Endpoint") _ "|" _ $ClassMethod(tTool, "ReadType") _ "|" _ $ClassMethod(tTool, "WriteType"), $List(tCase, 2) _ "|OcuPilot.Port.SqlPort|Tables|" _ $List(tCase, 3) _ "|" _ $List(tCase, 4), $List(tCase, 2) _ ": name, port, endpoint and request types")
        Do $$$AssertEquals($ClassMethod(tTool, "Advertised") _ $ClassMethod(tTool, "Destructive") _ $ClassMethod(tTool, "SendsBody") _ "|" _ $ListToString($ClassMethod(tTool, "ScreenActionIds")) _ "|" _ $Parameter(tTool, "SCREENVALUES"), "100|" _ $List(tCase, 5) _ "|" _ $List(tCase, 6), $List(tCase, 2) _ ": advertised, not destructive, no body, its screen action and its values")
        Set tSeeded = ##class(OcuPilot.Kernel.Governance.Baseline).Seed($List(tCase, 2), .tListed)
        Do $$$AssertEquals(tListed _ " " _ tSeeded, "1 " _ $List(tCase, 8), $List(tCase, 2) _ ": its key is in the baseline and ships " _ $Select($List(tCase, 8): "enabled", 1: "disabled"))
        Do $$$AssertEquals($ClassMethod(tTool, "Consequence", {}), $List(tCase, 7), $List(tCase, 2) _ ": its consequence code")
        Set tPairs = $ClassMethod(tTool, "PrivilegePairs", "", .tResolved)
        Do $$$AssertTrue(tResolved && ($ListFind(tPairs, $ListBuild("%Development", "USE")) > 0), $List(tCase, 2) _ ": its pairs hold the Explorer's")
    }
    Do $$$AssertEquals($ListToString($ClassMethod(..#TUNETOOL, "SettableFields")) _ "|" _ $ListToString($ClassMethod(..#SCHEMATOOL, "SettableFields")) _ "|" _ $ListToString($ClassMethod(..#CLEARTOOL, "SettableFields")), "|ClearValues|", "the values each tool admits: the collection of a table and the removal take none")
    Set tSC = $ClassMethod(..#CLEARTOOL, "StateDiff", {"HasFixed": true}, .tRows, .tProblem)
    Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ tRows.%Size() _ "|" _ tProblem, "1|0|", "a table with fixed statistics shows no state row")
    Set tSC = $ClassMethod(..#CLEARTOOL, "StateDiff", {"HasFixed": false}, .tRows, .tProblem)
    Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ tRows.%Size() _ "|" _ tProblem, "1|0|" _ ##class(OcuPilot.Api.AtelierError).#REASONTABLENOFIXEDSTATS, "a table with none is refused with the published sentence")
    Do $$$AssertEquals($ClassMethod(..#SCHEMATOOL, "IdProblem", ..#SCHEMA) _ "|" _ ($ClassMethod(..#SCHEMATOOL, "IdProblem", "") '= "") _ "|" _ ($ClassMethod(..#SCHEMATOOL, "IdProblem", ..#SCHEMA _ $Char(7)) '= "") _ "|" _ ($ClassMethod(..#TUNETOOL, "IdProblem", ..#SCHEMA) '= ""), "|1|1|1", "the schema tool takes a schema name alone, and the table tools a table name")
    Set tSC = $ClassMethod(..#SCHEMATOOL, "ArgumentProblem", ..#SCHEMA, {"ClearValues": "true"}, .tProblem)
    Do $$$AssertTrue(tProblem '= "", "a value that is not a boolean is refused at the mint: " _ tProblem)
}

/// <p>AC3. A table's statistics are collected by the agent's confirmed proposal and by the screen's page action: the extent size reads the table's rows
/// when the confirm answers, the kind reads collected, and the read-back reads nothing sent.</p>
/// <p>Mutation (Rule 19): <code>SqlPort.TableCall</code> makes no call for <code>TUNE</code> -> both callers' assertions go red.</p>
Method TestCollectStatisticsOnBothCallers()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tFirst), "the first probe table is created")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 2, 7, .tSecond), "the second is created")
    Do $$$AssertEquals($Piece(..Stats(tFirst), " ", 1) _ "|" _ $Piece(..Stats(tSecond), " ", 1), "none|none", "no statistics are collected yet")
    Set tConfirm = ..Agent(..#TUNETOOL, tFirst, {}, , .tProposal, .tResult)
    Do $$$AssertEquals(tConfirm _ "|" _ ##class(OcuPilot.Test.EcpDataServerWrite).Verdict($Get(tResult)) _ "|" _ ..Stats(tFirst), "200 |nothingSent|collected 5 0", "the agent's collection reads the rows' count: " _ tConfirm)
    Set tStatus = ..Act(..#TABLESCREEN, "tune", tSecond, "", , .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ##class(OcuPilot.Test.EcpDataServerWrite).Verdict(tAnswer) _ "|" _ ..Stats(tSecond), "200|nothingSent|collected 7 0", "the screen's collection reads the rows' count")
}

/// <p>AC3. A collection leaves the table's class definition as it was, from both callers: the agent's confirm reaches the instance as one table tune with
/// no value, and the class's source time, the time its compiled form records, its up-to-date flag and its storage extent size are the ones they were,
/// for a class that holds a stored extent size.</p>
/// <p>Mutation (Rule 19): <code>SqlPort.TableCall</code> passes <code>1</code> for the tune's class-up-to-date argument -> the compiled-time
/// assertions go red.</p>
Method TestACollectionLeavesTheClassDefinitionAsItWas()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tTable), "the probe table is created")
    Do $$$AssertStatusOK(..StoreInClass(tTable), "the class stores a fixed extent size of 777")
    Set tBefore = ..ClassState(tTable)
    Do $$$AssertTrue(($Piece(tBefore, "|", 3) = 1) && ($Extract(tBefore, 1, 6) '= "unread") && ($Piece(tBefore, "|", 4) = 777), "the class is up to date and holds the size before: " _ tBefore)
    Set tConfirm = ..Agent(..#TUNETOOL, tTable, {}, , .tProposal, .tResult, ..#FIXTURE)
    Do $$$AssertEquals(tConfirm _ "|" _ $ClassMethod(..#SEAM, "TableCalls"), "200 |TUNE|", "the agent's collection reaches the instance as one table tune with no value: " _ tConfirm)
    Set tConfirm = ..Agent(..#TUNETOOL, tTable, {}, , .tProposal, .tResult)
    Do $$$AssertEquals(tConfirm _ "|" _ ..Stats(tTable) _ "|" _ (..ClassState(tTable) = tBefore), "200 |fixed 777 1|1", "the real collection keeps the fixed size and the class as it was: " _ tConfirm _ " " _ ..ClassState(tTable))
    Set tStatus = ..Act(..#TABLESCREEN, "tune", tTable, "", , .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ (..ClassState(tTable) = tBefore), "200|1", "and the screen's collection leaves the class as it was")
}

/// <p>AC3. Fixed statistics are removed by the agent's confirmed proposal and by the screen's action, each leaving the table with none; a table with none
/// is refused with the published sentence for both callers before any write, the agent's through the instrumented port, which counts no call.</p>
/// <p>Mutation (Rule 19): <code>SqlPort.TableCall</code> makes no call for <code>CLEARSTATS</code> -> the fixed flag stays and the assertions go red.</p>
Method TestFixedStatisticsAreClearedOnBothCallersAndATableWithNoneIsRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tFirst), "the first probe table is created")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 2, 5, .tSecond), "the second is created")
    Do $ClassMethod(..#READS, "Statistics", "collect", tFirst)
    Do $ClassMethod(..#READS, "Statistics", "collect", tSecond)
    Do $ClassMethod(..#READS, "Statistics", "fix", tFirst)
    Do $ClassMethod(..#READS, "Statistics", "fix", tSecond)
    Do $$$AssertEquals(..Stats(tFirst) _ "|" _ ..Stats(tSecond), "fixed 777 1|fixed 777 1", "both tables hold a fixed size")
    Set tConfirm = ..Agent(..#CLEARTOOL, tFirst, {}, , .tProposal, .tResult)
    Do $$$AssertEquals(tConfirm _ "|" _ $Piece(..Stats(tFirst), " ", 3) _ "|" _ ($Piece(..Stats(tFirst), " ", 1) '= "fixed"), "200 |0|1", "the agent's removal leaves the first table with none: " _ tConfirm)
    Set tStatus = ..Act(..#TABLESCREEN, "clear-statistics", tSecond, "", , .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $Piece(..Stats(tSecond), " ", 3), "200|0", "the screen's removal leaves the second with none")
    Set tSentence = ##class(OcuPilot.Api.AtelierError).#REASONTABLENOFIXEDSTATS
    Set tStatus = ..Act(..#TABLESCREEN, "clear-statistics", tFirst, "", , .tAnswer)
    Do $$$AssertEquals($ClassMethod(..#HELPERS, "Verdict", tStatus, tAnswer) _ "|" _ $ClassMethod(..#HELPERS, "Problem", tAnswer), "400 TOOL.ARGUMENTS|" _ tSentence, "the screen's removal from a table with none is refused with its sentence")
    Set tConfirm = ..Agent(..#CLEARTOOL, tFirst, {}, , .tProposal, .tResult, ..#FIXTURE)
    Do $$$AssertEquals(tConfirm _ "|" _ $ClassMethod(..#SEAM, "Calls"), "mint 400 " _ tSentence _ "|0", "and so is the agent's, with no call made")
}

/// <p>AC3. Every table of a schema is collected by the agent's confirmed proposal and by the screen's page action: with the fixed values kept
/// (<code>ClearValues</code> false) a table's fixed size stays, and with them cleared it goes. The two tables' extent sizes read their rows.</p>
/// <p>Mutation (Rule 19): <code>SqlPort.TableCall</code> passes <code>0</code> for <code>ClearValues</code> -> the cleared assertion goes red;
/// it passes <code>1</code> for the schema tune's class-up-to-date argument -> the class-state assertion goes red.</p>
Method TestASchemasTablesAreTunedOnBothCallers()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 3, .tFirst), "the first probe table is created")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 2, 6, .tSecond), "the second is created")
    Set tConfirm = ..Agent(..#SCHEMATOOL, ..#SCHEMA, {"ClearValues": false}, , .tProposal, .tResult, ..#FIXTURE)
    Do $$$AssertEquals(tConfirm _ "|" _ ##class(OcuPilot.Test.EcpDataServerWrite).Verdict($Get(tResult)) _ "|" _ $ClassMethod(..#SEAM, "TableCalls") _ "|" _ ..Stats(tFirst) _ "|" _ ..Stats(tSecond), "200 |nothingSent|TUNESCHEMA|0|collected 3 0|collected 6 0", "the agent's tune of the schema reads both tables' rows, with the value as sent: " _ tConfirm)
    Do $ClassMethod(..#READS, "Statistics", "fix", tFirst)
    Do $$$AssertStatusOK(..StoreInClass(tFirst), "the first table's class stores a fixed extent size of 777")
    Set tBefore = ..ClassState(tFirst)
    Set tStatus = ..Act(..#SCHEMASCREEN, "tune", ..#SCHEMA, {"ClearValues": "false"}, , .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..Stats(tFirst), "200|fixed 777 1", "the screen's tune with the fixed values kept leaves the fixed size")
    Do $$$AssertTrue(($Extract(tBefore, 1, 6) '= "unread") && (..ClassState(tFirst) = tBefore), "and leaves the class as it was: " _ ..ClassState(tFirst) _ " from " _ tBefore)
    Set tStatus = ..Act(..#SCHEMASCREEN, "tune", ..#SCHEMA, {"ClearValues": "true"}, , .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ##class(OcuPilot.Test.EcpDataServerWrite).Verdict(tAnswer) _ "|" _ $Piece(..Stats(tFirst), " ", 3) _ "|" _ $Piece(..Stats(tSecond), " ", 2), "200|nothingSent|0|6", "and with them cleared the fixed size goes and the other table still reads its rows")
}

/// <p>AC3. The table's Info tab and the schema's Tables tab declare the command aliases the story rules, and no other: "table statistics" is not one.</p>
/// <p>Mutation (Rule 19): add <code>"table statistics"</code> to <class>OcuPilot.Screen.Descriptor.ExplorerSqlSchema</class>'s <code>commandAliases</code>
/// -> the schema assertion goes red.</p>
Method TestTheTabsDeclareOnlyTheirRuledCommandAliases()
{
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Screen.Descriptor.ExplorerSqlTable", "DeclarationJson", .tTable), "the table's declaration parses")
    Do $$$AssertStatusOK($ClassMethod("OcuPilot.Screen.Descriptor.ExplorerSqlSchema", "DeclarationJson", .tSchema), "the schema's declaration parses")
    If '$IsObject($Get(tTable)) || '$IsObject($Get(tSchema)) Quit
    Do $$$AssertEquals(tTable.commandAliases.%ToJSON(), "[""rebuild indices"",""tune table""]", "the table's aliases")
    Do $$$AssertEquals(tSchema.commandAliases.%ToJSON(), "[""tune table""]", "the schema's aliases")
}

/// <p>A proposal whose table's statistics were collected after it was minted, and one whose schema gained a table after it was minted, are refused
/// <code>PROPOSAL.TARGETCHANGED</code> at their confirm, and nothing is collected.</p>
/// <p>Mutation (Rule 19): the table tool's <code>FINGERPRINTSUBJECT</code> drops <code>CollectedAt</code> and <code>StatsKind</code> -> the first confirm is
/// not refused and goes red.</p>
Method TestAChangedTargetIsRefusedTargetChanged()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tTable), "the probe table is created")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set ^||OcuPilotDatabaseWritePort = $Parameter(..#TUNETOOL, "PORTCLASS")
    Set tSC = $ClassMethod(..#HELPERS, "Mint", ..#TUNETOOL, tTable, {"Table": (tTable)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the proposal is minted: " _ $Get(tProblem))
    If '$IsObject($Get(tProposal)) Quit
    Do $ClassMethod(..#READS, "Statistics", "collect", tTable)
    Set tConfirm = $ClassMethod("OcuPilot.Test.LicenseProbe", "Confirm", tProposal, .tResult)
    Do $$$AssertEquals(tConfirm, "409 PROPOSAL.TARGETCHANGED", "the confirm after the statistics were collected is refused target-changed: " _ tConfirm)
    Set tSC = $ClassMethod(..#HELPERS, "Mint", ..#SCHEMATOOL, ..#SCHEMA, {"Schema": (..#SCHEMA), "ClearValues": false}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the schema's proposal is minted: " _ $Get(tProblem))
    If '$IsObject($Get(tProposal)) Quit
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 2, 4, .tOther), "a second table joins the schema")
    Set tConfirm = $ClassMethod("OcuPilot.Test.LicenseProbe", "Confirm", tProposal, .tResult)
    Do $$$AssertEquals(tConfirm _ "|" _ $Piece(..Stats(tOther), " ", 1), "409 PROPOSAL.TARGETCHANGED|none", "the schema's confirm is refused too, and the new table is not collected")
}

/// <p>AC5. A table of OcuPilot's own, <code>OcuPilot_Kernel_State.Convo</code>, and the schema it lies in are refused <code>PROHIBITED.OCUPILOTTABLE</code>
/// with the published sentence by the screen's three actions and by the agent's three confirmed proposals, before any write: the agent's run through the
/// instrumented port, which counts no vendor call.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Screen.Tool.SqlTableAction.RefusedBeforeState</code> answers 0 -> the clear-statistics assertions go red on both
/// callers, the table having no fixed statistics to refuse first. The schema branch of
/// <code>OcuPilot.Kernel.Proposal.Prohibited.TableEntry</code> is <class>OcuPilot.Test.Prohibited</class>'s.</p>
Method TestATableAndASchemaOfOcuPilotsOwnAreRefusedOnBothCallers()
{
    Set tReason = ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor("PROHIBITED.OCUPILOTTABLE")
    For tCase = $ListBuild(..#TABLESCREEN, "tune", ..#OWNTABLE, "{}"), $ListBuild(..#TABLESCREEN, "clear-statistics", ..#OWNTABLE, "{}"), $ListBuild(..#SCHEMASCREEN, "tune", ..#OWNSCHEMA, "{""ClearValues"":""false""}") {
        Set tStatus = ..Act($List(tCase, 1), $List(tCase, 2), $List(tCase, 3), ##class(%DynamicAbstractObject).%FromJSON($List(tCase, 4)), ..#OWNNAMESPACE, .tAnswer)
        Do $$$AssertEquals($ClassMethod(..#HELPERS, "Verdict", tStatus, tAnswer) _ "|" _ $Select($IsObject(tAnswer): tAnswer.reason, 1: ""), "403 PROHIBITED.OCUPILOTTABLE|" _ tReason, "the screen's " _ $List(tCase, 2) _ " of " _ $List(tCase, 3) _ " is refused with the published sentence")
    }
    For tCase = $ListBuild(..#TUNETOOL, ..#OWNTABLE, "{}"), $ListBuild(..#CLEARTOOL, ..#OWNTABLE, "{}"), $ListBuild(..#SCHEMATOOL, ..#OWNSCHEMA, "{""ClearValues"":false}") {
        Set tConfirm = ..Agent($List(tCase, 1), $List(tCase, 2), ##class(%DynamicAbstractObject).%FromJSON($List(tCase, 3)), ..#OWNNAMESPACE, .tProposal, .tResult, ..#FIXTURE)
        Do $$$AssertTrue(tConfirm [ "PROHIBITED.OCUPILOTTABLE", "the agent's " _ $Parameter($List(tCase, 1), "TOOLNAME") _ " of " _ $List(tCase, 2) _ " is refused: " _ tConfirm)
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 0, "no vendor call was made for OcuPilot's own table or schema")
}

/// <p>AC3. The port's <code>SCHEMA</code> read answers <code>{Namespace, Schema, Tables, ClearValues}</code>, the schema spelled as the
/// instance holds it whatever case the caller used and the base tables the caller sees counted, the value <code>null</code>. A schema that shows
/// no table is 404 <code>PORT.NOTFOUND</code>, a name outside the schema shape and a missing or non-boolean value are 400 <code>PORT.VALIDATION</code>,
/// each before any call.</p>
/// <p>Mutation (Rule 19): <code>SqlPort.SchemaServe</code> reads no row as a table count of 0 instead of refusing -> the absent-schema assertion goes red.</p>
Method TestTheSchemaIsReadAndEveryHostileIdOrValueIsRefusedBeforeAnyCall()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 2, .tFirst), "the first probe table is created")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 2, 2, .tSecond), "the second is created")
    Set tVerdict = $ClassMethod(..#READS, "Read", "SCHEMA", $ZConvert(..#SCHEMA, "L"), .tAnswer, .tFault)
    Do $$$AssertEquals(tVerdict, "200 ", "the read answers")
    If '$IsObject($Get(tAnswer)) Quit
    Do $$$AssertEquals(tAnswer.Namespace _ "|" _ tAnswer.Schema _ "|" _ tAnswer.Tables _ "|" _ tAnswer.%GetTypeOf("Tables") _ "|" _ tAnswer.%GetTypeOf("ClearValues"), "USER|" _ ..#SCHEMA _ "|2|number|null", "the schema as the instance spells it, its two tables and the null value")
    Set tVerdict = $ClassMethod(..#READS, "Read", "SCHEMA", "OcuProbe225Absent", .tAnswer, .tFault)
    Do $$$AssertEquals(tVerdict _ "|" _ tFault.reason, "404 PORT.NOTFOUND|" _ ##class(OcuPilot.Port.AtelierPort).#REASONCATALOGNOTFOUND, "a schema that shows no table is not found")
    For tId = "", $Translate($Justify("", 129), " ", "a"), ..#SCHEMA _ $Char(7) {
        Set tVerdict = $ClassMethod(..#READS, "Read", "SCHEMA", tId, .tAnswer, .tFault)
        Do $$$AssertEquals(tVerdict _ "|" _ tFault.reason, "400 PORT.VALIDATION|" _ ##class(OcuPilot.Port.AtelierPort).#REASONCATALOGSCHEMA, "a schema id outside the shape is refused: '" _ $Extract($Translate(tId, $Char(7), "!"), 1, 12) _ "'")
    }
    For tCase = $ListBuild("TUNESCHEMA", ..#SCHEMA, ""), $ListBuild("TUNESCHEMA", ..#SCHEMA, "ClearValues=yes"), $ListBuild("TUNESCHEMA", ..#SCHEMA, "ClearValues=1") {
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("id") = $List(tCase, 2)
        For tI = 1:1:$Length($List(tCase, 3), ",") {
            If $Piece($Piece($List(tCase, 3), ",", tI), "=", 1) '= "" Set tQuery($Piece($Piece($List(tCase, 3), ",", tI), "=", 1)) = $Piece($Piece($List(tCase, 3), ",", tI), "=", 2)
        }
        Set tSC = $ClassMethod(..#FIXTURE, "Invoke", "Tables", $List(tCase, 1), .tQuery, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code _ "|" _ tFault.reason, 1: ""), "400 PORT.VALIDATION|" _ ##class(OcuPilot.Api.Error).#REASONPORTFIELDSHAPE, $List(tCase, 1) _ " with '" _ $List(tCase, 3) _ "' is refused")
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 0, "the instance was asked for no write")
}

/// <p>Each statistics write's script (AD-59) is its one vendor call with the target shown as a string literal, so a name that holds a quote never runs
/// as code, and the values it was sent.</p>
/// <p>Mutation (Rule 19): <code>SqlPort.TableSnippet</code> renders <code>0</code> for the schema tune's <code>ClearValues</code> -> the value assertion
/// goes red; renders <code>1</code> for the table tune's class-up-to-date argument -> the table tune's assertion goes red.</p>
Method TestEachStatisticsWritesScriptIsItsOneVendorCall()
{
    Set tPort = ..#FIXTURE
    Do $$$AssertEquals($ClassMethod(tPort, "SnippetForm", "Tables", "TUNE") _ "|" _ $ClassMethod(tPort, "SnippetForm", "Tables", "CLEARSTATS") _ "|" _ $ClassMethod(tPort, "SnippetForm", "Tables", "TUNESCHEMA") _ "|" _ $ClassMethod(tPort, "SnippetForm", "Tables", "SCHEMA"), "objectscript|objectscript|objectscript|", "the three writes have a script and the read none")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = "OcuProbe225.T""1"
    Set tScript = $ClassMethod(tPort, "Snippet", "Tables", "TUNE", .tQuery).%Get(0).%Get("text")
    Do $$$AssertTrue(tScript [ "TuneTable(""OcuProbe225.T""""1"", 1, 0, .tMessage, 0, 0)", "the table tune: its table with the quote doubled, display off and the class left as it is: " _ tScript)
    Set tScript = $ClassMethod(tPort, "Snippet", "Tables", "CLEARSTATS", .tQuery).%Get(0).%Get("text")
    Do $$$AssertTrue(tScript [ "ClearTableStats(""OcuProbe225.T""""1"")", "the removal of fixed statistics: " _ tScript)
    Set tQuery("id") = "OcuProbe225"
    Set tQuery("ClearValues") = "true"
    Set tScript = $ClassMethod(tPort, "Snippet", "Tables", "TUNESCHEMA", .tQuery).%Get(0).%Get("text")
    Do $$$AssertTrue(tScript [ "TuneSchema(""OcuProbe225"", 1, 0, .tMessage, 0, 1)", "the schema tune: the class left as it is and the value sent: " _ tScript)
}

/// <p>AC1. The Field statistics tab's rows and the agent's <code>explorer.sqlfieldstatistics.read</code> are one: each field's collected and fixed
/// selectivity, outlier value and outlier selectivity and average size, equal to the rows of the classic window's join read directly with its table
/// bound. A field with a fixed selectivity shows it beside the collected one.</p>
/// <p>Mutation (Rule 19): <code>AtelierPort.CATALOGFIELDSTATISTICSCOLUMNS</code> drops <code>FixedSelectivity</code> -> the fixed assertions go red.</p>
Method TestTheFieldStatisticsTabAndTheAgentsReadAnswerTheDirectRows()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tTable), "the probe table is created")
    Do $ClassMethod(..#READS, "Statistics", "collect", tTable)
    Do $$$AssertStatusOK(..FixFieldB(tTable), "the collected statistics are fixed and field B's selectivity is fixed at 2.5%")
    Kill tDirect
    Do $$$AssertStatusOK(..DirectRows(tTable, .tDirect), "the classic join prepares and runs with the table bound")
    Do $$$AssertTrue(($Data(tDirect("A")) > 0) && ($Data(tDirect("B")) > 0) && ($Data(tDirect("C")) > 0), "it answers a row for each of the table's fields")
    Do $$$AssertTrue($Piece($Get(tDirect("B")), "|", 5) '= "", "and field B's fixed selectivity is there: " _ $Get(tDirect("B")))
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tCriteria("table") = tTable
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#STATISTICSDESCRIPTOR, 100, .tScreen, .tHttp, .tFault, .tCriteria)
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertEquals($Select($$$ISOK(tSC): tHttp, 1: 0), 200, "the tab's read answers: " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""))
    If $$$ISERR(tSC) || '$IsObject(tScreen) Quit
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a completed turn is seeded")
    Set tUse = {"type": "tool_use", "id": "toolu_sqlfieldstatistics"}
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName("explorer.sqlfieldstatistics.read"), "string")
    Do tUse.%Set("input", {"table": (tTable), "maxRows": 100})
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurnKey, $Username, "", [(tUse)], "OcuPilot.Kernel.Agent.Limits", .tResults, .tNames, 0, 0, .tDetails)
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $$$AssertStatusOK(tSC, "the agent's read is dispatched")
    If $$$ISERR(tSC) Quit
    Set tAgent = ##class(%DynamicObject).%FromJSON(tResults.%Get(0).%Get("content"))
    Do $$$AssertEquals(tResults.%Get(0).%Get("is_error"), 0, "and answers rows")
    Do $$$AssertEquals(tScreen.rows.%ToJSON(), tAgent.rows.%ToJSON(), "the tab's rows and the agent's are one")
    Set tIterator = tScreen.rows.%GetIterator()
    Set tSeen = 0
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set tSeen = tSeen + 1
        Set tShown = tRow.Selectivity _ "|" _ tRow.OutlierValue _ "|" _ tRow.OutlierSelectivity _ "|" _ tRow.AverageFieldSize _ "|" _ tRow.FixedSelectivity _ "|" _ tRow.FixedOutlierValue _ "|" _ tRow.FixedOutlierSelectivity _ "|" _ tRow.FixedAverageFieldSize
        Do $$$AssertEquals(tShown, $Get(tDirect(tRow.Field)), "field " _ tRow.Field _ " reads what the direct select reads")
        If tRow.Field = "B" {
            Do $$$AssertEquals(tRow.FixedSelectivity _ "|" _ tRow.Selectivity, "2.5000%|20.0000%", "field B shows its fixed selectivity under the fixed heading and the collected one under its own: " _ tShown)
        } ElseIf tRow.Field '= "ID" {
            Do $$$AssertEquals(tRow.FixedSelectivity, tRow.Selectivity, "field " _ tRow.Field _ " was fixed from its collected selectivity: " _ tShown)
        }
    }
    Do $$$AssertTrue(tSeen >= 3, "the tab shows each field: " _ tSeen)
    Do $$$AssertEquals($ClassMethod(..#READS, "Declaration", ..#STATISTICSDESCRIPTOR).tab.position _ "|" _ $ClassMethod(..#READS, "Declaration", ..#STATISTICSDESCRIPTOR).entityType _ "|" _ $ClassMethod(..#READS, "Declaration", ..#STATISTICSDESCRIPTOR).rowActions.%Size(), "10|class|0", "the tab is the tenth, a read of the class entity with no row action")
}

}
