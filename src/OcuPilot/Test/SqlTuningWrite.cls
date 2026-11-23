/// <p>Pins Story 21.6's two namespace-wide writes on both permitted callers (AC3, AC4; AD-6, AD-51, AD-53): the namespace's cached queries purged by
/// the Cached queries page's action and by the agent's confirmed proposal, and the namespace's statement index cleaned of its stale statements the
/// same way. Each asserts on its own probe objects alone: the probe's queries are gone, the probe's stale statement is gone, and the probe's
/// statements that still hold a location stay. A clean of an index that holds nothing stale is refused with its sentence.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, which holds
/// <code>%Development:USE</code> and WRITE on <code>USER</code>'s routines database, a <code>USER</code> namespace, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the purge removes every cached query of <code>USER</code> and the clean
/// every stale statement of its index, which a test cannot confine to its own objects. It runs on a throwaway container only. It makes
/// <class>OcuPilot.Test.SqlTuningProbe</class>'s objects in <code>USER</code> (and, for one test, in <code>HSCUSTOM</code>) and removes them after, and snapshots the stored governance policy
/// before and puts it back after.</p>
Class OcuPilot.Test.SqlTuningWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it: <code>1</code>.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_CONFIG_SETTINGS";

Parameter PROBE = "OcuPilot.Test.SqlTuningProbe";

Parameter WRITE = "OcuPilot.Test.SqlStatementWrite";

Parameter PURGE = "OcuPilot.Test.SqlCachedQueryPurge";

Parameter NAMESPACE = "USER";

/// <p>The second namespace the purge tests make a probe in, to show a purge of <parameter>NAMESPACE</parameter> leaves it.</p>
Parameter OTHERNAMESPACE = "HSCUSTOM";

Parameter CLEAN = "OcuPilot.Screen.Tool.ExplorerSqlStatementClean";

Parameter PURGENAMESPACE = "OcuPilot.Screen.Tool.ExplorerSqlCachedQueryPurgeNamespace";

Property PreparedPolicy [ MultiDimensional ];

Property PreparedPolicyTaken As %Boolean [ InitialExpression = 0 ];

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPolicyTaken = 0
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If $System.Util.GetEnviron(..#ARMINGVARIABLE) '= 1 {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlTuningWrite purges the cached queries of " _ ..#NAMESPACE _ " and cleans its statement index, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Kill ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set ..PreparedPolicyTaken = 1
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Clear()
    If $$$ISERR(tSC) Quit tSC
    Set tSC = $ClassMethod(..#PROBE, "Make", ..#NAMESPACE)
    Do $$$AssertStatusOK(tSC, "the probe objects are created in " _ ..#NAMESPACE)
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#NAMESPACE), "every probe object is removed")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Remove", ..#OTHERNAMESPACE), "every probe object of the other namespace is removed")
    Kill ^||OcuPilotDatabaseWritePort
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    If '..PreparedPolicyTaken Quit $$$OK
    Kill tRows
    Merge tRows = ..PreparedPolicy
    Quit ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
}

/// <p>AC4. The screen's purge of the namespace's cached queries and the agent's confirmed one each remove every cached query of the probe's two
/// tables, and the probe statement's class is no longer found.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.PurgeWrite</code> builds <code>{"table": [...]}</code> for the namespace -> the probe's second
/// table keeps its query and this goes red.</p>
Method TestTheNamespacesCachedQueriesArePurgedOnBothCallers()
{
    Set tWrite = ..#WRITE
    Set tHash = $ClassMethod(..#PROBE, "HashOf", ..#NAMESPACE, "SELECT A FROM")
    Do $$$AssertEquals($ClassMethod(..#PURGE, "Count", "OcuProbe216.T1") _ "|" _ $ClassMethod(..#PURGE, "Count", "OcuProbe216.T2") _ "|" _ ($ClassMethod(..#PROBE, "LocationOf", ..#NAMESPACE, tHash) '= ""), "2|1|1", "the probe holds its three cached queries, and its statement a location")
    Set tStatus = $ClassMethod(tWrite, "Act", "purge-namespace", "*", ..#NAMESPACE, .tAnswer, "explorer.sqlcachedqueries")
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#PURGE, "Count", "OcuProbe216.T1") _ "|" _ $ClassMethod(..#PURGE, "Count", "OcuProbe216.T2") _ "|" _ $ClassMethod(..#PROBE, "LocationOf", ..#NAMESPACE, tHash), "200|0|0|", "the screen's purge removes them, and the probe's statement holds no location")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.id, 1: ""), "updated|cached-query|*", "its answer names the namespace's cached queries")
    Do $ClassMethod(..#PROBE, "Make", ..#NAMESPACE)
    Set tConfirm = $ClassMethod(tWrite, "Agent", ..#PURGENAMESPACE, "*", "Target", , .tProposal, .tResult)
    Do $$$AssertEquals(tConfirm _ "|" _ $ClassMethod(..#PURGE, "Count", "OcuProbe216.T1") _ "|" _ $ClassMethod(..#PURGE, "Count", "OcuProbe216.T2"), "200 |0|0", "the agent's confirmed purge removes them too: " _ tConfirm)
}

/// <p>AC3. The screen's clean and the agent's confirmed one each remove the probe's stale statement from the index and leave the probe's statements
/// that still hold a location; an index that holds nothing stale is then refused, with its sentence, before any write.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.StatementCall</code> answers <code>$$$OK</code> for <code>CLEAN</code> without calling -> the stale
/// statement stays and this goes red.</p>
Method TestTheStaleStatementIsCleanedOnBothCallers()
{
    Set tWrite = ..#WRITE
    Kill tSettings
    Set tSettings($Parameter(..#CLEAN, "TOOLNAME")) = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the clean, whose key ships disabled, is enabled through its stored setting")
    Set tStale = $ClassMethod(..#PROBE, "HashOf", ..#NAMESPACE, "SELECT A , B FROM")
    Set tKept = $ClassMethod(..#PROBE, "HashOf", ..#NAMESPACE, "SELECT A FROM")
    Set tFacts = $ClassMethod(..#PROBE, "Facts", ..#NAMESPACE, tStale)
    Do $$$AssertEquals(tFacts.Present _ "|" _ (tFacts.Location = ""), "1|1", "the probe's stale statement is in the index and holds no location")
    Set tStatus = $ClassMethod(tWrite, "Act", "clean", "*", ..#NAMESPACE, .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#PROBE, "Facts", ..#NAMESPACE, tStale).Present _ "|" _ $ClassMethod(..#PROBE, "Facts", ..#NAMESPACE, tKept).Present, "200|0|1", "the screen's clean removes it and the statement that holds a location stays")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.id, 1: ""), "updated|statement-index-entry|*", "its answer names the index")
    Do $ClassMethod(..#PROBE, "Make", ..#NAMESPACE)
    Set tStale = $ClassMethod(..#PROBE, "HashOf", ..#NAMESPACE, "SELECT A , B FROM")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts", ..#NAMESPACE, tStale).Present, 1, "the probe is made again with a stale statement")
    Set tConfirm = $ClassMethod(tWrite, "Agent", ..#CLEAN, "*", "Hash", , .tProposal, .tResult)
    Do $$$AssertEquals(tConfirm _ "|" _ $ClassMethod(..#PROBE, "Facts", ..#NAMESPACE, tStale).Present _ "|" _ $ClassMethod(..#PROBE, "Facts", ..#NAMESPACE, tKept).Present, "200 |0|1", "the agent's confirmed clean does the same: " _ tConfirm)
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = "*"
    Set tSC = ##class(OcuPilot.Port.SqlPort).Invoke("Statements", "STATEMENT", .tQuery, "", .tIndex, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject($Get(tIndex)): tIndex.Stale, 1: -1), 0, "the clean left the index holding nothing stale")
    Set tStatus = $ClassMethod(tWrite, "Act", "clean", "*", ..#NAMESPACE, .tAnswer)
    Do $$$AssertEquals($ClassMethod(tWrite, "Verdict", tStatus, tAnswer) _ "|" _ $Select($IsObject(tAnswer) && $IsObject(tAnswer.detail): tAnswer.detail.problem, 1: ""), "400 TOOL.ARGUMENTS|" _ ##class(OcuPilot.Api.AtelierError).#REASONSTATEMENTNOSTALE, "the screen's clean of an index that holds nothing stale is refused with its sentence")
    Set tConfirm = $ClassMethod(tWrite, "Agent", ..#CLEAN, "*", "Hash", , .tProposal, .tResult)
    Do $$$AssertEquals(tConfirm, "mint 400 " _ ##class(OcuPilot.Api.AtelierError).#REASONSTATEMENTNOSTALE, "the agent's clean of such an index is refused before any write: " _ tConfirm)
}

/// <p>AC4. A purge of one namespace's cached queries removes that namespace's and leaves another namespace's. Each namespace holds its own probe.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.Applied</code> calls <code>PurgeCachedQueries</code> without the target namespace -> the purge
/// runs in the request's own namespace, the other namespace's queries are gone and the target's stay, and this goes red.</p>
Method TestAnotherNamespacesCachedQueriesSurviveTheNamespacePurge()
{
    Set tWrite = ..#WRITE
    Set tOther = ..#OTHERNAMESPACE
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Make", tOther), "the probe objects are created in " _ tOther)
    Do $$$AssertEquals(..CountIn(tOther, "OcuProbe216.T1") _ "|" _ ..CountIn(tOther, "OcuProbe216.T2"), "2|1", tOther _ " holds the probe's three cached queries")
    Set tStatus = $ClassMethod(tWrite, "Act", "purge-namespace", "*", ..#NAMESPACE, .tAnswer, "explorer.sqlcachedqueries")
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#PURGE, "Count", "OcuProbe216.T1") _ "|" _ ..CountIn(tOther, "OcuProbe216.T1") _ "|" _ ..CountIn(tOther, "OcuProbe216.T2"), "200|0|2|1", "the purge of " _ ..#NAMESPACE _ " removes its queries and leaves the queries of " _ tOther)
}

/// <p>AC3. A statement no class or routine holds whose plan is frozen is not stale: freezing the probe's stale statement takes it out of the index's
/// stale count, and the screen's clean leaves it in the index.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.STALECOUNTQUERY</code> counts frozen statements -> the count assertion goes red.</p>
Method TestAFrozenStatementNoClassHoldsIsNotStale()
{
    Set tWrite = ..#WRITE
    Kill tSettings
    Set tSettings($Parameter(..#CLEAN, "TOOLNAME")) = "enabled"
    Do $$$AssertStatusOK(##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings), "the clean, whose key ships disabled, is enabled through its stored setting")
    Set tStale = $ClassMethod(..#PROBE, "HashOf", ..#NAMESPACE, "SELECT A , B FROM")
    Set tBefore = ..StaleIn(..#NAMESPACE)
    Do $ClassMethod(tWrite, "Call", ..#NAMESPACE, "freeze", tStale)
    Set tFacts = $ClassMethod(..#PROBE, "Facts", ..#NAMESPACE, tStale)
    Do $$$AssertEquals(tFacts.PlanState _ "|" _ (tFacts.Location = "") _ "|" _ (tBefore - ..StaleIn(..#NAMESPACE)), "Frozen/Explicit|1|1", "the frozen statement no class holds leaves the stale count")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Do $SYSTEM.SQL.Statement.Clean()
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Facts", ..#NAMESPACE, tStale).Present, 1, "and the vendor's clean, which the tool calls, leaves it in the index")
}

/// <p>The stale statements the port's <code>STATEMENT</code> read of <code>*</code> counts in <var>pNamespace</var>, or <code>-1</code> when it answers none.</p>
ClassMethod StaleIn(pNamespace As %String) As %Integer
{
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    Set tQuery("id") = "*"
    Set tSC = ##class(OcuPilot.Port.SqlPort).Invoke("Statements", "STATEMENT", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Quit $Select($IsObject($Get(tAnswer)): tAnswer.Stale, 1: -1)
}

/// <p>The cached queries the port's <code>PURGE</code> read says <var>pId</var> holds in <var>pNamespace</var>, or <code>-1</code> when it answers none.</p>
ClassMethod CountIn(pNamespace As %String, pId As %String) As %Integer
{
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    Set tQuery("id") = pId
    Set tSC = ##class(OcuPilot.Port.SqlPort).Invoke("CachedQueries", "PURGE", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Quit $Select($IsObject($Get(tAnswer)): tAnswer.CachedQueries, 1: -1)
}

}
