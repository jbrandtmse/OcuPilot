/// <p>The Background tasks port (AD-27's Story 16.5 case, AD-29, AD-52): one list over the admin
/// API's async tasks the caller queued and the classic portal's background jobs, and the cancel,
/// pause and resume of one of them. It is <class>OcuPilot.Port.AdminPort</class> with one
/// pseudo-endpoint, <parameter>ENDPOINT</parameter>, carried out here; every other call is the
/// admin port's own.</p>
/// <p><b>Why a port.</b> The admin API reaches only the caller's own async tasks
/// (<code>AsyncResult</code> answers another user's with 404) and nothing of the portal's job log,
/// so the portal half is read through the classic page's own query,
/// <parameter>PORTALQUERY</parameter>, and a portal row is controlled through the documented
/// <parameter>PORTALTASKCLASS</parameter> <code>Cancel()</code>, <code>Pause()</code> and
/// <code>Resume()</code>, both in <code>%SYS</code> (AD-16): outside it the query reports stored
/// states and blank background task ids.</p>
/// <p><b>Its own gate comes first</b> (AD-29): <parameter>PAIRS</parameter>, checked in order in
/// the calling process before any read or vendor call. A caller missing one is refused 403
/// <code>PORT.ACCESSDENIED</code> with <code>detail.failedPair</code> naming it; the vendor's own
/// control check would otherwise raise <code>&lt;UNDEFINED&gt;</code>.</p>
/// <p><b>A row's id is composite</b> (AD-13): <parameter>SOURCEPORTAL</parameter> or
/// <parameter>SOURCEADMIN</parameter>, then the job number or the async task's GUID, joined by
/// <method>OcuPilot.Kernel.EntityId.JoinComposite</method>. The GUID is compared as a string, since
/// its leading zeros are significant.</p>
/// <p><b>One refusal is published</b>: <code>TASK.BACKGROUND.STATE</code>, 409, for the vendor's own
/// state refusal (the admin API's 409, <parameter>PORTALTASKCLASS</parameter>'s error
/// <parameter>PORTALSTATECODE</parameter>) and, before any vendor call, for a portal row with no
/// background task to act on.</p>
/// <p>Seams a test subclass overrides (<class>OcuPilot.Test.BackgroundTaskFixture</class>):
/// <method>PortalRows</method>, <method>AdminRows</method>, <method>PortalControl</method> and
/// <method>AdminControl</method>, with the admin port's own <method>HoldsPair</method>. Production
/// overrides none of them.</p>
Class OcuPilot.Port.BackgroundTaskPort Extends OcuPilot.Port.AdminPort
{

/// <p>The pseudo-endpoint this port carries out itself.</p>
Parameter ENDPOINT = "BackgroundTask";

/// <p>The read type: every row, or, with <parameter>IDPARAM</parameter>, the one row it names.</p>
Parameter LISTTYPE = "LIST";

/// <p>The control types, each paired with the <parameter>PORTALTASKCLASS</parameter> method a
/// portal row's is carried out by.</p>
Parameter CONTROLTYPES = "CANCEL=Cancel,PAUSE=Pause,RESUME=Resume";

/// <p>The query parameter a row's composite id travels under.</p>
Parameter IDPARAM = "id";

/// <p>The query parameter a list's row cap travels under.</p>
Parameter MAXROWSPARAM = "maxRows";

/// <p>The row cap a list that names none is read under, and the one the fresh read of an admin
/// row lists the caller's tasks under.</p>
Parameter DEFAULTMAXROWS As INTEGER = 1000;

/// <p>The <code>Source</code> a portal row carries.</p>
Parameter SOURCEPORTAL = "Management Portal";

/// <p>The <code>Source</code> an admin API row carries.</p>
Parameter SOURCEADMIN = "Admin API";

/// <p>The port's own pair set, checked in this order before any read or vendor call (AD-29).</p>
Parameter PAIRS = "%Admin_Operate:USE,%DB_IRISSYS:READ";

/// <p>The classic Background tasks page's own query, read in <code>%SYS</code>.</p>
Parameter PORTALQUERY = "%CSP.UI.System.BackgroundTask:EnumerateTasks";

/// <p>The documented class a portal job's background task is controlled through.</p>
Parameter PORTALTASKCLASS = "%SYS.BackgroundTask";

/// <p>The vendor error <parameter>PORTALTASKCLASS</parameter> answers for a request the task's
/// current state does not allow (<code>BGTaskRequestNotAllowedState</code>).</p>
Parameter PORTALSTATECODE As INTEGER = 9503;

/// <p>The admin port's own write types this port issues for its control types (Story 12.6's
/// grammar): an admin API row is controlled through <code>AsyncResult</code>.</p>
Parameter DELEGATEDTYPES = "AsyncResult/CANCEL,AsyncResult/PAUSE,AsyncResult/RESUME";

/// <p>The admin port's call, except for <parameter>ENDPOINT</parameter>: a
/// <parameter>LISTTYPE</parameter> answers the merged rows, newest start first and at most
/// <parameter>MAXROWSPARAM</parameter> of them, each <code>{Source, Id, Task, Namespace, Status,
/// Details, ErrorCount, StartTime}</code>, or, where the query carries <parameter>IDPARAM</parameter>,
/// the one row whose source and id equal its parts exactly as an object, and 404
/// <code>PORT.NOTFOUND</code> when none does; a <parameter>CONTROLTYPES</parameter> type acts on the
/// row <parameter>IDPARAM</parameter> names and answers <code>{}</code> at 200.</p>
/// <p><b>Caller contract:</b> the arguments and outputs are
/// <method>OcuPilot.Port.AdminPort.Invoke</method>'s. <parameter>ENDPOINT</parameter> takes no body;
/// any other type is 501 <code>PORT.NOTIMPLEMENTED</code>. Must not be called from an escalated
/// frame (AD-9); the caller's namespace is unchanged on return (AD-16).</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    If pEndpoint '= ..#ENDPOINT Quit ##super(pEndpoint, pType, .pQuery, pBody, .pResult, .pHttpStatus, .pFault)
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Try {
        If '..Gate(.tFailedPair) {
            Set tSC = ..GateRefusal(tFailedPair, .pHttpStatus, .pFault)
            Quit
        }
        If $IsObject(pBody) || (pBody '= "") {
            Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
            Do ..LogFault(pEndpoint _ " " _ pType _ " was given a caller body, and it takes none", $$$ERROR($$$GeneralError, "a background task call takes no body"), pFault.code)
            Quit
        }
        If pType = ..#LISTTYPE {
            Set tKey = $Get(pQuery(..#IDPARAM))
            If tKey '= "" {
                Set tSC = ..Row(tKey, .pResult, .pHttpStatus, .pFault)
                Quit
            }
            Set tSC = ..Rows($Get(pQuery(..#MAXROWSPARAM)), .pResult, .pHttpStatus, .pFault)
            Quit
        }
        If ..ControlMethod(pType) = "" {
            Set tSC = ..Refuse(501, ##class(OcuPilot.Api.Error).#NOTIMPLEMENTED, ##class(OcuPilot.Api.Error).#PORTNOTIMPLEMENTED, "This instance does not implement that operation", .pHttpStatus, .pFault)
            Quit
        }
        Set tSC = ..Control(pType, $Get(pQuery(..#IDPARAM)), .pResult, .pHttpStatus, .pFault)
    } Catch ex {
        Set pResult = ""
        Set tSC = ..Fail(pEndpoint, 500, ex.AsStatus(), .pHttpStatus, .pFault)
    }
    Quit tSC
}

/// <p>Whether the calling process holds every pair in <parameter>PAIRS</parameter>, checked in
/// order through <method>OcuPilot.Port.AdminPort.HoldsPair</method>. <var>pFailedPair</var> names
/// the first it lacks, or is <code>""</code>.</p>
ClassMethod Gate(Output pFailedPair As %String) As %Boolean
{
    Set pFailedPair = ""
    Set tPairs = $ListFromString(..#PAIRS)
    For tI = 1:1:$ListLength(tPairs) {
        If ..HoldsPair($List(tPairs, tI)) Continue
        Set pFailedPair = $List(tPairs, tI)
        Quit
    }
    Quit (pFailedPair = "")
}

/// <p>The <parameter>PORTALTASKCLASS</parameter> method a control type <var>pType</var> is carried
/// out by, or <code>""</code> for a type that is not one.</p>
ClassMethod ControlMethod(pType As %String) As %String
{
    Set tMethod = ""
    For tI = 1:1:$Length(..#CONTROLTYPES, ",") {
        Set tEntry = $Piece(..#CONTROLTYPES, ",", tI)
        If $Piece(tEntry, "=", 1) = pType Set tMethod = $Piece(tEntry, "=", 2)
    }
    Quit tMethod
}

/// <p>The merged rows, at most <var>pMax</var> of them (<parameter>DEFAULTMAXROWS</parameter> when
/// it is empty), newest start first, in <var>pRows</var> at 200. The admin half is asked for at
/// most <var>pMax</var> rows, so a cut in either half still leaves <var>pMax</var> rows for the
/// caller's truncation signal.</p>
ClassMethod Rows(pMax As %String, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRows = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tMax = $Select(pMax = "": ..#DEFAULTMAXROWS, 1: pMax)
    If '$Match(tMax, "^[1-9][0-9]*$") Quit ..Fail(..#ENDPOINT, 500, $$$ERROR($$$GeneralError, "the list was asked for '" _ pMax _ "' rows"), .pHttpStatus, .pFault)
    Set tSC = ..AdminRows(tMax, .tAdmin, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set tSC = ..PortalRows(.tPortal)
    If $$$ISERR(tSC) Quit ..Fail(..#ENDPOINT, 500, tSC, .pHttpStatus, .pFault)
    ; Keyed by start time, then by arrival, so two rows started in the same second both survive;
    ; the leading space gives a row not yet started a subscript that sorts below every time.
    Kill tSorted
    Set tN = 0
    For tHalf = tPortal, tAdmin {
        Set tIterator = tHalf.%GetIterator()
        While tIterator.%GetNext(.tIndex, .tRow) {
            Set tN = tN + 1
            Set tSorted(" " _ tRow.%Get("StartTime"), tN) = tRow
        }
    }
    Set pRows = []
    Set tTime = ""
    For {
        Set tTime = $Order(tSorted(tTime), -1)
        If (tTime = "") || (pRows.%Size() >= tMax) Quit
        Set tAt = ""
        For {
            Set tAt = $Order(tSorted(tTime, tAt), -1, tRow)
            If (tAt = "") || (pRows.%Size() >= tMax) Quit
            Do pRows.%Push(..Listed(tRow))
        }
    }
    Kill tSorted
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The one row whose source and id equal the parts of the composite id <var>pKey</var> exactly,
/// in <var>pRow</var> at 200, or 404 <code>PORT.NOTFOUND</code>.</p>
ClassMethod Row(pKey As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pHttpStatus = 0
    Set pFault = ""
    Set tSC = ..Find(pKey, .pRow, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(pRow) Quit ..Fail(..#ENDPOINT, 404, $$$OK, .pHttpStatus, .pFault)
    Set pRow = ..Listed(pRow)
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The row the composite id <var>pKey</var> names, with its background task id for a portal
/// row, in <var>pRow</var>, or <code>""</code> when the id is malformed or no row carries it. An
/// error status is a half that could not be read.</p>
ClassMethod Find(pKey As %String, Output pRow As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pRow = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pKey)
    If $ListLength(tParts) '= 2 Quit $$$OK
    Set tSource = $ListGet(tParts, 1)
    Set tId = $ListGet(tParts, 2)
    If tId = "" Quit $$$OK
    If tSource = ..#SOURCEPORTAL {
        Set tSC = ..PortalRows(.tRows)
        If $$$ISERR(tSC) Quit ..Fail(..#ENDPOINT, 500, tSC, .pHttpStatus, .pFault)
    } ElseIf tSource = ..#SOURCEADMIN {
        Set tSC = ..AdminRows(..#DEFAULTMAXROWS, .tRows, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) Quit tSC
    } Else {
        Quit $$$OK
    }
    Set tIterator = tRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If tRow.%Get("Id") '= tId Continue
        Set pRow = tRow
        Quit
    }
    Quit $$$OK
}

/// <p><var>pRow</var> as a list answers it: the declared members alone, without a portal row's
/// background task id.</p>
ClassMethod Listed(pRow As %DynamicObject) As %DynamicObject [ Private ]
{
    Set tOut = {}
    For tField = "Source", "Id", "Task", "Namespace", "Status", "Details", "ErrorCount", "StartTime" {
        Do tOut.%Set(tField, pRow.%Get(tField) _ "", "string")
    }
    Quit tOut
}

/// <p>Carry out control type <var>pType</var> on the row the composite id <var>pKey</var> names: an
/// admin API row through <code>AsyncResult</code> (<method>AdminControl</method>), a portal row
/// through its background task (<method>PortalControl</method>), read fresh here. A malformed id,
/// and a row the instance no longer lists, are 404 <code>PORT.NOTFOUND</code>; a portal row with no
/// background task, and the vendor's own state refusal, are 409
/// <code>TASK.BACKGROUND.STATE</code>.</p>
ClassMethod Control(pType As %String, pKey As %String, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pKey)
    Set tSource = $ListGet(tParts, 1)
    Set tId = $ListGet(tParts, 2)
    If ($ListLength(tParts) '= 2) || (tId = "") || ((tSource '= ..#SOURCEPORTAL) && (tSource '= ..#SOURCEADMIN)) Quit ..Fail(..#ENDPOINT, 404, $$$OK, .pHttpStatus, .pFault)
    If tSource = ..#SOURCEADMIN {
        Set tSC = ..AdminControl(pType, tId, .pResult, .pHttpStatus, .pFault)
        If $$$ISERR(tSC) && (+pHttpStatus = 409) Quit ..StateRefusal(.pHttpStatus, .pFault)
        Quit tSC
    }
    If '$Match(tId, "^[1-9][0-9]{0,18}$") Quit ..Fail(..#ENDPOINT, 404, $$$OK, .pHttpStatus, .pFault)
    Set tSC = ..Find(pKey, .tRow, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject(tRow) Quit ..Fail(..#ENDPOINT, 404, $$$OK, .pHttpStatus, .pFault)
    Set tTaskId = tRow.%Get("SysBGTaskId")
    If tTaskId = "" Quit ..StateRefusal(.pHttpStatus, .pFault)
    Set tSC = ..PortalControl(tTaskId, pType, .tAbsent, .tVendorSC)
    If $$$ISERR(tSC) Quit ..Fail(..#ENDPOINT, 500, tSC, .pHttpStatus, .pFault)
    If tAbsent Quit ..StateRefusal(.pHttpStatus, .pFault)
    If $$$ISERR(tVendorSC) {
        If ("," _ $System.Status.GetErrorCodes(tVendorSC) _ ",") [ ("," _ ..#PORTALSTATECODE _ ",") Quit ..StateRefusal(.pHttpStatus, .pFault)
        Quit ..Fail(..#ENDPOINT, 500, tVendorSC, .pHttpStatus, .pFault)
    }
    Set pResult = {}
    Set pHttpStatus = 200
    Quit $$$OK
}

/// <p>The 409 <code>TASK.BACKGROUND.STATE</code> on its published sentence.</p>
ClassMethod StateRefusal(Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.Error).#TASKBACKGROUNDSTATE, ##class(OcuPilot.Api.Error).#REASONTASKBACKGROUNDSTATE, .pHttpStatus, .pFault)
}

/// <p>The 403 the gate answers: the admin port's own mapping of 403, with the pair in
/// <code>detail.failedPair</code> (AD-8, AD-39).</p>
ClassMethod GateRefusal(pFailedPair As %String, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tDetail = {}
    Do tDetail.%Set("failedPair", pFailedPair, "string")
    Do ##class(OcuPilot.Kernel.Fault).Outcome(403, $$$OK, .tMapped, .tVendorText)
    Quit ..Refuse(403, tMapped.error, tMapped.code, tMapped.reason, .pHttpStatus, .pFault, tDetail)
}

/// <p>The portal half: one row per job <parameter>PORTALQUERY</parameter> lists, newest first, each
/// <code>{Source, Id, Task, Namespace, Status, Details, ErrorCount, StartTime, SysBGTaskId}</code>,
/// read in <code>%SYS</code> (AD-16). The query overlays a job's background task state on its
/// stored status and blanks the id of a task it cannot open.</p>
ClassMethod PortalRows(Output pRows As %DynamicArray) As %Status
{
    Set tSC = $$$OK
    Set pRows = []
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tRS = ##class(%ResultSet).%New(..#PORTALQUERY)
        If '$IsObject(tRS) {
            Set $NAMESPACE = tOrigNS
            Set tSC = $$$ERROR($$$GeneralError, "the background task list could not be opened")
            Quit
        }
        Set tSC = tRS.Execute()
        If $$$ISOK(tSC) {
            While tRS.Next(.tSC) {
                Set tRow = {}
                Do tRow.%Set("Source", ..#SOURCEPORTAL, "string")
                Do tRow.%Set("Id", tRS.Get("ID") _ "", "string")
                Do tRow.%Set("Task", tRS.Get("Task") _ "", "string")
                Do tRow.%Set("Namespace", tRS.Get("Namespace") _ "", "string")
                Do tRow.%Set("Status", tRS.Get("Status") _ "", "string")
                Do tRow.%Set("Details", tRS.Get("Details") _ "", "string")
                Do tRow.%Set("ErrorCount", tRS.Get("ErrorCount") _ "", "string")
                Do tRow.%Set("StartTime", tRS.Get("StartTime") _ "", "string")
                Do tRow.%Set("SysBGTaskId", tRS.Get("SysBGTaskId") _ "", "string")
                Do pRows.%Push(tRow)
            }
        }
        Do tRS.Close()
        Set tRS = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pRows = []
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The admin half: the caller's own async tasks, as the <code>AsyncResult</code>
/// <code>LIST</code> answers them (newest queued first, at most <var>pMax</var>), each mapped to
/// <code>{Source, Id, Task, Namespace, Status, Details, ErrorCount, StartTime}</code>. The vendor
/// answers no namespace or error count, so both are empty. A failed list passes its fault
/// through.</p>
ClassMethod AdminRows(pMax As %Integer, Output pRows As %DynamicArray, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Set pRows = []
    Kill tQuery
    Set tQuery(..#MAXROWSPARAM) = pMax
    Set tSC = ..Invoke(..#ASYNCRESULTENDPOINT, ..#LISTTYPE, .tQuery, "", .tAnswer, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject($Get(tAnswer)) || 'tAnswer.%IsA("%Library.DynamicArray") Quit ..Fail(..#ENDPOINT, 500, $$$ERROR($$$GeneralError, "the async task list answered something other than a list"), .pHttpStatus, .pFault)
    Set tIterator = tAnswer.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tTask) {
        If '$IsObject(tTask) Continue
        Set tRow = {}
        Do tRow.%Set("Source", ..#SOURCEADMIN, "string")
        Do tRow.%Set("Id", tTask.%Get("GUID") _ "", "string")
        Do tRow.%Set("Task", tTask.%Get("TaskName") _ "", "string")
        Do tRow.%Set("Namespace", "", "string")
        Do tRow.%Set("Status", tTask.%Get("State") _ "", "string")
        Do tRow.%Set("Details", tTask.%Get("FailureReason") _ "", "string")
        Do tRow.%Set("ErrorCount", "", "string")
        Do tRow.%Set("StartTime", tTask.%Get("TimeStarted") _ "", "string")
        Do pRows.%Push(tRow)
    }
    Quit $$$OK
}

/// <p>Control type <var>pType</var> on the caller's async task <var>pGuid</var>, through
/// <code>AsyncResult</code>: its own answer, its HTTP status and its fault.</p>
ClassMethod AdminControl(pType As %String, pGuid As %String, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Kill tQuery
    Set tQuery(..#IDPARAM) = pGuid
    Quit ..Invoke(..#ASYNCRESULTENDPOINT, pType, .tQuery, "", .pResult, .pHttpStatus, .pFault)
}

/// <p>Control type <var>pType</var> on the portal's background task <var>pTaskId</var>, through
/// <parameter>PORTALTASKCLASS</parameter> in <code>%SYS</code> (AD-16). <var>pAbsent</var> is 1
/// when no such task opens, and nothing is asked of it; <var>pVendorSC</var> is the vendor method's
/// own status. The returned status is an error only when the call could not be made. No reference
/// to the task survives the call.</p>
ClassMethod PortalControl(pTaskId As %String, pType As %String, Output pAbsent As %Boolean, Output pVendorSC As %Status) As %Status
{
    Set tSC = $$$OK
    Set pAbsent = 0
    Set pVendorSC = $$$OK
    Set tMethod = ..ControlMethod(pType)
    If tMethod = "" Quit $$$ERROR($$$GeneralError, "'" _ pType _ "' is not a control type")
    Set tOrigNS = $NAMESPACE
    Try {
        Set $NAMESPACE = "%SYS"
        Set tTask = $ClassMethod(..#PORTALTASKCLASS, "%OpenId", pTaskId)
        If '$IsObject(tTask) {
            Set pAbsent = 1
        } Else {
            Set pVendorSC = $Method(tTask, tMethod)
        }
        Set tTask = ""
        Set $NAMESPACE = tOrigNS
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set tTask = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The kind of script step <method>Snippet</method> renders: <code>objectscript</code> for a
/// <parameter>ENDPOINT</parameter> control type, whose admin API rows render as the admin port's
/// <code>rest</code> step; the admin port's answer otherwise.</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    If (pEndpoint = ..#ENDPOINT) && (..ControlMethod(pType) '= "") Quit "objectscript"
    Quit ##super(pEndpoint, pType)
}

/// <p><method>Invoke</method>'s branches as a script (AD-59): an admin API row is the admin port's
/// <code>AsyncResult</code> call for the same type and GUID; any other id is the
/// <parameter>PORTALTASKCLASS</parameter> call on the job's background task, read from the job log
/// the portal's query reads, and refused as the port refuses it when the job has none. Every other
/// call is the admin port's script.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    If (pEndpoint '= ..#ENDPOINT) || (..ControlMethod(pType) = "") Quit ##super(pEndpoint, pType, .pQuery, pBody, pContext)
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite($Get(pQuery(..#IDPARAM)))
    Set tId = $ListGet(tParts, $ListLength(tParts))
    If $ListGet(tParts, 1) = ..#SOURCEADMIN {
        Kill tQuery
        Set tQuery(..#IDPARAM) = tId
        Quit ##super(..#ASYNCRESULTENDPOINT, pType, .tQuery, "", pContext)
    }
    Set tSteps = []
    Set tLines = $ListBuild("Set tTaskId = $Get(^IRIS.Temp.MgtPortalTask(" _ ..Literal(tId) _ ", ""SysBGTaskId""))")
    Set tLines = tLines _ $ListBuild("Set tTask = $Select(tTaskId = """": """", 1: ##class(" _ ..#PORTALTASKCLASS _ ").%OpenId(tTaskId))")
    Set tLines = tLines _ $ListBuild("Set tSC = $Select($IsObject(tTask): tTask." _ ..ControlMethod(pType) _ "(), 1: $System.Status.Error(5001, " _ ..Literal(##class(OcuPilot.Api.Error).#REASONTASKBACKGROUNDSTATE) _ "))")
    Set tLines = tLines _ $ListBuild("Kill tTask", "Do $System.Status.DisplayError(tSC)")
    Do tSteps.%Push(..ObjectScriptStep(tLines))
    Quit tSteps
}

}
