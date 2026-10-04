/// <p>Pins <class>OcuPilot.Port.SqlPort</class>'s answer to a query the instance's statement index
/// holds no row for once it is prepared: refused 422 <code>EXPLORER.SQL.UNRECORDED</code> by name on a
/// classify, a run, a plan and both console routes, never 500. The probe is <parameter>TABLE</parameter>,
/// whose string column is NULL in 28 of its 30 rows, with its statistics gathered: the instance then
/// compiles a <code>LIKE ... ESCAPE</code> query on that column with runtime plan choice and writes its
/// statement-index row only when it runs (measured). The same filter without <code>ESCAPE</code> is
/// recorded, and the text the refusal suggests, with <code>%NORUNTIME</code> after
/// <code>SELECT</code>, is recorded and runs.</p>
/// <p><b>What it needs from the environment:</b> OcuPilot installed and serving over HTTP as
/// <class>OcuPilot.Test.Http</class>'s account, and a <code>USER</code> namespace, where it creates and
/// removes <parameter>TABLE</parameter>, data included. The statement-index rows its statements leave
/// are the instance's, and outlive the table.</p>
Class OcuPilot.Test.SqlUnrecordedStatement Extends %UnitTest.TestCase
{

Parameter PORT = "OcuPilot.Port.SqlPort";

Parameter NAMESPACE = "USER";

Parameter TABLE = "OcuProbe2025.Pets";

Parameter RUN = "/api/ocupilot/explorer/sql/run";

Parameter PLAN = "/api/ocupilot/explorer/sql/plan";

/// <p>A query the instance compiles with runtime plan choice over <parameter>TABLE</parameter>.</p>
Parameter ESCAPED = "SELECT Num FROM OcuProbe2025.Pets WHERE Name LIKE 'n%' ESCAPE '\'";

Method OnBeforeAllTests() As %Status
{
    Set tSC = ..Drop()
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..Exec("CREATE TABLE " _ ..#TABLE _ " (Num INTEGER, Name VARCHAR(50))")
    For tNum = 1:1:30 {
        If $$$ISERR(tSC) Quit
        Set tSC = ..Exec("INSERT INTO " _ ..#TABLE _ " (Num, Name) VALUES (?, ?)", tNum, $Case(tNum, 1: "nemo", 2: "n%x", : ""))
    }
    If $$$ISOK(tSC) Set tSC = ..Exec("TUNE TABLE " _ ..#TABLE)
    Quit tSC
}

Method OnAfterAllTests() As %Status
{
    Quit ..Drop()
}

/// <p>Drop <parameter>TABLE</parameter> in <parameter>NAMESPACE</parameter> when it is there.</p>
ClassMethod Drop() As %Status
{
    If ..Rows() = "" Quit $$$OK
    Quit ..Exec("DROP TABLE " _ ..#TABLE)
}

/// <p>Run <var>pText</var> with the values <var>pValues</var> in <parameter>NAMESPACE</parameter>, an
/// error status naming its SQLCODE when it fails.</p>
ClassMethod Exec(pText As %String, pValues...) As %Status
{
    Set tSC = $$$OK
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, pText, pValues...)
        Set tCode = tResult.%SQLCODE
        Set tMessage = tResult.%Message
        Set tResult = ""
        Set $NAMESPACE = tOrigNS
        If tCode < 0 Set tSC = $$$ERROR($$$GeneralError, "SQLCODE " _ tCode _ " " _ tMessage _ ": " _ pText)
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p><parameter>TABLE</parameter>'s row count and the sum of its <code>Num</code>, as
/// <code>"&lt;count&gt; &lt;sum&gt;"</code>, or <code>""</code> when it cannot be read.</p>
ClassMethod Rows() As %String
{
    Set tRows = ""
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = ..#NAMESPACE
        Set tResult = ##class(%SQL.Statement).%ExecDirect(, "SELECT COUNT(*), SUM(Num) FROM " _ ..#TABLE)
        If (tResult.%SQLCODE = 0) && tResult.%Next() Set tRows = tResult.%GetData(1) _ " " _ tResult.%GetData(2)
        Set tResult = ""
        Set $NAMESPACE = tOrigNS
    } Catch {
        Set $NAMESPACE = tOrigNS
    }
    Quit tRows
}

/// <p><var>pAnswer</var> or the refusal as one line: on a refusal its status, code and reason.</p>
ClassMethod Said(pSC As %Status, pAnswer, pHttp, pFault) As %String
{
    If $$$ISERR(pSC) Quit $Get(pHttp) _ " " _ $Select($IsObject($Get(pFault)): pFault.%Get("code") _ " " _ pFault.%Get("reason"), 1: "")
    If '$IsObject($Get(pAnswer)) Quit "no answer"
    Quit pAnswer.%ToJSON()
}

/// <p>The refusal every leg expects, as <method>Said</method> writes it.</p>
ClassMethod Refused() As %String
{
    Quit "422 " _ ##class(OcuPilot.Api.AtelierError).#SQLUNRECORDED _ " " _ ##class(OcuPilot.Api.AtelierError).#REASONSQLUNRECORDED
}

/// <p>The query is refused by name, never 500, on a classify, a run and a plan, while the same filter
/// without <code>ESCAPE</code> is classified with its table.</p>
/// <p>Mutation (Rule 19): drop the <code>unrecorded</code> refusal from
/// <method>OcuPilot.Port.SqlPort.Classify</method> -- each refused leg answers 500
/// <code>INTERNAL</code> and goes red.</p>
Method TestAnUnrecordedQueryIsRefusedByName()
{
    Set tSC = $ClassMethod(..#PORT, "Classify", ..#NAMESPACE, "SELECT Num FROM OcuProbe2025.Pets WHERE Name LIKE 'n%'", .tGuard, .tHttp, .tFault)
    Do $$$AssertEquals($Select($$$ISOK(tSC): tGuard.Kind _ " " _ tGuard.Tables.%ToJSON(), 1: ..Said(tSC, "", .tHttp, .tFault)), "query [""OCUPROBE2025.PETS""]", "without ESCAPE the query is recorded with its table")
    Set tSC = $ClassMethod(..#PORT, "Classify", ..#NAMESPACE, ..#ESCAPED, .tGuard, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tSC, "", .tHttp, .tFault), ..Refused(), "classify")
    Set tSC = $ClassMethod(..#PORT, "Run", ..#NAMESPACE, ..#ESCAPED, [], 10, "query", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tSC, .tAnswer, .tHttp, .tFault), ..Refused(), "run")
    Set tSC = $ClassMethod(..#PORT, "Plan", ..#NAMESPACE, ..#ESCAPED, .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tSC, .tAnswer, .tHttp, .tFault), ..Refused(), "plan")
    Do $$$AssertEquals(..Rows(), "30 465", "and the table is as it was made")
}

/// <p>The text the refusal suggests, <code>%NORUNTIME</code> after <code>SELECT</code>, is recorded
/// with its table and runs, its <code>ESCAPE</code> applied.</p>
Method TestNoRuntimeLetsTheQueryBeChecked()
{
    Set tSC = $ClassMethod(..#PORT, "Classify", ..#NAMESPACE, "SELECT %NORUNTIME Num FROM OcuProbe2025.Pets WHERE Name LIKE 'n\%%' ESCAPE '\'", .tGuard, .tHttp, .tFault)
    Do $$$AssertEquals($Select($$$ISOK(tSC): tGuard.Kind _ " " _ tGuard.Tables.%ToJSON(), 1: ..Said(tSC, "", .tHttp, .tFault)), "query [""OCUPROBE2025.PETS""]", "the query is recorded with its table")
    Set tSC = $ClassMethod(..#PORT, "Run", ..#NAMESPACE, "SELECT %NORUNTIME Num FROM OcuProbe2025.Pets WHERE Name LIKE 'n\%%' ESCAPE '\' ORDER BY Num", [], 10, "query", .tAnswer, .tHttp, .tFault)
    Do $$$AssertEquals(..Said(tSC, .tAnswer, .tHttp, .tFault), "{""kind"":""query"",""outcome"":""rows"",""columns"":[""Num""],""rows"":[[""2""]],""truncated"":false}", "and runs, matching only the name holding a literal %")
}

/// <p>Over the wire, the run route and the plan route each answer the query 422
/// <code>EXPLORER.SQL.UNRECORDED</code> with its sentence.</p>
Method TestBothRoutesAnswerTheRefusal()
{
    For tPath = ..#RUN, ..#PLAN {
        Set tBody = {}
        Do tBody.%Set("statement", ..#ESCAPED, "string")
        Do ##class(OcuPilot.Test.Http).AbsoluteRequest("POST", tPath _ "?ns=" _ ..#NAMESPACE, ##class(OcuPilot.Test.Http).GetTestUsername(), ##class(OcuPilot.Test.Http).GetTestPassword(), .tStatus, .tText, .tHeaders, tBody.%ToJSON(), "application/json")
        Set tAnswer = ""
        Try {
            Set tAnswer = ##class(%DynamicObject).%FromJSON(tText)
        } Catch {
            Set tAnswer = ""
        }
        Do $$$AssertEquals($Get(tStatus) _ " " _ $Select($IsObject(tAnswer): tAnswer.%Get("code") _ " " _ tAnswer.%Get("reason"), 1: $Get(tText)), ..Refused(), tPath)
    }
}

}
