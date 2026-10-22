/// <p>MDX query's background run (Story 20.33, AD-7, AD-33, AD-41, AD-42, AD-65): <code>POST /analytics/mdx/background</code> starts one MDX
/// statement in a job and answers its run id at once; <code>GET /analytics/mdx/background/:id</code> answers the run as its owner
/// reads it; <code>POST /analytics/mdx/background/:id/cancel</code> asks it to stop. Each answers this screen only (AD-36, AD-39's
/// sixth exception). The routes, the run row, the job and the owner-scoped 404 are
/// <class>OcuPilot.Kernel.Shell.BackgroundRun</class>'s, the SQL console's own machinery, with the run kind <code>mdx</code>; this class
/// is the MDX kind: its checks, its work and its codes. Every vendor call goes through <class>OcuPilot.Port.AnalyticsPort</class>.</p>
/// <p><b>The start's body</b> is <code>{statement, drill?, confirmed?}</code>: a string of 1 to
/// <parameter>OcuPilot.Port.AnalyticsPort.MDXMAXSTATEMENT</parameter> characters; <code>drill</code>, <code>{row, column}</code>, the
/// positive whole 1-based positions of one cell of the statement's answer within <parameter>OcuPilot.Port.AnalyticsPort.MDXMAXROWS</parameter>
/// and <parameter>OcuPilot.Port.AnalyticsPort.MDXMAXCOLUMNS</parameter>; and <code>confirmed</code>, absent or <code>true</code>. Any other
/// key or shape is 400 <code>ANALYTICS.MDX.INPUT</code> before anything is prepared, and so, once it is prepared, is a drill of a
/// DRILLTHROUGH statement, whose answer has no cells.</p>
/// <p><b>The start's order</b> is: the screen gate; the body; <method>OcuPilot.Port.AnalyticsPort.MdxAdmit</method>; the detection of text
/// that runs server-side code or SQL (<method>OcuPilot.Port.AnalyticsPort.MdxConstructs</method>); the prepare
/// (<method>OcuPilot.Port.AnalyticsPort.MdxPrepare</method>), whose refusals and error answer are rendered; and the detection again on the
/// variable-resolved text. A finding without <code>confirmed</code> is answered 200 <code>{outcome: confirm, constructs, consequence}</code>,
/// and nothing is reserved or spawned for it, for a refusal or for an error answer. The confirmation is the person's own step on their own
/// query (AD-65), carried in the same body as the text it confirms.</p>
/// <p><b>The job</b> repeats the gate, both detections and the prepare in its own process (<method>Work</method>): a finding the flag does
/// not confirm ends the run <code>failed</code> with <code>ANALYTICS.MDX.LOST</code>, executing nothing. The run itself is
/// <method>OcuPilot.Port.AnalyticsPort.MdxRun</method>, the loop the agent's MDX read shares: under an alarm of the time that remains
/// (<method>BoundSeconds</method>), because the vendor resolves the statement's members, and runs any SQL they name, in the start itself;
/// it polls the vendor's agents and this class's <method>MdxStopRequested</method>, its owner's cancel, and at either, or at the time
/// bound, cancels the vendor's query and waits for the vendor to report it finished. A drill-through runs the statement, then the cell's
/// listing, and a typed DRILLTHROUGH runs its listing, each read under an alarm of the time that remains. The run ends <code>canceled</code>
/// on its owner's cancel and <code>stopped</code> at the bound. The statement is handed to the job as one <code>JOB</code> argument and is
/// stored nowhere.</p>
/// <p>Seams a fixture subclass overrides: <method>BoundSeconds</method>, <method>Variables</method>, <method>MaxRunning</method>,
/// <method>LimitsClass</method>, <method>PortClass</method> and <method>Spawn</method>. Production overrides none.</p>
Class OcuPilot.Area.Analytics.MdxQuery Extends OcuPilot.Kernel.Shell.BackgroundRun
{

/// <p>The screen the three routes and the job answer for.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsMdxQuery";

/// <p>The kind this class's runs carry in the store.</p>
Parameter RUNKIND = "mdx";

/// <p>The subsystem the job's failures are logged under.</p>
Parameter LOGSUBSYSTEM = "mdxbackground";

/// <p>The answer to a start whose text needs the person's confirmation first.</p>
Parameter OUTCOMECONFIRM = "confirm";

/// <p>The port the job runs its statement through.</p>
ClassMethod PortClass() As %String
{
    Quit "OcuPilot.Port.AnalyticsPort"
}

/// <p>The seconds a run is bounded to. A fixture subclass overrides it; production never does.</p>
ClassMethod BoundSeconds() As %Numeric
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).#MDXSECONDS
}

/// <p>The pivot variables <method>OcuPilot.Port.AnalyticsPort.MdxPrepare</method> resolves <code>$variable.&lt;name&gt;</code> from, as an
/// array subscripted by name. Production hands none, so each resolves to an empty text. A fixture subclass overrides it; production never
/// does.</p>
ClassMethod Variables(Output pVariables)
{
    Kill pVariables
}

/// <p>The start's checks (see the class); a refusal, an error answer or a confirmation is rendered here and <var>pDone</var> is 1. Otherwise
/// the request list is <code>$ListBuild(statement, row, column, confirmed)</code>, <var>row</var> and <var>column</var> empty when no
/// drill is asked and <var>confirmed</var> 0 or 1.</p>
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
        If $$$ISERR(tReadSC) || '$IsObject(tBody) || 'tBody.%IsA("%Library.DynamicObject") || '..Body(tBody, .tStatement, .tRow, .tColumn, .tConfirmed) {
            Set tSC = ..RenderInput()
            Quit
        }
        Set tNamespace = ##class(OcuPilot.Kernel.Scope).Current()
        Set tCheckSC = ..Check(tNamespace, tStatement, tConfirmed, .tAnswer, .tHttp, .tFault, .tRS)
        Set tListing = ($ClassMethod(..PortClass(), "MdxKind", $Get(tRS)) = "DRILLTHROUGH")
        Do $ClassMethod(..PortClass(), "MdxRelease", tNamespace, .tRS)
        If $$$ISERR(tCheckSC) {
            Set tSC = ..RenderPortFault(tCheckSC, $Get(tHttp), $Get(tFault))
            Quit
        }
        If $IsObject($Get(tAnswer)) {
            Set tSC = ..Reply(200, tAnswer)
            Quit
        }
        If tListing && (tRow '= "") {
            Set tSC = ..RenderInput()
            Quit
        }
        Set pNamespace = tNamespace
        Set pRequest = $ListBuild(tStatement, tRow, tColumn, tConfirmed)
        Set pDone = 0
    } Catch ex {
        Set pDone = 1
        Set tSC = ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus($$$ERROR($$$GeneralError, "the MDX run's start failed: " _ ex.Name)))
    }
    Quit tSC
}

/// <p>The checks both the start and the job make on <var>pStatement</var> in <var>pNamespace</var>, in order, executing nothing: the port's
/// gate (<method>OcuPilot.Port.AnalyticsPort.MdxAdmit</method>); the detection of text that runs server-side code or SQL on the statement
/// (<method>OcuPilot.Port.AnalyticsPort.MdxConstructs</method>); the prepare, with <method>Variables</method>
/// (<method>OcuPilot.Port.AnalyticsPort.MdxPrepare</method>); and the detection again on the variable-resolved text. A refusal is an error
/// status with <var>pHttp</var> and <var>pFault</var>. Otherwise <var>pAnswer</var> is an answer that needs no run: the
/// <code>confirm</code> answer when a finding is not covered by <var>pConfirmed</var>, or the vendor's <code>error</code> answer; and
/// when it is <code>""</code>, <var>pRS</var> is the prepared result set, which the caller releases
/// (<method>OcuPilot.Port.AnalyticsPort.MdxRelease</method>). A statement with a finding that <var>pConfirmed</var> covers proceeds as one
/// without.</p>
ClassMethod Check(pNamespace As %String, pStatement As %String, pConfirmed As %Boolean, Output pAnswer As %DynamicObject, Output pHttp As %Integer, Output pFault As %DynamicObject, Output pRS) As %Status
{
    Set pAnswer = ""
    Set pHttp = 0
    Set pFault = ""
    Set pRS = ""
    Set tPort = ..PortClass()
    Set tSC = $ClassMethod(tPort, "MdxAdmit", pNamespace, .pHttp, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If $ClassMethod(tPort, "MdxConstructs", pStatement, .tFound, .tUnread) && 'pConfirmed {
        Set pAnswer = ..ConfirmAnswer($Get(tFound))
        Quit $$$OK
    }
    Do ..Variables(.tVariables)
    Set tSC = $ClassMethod(tPort, "MdxPrepare", pNamespace, pStatement, .pRS, .pAnswer, .pHttp, .pFault, .tAsk, .tFoundResolved, .tVariables)
    If $$$ISERR(tSC) Quit tSC
    If $IsObject($Get(pAnswer)) Quit $$$OK
    Set pAnswer = ""
    If tAsk && 'pConfirmed {
        Do $ClassMethod(tPort, "MdxRelease", pNamespace, .pRS)
        Set pAnswer = ..ConfirmAnswer($Get(tFoundResolved))
    }
    Quit $$$OK
}

/// <p>Read <var>pBody</var> into the statement, the drill's cell and the confirmation, answering 0 for any key but the three, a value of
/// the wrong shape, a statement that is blank or too long, a drill that is not two positive whole positions within the caps, or a
/// <code>confirmed</code> that is not <code>true</code>.</p>
ClassMethod Body(pBody As %DynamicObject, Output pStatement As %String, Output pRow As %String, Output pColumn As %String, Output pConfirmed As %Boolean) As %Boolean [ Private ]
{
    Set pStatement = ""
    Set pRow = ""
    Set pColumn = ""
    Set pConfirmed = 0
    Set tPort = "OcuPilot.Port.AnalyticsPort"
    Set tStray = 0
    Set tIterator = pBody.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        If '$ListFind($ListBuild("statement", "drill", "confirmed"), tKey) Set tStray = 1
    }
    If tStray Quit 0
    If pBody.%GetTypeOf("statement") '= "string" Quit 0
    Set pStatement = pBody.%Get("statement")
    If $ClassMethod(tPort, "MdxBlank", pStatement) || ($Length(pStatement) > $Parameter(tPort, "MDXMAXSTATEMENT")) Quit 0
    Set tType = pBody.%GetTypeOf("drill")
    If tType = "object" {
        Set tDrill = pBody.%Get("drill")
        Set tKeys = 0
        Set tDrillIterator = tDrill.%GetIterator()
        While tDrillIterator.%GetNext(.tDrillKey, .tDrillValue) {
            Set tKeys = tKeys + 1
            If '$ListFind($ListBuild("row", "column"), tDrillKey) Set tStray = 1
        }
        If tStray || (tKeys '= 2) Quit 0
        If '..Position(tDrill, "row", $Parameter(tPort, "MDXMAXROWS"), .pRow) Quit 0
        If '..Position(tDrill, "column", $Parameter(tPort, "MDXMAXCOLUMNS"), .pColumn) Quit 0
    } ElseIf tType '= "unassigned" {
        Quit 0
    }
    Set tType = pBody.%GetTypeOf("confirmed")
    If tType = "boolean" {
        If 'pBody.%Get("confirmed") Quit 0
        Set pConfirmed = 1
    } ElseIf tType '= "unassigned" {
        Quit 0
    }
    Quit 1
}

/// <p>Whether <var>pObject</var>'s <var>pKey</var> is a positive whole number of at most <var>pMax</var>; <var>pValue</var> is that
/// number.</p>
ClassMethod Position(pObject As %DynamicObject, pKey As %String, pMax As %Integer, Output pValue As %Integer) As %Boolean [ Private ]
{
    Set pValue = ""
    If pObject.%GetTypeOf(pKey) '= "number" Quit 0
    Set tValue = pObject.%Get(pKey)
    If (tValue < 1) || (tValue > pMax) || (tValue '= (tValue \ 1)) Quit 0
    Set pValue = tValue
    Quit 1
}

/// <p>The <code>{outcome: confirm, constructs, consequence}</code> answer: the names <var>pFound</var> lists (empty for a statement the
/// detector cannot read) and the consequence in plain words. Nothing is reserved, prepared or spawned for it.</p>
ClassMethod ConfirmAnswer(pFound As %List) As %DynamicObject [ Private ]
{
    Set tConstructs = []
    For tI = 1:1:$ListLength(pFound) {
        Do tConstructs.%Push($List(pFound, tI), "string")
    }
    Set tAnswer = {}
    Do tAnswer.%Set("outcome", ..#OUTCOMECONFIRM, "string")
    Do tAnswer.%Set("constructs", tConstructs)
    Do tAnswer.%Set("consequence", ##class(OcuPilot.Port.AnalyticsPort).#MDXCONSEQUENCE, "string")
    Quit tAnswer
}

/// <p>Render the port's refusal <var>pFault</var> with the status <var>pHttp</var>, or the generic internal envelope when the port gave
/// none.</p>
ClassMethod RenderPortFault(pSC As %Status, pHttp As %Integer, pFault) As %Status [ Private ]
{
    If '$IsObject(pFault) || (pFault.%Get("code") = "") {
        Quit ##class(OcuPilot.Api.Error).RenderInternal("An internal error occurred", ##class(%Exception.StatusException).CreateFromStatus(pSC))
    }
    Quit ..Render(pFault, $Select(+pHttp: +pHttp, 1: 500))
}

/// <p>The 400 <code>ANALYTICS.MDX.INPUT</code> envelope.</p>
ClassMethod RenderInput() As %Status [ Private ]
{
    Quit ##class(OcuPilot.Api.Error).Render(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.AnalyticsError).#REASONMDXINPUT, ##class(OcuPilot.Api.AnalyticsError).#MDXINPUT)
}

/// <p>The job's work, after the shared checks (see the class): the gate again, both detections and the prepare, then the run, then the
/// answer, ending the run <code>ended</code> with its answer, <code>canceled</code> when its owner asked, or <code>failed</code> with a
/// refusal. The statement is never logged.</p>
ClassMethod Work(pKey As %String, pUser As %String, pNamespace As %String, pRequest As %List, pClass As %String)
{
    Set tRS = ""
    Try {
        Do ..Process(pKey, pNamespace, pRequest, .tRS)
    } Catch ex {
        Do ..Release(pNamespace, .tRS)
        Throw ex
    }
    Do ..Release(pNamespace, .tRS)
}

/// <p>Release the run's result set in <var>pNamespace</var>, where the vendor's destructor clears its local cache
/// (<method>OcuPilot.Port.AnalyticsPort.MdxRelease</method>).</p>
ClassMethod Release(pNamespace As %String, ByRef pRS) [ Private ]
{
    Do $ClassMethod(..PortClass(), "MdxRelease", pNamespace, .pRS)
}

/// <p>The work of <method>Work</method>, holding the statement's result set in <var>pRS</var> so that <method>Work</method> releases it on
/// every path.</p>
ClassMethod Process(pKey As %String, pNamespace As %String, pRequest As %List, ByRef pRS) [ Private ]
{
    Set tPort = ..PortClass()
    Set tStatement = $ListGet(pRequest, 1)
    Set tRow = $ListGet(pRequest, 2)
    Set tColumn = $ListGet(pRequest, 3)
    Set tConfirmed = +$ListGet(pRequest, 4)
    Set tEnded = $Parameter(..#STORECLASS, "STATEENDED")
    Set tSC = ..Check(pNamespace, tStatement, tConfirmed, .tAnswer, .tHttp, .tFault, .pRS)
    If $$$ISERR(tSC) {
        Do ..FinishRefused(pKey, tSC, $Get(tFault))
        Quit
    }
    If $IsObject($Get(tAnswer)) {
        If tAnswer.%Get("outcome") = ..#OUTCOMECONFIRM {
            Do ..FinishUnconfirmed(pKey)
        } Else {
            Do ..Finish(pKey, tEnded, tAnswer.%ToJSON())
        }
        Quit
    }
    Set tSC = $ClassMethod(tPort, "MdxRun", pNamespace, pRS, tRow, tColumn, ..BoundSeconds(), $ClassName(), pKey, .tResult, .tStopped, .tHttp, .tFault)
    If $$$ISERR(tSC) {
        Do ..FinishRefused(pKey, tSC, $Get(tFault))
        Quit
    }
    If tStopped = "request" {
        Do ..Finish(pKey, tEnded, "")
        Quit
    }
    Do ..Finish(pKey, tEnded, tResult.%ToJSON())
}

/// <p>Whether run <var>pKey</var>'s owner has asked it to stop, read fresh from the store; 0 when the store cannot answer. It is the stop
/// hook <method>OcuPilot.Port.AnalyticsPort.MdxRun</method> asks.</p>
ClassMethod MdxStopRequested(pKey As %String) As %Boolean
{
    Set tRequested = 0
    Set tSC = $ClassMethod(..#STORECLASS, "GuardedCancelRequested", pKey, .tRequested)
    Quit $$$ISOK(tSC) && tRequested
}

/// <p>End run <var>pKey</var> <code>failed</code> with <code>ANALYTICS.MDX.LOST</code>'s envelope: the statement, or its
/// variable-resolved text, holds a finding the start's <code>confirmed</code> did not cover, and nothing was executed.</p>
ClassMethod FinishUnconfirmed(pKey As %String) [ Private ]
{
    Do ..Finish(pKey, $Parameter(..#STORECLASS, "STATEFAILED"), ..Envelope(..Lost(.tHttp)).%ToJSON())
}

/// <p>What a cancel sends to the job: one <code>$SYSTEM.SQL.CancelQuery</code>, which reaches a statement the job runs, a listing's or the
/// SQL a start runs for a member. A job that runs no statement answers an error status at once, which is not a failure: the job reads its
/// owner's flag while it polls the vendor's agents and before each start and each listing's read, so it acts on the cancel at its next
/// step. A cancel that arrives while the vendor computes a DRILLTHROUGH's MDX portion is acted on when that wait ends, or at the
/// bound.</p>
ClassMethod CancelJob(pId As %String, pUser As %String, pJobId As %String, pLive As %Boolean) As %Status
{
    If pLive && (pJobId '= "") Do $SYSTEM.SQL.CancelQuery(pJobId, , 0)
    Quit $$$OK
}

/// <p>The code of the shared refusal <var>pName</var>: the four <code>ANALYTICS.MDX.*</code> run codes.</p>
ClassMethod CodeFor(pName As %String) As %String
{
    Quit $Case(pName, "busy": ##class(OcuPilot.Api.AnalyticsError).#MDXBUSY, "full": ##class(OcuPilot.Api.AnalyticsError).#MDXFULL, "notfound": ##class(OcuPilot.Api.AnalyticsError).#MDXNOTFOUND, "lost": ##class(OcuPilot.Api.AnalyticsError).#MDXLOST, : "")
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

}
