/// <p>Pins how Story 21.31's field setter treats an outlier value and a set that fails (AC1, AC2; AD-6, AD-21, AD-51, AD-53, AD-58): a value sent is plain data that
/// the port quotes, stored and read back as the text sent and never run, by the port and by the agent; a value left out keeps what the field holds, byte for
/// byte; and a set the instance refuses or raises after the collected statistics were saved as fixed says so.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, which holds
/// <code>%Development:USE</code> and WRITE on <code>USER</code>'s and the install namespace's routines databases, and a <code>USER</code> namespace, where
/// each test makes its own <class>OcuPilot.Test.SqlTuningProbe</class> tables and removes them after, each fixed statistic through Clear fixed statistics.
/// It snapshots the stored governance policy before and puts it back after. Live-safe.</p>
Class OcuPilot.Test.SqlTableOutlierValues Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.SqlTuningProbe";

Parameter FIXED = "OcuPilot.Test.SqlTableFixedStats";

Parameter FIXTURE = "OcuPilot.Test.SqlTuningPortFixture";

Parameter SEAM = "OcuPilot.Test.SqlTuningGateSeam";

Parameter READS = "OcuPilot.Test.SqlTableRead";

Parameter NAMESPACE = "USER";

Parameter MAPTOOL = "OcuPilot.Screen.Tool.ExplorerSqlIndexSetMapSize";

Parameter FIELDTOOL = "OcuPilot.Screen.Tool.ExplorerSqlFieldSetSelectivity";

Parameter CLEARTOOL = "OcuPilot.Screen.Tool.ExplorerSqlTableClearStatistics";

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
    For tTool = ..#MAPTOOL, ..#FIELDTOOL, ..#CLEARTOOL {
        Set tSettings($Parameter(tTool, "TOOLNAME")) = "enabled"
    }
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
    Do $$$AssertStatusOK(tSC, "the two setters and Clear fixed statistics, whose keys ship disabled, are enabled through their stored settings")
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

/// <p>The field <var>pField</var>'s fixed outlier selectivity, outlier value and average size, as the instance holds them: <code>a|b|c</code>.</p>
ClassMethod Held(pTable As %String, pField As %String) As %String
{
    Quit $Piece($ClassMethod(..#PROBE, "FixedField", ..#NAMESPACE, pTable, pField), "|", 2, 4)
}

/// <p>The outlier value <code>FIELDSTATS</code> answers for the field <var>pField</var> of <var>pTable</var>.</p>
ClassMethod Plain(pTable As %String, pField As %String) As %String
{
    Set tVerdict = $ClassMethod(..#READS, "Read", "FIELDSTATS", pTable _ $Char(1) _ pField, .tAnswer, .tFault)
    Quit $Select($IsObject($Get(tAnswer)): tAnswer.OutlierValue, 1: "unread " _ tVerdict)
}

/// <p>AC1, AC2. A value sent as an outlier value is plain data, however it reads: the port hands the instance a number as it is and any other text as a
/// double-quoted literal, so the instance stores it, the field's read answers the text sent, and nothing it holds runs. Each value is set once through the
/// port and once through the agent's confirmed proposal; the marker the code-shaped ones would set stays unset.</p>
/// <p>The longest value, 128 characters, is set as plain text and as all quotes, whose literal is longer still.</p>
/// <p>Mutation (Rule 19): <code>SqlPort.OutlierExpression</code> answers the text unquoted -> the code-shaped legs go red and the marker is set;
/// <code>SqlPort.ValueProblem</code> refuses a value of 128 characters -> the two longest legs go red.</p>
Method TestAnOutlierValueIsNeverRun()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tTable), "the probe table is created")
    Do $ClassMethod(..#READS, "Statistics", "collect", tTable)
    Set tRan = "^OcuPilotSqlProbeRan"
    Set tCases = $ListBuild($ListBuild("$Increment(" _ tRan _ ")", """$Increment(" _ tRan _ ")"""), $ListBuild("1_$Increment(" _ tRan _ ")", """1_$Increment(" _ tRan _ ")"""), $ListBuild("$C(65)", """$C(65)"""), $ListBuild("a""b", """a""""b"""), $ListBuild("@X", """@X"""), $ListBuild(tRan, """" _ tRan _ """"), $ListBuild("1 Set " _ tRan _ "=1", """1 Set " _ tRan _ "=1"""), $ListBuild("42", "42"), $ListBuild(".5", ".5"), $ListBuild("0.5", """0.5"""), $ListBuild("-3", "-3"))
    Set tLong = $Translate($Justify("", 128), " ", "a")
    Set tQuotes = $Translate($Justify("", 128), " ", """")
    Set tCases = tCases _ $ListBuild($ListBuild(tLong, """" _ tLong _ """"), $ListBuild(tQuotes, """" _ $Replace(tQuotes, """", """""") _ """"))
    For tI = 1:1:$ListLength(tCases) {
        Set tText = $List($List(tCases, tI), 1)
        Set tExpected = $List($List(tCases, tI), 2)
        Kill ^|"USER"|OcuPilotSqlProbeRan
        Set tVerdict = $ClassMethod(..#FIXED, "Invoke", "SETSELECTIVITY", $ClassMethod(..#FIXED, "Id", tTable, "B"), {"Selectivity": "25%", "OutlierSelectivity": "5%", "OutlierValue": (tText)}, .tFault)
        Set tPort = $Piece($ClassMethod(..#PROBE, "FixedField", ..#NAMESPACE, tTable, "B"), "|", 3) _ "|" _ ..Plain(tTable, "B")
        Set tConfirm = $ClassMethod(..#FIXED, "Agent", ..#FIELDTOOL, "A", {"Table": (tTable), "Selectivity": "25%", "OutlierSelectivity": "5%", "OutlierValue": (tText)}, , ..#FIXTURE)
        Set tAgent = $Piece($ClassMethod(..#PROBE, "FixedField", ..#NAMESPACE, tTable, "A"), "|", 3) _ "|" _ ..Plain(tTable, "A")
        Do $$$AssertEquals(tVerdict _ "|" _ tPort _ "|" _ tConfirm _ "|" _ tAgent _ "|" _ $Get(^|"USER"|OcuPilotSqlProbeRan, "unset"), "200 |" _ tExpected _ "|" _ tText _ "|200 |" _ tExpected _ "|" _ tText _ "|unset", "'" _ tText _ "' is stored as data through the port and the agent, read back as sent, and run nowhere")
        Do $ClassMethod(..#FIXED, "Restore", tTable)
    }
}

/// <p>AC2. An outlier value holding a control character, or over 128 characters, is refused before any call, by the port and by the agent's mint.</p>
/// <p>Mutation (Rule 19): <code>SqlPort.ValueProblem</code> lets a control character through -> the control legs go red.</p>
Method TestAnOutlierValueWithAControlCharacterIsRefused()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tTable), "the probe table is created")
    Do $ClassMethod(..#READS, "Statistics", "collect", tTable)
    For tText = "a" _ $Char(10) _ "b", "a" _ $Char(13), "a" _ $Char(9), "a" _ $Char(0), "a" _ $Char(127), $Translate($Justify("", 129), " ", "a") {
        Set tVerdict = $ClassMethod(..#FIXED, "Invoke", "SETSELECTIVITY", $ClassMethod(..#FIXED, "Id", tTable, "B"), {"Selectivity": "25%", "OutlierSelectivity": "5%", "OutlierValue": (tText)}, .tFault)
        Set tConfirm = $ClassMethod(..#FIXED, "Agent", ..#FIELDTOOL, "B", {"Table": (tTable), "Selectivity": "25%", "OutlierSelectivity": "5%", "OutlierValue": (tText)}, , ..#FIXTURE)
        Do $$$AssertTrue(($Extract(tVerdict, 1, 3) = "400") && ($Extract(tConfirm, 1, 8) = "mint 400"), "a value of " _ $Length(tText) _ " characters ending in code " _ $ASCII(tText, $Length(tText)) _ " is refused by both: " _ tVerdict _ " " _ tConfirm)
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls") _ "|" _ $ClassMethod(..#FIXED, "Stats", tTable), "0|collected 5 0", "no call was made and the collected statistics are not fixed")
}

/// <p>AC1. A selectivity set alone keeps each outlier value the field holds exactly as the instance holds it: a quoted text, a quoted text longer than the 128
/// characters a caller may send, and a number below 1, read before and after through the agent's proposal and through the screen's row action, and each is still read back as
/// the plain text.</p>
/// <p>Mutation (Rule 19): <code>SqlPort.SettingCall</code> passes an omitted outlier value through <code>OutlierExpression</code> -> the quoted text's leg
/// goes red; it passes the empty string -> every leg goes red; <code>SqlPort.OptionalProblem</code> compares the held outlier value without
/// <code>OutlierPlain</code> -> the screen's leg on the long text goes red.</p>
Method TestAnOmittedOutlierValueIsKeptByteForByte()
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tTable), "the probe table is created")
    Do $ClassMethod(..#READS, "Statistics", "collect", tTable)
    Set tLong = $Translate($Justify("", 130), " ", "a")
    For tCase = $ListBuild("A", """q""", 9), $ListBuild("B", """" _ tLong _ """", 9), $ListBuild("C", ".5", ".5") {
        Do $$$AssertStatusOK($ClassMethod(..#PROBE, "FixField", ..#NAMESPACE, tTable, $List(tCase, 1), "40%", "10%", $List(tCase, 2), $List(tCase, 3)), "field " _ $List(tCase, 1) _ " is fixed with the outlier value " _ $List(tCase, 2) _ " and the average size " _ $List(tCase, 3))
    }
    Set tBefore = ..Held(tTable, "A") _ "#" _ ..Held(tTable, "B") _ "#" _ ..Held(tTable, "C")
    Do $$$AssertEquals(tBefore, "10%|""q""|9#10%|""" _ tLong _ """|9#10%|.5|.5", "the three fields hold a quoted text, a quoted text of 130 characters, as a classic page may leave one, and a number below 1, field C with an average size below 1")
    Set tConfirm = $ClassMethod(..#FIXED, "Agent", ..#FIELDTOOL, "A", {"Table": (tTable), "Selectivity": "25%"}, , ..#FIXTURE)
    Set tStatus = $ClassMethod(..#FIXED, "Act", ..#FIELDSCREEN, "set-selectivity", $ClassMethod(..#FIXED, "Id", tTable, "B"), {"Selectivity": "25%"}, , .tAnswer)
    Set tStatus = tStatus _ "|" _ $ClassMethod(..#FIXED, "Act", ..#FIELDSCREEN, "set-selectivity", $ClassMethod(..#FIXED, "Id", tTable, "C"), {"Selectivity": "25%"}, , .tAnswer)
    Do $$$AssertEquals(tConfirm _ "|" _ tStatus, "200 |200|200", "the agent's set and the screen's two sets are accepted")
    Do $$$AssertEquals(..Held(tTable, "A") _ "#" _ ..Held(tTable, "B") _ "#" _ ..Held(tTable, "C"), tBefore, "each outlier selectivity, outlier value and average size reads byte for byte as before")
    Do $$$AssertEquals(..Plain(tTable, "A") _ "|" _ ..Plain(tTable, "B") _ "|" _ ..Plain(tTable, "C"), "q|" _ tLong _ "|.5", "and each is answered as plain text")
    Do $$$AssertEquals($ClassMethod(..#FIXED, "Restore", tTable) _ "|" _ $ClassMethod(..#FIXED, "Stats", tTable), "200 |collected 5 0", "Clear fixed statistics restores the table")
}

/// <p>A set the instance refuses, or raises, after the collected statistics were saved as fixed answers 409 <code>SQL.TABLE.VENDOR</code> with the ruled
/// sentence for it as its reason, the instance's message and <code>statisticsFixed</code> in <code>detail</code>, from the port and from the agent's confirm,
/// and the table then reads fixed. A refusal that saved nothing keeps the plain sentence (<class>OcuPilot.Test.SqlIndexRebuild</class> pins it).</p>
/// <p>Mutation (Rule 19): <code>SqlPort.TableWritten</code> answers the plain sentence for a set that saved the statistics -> the reason assertions go red;
/// <code>SqlPort.SettingCall</code>'s <code>Catch</code> rethrows -> the raise leg goes red.</p>
Method TestASetThatFailsAfterTheStatisticsWereSavedSaysSo()
{
    Set tSentence = "The table's collected statistics were saved as its fixed statistics, but the new value was not set."
    Do $$$AssertEquals(##class(OcuPilot.Api.AtelierError).#REASONTABLESETUNAPPLIED, tSentence, "the sentence is the ruled one")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 1, 5, .tRefused), "the first probe table is created")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 2, 7, .tAgent), "the second is created")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "Table", ..#NAMESPACE, 3, 6, .tRaised), "the third is created")
    For tTable = tRefused, tAgent, tRaised {
        Do $ClassMethod(..#READS, "Statistics", "collect", tTable)
    }
    Do $ClassMethod(..#SEAM, "BadMap")
    Set tVerdict = $ClassMethod(..#FIXED, "Invoke", "SETMAPSIZE", $ClassMethod(..#FIXED, "Id", tRefused, "IdxB"), {"SizeMB": "3"}, .tFault)
    Do $$$AssertEquals(tVerdict _ "|" _ $Select($IsObject($Get(tFault)): tFault.reason _ "|" _ tFault.detail.statisticsFixed _ "|" _ (tFault.detail.message '= "") _ "|" _ (tFault.reason '[ tFault.detail.message), 1: ""), "409 SQL.TABLE.VENDOR|" _ tSentence _ "|1|1|1", "the port's refusal says so, with the instance's message in detail alone")
    Do $$$AssertEquals($ClassMethod(..#FIXED, "Stats", tRefused), "fixed 5 1", "and the table's collected statistics are its fixed ones now")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set ^||OcuPilotDatabaseWritePort = ..#FIXTURE
    Set tSC = $ClassMethod("OcuPilot.Test.SqlIndexRebuild", "Mint", ..#MAPTOOL, "IdxB", {"Table": (tAgent), "Map": "IdxB", "SizeMB": 3}, .tProposal, .tHttp, .tProblem)
    Do $$$AssertStatusOK(tSC, "the map size's proposal is minted: " _ $Get(tProblem))
    If '$IsObject($Get(tProposal)) Quit
    Set tSC = ##class(OcuPilot.Test.DatabaseConfirm).Confirm(tProposal.%Get("proposalId"), "", $Username, .tResult, .tHttp, .tCode, .tDetail, .tReason)
    Do $$$AssertEquals(+$Get(tHttp) _ " " _ $Get(tCode) _ "|" _ $Get(tReason), "409 SQL.TABLE.VENDOR|" _ tSentence, "the agent's confirm is refused with the same code and the same sentence as its outcome")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Throw")
    Set tVerdict = $ClassMethod(..#FIXED, "Invoke", "SETSELECTIVITY", $ClassMethod(..#FIXED, "Id", tRaised, "B"), {"Selectivity": "25%"}, .tFault)
    Do $$$AssertEquals(tVerdict _ "|" _ $Select($IsObject($Get(tFault)): tFault.reason _ "|" _ tFault.detail.statisticsFixed _ "|" _ (tFault.detail.message '= ""), 1: ""), "409 SQL.TABLE.VENDOR|" _ tSentence _ "|1|1", "a setter that raises is refused the same way, with the raise in detail")
    Do $$$AssertEquals($ClassMethod(..#FIXED, "Stats", tRaised), "fixed 6 1", "and that table's statistics are fixed too")
    For tTable = tRefused, tAgent, tRaised {
        Do $ClassMethod(..#FIXED, "Restore", tTable)
    }
}

}
