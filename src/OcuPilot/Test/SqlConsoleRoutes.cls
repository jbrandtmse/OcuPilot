/// <p>Pins SQL query's two routes over the wire (Story 19.6): <code>POST /explorer/sql/run</code> and
/// <code>POST /explorer/sql/plan</code>, each answering one JSON envelope -- a query's rows bound by
/// its values and cut by Max rows, the values a statement asks for, a confirmation and nothing run for
/// a statement that changes something, the instance's refusal of two statements, the refused kinds and
/// a password statement by name, OcuPilot's own tables refused on both routes, a plan that executes
/// nothing, bad input refused before any prepare, the screen's gate naming its pair, and SQLCODE -99
/// for a principal's statement on a table it holds no SQL privilege on (DW-1964).</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, and a <code>USER</code> namespace. It creates and
/// removes <class>OcuPilot.Test.SqlConsoleProbe</class>'s objects, data included, and its principals,
/// so it runs on a throwaway only: <method>OnBeforeAllTests</method> refuses unless
/// <parameter>OcuPilot.Test.SqlConsoleProbe.ARMINGVARIABLE</parameter> reads <code>1</code>.</p>
Class OcuPilot.Test.SqlConsoleRoutes Extends %UnitTest.TestCase
{

Parameter PROBE = "OcuPilot.Test.SqlConsoleProbe";

Parameter RUN = "/api/ocupilot/explorer/sql/run";

Parameter PLAN = "/api/ocupilot/explorer/sql/plan";

/// <p>The principals' password for this run.</p>
Property PreparedPassword As %String;

Method %OnNew(initvalue As %String = "") As %Status
{
    Set tSC = ##super(initvalue)
    If $$$ISERR(tSC) Quit tSC
    Set ..PreparedPassword = ""
    Quit $$$OK
}

Method OnBeforeAllTests() As %Status
{
    If '$ClassMethod(..#PROBE, "Armed") {
        Quit $$$ERROR($$$GeneralError, "OcuPilot.Test.SqlConsoleRoutes creates IRIS users and roles and runs on a throwaway container only. " _ $Parameter(..#PROBE, "ARMINGVARIABLE") _ " does not read 1 here, so nothing was created. Bring one up with scripts/ci-throwaway.sh, which sets it.")
    }
    Set ..PreparedPassword = "OcuProbe196" _ $Translate($System.Encryption.Base64Encode($System.Encryption.GenCryptRand(18), 1), "+/=", "") _ "!Aa9"
    Set tSC = $ClassMethod(..#PROBE, "Make")
    If $$$ISOK(tSC) Set tSC = $ClassMethod(..#PROBE, "EnsurePrincipals", ..PreparedPassword)
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Set tSC = $ClassMethod(..#PROBE, "Remove")
    Quit $$$ADDSC(tSC, $ClassMethod(..#PROBE, "RemovePrincipals"))
}

/// <p>POST <var>pBody</var> to <var>pPath</var> in namespace <var>pNamespace</var> as <var>pUser</var>
/// (the suite's own account when <code>""</code>), answering the status, the parsed answer and the
/// response's content type.</p>
Method Post(pPath As %String, pBody As %DynamicObject, Output pStatus As %Integer, Output pAnswer, Output pType As %String, pNamespace As %String = "USER", pUser As %String = "")
{
    Set tUser = $Select(pUser = "": ##class(OcuPilot.Test.Http).GetTestUsername(), 1: pUser)
    Set tPassword = $Select(pUser = "": ##class(OcuPilot.Test.Http).GetTestPassword(), 1: ..PreparedPassword)
    Set tText = $Select($IsObject(pBody): pBody.%ToJSON(), 1: pBody)
    Do ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", pPath _ "?ns=" _ pNamespace, tUser, tPassword, .pStatus, .tBody, .tHeaders, tText, "application/json")
    Set pType = $Piece($Get(tHeaders("CONTENT-TYPE")), ";", 1)
    Set pAnswer = ""
    Try {
        Set pAnswer = ##class(%DynamicObject).%FromJSON(tBody)
    } Catch {
        Set pAnswer = $Get(tBody)
    }
}

/// <p>An answer as one line: the status, then the body as JSON.</p>
ClassMethod Line(pStatus As %Integer, pAnswer) As %String
{
    Quit $Get(pStatus) _ " " _ $Select($IsObject($Get(pAnswer)): pAnswer.%ToJSON(), 1: $Get(pAnswer))
}

/// <p>A refusal as one line: the status and the envelope's code.</p>
ClassMethod Code(pStatus As %Integer, pAnswer) As %String
{
    Quit $Get(pStatus) _ " " _ $Select($IsObject($Get(pAnswer)): pAnswer.%Get("code"), 1: $Get(pAnswer))
}

/// <p>AC1: the run route answers a query's columns and rows, cut by Max rows with the cut reported,
/// its values bound as values, and the value count a statement asks for when the values given do not
/// number its positions -- for a statement that changes something too, before its confirmation.</p>
/// <p>Mutation (Rule 19): answer the confirmation before the value count in
/// <method>OcuPilot.Area.Explorer.SqlConsole.HandleRun</method> -- the UPDATE-with-a-? leg goes red.</p>
Method TestTheRunRouteAnswersAQueryAndAsksForValues()
{
    Do ..Post(..#RUN, {"statement": "SELECT Name FROM OcuProbe196.Granted WHERE Num > ? ORDER BY Num", "parameters": ["0"], "maxRows": 1}, .tStatus, .tAnswer, .tType)
    Do $$$AssertEquals(tStatus, 200, "the run route answers 200")
    Do $$$AssertEquals(tType, "application/json", "with CONTENT-TYPE application/json")
    Do $$$AssertEquals(..Line(tStatus, tAnswer) _ " " _ tType, "200 {""kind"":""query"",""outcome"":""rows"",""columns"":[""Name""],""rows"":[[""n1""]],""truncated"":true} application/json", "one row, the cut reported, as JSON")
    Do ..Post(..#RUN, {"statement": "SELECT Name FROM OcuProbe196.Granted WHERE Name = ?", "parameters": ["' OR ''='"]}, .tStatus, .tAnswer, .tType)
    Do $$$AssertEquals(..Line(tStatus, tAnswer), "200 {""kind"":""query"",""outcome"":""rows"",""columns"":[""Name""],""rows"":[],""truncated"":false}", "a value is bound, never spliced")
    For tValues = [], ["1"], ["1", "2", "3"] {
        Do ..Post(..#RUN, {"statement": "SELECT Name FROM OcuProbe196.Granted WHERE Num > ? AND Name <> ?", "parameters": (tValues)}, .tStatus, .tAnswer, .tType)
        Do $$$AssertEquals(..Line(tStatus, tAnswer), "200 {""outcome"":""parameters"",""count"":2}", tValues.%Size() _ " values for two positions: the count is asked for, nothing runs")
    }
    Do ..Post(..#RUN, {"statement": "UPDATE OcuProbe196.Granted SET Num = Num + 1 WHERE Num = ?"}, .tStatus, .tAnswer, .tType)
    Do $$$AssertEquals(..Line(tStatus, tAnswer), "200 {""outcome"":""parameters"",""count"":1}", "an UPDATE with a ? asks for its value before any confirmation")
    Do ..Post(..#RUN, {"statement": "UPDATE OcuProbe196.Granted SET Num = Num + 1 WHERE Num = ?", "parameters": ["1"]}, .tStatus, .tAnswer, .tType)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("outcome") _ " " _ tAnswer.%Get("kind"), 1: ""), "confirm dml", "and, given it, waits on a confirmation")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Granted"), "40 820", "nothing ran")
}

/// <p>AC2: a statement that changes something is answered <code>confirm</code> naming its kind and
/// tables, and nothing runs -- a comment or a leading <code>/* SELECT */</code> leaves a DELETE DML;
/// DDL and a CALL wait the same way; and text holding two statements is refused by the instance.</p>
Method TestAChangeWaitsOnAConfirmationAndRunsNothing()
{
    Do ..Post(..#RUN, {"statement": "UPDATE OcuProbe196.Granted SET Num = 3"}, .tStatus, .tAnswer, .tType)
    Do $$$AssertEquals(..Line(tStatus, tAnswer), "200 {""outcome"":""confirm"",""kind"":""dml"",""statementType"":3,""tables"":[""OCUPROBE196.GRANTED""]}", "an UPDATE waits on a confirmation naming its table")
    For tText = "/* SELECT */ DELETE FROM OcuProbe196.Granted", "-- c" _ $Char(10) _ "DELETE FROM OcuProbe196.Granted" {
        Do ..Post(..#RUN, {"statement": (tText)}, .tStatus, .tAnswer, .tType)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("outcome") _ " " _ tAnswer.%Get("kind") _ " " _ tAnswer.%Get("statementType"), 1: ""), "confirm dml 4", "a disguised DELETE is DML: " _ tText)
    }
    For tCase = $ListBuild("CREATE TABLE OcuProbe196.Made (X INTEGER)", "ddl"), $ListBuild("CALL OcuProbe196.LeaveOpen()", "call") {
        Do ..Post(..#RUN, {"statement": ($List(tCase, 1))}, .tStatus, .tAnswer, .tType)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("outcome") _ " " _ tAnswer.%Get("kind"), 1: ""), "confirm " _ $List(tCase, 2), $List(tCase, 1) _ " waits on a confirmation")
    }
    Do ..Post(..#RUN, {"statement": "SELECT Name FROM OcuProbe196.Granted; DELETE FROM OcuProbe196.Granted"}, .tStatus, .tAnswer, .tType)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tStatus _ " " _ tAnswer.%Get("outcome") _ " " _ tAnswer.%Get("sqlcode"), 1: ""), "200 error -25", "two statements are refused by the instance")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Granted"), "40 820", "nothing ran")
    Do $$$AssertTrue('$ClassMethod(..#PROBE, "HoldsTable", "OcuProbe196.Made"), "and nothing was created")
}

/// <p>AC3: a session, administration, server-file or password statement is refused by name on the
/// run route and the plan route.</p>
Method TestRefusedStatementsOnBothRoutes()
{
    For tCase = $ListBuild("START TRANSACTION", "EXPLORER.SQL.SESSION"), $ListBuild("LOCK TABLE OcuProbe196.Granted IN EXCLUSIVE MODE", "EXPLORER.SQL.SESSION"), $ListBuild("GRANT SELECT ON OcuProbe196.Granted TO _PUBLIC", "EXPLORER.SQL.ADMINISTRATION"), $ListBuild("DROP USER OcuProbe196Nobody", "EXPLORER.SQL.ADMINISTRATION"), $ListBuild("LOAD DATA FROM FILE '/tmp/ocuprobe196.csv' INTO OcuProbe196.Granted", "EXPLORER.SQL.SERVERFILES"), $ListBuild("CREATE USER OcuProbe196Nobody IDENTIFY BY 'OcuProbe196NotACredential'", "EXPLORER.SQL.PASSWORD") {
        For tPath = ..#RUN, ..#PLAN {
            Do ..Post(tPath, {"statement": ($List(tCase, 1))}, .tStatus, .tAnswer, .tType)
            Do $$$AssertEquals(..Code(tStatus, tAnswer), "422 " _ $List(tCase, 2), tPath _ ": " _ $List(tCase, 1))
        }
    }
    Do ..Post(..#RUN, {"statement": "START TRANSACTION"}, .tStatus, .tAnswer, .tType)
    Do $$$AssertEquals($Select($IsObject(tAnswer): tAnswer.%Get("reason"), 1: ""), ##class(OcuPilot.Api.AtelierError).#REASONSQLSESSION, "with the published sentence")
}

/// <p>AC4: as the suite's <code>%All</code> account in the install namespace, a statement over
/// OcuPilot's own tables -- directly, reading or changing them through a view, or as DDL naming one --
/// is refused 403 <code>PROHIBITED.OCUPILOTSQL</code> on the run route and the plan route.</p>
Method TestOcuPilotsOwnTablesAreRefusedOnBothRoutes()
{
    Set tView = $Parameter(..#PROBE, "OWNVIEW")
    For tText = "SELECT ID FROM OcuPilot_Kernel_State.Proposal", "SELECT ID FROM " _ tView, "INSERT INTO " _ tView _ " (ID) VALUES (-1)", "DELETE FROM " _ tView _ " WHERE ID < 0", "DROP TABLE OcuPilot_Kernel_State.Proposal" {
        For tPath = ..#RUN, ..#PLAN {
            Do ..Post(tPath, {"statement": (tText)}, .tStatus, .tAnswer, .tType, $NAMESPACE)
            Do $$$AssertEquals(..Code(tStatus, tAnswer) _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("reason"), 1: ""), "403 PROHIBITED.OCUPILOTSQL " _ ##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTSQLREASON, tPath _ ": " _ tText)
        }
    }
}

/// <p>AC5: the plan route answers an UPDATE's plan and changes nothing, and answers a DDL statement and
/// a CALL that they have no plan.</p>
Method TestThePlanRouteExecutesNothing()
{
    Do ..Post(..#PLAN, {"statement": "UPDATE OcuProbe196.Granted SET Num = Num + 1"}, .tStatus, .tAnswer, .tType)
    Do $$$AssertEquals(tStatus, 200, "the plan route answers 200")
    Do $$$AssertEquals(tType, "application/json", "with CONTENT-TYPE application/json")
    Do $$$AssertEquals($Select($IsObject(tAnswer): tStatus _ " " _ tAnswer.%Get("outcome") _ " " _ (tAnswer.%Get("plan") [ "<plan>"), 1: ""), "200 plan 1", "an UPDATE's plan")
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Granted"), "40 820", "and nothing changed")
    For tText = "CREATE TABLE OcuProbe196.Made (X INTEGER)", "CALL OcuProbe196.LeaveOpen()" {
        Do ..Post(..#PLAN, {"statement": (tText)}, .tStatus, .tAnswer, .tType)
        Do $$$AssertEquals(..Line(tStatus, tAnswer), "200 {""kind"":""" _ $Select(tText [ "CALL": "call", 1: "ddl") _ """,""outcome"":""noplan""}", tText _ " has no plan")
    }
}

/// <p>Bad input is refused 400 <code>EXPLORER.SQL.INPUT</code> before any prepare: an empty or
/// over-long statement, values that are not an array of strings, more than 100 values, one too long,
/// Max rows outside 1 to 1,000, and a key the route does not take.</p>
Method TestBadInputIsRefusedBeforeAnyPrepare()
{
    Set tMany = []
    For tI = 1:1:101 Do tMany.%Push("v", "string")
    Set tLong = []
    Do tLong.%Push($Translate($Justify("", 32768), " ", "v"), "string")
    Set tBodies = [{"statement": ""}, {"statement": ($Translate($Justify("", 100001), " ", "x"))}, {"statement": "SELECT 1", "parameters": "1"}, {"statement": "SELECT 1", "parameters": [1]}, {"statement": "SELECT 1", "parameters": (tMany)}, {"statement": "SELECT 1", "parameters": (tLong)}, {"statement": "SELECT 1", "maxRows": 0}, {"statement": "SELECT 1", "maxRows": 1001}, {"statement": "SELECT 1", "maxRows": "10"}, {"statement": "SELECT 1", "extra": true}, {"parameters": []}]
    Set tIterator = tBodies.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tBody) {
        For tPath = ..#RUN, ..#PLAN {
            Do ..Post(tPath, tBody, .tStatus, .tAnswer, .tType)
            Do $$$AssertEquals(..Code(tStatus, tAnswer), "400 EXPLORER.SQL.INPUT", tPath _ ": body " _ tIndex)
        }
    }
}

/// <p>The screen's gate and DW-1964: without <code>%Development:USE</code> both routes refuse 403
/// <code>AUTH.NOPRIVILEGE</code> naming it; a principal granted SELECT on one table reads it and is
/// answered SQLCODE -99 for SELECT, UPDATE, TRUNCATE and a plan on the other, which is unchanged.</p>
Method TestTheGateAndAnUngrantedTable()
{
    For tPath = ..#RUN, ..#PLAN {
        Do ..Post(tPath, {"statement": "SELECT Name FROM OcuProbe196.Granted"}, .tStatus, .tAnswer, .tType, "USER", $Parameter(..#PROBE, "NODEVUSER"))
        Do $$$AssertEquals(..Code(tStatus, tAnswer) _ " " _ $Select($IsObject(tAnswer) && $IsObject(tAnswer.%Get("detail")): tAnswer.detail.%Get("failedPair"), 1: ""), "403 AUTH.NOPRIVILEGE %Development:USE", tPath _ " without %Development:USE")
    }
    Set tUser = $Parameter(..#PROBE, "USER")
    Do ..Post(..#RUN, {"statement": "SELECT Name FROM OcuProbe196.Granted WHERE Num = 1"}, .tStatus, .tAnswer, .tType, "USER", tUser)
    Do $$$AssertEquals(..Line(tStatus, tAnswer), "200 {""kind"":""query"",""outcome"":""rows"",""columns"":[""Name""],""rows"":[[""n1""]],""truncated"":false}", "the principal reads the granted table")
    For tCase = $ListBuild(..#RUN, "SELECT Name FROM OcuProbe196.Hidden"), $ListBuild(..#RUN, "UPDATE OcuProbe196.Hidden SET Num = Num + 10"), $ListBuild(..#RUN, "TRUNCATE TABLE OcuProbe196.Hidden"), $ListBuild(..#PLAN, "SELECT Name FROM OcuProbe196.Hidden") {
        Do ..Post($List(tCase, 1), {"statement": ($List(tCase, 2))}, .tStatus, .tAnswer, .tType, "USER", tUser)
        Do $$$AssertEquals($Select($IsObject(tAnswer): tStatus _ " " _ tAnswer.%Get("outcome") _ " " _ tAnswer.%Get("sqlcode"), 1: ""), "200 error -99", $List(tCase, 1) _ ": " _ $List(tCase, 2))
    }
    Do $$$AssertEquals($ClassMethod(..#PROBE, "Granted", $Parameter(..#PROBE, "HIDDEN")), "2 3", "the ungranted table is unchanged")
}

}
