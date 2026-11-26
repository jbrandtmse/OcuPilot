/// <p>Pins Story 21.27's three writes on both permitted callers (AC1, AC2; AD-4, AD-6, AD-7, AD-21, AD-51, AD-53, AD-58): the namespace's statements gathered
/// by the list's Gather statements and by the agent's confirmed proposal, each of the five reports run by both, the list's rows equal to the agent's read
/// and to a bound read of the vendor's own table, a report replacing only its own rows, a purge removing both stores of the namespace and no other's, the
/// refusals before any call (a report with nothing gathered, a purge with nothing to purge), each skip flag reaching its position of the vendor's call, a proposal whose analysis changed
/// after it was minted closed target-changed, the instance's own refusal answered 409 <code>SQL.INDEXANALYSIS.VENDOR</code> with its message in
/// <code>detail</code> alone, a namespace whose analysis lock another process holds answered 409 <code>SQL.INDEXANALYSIS.BUSY</code> with nothing called,
/// and the lock released on every exit.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, which holds
/// <code>%Development:USE</code> and WRITE on <code>USER</code>'s and <code>HSCUSTOM</code>'s routines databases, a <code>USER</code> namespace, and
/// <parameter>ARMINGVARIABLE</parameter> reading <code>1</code>, because a gathering replaces every statement of a namespace and a purge removes every
/// result of it, which a test cannot confine to its own objects. It runs on a throwaway container only, makes <class>OcuPilot.Test.SqlTuningProbe</class>'s
/// analysis objects and clears both namespaces' analysis when each test ends.</p>
Class OcuPilot.Test.SqlIndexAnalysisWrite Extends %UnitTest.TestCase
{

/// <p>The environment variable that arms this class, set by <file>scripts/ci-throwaway.sh</file> alone.</p>
Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_CONFIG_SETTINGS";

Parameter PROBE = "OcuPilot.Test.SqlTuningProbe";

Parameter PORT = "OcuPilot.Port.SqlPort";

Parameter FIXTURE = "OcuPilot.Test.SqlTuningPortFixture";

Parameter SEAM = "OcuPilot.Test.SqlTuningGateSeam";

Parameter AGENT = "OcuPilot.Test.LicenseProbe";

Parameter VERDICT = "OcuPilot.Test.EcpDataServerWrite";

Parameter WRITE = "OcuPilot.Test.SqlStatementWrite";

Parameter NAMESPACE = "USER";

/// <p>The second namespace whose analysis a purge of <parameter>NAMESPACE</parameter> leaves.</p>
Parameter OTHERNAMESPACE = "HSCUSTOM";

Parameter SCREEN = "explorer.sqlindexanalysis";

Parameter LIST = "OcuPilot.Screen.Descriptor.ExplorerSqlIndexAnalysis";

Parameter GATHER = "OcuPilot.Screen.Tool.ExplorerSqlIndexAnalysisGather";

Parameter RUN = "OcuPilot.Screen.Tool.ExplorerSqlIndexAnalysisRun";

Parameter PURGE = "OcuPilot.Screen.Tool.ExplorerSqlIndexAnalysisPurge";

Parameter ERROR = "OcuPilot.Api.AtelierError";

Parameter LIMITS = "OcuPilot.Kernel.Agent.Limits";

/// <p>The governance policy as it stood before each test.</p>
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
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlIndexAnalysisWrite gathers the SQL statements of " _ ..#NAMESPACE _ " and " _ ..#OTHERNAMESPACE _ " again and purges their index analysis, and runs on a throwaway container only. " _ ..#ARMINGVARIABLE _ " does not read 1 here, so nothing was changed.")
    }
    Quit $$$OK
}

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Proposal.Caller).Clear()
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Do ##class(OcuPilot.Test.ProposalFixture).Clear()
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Kill ..PreparedPolicy
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Snapshot(.tRows)
    If $$$ISERR(tSC) Quit tSC
    Merge ..PreparedPolicy = tRows
    Set ..PreparedPolicyTaken = 1
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Clear()
    If $$$ISERR(tSC) Quit tSC
    Kill tSettings
    Set tSettings($Parameter(..#PURGE, "TOOLNAME")) = "enabled"
    Set tSC = ##class(OcuPilot.Test.GovernanceFixture).Apply("", .tSettings)
    If $$$ISERR(tSC) Quit tSC
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeAnalysis", ..#NAMESPACE), "the probe's table and class are created in " _ ..#NAMESPACE)
    Quit $$$OK
}

Method OnAfterOneTest() As %Status
{
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAnalysis", ..#NAMESPACE), "the probe's table, class and analysis of " _ ..#NAMESPACE _ " are removed")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAnalysis", ..#OTHERNAMESPACE), "and the analysis of " _ ..#OTHERNAMESPACE)
    Set tCounts = $ClassMethod(..#PROBE, "AnalysisCounts", ..#NAMESPACE)
    Do $$$AssertEquals(tCounts.%Get("IU") + tCounts.%Get("TS") + tCounts.%Get("TI") + tCounts.%Get("JI") + tCounts.%Get("OI"), 0, "none of the probe table's report rows is left")
    Kill ^||OcuPilotDatabaseWritePort, ^||OcuPilotSqlTuningVendorArmed, ^||OcuPilotSqlTuningVendor, ^||OcuPilotSqlTuningVendorFail
    If $Data(^OcuPilotTestAnalysisLock("held")) && '$Data(^OcuPilotTestAnalysisLock("release")) {
        Set ^OcuPilotTestAnalysisLock("release") = 1
        Hang 0.5
    }
    Kill ^OcuPilotTestAnalysisLock
    Do ##class(OcuPilot.Test.ScreenGate).Reset()
    Do $ClassMethod(..#SEAM, "Reset")
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
    If '..PreparedPolicyTaken Quit $$$OK
    Kill tRows
    Merge tRows = ..PreparedPolicy
    Quit ##class(OcuPilot.Test.GovernanceFixture).Restore(.tRows)
}

/// <p>The screen action <var>pAction</var> on <code>*</code> with the values <var>pValues</var>, through the shipped route in <var>pNamespace</var>: the
/// answer's parsed envelope in <var>pAnswer</var>, answering the HTTP status.</p>
ClassMethod Act(pAction As %String, pValues As %DynamicObject = "", pNamespace As %String = {..#NAMESPACE}, Output pAnswer As %DynamicObject) As %Integer
{
    Set tBody = {"action": (pAction), "id": "*"}
    If $IsObject(pValues) Do tBody.%Set("values", pValues)
    Set tSC = ##class(OcuPilot.Test.Http).MakeRequest("POST", "/screens/" _ ..#SCREEN _ "/action?ns=" _ pNamespace, .tStatus, .pAnswer, tBody.%ToJSON())
    Quit $Select($$$ISOK(tSC): tStatus, 1: 0)
}

/// <p>The agent's proposal of tool <var>pTool</var> on <code>*</code> with the arguments <var>pArgs</var>, minted in <var>pNamespace</var> and, when
/// <var>pConfirm</var> is 1, confirmed: <code>mint &lt;http&gt; &lt;problem&gt;</code> when the mint refused, else the confirm's <code>http code</code>. The
/// proposal is in <var>pProposal</var> and the confirm's answer in <var>pResult</var>.</p>
ClassMethod Agent(pTool As %String, pArgs As %DynamicObject, pConfirm As %Boolean = 1, pNamespace As %String = {..#NAMESPACE}, Output pProposal As %DynamicObject, Output pResult As %DynamicObject) As %String
{
    Do ##class(OcuPilot.Kernel.Scope).Set(pNamespace)
    Set ^||OcuPilotDatabaseWritePort = $Parameter(pTool, "PORTCLASS")
    Do pArgs.%Set("Target", "*", "string")
    Set tSC = $ClassMethod(..#AGENT, "Mint", pTool, "*", pArgs, .pProposal, .tHttp, .tProblem)
    If $$$ISERR(tSC) Quit "mint " _ tHttp _ " " _ tProblem
    If 'pConfirm Quit "minted"
    Quit $ClassMethod(..#AGENT, "Confirm", pProposal, .pResult)
}

/// <p>The vendor's own counts for the probe table, or for every table when <var>pAllTables</var> is 1, and the namespace's gathered statements, as
/// <code>statements|IU|TS|TI|JI|OI</code>.</p>
ClassMethod Counts(pNamespace As %String = {..#NAMESPACE}, pAllTables As %Boolean = 0) As %String
{
    Set tCounts = $ClassMethod(..#PROBE, "AnalysisCounts", pNamespace, pAllTables)
    Quit tCounts.%Get("Statements") _ "|" _ tCounts.%Get("IU") _ "|" _ tCounts.%Get("TS") _ "|" _ tCounts.%Get("TI") _ "|" _ tCounts.%Get("JI") _ "|" _ tCounts.%Get("OI")
}

/// <p>The port's <code>ANALYSIS</code> read of <var>pNamespace</var> as <code>Statements|IndexUsage|TableScans|TempIndices|JoinIndices|OutlierIndices</code>,
/// through the shipped port.</p>
ClassMethod Read(pNamespace As %String = {..#NAMESPACE}) As %String
{
    Kill tQuery
    Set tQuery("namespace") = pNamespace
    Set tQuery("id") = "*"
    Set tSC = $ClassMethod(..#PORT, "Invoke", "IndexAnalysis", "ANALYSIS", .tQuery, "", .tAnswer, .tHttp, .tFault)
    If '$IsObject($Get(tAnswer)) Quit "(" _ $Get(tHttp) _ ")"
    Quit tAnswer.Statements _ "|" _ tAnswer.IndexUsage _ "|" _ tAnswer.TableScans _ "|" _ tAnswer.TempIndices _ "|" _ tAnswer.JoinIndices _ "|" _ tAnswer.OutlierIndices
}

/// <p>The report values the screen sends for <var>pCode</var>, with the system classes and INSERT statements skipped and IDKEY indices skipped for
/// the index usage report.</p>
ClassMethod RunValues(pCode As %String) As %DynamicObject
{
    Quit {"Report": (pCode), "SkipSystem": "true", "SkipInserts": "true", "SkipIdKeys": "true"}
}

/// <p>AC1, AC2. The list's Gather statements gathers the namespace's statements, which the port reads back as a count, and the list's Run report runs
/// each of the five reports, each answering 200 and, for the four the probe's statements feed, rows for the probe table; a report replaces its own rows alone,
/// so the index usage rows read after the other reports ran are still there, and a table scan report run again leaves the same rows.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.AnalysisCall</code> calls <code>tableScans</code> for every report -> the index usage leg goes red.</p>
Method TestTheScreenGathersAndRunsEachReport()
{
    Set tStatus = ..Act("gather", {"SkipSystem": "true", "SkipInserts": "true"}, , .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ $Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.id, 1: ""), "200|updated|sql-index-analysis|*", "the screen's gather answers: " _ $Select($IsObject(tAnswer): tAnswer.%ToJSON(), 1: ""))
    Set tCounts = ..Counts()
    Do $$$AssertTrue(+$Piece(tCounts, "|", 1) > 0, "the namespace holds gathered statements: " _ tCounts)
    Do $$$AssertEquals($Piece(tCounts, "|", 2, 6), "0|0|0|0|0", "and no report row of the probe table")
    Do $$$AssertEquals(..Read(), ..Counts(, 1), "the port's read answers the namespace's gathered statements and report rows as the vendor's tables hold them")
    Set tStatus = ..Act("run", ..RunValues("IU"), , .tAnswer)
    Do $$$AssertEquals(tStatus, 200, "the index usage report answers")
    Set tAfterIU = ..Counts()
    Do $$$AssertTrue(($Piece(tAfterIU, "|", 2) > 0) && ($Piece(tAfterIU, "|", 3) = 0), "it holds the probe table's indices and no table scan: " _ tAfterIU)
    For tCode = "TS", "TI", "JI", "OI" {
        Set tStatus = ..Act("run", ..RunValues(tCode), , .tAnswer)
        Do $$$AssertEquals(tStatus, 200, tCode _ ": the report answers")
    }
    Set tAll = ..Counts()
    Do $$$AssertEquals($Piece(tAll, "|", 2), $Piece(tAfterIU, "|", 2), "a report replaces its own rows alone: the index usage rows are still there")
    Do $$$AssertTrue(($Piece(tAll, "|", 3) > 0) && ($Piece(tAll, "|", 4) > 0) && ($Piece(tAll, "|", 5) > 0), "and the table scan, temporary index and join reports hold the probe table's rows: " _ tAll)
    Do $$$AssertEquals(..Read(), ..Counts(, 1), "and the port's read answers each report's rows in the namespace")
    Set tStatus = ..Act("run", ..RunValues("TS"), , .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..Counts(), "200|" _ tAll, "a report run again leaves the same rows")
}

/// <p>AC1, AC2. The agent's confirmed gather, with no choice sent, skips the system classes and INSERT statements as the classic page's boxes start, and its
/// confirmed reports each answer and hold the probe table's rows; a flag the agent sends is the one the port is given.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.AnalysisValues</code> sends an absent flag as 0 -> the recorded values assertion goes red.</p>
Method TestTheAgentGathersAndRunsEachReportAndAnAbsentFlagIsTrue()
{
    Set tOutcome = ..Agent(..#GATHER, {}, 1, , .tProposal, .tResult)
    Do $$$AssertEquals(tOutcome _ "|" _ $ClassMethod(..#VERDICT, "Verdict", $Get(tResult)), "200 |nothingSent", "the agent's confirmed gather answers: " _ tOutcome)
    Do $$$AssertTrue(+$Piece(..Counts(), "|", 1) > 0, "and the namespace holds gathered statements")
    For tCode = "IU", "TS", "TI", "JI", "OI" {
        Set tOutcome = ..Agent(..#RUN, {"Report": (tCode)}, 1, , .tProposal, .tResult)
        Do $$$AssertEquals(tOutcome, "200 ", tCode _ ": the agent's confirmed report answers: " _ tOutcome)
    }
    Set tAll = ..Counts()
    Do $$$AssertTrue(($Piece(tAll, "|", 2) > 0) && ($Piece(tAll, "|", 3) > 0) && ($Piece(tAll, "|", 4) > 0) && ($Piece(tAll, "|", 5) > 0), "each report holds the probe table's rows: " _ tAll)
    Do $ClassMethod(..#SEAM, "Reset")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = "*"
    Set tSC = $ClassMethod(..#FIXTURE, "Invoke", "IndexAnalysis", "GATHER", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Set tQuery("SkipSystem") = "false"
    Set tQuery("SkipInserts") = "true"
    Set tQuery("Report") = "TS"
    Set tSC = $ClassMethod(..#FIXTURE, "Invoke", "IndexAnalysis", "RUNREPORT", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($ClassMethod(..#SEAM, "StatementCalls"), "GATHER|{""SkipSystem"":1,""SkipInserts"":1};RUNREPORT|{""Report"":""TS"",""SkipSystem"":0,""SkipInserts"":1,""SkipIdKeys"":1}", "an absent flag is sent as 1 and a flag sent false as 0")
}

/// <p>AC2. Each skip flag sent false, the other two true, reaches the vendor's positional argument the classic page gives it, for the gather and each of the
/// five reports, observed on the vendor call without making it (so <code>SkipSystem</code> false, which takes a minute to gather, is covered too).</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.AnalysisCall</code> reads <code>tInserts</code> from the <code>SkipIdKeys</code> key and
/// <code>tIdKeys</code> from the <code>SkipInserts</code> key -> the inserts and ID key legs go red; it swaps <code>tSystem</code> and <code>tInserts</code>
/// the same way -> the system and inserts legs go red.</p>
Method TestEachSkipFlagReachesItsPositionOfTheVendorCall()
{
    Set tClears = "clearSQLStatements(USER);clearSQLAnalysisDB(USER)"
    Set ^||OcuPilotSqlTuningVendorArmed = 1
    For tFlag = "SkipSystem", "SkipInserts", "SkipIdKeys" {
        Set tS = (tFlag '= "SkipSystem")
        Set tI = (tFlag '= "SkipInserts")
        Set tK = (tFlag '= "SkipIdKeys")
        Kill ^||OcuPilotSqlTuningVendor
        Set tValues = {"SkipSystem": (tS), "SkipInserts": (tI), "SkipIdKeys": (tK)}
        Set tSC = $ClassMethod(..#FIXTURE, "StatementCall", "GATHER", "", ..#NAMESPACE, tValues.%ToJSON())
        Do $$$AssertEquals(..Recorded(), tClears _ ";getAllSQLStmts(1," _ tS _ "," _ tI _ ",0,0)", tFlag _ " false: the gather's vendor calls")
        For tCase = $ListBuild("IU", "indexUsage(1,1,0," _ tS _ "," _ tK _ "," _ tI _ ",0)"), $ListBuild("TS", "tableScans(1,0," _ tS _ "," _ tI _ ",0)"), $ListBuild("TI", "tempIndices(1,0," _ tS _ "," _ tI _ ",0)"), $ListBuild("JI", "joinIndices(1,0," _ tS _ "," _ tI _ ",0)"), $ListBuild("OI", "outlierIndices(1,0," _ tS _ "," _ tI _ ",0)") {
            Kill ^||OcuPilotSqlTuningVendor
            Do tValues.%Set("Report", $List(tCase, 1), "string")
            Set tSC = $ClassMethod(..#FIXTURE, "StatementCall", "RUNREPORT", "", ..#NAMESPACE, tValues.%ToJSON())
            Do $$$AssertEquals(..Recorded(), $List(tCase, 2), tFlag _ " false: the " _ $List(tCase, 1) _ " report's vendor call")
        }
    }
    Kill ^||OcuPilotSqlTuningVendorArmed, ^||OcuPilotSqlTuningVendor
}

/// <p>The vendor calls recorded since the last <code>Kill</code> of <code>^||OcuPilotSqlTuningVendor</code>, in order, joined by <code>;</code>.</p>
ClassMethod Recorded() As %String
{
    Set tText = ""
    For tIndex = 1:1:+$Get(^||OcuPilotSqlTuningVendor) Set tText = tText _ $Select(tIndex > 1: ";", 1: "") _ $Get(^||OcuPilotSqlTuningVendor(tIndex))
    Quit tText
}

/// <p>AC2. The same two flags sent false to the instance itself: a gather that includes INSERT statements reads more statements than one that skips them,
/// and an index usage report that includes the IDKEY indices holds more of the probe table's rows than one that skips them.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.AnalysisCall</code> reads <code>tInserts</code> from the <code>SkipIdKeys</code> key and
/// <code>tIdKeys</code> from the <code>SkipInserts</code> key -> both comparisons go red.</p>
Method TestAFlagSentFalseChangesWhatTheInstanceReads()
{
    Set tStatus = ..Act("gather", {"SkipSystem": "true", "SkipInserts": "true"})
    Set tSkipped = +$Piece(..Counts(), "|", 1)
    Set tStatus = tStatus _ "|" _ ..Act("gather", {"SkipSystem": "true", "SkipInserts": "false"})
    Set tIncluded = +$Piece(..Counts(), "|", 1)
    Do $$$AssertEquals(tStatus, "200|200", "both gathers answer")
    Do $$$AssertTrue((tSkipped > 0) && (tIncluded > tSkipped), "a gather that includes INSERT statements reads more: " _ tSkipped _ " then " _ tIncluded)
    Set tStatus = ..Act("run", ..RunValues("IU"))
    Set tWithout = +$Piece(..Counts(), "|", 2)
    Set tValues = ..RunValues("IU")
    Do tValues.%Set("SkipIdKeys", "false", "string")
    Set tStatus = tStatus _ "|" _ ..Act("run", tValues)
    Set tWith = +$Piece(..Counts(), "|", 2)
    Do $$$AssertEquals(tStatus, "200|200", "both index usage reports answer")
    Do $$$AssertTrue((tWithout > 0) && (tWith > tWithout), "a report that includes the IDKEY indices holds more of the probe table's rows: " _ tWithout _ " then " _ tWith)
}

/// <p>AC1. The list's rows are the agent's <code>explorer.sqlindexanalysis.read</code> rows under the same view and the instance's own: the rows of the probe
/// table the list shows equal a bound read of the vendor's table that leaves out a join or outlier row with an exact match, which the probe's join on an
/// indexed column makes exist, and the cap is reported (AD-36): a cap of one answers one row with <code>truncated</code> set and a cap above the count every
/// row with it unset.</p>
/// <p>Mutation (Rule 19): <parameter>OcuPilot.Port.AtelierPort.CATALOGINDEXANALYSISQUERY</parameter> drops <code>JoinIndexFlag &lt; 4</code> -> the join
/// count assertion goes red; the row map drops <code>sqltext</code> from the statement -> the masking in <class>OcuPilot.Test.SqlIndexAnalysisRead</class> goes red.</p>
Method TestTheListAndTheAgentsReadAnswerTheSameRows()
{
    Set tStatus = ..Act("gather", {"SkipSystem": "true", "SkipInserts": "true"})
    For tCode = "IU", "TS", "TI", "JI", "OI" Set tStatus = ..Act("run", ..RunValues(tCode))
    Set tDirect = ..DirectListed(..#NAMESPACE, .tJoinAll, .tJoinListed)
    Do $$$AssertTrue((tDirect > 0) && (tJoinAll > tJoinListed) && (tJoinListed > 0), "the vendor's table holds exact-match join rows the classic page leaves out: " _ tJoinAll _ " rows, " _ tJoinListed _ " not exact")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#LIST, 1000, .tScreen, .tHttp, .tFault)
    Do $$$AssertEquals($Select($$$ISOK(tSC): tHttp, 1: 0), 200, "the screen's read answers: " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""))
    If $$$ISERR(tSC) || '$IsObject(tScreen) Quit
    Set tRows = ..ProbeRows(tScreen)
    Do $$$AssertEquals(tRows.%Size(), tDirect, "the list shows the probe table's rows as a bound read of the vendor's table counts them")
    Set tJoin = 0
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.Report = "Missing join index" Set tJoin = tJoin + 1
    }
    Do $$$AssertEquals(tJoin, tJoinListed, "and its join rows are the not-exact ones")
    Set tSC = ##class(OcuPilot.Test.ProposalFixture).SeedTurn($Username, "completed", .tTurnKey)
    Do $$$AssertStatusOK(tSC, "a completed turn is seeded")
    Set tUse = {"type": "tool_use", "id": "toolu_sqlindexanalysis"}
    Do tUse.%Set("name", ##class(OcuPilot.Screen.Tool.Registry).WireName("explorer.sqlindexanalysis.read"), "string")
    Do tUse.%Set("input", {"filter": (##class(OcuPilot.Test.SqlTuningProbe).#ANALYSISSCHEMA), "maxRows": 1000})
    Set tSC = ##class(OcuPilot.Kernel.Agent.Dispatch).Answer(tTurnKey, $Username, "", [(tUse)], ..#LIMITS, .tResults, .tNames, 0, 0, .tDetails)
    Do $$$AssertStatusOK(tSC, "the agent's read is dispatched")
    If $$$ISERR(tSC) Quit
    Set tAgent = ##class(%DynamicObject).%FromJSON(tResults.%Get(0).%Get("content"))
    Do $$$AssertEquals(tResults.%Get(0).%Get("is_error"), 0, "and answers rows")
    Set tView = ##class(OcuPilot.Screen.Read).ApplyView(tScreen.rows, ..Declaration().read, ##class(OcuPilot.Test.SqlTuningProbe).#ANALYSISSCHEMA)
    Do $$$AssertEquals(tView.%ToJSON(), tAgent.rows.%ToJSON(), "the rows the agent's filter keeps are the screen's rows under the same view")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#LIST, 1, .tCut, .tHttp, .tFault)
    Do $$$AssertEquals($Select($$$ISOK(tSC) && $IsObject(tCut): tHttp _ "|" _ tCut.rows.%Size() _ "|" _ tCut.truncated, 1: ""), "200|1|1", "a cap of one row is reported as truncation")
    Set tSC = ##class(OcuPilot.Screen.Read).Execute(..#LIST, 100000, .tAll, .tHttp, .tFault)
    Do $$$AssertEquals($Select($$$ISOK(tSC) && $IsObject(tAll): tHttp _ "|" _ (tAll.rows.%Size() '< tDirect) _ "|" _ tAll.truncated, 1: ""), "200|1|0", "a cap above the count answers every row and reports no cut")
    Do ##class(OcuPilot.Test.ProposalFixture).RemoveSeeded(.tSeeded)
}

/// <p>The list's descriptor declaration.</p>
ClassMethod Declaration() As %DynamicObject
{
    Do $ClassMethod(..#LIST, "DeclarationJson", .tDeclaration)
    Quit tDeclaration
}

/// <p>The rows of <var>pAnswer</var>, a screen read's answer, whose schema is the probe's.</p>
ClassMethod ProbeRows(pAnswer As %DynamicObject) As %DynamicArray
{
    Set tRows = []
    If '$IsObject(pAnswer) || (pAnswer.%GetTypeOf("rows") '= "array") Quit tRows
    Set tIterator = pAnswer.rows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("Schema") = ##class(OcuPilot.Test.SqlTuningProbe).#ANALYSISSCHEMA Do tRows.%Push(tRow)
    }
    Quit tRows
}

/// <p>The probe table's rows in the vendor's own table as the list shows them, from a bound read that leaves out an exact join or outlier match, and,
/// in <var>pJoinAll</var> and <var>pJoinListed</var>, its join rows with and without that exclusion.</p>
ClassMethod DirectListed(pNamespace As %String, Output pJoinAll As %Integer, Output pJoinListed As %Integer) As %Integer
{
    Set (tCount, pJoinAll, pJoinListed) = -1
    Set tSchema = ##class(OcuPilot.Test.SqlTuningProbe).#ANALYSISSCHEMA
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tSC = tStatement.%Prepare("SELECT COUNT(*), COUNT(CASE WHEN OptionName = 'JI' THEN 1 END) FROM %SYS_PTools.UtilSQLAnalysisDB WHERE SchemaName = ? AND (OptionName IN ('IU', 'TS', 'TI') OR (OptionName = 'JI' AND JoinIndexFlag < 4) OR (OptionName = 'OI' AND OutlierIndexFlag < 4))", 0)
        If $$$ISOK(tSC) {
            Set tResult = tStatement.%Execute(tSchema)
            If tResult.%Next() {
                Set tCount = tResult.%GetData(1)
                Set pJoinListed = tResult.%GetData(2)
            }
        }
        Set tStatement = ##class(%SQL.Statement).%New()
        Set tSC = tStatement.%Prepare("SELECT COUNT(*) FROM %SYS_PTools.UtilSQLAnalysisDB WHERE SchemaName = ? AND OptionName = 'JI'", 0)
        If $$$ISOK(tSC) {
            Set tResult = tStatement.%Execute(tSchema)
            If tResult.%Next() Set pJoinAll = tResult.%GetData(1)
        }
        Set (tResult, tStatement) = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tCount
}

/// <p>AC2. A report with nothing gathered is refused before any call, on both callers, with its ruled sentence: the vendor would gather the statements itself,
/// with the report's own choices, so the namespace's statements are still none after the refusals.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Screen.Tool.ExplorerSqlIndexAnalysisRun.Holds</code> answers 1 -> the refusals go red and the report gathers.</p>
Method TestAReportWithNothingGatheredIsRefusedBeforeAnyCall()
{
    Do $$$AssertEquals(..Counts(), "0|0|0|0|0|0", "nothing is gathered in " _ ..#NAMESPACE _ " to begin with")
    Set tStatus = ..Act("run", ..RunValues("TS"), , .tAnswer)
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Verdict", tStatus, tAnswer) _ "|" _ $Select($IsObject(tAnswer) && $IsObject(tAnswer.detail): tAnswer.detail.problem, 1: ""), "400 TOOL.ARGUMENTS|" _ $Parameter(..#ERROR, "REASONINDEXANALYSISNOSTATEMENTS"), "the screen's run is refused with the ruled sentence")
    Set tOutcome = ..Agent(..#RUN, {"Report": "TS"})
    Do $$$AssertEquals(tOutcome, "mint 400 " _ $Parameter(..#ERROR, "REASONINDEXANALYSISNOSTATEMENTS"), "and so is the agent's, at the mint")
    Do $$$AssertEquals(..Counts(), "0|0|0|0|0|0", "and nothing was gathered or run")
}

/// <p>AC2. A purge, by the list and by the agent, removes the namespace's gathered statements and every report's rows and no other namespace's; a second purge
/// is refused before any call with its ruled sentence on both callers, and the purge tool, whose key ships disabled, is the agent's only through its stored
/// setting.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Screen.Tool.ExplorerSqlIndexAnalysisPurge.Holds</code> answers 1 -> the nothing-to-purge assertions go red;
/// <code>OcuPilot.Port.SqlPort.AnalysisCall</code> clears the statements alone -> the report rows assertion goes red.</p>
Method TestAPurgeRemovesTheNamespacesAnalysisOnBothCallers()
{
    Do ..GatherAndRun(..#NAMESPACE)
    Do ..GatherAndRun(..#OTHERNAMESPACE)
    Set tOther = ..Read(..#OTHERNAMESPACE)
    Do $$$AssertTrue((+$Piece(..Read(), "|", 1) > 0) && (+$Piece(tOther, "|", 1) > 0), "both namespaces hold gathered statements: " _ ..Read() _ " and " _ tOther)
    Set tStatus = ..Act("purge", , , .tAnswer)
    Do $$$AssertEquals(tStatus _ "|" _ ..Read() _ "|" _ ..Counts(), "200|0|0|0|0|0|0|0|0|0|0|0|0", "the list's purge removes the statements and every report's rows of " _ ..#NAMESPACE)
    Do $$$AssertEquals(..Read(..#OTHERNAMESPACE), tOther, "and leaves the other namespace's")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.action _ "|" _ tAnswer.target.type _ "|" _ tAnswer.target.id, 1: ""), "updated|sql-index-analysis|*", "its answer names the namespace's analysis")
    Set tStatus = ..Act("purge", , , .tAnswer)
    Do $$$AssertEquals($ClassMethod(..#WRITE, "Verdict", tStatus, tAnswer) _ "|" _ $Select($IsObject(tAnswer) && $IsObject(tAnswer.detail): tAnswer.detail.problem, 1: ""), "400 TOOL.ARGUMENTS|" _ $Parameter(..#ERROR, "REASONINDEXANALYSISNOROWS"), "a second purge is refused with its sentence")
    Set tOutcome = ..Agent(..#PURGE, {})
    Do $$$AssertEquals(tOutcome, "mint 400 " _ $Parameter(..#ERROR, "REASONINDEXANALYSISNOROWS"), "and so is the agent's, at the mint")
    Do ..GatherAndRun(..#NAMESPACE)
    Set tOutcome = ..Agent(..#PURGE, {}, 1, , .tProposal, .tResult)
    Do $$$AssertEquals(tOutcome _ "|" _ ..Read() _ "|" _ ..Read(..#OTHERNAMESPACE), "200 |0|0|0|0|0|0|" _ tOther, "the agent's confirmed purge removes both stores of the namespace and no other's: " _ tOutcome)
    Do $$$AssertEquals($ClassMethod(..#VERDICT, "Verdict", $Get(tResult)), "nothingSent", "and its read-back reads nothing sent")
}

/// <p>The statements of <var>pNamespace</var> gathered and, in <code>USER</code>, every report run, through the vendor's own calls, as a test's precondition.</p>
ClassMethod GatherAndRun(pNamespace As %String)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ##class(%SYS.PTools.UtilSQLAnalysis).clearSQLStatements(pNamespace)
        Do ##class(%SYS.PTools.UtilSQLAnalysis).clearSQLAnalysisDB(pNamespace)
        Do ##class(%SYS.PTools.UtilSQLAnalysis).getAllSQLStmts(1, 1, 1, 0, 0)
        Do ##class(%SYS.PTools.UtilSQLAnalysis).tableScans(1, 0, 1, 1, 0)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>The index usage report run in <var>pNamespace</var> through the vendor's own call, outside the product's write path, so the namespace's analysis moves
/// under a proposal already minted. It includes the IDKEY indices, which a proposed index usage run skips, so a confirm that ran anyway would leave fewer
/// rows than this run did.</p>
ClassMethod RunOutOfBand(pNamespace As %String)
{
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = pNamespace
        Do ##class(%SYS.PTools.UtilSQLAnalysis).indexUsage(1, 1, 0, 1, 0, 1, 0)
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
}

/// <p>AC2. The mint of each write calls nothing and changes no row; a proposal whose analysis changed after it was minted, a report run out of band, is
/// closed <code>PROPOSAL.TARGETCHANGED</code> at its confirm, and the analysis stays as it was moved; the cards state their consequence, a gather the
/// system classes' sentence only when it includes them.</p>
/// <p>Mutation (Rule 19): the tools' <code>FINGERPRINTSUBJECT</code> drops the report counts -> the confirm is not refused and the assertions go red.</p>
Method TestAChangedTargetRefusesTheConfirmAndTheMintCallsNothing()
{
    Do ..GatherAndRun(..#NAMESPACE)
    Set tBefore = ..Read()
    Set tOutcome = ..Agent(..#RUN, {"Report": "IU"}, 0, , .tRunProposal)
    Set tOutcome2 = ..Agent(..#GATHER, {"SkipSystem": false}, 0, , .tGatherProposal)
    Set tOutcome3 = ..Agent(..#PURGE, {}, 0, , .tPurgeProposal)
    Do $$$AssertEquals(tOutcome _ "|" _ tOutcome2 _ "|" _ tOutcome3 _ "|" _ ..Read(), "minted|minted|minted|" _ tBefore, "the three mints call nothing and change no row")
    Do $$$AssertEquals(##class(OcuPilot.Test.EcpSettingsWrite).Consequence(tRunProposal) _ "|" _ ##class(OcuPilot.Test.EcpSettingsWrite).Consequence(tGatherProposal) _ "|" _ ##class(OcuPilot.Test.EcpSettingsWrite).Consequence(tPurgeProposal), "SQL.INDEXANALYSIS.RUN|SQL.INDEXANALYSIS.GATHERSYSTEM|SQL.INDEXANALYSIS.PURGE", "the cards state their consequences, the gather's naming the system classes it includes")
    Do ..RunOutOfBand(..#NAMESPACE)
    Set tNow = ..Read()
    Do $$$AssertTrue(tNow '= tBefore, "a report is run out of band: " _ tNow)
    Set tConfirm = $ClassMethod(..#AGENT, "Confirm", tRunProposal, .tResult)
    Do $$$AssertEquals(tConfirm _ "|" _ ..Read(), "409 PROPOSAL.TARGETCHANGED|" _ tNow, "run: the confirm is refused target-changed and the analysis stays where it was moved: " _ tConfirm)
    Set tConfirm = $ClassMethod(..#AGENT, "Confirm", tGatherProposal, .tResult)
    Do $$$AssertEquals(tConfirm _ "|" _ ..Read(), "409 PROPOSAL.TARGETCHANGED|" _ tNow, "gather: the confirm is refused target-changed and the analysis stays where it was moved: " _ tConfirm)
    Set tConfirm = $ClassMethod(..#AGENT, "Confirm", tPurgeProposal, .tResult)
    Do $$$AssertEquals(tConfirm _ "|" _ ..Read(), "409 PROPOSAL.TARGETCHANGED|" _ tNow, "purge: the confirm is refused target-changed and the analysis stays where it was moved: " _ tConfirm)
}

/// <p>AC2. The instance's own refusal of each write is 409 <code>SQL.INDEXANALYSIS.VENDOR</code>, its ruled sentence on the wire and the instance's message in
/// <code>detail</code> alone, with one call made for each, and a call that raises is the internal fault; an error status from the vendor's own method is the
/// same refusal and no vendor call follows it; the lock is released after each, so the next call goes through.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.StatementWrite</code> puts the message in the reason -> the reason assertion goes red;
/// <code>OcuPilot.Port.SqlPort.AnalysisCall</code> makes the next call whatever the last one answered -> the gather's vendor status legs go red.</p>
Method TestTheInstancesRefusalIsTheVendorRefusalAndTheLockIsReleased()
{
    Do $ClassMethod(..#SEAM, "Refuse", "the analysis could not be completed")
    For tType = "GATHER", "RUNREPORT", "PURGEANALYSIS" {
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("id") = "*"
        Set tQuery("Report") = "TS"
        Set tSC = $ClassMethod(..#FIXTURE, "Invoke", "IndexAnalysis", tType, .tQuery, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code _ "|" _ tFault.reason, 1: ""), "409 SQL.INDEXANALYSIS.VENDOR|" _ $Parameter(..#ERROR, "REASONINDEXANALYSISVENDOR"), tType _ ": 409 with the ruled sentence")
        Do $$$AssertTrue($IsObject($Get(tFault)) && (tFault.detail.message [ "could not be completed") && (tFault.reason '[ "completed"), tType _ ": the instance's message is in detail alone")
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 3, "one call was made for each")
    Do $$$AssertEquals(..LockFree(..#NAMESPACE), 1, "and the namespace's analysis lock is free after them")
    Do $ClassMethod(..#SEAM, "Reset")
    Do $ClassMethod(..#SEAM, "Raise")
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = "*"
    Set tSC = $ClassMethod(..#FIXTURE, "Invoke", "IndexAnalysis", "GATHER", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "500 " _ ##class(OcuPilot.Api.Error).#INTERNAL, "a call that raises is the internal fault")
    Do $$$AssertEquals(..LockFree(..#NAMESPACE), 1, "and the lock is free after it")
    Do $ClassMethod(..#SEAM, "Reset")
    Set ^||OcuPilotSqlTuningVendorArmed = 1
    For tCase = $ListBuild("GATHER", "clearSQLAnalysisDB", "clearSQLStatements(USER);clearSQLAnalysisDB(USER)"), $ListBuild("RUNREPORT", "tableScans", "tableScans(1,0,1,1,0)"), $ListBuild("PURGEANALYSIS", "clearSQLStatements", "clearSQLStatements(USER)") {
        Set ^||OcuPilotSqlTuningVendorFail = $List(tCase, 2)
        Kill ^||OcuPilotSqlTuningVendor, tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("id") = "*"
        Set tQuery("Report") = "TS"
        Set tSC = $ClassMethod(..#FIXTURE, "Invoke", "IndexAnalysis", $List(tCase, 1), .tQuery, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code, 1: ""), "409 SQL.INDEXANALYSIS.VENDOR", $List(tCase, 1) _ ": an error status from the vendor's own call is the vendor refusal")
        Do $$$AssertTrue($IsObject($Get(tFault)) && (tFault.detail.message [ ("the vendor's " _ $List(tCase, 2) _ " failed")), $List(tCase, 1) _ ": with the vendor's message in detail")
        Do $$$AssertEquals(..Recorded(), $List(tCase, 3), $List(tCase, 1) _ ": no vendor call follows the one that failed")
    }
    Kill ^||OcuPilotSqlTuningVendorArmed, ^||OcuPilotSqlTuningVendorFail, ^||OcuPilotSqlTuningVendor
    Do $$$AssertEquals(..LockFree(..#NAMESPACE), 1, "and the lock is free after them")
}

/// <p>Whether the namespace's analysis lock is free for another process, asked by a job that tries to take it with no wait: <code>1</code> free,
/// <code>0</code> held.</p>
ClassMethod LockFree(pNamespace As %String) As %Integer
{
    Kill ^OcuPilotTestAnalysisLock("free")
    Job ##class(OcuPilot.Test.SqlIndexAnalysisWrite).TryLock(pNamespace)
    Set tEnd = $ZHorolog + 20
    While ($ZHorolog < tEnd) && ('$Data(^OcuPilotTestAnalysisLock("free"))) {
        Hang 0.1
    }
    Quit +$Get(^OcuPilotTestAnalysisLock("free"), -1)
}

/// <p>The job <method>LockFree</method> starts.</p>
ClassMethod TryLock(pNamespace As %String)
{
    Set tName = $ZConvert(pNamespace, "U")
    Lock +^%sqlcq(tName, "PTools", "util", "SQLAnlsys"):0
    Set tFree = $Test
    If tFree Lock -^%sqlcq(tName, "PTools", "util", "SQLAnlsys")
    Set ^OcuPilotTestAnalysisLock("free") = tFree
}

/// <p>The job that holds the namespace's analysis lock until <code>release</code> is set or twenty seconds pass.</p>
ClassMethod HoldLock(pNamespace As %String)
{
    Set tName = $ZConvert(pNamespace, "U")
    Lock +^%sqlcq(tName, "PTools", "util", "SQLAnlsys"):5
    Set ^OcuPilotTestAnalysisLock("held") = $Test
    Set tEnd = $ZHorolog + 20
    While ($ZHorolog < tEnd) && ('$Data(^OcuPilotTestAnalysisLock("release"))) {
        Hang 0.1
    }
    Lock -^%sqlcq(tName, "PTools", "util", "SQLAnlsys")
}

/// <p>AC2. A namespace whose analysis lock another process holds, as a running report holds it, answers each write 409 <code>SQL.INDEXANALYSIS.BUSY</code>
/// with the ruled sentence and nothing called, and answers 200 once the holder lets go.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.AnalysisWrite</code> skips the lock -> the busy assertions go red.</p>
Method TestABusyNamespaceRefusesEachWriteWithNothingCalled()
{
    Kill ^OcuPilotTestAnalysisLock
    Job ##class(OcuPilot.Test.SqlIndexAnalysisWrite).HoldLock(..#NAMESPACE)
    Set tEnd = $ZHorolog + 20
    While ($ZHorolog < tEnd) && ('$Data(^OcuPilotTestAnalysisLock("held"))) {
        Hang 0.1
    }
    Do $$$AssertEquals($Get(^OcuPilotTestAnalysisLock("held")), 1, "another process holds the namespace's analysis lock")
    For tType = "GATHER", "RUNREPORT", "PURGEANALYSIS" {
        Kill tQuery
        Set tQuery("namespace") = ..#NAMESPACE
        Set tQuery("id") = "*"
        Set tQuery("Report") = "TS"
        Set tSC = $ClassMethod(..#FIXTURE, "Invoke", "IndexAnalysis", tType, .tQuery, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertEquals($Get(tHttp) _ " " _ $Select($IsObject($Get(tFault)): tFault.code _ "|" _ tFault.reason, 1: ""), "409 SQL.INDEXANALYSIS.BUSY|" _ $Parameter(..#ERROR, "REASONINDEXANALYSISBUSY"), tType _ ": refused as busy with the ruled sentence")
    }
    Do $$$AssertEquals($ClassMethod(..#SEAM, "Calls"), 0, "the instance was asked for no call")
    Set ^OcuPilotTestAnalysisLock("release") = 1
    Set tEnd = $ZHorolog + 20
    While ($ZHorolog < tEnd) && (..LockFree(..#NAMESPACE) '= 1) {
        Hang 0.2
    }
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = "*"
    Set tSC = $ClassMethod(..#FIXTURE, "Invoke", "IndexAnalysis", "GATHER", .tQuery, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Get(tHttp) _ "|" _ $ClassMethod(..#SEAM, "Calls"), "200|1", "and the next gather goes through once the holder lets go")
}

/// <p>The copy-out scripts do what the writes do: the gather script gathers the namespace's statements and the purge script removes them, each run as a
/// person pasting it into a terminal would.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.AnalysisSnippet</code> omits the gathering call -> the gathered-statements assertion goes red.</p>
Method TestTheCopyOutScriptsDoWhatTheWritesDo()
{
    Kill tQuery
    Set tQuery("namespace") = ..#NAMESPACE
    Set tQuery("id") = "*"
    Set tQuery("SkipSystem") = "true"
    Set tQuery("SkipInserts") = "true"
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "IndexAnalysis", "GATHER", .tQuery)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RunScript", ..#NAMESPACE, tSteps.%Get(0).text), "the gather script runs")
    Do $$$AssertTrue(+$Piece(..Counts(), "|", 1) > 0, "and the namespace holds gathered statements: " _ ..Counts())
    Set tSteps = $ClassMethod(..#PORT, "Snippet", "IndexAnalysis", "PURGEANALYSIS", .tQuery)
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RunScript", ..#NAMESPACE, tSteps.%Get(0).text), "the purge script runs")
    Do $$$AssertEquals(..Counts(), "0|0|0|0|0|0", "and the namespace holds none")
}

}
