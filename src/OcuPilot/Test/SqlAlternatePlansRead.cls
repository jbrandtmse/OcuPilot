/// <p>Pins <class>OcuPilot.Port.SqlPort</class>'s Alternate plans (Story 21.28; AD-7, AD-21, AD-36, AD-51) at the port, over
/// <class>OcuPilot.Test.SqlTuningProbe</class>'s alternate-plans table: the list of a query's possible plans with its four columns and nothing run, the
/// list of a DML statement changing no row, one plan's text alone and an unlisted plan refused after the list and before any text, a compare of two listed
/// plans answering one row each with its numbers and removing nothing but its own recorded rows, every refusal before any vendor call (a statement that is
/// not a query, a bad count, a repeat, a number that is not whole, an unlisted plan, a cross product, a statement over the bound, a view's text counting
/// toward it), the cap on the list and on a compare at each side of its boundary, a compare stopped at the bound, the SQL EXECUTE refusal, the error outcome
/// of an SQLCODE below 0 and of a statement the instance does not prepare, and the console's own-table check refusing before the port is reached.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed, the calling account holding the SQL query screen's pairs and READ and WRITE on
/// <code>USER</code>'s code databases, and a <code>USER</code> namespace, where each test makes the probe table, tunes it and removes it, its cached queries,
/// its statement index rows and the runtime statistics rows of its own statements after, reading each back absent. Live-safe: it changes no setting and
/// removes no row it did not record.</p>
Class OcuPilot.Test.SqlAlternatePlansRead Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.SqlTuningProbe";

Parameter PORT = "OcuPilot.Port.SqlPort";

Parameter FIXTURE = "OcuPilot.Test.SqlAlternateFixture";

Parameter ERROR = "OcuPilot.Api.AtelierError";

Parameter NAMESPACE = "USER";

Method OnBeforeOneTest() As %Status
{
    Do ##class(OcuPilot.Kernel.Scope).Clear()
    Do $ClassMethod(..#FIXTURE, "Reset")
    Set tSC = $ClassMethod(..#PROBE, "MakeAlternates", ..#NAMESPACE)
    Do $$$AssertStatusOK(tSC, "the alternate-plans probe is created in " _ ..#NAMESPACE)
    Quit tSC
}

Method OnAfterOneTest() As %Status
{
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

/// <p>The probe table's name.</p>
ClassMethod Table() As %String
{
    Quit $Parameter(..#PROBE, "ALTERNATETABLE")
}

/// <p><var>pPort</var>'s <code>Plan</code> for <var>pText</var> with alternates, <var>pPlanId</var> and <var>pCompare</var> (JSON array text or
/// <code>""</code>).</p>
ClassMethod Plan(pPort As %String, pText As %String, pPlanId As %String, pCompare As %String, Output pAnswer As %DynamicObject, Output pHttp As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set tCompare = $Select(pCompare = "": "", 1: ##class(%DynamicAbstractObject).%FromJSON(pCompare))
    Quit $ClassMethod(pPort, "Plan", ..#NAMESPACE, pText, .pAnswer, .pHttp, .pFault, 0, 0, 1, pPlanId, tCompare)
}

/// <p>A refusal as <code>http code reason</code>, <code>answered</code> for a call that answered, and <code>raised</code> for a status with no fault.</p>
ClassMethod Refused(pSC As %Status, pHttp As %Integer, pFault As %DynamicObject) As %String
{
    If $$$ISOK(pSC) Quit "answered"
    If '$IsObject($Get(pFault)) Quit "raised"
    Quit pHttp _ " " _ pFault.code _ " " _ pFault.reason
}

/// <p>The first column of the first row of <var>pText</var> run in <code>USER</code>, <code>""</code> when it answers none.</p>
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

/// <p>The instance's own statistics row for plan <var>pId</var> of the compare text <var>pText</var>, read through the fixture with the call a compare
/// makes: <code>[plan, cost, starting map, ...]</code>, or <code>""</code> when the instance answers none.</p>
ClassMethod StatisticsRow(pText As %String, pId As %String) As %DynamicArray
{
    Set tFound = ""
    Set tSC = $ClassMethod(..#FIXTURE, "VendorRead", ..#NAMESPACE, $Parameter(..#PORT, "ALTSTATSQUERY"), pText, pId, .tRows, .tCode, .tMessage)
    If $$$ISERR(tSC) || (tCode < 0) Quit tFound
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tKey, .tRow) {
        If (tFound = "") && (+tRow.%Get(0) = pId) Set tFound = tRow
    }
    Quit tFound
}

/// <p>A statement of <var>pTables</var> aliases of the probe table joined by <code>B</code> on <var>pConditions</var> - 1 conditions or fewer.</p>
ClassMethod Aliases(pTables As %Integer, pJoined As %Boolean = 1) As %String
{
    Set tFrom = ""
    Set tWhere = ""
    For tI = 1:1:pTables {
        Set tFrom = tFrom _ $Select(tI > 1: ", ", 1: "") _ ..Table() _ " t" _ tI
        If pJoined && (tI > 1) Set tWhere = tWhere _ $Select(tWhere = "": " WHERE ", 1: " AND ") _ "t" _ (tI - 1) _ ".B = t" _ tI _ ".B"
    }
    Quit "SELECT t1.A AS Probe228 FROM " _ tFrom _ tWhere
}

/// <p>AC1. The list of the probe's query: one row for each possible plan, at least two, each carrying the plan's number, cost, map type and starting map;
/// nothing ran, so the statistics rows are still none and a second list leaves the cached queries and statement index rows as the first left them.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.Alternates</code> leaves <code>MapType</code> out of a plan -> the columns assertion goes red;
/// <code>PlansVendor</code> runs the statistics query for the list -> the nothing-ran assertion goes red.</p>
Method TestTheListAnswersThePlansTheOptimizerConsideredAndRunsNothing()
{
    Set tSC = ..Plan(..#PORT, ..Query(), "", "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the list answers")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tAnswer.outcome _ "|" _ tAnswer.kind _ "|" _ tAnswer.truncated, "plans|query|0", "the plans outcome of a query, not cut")
    Do $$$AssertTrue(tAnswer.plans.%Size() >= 2, "the statement has at least two possible plans: " _ tAnswer.plans.%Size())
    Set tFirst = tAnswer.plans.%Get(0)
    Set tColumns = ""
    Set tIterator = tFirst.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tColumns = tColumns _ $Select(tColumns = "": "", 1: ",") _ tKey
    }
    Do $$$AssertEquals(tColumns, "Plan,Cost,MapType,StartingMap", "each plan carries the four columns")
    Do $$$AssertEquals(tFirst.%GetTypeOf("Plan") _ "|" _ tFirst.Plan _ "|" _ tAnswer.plans.%Get(1).Plan, "number|1|2", "numbered from 1")
    Do $$$AssertTrue($Match(tFirst.Cost, "^[0-9]+\.[0-9]$") && (tFirst.MapType '= "") && (tFirst.StartingMap '= ""), "a cost with one decimal, a map type and a starting map: " _ tFirst.%ToJSON())
    Set tState = $ClassMethod(..#PROBE, "AlternateState", ..#NAMESPACE)
    Do $$$AssertEquals($Piece(tState, "|", 3), 0, "no statistics row was recorded: nothing ran")
    Set tSC = ..Plan(..#PORT, ..Query(), "", "", .tAgain, .tHttp, .tFault)
    Do $$$AssertEquals($ClassMethod(..#PROBE, "AlternateState", ..#NAMESPACE), tState, "a second list adds no cached query and no statement index row")
    Do $$$AssertEquals(tAgain.plans.%ToJSON(), tAnswer.plans.%ToJSON(), "and answers the same plans")
}

/// <p>The list of a DML statement answers its plans and changes no row.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.Plan</code> runs the DML statement -> the row assertion goes red.</p>
Method TestTheListOfADmlStatementChangesNoRow()
{
    Set tSC = ..Plan(..#PORT, "UPDATE " _ ..Table() _ " SET D = 'zz' WHERE B = 5 AND C = 'c5'", "", "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the list of an UPDATE answers")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tAnswer.outcome _ "|" _ tAnswer.kind, "plans|dml", "its plans")
    Do $$$AssertTrue(tAnswer.plans.%Size() >= 1, "at least one: " _ tAnswer.plans.%Size())
    Do $$$AssertEquals(..ScalarIn("SELECT COUNT(*) FROM " _ ..Table() _ " WHERE D = 'zz'"), 0, "no row was updated")
    Do $$$AssertEquals(..ScalarIn("SELECT COUNT(*) FROM " _ ..Table()), 3000, "and none was added or removed")
}

/// <p>Show plan answers the text of the one plan named, which is not the plan the statement would run, and an unlisted number or one that is not whole is
/// 400 <code>EXPLORER.SQL.ALTPLAN</code>: the second after the list and before any text, the others before the list.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.Alternates</code> omits the check of the number against the list -> the unlisted leg goes red.</p>
Method TestShowPlanAnswersOnePlansTextAndRefusesAnUnlistedPlan()
{
    Set tFixture = ..#FIXTURE
    Set tSC = ..Plan(tFixture, ..Query(), 2, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "plan 2's text answers")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tAnswer.outcome _ "|" _ tAnswer.kind _ "|" _ tAnswer.alternate _ "|" _ tAnswer.truncated, "plan|query|2|0", "the plan outcome, naming plan 2")
    Do $$$AssertEquals($Length(tAnswer.plan, "<plan>") - 1, 1, "the text holds one plan")
    Do $$$AssertEquals($ClassMethod(tFixture, "Lists") _ "|" _ $ClassMethod(tFixture, "Stats") _ "|" _ $ClassMethod(tFixture, "Explains"), "1|0|1", "after one list and one text, with no statistics call")
    Set tSC = $ClassMethod(..#PORT, "Plan", ..#NAMESPACE, ..Query(), .tBest, .tHttp, .tFault)
    Do $$$AssertTrue(tBest.plan '= tAnswer.plan, "it is not the plan the statement would run")
    Set tNotFound = "400 EXPLORER.SQL.ALTPLAN " _ $Parameter(..#ERROR, "REASONSQLALTPLAN")
    Do $ClassMethod(tFixture, "Reset")
    Set tSC = ..Plan(tFixture, ..Query(), 99, "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(..Refused(tSC, tHttp, tFault), tNotFound, "an unlisted plan is refused with the published sentence")
    Do $$$AssertEquals($ClassMethod(tFixture, "Lists") _ "|" _ $ClassMethod(tFixture, "Explains"), "1|0", "after the list and before any text")
    Do $ClassMethod(tFixture, "Reset")
    For tId = "0", "1.5", "abc", "-1", "01", "1e2" {
        Set tSC = ..Plan(tFixture, ..Query(), tId, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertEquals(..Refused(tSC, tHttp, tFault), tNotFound, tId _ " is not a listed plan")
    }
    Do $$$AssertEquals($ClassMethod(tFixture, "Calls") _ "|" _ $ClassMethod(tFixture, "Explains"), "1|0", "the shapes were refused before any list, and plan 0, a whole number, only after it")
}

/// <p>AC2. A compare of two listed plans runs the statement's own text once for each, in order, each with its plan number as the only id, and answers one
/// row each: the cost and starting map the list gave and the run's numbers. The text it ran is the statement with <code>?</code> for the literals and
/// <code>%NOPARALLEL</code> after its FROM. The runs record statistics rows and nothing else changes: the table still holds its rows.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.Compared</code> sends the caller's text -> the text assertions go red; it sends every id in one call -> the
/// call-count assertion goes red.</p>
Method TestACompareRunsEachListedPlanAndAnswersItsNumbers()
{
    Set tFixture = ..#FIXTURE
    Set tSC = ..Plan(tFixture, ..Query(), "", "", .tList, .tHttp, .tFault)
    Do $ClassMethod(tFixture, "Reset")
    Set tSC = ..Plan(tFixture, ..Query(), "", "[2,1]", .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the compare answers")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tAnswer.outcome _ "|" _ tAnswer.kind _ "|" _ tAnswer.plans.%Size(), "compared|query|2", "the compared outcome with one row for each plan")
    Set tRow = tAnswer.plans.%Get(0)
    Set tColumns = ""
    Set tIterator = tRow.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tColumns = tColumns _ $Select(tColumns = "": "", 1: ",") _ tKey
    }
    Do $$$AssertEquals(tColumns, "Plan,Cost,StartingMap,GlobalReferences,Commands,TotalTime,Rows", "each row carries the seven columns")
    Do $$$AssertEquals(tRow.Plan _ "|" _ tAnswer.plans.%Get(1).Plan, "2|1", "in the order the plans were chosen")
    For tI = 0, 1 {
        Set tCompared = tAnswer.plans.%Get(tI)
        Do $$$AssertTrue($Match(tCompared.GlobalReferences, "^[0-9,]+$") && $Match(tCompared.Commands, "^[0-9,]+$") && $Match(tCompared.TotalTime, "^[0-9.]+$") && $Match(tCompared.Rows, "^[0-9,]+$"), "plan " _ tCompared.Plan _ ": its numbers: " _ tCompared.%ToJSON())
    }
    Do $$$AssertEquals($ClassMethod(tFixture, "Lists") _ "|" _ $ClassMethod(tFixture, "Stats"), "1|2", "one list, then the statistics query once for each plan")
    Set tFirst = $ClassMethod(tFixture, "Call", 2)
    Set tSecond = $ClassMethod(tFixture, "Call", 3)
    Do $$$AssertEquals($Piece(tFirst, "|", 1, 2) _ "~" _ $Piece(tSecond, "|", 1, 2), "possiblePlansStats|2~possiblePlansStats|1", "each call takes its plan number alone, built by the port")
    Set tText = $Piece(tFirst, "|", 3, *)
    Do $$$AssertTrue((tText [ "FROM %NOPARALLEL") && (tText '[ "c5") && (tText [ "B = ?"), "the text is the statement's own with ? for the literals and no parallel workers: " _ tText)
    Do $$$AssertEquals(tText, $Piece(tSecond, "|", 3, *), "both runs ran the same text")
    Set tState = $ClassMethod(..#PROBE, "AlternateState", ..#NAMESPACE)
    Do $$$AssertTrue(($Piece(tState, "|", 2) > 0) && ($Piece(tState, "|", 3) > 0) && ($Piece(tState, "|", 4) > 0), "the runs recorded a cached query, statistics rows and a statement index row: " _ tState)
    Do $$$AssertEquals(..ScalarIn("SELECT COUNT(*) FROM " _ ..Table()), 3000, "and the table still holds its rows")
    For tI = 0, 1 {
        Set tCompared = tAnswer.plans.%Get(tI)
        Set tListed = tList.plans.%Get(tCompared.Plan - 1)
        Set tRan = $ClassMethod(tFixture, "Call", tI + 2)
        Set tOwn = ..StatisticsRow($Piece(tRan, "|", 3, *), $Piece(tRan, "|", 2))
        Do $$$AssertTrue($IsObject(tOwn), "plan " _ tCompared.Plan _ ": the instance's own statistics row for the plan the run named, " _ $Piece(tRan, "|", 2) _ ", is read")
        If $IsObject(tOwn) {
            Do $$$AssertTrue(+tOwn.%Get(1) = +tListed.Cost, "plan " _ tCompared.Plan _ ": the cost the instance's own row holds, " _ tOwn.%Get(1) _ ", is the list's, " _ tListed.Cost)
            Do $$$AssertEquals($ZStrip(tOwn.%Get(2), "<>W"), $ZStrip(tListed.StartingMap, "<>W"), "plan " _ tCompared.Plan _ ": and so is its starting map")
        }
    }
}

/// <p>Every refusal of a compare answers before the statistics query is called: a statement that is not a query (422 <code>EXPLORER.SQL.ALTCOMPARE</code>),
/// no plan, six, a repeat or a value that is not a whole number (400 <code>EXPLORER.SQL.ALTCOUNT</code>), a table no condition joins (422
/// <code>EXPLORER.SQL.ALTJOIN</code>) and, after the list alone, a plan it does not hold (400 <code>EXPLORER.SQL.ALTPLAN</code>). A plan and a compare
/// together, and either without alternates, are the input refusal.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.Alternates</code> skips the query-only check -> the DML leg goes red.</p>
Method TestEveryCompareRefusalCallsNothing()
{
    Set tFixture = ..#FIXTURE
    Set tCount = "400 EXPLORER.SQL.ALTCOUNT " _ $Parameter(..#ERROR, "REASONSQLALTCOUNT")
    Set tSC = ..Plan(tFixture, "UPDATE " _ ..Table() _ " SET D = 'zz' WHERE B = 5 AND C = 'c5'", "", "[1,2]", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(..Refused(tSC, tHttp, tFault), "422 EXPLORER.SQL.ALTCOMPARE " _ $Parameter(..#ERROR, "REASONSQLALTCOMPARE"), "an UPDATE is not compared")
    Do $$$AssertEquals(..ScalarIn("SELECT COUNT(*) FROM " _ ..Table() _ " WHERE D = 'zz'"), 0, "and no row changed")
    For tIds = "[]", "[1,2,3,4,5,6]", "[1,1]", "[""a""]", "[1.5]", "[true]", "[-1]", "[[1]]", "[null]", "[""1"",1]" {
        Set tSC = ..Plan(tFixture, ..Query(), "", tIds, .tAnswer, .tHttp, .tFault)
        Do $$$AssertEquals(..Refused(tSC, tHttp, tFault), tCount, tIds _ " is not one to five distinct whole numbers")
    }
    Set tSC = ..Plan(tFixture, ..Aliases(2, 0), "", "[1]", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(..Refused(tSC, tHttp, tFault), "422 EXPLORER.SQL.ALTJOIN " _ $Parameter(..#ERROR, "REASONSQLALTJOIN"), "two tables joined by no condition")
    Do $$$AssertEquals($ClassMethod(tFixture, "Calls"), 0, "none of them called the instance")
    Set tSC = ..Plan(tFixture, ..Query(), "", "[1,99]", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(..Refused(tSC, tHttp, tFault), "400 EXPLORER.SQL.ALTPLAN " _ $Parameter(..#ERROR, "REASONSQLALTPLAN"), "an unlisted plan among the chosen")
    Do $$$AssertEquals($ClassMethod(tFixture, "Lists") _ "|" _ $ClassMethod(tFixture, "Stats"), "1|0", "is refused after the list alone: nothing ran")
    Set tInput = "400 EXPLORER.SQL.INPUT " _ $Parameter(..#ERROR, "REASONSQLINPUT")
    Set tSC = $ClassMethod(tFixture, "Plan", ..#NAMESPACE, ..Query(), .tAnswer, .tHttp, .tFault, 0, 0, 1, 1, [1])
    Do $$$AssertEquals(..Refused(tSC, tHttp, tFault), tInput, "a plan and a compare together")
    Set tSC = $ClassMethod(tFixture, "Plan", ..#NAMESPACE, ..Query(), .tAnswer, .tHttp, .tFault, 0, 0, 0, 1, "")
    Do $$$AssertEquals(..Refused(tSC, tHttp, tFault), tInput, "a plan without alternates")
    Set tSC = $ClassMethod(tFixture, "Plan", ..#NAMESPACE, ..Query(), .tAnswer, .tHttp, .tFault, 0, 0, 0, "", [1])
    Do $$$AssertEquals(..Refused(tSC, tHttp, tFault), tInput, "a compare without alternates")
    Set tSC = $ClassMethod(tFixture, "Plan", ..#NAMESPACE, ..Query(), .tAnswer, .tHttp, .tFault, 1, 0, 1)
    Do $$$AssertEquals(..Refused(tSC, tHttp, tFault), tInput, "alternates with statistics")
    Set tSC = $ClassMethod(tFixture, "Plan", ..#NAMESPACE, ..Query(), .tAnswer, .tHttp, .tFault, 0, 1, 1)
    Do $$$AssertEquals(..Refused(tSC, tHttp, tFault), tInput, "alternates with advice")
}

/// <p>AC1, the bound. A statement of more than 4 tables or more than 4 conditions is refused 422 <code>EXPLORER.SQL.ALTBOUND</code> with the published
/// sentence before anything reaches the instance, for the list, a plan's text and a compare alike, and a statement at 4 and 4 is not. A view whose own text
/// repeats the table four times counts toward the bound.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.AlternateCounts</code> reads no view text -> the view leg goes red.</p>
Method TestAStatementOverTheBoundIsRefusedBeforeAnyCall()
{
    Set tFixture = ..#FIXTURE
    Set tBound = "422 EXPLORER.SQL.ALTBOUND " _ $ClassMethod(..#ERROR, "AlternateBoundReason", $Parameter(..#PORT, "ALTMAXTABLES"), $Parameter(..#PORT, "ALTMAXCONDITIONS"))
    Do $$$AssertEquals($ClassMethod(..#ERROR, "AlternateBoundReason", 4, 4), "Alternate plans take a statement with at most 4 tables and 4 conditions.", "the published sentence")
    Do $$$AssertEquals($Parameter(..#PORT, "ALTMAXTABLES") _ "|" _ $Parameter(..#PORT, "ALTMAXCONDITIONS"), "4|4", "the bound is four tables and four conditions")
    Set tFiveTables = ..Aliases(5)
    Set tFiveConditions = "SELECT t1.A AS Probe228 FROM " _ ..Table() _ " t1 WHERE t1.A = 1 AND t1.B = 2 AND t1.C = 'c' AND t1.D = 'd' AND t1.A = 5"
    Do $$$AssertStatusOK($ClassMethod(..#PROBE, "MakeAlternateView", ..#NAMESPACE), "the view of four aliases is created")
    Set tView = "SELECT A AS Probe228 FROM " _ $Parameter(..#PROBE, "ALTERNATEVIEW")
    For tText = tFiveTables, tFiveConditions, tView {
        Set tSC = ..Plan(tFixture, tText, "", "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertEquals(..Refused(tSC, tHttp, tFault), tBound, "the list of " _ tText)
        Set tSC = ..Plan(tFixture, tText, 1, "", .tAnswer, .tHttp, .tFault)
        Do $$$AssertEquals(..Refused(tSC, tHttp, tFault), tBound, "a plan's text of " _ tText)
        Set tSC = ..Plan(tFixture, tText, "", "[1]", .tAnswer, .tHttp, .tFault)
        Do $$$AssertEquals(..Refused(tSC, tHttp, tFault), tBound, "a compare of " _ tText)
    }
    Do $$$AssertEquals($ClassMethod(tFixture, "Calls") _ "|" _ $ClassMethod(tFixture, "Explains"), "0|0", "none of them reached the instance")
    Do $ClassMethod(tFixture, "Fake", 3)
    Set tFour = ..Aliases(4) _ " AND t4.A = 1"
    Set tSC = ..Plan(tFixture, tFour, "", "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Select($$$ISOK(tSC): tAnswer.outcome _ "|" _ tAnswer.plans.%Size(), 1: ..Refused(tSC, tHttp, tFault)), "plans|3", "four tables and four conditions are within the bound")
    Set tSC = ..Plan(tFixture, ..Aliases(4), "", "[1]", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Select($$$ISOK(tSC): tAnswer.outcome _ "|" _ tAnswer.plans.%Size(), 1: ..Refused(tSC, tHttp, tFault)), "compared|1", "so is a compare of four tables joined by three conditions")
}

/// <p>AD-36. The list is cut at 100 plans and says so: 100 plans are not cut and 101 are. A compare takes five plans and not six.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.ALTMAXPLANS</code> is 101 -> the 101 leg goes red; <code>ALTMAXCOMPARE</code> is 6 -> the six leg goes red.</p>
Method TestTheListAndACompareAreCappedAtTheirBoundaries()
{
    Set tFixture = ..#FIXTURE
    Do $ClassMethod(tFixture, "Fake", 100)
    Set tSC = ..Plan(tFixture, ..Query(), "", "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Select($$$ISOK(tSC): tAnswer.plans.%Size() _ "|" _ tAnswer.truncated, 1: ..Refused(tSC, tHttp, tFault)), "100|0", "100 plans are all listed")
    Do $ClassMethod(tFixture, "Fake", 101)
    Set tSC = ..Plan(tFixture, ..Query(), "", "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Select($$$ISOK(tSC): tAnswer.plans.%Size() _ "|" _ tAnswer.truncated, 1: ..Refused(tSC, tHttp, tFault)), "100|1", "101 are cut to 100 and the cut is reported")
    Do $ClassMethod(tFixture, "Reset")
    Do $ClassMethod(tFixture, "Fake", 10)
    Set tSC = ..Plan(tFixture, ..Query(), "", "[1,2,3,4,5]", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Select($$$ISOK(tSC): tAnswer.outcome _ "|" _ tAnswer.plans.%Size(), 1: ..Refused(tSC, tHttp, tFault)), "compared|5", "five plans are compared")
    Do $$$AssertEquals(tAnswer.plans.%Get(4).GlobalReferences _ "|" _ tAnswer.plans.%Get(4).Commands _ "|" _ tAnswer.plans.%Get(4).TotalTime _ "|" _ tAnswer.plans.%Get(4).Rows, "7|1,368|0.000049|400,000", "each row carries the vendor's own strings")
    Do $ClassMethod(tFixture, "Reset")
    Do $ClassMethod(tFixture, "Fake", 10)
    Set tSC = ..Plan(tFixture, ..Query(), "", "[1,2,3,4,5,6]", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(..Refused(tSC, tHttp, tFault), "400 EXPLORER.SQL.ALTCOUNT " _ $Parameter(..#ERROR, "REASONSQLALTCOUNT"), "six are refused")
    Do $$$AssertEquals($ClassMethod(tFixture, "Calls"), 0, "before anything is called")
}

/// <p>A compare whose runs reach the bound answers <code>stopped</code> with the bound's seconds and no rows, and runs no further plan.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.Compared</code> never reads the elapsed seconds -> the stopped assertion goes red.</p>
Method TestACompareThatReachesTheBoundIsStoppedWithNoRows()
{
    Set tFixture = ..#FIXTURE
    Do $ClassMethod(tFixture, "Slow", 1.2, 1)
    Set tSC = ..Plan(tFixture, ..Query(), "", "[1,2]", .tAnswer, .tHttp, .tFault)
    Do $$$AssertStatusOK(tSC, "the compare answers")
    If $$$ISERR(tSC) Quit
    Do $$$AssertEquals(tAnswer.outcome _ "|" _ tAnswer.kind _ "|" _ tAnswer.seconds _ "|" _ tAnswer.%GetTypeOf("plans"), "stopped|query|1|unassigned", "stopped at the bound, with no rows")
    Do $$$AssertEquals($ClassMethod(tFixture, "Stats"), 1, "after the first run: the second plan was not run")
}

/// <p>The instance refusing the caller a procedure (SQLCODE -99) is the 403 <code>SQL.EXECUTE.PRIVILEGE</code> naming it, for the list and for a run of
/// the statistics query; any other SQLCODE below 0 is the <code>error</code> outcome with the instance's code and message; a statement the instance does
/// not prepare is the <code>error</code> outcome before any call.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.PlansRead</code> answers the error outcome for -99 -> the 403 legs go red.</p>
Method TestARefusedProcedureIsTheExecuteRefusalAndAnyOtherCodeTheErrorOutcome()
{
    Set tFixture = ..#FIXTURE
    Do $ClassMethod(tFixture, "Answer", -99)
    Set tSC = ..Plan(tFixture, ..Query(), "", "", .tAnswer, .tHttp, .tFault)
    Set tReason = $ClassMethod(..#ERROR, "ExecutePrivilegeReason", $Parameter(..#PORT, "ALTLISTPROCEDURE"))
    Do $$$AssertEquals(..Refused(tSC, tHttp, tFault), "403 SQL.EXECUTE.PRIVILEGE " _ tReason, "the list is refused naming its procedure")
    Do $$$AssertEquals(tReason, "Reading this needs the SQL EXECUTE privilege on %SYS_PTools.PT_possiblePlans.", "with the published sentence")
    Do $$$AssertEquals(tFault.detail.procedure _ "|" _ tFault.detail.reason, "%SYS_PTools.PT_possiblePlans|" _ tReason, "and the same in the detail")
    Do $ClassMethod(tFixture, "Reset")
    Do $ClassMethod(tFixture, "Fake", 3)
    Do $ClassMethod(tFixture, "AnswerStats", -99)
    Set tSC = ..Plan(tFixture, ..Query(), "", "[1]", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(..Refused(tSC, tHttp, tFault), "403 SQL.EXECUTE.PRIVILEGE " _ $ClassMethod(..#ERROR, "ExecutePrivilegeReason", $Parameter(..#PORT, "ALTSTATSPROCEDURE")), "a compare is refused naming the statistics procedure")
    Do $ClassMethod(tFixture, "Reset")
    Do $ClassMethod(tFixture, "Answer", -400, "probe refused")
    Set tSC = ..Plan(tFixture, ..Query(), "", "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Select($$$ISOK(tSC): tAnswer.outcome _ "|" _ tAnswer.kind _ "|" _ tAnswer.sqlcode _ "|" _ tAnswer.message, 1: ..Refused(tSC, tHttp, tFault)), "error|query|-400|probe refused", "any other SQLCODE below 0 is the error outcome")
    Do $ClassMethod(tFixture, "Reset")
    Set tSC = ..Plan(tFixture, "SELECT FROM WHERE", "", "", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals($Select($$$ISOK(tSC): tAnswer.outcome _ "|" _ (tAnswer.sqlcode < 0), 1: ..Refused(tSC, tHttp, tFault)), "error|1", "a statement the instance does not prepare is the error outcome")
    Do $$$AssertEquals($ClassMethod(tFixture, "Calls"), 0, "before any call")
}

/// <p>The process as <code>PlansVendor</code> must leave it: the current device with its mnemonic space, the namespace, the transaction level, whether
/// the null device is open.</p>
ClassMethod ProcessState() As %String
{
    Set tNull = ##class(%Library.Device).GetNullDevice()
    Quit $IO _ "|" _ ##class(%Library.Device).GetMnemonicRoutine() _ "|" _ $NAMESPACE _ "|" _ $TLevel _ "|" _ ##class(OcuPilot.Kernel.Utils).DeviceIsOpen(tNull)
}

/// <p>The vendor read leaves the process as it found it, for a read that succeeds and for one the instance answers an SQLCODE below 0: the current
/// device and its mnemonic space, the namespace, the transaction level (a transaction the caller holds stays open) and the null device's open state; and
/// a <code>%AltPlan</code> the process holds is killed.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Port.SqlPort.PlansCall</code> does not kill <code>%AltPlan</code> -> the <code>%AltPlan</code> assertion of the
/// error leg goes red.</p>
Method TestThePlansReadLeavesTheProcessAsItFoundIt()
{
    Set tFixture = ..#FIXTURE
    Set tQuery = $Parameter(..#PORT, "ALTLISTQUERY")
    For tCase = "success", "error" {
        Set tIds = $Select(tCase = "success": "", 1: "1")
        TStart
        Set tBefore = ..ProcessState()
        Set %AltPlan = "left behind"
        Set tSC = $ClassMethod(tFixture, "VendorRead", ..#NAMESPACE, tQuery, ..Query(), tIds, .tRows, .tCode, .tMessage)
        Set tAfter = ..ProcessState()
        Set tAltPlan = $Data(%AltPlan)
        Kill %AltPlan
        TRollback
        Do $$$AssertStatusOK(tSC, tCase _ ": the read answers")
        Do $$$AssertEquals(tAfter, tBefore, tCase _ ": device, mnemonic space, namespace, transaction level and null device are as before")
        Do $$$AssertEquals(tAltPlan, 0, tCase _ ": a %AltPlan the process holds is killed")
        If tCase = "success" {
            Do $$$AssertTrue((tCode = 0) && (tRows.%Size() >= 2), "the read answers its rows with SQLCODE 0: " _ tRows.%Size())
        } Else {
            Do $$$AssertTrue(tCode < 0, "the SQLCODE is below 0: " _ tCode)
        }
    }
}

/// <p>The console's own check refuses a statement over OcuPilot's own tables with <code>PROHIBITED.OCUPILOTSQL</code>, so the caller never reaches the
/// port; the port itself answers a statement it is given and is not that check.</p>
/// <p>Mutation (Rule 19): <code>OcuPilot.Area.Explorer.SqlConsole.Check</code> skips its self-protection set -> this goes red.</p>
Method TestTheConsolesCheckRefusesOcuPilotsOwnTablesBeforeThePort()
{
    Set tSC = ##class(OcuPilot.Area.Explorer.SqlConsole).Check($NAMESPACE, "SELECT ID FROM OcuPilot_Kernel_State.Proposal", .tGuard, .tHttp, .tFault)
    Do $$$AssertEquals($Select($$$ISERR(tSC) && $IsObject(tFault): tHttp _ " " _ tFault.code, 1: "answered"), "403 PROHIBITED.OCUPILOTSQL", "the check refuses the statement")
    Do $$$AssertEquals($ClassMethod(..#FIXTURE, "Calls"), 0, "and no plans call was made")
}

}
