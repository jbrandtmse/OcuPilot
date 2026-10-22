/// <p>SQL query's background run (Story 19.15, AD-7, AD-42): <code>POST
/// /explorer/sql/background</code> starts one query in a job and answers its run id at once;
/// <code>GET /explorer/sql/background/:id</code> answers the run as its owner reads it; <code>POST
/// /explorer/sql/background/:id/cancel</code> asks it to stop. Each answers this screen only (AD-36,
/// AD-39's sixth exception). The routes, the run row, the job and the owner-scoped 404 are
/// <class>OcuPilot.Kernel.Shell.BackgroundRun</class>'s; this class is the SQL kind: its checks, its work and its codes.</p>
/// <p><b>Only a query runs in the background.</b> The start keeps the run route's order -- the screen
/// gate, the body, its bounds, the classification, the self-protection check and the value count
/// (<class>OcuPilot.Area.Explorer.SqlConsole</class>) -- refuses every kind but
/// <parameter>OcuPilot.Port.SqlPort.KINDQUERY</parameter> (<method>Admit</method>), then reserves the run
/// (<method>OcuPilot.Kernel.State.SqlRun.GuardedReserve</method>), and only then spawns its job.</p>
/// <p><b>The job</b> takes the statement, its values and Max rows as one <code>JOB</code> argument and
/// stores none of them; it repeats the gate and the checks in its own process before its one statement
/// (<method>Work</method>), and is bounded by the port's alarm.</p>
/// <p>Seams a fixture subclass overrides: <method>PortClass</method>, <method>MaxRunning</method>,
/// <method>LimitsClass</method> and <method>Spawn</method>. Production overrides none.</p>
Class OcuPilot.Area.Explorer.SqlBackground Extends OcuPilot.Kernel.Shell.BackgroundRun
{

/// <p>The screen the three routes and the job answer for.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerSqlQuery";

/// <p>The kind this class's runs carry in the store.</p>
Parameter RUNKIND = "sql";

/// <p>The console whose gate, body read and checks the start reuses.</p>
Parameter CONSOLECLASS = "OcuPilot.Area.Explorer.SqlConsole";

/// <p>The seconds <code>$SYSTEM.SQL.CancelQuery</code> is given to stop the job's query.</p>
Parameter CANCELSECONDS As %Integer = 3;

/// <p>How many times a cancel the job is not yet ready for is sent again, and the seconds between: a
/// job that has begun but not yet reached its statement answers that it runs no query.</p>
Parameter CANCELTRIES As %Integer = 10;

Parameter CANCELPAUSE = 0.2;

/// <p>The subsystem the job's failures are logged under.</p>
Parameter LOGSUBSYSTEM = "sqlbackground";

/// <p>The port the job runs its statement through.</p>
ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Port.SqlPort"
}

/// <p>The start's checks: <code>{outcome: error}</code> for a statement the instance would not prepare and <code>{outcome:
/// parameters, count}</code> when the values do not number its value positions, as the run route answers them; then 422
/// <code>EXPLORER.SQL.BACKGROUND.QUERYONLY</code> for any kind but a query. Each is rendered here and <var>pDone</var> is 1.
/// Otherwise the request list is <code>$ListBuild(statement, $ListBuild(values...), maxRows)</code>.</p>
ClassMethod Admit(Output pNamespace As %String, Output pRequest As %List, Output pDone As %Boolean) As %Status
{
    Set pNamespace = ""
    Set pRequest = ""
    Set pDone = 1
    Set tSC = $$$OK
    Try {
        Set tSC = $ClassMethod(..#CONSOLECLASS, "Read", .tRefused, .tNamespace, .tText, .tValues, .tMaxRows)
        If tRefused Quit
        Set tCheckSC = $ClassMethod(..#CONSOLECLASS, "Check", tNamespace, tText, .tGuard, .tHttp, .tFault)
        If $$$ISERR(tCheckSC) {
            If '$IsObject($Get(tFault)) {
                Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tCheckSC))
                Quit
            }
            Set tSC = $ClassMethod(..#CONSOLECLASS, "RenderFault", tCheckSC, $Get(tHttp), tFault)
            Quit
        }
        Set tAnswer = $ClassMethod(..#CONSOLECLASS, "ErrorOutcome", tGuard)
        If $IsObject(tAnswer) {
            Set tSC = ##class(OcuPilot.Api.Response).JSON(tAnswer)
            Quit
        }
        If tValues.%Size() '= tGuard.%Get("Parameters") {
            Set tAnswer = {}
            Do tAnswer.%Set("outcome", $Parameter(..#CONSOLECLASS, "OUTCOMEPARAMETERS"), "string")
            Do tAnswer.%Set("count", +tGuard.%Get("Parameters"), "number")
            Set tSC = ##class(OcuPilot.Api.Response).JSON(tAnswer)
            Quit
        }
        If tGuard.%Get("Kind") '= ##class(OcuPilot.Port.SqlPort).#KINDQUERY {
            Set tFault = ..QueryOnly(.tHttp)
            Set tSC = ..Render(tFault, tHttp)
            Quit
        }
        Set pNamespace = tNamespace
        Set pRequest = ..RequestOf(tText, tValues, tMaxRows)
        Set pDone = 0
    } Catch ex {
        Set pDone = 1
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the background run's start failed: " _ ex.Name)))
    }
    Quit tSC
}

/// <p>Reserve a run of the caller's query <var>pText</var> in <var>pNamespace</var> and spawn its job,
/// with the values <var>pValues</var> and the row cap <var>pMaxRows</var>; <var>pKey</var> is the run's
/// id. The caller has already checked the statement. A refusal is an error status with
/// <var>pHttp</var> and <var>pFault</var>, as <method>OcuPilot.Kernel.Shell.BackgroundRun.Begin</method>
/// answers them: 409 <code>EXPLORER.SQL.BACKGROUND.BUSY</code>, 503
/// <code>EXPLORER.SQL.BACKGROUND.FULL</code> and 503 <code>EXPLORER.SQL.BACKGROUND.LOST</code>.</p>
ClassMethod Start(pNamespace As %String, pText As %String, pValues As %DynamicArray, pMaxRows As %Integer, Output pKey As %String, Output pHttp As %Integer, Output pFault As %DynamicObject) As %Status
{
    Quit ..Begin(pNamespace, ..RequestOf(pText, pValues, pMaxRows), .pKey, .pHttp, .pFault)
}

/// <p>The request list the job is handed: <code>$ListBuild(statement, $ListBuild(values...), maxRows)</code>.</p>
ClassMethod RequestOf(pText As %String, pValues As %DynamicArray, pMaxRows As %Integer) As %List [ Private ]
{
    Set tValues = ""
    Set tIterator = pValues.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tValue) {
        Set tValues = tValues _ $ListBuild(tValue)
    }
    Quit $ListBuild(pText, tValues, +pMaxRows)
}

/// <p>The job's work, after the shared checks: it repeats the classification, the self-protection check and the query-only check,
/// a refusal ending the run <code>failed</code> with its envelope, and it runs the statement through the port and ends the run with
/// the port's answer.</p>
ClassMethod Work(pKey As %String, pUser As %String, pNamespace As %String, pRequest As %List, pClass As %String)
{
    Set tText = $ListGet(pRequest, 1)
    Set tValues = []
    Set tList = $ListGet(pRequest, 2)
    For tI = 1:1:$ListLength(tList) {
        Do tValues.%Push($ListGet(tList, tI), "string")
    }
    Set tMaxRows = $ListGet(pRequest, 3)
    Set tSC = $ClassMethod(..#CONSOLECLASS, "Check", pNamespace, tText, .tGuard, .tHttp, .tFault)
    If $$$ISERR(tSC) {
        Do ..FinishRefused(pKey, tSC, $Get(tFault))
        Quit
    }
    If (tGuard.%GetTypeOf("error") '= "object") && (tGuard.%Get("Kind") '= ##class(OcuPilot.Port.SqlPort).#KINDQUERY) {
        Do ..Finish(pKey, $Parameter(..#STORECLASS, "STATEFAILED"), ..Envelope(..QueryOnly(.tHttp)).%ToJSON())
        Quit
    }
    Set tSC = $ClassMethod(..PortClass(), "Run", pNamespace, tText, tValues, tMaxRows, "query", .tAnswer, .tHttp, .tFault)
    If $$$ISERR(tSC) {
        Do ..FinishRefused(pKey, tSC, $Get(tFault))
        Quit
    }
    Do ..Finish(pKey, $Parameter(..#STORECLASS, "STATEENDED"), tAnswer.%ToJSON())
}

/// <p>Cancel the job's query with <code>$SYSTEM.SQL.CancelQuery</code>, from the cancel request, while the job holds the run's lock,
/// and send it again for up to <parameter>CANCELTRIES</parameter> tries while the job, having begun, runs no query yet.</p>
ClassMethod CancelJob(pId As %String, pUser As %String, pJobId As %String, pLive As %Boolean) As %Status
{
    Set tSC = $$$OK
    Set tJobId = pJobId
    Set tLive = pLive
    For tTry = 1:1:..#CANCELTRIES {
        If 'tLive || (tJobId = "") Quit
        If $$$ISOK($SYSTEM.SQL.CancelQuery(tJobId, , ..#CANCELSECONDS)) Quit
        Hang ..#CANCELPAUSE
        Set tSC = $ClassMethod(..#STORECLASS, "GuardedCancel", pId, pUser, .tStill, .tJobId, .tLive, ..#RUNKIND)
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
}

/// <p>Write <var>pBody</var> with the status <var>pHttp</var>.</p>
ClassMethod Reply(pHttp As %Integer, pBody As %DynamicObject) As %Status
{
    Quit $Select(pHttp = 200: ##class(OcuPilot.Api.Response).JSON(pBody), 1: ##class(OcuPilot.Api.Response).JSONStatus(pHttp, pBody))
}

/// <p>The code of the shared refusal <var>pName</var>: the five <code>EXPLORER.SQL.BACKGROUND.*</code> codes.</p>
ClassMethod CodeFor(pName As %String) As %String
{
    Quit $Case(pName, "busy": ##class(OcuPilot.Api.AtelierError).#SQLBACKGROUNDBUSY, "full": ##class(OcuPilot.Api.AtelierError).#SQLBACKGROUNDFULL, "notfound": ##class(OcuPilot.Api.AtelierError).#SQLBACKGROUNDNOTFOUND, "lost": ##class(OcuPilot.Api.AtelierError).#SQLBACKGROUNDLOST, : "")
}

/// <p>The written reason of the shared refusal <var>pName</var>.</p>
ClassMethod ReasonFor(pName As %String) As %String
{
    Quit $Case(pName, "busy": ##class(OcuPilot.Api.AtelierError).#REASONSQLBACKGROUNDBUSY, "full": ##class(OcuPilot.Api.AtelierError).#REASONSQLBACKGROUNDFULL, "notfound": ##class(OcuPilot.Api.AtelierError).#REASONSQLBACKGROUNDNOTFOUND, "lost": ##class(OcuPilot.Api.AtelierError).#REASONSQLBACKGROUNDLOST, : "")
}

/// <p>The 422 <code>EXPLORER.SQL.BACKGROUND.QUERYONLY</code> fault.</p>
ClassMethod QueryOnly(Output pHttp As %Integer) As %DynamicObject [ Private ]
{
    Set pHttp = 422
    Quit ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.AtelierError).#SQLBACKGROUNDQUERYONLY, ##class(OcuPilot.Api.AtelierError).#REASONSQLBACKGROUNDQUERYONLY)
}

}
