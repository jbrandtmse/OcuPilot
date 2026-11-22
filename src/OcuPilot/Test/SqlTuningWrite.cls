/// <p>Pins Story 21.6's two namespace-wide writes on both permitted callers (AC3, AC4; AD-6, AD-51, AD-53): the namespace's cached queries purged by
/// the Cached queries page's action and by the agent's confirmed proposal, and the namespace's statement index cleaned of its stale statements the
/// same way. Each asserts on its own probe objects alone: the probe's queries are gone, the probe's stale statement is gone, and the probe's
/// statements that still hold a location stay. A clean of an index that holds nothing stale is refused with its sentence.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, which holds
/// <code>%Development:USE</code> and WRITE on <code>USER</code>'s routines database, a <code>USER</code> namespace, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because the purge removes every cached query of <code>USER</code> and the clean
/// every stale statement of its index, which a test cannot confine to its own objects. It runs on a throwaway container only. It makes
/// <class>OcuPilot.Test.SqlTuningProbe</class>'s objects in <code>USER</code> and removes them after, and snapshots the stored governance policy
/// before and puts it back after.</p>
Class OcuPilot.Test.SqlTuningWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, and the one value that arms it: <code>1</code>.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_CONFIG_SETTINGS";

Parameter PROBE = "OcuPilot.Test.SqlTuningProbe";

Parameter WRITE = "OcuPilot.Test.SqlStatementWrite";

Parameter PURGE = "OcuPilot.Test.SqlCachedQueryPurge";

Parameter NAMESPACE = "USER";

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
    Set tClass = $ClassMethod(..#PURGE, "Class", "SELECT A FROM")
    Do $$$AssertEquals($ClassMethod(..#PURGE, "Count", "OcuProbe216.T1") _ "|" _ $ClassMethod(..#PURGE, "Count", "OcuProbe216.T2"), "2|1", "the probe holds its three cached queries")
    Set tStatus = $ClassMethod(tWrite, "Act", "purge-namespace", "*", ..#NAMESPACE, .tAnswer, "explorer.sqlcachedqueries")
    Do $$$AssertEquals(tStatus _ "|" _ $ClassMethod(..#PURGE, "Count", "OcuProbe216.T1") _ "|" _ $ClassMethod(..#PURGE, "Count", "OcuProbe216.T2") _ "|" _ $ClassMethod(..#PURGE, "Count", tClass), "200|0|0|-1", "the screen's purge removes them, and the probe's class is no longer found")
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
    If $IsObject($Get(tIndex)) && (tIndex.Stale = 0) {
        Set tStatus = $ClassMethod(tWrite, "Act", "clean", "*", ..#NAMESPACE, .tAnswer)
        Do $$$AssertEquals($ClassMethod(tWrite, "Verdict", tStatus, tAnswer) _ "|" _ $Select($IsObject(tAnswer) && $IsObject(tAnswer.detail): tAnswer.detail.problem, 1: ""), "400 TOOL.ARGUMENTS|" _ ##class(OcuPilot.Api.AtelierError).#REASONSTATEMENTNOSTALE, "a clean of an index that holds nothing stale is refused with its sentence")
    }
}

}
