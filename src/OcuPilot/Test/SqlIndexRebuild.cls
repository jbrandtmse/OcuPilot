/// <p>Pins Story 21.25's index rebuilds on both permitted callers (AC2, AC5; AD-6, AD-7, AD-10, AD-22, AD-51, AD-53, AD-58): one index and every index
/// of a table rebuilt by the screen's action and by the agent's confirmed proposal, each answered only once the index holds every row again and
/// each read back as nothing sent; the table's data map refused before any write; a proposal whose table's statistics changed after it was minted
/// closed target-changed; the instance's own refusal answered 409 <code>SQL.TABLE.VENDOR</code> with its message in <code>detail</code> alone; and a
/// table of OcuPilot's own refused <code>PROHIBITED.OCUPILOTTABLE</code> on both callers, before any write.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, which holds
/// <code>%Development:USE</code> and WRITE on <code>USER</code>'s and the install namespace's routines databases, and a <code>USER</code> namespace,
/// where each test makes <class>OcuPilot.Test.SqlTuningProbe</class>'s table and removes it after. The own-table test only asks for rebuilds of
/// OcuPilot's own table in the install namespace, which a mutation that lets the write through would run. It snapshots the stored governance policy
/// before and puts it back after.</p>
Class OcuPilot.Test.SqlIndexRebuild Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.SqlTuningProbe";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter FIXTURE = "OcuPilot.Test.SqlTuningPortFixture";

Parameter SEAM = "OcuPilot.Test.SqlTuningGateSeam";

Parameter NAMESPACE = "USER";

Parameter OWNNAMESPACE = "HSCUSTOM";

Parameter OWNTABLE = "OcuPilot_Kernel_State.Convo";

Parameter INDEXTOOL = "OcuPilot.Screen.Tool.ExplorerSqlIndexRebuild";

Parameter TABLETOOL = "OcuPilot.Screen.Tool.ExplorerSqlTableRebuildIndices";

Parameter INDEXSCREEN = "explorer.sqlindices";

Parameter TABLESCREEN = "explorer.sqltable";

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
    Set tSettings($Parameter(..#INDEXTOOL, "TOOLNAME")) = "enabled"
    Set tSettings($Parameter(..#TABLETOOL, "TOOLNAME")) = "enabled"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
    Do $$$AssertStatusOK(tSC, "the two rebuilds, whose keys ship disabled, are enabled through their stored settings")
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

/// <p>The screen action <var>pAction</var> of screen <var>pScreen</var> on <var>pId</var> over HTTP, in namespace <var>pNamespace</var>, as the suite's
/// account: the status, and the parsed answer in <var>pAnswer</var>.</p>
ClassMethod Act(pScreen As %String, pAction As %String, pId As %String, pNamespace As %String = {..#NAMESPACE}, Output pAnswer As %DynamicObject) As %Integer
{
    Set tBody = {"action": (pAction)}
    Do tBody.%Set("id", pId, "string")
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/screens/" _ pScreen _ "/action?ns=" _ pNamespace, .tStatus, .pAnswer, tBody.%ToJSON())
    Quit $Select($$$ISOK(tSC): tStatus, 1: 0)
}

/// <p>The status and refusal code an answer carries, as <code>status code</code>.</p>
ClassMethod Verdict(pStatus As %Integer, pAnswer As %DynamicObject) As %String
{
    Quit pStatus _ " " _ $Select($IsObject(pAnswer): pAnswer.%Get("code"), 1: "")
}

/// <p>The refusal sentence an answer carries in <code>detail.problem</code>, or <code>""</code>.</p>
ClassMethod Problem(pAnswer As %DynamicObject) As %String
{
    Quit $Select($IsObject(pAnswer) && $IsObject(pAnswer.detail): pAnswer.detail.problem, 1: "")
}

/// <p>The agent's proposal of table tool <var>pTool</var> for <var>pTable</var>, and, for the index tool, <var>pMap</var>, minted and confirmed in
/// <var>pNamespace</var> through <var>pPort</var>: <code>mint &lt;http&gt; &lt;problem&gt;</code> when the mint refused, else the confirm's
/// <code>http code</code>. The proposal is in <var>pProposal</var> and the confirm's answer in <var>pResult</var>.</p>
ClassMethod Agent(pTool As %String, pTable As %String, pMap As %String = "", pNamespace As %String = {..#NAMESPACE}, Output pProposal As %DynamicObject, Output pResult As %DynamicObject, pPort As %String = "") As %String
{
    Do ##class(OcuPilot.Kernel.Scope).Set(pNamespace)
    Set ^||OcuPilotDatabaseWritePort = $Select(pPort '= "": pPort, 1: $Parameter(pTool, "PORTCLASS"))
    Set tArgs = {}
    Do tArgs.%Set("Table", pTable, "string")
    If pMap '= "" Do tArgs.%Set("Map", pMap, "string")
    Set tSC = ..Mint(pTool, $Select(pMap '= "": pMap, 1: pTable), tArgs, .pProposal, .tHttp, .tProblem)
    If $$$ISERR(tSC) Quit "mint " _ tHttp _ " " _ tProblem
    Quit $ClassMethod(..#AGENT, "Confirm", pProposal, .pResult)
}

/// <p>Mint <var>pTool</var>'s proposal for <var>pName</var> from <var>pArgs</var> through the mint the tool declares
/// (<method>OcuPilot.Screen.Tool.Write.MintClass</method>), as the agent's dispatch does, over a completed turn: <var>pProposal</var> is
/// <code>""</code> when the mint refused, with its problem in <var>pProblem</var>.</p>
ClassMethod Mint(pTool As %String, pName As %String, pArgs As %DynamicObject, Output pProposal As %DynamicObject, Output pHttp As %Integer, Output pProblem As %String) As %Status
{
    Set pProposal = ""
    Set pHttp = 0
    Set pProblem = ""
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod($ClassMethod(pTool, "MintClass"), "Mint", $Parameter(pTool, "DESCRIPTORCLASS"), $Parameter(pTool, "TOOLNAME"), $Username, "", tTurnKey, pArgs, "OcuPilot.Kernel.Agent.Limits", .tResult, .pHttp, .tFault, $ClassMethod(pTool, "Endpoint"), $ClassMethod(pTool, "IdParam"), pName, $ClassMethod(pTool, "IdArgument"), $ClassMethod(pTool, "SettableFields"), pTool)
    If $IsObject($Get(tResult)) Set pProposal = tResult
    If $IsObject($Get(tFault)) && $IsObject(tFault.%Get("detail")) Set pProblem = tFault.%Get("detail").%Get("problem")
    If $IsObject($Get(tFault)) && (pProblem = "") Set pProblem = tFault.%Get("code")
    If '$IsObject(pProposal) Quit $$$ERROR($$$GeneralError, "the mint answered no proposal: " _ pHttp _ " " _ pProblem)
    Quit $$$OK
}

/// <p>The composite id of index <var>pMap</var> of <var>pTable</var>, as the indices rows key it.</p>
ClassMethod IndexId(pTable As %String, pMap As %String) As %String
{
    Quit pTable _ $Char(1) _ pMap
}

/// <p>The entries of the probe table's two indices, as <code>IdxB|IdxC</code>, counted in their globals.</p>
ClassMethod Entries(pTable As %String) As %String
{
    Quit $ClassMethod(..#PROBE, "IndexEntries", ..#NAMESPACE, pTable, "IdxB") _ "|" _ $ClassMethod(..#PROBE, "IndexEntries", ..#NAMESPACE, pTable, "IdxC")
}

/// <p>The first index of <var>pTable</var> in <var>pNamespace</var> that is not the data map, read as the indices tab reads it, or <code>""</code>.</p>
ClassMethod OwnMap(pNamespace As %String, pTable As %String) As %String
{
    Set tMap = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tSC = tStatement.%PrepareClassQuery("%SQL.Manager.Catalog", "Indices")
        Set tResult = tStatement.%Execute($Piece(pTable, ".", 1), $Piece(pTable, ".", 2))
        While tResult.%Next() {
            If tResult.%Get("TYPE") '[ "Data" Set tMap = tResult.%Get("SQL_MAP_NAME") Quit
        }
        Set tResult = ""
        Set tStatement = ""
    } Catch {
    }
    Set $NAMESPACE = tOrigNS
    Quit tMap
}

/// <p>The two tools declare what the story rules: names, the one port, endpoint, request types, who reaches each, that neither is destructive and
/// neither sends a body, the screen action each carries, the governance keys, which ship disabled, the consequence codes, and the pairs each
/// requires, the classic SQL page's resource among them. An id is accepted only in its tool's shape.</p>
/// <p>Neither card shows a state row, and the data map's refusal is the one sentence <method>StateDiff</method> answers.</p>
/// <p>Mutation (Rule 19): set <code>DESTRUCTIVE</code> 1 on the index rebuild -> the destructive assertion goes red. Delete the
/// <method>StateDiff</method> override of <class>OcuPilot.Screen.Tool.SqlTableAction</class> -> the state-row assertions go red.</p>
Method TestTheToolsDeclareTheirWritePath()
{
    Set tSeparator = $Char(1)
    For tCase = $ListBuild(..#INDEXTOOL, "explorer.sqlindices.rebuild", "INDEX", "REBUILD", "rebuild", "SQL.TABLE.REBUILD"), $ListBuild(..#TABLETOOL, "explorer.sqltable.rebuildindices", "TABLESTATS", "REBUILDALL", "rebuild-indices", "SQL.TABLE.REBUILDALL") {
        Set tTool = $List(tCase, 1)
        Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $ClassMethod(tTool, "PortClass") _ "|" _ $ClassMethod(tTool, "Endpoint") _ "|" _ $ClassMethod(tTool, "ReadType") _ "|" _ $ClassMethod(tTool, "WriteType"), $List(tCase, 2) _ "|OcuPilot.Port.SqlPort|Tables|" _ $List(tCase, 3) _ "|" _ $List(tCase, 4), $List(tCase, 2) _ ": name, port, endpoint and request types")
        Do $$$AssertEquals($ClassMethod(tTool, "Advertised") _ $ClassMethod(tTool, "Destructive") _ $ClassMethod(tTool, "SendsBody") _ "|" _ $ListToString($ClassMethod(tTool, "ScreenActionIds")), "100|" _ $List(tCase, 5), $List(tCase, 2) _ ": advertised, not destructive, no body, one screen action")
        Set tSeeded = ##class(OcuPilot.Kernel.Governance.Baseline).Seed($List(tCase, 2), .tListed)
        Do $$$AssertEquals(tListed _ " " _ tSeeded, "1 0", $List(tCase, 2) _ ": its key is in the baseline and ships disabled")
        Do $$$AssertEquals($ClassMethod(tTool, "Consequence", {}), $List(tCase, 6), $List(tCase, 2) _ ": its consequence code")
        Set tPairs = $ClassMethod(tTool, "PrivilegePairs", "", .tResolved)
        Do $$$AssertTrue(tResolved && ($ListFind(tPairs, $ListBuild("%Development", "USE")) > 0), $List(tCase, 2) _ ": its pairs hold the Explorer's")
    }
    For tTool = ..#INDEXTOOL, ..#TABLETOOL {
        Set tSC = $ClassMethod(tTool, "StateDiff", {"Type": "Index", "Map": "IdxB"}, .tRows, .tProblem)
        Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ tRows.%Size() _ "|" _ tProblem _ "|" _ $ClassMethod(tTool, "StateField") _ "|" _ $Parameter(tTool, "STATEAFTER"), "1|0|||", tTool _ ": a rebuild that can run shows no state row")
    }
    Set tSC = $ClassMethod(..#INDEXTOOL, "StateDiff", {"Type": "Data", "Map": "IDKEY"}, .tRows, .tProblem)
    Do $$$AssertEquals($$$ISOK(tSC) _ "|" _ tRows.%Size() _ "|" _ tProblem, "1|0|" _ ##class(OcuPilot.Api.AtelierError).#REASONTABLEDATAMAP, "the data map is refused with its sentence and no state row")
    Do $$$AssertEquals($ClassMethod(..#TABLETOOL, "IdProblem", "OcuProbe225.T1") _ "|" _ ($ClassMethod(..#TABLETOOL, "IdProblem", "NoDot") '= "") _ "|" _ ($ClassMethod(..#TABLETOOL, "IdProblem", ..IndexId("OcuProbe225.T1", "IdxB")) = ""), "|1|0", "the table tool takes a table name alone, and an index's composite id is not one")
    Do $$$AssertEquals($ClassMethod(..#INDEXTOOL, "IdProblem", ..IndexId("OcuProbe225.T1", "IdxB")) _ "|" _ ($ClassMethod(..#INDEXTOOL, "IdProblem", "OcuProbe225.T1") '= "") _ "|" _ ($ClassMethod(..#INDEXTOOL, "IdProblem", tSeparator _ "IdxB") '= "") _ "|" _ ($ClassMethod(..#INDEXTOOL, "IdProblem", ..IndexId("NoDot", "IdxB")) '= ""), "|1|1|1", "the index tool takes the composite [Table, Map] alone")
    Do $$$AssertEquals($ClassMethod(..#INDEXTOOL, "MintClass"), "OcuPilot.Screen.Tool.SqlIndexMint", "the index rebuild builds its composite id through its mint")
}

/// <p>AC2. One index is rebuilt by the agent's confirmed proposal and by the screen's row action: with both indices' globals killed, the confirm
/// answers only once the named index holds every row again, a query through it returns them, and the other index is untouched, still empty. Each
/// answer's read-back reads <code>nothingSent</code>.</p>
/// <p>Mutation (Rule 19): <code>SqlPort.TableWrite</code> passes an empty index list for <code>REBUILD</code> -> the untouched-index assertions and the
/// killed-index assertions go red.</p>
Method TestOneIndexIsRebuiltOnBothCallers()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tTable), "the probe table is created")
    Do $ClassMethod(..#PROBE, "KillIndex", ..#NAMESPACE, tTable, "IdxB")
    Do $ClassMethod(..#PROBE, "KillIndex", ..#NAMESPACE, tTable, "IdxC")
    Do $$$AssertEquals(..Entries(tTable) _ "|" _ $ClassMethod(..#PROBE, "IndexedCount", ..#NAMESPACE, tTable, "B"), "0|0|0", "both indices are empty, and a query through one finds nothing")
    Set tConfirm = ..Agent(..#INDEXTOOL, tTable, "IdxB", , .tProposal, .tResult)
    Do $$$AssertEquals(tConfirm _ "|" _ ..Entries(tTable) _ "|" _ $ClassMethod(..#PROBE, "IndexedCount", ..#NAMESPACE, tTable, "B"), "200 |5|0|5", "the agent's confirmed rebuild fills the named index and leaves the other empty: " _ tConfirm)
    Do $$$AssertEquals(##class(OcuPilot.Test.EcpDataServerWrite).Verdict($Get(tResult)), "nothingSent", "and its read-back reads nothing sent")
    Do $ClassMethod(..#PROBE, "KillIndex", ..#NAMESPACE, tTable, "IdxB")
    Set tStatus = ..Act(..#INDEXSCREEN, "rebuild", ..IndexId(tTable, "IdxC"), , .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..Entries(tTable) _ "|" _ $ClassMethod(..#PROBE, "IndexedCount", ..#NAMESPACE, tTable, "C"), "200|0|5|5", "the screen's rebuild fills the other index and leaves the killed one empty")
    Do $$$AssertEquals(##class(OcuPilot.Test.EcpDataServerWrite).Verdict(tAnswer), "nothingSent", "its read-back reads nothing sent")
}

/// <p>AC2. An index whose SQL map name differs from the name the instance builds it by, the table's bitmap extent index <code>%%DDLBEIndex</code>
/// built as <code>DDLBEIndex</code>, is rebuilt by the screen's action: the rebuild passes the instance's own build name, which the instance accepts.</p>
/// <p>Mutation (Rule 19): <code>SqlPort.TableFacts</code> answers the map name as the argument -> the instance refuses it and the assertion goes red.</p>
Method TestAnIndexWhoseMapNameDiffersFromItsBuildNameIsRebuilt()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tTable), "the probe table is created")
    Set tStatus = ..Act(..#INDEXSCREEN, "rebuild", ..IndexId(tTable, "%%DDLBEIndex"), , .tAnswer)
    Do $$$AssertEquals(..Verdict(tStatus, tAnswer), "200 ", "the bitmap extent index is rebuilt")
}

/// <p>AC2. Every index of a table is rebuilt by the agent's confirmed proposal and by the screen's page action: with both indices' globals killed,
/// each holds every row when the confirm answers, and a query through each returns them.</p>
/// <p>Mutation (Rule 19): <code>SqlPort.TableWrite</code> is a no-op for <code>REBUILDALL</code> -> both callers' assertions go red.</p>
Method TestEveryIndexIsRebuiltOnBothCallers()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tTable), "the probe table is created")
    For tKill = 1:1:2 {
        Do $ClassMethod(..#PROBE, "KillIndex", ..#NAMESPACE, tTable, "IdxB")
        Do $ClassMethod(..#PROBE, "KillIndex", ..#NAMESPACE, tTable, "IdxC")
        Do $$$AssertEquals(..Entries(tTable), "0|0", "both indices are empty (round " _ tKill _ ")")
        If tKill = 1 {
            Set tConfirm = ..Agent(..#TABLETOOL, tTable, , , .tProposal, .tResult)
            Set tVerdict = tConfirm _ "|" _ ##class(OcuPilot.Test.EcpDataServerWrite).Verdict($Get(tResult))
        } Else {
            Set tStatus = ..Act(..#TABLESCREEN, "rebuild-indices", tTable, , .tAnswer)
            Set tVerdict = tStatus _ "||" _ ##class(OcuPilot.Test.EcpDataServerWrite).Verdict(tAnswer)
        }
        Do $$$AssertEquals(tVerdict _ "|" _ ..Entries(tTable) _ "|" _ $ClassMethod(..#PROBE, "IndexedCount", ..#NAMESPACE, tTable, "B") _ "|" _ $ClassMethod(..#PROBE, "IndexedCount", ..#NAMESPACE, tTable, "C"), $Select(tKill = 1: "200 |nothingSent", 1: "200||nothingSent") _ "|5|5|5|5", "the " _ $Select(tKill = 1: "agent's", 1: "screen's") _ " rebuild fills both indices, and a query through each returns every row: " _ tVerdict)
    }
}

/// <p>AC2. A table whose schema and name each hold a space, <code>Probe Table</code> in
/// <parameter>OcuPilot.Test.SqlTuningProbe.DELIMITEDSCHEMA</parameter>, has one index rebuilt by the agent's confirmed proposal and every index by the
/// screen's page action, each filling the indices whose globals were killed.</p>
/// <p>Mutation (Rule 19): <code>SqlPort.ResolveTable</code> refuses an id holding a space -> both callers' assertions go red.</p>
Method TestATableWithADelimitedNameIsRebuiltOnBothCallers()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 0, 5, .tTable, "Probe Table"), "a table named with a space is made in the schema named with one")
    Do $ClassMethod(..#PROBE, "KillIndex", ..#NAMESPACE, tTable, "IdxB")
    Do $ClassMethod(..#PROBE, "KillIndex", ..#NAMESPACE, tTable, "IdxC")
    Do $$$AssertEquals(..Entries(tTable), "0|0", "both indices are empty")
    Set tConfirm = ..Agent(..#INDEXTOOL, tTable, "IdxB", , .tProposal, .tResult)
    Do $$$AssertEquals(tConfirm _ "|" _ ..Entries(tTable), "200 |5|0", "the agent's confirmed rebuild fills the named index: " _ tConfirm)
    Do $ClassMethod(..#PROBE, "KillIndex", ..#NAMESPACE, tTable, "IdxB")
    Set tStatus = ..Act(..#TABLESCREEN, "rebuild-indices", tTable, , .tAnswer)
    Do $$$AssertEquals(..Verdict(tStatus, tAnswer) _ "|" _ ..Entries(tTable), "200 |5|5", "the screen's rebuild fills both")
}

/// <p>AC2. The table's data map holds its rows and has no index to rebuild: the screen's rebuild of it and the agent's proposal are refused with
/// the published sentence before any write, and the table's rows stay.</p>
/// <p>Mutation (Rule 19): the index tool's <code>Holds</code> admits a data map -> both refusals go red.</p>
Method TestTheDataMapIsRefusedBeforeAnyWrite()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tTable), "the probe table is created")
    Set tStatus = ..Act(..#INDEXSCREEN, "rebuild", ..IndexId(tTable, "IDKEY"), , .tAnswer)
    Do $$$AssertEquals(..Verdict(tStatus, tAnswer) _ "|" _ ..Problem(tAnswer), "400 TOOL.ARGUMENTS|" _ ##class(OcuPilot.Api.AtelierError).#REASONTABLEDATAMAP, "the screen's rebuild of the data map is refused with its sentence")
    Set tConfirm = ..Agent(..#INDEXTOOL, tTable, "IDKEY", , .tProposal, .tResult, ..#FIXTURE)
    Do $$$AssertEquals(tConfirm, "mint 400 " _ ##class(OcuPilot.Api.AtelierError).#REASONTABLEDATAMAP, "and so is the agent's")
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls") _ "|" _ $ClassMethod(..#PROBE, "IndexedCount", ..#NAMESPACE, tTable, "B"), "0|5", "no vendor call was made and the rows are there")
}

/// <p>A proposal whose table's statistics were collected after it was minted is refused <code>PROPOSAL.TARGETCHANGED</code> at its confirm, and nothing
/// is rebuilt.</p>
/// <p>Mutation (Rule 19): the table tool's <code>FINGERPRINTSUBJECT</code> drops <code>CollectedAt</code> and <code>StatsKind</code> -> the confirm is not
/// refused and goes red.</p>
Method TestATableWhoseStatisticsChangedAfterTheProposalIsRefusedTargetChanged()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tTable), "the probe table is created")
    Do $ClassMethod(..#PROBE, "KillIndex", ..#NAMESPACE, tTable, "IdxB")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set ^||OcuPilotDatabaseWritePort = $Parameter(..#TABLETOOL, "PORTCLASS")
    Set tSC = ..Mint(..#TABLETOOL, tTable, {"Table": (tTable)}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the proposal is minted: " _ $Get(tProblem))
    If '$IsObject($Get(tProposal)) Quit
    Do $ClassMethod("OcuPilot.Test.SqlTableRead", "Statistics", "collect", tTable)
    Set tConfirm = $ClassMethod(..#AGENT, "Confirm", tProposal, .tResult)
    Do $$$AssertEquals(tConfirm _ "|" _ ..Entries(tTable), "409 PROPOSAL.TARGETCHANGED|0|5", "the confirm is refused target-changed and the killed index is still empty: " _ tConfirm)
}

/// <p>The instance's own refusal of a table write is 409 <code>SQL.TABLE.VENDOR</code>, its ruled sentence on the wire and the instance's message in
/// <code>detail.message</code> alone; the call is made once, and the killed index is still empty.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.TableWrite</code> puts the message in the reason -> the reason assertion goes red.</p>
Method TestTheInstancesRefusalIsAnsweredWithItsMessageInDetailAlone()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tTable), "the probe table is created")
    Do $ClassMethod(..#PROBE, "KillIndex", ..#NAMESPACE, tTable, "IdxB")
    For tCase = $ListBuild("REBUILD", ..IndexId(tTable, "IdxB")), $ListBuild("REBUILDALL", tTable) {
        Do $ClassMethod(..#SEAM, "Reset")
        Do $ClassMethod(..#SEAM, "Refuse", "ERROR #5798: Failed to lock extent for exclusive access")
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("id") = $List(tCase, 2)
        Set tSC = $ClassMethod(..#FIXTURE, "Invoke", "Tables", $List(tCase, 1), .tQuery, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "409 SQL.TABLE.VENDOR", $List(tCase, 1) _ ": the refusal is 409 with its code")
        Do $$$AssertEquals($Select($IsObject($Get(tFault)): tFault.reason, 1: ""), "The instance did not apply this change to the table.", $List(tCase, 1) _ ": its reason is the ruled sentence")
        Do $$$AssertTrue($IsObject($Get(tFault)) && (tFault.detail.message [ "5798") && (tFault.reason '[ "5798"), $List(tCase, 1) _ ": the instance's message is in detail alone: " _ $Select($IsObject($Get(tFault)): tFault.%ToJSON(), 1: ""))
        Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls") _ "|" _ ..Entries(tTable), "1|0|5", $List(tCase, 1) _ ": one call was made and the killed index is still empty")
    }
}

/// <p>AC5. A table of OcuPilot's own, <code>OcuPilot_Kernel_State.Convo</code>, is refused <code>PROHIBITED.OCUPILOTTABLE</code> with its published
/// sentence by the screen's two actions and by the agent's two confirmed proposals, before any write: the agent's run through the instrumented port,
/// which counts no vendor call. The table and its index are read, not changed.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Screen.Tool.SqlTableAction.RefusedBeforeState</code> answers 0 and
/// <code>OcuPilot.Kernel.Proposal.Prohibited.TableEntry</code> skips its schema and class tests -> the own-table assertions go red on both callers.
/// Either check alone still refuses this table.</p>
Method TestATableOfOcuPilotsOwnIsRefusedOnBothCallers()
{
    Set tOwn = ..#OWNTABLE
    Set tMap = ..OwnMap(..#OWNNAMESPACE, tOwn)
    Do $$$AssertTrue(tMap '= "", "OcuPilot's own table holds an index that is not its data map: " _ tMap)
    If tMap = "" Quit
    Set tReason = ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor("PROHIBITED.OCUPILOTTABLE")
    Set tStatus = ..Act(..#TABLESCREEN, "rebuild-indices", tOwn, ..#OWNNAMESPACE, .tAnswer)
    Do $$$AssertEquals(..Verdict(tStatus, tAnswer), "403 PROHIBITED.OCUPILOTTABLE", "the screen's rebuild of every index is refused")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.reason, 1: ""), tReason, "with its published sentence")
    Set tStatus = ..Act(..#INDEXSCREEN, "rebuild", ..IndexId(tOwn, tMap), ..#OWNNAMESPACE, .tAnswer)
    Do $$$AssertEquals(..Verdict(tStatus, tAnswer), "403 PROHIBITED.OCUPILOTTABLE", "the screen's rebuild of one index is refused")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.reason, 1: ""), tReason, "with the same sentence")
    Set tConfirm = ..Agent(..#TABLETOOL, tOwn, , ..#OWNNAMESPACE, .tProposal, .tResult, ..#FIXTURE)
    Do $$$AssertTrue(tConfirm [ "PROHIBITED.OCUPILOTTABLE", "the agent's rebuild of every index is refused: " _ tConfirm)
    Set tConfirm = ..Agent(..#INDEXTOOL, tOwn, tMap, ..#OWNNAMESPACE, .tProposal, .tResult, ..#FIXTURE)
    Do $$$AssertTrue(tConfirm [ "PROHIBITED.OCUPILOTTABLE", "and of one index: " _ tConfirm)
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 0, "no vendor call was made for OcuPilot's own table")
}

}
