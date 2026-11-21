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
/// <p><b>The job</b> (<method>Work</method>) is a supervisor, the background run's own job, which holds the run's lock. It spawns the run's child (<method>Child</method>, through
/// <method>OcuPilot.Kernel.Shell.BackgroundRun.SpawnChild</method>) and waits on the run's event (<method>EventName</method>). The child runs <method>ChildWork</method>:
/// <method>OcuPilot.Port.AnalyticsPort.PmmlRun</method> under the bound <method>BoundSeconds</method>, which reads the answer and drops the test's result rows on every path it ends itself. The run ends
/// <code>canceled</code> on its owner's cancel and <code>stopped</code> at the bound. The SQL text is handed to each job as one <code>JOB</code> argument and is stored nowhere.</p>
/// <p><b>The cancel</b> (<method>CancelJob</method>) ends no process: the stop flag is already set (<method>OcuPilot.Kernel.Shell.BackgroundRun.Cancel</method>), and it signals the run's event and waits for the run to leave <code>running</code>. The supervisor, the
/// child's direct parent, wakes on a signal; it ignores a wake unless the owner's stop flag is set, then ends the child it spawned (never a process id read from storage), drops the result rows of the test id
/// the child recorded (<method>RecordTest</method>) when the record names that child, removes the record, deletes the event, and only then ends the run <code>canceled</code>. The same cleanup follows the
/// bound plus <parameter>GRACESECONDS</parameter> (the run ends <code>stopped</code>) and a child that ends on its own (a run still <code>running</code> ends <code>failed</code>).</p>
/// <p>Seams a fixture subclass overrides: <method>BoundSeconds</method>, <method>MaxRunning</method>, <method>LimitsClass</method>, <method>PortClass</method>, <method>Spawn</method>, <method>ChildWork</method>,
/// <method>EndChild</method> and the <parameter>ENDSECONDS</parameter> and <parameter>GRACESECONDS</parameter> parameters. Production overrides none.</p>
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

/// <p>The supervisor, the job <method>OcuPilot.Kernel.Shell.BackgroundRun.Run</method> spawned, which holds the run's lock for its life and runs after that method's checks (see the class). It creates the
/// run's event (<method>EventName</method>) and asks the stop flag once more, since a cancel made before the event existed found nothing to signal. It then spawns the child
/// (<method>OcuPilot.Kernel.Shell.BackgroundRun.SpawnChild</method>) and waits (<method>Await</method>) until the owner cancels, the child ends, or the bound plus
/// <parameter>GRACESECONDS</parameter> passes. Whatever ends the wait, it ends the child it spawned and no other process, drops that child's rows and removes the record (<method>Reap</method>), deletes the
/// event, and only then ends the run: <code>canceled</code> on a cancel (the owner's flag is set), <code>ended</code> with <code>{outcome: stopped, seconds}</code> past the bound, and <code>failed</code> for a
/// child that ended without ending the run, a child that would not start and a fault here. A run a child already ended is left as it is.</p>
/// <p><b>Terminating the child.</b> The supervisor holds the run's lock, which no one takes from it. The child holds no lock across a wait: the vendor's save of a result row, the store's save of the run's
/// end and the drop's <code>DELETE</code> each lock rows and open a transaction for that one statement or save, and a process that is ended inside one rolls it back and releases its locks as it ends. A result
/// row whose save is cut can therefore stay under the test id, and the supervisor's drop by id, made once the child is gone, removes every row whose index entry was written; the store's save that is cut
/// leaves the run <code>running</code>, and the supervisor's own end then writes the state.</p>
ClassMethod Work(pKey As %String, pUser As %String, pNamespace As %String, pRequest As %List, pClass As %String)
{
    Set tEvent = ..EventName(pKey)
    Set tChild = ""
    Set tOutcome = "failed"
    Try {
        If '..EnsureEvent(tEvent) Do ..Log("a PMML test's event could not be created", $$$ERROR($$$GeneralError, "the event resource was not created; the wait creates it again"))
        If ..StopRequested(pKey) {
            Set tOutcome = "cancel"
        } ElseIf '..SpawnChild(pKey, pUser, pNamespace, pRequest, pClass, .tChild) {
            Do ..Log("a PMML test's child could not be started", $$$ERROR($$$GeneralError, "the spawn was not accepted within " _ ..#SPAWNTIMEOUT _ " seconds"))
        } Else {
            Set tOutcome = ..Await(pKey, tEvent, tChild, ..BoundSeconds() + ..#GRACESECONDS)
        }
    } Catch ex {
        Do ..Log("a PMML test's supervisor failed", ex.AsStatus())
        Set tOutcome = "failed"
    }
    Set tState = $Parameter(..#STORECLASS, "STATEFAILED")
    Set tAnswer = ""
    Try {
        Set tGone = ..Reap(pKey, tChild, tOutcome '= "exited")
        If (tOutcome = "cancel") Set tState = $Parameter(..#STORECLASS, "STATEENDED")
        If (tOutcome = "bound") && tGone {
            Set tState = $Parameter(..#STORECLASS, "STATEENDED")
            Set tAnswer = {"outcome": "stopped", "seconds": (..BoundSeconds())}.%ToJSON()
        }
    } Catch ex {
        Do ..Log("a PMML test's child could not be cleaned up", ex.AsStatus())
    }
    Do ..DropEvent(tEvent)
    Do ..Finish(pKey, tState, tAnswer)
}

/// <p>The child's entry point (<method>OcuPilot.Kernel.Shell.BackgroundRun.SpawnChild</method>): <method>ChildWork</method>, a fault in it ending the run <code>failed</code> with no answer, then a wake for the supervisor.</p>
ClassMethod Child(pKey As %String, pUser As %String, pNamespace As %String, pRequest As %List, pClass As %String)
{
    Try {
        Do $ClassMethod(pClass, "ChildWork", pKey, pUser, pNamespace, pRequest, pClass)
    } Catch ex {
        Do ..Log("a PMML test's job failed", $$$ERROR($$$GeneralError, ex.Name))
        Do ..Finish(pKey, $Parameter(..#STORECLASS, "STATEFAILED"), "")
    }
    Try {
        Do $System.Event.Signal(..EventName(pKey))
    } Catch {
        ; The event is gone, so the supervisor is gone or is re-creating it; it also reads the child's end on its next slice.
    }
}

/// <p>The child's work: the same checks again in its own process, then the run, ending the run <code>ended</code> with its answer, <code>canceled</code> when its owner
/// asked, or <code>failed</code> with a refusal. The SQL is never logged.</p>
ClassMethod ChildWork(pKey As %String, pUser As %String, pNamespace As %String, pRequest As %List, pClass As %String)
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
    Set tCaught = ""
    Try {
        Set tSC = $ClassMethod(tPort, "PmmlRun", pNamespace, tClassName, tName, tSource, tDataSource, tSQL, ..BoundSeconds(), $ClassName(), pKey, .tResult, .tStopped)
    } Catch tException {
        Set tCaught = tException
    }
    Do ..ForgetRecord(pKey)
    If $IsObject(tCaught) Throw tCaught
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

/// <p>The seconds a cancel waits for its run to leave <code>running</code>.</p>
Parameter ENDSECONDS As %Integer = 2;

/// <p>The seconds past <method>BoundSeconds</method> after which the supervisor ends a child that has not ended.</p>
Parameter GRACESECONDS As %Integer = 5;

/// <p>The seconds the supervisor waits for a child it has ended to leave the process table, before it drops nothing and logs it.</p>
Parameter CHILDSECONDS As %Integer = 1;

/// <p>The seconds one wait on the run's event lasts; the child's end and the deadline are read at each wake or timeout.</p>
Parameter WAKESECONDS = 0.5;

/// <p>The seconds the supervisor pauses after a wake it does not act on, so that a flood of signals or deletes costs at most one read of the stop flag per pause.</p>
Parameter WAKEFLOOR = 0.05;

/// <p>Record, in IRISTEMP under the run's key, the calling process and the test id the run's rows carry: <code>$ListBuild($Job, pTestId)</code>. The stop class's hook that
/// <method>OcuPilot.Port.AnalyticsPort.PmmlRun</method> calls before the vendor writes a row. <method>ChildWork</method> removes the record when the run returns, on every path
/// (<method>ForgetRecord</method>); the supervisor removes it when the child did not.</p>
ClassMethod RecordTest(pKey As %String, pTestId As %Integer)
{
    Set ^IRIS.Temp.OcuPilotPmmlRun(pKey) = $ListBuild($Job, pTestId)
}

/// <p>Remove run <var>pKey</var>'s record (<method>RecordTest</method>).</p>
ClassMethod ForgetRecord(pKey As %String)
{
    Kill ^IRIS.Temp.OcuPilotPmmlRun(pKey)
}

/// <p>The name of run <var>pKey</var>'s event resource, which the supervisor waits on and a cancel signals. The resource is unguarded: any process may signal or delete it, so the supervisor
/// acts on a wake only when the owner's stop flag is set, and re-creates a deleted resource.</p>
ClassMethod EventName(pKey As %String) As %String
{
    Quit $Name(^IRIS.Temp.OcuPilotPmmlCancel(pKey))
}

/// <p>Whether the event resource <var>pEvent</var> exists after this call: it is created, or already there.</p>
ClassMethod EnsureEvent(pEvent As %String) As %Boolean [ Private ]
{
    Set tHeld = 0
    Try {
        Set tHeld = ($System.Event.Create(pEvent) = 1) || ($System.Event.Defined(pEvent) > 0)
    } Catch {
        Set tHeld = 0
    }
    Quit tHeld
}

/// <p>Delete the event resource <var>pEvent</var>; a resource that is already gone, or a delete that throws, is not a failure.</p>
ClassMethod DropEvent(pEvent As %String) [ Private ]
{
    Try {
        Do $System.Event.Delete(pEvent)
    } Catch {
        ; Nothing is waiting on it any more.
    }
}

/// <p>Wait on run <var>pKey</var>'s event <var>pEvent</var> until one of three things, answered as its name: <code>exited</code> when child <var>pChild</var> has left the process table;
/// <code>cancel</code> on a wake while the owner's stop flag is set; <code>bound</code> after <var>pSeconds</var>. A wake with the flag clear is ignored, and the next wait comes no sooner than
/// <parameter>WAKEFLOOR</parameter> seconds later. A deleted event (the wait answers -1, or throws because the resource is not there) is re-created, and the flag is read again, because a cancel's signal
/// may have found no event; an event that cannot be re-created is logged once and tried again after <parameter>WAKESECONDS</parameter>, so no process but the owner's cancel, the child's end or the deadline ends
/// the wait.</p>
ClassMethod Await(pKey As %String, pEvent As %String, pChild As %Integer, pSeconds As %Numeric) As %String [ Private ]
{
    Set tDeadline = $ZHorolog + pSeconds
    Set tOutcome = ""
    Set tLogged = 0
    For {
        Set tWoke = 0
        Try {
            Set tWoke = $System.Event.Wait(pEvent, ..#WAKESECONDS)
        } Catch {
            Set tWoke = -1
        }
        If (tWoke = -1) && '..EnsureEvent(pEvent) {
            If 'tLogged Do ..Log("a PMML test's event could not be created again", $$$ERROR($$$GeneralError, "the event resource was deleted and not created"))
            Set tLogged = 1
            Hang ..#WAKESECONDS
        }
        If '$Data(^$JOB(pChild)) {
            Set tOutcome = "exited"
        } ElseIf (tWoke '= 0) && ..StopRequested(pKey) {
            Set tOutcome = "cancel"
        } ElseIf $ZHorolog > tDeadline {
            Set tOutcome = "bound"
        } ElseIf tWoke '= 0 {
            Hang ..#WAKEFLOOR
        }
        If tOutcome '= "" Quit
    }
    Quit tOutcome
}

/// <p>Clean up after child <var>pChild</var> of run <var>pKey</var>. When <var>pEnd</var> is set and the child is in the process table, end it (<method>EndChild</method>), the supervisor being its direct
/// parent, and wait up to <parameter>CHILDSECONDS</parameter> for it to leave; a child still there is logged and waited for up to <method>BoundSeconds</method> plus <parameter>GRACESECONDS</parameter> more.
/// Then drop the rows of the test id the record holds when the record names that child (<method>OcuPilot.Port.AnalyticsPort.PmmlDrop</method>), whatever process it names otherwise, and remove the record, so
/// the run's end that follows never finds them. Answers whether the child is gone. A child that outlasts both waits and goes on writing drops its own rows when its run returns.</p>
ClassMethod Reap(pKey As %String, pChild As %Integer, pEnd As %Boolean) As %Boolean [ Private ]
{
    Set tGone = 1
    If pEnd && (pChild '= "") && $Data(^$JOB(pChild)) {
        Try {
            Set tEnded = ..EndChild(pChild)
            If tEnded '= 1 Do ..Log("a PMML test's child could not be ended", $$$ERROR($$$GeneralError, "Terminate answered " _ tEnded))
        } Catch ex {
            Do ..Log("a PMML test's child could not be ended", ex.AsStatus())
        }
        Set tGone = ..AwaitGone(pChild, ..#CHILDSECONDS)
        If 'tGone {
            Do ..Log("a PMML test's child did not end", $$$ERROR($$$GeneralError, "the process was still in the process table after " _ ..#CHILDSECONDS _ " seconds"))
            Try {
                Do ..EndChild(pChild)
            } Catch {
                ; Already logged once; the wait below decides.
            }
            Set tGone = ..AwaitGone(pChild, ..BoundSeconds() + ..#GRACESECONDS)
        }
    }
    Set tRecord = $Get(^IRIS.Temp.OcuPilotPmmlRun(pKey))
    If '$ListValid(tRecord) Set tRecord = ""
    Do ..ForgetRecord(pKey)
    Set tTestId = $ListGet(tRecord, 2)
    If (pChild '= "") && ($ListGet(tRecord, 1) = pChild) && (tTestId '= "") Do $ClassMethod(..PortClass(), "PmmlDrop", tTestId)
    Quit tGone
}

/// <p>End child <var>pChild</var>, the process <method>OcuPilot.Kernel.Shell.BackgroundRun.SpawnChild</method> answered, with the person's own rights; <code>$SYSTEM.Process.Terminate</code>'s answer, 1 when the
/// end was sent. A seam: a fixture overrides it.</p>
ClassMethod EndChild(pChild As %Integer) As %Integer [ Private ]
{
    Quit $SYSTEM.Process.Terminate(pChild)
}

/// <p>Wait up to <var>pSeconds</var> for process <var>pChild</var> to leave the process table; whether it has.</p>
ClassMethod AwaitGone(pChild As %Integer, pSeconds As %Numeric) As %Boolean [ Private ]
{
    Set tEnd = $ZHorolog + pSeconds
    While $Data(^$JOB(pChild)) && ($ZHorolog < tEnd) {
        Hang 0.005
    }
    Quit '$Data(^$JOB(pChild))
}

/// <p>What a cancel does to run <var>pId</var>, whose owner's stop flag is set: it signals the run's event (<method>EventName</method>) and waits up to <parameter>ENDSECONDS</parameter> for the run to
/// leave <code>running</code> as its owner reads it. It acts only when <var>pLive</var> says the process that holds the run's lock is live, and it ends no process: the supervisor, the child's direct parent,
/// ends the child (<method>Work</method>), so the cancel lands from any process of the owner. A signal that finds no event, because the supervisor has not created it yet or has just deleted it, is not a fault:
/// the supervisor reads the flag after it creates the event. A run whose rows take longer than the wait to drop reads <code>running</code> in the cancel's own answer, and <code>canceled</code> once the
/// supervisor has dropped them.</p>
ClassMethod CancelJob(pId As %String, pUser As %String, pJobId As %String, pLive As %Boolean) As %Status
{
    Set tSC = $$$OK
    Try {
        If 'pLive || (pJobId = "") Quit
        Try {
            Do $System.Event.Signal(..EventName(pId))
        } Catch tSignal {
            If tSignal.Name '= "<UNDEFINED>" Do ..Log("a PMML test's cancel could not be signaled", tSignal.AsStatus())
        }
        Set tEnd = $ZHorolog + ..#ENDSECONDS
        For {
            Set tView = ""
            Set tViewSC = ..View(pId, pUser, .tFound, .tView)
            If $$$ISERR(tViewSC) || '$Get(tFound) || (tView.%Get("status") '= ..#STATUSRUNNING) || ($ZHorolog > tEnd) Quit
            Hang 0.005
        }
    } Catch ex {
        Do ..Log("a PMML test's cancel failed", ex.AsStatus())
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
