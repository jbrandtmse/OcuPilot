/// <p>Pins what Story 21.31's three setters show on the card and at the lower bound (AC1, AC2): a minted proposal's diff holds the declared value with the
/// value in use as old and the declared one as new, a selectivity's undeclared optional values are unchanged rather than changes, the bound 0 is a valid
/// extent size, map size and average size, and a map size of 0 is set and read back.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, which holds
/// <code>%Development:USE</code> and WRITE on <code>USER</code>'s and the install namespace's routines databases, and a <code>USER</code> namespace, where
/// each test makes its own <class>OcuPilot.Test.SqlTuningProbe</class> table and removes it after, each fixed statistic through Clear fixed statistics.
/// It snapshots the stored governance policy before and puts it back after. Live-safe.</p>
Class OcuPilot.Test.SqlTableFixedStatsCard Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.SqlTuningProbe";

Parameter SEAM = "OcuPilot.Test.SqlTuningGateSeam";

Parameter FIXED = "OcuPilot.Test.SqlTableFixedStats";

Parameter HELPERS = "OcuPilot.Test.SqlIndexRebuild";

Parameter PORT = "OcuPilot.Port.SqlPort";

Parameter NAMESPACE = "USER";

Parameter EXTENTTOOL = "OcuPilot.Screen.Tool.ExplorerSqlTableSetExtentSize";

Parameter MAPTOOL = "OcuPilot.Screen.Tool.ExplorerSqlIndexSetMapSize";

Parameter FIELDTOOL = "OcuPilot.Screen.Tool.ExplorerSqlFieldSetSelectivity";

Parameter CLEARTOOL = "OcuPilot.Screen.Tool.ExplorerSqlTableClearStatistics";

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

/// <p>The proposal of <var>pTool</var> for the target <var>pId</var> with <var>pArgs</var>, minted and not confirmed: the card's rows as
/// <code>field: before -> after</code> joined by <code>|</code> in <var>pRows</var>, and the proposal's <code>unchangedCount</code> in
/// <var>pUnchanged</var>. The status is the mint's.</p>
ClassMethod Card(pTool As %String, pId As %String, pArgs As %DynamicObject, Output pRows As %String, Output pUnchanged As %Integer) As %Status
{
    Set pRows = ""
    Set pUnchanged = -1
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set ^||OcuPilotDatabaseWritePort = $Parameter(pTool, "PORTCLASS")
    Do pArgs.%Set($ClassMethod(pTool, "IdArgument"), pId, "string")
    Set tSC = $ClassMethod(..#HELPERS, "Mint", pTool, pId, pArgs, .tProposal, .tHttp, .tProblem)
    If $$$ISERR(tSC) Quit tSC
    Set tIterator = tProposal.changed.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        Set pRows = pRows _ $Select(pRows = "": "", 1: "|") _ tRow.field _ ": " _ tRow.before _ " -> " _ tRow.after
    }
    Set pUnchanged = tProposal.unchangedCount
    Quit $$$OK
}

/// <p>The composite id of the map or field <var>pSecond</var> of <var>pTable</var>.</p>
ClassMethod Id(pTable As %String, pSecond As %String) As %String
{
    Quit pTable _ $Char(1) _ pSecond
}

/// <p>AC1. The card of each setter shows the value in use as old and the declared value as new, one row for the declared value: the extent size, a field's
/// selectivity and a map's size, each read from the tab's own read as it stood at the mint. A selectivity's undeclared outlier selectivity, outlier value
/// and average size are no row of the card (a write that sends no body counts none as unchanged), while one declared with another value is a row.</p>
Method TestEachCardShowsTheValueInUseAsOldAndTheDeclaredOneAsNew()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tTable), "the probe table is created")
    Do $ClassMethod("OcuPilot.Test.SqlTableRead", "Statistics", "collect", tTable)
    Set tSC = ..Card(..#EXTENTTOOL, tTable, {"ExtentSize": 5000}, .tRows, .tUnchanged)
    Do $$$AssertStatusOK(tSC, "the extent size's proposal is minted")
    Do $$$AssertEquals(tRows, "ExtentSize: 5 -> 5000", "its card shows the collected size in use as old and 5000 as new")
    Set tVerdict = $ClassMethod("OcuPilot.Test.SqlTableRead", "Read", "INDEX", ..Id(tTable, "IdxB"), .tAnswer, .tFault)
    Set tInUse = tAnswer.SizeMB
    Set tSC = ..Card(..#MAPTOOL, "IdxB", {"Table": (tTable), "SizeMB": 3}, .tRows, .tUnchanged)
    Do $$$AssertStatusOK(tSC, "the map size's proposal is minted")
    Do $$$AssertEquals(tRows, "SizeMB: " _ tInUse _ " -> 3", "its card shows the map's size in use as old and 3 as new")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "FixField", ..#NAMESPACE, tTable, "B", "40%", "10%", """q""", 9), "field B is fixed at 40% with an outlier of ""q"" at 10% and an average size of 9")
    Set tSC = ..Card(..#FIELDTOOL, "B", {"Table": (tTable), "Selectivity": "25%"}, .tRows, .tUnchanged)
    Do $$$AssertStatusOK(tSC, "the selectivity's proposal is minted")
    Do $$$AssertEquals(tRows, "Selectivity: 40.0000% -> 25%", "its card shows the fixed selectivity in use as old and 25% as new, and no row for an outlier value or the average size")
    Set tSC = ..Card(..#FIELDTOOL, "B", {"Table": (tTable), "Selectivity": "25%", "OutlierSelectivity": "5%"}, .tRows, .tUnchanged)
    Do $$$AssertStatusOK(tSC, "the proposal declaring an outlier selectivity too is minted")
    Do $$$AssertEquals(tRows, "Selectivity: 40.0000% -> 25%|OutlierSelectivity: 10% -> 5%", "an outlier selectivity declared with another value is a row beside it")
    Do $$$AssertEquals($ClassMethod(..#FIXED, "Restore", tTable), "200 ", "Clear fixed statistics restores the table")
}

/// <p>AC2. The lower bound 0 is a valid extent size, map size and average size, and a number below it is not.</p>
Method TestTheLowerBoundZeroIsAValidValue()
{
    Set tPort = ..#PORT
    For tName = "ExtentSize", "SizeMB", "AverageFieldSize" {
        Do $$$AssertEquals($ClassMethod(tPort, "ValueProblem", tName, "0"), "", tName _ ": 0 is accepted")
        Do $$$AssertTrue($ClassMethod(tPort, "ValueProblem", tName, "-1") '= "", tName _ ": -1 is refused")
    }
}

/// <p>AC1. A map size of 0, which the instance reads as "use the measured size", is set through the agent's confirmed proposal on a probe map and the
/// map reads its measured size again, so the read-back, comparing the declared 0, reads <code>differs</code> and names <code>SizeMB</code>.</p>
Method TestAMapSizeOfZeroIsSetAndReadBack()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tTable), "the probe table is created")
    Do $ClassMethod("OcuPilot.Test.SqlTableRead", "Statistics", "collect", tTable)
    Set tConfirm = $ClassMethod(..#FIXED, "Agent", ..#MAPTOOL, "IdxB", {"Table": (tTable), "SizeMB": 3}, .tResult)
    Do $$$AssertEquals(tConfirm, "200 ", "a map is first set to 3 MB: " _ tConfirm)
    Set tConfirm = $ClassMethod(..#FIXED, "Agent", ..#MAPTOOL, "IdxB", {"Table": (tTable), "SizeMB": 0}, .tResult)
    Set tVerdict = $ClassMethod("OcuPilot.Test.SqlTableRead", "Read", "INDEX", ..Id(tTable, "IdxB"), .tAnswer, .tFault)
    Do $$$AssertEquals(tConfirm _ "|" _ ##class(OcuPilot.Test.EcpDataServerWrite).Verdict($Get(tResult)) _ "|" _ (tAnswer.SizeMB '= 3), "200 |differs|1", "the set of 0 answers, the map no longer reads 3 MB, and the read-back reads differs, naming SizeMB: " _ tConfirm)
    Do $$$AssertEquals($Get(tResult).readBack.fields.%ToJSON(), "[""SizeMB""]", "the one field it names")
    Do $$$AssertEquals($ClassMethod(..#FIXED, "Restore", tTable), "200 ", "Clear fixed statistics restores the table")
}

}
