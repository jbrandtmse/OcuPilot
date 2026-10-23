/// <p>The background run two screens share (Story 19.15's SQL query, Story 20.33's MDX query; AD-7, AD-33, AD-41, AD-42): a start
/// route that answers a run id at once, a poll route that answers the run as its owner reads it, and a cancel route that asks it
/// to stop. A kind extends this class and supplies its own checks, its own work and its own codes; everything else is here:
/// the run row (<class>OcuPilot.Kernel.State.SqlRun</class>), the one <code>JOB</code>, the job's owner check, begin, cancel
/// before begin and second screen gate, the owner-scoped 404, and the written reasons of the shared refusals. Each route answers
/// its screen only (AD-36, AD-39's sixth exception).</p>
/// <p><b>The kind's hooks</b> (class methods a subclass overrides; the base answers a refusing default):</p>
/// <ul>
/// <li><method>Admit</method> -- the start's checks. It answers a refusal or an immediate answer itself, or hands back the
/// namespace and the request list the job is given.</li>
/// <li><method>Work</method> -- the job's work after the shared checks, ending its own run.</li>
/// <li><method>CancelJob</method> -- what a cancel sends to the running job.</li>
/// <li><method>Reply</method> -- the JSON answer of the start and the poll, through the API's writer.</li>
/// <li><method>CodeFor</method> and <method>ReasonFor</method> -- the code and the written reason of the shared refusals.</li>
/// <li><parameter>RUNKIND</parameter>, <parameter>DESCRIPTORCLASS</parameter> and <parameter>LOGSUBSYSTEM</parameter>, and the seams
/// <method>PortClass</method>, <method>MaxRunning</method>, <method>LimitsClass</method> and <method>Spawn</method>, which a
/// fixture subclass overrides; production overrides none.</li>
/// </ul>
/// <p><b>The job</b> (<method>Run</method>) is the one process spawn site this class holds (AD-42). It is spawned from no escalated
/// frame and inherits the caller's <code>$USERNAME</code> and <code>$ROLES</code>; it takes the request as one <code>JOB</code>
/// argument and stores none of it; it holds the run's lock for its life. <method>Spawn</method> hands the job the invoked
/// class's name, so a fixture's seams apply in it.</p>
/// <p><b>A run belongs to its owner and its kind.</b> Another user's run, another kind's run, an unknown id and a swept run each
/// answer the same 404. The answer is kept in OcuPilot's protected state for the owner's poll alone until it is swept; nothing of
/// the request, its rows or its vendor error is logged.</p>
Class OcuPilot.Kernel.Shell.BackgroundRun Extends %RegisteredObject [ Abstract ]
{

/// <p>The screen the routes and the job answer for.</p>
Parameter DESCRIPTORCLASS = "";

/// <p>The store a run is kept in.</p>
Parameter STORECLASS = "OcuPilot.Kernel.State.SqlRun";

/// <p>The kind a subclass's runs carry in the store.</p>
Parameter RUNKIND = "";

/// <p>Seconds the start waits for the spawn to be accepted.</p>
Parameter SPAWNTIMEOUT As %Integer = 5;

/// <p>The shape of a run id: 32 lower-case hex characters. Any other id is not found before any store read.</p>
Parameter IDPATTERN = "^[0-9a-f]{32}$";

/// <p>The status a run answers while it is queued or running.</p>
Parameter STATUSRUNNING = "running";

/// <p>The subsystem the job's failures are logged under.</p>
Parameter LOGSUBSYSTEM = "backgroundrun";

/// <p>The port the job runs its work through; a subclass names its own.</p>
ClassMethod PortClass() As %String
{
    Quit ""
}

/// <p>How many runs the instance may have queued or running at once, of every kind together (AD-41).</p>
ClassMethod MaxRunning() As %Integer
{
    Quit 5
}

/// <p>The class the store reads its retention and queued limits from.</p>
ClassMethod LimitsClass() As %String
{
    Quit "OcuPilot.Kernel.Agent.Limits"
}

/// <p>The start's checks, in the request's scope. A refusal or an answer that needs no run is rendered here and
/// <var>pDone</var> is 1. Otherwise <var>pDone</var> is 0, <var>pNamespace</var> is the request's scope and
/// <var>pRequest</var> the <code>$ListBuild</code> list the job is handed. Nothing is reserved or spawned before every check
/// has passed. The base refuses.</p>
ClassMethod Admit(Output pNamespace As %String, Output pRequest As %List, Output pDone As %Boolean) As %Status
{
    Set pNamespace = ""
    Set pRequest = ""
    Set pDone = 1
    Quit $$$OK
}

/// <p>The job's work, called in the job after the shared checks (the owner, begin, cancel before begin and the screen gate), with the
/// request <var>pRequest</var> <method>Admit</method> handed over. It repeats its kind's checks, does the work and ends the run
/// (<method>Finish</method> or <method>FinishRefused</method>). The base ends the run <code>failed</code>.</p>
ClassMethod Work(pKey As %String, pUser As %String, pNamespace As %String, pRequest As %List, pClass As %String)
{
    Do ..Finish(pKey, $Parameter(..#STORECLASS, "STATEFAILED"), "")
}

/// <p>What a cancel sends to run <var>pId</var> of <var>pUser</var>, whose job <var>pJobId</var> holds the run's lock when
/// <var>pLive</var> is 1, called after the cancel flag is set. The base sends nothing.</p>
ClassMethod CancelJob(pId As %String, pUser As %String, pJobId As %String, pLive As %Boolean) As %Status
{
    Quit $$$OK
}

/// <p>Write the JSON body <var>pBody</var> with the status <var>pHttp</var> (200, or 202 for an accepted start) through the API's
/// response writer, which the shell never names (dependency direction); each kind answers through
/// <class>OcuPilot.Api.Response</class>. The base answers an error status.</p>
ClassMethod Reply(pHttp As %Integer, pBody As %DynamicObject) As %Status
{
    Quit $$$ERROR($$$GeneralError, "a background run kind answers through Reply")
}

/// <p>The code of the shared refusal <var>pName</var> (<code>busy</code>, <code>full</code>, <code>notfound</code> or
/// <code>lost</code>).</p>
ClassMethod CodeFor(pName As %String) As %String
{
    Quit ""
}

/// <p>The written reason of the shared refusal <var>pName</var>.</p>
ClassMethod ReasonFor(pName As %String) As %String
{
    Quit ""
}

/// <p>Answer the start route: 202 <code>{id, status}</code> once the job is spawned, after <method>Admit</method>'s own answer or
/// refusal when it gave one, and <method>Begin</method>'s refusals. A refusal is one envelope, and nothing is spawned before every
/// check has passed.</p>
ClassMethod HandleStart() As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..Admit(.tNamespace, .tRequest, .tDone)
        If $$$ISERR(tSC) || tDone Quit
        Set tStartSC = ..Begin(tNamespace, tRequest, .tKey, .tHttp, .tFault)
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
        Set tSC = ..Reply(202, tBody)
    } Catch ex {
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the background run's start failed: " _ ex.Name)))
    }
    Quit tSC
}

/// <p>Answer the poll route: the caller's own run (<method>View</method>). Another user's run, another kind's, an unknown id, a
/// swept run and an id of any other shape each answer the kind's 404.</p>
ClassMethod HandlePoll(pId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..Gate(.tRefused)
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

/// <p>Answer the cancel route: ask the caller's own run to stop and answer it as it then reads
/// (<method>Cancel</method>). An ended run is answered as it is. The same 404 as a poll answers anyone else.</p>
ClassMethod HandleCancel(pId As %String) As %Status
{
    Set tSC = $$$OK
    Try {
        Set tSC = ..Gate(.tRefused)
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

/// <p>Refuse a caller who does not hold the screen's pairs, the classic page's custom resource included (AD-8, AD-44):
/// <var>pRefused</var> 1 means the envelope is written.</p>
ClassMethod Gate(Output pRefused As %Boolean) As %Status
{
    Set pRefused = 0
    Set tFailedPair = ""
    If ##class(OcuPilot.Screen.Gate).Evaluate(..#DESCRIPTORCLASS, .tFailedPair) Quit $$$OK
    Set pRefused = 1
    Quit ##class(OcuPilot.Kernel.Denial).Envelope(tFailedPair)
}

/// <p>Reserve a run of this kind for the caller in <var>pNamespace</var> and spawn its job with the request list
/// <var>pRequest</var>; <var>pKey</var> is the run's id. The caller has already checked the request. A refusal is an error
/// status with <var>pHttp</var> and <var>pFault</var>: 409 for the caller's own live run of this kind, whose
/// <code>detail.runId</code> names it; 503 at <method>MaxRunning</method> live runs of every kind; and 503 when the spawn is not
/// accepted, the run then ended <code>failed</code>. Neither of the first two spawns anything.</p>
/// <p>Caller contract: no <code>New $ROLES</code> escalation is in effect in any frame of the caller's stack (AD-9), because a
/// job keeps the roles it was spawned with.</p>
ClassMethod Begin(pNamespace As %String, pRequest As %List, Output pKey As %String, Output pHttp As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pKey = ""
    Set pHttp = 0
    Set pFault = ""
    Set tUser = $Username
    Set tSC = $ClassMethod(..#STORECLASS, "GuardedReserve", tUser, pNamespace, ..MaxRunning(), ..LimitsClass(), .tKey, .tBusyKey, .tFull, .tSweepSC, ..#RUNKIND)
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
    If '..Spawn(tKey, tUser, pNamespace, pRequest, .tChild) {
        Do ..Log("the background run's job could not be started", $$$ERROR($$$GeneralError, "the spawn was not accepted within " _ ..#SPAWNTIMEOUT _ " seconds"))
        Set tFinishSC = $ClassMethod(..#STORECLASS, "GuardedFinish", tKey, $Parameter(..#STORECLASS, "STATEFAILED"), "")
        If $$$ISERR(tFinishSC) Do ..Log("a run whose job did not start could not be ended", tFinishSC)
        Set pFault = ..Lost(.pHttp)
        Quit $$$ERROR($$$GeneralError, pFault.code)
    }
    Set pKey = tKey
    Quit $$$OK
}

/// <p>Spawn the job for run <var>pKey</var> of <var>pUser</var> in <var>pNamespace</var>, with <var>pRequest</var> as its one
/// argument, and answer whether the <code>JOB</code> was accepted within <parameter>SPAWNTIMEOUT</parameter> seconds;
/// <var>pChild</var> is the job's process id when it was. The one <code>JOB</code> in this class: the job runs in this
/// process's namespace and is handed the invoked class's name, so a fixture's seams apply in it.</p>
ClassMethod Spawn(pKey As %String, pUser As %String, pNamespace As %String, pRequest As %List, Output pChild As %Integer) As %Boolean
{
    Set pChild = ""
    Job ##class(OcuPilot.Kernel.Shell.BackgroundRun).Enter(pKey, pUser, pNamespace, pRequest, $ClassName()):($Namespace):..#SPAWNTIMEOUT
    If '$Test Quit 0
    Set pChild = $ZChild
    Quit 1
}

/// <p>The job's entry point, spawned by <method>Spawn</method> and never called directly: it runs <var>pClass</var>'s own
/// <method>Run</method>, so the kind's parameters and seams are the ones in effect.</p>
ClassMethod Enter(pKey As %String, pUser As %String, pNamespace As %String, pRequest As %List, pClass As %String)
{
    Do $ClassMethod(pClass, "Run", pKey, pUser, pNamespace, pRequest, pClass)
}

/// <p>The job's body, run by <method>Enter</method>. <var>pClass</var> is the class whose seams apply.</p>
/// <p>In this order: it refuses a <code>$USERNAME</code> that is not <var>pUser</var>, ending the run <code>failed</code>; it begins
/// the run, or ends it <code>canceled</code> when the owner asked before it began; it repeats the screen's gate, the classic page's
/// custom resource included, a refusal ending the run <code>failed</code> with its envelope; and it calls <method>Work</method>.
/// Any fault is logged with nothing of the request and ends the run <code>failed</code> with no answer, which reads as lost.</p>
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
        Do $ClassMethod(pClass, "Work", pKey, pUser, pNamespace, pRequest, pClass)
    } Catch ex {
        Do ..Log("the background run's job failed", $$$ERROR($$$GeneralError, ex.Name))
        Do ..Finish(pKey, tFailed, "")
    }
}

/// <p>End run <var>pKey</var> <code>failed</code> after a check or the work answered the error status <var>pStatus</var>: with
/// <var>pFault</var>'s envelope when it is a refusal the caller decided, and, logged, with no answer, which reads as lost, when it
/// is an internal failure. <var>pStatus</var> names a code and a written reason, never the request.</p>
ClassMethod FinishRefused(pKey As %String, pStatus As %Status, pFault) [ Private ]
{
    Set tFailed = $Parameter(..#STORECLASS, "STATEFAILED")
    If '$IsObject(pFault) || (pFault.%Get("code") = ##class(OcuPilot.Api.Error).#INTERNAL) {
        Do ..Log("the background run did not run", pStatus)
        Do ..Finish(pKey, tFailed, "")
        Quit
    }
    Do ..Finish(pKey, tFailed, ..Envelope(pFault).%ToJSON())
}

/// <p>Ask run <var>pId</var> of <var>pUser</var> to stop (<method>OcuPilot.Kernel.State.SqlRun.GuardedCancel</method>) and send the
/// kind's cancel to its job (<method>CancelJob</method>). <var>pFound</var> is 0 for anyone but the owner, and for another kind's
/// run.</p>
ClassMethod Cancel(pId As %String, pUser As %String, Output pFound As %Boolean) As %Status
{
    Set pFound = 0
    Set tSC = $ClassMethod(..#STORECLASS, "GuardedCancel", pId, pUser, .pFound, .tJobId, .tLive, ..#RUNKIND)
    If $$$ISERR(tSC) || 'pFound Quit tSC
    Quit ..CancelJob(pId, pUser, tJobId, tLive)
}

/// <p>Render run <var>pId</var> as the caller reads it (<method>View</method>), or the 404 when it is not the caller's.</p>
ClassMethod RenderView(pId As %String) As %Status [ Private ]
{
    Set tSC = ..View(pId, $Username, .tFound, .tView)
    If $$$ISERR(tSC) Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(tSC))
    If 'tFound Quit ..RenderNotFound()
    Quit ..Reply(200, tView)
}

/// <p>Run <var>pId</var> as its owner <var>pUser</var> reads it: <code>{id, status, startedAt, endedAt, cancelRequested, result?,
/// refusal?}</code>, a failed run that stored no refusal answered with the kind's <code>lost</code> refusal.</p>
ClassMethod View(pId As %String, pUser As %String, Output pFound As %Boolean, Output pView As %DynamicObject) As %Status
{
    Set tSC = $ClassMethod(..#STORECLASS, "GuardedViewForOwner", pId, pUser, ..LimitsClass(), .pFound, .pView, ..#RUNKIND)
    If $$$ISERR(tSC) || 'pFound Quit tSC
    If (pView.%Get("status") = $Parameter(..#STORECLASS, "STATEFAILED")) && (pView.%GetTypeOf("refusal") '= "object") {
        Do pView.%Set("refusal", ..Envelope(..Lost(.tHttp)))
    }
    Quit $$$OK
}

/// <p>The 409 <code>busy</code> fault, <code>detail.runId</code> naming the caller's running run <var>pRunId</var>.</p>
ClassMethod Busy(pRunId As %String, Output pHttp As %Integer) As %DynamicObject [ Private ]
{
    Set pHttp = 409
    Set tFault = ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#CONFLICT, ..CodeFor("busy"), ..ReasonFor("busy"))
    Set tDetail = {}
    Do tDetail.%Set("runId", pRunId, "string")
    Do tFault.%Set("detail", tDetail)
    Quit tFault
}

/// <p>The 503 <code>full</code> fault.</p>
ClassMethod Full(Output pHttp As %Integer) As %DynamicObject [ Private ]
{
    Set pHttp = 503
    Quit ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#UNAVAILABLE, ..CodeFor("full"), ..ReasonFor("full"))
}

/// <p>The 404 <code>notfound</code> fault.</p>
ClassMethod NotFound(Output pHttp As %Integer) As %DynamicObject [ Private ]
{
    Set pHttp = 404
    Quit ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#NOTFOUND, ..CodeFor("notfound"), ..ReasonFor("notfound"))
}

/// <p>The 503 <code>lost</code> fault: a run that ended without an answer.</p>
ClassMethod Lost(Output pHttp As %Integer) As %DynamicObject [ Private ]
{
    Set pHttp = 503
    Quit ##class(OcuPilot.Kernel.Fault).Build(##class(OcuPilot.Api.Error).#UNAVAILABLE, ..CodeFor("lost"), ..ReasonFor("lost"))
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

/// <p>Render the 404 <code>notfound</code> refusal; the id is not echoed back.</p>
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

/// <p>Log <var>pStatus</var> under <parameter>LOGSUBSYSTEM</parameter> with the kind's <code>lost</code> code. Every caller builds
/// <var>pStatus</var> from an exception's name, a store's status or a fixed sentence, never from a request, a value or an
/// answer.</p>
ClassMethod Log(pMessage As %String, pStatus As %Status) [ Private ]
{
    Do ##class(OcuPilot.Kernel.Fault).LogRaw(..#LOGSUBSYSTEM, pMessage, pStatus, ..CodeFor("lost"))
}

}
