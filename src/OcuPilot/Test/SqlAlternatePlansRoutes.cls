/// <p>Pins Alternate plans at its two callers (Story 21.28; AD-7, AD-21, AD-36, AD-44, AD-60): SQL query's plan route and the agent's
/// <code>explorer.sqlalternateplans.read</code> answering the same possible plans and the same plan text for the alternate-plans probe with nothing run; the
/// route's body keys and their refusals before anything is prepared; a compare posted to the route answering one row for each plan chosen and recording
/// nothing but its statistics; the agent read's shape, with no compare and no values, and its refusal of a statement that is not a query; the console's own
/// check refusing OcuPilot's own tables and the error outcome for a statement the instance does not prepare, each before any call reaches the instance; and the
/// tool's pairs, the SQL query screen's with the classic page's custom resource.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as <class>OcuPilot.Test.Http</class>'s account, the calling account
/// holding the SQL query screen's pairs and READ and WRITE on <code>USER</code>'s code databases, and a <code>USER</code> namespace, where each test makes
/// <class>OcuPilot.Test.SqlTuningProbe</class>'s alternate-plans table and removes it, its cached queries, statement index rows and statistics rows after,
/// reading each back absent. Live-safe: it changes no setting. The principals' refusals are in <class>OcuPilot.Test.SqlConsoleRoutes</class> and
/// <class>OcuPilot.Test.ClassicPageGate</class>, which create them.</p>
Class OcuPilot.Test.SqlAlternatePlansRoutes Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.SqlTuningProbe";

Parameter TOOL = "OcuPilot.Screen.Tool.ExplorerSqlAlternatePlansRead";

Parameter SEAMTOOL = "OcuPilot.Test.SqlAlternateTool";

Parameter FIXTURE = "OcuPilot.Test.SqlAlternateFixture";

Parameter ERROR = "OcuPilot.Api.AtelierError";

Parameter NAMESPACE = "USER";

Parameter PLAN = "/api/ocupilot/explorer/sql/plan";

Parameter RUN = "/api/ocupilot/explorer/sql/run";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#FIXTURE, "Reset")
    Set tSC = $ClassMethod(..#PROBE, "MakeAlternates", ..#NAMESPACE)
    Do $$$AssertStatusOK(tSC, "the alternate-plans probe is created in " _ ..#NAMESPACE)
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#FIXTURE, "Reset")
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "RemoveAlternates", ..#NAMESPACE), "the probe is removed")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "AlternateState", ..#NAMESPACE), "0|0|0|0", "and no table, cached query, statistics row or statement index row of it is left")
    Quit $$$OK
}

/// <p>The probe's statement.</p>
ClassMethod Query() As %String
{
    Quit $Parameter(..#PROBE, "ALTERNATEQUERY")
}

/// <p>POST <var>pBody</var> to <var>pPath</var> in <code>USER</code> as the suite's own account, answering the status and the parsed answer.</p>
Method Post(pBody As %DynamicObject, Output pStatus As %Integer, Output pAnswer, pPath As %String = {..#PLAN}, pNamespace As %String = {..#NAMESPACE})
{
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", pPath _ "?ns=" _ pNamespace, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .pStatus, .tBody, .tHeaders, pBody.%ToJSON(), "application/json")
    Set pAnswer = ""
    Try {
        Set pAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    } Catch {
        Set pAnswer = $Get(tBody)
    }
}

/// <p>A route answer as <code>status code reason</code> for a refusal and <code>status outcome</code> for an answer.</p>
ClassMethod Said(pStatus As %Integer, pAnswer) As %String
{
    If '$IsObject($Get(pAnswer)) Quit $Get(pStatus) _ " " _ $Get(pAnswer)
    If pAnswer.%GetTypeOf("code") = "string" Quit pStatus _ " " _ pAnswer.code _ " " _ pAnswer.reason
    Quit pStatus _ " " _ pAnswer.outcome
}

/// <p>An agent refusal as <code>status code reason</code>, or <code>200 outcome</code> for an answer.</p>
ClassMethod Told(pSC As %Status, pHttp As %Integer, pResult, pFault) As %String
{
    If $$$ISOK(pSC) Quit pHttp _ " " _ pResult.outcome
    If '$IsObject($Get(pFault)) Quit "raised"
    Quit pHttp _ " " _ pFault.code _ " " _ pFault.reason
}

/// <p><var>pPlan</var> without the instance's warning about a process whose collation differs from the temporary database's, which a web process can add.</p>
ClassMethod WithoutCollationWarning(pPlan As %String) As %String
{
    Set tText = ""
    For tI = 1:1:$Length(pPlan, $Char(10)) {
        Set tLine = $Piece(pPlan, $Char(10), tI)
        If tLine '[ "The NLS Collation" Set tText = tText _ tLine _ $Char(10)
    }
    Quit tText
}

/// <p>The tool declares its name, kind and screen, its description says it lists and shows plans and runs nothing, it takes a statement and a plan number and
/// neither values nor a compare, and its pairs are the SQL query screen's with the custom resource of the classic page.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Screen.Tool.ExplorerSqlAlternatePlansRead.InputSchema</code> declares a <code>compare</code> property -> the
/// properties assertion goes red; <code>PrivilegePairs</code> answers the screen's pairs alone -> the pairs assertion goes red.</p>
Method TestTheToolDeclaresItsShapeAndItsPairs()
{
    Set tTool = ..#TOOL
    Do $$$AssertEquals($Parameter(tTool, "TOOLNAME") _ "|" _ $Parameter(tTool, "KIND") _ "|" _ $Parameter(tTool, "DESCRIPTORCLASS"), "explorer.sqlalternateplans.read|read|OcuPilot.Screen.Descriptor.ExplorerSqlQuery", "named, a read, and gated as SQL query is")
    Do $$$AssertEquals($Parameter(tTool, "DESCRIPTION"), "List the plans the optimizer considered for one SQL query, with their cost, map type and starting map, or show one of them by its plan number. This lists and shows plans and runs nothing.", "its description says it runs nothing")
    Set tProperties = $ClassMethod(tTool, "InputSchema").properties
    Set tNames = ""
    Set tIterator = tProperties.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tNames = tNames _ $Select(tNames = "": "", 1: ",") _ tKey
    }
    Do $$$AssertEquals(tNames, "statement,plan", "it takes a statement and a plan number, with no values and no compare")
    Set tPairs = $ClassMethod(tTool, "PrivilegePairs", "", .tResolved)
    Set tScreen = ##class(OcuPilot.Screen.Gate).RequiredPairs($Parameter(tTool, "DESCRIPTORCLASS"), .tScreenResolved)
    Do $$$AssertTrue(tResolved && tScreenResolved && $ListFind(tPairs, $ListBuild("%Development", "USE")), "its pairs resolve and hold %Development:USE")
    Do $$$AssertEquals(tPairs, ##class(OcuPilot.Screen.Gate).WithClassicPages(tScreen, $Parameter("OcuPilot.Area.Explorer.SqlConsole", "ALTERNATESPAGE")), "and are the screen's pairs with the custom resource of the classic Alternate Show Plans page")
    Do $$$AssertEquals($Parameter("OcuPilot.Area.Explorer.SqlConsole", "ALTERNATESPAGE"), "%CSP.UI.Portal.SQL.QButtons.ShowPlanAlt", "which is that page")
}

/// <p>AC1. The route and the agent read answer the same possible plans for the probe's query, nothing run, and the same text for one plan; the answers
/// conform to the tool's result schema, and the statistics rows are still none.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Screen.Tool.ExplorerSqlAlternatePlansRead.View</code> calls <code>Plan</code> without alternates -> the plans leg goes
/// red; <code>OcuPilot.Area.Explorer.SqlConsole.HandlePlan</code> drops <code>tAlternates</code> -> the route leg goes red.</p>
Method TestTheRouteAndTheAgentReadAnswerTheSamePlansAndNothingRuns()
{
    Do ..Post({"statement": (..Query()), "alternates": true}, .tStatus, .tRoute)
    Do $$$AssertEquals(..Said(tStatus, tRoute), "200 plans", "the route answers the list")
    Set tSC = $ClassMethod(..#TOOL, "View", "", {"statement": (..Query())}, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Told(tSC, tHttp, .tResult, .tFault), "200 plans", "so does the agent read")
    If '$IsObject($Get(tRoute)) || '$IsObject($Get(tResult)) || (tRoute.%GetTypeOf("plans") '= "array") Quit
    Do $$$AssertStatusOK(##class(OcuPilot.Screen.Tool.Registry).ValidateArguments($ClassMethod(..#TOOL, "ResultSchema"), tResult, .tProblem), "the agent's answer conforms to the tool's result schema: " _ $Get(tProblem))
    Do $$$AssertTrue(tRoute.plans.%Size() >= 2, "at least two possible plans: " _ tRoute.plans.%Size())
    Do $$$AssertEquals(tResult.plans.%ToJSON(), tRoute.plans.%ToJSON(), "the same plans, row for row")
    Do $$$AssertEquals(tResult.truncated _ "|" _ tRoute.truncated _ "|" _ tResult.kind _ "|" _ tRoute.kind _ "|" _ tResult.namespace, "0|0|query|query|" _ ..#NAMESPACE, "neither cut, both a query, in the scope's namespace")
    Do $$$AssertEquals(tResult.tables.%ToJSON(), "[""OCUPROBE228.T""]", "the tables the instance records for it")
    Do $$$AssertEquals($Piece($ClassMethod(..#PROBE, "AlternateState", ..#NAMESPACE), "|", 3), 0, "no statistics row was recorded: nothing ran")
    Do ..Post({"statement": (..Query()), "alternates": true, "plan": 2}, .tStatus, .tOneRoute)
    Set tSC = $ClassMethod(..#TOOL, "View", "", {"statement": (..Query()), "plan": 2}, 200, .tOneResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tStatus, tOneRoute) _ "|" _ ..Told(tSC, tHttp, .tOneResult, .tFault), "200 plan|200 plan", "both answer plan 2's text")
    If '$IsObject($Get(tOneRoute)) || '$IsObject($Get(tOneResult)) Quit
    Do $$$AssertEquals(tOneRoute.alternate _ "|" _ tOneResult.alternate, "2|2", "naming plan 2")
    Do $$$AssertEquals(..WithoutCollationWarning(tOneRoute.plan), ..WithoutCollationWarning(tOneResult.plan), "the same text, but for the instance's collation warning")
    Do $$$AssertEquals($Length(tOneResult.plan, "<plan>") - 1, 1, "of one plan alone")
    Do $$$AssertEquals($Piece($ClassMethod(..#PROBE, "AlternateState", ..#NAMESPACE), "|", 3), 0, "still no statistics row")
    Do ..Post({"statement": ("UPDATE " _ $Parameter(..#PROBE, "ALTERNATETABLE") _ " SET D = 'zz' WHERE B = 5 AND C = 'c5'"), "alternates": true}, .tStatus, .tDml)
    Do $$$AssertEquals(..Said(tStatus, tDml) _ "|" _ $Select($IsObject(tDml): tDml.kind, 1: ""), "200 plans|dml", "the route lists an UPDATE's plans too")
}

/// <p>The agent read has no compare and no values, and a statement that is not a query is refused 422 <code>EXPLORER.SQL.CHANGES</code> with its parent's
/// sentence before anything reaches the instance; a plan the list does not hold is 400 <code>EXPLORER.SQL.ALTPLAN</code> on both callers, after the list
/// alone.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Screen.Tool.ExplorerSqlAlternatePlansRead.View</code> skips its <code>Mutating</code> check -> the UPDATE leg goes
/// red.</p>
Method TestTheAgentReadTakesNoCompareAndRefusesWhatIsNotAQuery()
{
    Set tTool = ..#SEAMTOOL
    Set tFixture = ..#FIXTURE
    Set tSC = $ClassMethod(tTool, "View", "", {"statement": (..Query()), "compare": [1, 2]}, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tHttp _ " " _ tFault.code, 1: "answered"), "400 TOOL.ARGUMENTS", "a compare argument is refused as an argument the tool does not declare")
    Set tSC = $ClassMethod(tTool, "View", "", {"statement": (..Query()), "parameters": ["5"]}, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tHttp _ " " _ tFault.code, 1: "answered"), "400 TOOL.ARGUMENTS", "so are values")
    Set tSC = $ClassMethod(tTool, "View", "", {"statement": ("UPDATE " _ $Parameter(..#PROBE, "ALTERNATETABLE") _ " SET D = 'zz'")}, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Told(tSC, tHttp, .tResult, .tFault), "422 EXPLORER.SQL.CHANGES " _ $Parameter(..#ERROR, "REASONSQLCHANGES"), "an UPDATE is refused with the query read's sentence")
    Do $$$AssertEquals($ClassMethod(tFixture, "Calls") _ "|" _ $ClassMethod(tFixture, "Explains"), "0|0", "before anything reached the instance")
    Set tNotFound = "400 EXPLORER.SQL.ALTPLAN " _ $Parameter(..#ERROR, "REASONSQLALTPLAN")
    Set tSC = $ClassMethod(tTool, "View", "", {"statement": (..Query()), "plan": 99}, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals(..Told(tSC, tHttp, .tResult, .tFault), tNotFound, "an unlisted plan is refused with the published sentence")
    Do $$$AssertEquals($ClassMethod(tFixture, "Lists") _ "|" _ $ClassMethod(tFixture, "Explains") _ "|" _ $ClassMethod(tFixture, "Stats"), "1|0|0", "after the list alone")
    Do ..Post({"statement": (..Query()), "alternates": true, "plan": 99}, .tStatus, .tRoute)
    Do $$$AssertEquals(..Said(tStatus, tRoute), tNotFound, "and so is it on the route")
}

/// <p>The console's own check and the instance's refusal to prepare answer before any call reaches the instance, on both callers: OcuPilot's own table is
/// 403 <code>PROHIBITED.OCUPILOTSQL</code>, and a statement the instance does not prepare is the <code>error</code> outcome with its SQLCODE.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Area.Explorer.SqlConsole.Check</code> skips its self-protection set -> the own-table legs go red.</p>
Method TestOwnTablesAndAnUnpreparedStatementAnswerBeforeAnyCall()
{
    Set tTool = ..#SEAMTOOL
    Set tFixture = ..#FIXTURE
    Set tOwn = "SELECT ID FROM OcuPilot_Kernel_State.Turn"
    Do ##class(OcuPilot.Kernel.Scope).Set($NAMESPACE)
    Set tSC = $ClassMethod(tTool, "View", "", {"statement": (tOwn)}, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tHttp _ " " _ tFault.code, 1: "answered"), "403 PROHIBITED.OCUPILOTSQL", "the agent read refuses OcuPilot's own table")
    Set tSC = $ClassMethod(tTool, "View", "", {"statement": (tOwn), "plan": 1}, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($Select($IsObject($Get(tFault)): tHttp _ " " _ tFault.code, 1: "answered"), "403 PROHIBITED.OCUPILOTSQL", "and a plan's text of it")
    Do ##class(OcuPilot.Kernel.Scope).Set(..#NAMESPACE)
    Set tSC = $ClassMethod(tTool, "View", "", {"statement": "SELECT FROM WHERE"}, 200, .tResult, .tHttp, .tFault)
    Do $$$AssertEquals($Select($$$ISOK(tSC): tHttp _ " " _ tResult.outcome _ " " _ (tResult.sqlcode < 0), 1: "refused"), "200 error 1", "a statement the instance does not prepare is the error outcome")
    Do $$$AssertEquals($ClassMethod(tFixture, "Calls") _ "|" _ $ClassMethod(tFixture, "Explains"), "0|0", "and none of them reached the instance")
    Do ..Post({"statement": (tOwn), "alternates": true}, .tStatus, .tRoute, ..#PLAN, $NAMESPACE)
    Do $$$AssertEquals($Select($IsObject(tRoute): tStatus _ " " _ tRoute.code, 1: tStatus), "403 PROHIBITED.OCUPILOTSQL", "the route refuses it too")
    Do ..Post({"statement": "SELECT FROM WHERE", "alternates": true}, .tStatus, .tRoute)
    Do $$$AssertEquals($Select($IsObject(tRoute): tStatus _ " " _ tRoute.outcome _ " " _ (tRoute.sqlcode < 0), 1: tStatus), "200 error 1", "and answers the error outcome")
    Do $$$AssertEquals($Piece($ClassMethod(..#PROBE, "AlternateState", ..#NAMESPACE), "|", 3), 0, "and no statistics row was recorded")
}

/// <p>The plan route's body: <code>alternates</code> is a boolean, <code>plan</code> a number and <code>compare</code> an array; <code>alternates</code> with
/// <code>stats</code> or <code>advise</code>, <code>plan</code> with <code>compare</code>, and either without <code>alternates</code> set to true are
/// 400 <code>EXPLORER.SQL.INPUT</code>; the run route takes none of the three. A compare of no plan, six, a repeat or a value that is not whole is 400
/// <code>EXPLORER.SQL.ALTCOUNT</code>, a compare of an UPDATE 422 <code>EXPLORER.SQL.ALTCOMPARE</code>, a plan the list does not hold 400
/// <code>EXPLORER.SQL.ALTPLAN</code> and a statement over the bound 422 <code>EXPLORER.SQL.ALTBOUND</code>, each before anything runs.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Area.Explorer.SqlConsole.Body</code> accepts a plan with a compare -> that leg goes red.</p>
Method TestTheRouteRefusesEachMalformedBodyAndEachBadCompareBeforeAnythingRuns()
{
    Set tQuery = ..Query()
    Set tInput = "400 EXPLORER.SQL.INPUT " _ $Parameter(..#ERROR, "REASONSQLINPUT")
    ; A statement the instance cannot prepare: only the body's own refusal answers 400 for it, never the console's check or the port's.
    Set tBad = "SELECT FROM WHERE"
    Set tBodies = [{"statement": (tBad), "alternates": "yes"}, {"statement": (tBad), "alternates": true, "plan": "2"}, {"statement": (tBad), "alternates": true, "compare": "1"}, {"statement": (tBad), "alternates": true, "stats": true}, {"statement": (tBad), "alternates": true, "advise": true}, {"statement": (tBad), "alternates": true, "plan": 1, "compare": [1]}, {"statement": (tBad), "plan": 1}, {"statement": (tBad), "compare": [1]}, {"statement": (tBad), "alternates": false, "plan": 1}]
    Set tIterator = tBodies.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tBody) {
        Do ..Post(tBody, .tStatus, .tAnswer)
        Do $$$AssertEquals(..Said(tStatus, tAnswer), tInput, "body " _ tIndex _ " is refused as input before the statement is prepared")
    }
    Do ..Post({"statement": (tQuery), "alternates": true}, .tStatus, .tAnswer, ..#RUN)
    Do $$$AssertEquals(..Said(tStatus, tAnswer), tInput, "the run route takes no alternates key")
    Set tCount = "400 EXPLORER.SQL.ALTCOUNT " _ $Parameter(..#ERROR, "REASONSQLALTCOUNT")
    For tIds = [], [1, 2, 3, 4, 5, 6], [1, 1], ["a"], [1.5], [true], [-1], [[1]] {
        Do ..Post({"statement": (tQuery), "alternates": true, "compare": (tIds)}, .tStatus, .tAnswer)
        Do $$$AssertEquals(..Said(tStatus, tAnswer), tCount, tIds.%ToJSON() _ " is not one to five distinct whole numbers")
    }
    Do ..Post({"statement": (tQuery), "alternates": true, "compare": [1, 99]}, .tStatus, .tAnswer)
    Do $$$AssertEquals(..Said(tStatus, tAnswer), "400 EXPLORER.SQL.ALTPLAN " _ $Parameter(..#ERROR, "REASONSQLALTPLAN"), "a plan the list does not hold")
    Do ..Post({"statement": ("UPDATE " _ $Parameter(..#PROBE, "ALTERNATETABLE") _ " SET D = 'zz' WHERE B = 5"), "alternates": true, "compare": [1]}, .tStatus, .tAnswer)
    Do $$$AssertEquals(..Said(tStatus, tAnswer), "422 EXPLORER.SQL.ALTCOMPARE " _ $Parameter(..#ERROR, "REASONSQLALTCOMPARE"), "a compare of an UPDATE")
    Set tTable = $Parameter(..#PROBE, "ALTERNATETABLE")
    Set tFive = "SELECT t1.A AS Probe228 FROM " _ tTable _ " t1, " _ tTable _ " t2, " _ tTable _ " t3, " _ tTable _ " t4, " _ tTable _ " t5 WHERE t1.B = t2.B AND t2.B = t3.B AND t3.B = t4.B AND t4.B = t5.B"
    Do ..Post({"statement": (tFive), "alternates": true}, .tStatus, .tAnswer)
    Do $$$AssertEquals(..Said(tStatus, tAnswer), "422 EXPLORER.SQL.ALTBOUND " _ $ClassMethod(..#ERROR, "AlternateBoundReason", 4, 4), "a statement of five tables")
    Do $$$AssertEquals($Piece($ClassMethod(..#PROBE, "AlternateState", ..#NAMESPACE), "|", 3), 0, "none of them recorded a statistics row")
}

/// <p>AC2. A compare posted to the route answers one row for each plan chosen, in the order chosen, each with the list's cost and starting map and the run's
/// numbers, no values sent; the runs record statistics rows and the table keeps its rows; the same plans listed after are the same plans.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Area.Explorer.SqlConsole.HandlePlan</code> passes no compare to the port -> the compared assertion goes red.</p>
Method TestTheRouteComparesTwoListedPlans()
{
    Do ..Post({"statement": (..Query()), "alternates": true}, .tStatus, .tList)
    Do ..Post({"statement": (..Query()), "alternates": true, "compare": [2, 1]}, .tStatus, .tAnswer)
    Do $$$AssertEquals(..Said(tStatus, tAnswer), "200 compared", "the route answers the compare")
    If '$IsObject($Get(tAnswer)) || '$IsObject($Get(tList)) || (tAnswer.%GetTypeOf("plans") '= "array") Quit
    Do $$$AssertEquals(tAnswer.plans.%Size() _ "|" _ tAnswer.plans.%Get(0).Plan _ "|" _ tAnswer.plans.%Get(1).Plan, "2|2|1", "one row for each plan, in the order chosen")
    For tI = 0, 1 {
        Set tRow = tAnswer.plans.%Get(tI)
        Set tListed = tList.plans.%Get(tRow.Plan - 1)
        Do $$$AssertEquals(tRow.Cost _ "|" _ tRow.StartingMap, tListed.Cost _ "|" _ tListed.StartingMap, "plan " _ tRow.Plan _ ": the list's cost and starting map")
        Do $$$AssertTrue($Match(tRow.GlobalReferences, "^[0-9,]+$") && $Match(tRow.Commands, "^[0-9,]+$") && $Match(tRow.TotalTime, "^[0-9.]+$") && $Match(tRow.Rows, "^[0-9,]+$"), "plan " _ tRow.Plan _ ": its numbers: " _ tRow.%ToJSON())
    }
    Do $$$AssertTrue($Piece($ClassMethod(..#PROBE, "AlternateState", ..#NAMESPACE), "|", 3) > 0, "the runs recorded statistics rows")
    Do ..Post({"statement": (..Query()), "alternates": true}, .tStatus, .tAgain)
    Do $$$AssertEquals($Select($IsObject(tAgain): tAgain.plans.%ToJSON(), 1: ""), tList.plans.%ToJSON(), "the same plans are listed after")
}

}
