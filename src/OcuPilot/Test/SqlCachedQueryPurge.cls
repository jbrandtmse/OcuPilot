/// <p>Pins Story 21.6's cached-query purges on both permitted callers (AC4, AC5; AD-6, AD-10, AD-51, AD-53): one cached query and a table's purged by
/// the Cached queries tab's actions and by the agent's confirmed proposals, exactly the target's queries gone and every other query surviving; each
/// id shape refused on the tool that does not take it, before any write; and a purge of a table of OcuPilot's own not refused by the kernel.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, which holds
/// <code>%Development:USE</code> and WRITE on <code>USER</code>'s routines database, and a <code>USER</code> namespace, where each test makes
/// <class>OcuPilot.Test.SqlTuningProbe</class>'s objects and removes them after. It purges only the probe tables' cached queries, and it snapshots
/// the stored governance policy before and puts it back after.</p>
Class OcuPilot.Test.SqlCachedQueryPurge Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.SqlTuningProbe";

Parameter WRITE = "OcuPilot.Test.SqlStatementWrite";

Parameter PORT = "OcuPilot.Port.SqlPort";

Parameter SCREEN = "explorer.sqlcachedqueries";

Parameter NAMESPACE = "USER";

Parameter PURGE = "OcuPilot.Screen.Tool.ExplorerSqlCachedQueryPurge";

Parameter PURGETABLE = "OcuPilot.Screen.Tool.ExplorerSqlCachedQueryPurgeTable";

Parameter PURGENAMESPACE = "OcuPilot.Screen.Tool.ExplorerSqlCachedQueryPurgeNamespace";

Property PreparedPolicy [ MultiDimensional ];

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Kill ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Clear()
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "Make", ..#NAMESPACE)
    Do $$$AssertStatusOK(tSC, "the probe objects are created in " _ ..#NAMESPACE)
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#NAMESPACE), "every probe object is removed")
    Kill ^||OcuPilotDatabaseWritePort
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    Kill tRows
    Merge tRows = ..PreparedPolicy
    Quit ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
}

/// <p>The cached queries the port's <code>PURGE</code> read says <var>pId</var> holds in the probe namespace, or <code>-1</code> when it answers none.</p>
ClassMethod Count(pId As %String) As %Integer
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = pId
    Set tSC = $ClassMethod(..#PORT, "Invoke", "CachedQueries", "PURGE", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Quit $Select($IsObject($Get(tAnswer)): tAnswer.CachedQueries, 1: -1)
}

/// <p>The cached query class the probe statement whose text holds <var>pToken</var> is held by.</p>
ClassMethod Class(pToken As %String) As %String
{
    Quit $ClassMethod(..#PROBE, "LocationOf", ..#NAMESPACE, $ClassMethod(..#PROBE, "HashOf", ..#NAMESPACE, pToken))
}

/// <p>The three tools declare what the story rules: names, port, endpoints, request types, who reaches each, that none is destructive and none sends
/// a body, the screen action each carries, the governance keys -- all on, since a purge costs only a re-prepare -- and the one id shape each takes.</p>
/// <p>Mutation (Rule 19): set <code>DESTRUCTIVE</code> 1 on the purge base -> the destructive assertion goes red.</p>
Method TestThePurgeToolsDeclareTheirWritePath()
{
    For tCase = $ListBuild(..#PURGE, "explorer.sqlcachedqueries.purge", "purge", "CachedQuery"), $ListBuild(..#PURGETABLE, "explorer.sqlcachedqueries.purgetable", "purge-table", "Table"), $ListBuild(..#PURGENAMESPACE, "explorer.sqlcachedqueries.purgenamespace", "purge-namespace", "Target") {
        Set tTool = $List(tCase, 1)
        Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $ClassMethod(tTool, "PortClass") _ "|" _ $ClassMethod(tTool, "Endpoint") _ "|" _ $ClassMethod(tTool, "ReadType") _ "|" _ $ClassMethod(tTool, "WriteType"), $List(tCase, 2) _ "|OcuPilot.Port.SqlPort|CachedQueries|PURGE|PURGEQUERIES", $List(tCase, 2) _ ": name, port, endpoint and request types")
        Do $$$AssertEquals($ClassMethod(tTool, "Advertised") _ $ClassMethod(tTool, "Destructive") _ $ClassMethod(tTool, "SendsBody") _ "|" _ $ListToString($ClassMethod(tTool, "ScreenActionIds")) _ "|" _ $ClassMethod(tTool, "IdArgument"), "100|" _ $List(tCase, 3) _ "|" _ $List(tCase, 4), $List(tCase, 2) _ ": advertised, not destructive, no body, one screen action, its id argument")
        Do ##class(OcuPilot.Kernel.Governance.Baseline).Seed($List(tCase, 2), .tListed)
        Set tSC = ##class(OcuPilot.Kernel.Governance.Policy).Resolve($List(tCase, 2), "write", .tEnabled, .tSource)
        Do $$$AssertEquals(tListed _ " " _ ''$Get(tEnabled), "1 1", $List(tCase, 2) _ ": its key is in the baseline and ships enabled")
        Set tPairs = $ClassMethod(tTool, "PrivilegePairs", "", .tResolved)
        Do $$$AssertTrue(tResolved && ($ListFind(tPairs, $ListBuild("%Development", "USE")) > 0), $List(tCase, 2) _ ": its pairs hold the Explorer's")
        Do $$$AssertEquals($ClassMethod(tTool, "Consequence", {}), "SQL.CACHEDQUERY.PURGE", $List(tCase, 2) _ ": its consequence code")
    }
    Set tClass = ..Class("SELECT A FROM")
    Do $$$AssertEquals(($ClassMethod(..#PURGE, "IdProblem", tClass) = "") _ ($ClassMethod(..#PURGETABLE, "IdProblem", tClass) = "") _ ($ClassMethod(..#PURGENAMESPACE, "IdProblem", tClass) = ""), "100", "a cached query's class is the one-query tool's alone")
    Do $$$AssertEquals(($ClassMethod(..#PURGE, "IdProblem", "OcuProbe216.T1") = "") _ ($ClassMethod(..#PURGETABLE, "IdProblem", "OcuProbe216.T1") = "") _ ($ClassMethod(..#PURGENAMESPACE, "IdProblem", "OcuProbe216.T1") = ""), "010", "a table is the table tool's alone")
    Do $$$AssertEquals(($ClassMethod(..#PURGE, "IdProblem", "*") = "") _ ($ClassMethod(..#PURGETABLE, "IdProblem", "*") = "") _ ($ClassMethod(..#PURGENAMESPACE, "IdProblem", "*") = ""), "001", "the literal * is the namespace tool's alone")
}

/// <p>AC4. Each purge removes exactly its target's cached queries: one class by the screen's action, then one by the agent's confirmed proposal, a
/// table's by the screen's page action and by the agent's, each leaving the table's other query and the other table's query, and the port's count of
/// the target reading <code>0</code> afterwards.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.PurgeWrite</code> builds <code>{}</code> for a table target -> the other table's surviving query
/// goes red.</p>
Method TestExactlyTheTargetsQueriesAreGoneOnBothCallers()
{
    Set tWrite = ..#WRITE
    Set tClass = ..Class("SELECT A FROM")
    Do $$$AssertEquals(..Count("OcuProbe216.T1") _ "|" _ ..Count("OcuProbe216.T2") _ "|" _ ..Count(tClass), "2|1|1", "the probe holds two cached queries on the first table and one on the second")
    Set tStatus = $ClassMethod(tWrite, "Act", "purge", tClass, ..#NAMESPACE, .tAnswer, ..#SCREEN)
    Do $$$AssertEquals(tStatus _ "|" _ ..Count("OcuProbe216.T1") _ "|" _ ..Count("OcuProbe216.T2") _ "|" _ ..Count(tClass), "200|1|1|-1", "the screen's purge of one query removes it alone, and the class is no longer found")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.id, 1: ""), "updated|cached-query|" _ tClass, "its answer names the cached query")
    Set tStatus = $ClassMethod(tWrite, "Act", "purge", tClass, ..#NAMESPACE, .tAnswer, ..#SCREEN)
    Do $$$AssertEquals($ClassMethod(tWrite, "Verdict", tStatus, tAnswer), "404 PORT.NOTFOUND", "a class already gone is refused 404")
    Do $ClassMethod(..#PROBE, "Make", ..#NAMESPACE)
    Set tClass = ..Class("SELECT B FROM")
    Set tConfirm = $ClassMethod(tWrite, "Agent", ..#PURGE, tClass, "CachedQuery", , .tProposal, .tResult)
    Do $$$AssertEquals(tConfirm _ "|" _ ..Count("OcuProbe216.T1") _ "|" _ ..Count("OcuProbe216.T2"), "200 |1|1", "the agent's confirmed purge of one query removes it alone: " _ tConfirm)
    Set tStatus = $ClassMethod(tWrite, "Act", "purge-table", "OcuProbe216.T1", ..#NAMESPACE, .tAnswer, ..#SCREEN)
    Do $$$AssertEquals(tStatus _ "|" _ ..Count("OcuProbe216.T1") _ "|" _ ..Count("OcuProbe216.T2"), "200|0|1", "the page's purge of a table removes its queries and the other table's survives")
    Do $ClassMethod(..#PROBE, "Make", ..#NAMESPACE)
    Set tConfirm = $ClassMethod(tWrite, "Agent", ..#PURGETABLE, "OcuProbe216.T1", "Table", , .tProposal, .tResult)
    Do $$$AssertEquals(tConfirm _ "|" _ ..Count("OcuProbe216.T1") _ "|" _ ..Count("OcuProbe216.T2"), "200 |0|1", "so does the agent's: " _ tConfirm)
    Do $$$AssertEquals($Get(tResult) '= "", 1, "its confirm answered")
}

/// <p>Each id shape is refused, before any write, on the tool that does not take it: a table on the one-query tool, a class on the table tool, and
/// anything but <code>*</code> on the namespace tool, by the screen's action and by the agent's mint, the queries unchanged; a table the namespace
/// does not show is refused 404.</p>
/// <p>Mutation (Rule 19): the table tool's <code>IdProblem</code> admits a cached query's class -> the class-on-table assertions go red.</p>
Method TestAnIdOfAnotherShapeIsRefusedOnTheWrongTool()
{
    Set tWrite = ..#WRITE
    Set tClass = ..Class("SELECT A FROM")
    Set tBefore = ..Count("OcuProbe216.T1") _ "|" _ ..Count("OcuProbe216.T2")
    For tCase = $ListBuild("purge", ..#PURGE, "CachedQuery", "OcuProbe216.T1"), $ListBuild("purge-table", ..#PURGETABLE, "Table", tClass), $ListBuild("purge-namespace", ..#PURGENAMESPACE, "Target", tClass), $ListBuild("purge-namespace", ..#PURGENAMESPACE, "Target", "OcuProbe216.T1") {
        Set tStatus = $ClassMethod(tWrite, "Act", $List(tCase, 1), $List(tCase, 4), ..#NAMESPACE, .tAnswer, ..#SCREEN)
        Do $$$AssertEquals($ClassMethod(tWrite, "Verdict", tStatus, tAnswer), "400 TOOL.ARGUMENTS", $List(tCase, 1) _ " of " _ $List(tCase, 4) _ ": the screen refuses the shape")
        Set tConfirm = $ClassMethod(tWrite, "Agent", $List(tCase, 2), $List(tCase, 4), $List(tCase, 3), , .tProposal, .tResult)
        Do $$$AssertEquals($Extract(tConfirm, 1, 8), "mint 400", $List(tCase, 1) _ " of " _ $List(tCase, 4) _ ": the agent's mint refuses it")
    }
    Set tStatus = $ClassMethod(tWrite, "Act", "purge-table", "OcuProbe216.Absent", ..#NAMESPACE, .tAnswer, ..#SCREEN)
    Do $$$AssertEquals($ClassMethod(tWrite, "Verdict", tStatus, tAnswer), "404 PORT.NOTFOUND", "a table the namespace does not show is not found")
    Do $$$AssertEquals(..Count("OcuProbe216.T1") _ "|" _ ..Count("OcuProbe216.T2"), tBefore, "and no query was purged")
}

/// <p>AC5. A purge of the cached queries of a table of OcuPilot's own is not refused by the kernel: the prohibited set answers permitted for the table
/// tool over <code>OcuPilot_Kernel_State.Version</code>, which the test asks and does not purge.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Kernel.Proposal.Prohibited.StatementEntry</code> is applied to the cached-query type -> this goes red.</p>
Method TestAPurgeOfAnOwnTableIsNotRefused()
{
    Do ##class(OcuPilot.Kernel.Scope).Set("HSCUSTOM")
    Set tSC = ##class(OcuPilot.Kernel.EntityRef).Key("cached-query", "HSCUSTOM", "OcuPilot_Kernel_State.Version", .tRef)
    Do $$$AssertStatusOK(tSC, "the target has a key")
    If $$$ISERR(tSC) Quit
    Set tSC = ##class(OcuPilot.Kernel.Proposal.Prohibited).Prohibits($Parameter(..#PURGETABLE, "TOOLNAME"), tRef, "{}", "[]", .tProhibits, .tCode, .tReason)
    Do $$$AssertEquals($Select($$$ISOK(tSC): tProhibits _ "|" _ tCode, 1: "error"), "0|", "the table's purge is not prohibited")
}

}
