/// <p>SQL query's background run (Story 19.15, AD-7, AD-42): <code>POST
/// /explorer/sql/background</code> starts one query in a job and answers its run id at once;
/// <code>GET /explorer/sql/background/:id</code> answers the run as its owner reads it; <code>POST
/// /explorer/sql/background/:id/cancel</code> asks it to stop. Each answers this screen only (AD-36,
/// AD-39's sixth exception).</p>
/// <p><b>Only a query runs in the background.</b> The start keeps the run route's order -- the screen
/// gate, the body, its bounds, the classification, the self-protection check and the value count
/// (<class>OcuPilot.Area.Explorer.SqlConsole</class>) -- refuses every kind but
/// <parameter>OcuPilot.Port.SqlPort.KINDQUERY</parameter>, then reserves the run
/// (<method>OcuPilot.Kernel.State.SqlRun.GuardedReserve</method>), and only then spawns its job.</p>
/// <p><b>The job</b> (<method>Run</method>) is the fourth process spawn site AD-42 names. It is
/// spawned from no escalated frame and inherits the caller's <code>$USERNAME</code> and
/// <code>$ROLES</code>; it takes the statement, its values and Max rows as one <code>JOB</code>
/// argument and stores none of them; it repeats the gate and the checks in its own process before its
/// one statement, holds the run's lock for its life, and is bounded by the port's alarm.</p>
/// <p><b>A run belongs to its owner.</b> Another user's run, an unknown id and a swept run each
/// answer the same 404. The answer is kept in OcuPilot's protected state for the owner's poll alone
/// until it is swept; nothing of the statement, its values, its rows or its SQL error is logged.</p>
/// <p>Seams a fixture subclass overrides: <method>PortClass</method>, <method>MaxRunning</method> and
/// <method>LimitsClass</method>. Production overrides none.</p>
Class OcuPilot.Area.Explorer.SqlBackground Extends %RegisteredObject
{

/// <p>The screen the three routes and the job answer for.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ExplorerSqlQuery";

/// <p>The console whose gate, body read and checks the start reuses.</p>
Parameter CONSOLECLASS = "OcuPilot.Area.Explorer.SqlConsole";

/// <p>The store a run is kept in.</p>
Parameter STORECLASS = "OcuPilot.Kernel.State.SqlRun";

/// <p>Seconds the start waits for the spawn to be accepted.</p>
Parameter SPAWNTIMEOUT As %Integer = 5;

/// <p>The shape of a run id: 32 lower-case hex characters. Any other id is not found before any store
/// read.</p>
Parameter IDPATTERN = "^[0-9a-f]{32}$";

/// <p>The seconds <code>$SYSTEM.SQL.CancelQuery</code> is given to stop the job's query.</p>
Parameter CANCELSECONDS As %Integer = 3;

/// <p>How many times a cancel the job is not yet ready for is sent again, and the seconds between: a
/// job that has begun but not yet reached its statement answers that it runs no query.</p>
Parameter CANCELTRIES As %Integer = 10;

Parameter CANCELPAUSE = 0.2;

/// <p>The status a run answers while it is queued or running.</p>
Parameter STATUSRUNNING = "running";

/// <p>The subsystem the job's failures are logged under.</p>
Parameter LOGSUBSYSTEM = "sqlbackground";

/// <p>The port the job runs its statement through.</p>
ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Port.SqlPort"
}

/// <p>How many runs the instance may have queued or running at once (AD-41).</p>
ClassMethod MaxRunning() As %Integer
{
    Quit 5
}

/// <p>The class the store reads its retention and queued limits from.</p>
ClassMethod LimitsClass() As %String
{
    Quit "OcuPilot.Kernel.Agent.Limits"
}

/// <p>Answer <code>POST /explorer/sql/background</code> in the request's scope: 202 <code>{id,
/// status}</code> once the job is spawned. Before that, as the run route answers them,
/// <code>{outcome: error}</code> for a statement the instance would not prepare and <code>{outcome:
/// parameters, count}</code> when the values do not number its value positions; then 422
/// <code>EXPLORER.SQL.BACKGROUND.QUERYONLY</code> for any kind but a query, and
/// <method>Start</method>'s refusals. A refusal is one envelope, and nothing is spawned before every
/// check has passed.</p>
ClassMethod HandleStart() As %Status
{
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
        Set tStartSC = ..Start(tNamespace, tText, tValues, tMaxRows, .tKey, .tHttp, .tFault)
        If $$$ISERR(tStartSC) {
            If '$IsObject($Get(tFault)) {
                Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tStartSC))
                Quit
            }
            Set tSC = ..Render(tFault, tHttp)
            Quit
        }
        Set tBody = {}
        Do tBody.%Set("id", tKey, "string")
        Do tBody.%Set("status", ..#STATUSRUNNING, "string")
        Set tSC = ##class(OcuPilot.Api.Response).JSONStatus(202, tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the background run's start failed: " _ ex.Name)))
    }
    Quit tSC
}

/// <p>Answer <code>GET /explorer/sql/background/:id</code>: the caller's own run (<method>View</method>).
/// Another user's run, an unknown id, a swept run and an id of any other shape each answer 404
/// <code>EXPLORER.SQL.BACKGROUND.NOTFOUND</code>.</p>
ClassMethod HandlePoll(pId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = $ClassMethod(..#CONSOLECLASS, "Gate", .tRefused)
        If tRefused || $$$ISERR(tSC) Quit
        If '$Match(pId, ..#IDPATTERN) {
            Set tSC = ..RenderNotFound()
            Quit
        }
        Set tSC = ..RenderView(pId)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the background run's poll failed: " _ ex.Name)))
    }
    Quit tSC
}

/// <p>Answer <code>POST /explorer/sql/background/:id/cancel</code>: ask the caller's own run to stop
/// and answer it as it then reads. A running run's query is canceled with
/// <code>$SYSTEM.SQL.CancelQuery</code> on its own job, from this request, and only while that job
/// holds the run's lock (<method>Cancel</method>); an ended run is answered as it is. The same 404 as
/// a poll answers anyone else.</p>
ClassMethod HandleCancel(pId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = $ClassMethod(..#CONSOLECLASS, "Gate", .tRefused)
        If tRefused || $$$ISERR(tSC) Quit
        If '$Match(pId, ..#IDPATTERN) {
            Set tSC = ..RenderNotFound()
            Quit
        }
        Set tCancelSC = ..Cancel(pId, $Username, .tFound)
        If $$$ISERR(tCancelSC) {
            Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tCancelSC))
            Quit
        }
        If 'tFound {
            Set tSC = ..RenderNotFound()
            Quit
        }
        Set tSC = ..RenderView(pId)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the background run's cancel failed: " _ ex.Name)))
    }
    Quit tSC
}

/// <p>Reserve a run of the caller's query <var>pText</var> in <var>pNamespace</var> and spawn its job,
/// with the values <var>pValues</var> and the row cap <var>pMaxRows</var>; <var>pKey</var> is the run's
/// id. The caller has already checked the statement. A refusal is an error status with
/// <var>pHttp</var> and <var>pFault</var>: 409 <code>EXPLORER.SQL.BACKGROUND.BUSY</code>, whose
/// <code>detail.runId</code> names the caller's running run; 503
/// <code>EXPLORER.SQL.BACKGROUND.FULL</code> at <method>MaxRunning</method>; and 503
/// <code>EXPLORER.SQL.BACKGROUND.LOST</code> when the spawn is not accepted, the run then ended
/// <code>failed</code>. Neither of the first two spawns anything.</p>
/// <p>Caller contract: no <code>New $ROLES</code> escalation is in effect in any frame of the caller's
/// stack (AD-9), because a job keeps the roles it was spawned with.</p>
ClassMethod Start(pNamespace As %String, pText As %String, pValues As %DynamicArray, pMaxRows As %Integer, Output pKey As %String, Output pHttp As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pKey = ""
    Set pHttp = 0
    Set pFault = ""
    Set tUser = $Username
    Set tSC = $ClassMethod(..#STORECLASS, "GuardedReserve", tUser, pNamespace, ..MaxRunning(), ..LimitsClass(), .tKey, .tBusyKey, .tFull, .tSweepSC)
    If $$$ISERR(tSC) Quit tSC
    If $$$ISERR(tSweepSC) Do ..Log("expired background runs could not be swept", tSweepSC)
    If tBusyKey '= "" {
        Set pFault = ..Busy(tBusyKey, .pHttp)
        Quit $$$ERROR($$$GeneralError, pFault.code)
    }
    If tFull {
        Set pFault = ..Full(.pHttp)
        Quit $$$ERROR($$$GeneralError, pFault.code)
    }
    Set tValues = ""
    Set tIterator = pValues.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tValue) {
        Set tValues = tValues _ $ListBuild(tValue)
    }
    If '..Spawn(tKey, tUser, pNamespace, $ListBuild(pText, tValues, +pMaxRows), .tChild) {
        Do ..Log("the background run's job could not be started", $$$ERROR($$$GeneralError, "the spawn was not accepted within " _ ..#SPAWNTIMEOUT _ " seconds"))
        Set tFinishSC = $ClassMethod(..#STORECLASS, "GuardedFinish", tKey, $Parameter(..#STORECLASS, "STATEFAILED"), "")
        If $$$ISERR(tFinishSC) Do ..Log("a run whose job did not start could not be ended", tFinishSC)
        Set pFault = ..Lost(.pHttp)
        Quit $$$ERROR($$$GeneralError, pFault.code)
    }
    Set pKey = tKey
    Quit $$$OK
}

/// <p>Spawn the job for run <var>pKey</var> of <var>pUser</var> in <var>pNamespace</var>, with
/// <var>pRequest</var> -- <code>$ListBuild(statement, $ListBuild(values...), maxRows)</code> -- as its
/// one argument, and answer whether the <code>JOB</code> was accepted within
/// <parameter>SPAWNTIMEOUT</parameter> seconds; <var>pChild</var> is the job's process id when it was.
/// The one <code>JOB</code> in this class: the job runs in this process's namespace, and is handed
/// this class's name so a fixture's seams apply in it.</p>
ClassMethod Spawn(pKey As %String, pUser As %String, pNamespace As %String, pRequest As %List, Output pChild As %Integer) As %Boolean
{
    Set pChild = ""
    Job ##class(OcuPilot.Area.Explorer.SqlBackground).Run(pKey, pUser, pNamespace, pRequest, $ClassName()):($Namespace):..#SPAWNTIMEOUT
    If '$Test Quit 0
    Set pChild = $ZChild
    Quit 1
}

/// <p>The job's entry point, spawned by <method>Spawn</method> and never called directly.
/// <var>pClass</var> is the class whose seams apply.</p>
/// <p>In this order: it refuses a <code>$USERNAME</code> that is not <var>pUser</var>, ending the run
/// <code>failed</code>; it begins the run, or ends it <code>canceled</code> when the owner asked
/// before it began; it repeats the screen's gate, the classic page's custom resource included, then
/// the classification, the self-protection check and the query-only check, a refusal ending the run
/// <code>failed</code> with its envelope; and it runs the statement through the port and ends the run
/// with the port's answer. Any other fault is logged with nothing of the statement and ends the run
/// <code>failed</code> with no answer, which reads as lost.</p>
ClassMethod Run(pKey As %String, pUser As %String, pNamespace As %String, pRequest As %List, pClass As %String)
{
    Set tStore = ..#STORECLASS
    Set tFailed = $Parameter(tStore, "STATEFAILED")
    Set tBegun = 0
    Try {
        If $Username '= pUser {
            Do ..Log("the background run's job did not start as its owner", $$$ERROR($$$GeneralError, "user differs from the start"))
            Do ..Finish(pKey, tFailed, "")
            Quit
        }
        Set tSC = $ClassMethod(tStore, "GuardedBegin", pKey, pUser, .tBegun, .tCancel)
        If $$$ISERR(tSC) || 'tBegun {
            Do ..Log("the background run could not be begun", $Select($$$ISERR(tSC): tSC, 1: $$$ERROR($$$GeneralError, "the run was no longer queued for this user, or its lock was held")))
            Do ..Finish(pKey, tFailed, "")
            Quit
        }
        If tCancel {
            Do ..Finish(pKey, $Parameter(tStore, "STATEENDED"), "")
            Quit
        }
        Set tFailedPair = ""
        If '##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) {
            Set tRefusal = {}
            Do tRefusal.%Set("code", ##class(OcuPilot.Kernel.Denial).Code(), "string")
            Do tRefusal.%Set("reason", ##class(OcuPilot.Kernel.Denial).Reason(), "string")
            Set tDetail = ##class(OcuPilot.Kernel.Denial).Detail(tFailedPair)
            If $IsObject(tDetail) Do tRefusal.%Set("detail", tDetail)
            Do ..Finish(pKey, tFailed, tRefusal.%ToJSON())
            Quit
        }
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
            Do ..Finish(pKey, tFailed, ..Envelope(..QueryOnly(.tHttp)).%ToJSON())
            Quit
        }
        Set tSC = $ClassMethod($ClassMethod(pClass, "PortClass"), "Run", pNamespace, tText, tValues, tMaxRows, "query", .tAnswer, .tHttp, .tFault)
        If $$$ISERR(tSC) {
            Do ..FinishRefused(pKey, tSC, $Get(tFault))
            Quit
        }
        Do ..Finish(pKey, $Parameter(tStore, "STATEENDED"), tAnswer.%ToJSON())
    } Catch ex {
        Do ..Log("the background run's job failed", $$$ERROR($$$GeneralError, ex.Name))
        Do ..Finish(pKey, tFailed, "")
    }
}

/// <p>End run <var>pKey</var> <code>failed</code> after the check or the run answered the error status
/// <var>pStatus</var>: with <var>pFault</var>'s envelope when it is a refusal the caller decided, and,
/// logged, with no answer, which reads as lost, when it is an internal failure. <var>pStatus</var>
/// names a code and a written reason, never the statement.</p>
ClassMethod FinishRefused(pKey As %String, pStatus As %Status, pFault) [ Private ]
{
    Set tFailed = $Parameter(..#STORECLASS, "STATEFAILED")
    If '$IsObject(pFault) || (pFault.%Get("code") = ##class(OcuPilot.Api.Error).#INTERNAL) {
        Do ..Log("the background run's statement did not run", pStatus)
        Do ..Finish(pKey, tFailed, "")
        Quit
    }
    Set tRefusal = {}
    Do tRefusal.%Set("code", pFault.%Get("code"), "string")
    Do tRefusal.%Set("reason", pFault.%Get("reason"), "string")
    If pFault.%GetTypeOf("detail") = "object" Do tRefusal.%Set("detail", pFault.%Get("detail"))
    Do ..Finish(pKey, tFailed, tRefusal.%ToJSON())
}

/// <p>Ask run <var>pId</var> of <var>pUser</var> to stop (<method>OcuPilot.Kernel.State.SqlRun.GuardedCancel</method>),
/// and, while its job holds the run's lock, cancel the job's query with
/// <code>$SYSTEM.SQL.CancelQuery</code>, sent again for up to <parameter>CANCELTRIES</parameter>
/// tries while the job, having begun, runs no query yet. <var>pFound</var> is 0 for anyone but the
/// owner.</p>
ClassMethod Cancel(pId As %String, pUser As %String, Output pFound As %Boolean) As %Status
{
    Set pFound = 0
    Set tSC = $ClassMethod(..#STORECLASS, "GuardedCancel", pId, pUser, .pFound, .tJobId, .tLive)
    If $$$ISERR(tSC) || 'pFound Quit tSC
    For tTry = 1:1:..#CANCELTRIES {
        If 'tLive || (tJobId = "") Quit
        If $$$ISOK($SYSTEM.SQL.CancelQuery(tJobId, , ..#CANCELSECONDS)) Quit
        Hang ..#CANCELPAUSE
        Set tSC = $ClassMethod(..#STORECLASS, "GuardedCancel", pId, pUser, .tStill, .tJobId, .tLive)
        If $$$ISERR(tSC) Quit
    }
    Quit tSC
}

/// <p>Render run <var>pId</var> as the caller reads it (<method>View</method>), or the 404 when it is
/// not the caller's.</p>
ClassMethod RenderView(pId As %String) As %Status [ Private ]
{
    Set tSC = ..View(pId, $Username, .tFound, .tView)
    If $$$ISERR(tSC) Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tSC))
    If 'tFound Quit ..RenderNotFound()
    Quit ##class(OcuPilot.Api.Response).JSON(tView)
}

/// <p>Run <var>pId</var> as its owner <var>pUser</var> reads it: <code>{id, status, startedAt,
/// endedAt, cancelRequested, result?, refusal?}</code>, a failed run that stored no refusal answered
/// with <code>EXPLORER.SQL.BACKGROUND.LOST</code>'s.</p>
ClassMethod View(pId As %String, pUser As %String, Output pFound As %Boolean, Output pView As %DynamicObject) As %Status
{
    Set tSC = $ClassMethod(..#STORECLASS, "GuardedViewForOwner", pId, pUser, ..LimitsClass(), .pFound, .pView)
    If $$$ISERR(tSC) || 'pFound Quit tSC
    If (pView.%Get("status") = $Parameter(..#STORECLASS, "STATEFAILED")) && (pView.%GetTypeOf("refusal") '= "object") {
        Do pView.%Set("refusal", ..Envelope(..Lost(.tHttp)))
    }
    Quit $$$OK
}

/// <p>The 422 <code>EXPLORER.SQL.BACKGROUND.QUERYONLY</code> fault.</p>
ClassMethod QueryOnly(Output pHttp As %Integer) As %DynamicObject [ Private ]
{
    Set pHttp = 422
    Quit ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#VALIDATIONFAILED, ##class(OcuPilot.Api.AtelierError).#SQLBACKGROUNDQUERYONLY, ##class(OcuPilot.Api.AtelierError).#REASONSQLBACKGROUNDQUERYONLY)
}

/// <p>The 409 <code>EXPLORER.SQL.BACKGROUND.BUSY</code> fault, <code>detail.runId</code> naming the
/// caller's running run <var>pRunId</var>.</p>
ClassMethod Busy(pRunId As %String, Output pHttp As %Integer) As %DynamicObject [ Private ]
{
    Set pHttp = 409
    Set tFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.AtelierError).#SQLBACKGROUNDBUSY, ##class(OcuPilot.Api.AtelierError).#REASONSQLBACKGROUNDBUSY)
    Set tDetail = {}
    Do tDetail.%Set("runId", pRunId, "string")
    Do tFault.%Set("detail", tDetail)
    Quit tFault
}

/// <p>The 503 <code>EXPLORER.SQL.BACKGROUND.FULL</code> fault.</p>
ClassMethod Full(Output pHttp As %Integer) As %DynamicObject [ Private ]
{
    Set pHttp = 503
    Quit ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#UNAVAILABLE, ##class(OcuPilot.Api.AtelierError).#SQLBACKGROUNDFULL, ##class(OcuPilot.Api.AtelierError).#REASONSQLBACKGROUNDFULL)
}

/// <p>The 404 <code>EXPLORER.SQL.BACKGROUND.NOTFOUND</code> fault.</p>
ClassMethod NotFound(Output pHttp As %Integer) As %DynamicObject [ Private ]
{
    Set pHttp = 404
    Quit ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#NOTFOUND, ##class(OcuPilot.Api.AtelierError).#SQLBACKGROUNDNOTFOUND, ##class(OcuPilot.Api.AtelierError).#REASONSQLBACKGROUNDNOTFOUND)
}

/// <p>The 503 <code>EXPLORER.SQL.BACKGROUND.LOST</code> fault: a run that ended without an answer.</p>
ClassMethod Lost(Output pHttp As %Integer) As %DynamicObject [ Private ]
{
    Set pHttp = 503
    Quit ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#UNAVAILABLE, ##class(OcuPilot.Api.AtelierError).#SQLBACKGROUNDLOST, ##class(OcuPilot.Api.AtelierError).#REASONSQLBACKGROUNDLOST)
}

/// <p><var>pFault</var> as a run's stored refusal: <code>{code, reason, detail?}</code>.</p>
ClassMethod Envelope(pFault As %DynamicObject) As %DynamicObject [ Private ]
{
    Set tRefusal = {}
    Do tRefusal.%Set("code", pFault.%Get("code"), "string")
    Do tRefusal.%Set("reason", pFault.%Get("reason"), "string")
    If pFault.%GetTypeOf("detail") = "object" Do tRefusal.%Set("detail", pFault.%Get("detail"))
    Quit tRefusal
}

/// <p>Render <var>pFault</var> with the status <var>pHttp</var> (AD-12, AD-39).</p>
ClassMethod Render(pFault As %DynamicObject, pHttp As %Integer) As %Status [ Private ]
{
    Quit ##class(OcuPilot.Api.Error).Render(+pHttp, pFault.%Get("error"), pFault.%Get("reason"), pFault.%Get("code"), pFault.%Get("detail"))
}

/// <p>Render the 404 <code>EXPLORER.SQL.BACKGROUND.NOTFOUND</code>; the id is not echoed back.</p>
ClassMethod RenderNotFound() As %Status [ Private ]
{
    Set tFault = ..NotFound(.tHttp)
    Quit ..Render(tFault, tHttp)
}

/// <p><method>OcuPilot.Kernel.State.SqlRun.GuardedFinish</method>, with a failure logged.</p>
ClassMethod Finish(pKey As %String, pState As %String, pAnswerJson As %String) [ Private ]
{
    Set tSC = $ClassMethod(..#STORECLASS, "GuardedFinish", pKey, pState, pAnswerJson)
    If $$$ISERR(tSC) Do ..Log("the background run could not be ended", tSC)
}

/// <p>Log <var>pStatus</var> under <parameter>LOGSUBSYSTEM</parameter> with
/// <code>EXPLORER.SQL.BACKGROUND.LOST</code>. Every caller builds <var>pStatus</var> from an exception's
/// name, a store's status or a fixed sentence, never from a statement, a value or an answer.</p>
ClassMethod Log(pMessage As %String, pStatus As %Status) [ Private ]
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, pMessage, pStatus, ##class(OcuPilot.Api.AtelierError).#SQLBACKGROUNDLOST)
}

}
