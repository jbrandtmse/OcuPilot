/// <p>The PMML model tester's background run (Story 24.14, AD-7, AD-41, AD-42, AD-65): <code>POST /analytics/pmml/background</code> starts one test of one model in a job and answers its
/// run id at once; <code>GET /analytics/pmml/background/:id</code> answers the run as its owner reads it; <code>POST /analytics/pmml/background/:id/cancel</code> asks it to stop. Each answers
/// this screen only (AD-36, AD-39's sixth exception). The routes, the run row, the job and the owner-scoped 404 are <class>OcuPilot.Kernel.Shell.BackgroundRun</class>'s, with the run kind
/// <code>pmml</code>; this class is the PMML kind: its checks, its work and its codes. Every vendor call goes through <class>OcuPilot.Port.AnalyticsPort</class>.</p>
/// <p><b>The start's body</b> is <code>{model, source, dataSource?, sql?}</code>: <code>model</code> is the model's composite id <code>[Class, Model]</code> or the vendor's
/// <code>Class||Model</code>; <code>source</code> is <code>dataset</code>, <code>verification</code> or <code>custom</code>; <code>dataSource</code>, the name of one of the definition's data
/// sources, is required for <code>dataset</code> and allowed for no other; <code>sql</code>, one query of 1 to <parameter>OcuPilot.Port.AnalyticsPort.MDXMAXSTATEMENT</parameter> characters, is required
/// for <code>custom</code> and allowed for no other. Any other key or shape is 400 <code>ANALYTICS.PMML.INPUT</code>.</p>
/// <p><b>The start's checks, which the job repeats</b> (<method>Check</method>): the port's gate and the resolution of the model and its source
/// (<method>OcuPilot.Port.AnalyticsPort.PmmlResolve</method>: the definition, the model, a declared data source or verification records, a cube source's cube); then, for an SQL source, a custom one or a
/// declared one, SQL query's own classification and self-protection check (<method>OcuPilot.Area.Explorer.SqlConsole.Check</method>), which must type it a query, 422
/// <code>ANALYTICS.PMML.QUERYONLY</code> otherwise. An SQL the instance would not prepare is answered at once, <code>{outcome: error, ...}</code>, as SQL query answers it. Nothing is reserved or spawned for a
/// refusal or an immediate answer.</p>
/// <p><b>The job</b> (<method>Work</method>) runs <method>OcuPilot.Port.AnalyticsPort.PmmlRun</method> under the bound <method>BoundSeconds</method>, which reads the answer and drops the test's result rows
/// on every path. The run ends <code>canceled</code> on its owner's cancel and <code>stopped</code> at the bound. The SQL text is handed to the job as one <code>JOB</code> argument and is stored nowhere.</p>
/// <p>Seams a fixture subclass overrides: <method>BoundSeconds</method>, <method>MaxRunning</method>, <method>LimitsClass</method>, <method>PortClass</method>, <method>Spawn</method>, <method>Work</method>
/// and the <code>CANCEL*</code> parameters. Production overrides none.</p>
Class OcuPilot.Area.Analytics.PmmlTest Extends OcuPilot.Kernel.Shell.BackgroundRun
{

/// <p>The screen the three routes and the job answer for: the model's Test screen.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsPmmlModelTest";

/// <p>The kind this class's runs carry in the store.</p>
Parameter RUNKIND = "pmml";

/// <p>The subsystem the job's failures are logged under.</p>
Parameter LOGSUBSYSTEM = "pmmlbackground";

/// <p>The console whose classification, self-protection check and error answer an SQL source takes.</p>
Parameter CONSOLECLASS = "OcuPilot.Area.Explorer.SqlConsole";

/// <p>The port the job runs its test through.</p>
ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Port.AnalyticsPort"
}

/// <p>The seconds a run is bounded to. A fixture subclass overrides it; production never does.</p>
ClassMethod BoundSeconds() As %Numeric
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).#MDXSECONDS
}

/// <p>The start's checks (see the class); a refusal or an immediate answer is rendered here and <var>pDone</var> is 1. Otherwise the request list is
/// <code>$ListBuild(model, source, dataSource, sql)</code>.</p>
ClassMethod Admit(Output pNamespace As %String, Output pRequest As %List, Output pDone As %Boolean) As %Status
{
    Set pNamespace = ""
    Set pRequest = ""
    Set pDone = 1
    Set tSC = $$$OK
    Try {
        Set tSC = ..Gate(.tRefused)
        If tRefused || $$$ISERR(tSC) Quit
        Set tReadSC = ##class(OcuPilot.Kernel.Utils).ReadRequestBody(.tBody, .tStage)
        If $$$ISERR(tReadSC) || '$IsObject(tBody) || 'tBody.%IsA("%Library.DynamicObject") || '..Body(tBody, .tModel, .tSource, .tDataSource, .tSQL) {
            Set tSC = ..RenderInput()
            Quit
        }
        Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
        Set tCheckSC = ..Check(tNamespace, tModel, tSource, tDataSource, tSQL, .tAnswer, .tHttp, .tFault)
        If $$$ISERR(tCheckSC) {
            Set tSC = ..RenderPortFault(tCheckSC, $Get(tHttp), $Get(tFault))
            Quit
        }
        If $IsObject($Get(tAnswer)) {
            Set tSC = ..Reply(200, tAnswer)
            Quit
        }
        Set pNamespace = tNamespace
        Set pRequest = $ListBuild(tModel, tSource, tDataSource, tSQL)
        Set pDone = 0
    } Catch ex {
        Set pDone = 1
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the PMML run's start failed: " _ ex.Name)))
    }
    Quit tSC
}

/// <p>The checks both the start and the job make, in order, executing nothing: the port's resolution of the model and its source
/// (<method>OcuPilot.Port.AnalyticsPort.PmmlResolve</method>); then, for a source that runs SQL, the console's classification and self-protection check. A refusal is an error status with
/// <var>pHttp</var> and <var>pFault</var>. Otherwise <var>pAnswer</var> is the error answer of an SQL the instance would not prepare, or <code>""</code> when the run may proceed.</p>
ClassMethod Check(pNamespace As %String, pModel As %String, pSource As %String, pDataSource As %String, pSQL As %String, Output pAnswer As %DynamicObject, Output pHttp As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pAnswer = ""
    Set pHttp = 0
    Set pFault = ""
    Set tPort = ..PortClass()
    If '$ClassMethod(tPort, "PmmlParts", pModel, .tClass, .tName) Quit ..InputFault(.pHttp, .pFault)
    Set tSC = $ClassMethod(tPort, "PmmlResolve", pNamespace, tClass, tName, pSource, pDataSource, pSQL, .tRunSQL, .pHttp, .pFault)
    If $$$ISERR(tSC) || (tRunSQL = "") Quit tSC
    Set tSC = $ClassMethod(..#CONSOLECLASS, "Check", pNamespace, tRunSQL, .tGuard, .pHttp, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set pAnswer = $ClassMethod(..#CONSOLECLASS, "ErrorOutcome", tGuard)
    If $IsObject(pAnswer) Quit $$$OK
    If tGuard.%Get("Kind") '= ##class(OcuPilot.Port.SqlPort).#KINDQUERY {
        Set pFault = ..QueryOnly(.pHttp)
        Quit $$$ERROR($$$GeneralError, pFault.code)
    }
    Quit $$$OK
}

/// <p>Read <var>pBody</var> into the model, the source, the data source and the SQL, answering 0 for any key but the four, a value of the wrong shape, a model that names no class, a source that
/// is not one of the three, a data source on any source but <code>dataset</code> or none on it, or SQL on any source but <code>custom</code> or none, or a blank one, on it.</p>
ClassMethod Body(pBody As %DynamicObject, Output pModel As %String, Output pSource As %String, Output pDataSource As %String, Output pSQL As %String) As %Boolean [ Private ]
{
    Set (pModel, pSource, pDataSource, pSQL) = ""
    Set tPort = ..PortClass()
    Set tStray = 0
    Set tIterator = pBody.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If '$ListFind($ListBuild("model", "source", "dataSource", "sql"), tKey) Set tStray = 1
    }
    If tStray Quit 0
    If pBody.%GetTypeOf("model") '= "string" Quit 0
    Set pModel = pBody.%Get("model")
    If '$ClassMethod(tPort, "PmmlParts", pModel, .tClass, .tName) Quit 0
    If pBody.%GetTypeOf("source") '= "string" Quit 0
    Set pSource = pBody.%Get("source")
    Set tDataSourceType = pBody.%GetTypeOf("dataSource")
    Set tSQLType = pBody.%GetTypeOf("sql")
    If pSource = $Parameter(tPort, "PMMLSOURCEDATASET") {
        If (tDataSourceType '= "string") || (tSQLType '= "unassigned") Quit 0
        Set pDataSource = pBody.%Get("dataSource")
        Quit (pDataSource '= "") && ($Length(pDataSource) <= $Parameter(tPort, "MDXMAXCELL"))
    }
    If pSource = $Parameter(tPort, "PMMLSOURCECUSTOM") {
        If (tSQLType '= "string") || (tDataSourceType '= "unassigned") Quit 0
        Set pSQL = pBody.%Get("sql")
        Quit '$ClassMethod(tPort, "MdxBlank", pSQL) && ($Length(pSQL) <= $Parameter(tPort, "MDXMAXSTATEMENT"))
    }
    If pSource '= $Parameter(tPort, "PMMLSOURCEVERIFICATION") Quit 0
    Quit (tDataSourceType = "unassigned") && (tSQLType = "unassigned")
}

/// <p>The job's work, after the shared checks (see the class): the same checks again in its own process, then the run, ending the run <code>ended</code> with its answer, <code>canceled</code> when its owner
/// asked, or <code>failed</code> with a refusal. The SQL is never logged.</p>
ClassMethod Work(pKey As %String, pUser As %String, pNamespace As %String, pRequest As %List, pClass As %String)
{
    Set tModel = $ListGet(pRequest, 1)
    Set tSource = $ListGet(pRequest, 2)
    Set tDataSource = $ListGet(pRequest, 3)
    Set tSQL = $ListGet(pRequest, 4)
    Set tEnded = $Parameter(..#STORECLASS, "STATEENDED")
    Set tSC = ..Check(pNamespace, tModel, tSource, tDataSource, tSQL, .tAnswer, .tHttp, .tFault)
    If $$$ISERR(tSC) {
        Do ..FinishRefused(pKey, tSC, $Get(tFault))
        Quit
    }
    If $IsObject($Get(tAnswer)) {
        Do ..Finish(pKey, tEnded, tAnswer.%ToJSON())
        Quit
    }
    Set tPort = ..PortClass()
    If '$ClassMethod(tPort, "PmmlParts", tModel, .tClassName, .tName) {
        Do ..Finish(pKey, $Parameter(..#STORECLASS, "STATEFAILED"), "")
        Quit
    }
    Set tSC = $ClassMethod(tPort, "PmmlRun", pNamespace, tClassName, tName, tSource, tDataSource, tSQL, ..BoundSeconds(), $ClassName(), pKey, .tResult, .tStopped)
    If $$$ISERR(tSC) {
        Do ..FinishRefused(pKey, tSC, "")
        Quit
    }
    If tStopped = "request" {
        Do ..Finish(pKey, tEnded, "")
        Quit
    }
    Do ..Finish(pKey, tEnded, tResult.%ToJSON())
}

/// <p>The seconds <code>$SYSTEM.SQL.CancelQuery</code> is given to stop the job's statement, how many times, with a pause between, a cancel is sent again while the job is not inside a statement,
/// and the seconds in all a cancel request spends on it.</p>
Parameter CANCELSECONDS As %Integer = 3;

Parameter CANCELTRIES As %Integer = 100;

Parameter CANCELPAUSE = 0.1;

Parameter CANCELBUDGET As %Integer = 10;

/// <p>What a cancel sends to the job: <code>$SYSTEM.SQL.CancelQuery</code>, which reaches the statement the job runs, the data source's or the custom one, whose rows the vendor reads one at a time and
/// runs the model on between reads. An interrupt is accepted only while the job is inside a statement, so the cancel is given <parameter>CANCELSECONDS</parameter> seconds to meet it and is sent up to
/// <parameter>CANCELTRIES</parameter> times in all; it is not sent again once <parameter>CANCELBUDGET</parameter> seconds have passed, so a request returns within that budget plus one send's
/// <parameter>CANCELSECONDS</parameter>, and a run that never enters a statement goes on to the vendor's end. Once the statement ends the vendor's loop ends and the job, which reads its owner's flag then,
/// ends the run <code>canceled</code>.</p>
ClassMethod CancelJob(pId As %String, pUser As %String, pJobId As %String, pLive As %Boolean) As %Status
{
    Set tSC = $$$OK
    Set tJobId = pJobId
    Set tLive = pLive
    Set tEnd = $ZHorolog + ..#CANCELBUDGET
    For tTry = 1:1:..#CANCELTRIES {
        If 'tLive || (tJobId = "") || ($ZHorolog >= tEnd) Quit
        If $$$ISOK($SYSTEM.SQL.CancelQuery(tJobId, , ..#CANCELSECONDS)) Quit
        Hang ..#CANCELPAUSE
        Set tSC = $ClassMethod(..#STORECLASS, "GuardedCancel", pId, pUser, .tStill, .tJobId, .tLive, ..#RUNKIND)
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
}

/// <p>The code of the shared refusal <var>pName</var>: the four <code>ANALYTICS.PMML.*</code> run codes.</p>
ClassMethod CodeFor(pName As %String) As %String
{
    Quit $Case(pName, "busy": ##class(OcuPilot.Api.AnalyticsError).#PMMLBUSY, "full": ##class(OcuPilot.Api.AnalyticsError).#PMMLFULL, "notfound": ##class(OcuPilot.Api.AnalyticsError).#PMMLNOTFOUND, "lost": ##class(OcuPilot.Api.AnalyticsError).#PMMLLOST, : "")
}

/// <p>The written reason of the shared refusal <var>pName</var>.</p>
ClassMethod ReasonFor(pName As %String) As %String
{
    Quit ##class(OcuPilot.Api.AnalyticsError).ReasonFor(..CodeFor(pName))
}

/// <p>Write <var>pBody</var> with the status <var>pHttp</var>.</p>
ClassMethod Reply(pHttp As %Integer, pBody As %DynamicObject) As %Status
{
    Quit $Select(pHttp = 200: ##class(OcuPilot.Api.Response).JSON(pBody), 1: ##class(OcuPilot.Api.Response).JSONStatus(pHttp, pBody))
}

/// <p>The 400 <code>ANALYTICS.PMML.INPUT</code> envelope.</p>
ClassMethod RenderInput() As %Status [ Private ]
{
    Quit ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.AnalyticsError).#REASONPMMLINPUT, ##class(OcuPilot.Api.AnalyticsError).#PMMLINPUT)
}

/// <p>The 400 <code>ANALYTICS.PMML.INPUT</code> fault, as an error status with <var>pHttp</var> and <var>pFault</var>.</p>
ClassMethod InputFault(Output pHttp As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttp = 400
    Set pFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.AnalyticsError).#PMMLINPUT, ##class(OcuPilot.Api.AnalyticsError).#REASONPMMLINPUT)
    Quit $$$ERROR($$$GeneralError, pFault.code)
}

/// <p>The 422 <code>ANALYTICS.PMML.QUERYONLY</code> fault.</p>
ClassMethod QueryOnly(Output pHttp As %Integer) As %DynamicObject [ Private ]
{
    Set pHttp = 422
    Quit ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.AnalyticsError).#PMMLQUERYONLY, ##class(OcuPilot.Api.AnalyticsError).#REASONPMMLQUERYONLY)
}

}
