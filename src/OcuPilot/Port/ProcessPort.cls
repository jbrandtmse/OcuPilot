/// <p>The process port (AD-52): <class>OcuPilot.Port.AdminPort</class> with one write carried out
/// through the documented <code>%SYS</code> class the vendor endpoint itself calls, and one write
/// and one read composed over the admin API. A <code>Process</code> <code>TERMINATE</code> whose
/// query carries <parameter>SENDERRORPARAM</parameter> <code>1</code> calls
/// <code>SYS.Process.Terminate(1)</code>; <parameter>RECIPIENTSTYPE</parameter> and
/// <parameter>BROADCASTTYPE</parameter> are answered here (below); every other call is the admin
/// port's own, with that parameter removed first.</p>
/// <p><b>Why a port.</b> Measured on this build: the vendor's <code>RunTerminate</code> calls
/// <code>Terminate()</code> and never passes its <code>SendError</code> argument, so the admin API
/// cannot express a terminate that logs a <code>&lt;RESJOB&gt;</code> error in the process's
/// namespace. This port repeats that endpoint's guard before the call, in its order: the
/// <code>ResourcesOR()</code> gate (<parameter>GATERESOURCE</parameter> at <code>USE</code>), its
/// not-found answer (404 for a pid no process carries) and its refusal of a process that cannot be
/// terminated (409). Faults are mapped exactly as the admin port maps the vendor's own.</p>
/// <p><b>Broadcast</b> (AD-51, Story 16.6). The vendor's <code>BROADCAST</code> answers
/// <code>{}</code> whatever happens: it drops an ended or ineligible pid silently and delivers a pid
/// named twice twice (measured). So the target is a pid set in its canonical spelling
/// (<method>PidSetProblem</method>), and before any vendor call the port refuses a caller body,
/// re-reads the set's recipients from the admin API's <code>LIST</code>, and refuses
/// <code>PROCESS.BROADCAST.RECIPIENT</code> unless every pid is present and reads
/// <code>CanReceiveBroadcast</code> true. Only then does it compose <code>{Message, PidList}</code>
/// (<method>BroadcastBody</method>), each pid once, and send it; never inside a transaction.
/// <parameter>RECIPIENTSTYPE</parameter> is that re-read as a read, the broadcast tool's fresh
/// read.</p>
/// <p><b>It names no administration API class</b> (AD-2, AD-27): <code>SYS.Process</code> is the
/// documented class, and every other request goes through
/// <method>OcuPilot.Port.AdminPort.Invoke</method>.</p>
Class OcuPilot.Port.ProcessPort Extends OcuPilot.Port.AdminPort
{

/// <p>The endpoint and request type this port carries out itself.</p>
Parameter PROCESSENDPOINT = "Process";

Parameter TERMINATETYPE = "TERMINATE";

/// <p>The query parameter a tool sets to <code>1</code> to ask for the error-to-job flag
/// (<method>OcuPilot.Screen.Tool.Write.PortQuery</method>). It never reaches the vendor.</p>
Parameter SENDERRORPARAM = "sendError";

/// <p>The query parameter the vendor endpoint identifies a process by.</p>
Parameter IDPARAM = "id";

/// <p>The vendor endpoint's own <code>ResourcesOR()</code> resource, checked at <code>USE</code>
/// as <code>Main()</code> checks it.</p>
Parameter GATERESOURCE = "%Admin_Operate";

/// <p>The vendor's broadcast request type, whose body this port composes.</p>
Parameter BROADCASTTYPE = "BROADCAST";

/// <p>The read type this port answers itself: a pid set's recipients,
/// <code>{Recipients: [{Pid, Username, CanReceiveBroadcast}], Absent: [pid], Message: ""}</code>.</p>
Parameter RECIPIENTSTYPE = "RECIPIENTS";

/// <p>The vendor's process list, which both are read from.</p>
Parameter LISTTYPE = "LIST";

/// <p>The most processes one broadcast reaches. A target key names every pid, and twenty
/// seven-digit pids fit the ledger's 256-character target.</p>
Parameter BROADCASTMAXPIDS = 20;

/// <p>The query key the broadcast's message travels under
/// (<method>OcuPilot.Screen.Tool.Write.PortQuery</method>). It never reaches the vendor as a query
/// parameter.</p>
Parameter MESSAGEQUERY = "Message";

/// <p>The entity type whose canonical spelling a pid set takes (AD-13).</p>
Parameter ENTITYTYPE = "process";

/// <p>The <parameter>OcuPilot.Port.AdminPort.MUTATINGTYPES</parameter> pair whose vendor body this
/// port composes from the tool's declared argument and the target (AD-51).</p>
Parameter COMPOSEDTYPES = "Process/BROADCAST";

/// <p>The admin port's call with <parameter>SENDERRORPARAM</parameter> removed from a copy of
/// <var>pQuery</var>, except for a <parameter>PROCESSENDPOINT</parameter>
/// <parameter>TERMINATETYPE</parameter> that carries it as <code>1</code>, which
/// <method>TerminateWithError</method> answers, and for <parameter>RECIPIENTSTYPE</parameter> and
/// <parameter>BROADCASTTYPE</parameter>, which are answered here.</p>
/// <p>Both take the pid set as the <parameter>IDPARAM</parameter> query parameter; one
/// <method>PidSetProblem</method> refuses is 400 <code>PORT.VALIDATION</code> with nothing read.
/// <parameter>RECIPIENTSTYPE</parameter> answers the set's recipients from one <code>LIST</code>,
/// and 404 when no pid of it is running. <parameter>BROADCASTTYPE</parameter> takes the message as
/// <parameter>MESSAGEQUERY</parameter>: a caller body is refused as the admin port refuses one for
/// a constant-body pair, an empty message and a set that is not all present and receivable are
/// refused (400 <code>PORT.VALIDATION</code>, 409 <code>PROCESS.BROADCAST.RECIPIENT</code>), and
/// only then is <method>BroadcastBody</method>'s body sent with an empty query.</p>
/// <p><b>Caller contract:</b> the arguments and outputs are
/// <method>OcuPilot.Port.AdminPort.Invoke</method>'s, and <var>pQuery</var> is not modified.</p>
ClassMethod Invoke(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status
{
    Kill tQuery
    Merge tQuery = pQuery
    Set tSendError = $Get(tQuery(..#SENDERRORPARAM))
    Kill tQuery(..#SENDERRORPARAM)
    If (pEndpoint = ..#PROCESSENDPOINT) && (pType = ..#TERMINATETYPE) && (tSendError = 1) {
        Quit ..TerminateWithError(pEndpoint, $Get(tQuery(..#IDPARAM)), .pResult, .pHttpStatus, .pFault)
    }
    If (pEndpoint '= ..#PROCESSENDPOINT) || ((pType '= ..#RECIPIENTSTYPE) && (pType '= ..#BROADCASTTYPE)) {
        Quit ##super(pEndpoint, pType, .tQuery, pBody, .pResult, .pHttpStatus, .pFault)
    }
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tBroadcast = (pType = ..#BROADCASTTYPE)
    Set tProblem = ..PidSetProblem($Get(tQuery(..#IDPARAM)), .tPids)
    If tProblem '= "" Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, tProblem, .pHttpStatus, .pFault)
    If tBroadcast {
        If $IsObject(pBody) || (pBody '= "") {
            Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
            Do ..LogFault(pEndpoint _ " " _ pType _ " was given a caller body, and its body is composed by the port", $$$ERROR($$$GeneralError, "a COMPOSEDTYPES pair takes no caller body"), pFault.code)
            Quit tSC
        }
        If $Get(tQuery(..#MESSAGEQUERY)) = "" Quit ..Refuse(400, ##class(OcuPilot.Api.Error).#BADREQUEST, ##class(OcuPilot.Api.Error).#PORTVALIDATION, "A broadcast carries a message", .pHttpStatus, .pFault)
        ; The vendor JOBs one sender per pid, and a job started inside a transaction can observe
        ; what the transaction has not committed.
        If $TLevel > 0 {
            Set tSC = ..Refuse(500, ##class(OcuPilot.Api.Error).#SERVERERROR, ##class(OcuPilot.Api.Error).#INTERNAL, ##class(OcuPilot.Kernel.Fault).#DEFAULTREASON, .pHttpStatus, .pFault)
            Do ..LogFault(pEndpoint _ " " _ pType _ " was asked for inside a transaction", $$$ERROR($$$GeneralError, "a broadcast is never sent inside a transaction"), pFault.code)
            Quit tSC
        }
    }
    Kill tNone
    Set tSC = ##super(..#PROCESSENDPOINT, ..#LISTTYPE, .tNone, "", .tRows, .pHttpStatus, .pFault)
    If $$$ISERR(tSC) Quit tSC
    Set pHttpStatus = 0
    Set tSC = ..RecipientsOf(tPids, $Get(tRows), .tRecipients, .tAbsent)
    If $$$ISERR(tSC) Quit ..Fail(pEndpoint, 500, tSC, .pHttpStatus, .pFault)
    If 'tBroadcast {
        If tRecipients.%Size() = 0 Quit ..Fail(pEndpoint, 404, $$$ERROR($$$GeneralError, "no process of the set is running"), .pHttpStatus, .pFault)
        Set pResult = {}
        Do pResult.%Set("Recipients", tRecipients)
        Do pResult.%Set("Absent", tAbsent)
        Do pResult.%Set(..#MESSAGEQUERY, "", "string")
        Set pHttpStatus = 200
        Quit $$$OK
    }
    If '..Receivable(tRecipients, tAbsent) Quit ..Refuse(409, ##class(OcuPilot.Api.Error).#CONFLICT, ##class(OcuPilot.Api.Error).#PROCESSBROADCASTRECIPIENT, ##class(OcuPilot.Api.Error).#REASONPROCESSBROADCASTRECIPIENT, .pHttpStatus, .pFault)
    Kill tNone
    Quit ##super(..#PROCESSENDPOINT, ..#BROADCASTTYPE, .tNone, ..BroadcastBody($Get(tQuery(..#MESSAGEQUERY)), tPids), .pResult, .pHttpStatus, .pFault)
}

/// <p>What is wrong with <var>pIds</var> as a broadcast's pid set, or <code>""</code>, with the set
/// in <var>pPids</var> as a <class>%List</class> of plain decimal pids in the canonical order: the
/// value in its <code>process</code> spelling (<class>OcuPilot.Kernel.EntityRef</class>, AD-13) must
/// be 1 to <parameter>BROADCASTMAXPIDS</parameter> members, each a positive whole number.</p>
ClassMethod PidSetProblem(pIds As %String, Output pPids As %List) As %String
{
    Set pPids = ""
    Set tProblem = "A broadcast names 1 to " _ ..#BROADCASTMAXPIDS _ " processes by their numeric process ids"
    Set tCanonical = ##class(OcuPilot.Kernel.EntityRef).NormalizedId(..#ENTITYTYPE, pIds)
    If tCanonical = "" Quit tProblem
    If $Length(tCanonical, ",") > ..#BROADCASTMAXPIDS Quit tProblem
    Set tPids = ""
    Set tSound = 1
    For tI = 1:1:$Length(tCanonical, ",") {
        Set tPid = $Piece(tCanonical, ",", tI)
        If '$Match(tPid, "^[1-9][0-9]{0,18}$") {
            Set tSound = 0
            Quit
        }
        Set tPids = tPids _ $ListBuild(tPid)
    }
    If 'tSound Quit tProblem
    Set pPids = tPids
    Quit ""
}

/// <p>The recipients <var>pPids</var> name in the process list <var>pRows</var>, a
/// <class>%DynamicArray</class> of the vendor's <code>LIST</code> rows: in <var>pRecipients</var>
/// one <code>{Pid, Username, CanReceiveBroadcast}</code> per pid the list holds, and in
/// <var>pAbsent</var> each pid it does not, both in <var>pPids</var>' order. A list that is not an
/// array is an error.</p>
ClassMethod RecipientsOf(pPids As %List, pRows As %DynamicArray, Output pRecipients As %DynamicArray, Output pAbsent As %DynamicArray) As %Status
{
    Set pRecipients = []
    Set pAbsent = []
    If '$IsObject(pRows) || 'pRows.%IsA("%Library.DynamicArray") Quit $$$ERROR($$$GeneralError, "the process list answered no array")
    Kill tByPid
    Set tIterator = pRows.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRow) {
        If '$IsObject(tRow) || 'tRow.%IsA("%Library.DynamicObject") Continue
        Set tPid = tRow.%Get("Pid")
        If ($IsObject(tPid)) || (tPid = "") Continue
        Set tByPid("p" _ tPid) = tRow
    }
    For tI = 1:1:$ListLength(pPids) {
        Set tPid = $List(pPids, tI)
        Set tRow = $Get(tByPid("p" _ tPid))
        If '$IsObject(tRow) {
            Do pAbsent.%Push(+tPid, "number")
            Continue
        }
        Set tRecipient = {}
        Do tRecipient.%Set("Pid", +tPid, "number")
        Do tRecipient.%Set("Username", tRow.%Get("Username"), "string")
        Do tRecipient.%Set("CanReceiveBroadcast", ''tRow.%Get("CanReceiveBroadcast"), "boolean")
        Do pRecipients.%Push(tRecipient)
    }
    Quit $$$OK
}

/// <p>Whether a broadcast to <var>pRecipients</var> may be sent: no pid of the set is absent, at
/// least one is present, and every one reads <code>CanReceiveBroadcast</code> true -- the vendor's
/// own flag for a foreground terminal job. Anything else sends nothing to any of them.</p>
ClassMethod Receivable(pRecipients As %DynamicArray, pAbsent As %DynamicArray) As %Boolean
{
    If '$IsObject(pRecipients) || '$IsObject(pAbsent) Quit 0
    If (pAbsent.%Size() > 0) || (pRecipients.%Size() = 0) Quit 0
    Set tReceivable = 1
    Set tIterator = pRecipients.%GetIterator()
    While tIterator.%GetNext(.tIndex, .tRecipient) {
        If '$IsObject(tRecipient) || 'tRecipient.%Get("CanReceiveBroadcast") Set tReceivable = 0
    }
    Quit tReceivable
}

/// <p>The vendor's broadcast body: <code>{Message, PidList}</code>, <var>pMessage</var> exactly as
/// given and each pid of <var>pPids</var> once, as a number.</p>
ClassMethod BroadcastBody(pMessage As %String, pPids As %List) As %DynamicObject
{
    Set tBody = {}
    Do tBody.%Set("Message", pMessage, "string")
    Set tList = []
    For tI = 1:1:$ListLength(pPids) {
        Do tList.%Push(+$List(pPids, tI), "number")
    }
    Do tBody.%Set("PidList", tList)
    Quit tBody
}

/// <p>Terminate process <var>pPid</var> with <code>SendError</code> 1, after the vendor endpoint's
/// own guard. On success <var>pResult</var> is <code>{}</code> and <var>pHttpStatus</var> 200, as
/// the endpoint answers without waiting for the process to end.</p>
/// <p>Must not be called from an escalated frame (AD-9). The caller's namespace is unchanged on
/// return (AD-16).</p>
ClassMethod TerminateWithError(pEndpoint As %String, pPid As %String, Output pResult, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tSC = $$$OK
    Set pResult = ""
    Set pHttpStatus = 0
    Set pFault = ""
    Set tOrigNS = $NAMESPACE
    Try {
        If '..HoldsResource(..#GATERESOURCE) {
            Set tSC = ..Fail(pEndpoint, 403, $$$OK, .pHttpStatus, .pFault)
            Quit
        }
        If pPid = "" {
            Set tSC = ..Fail(pEndpoint, 400, $$$ERROR($$$GeneralError, "the '" _ ..#IDPARAM _ "' query parameter is required"), .pHttpStatus, .pFault)
            Quit
        }
        If '$Match(pPid, "^[1-9][0-9]{0,18}$") {
            Set tSC = ..Fail(pEndpoint, 404, $$$ERROR($$$GeneralError, "'" _ pPid _ "' is not a process id"), .pHttpStatus, .pFault)
            Quit
        }

        Set $NAMESPACE = "%SYS"
        Set tOpenSC = $$$OK
        Set tProcess = ##class(SYS.Process).%OpenId(pPid, , .tOpenSC)
        If '$IsObject(tProcess) {
            Set $NAMESPACE = tOrigNS
            Set tSC = ..Fail(pEndpoint, 404, $Select($$$ISERR(tOpenSC): tOpenSC, 1: $$$ERROR($$$GeneralError, "no process " _ pPid)), .pHttpStatus, .pFault)
            Quit
        }
        If 'tProcess.CanBeTerminated {
            Set tProcess = ""
            Set $NAMESPACE = tOrigNS
            Set tSC = ..Fail(pEndpoint, 409, $$$ERROR($$$GeneralError, "process " _ pPid _ " cannot be terminated"), .pHttpStatus, .pFault)
            Quit
        }
        Set tTerminateSC = tProcess.Terminate(1)
        Set tProcess = ""
        Set $NAMESPACE = tOrigNS
        If $$$ISERR(tTerminateSC) {
            Set tSC = ..Fail(pEndpoint, 500, tTerminateSC, .pHttpStatus, .pFault)
            Quit
        }
        Set pResult = {}
        Set pHttpStatus = 200
    } Catch ex {
        Set $NAMESPACE = tOrigNS
        Set pResult = ""
        If ex.%IsA("%Exception.SystemException") && (ex.Name = "<PROTECT>") {
            Set tSC = ..Fail(pEndpoint, 403, ex.AsStatus(), .pHttpStatus, .pFault)
        } Else {
            Set tSC = ..Fail(pEndpoint, 500, ex.AsStatus(), .pHttpStatus, .pFault)
        }
    }
    Quit tSC
}

/// <p>The kind of script step <method>Snippet</method> renders: <code>objectscript</code> for
/// <parameter>PROCESSENDPOINT</parameter> <parameter>TERMINATETYPE</parameter>, which this port
/// carries out itself when the error flag is asked for, and the admin port's answer otherwise.</p>
ClassMethod SnippetForm(pEndpoint As %String, pType As %String) As %String
{
    If (pEndpoint = ..#PROCESSENDPOINT) && (pType = ..#TERMINATETYPE) Quit "objectscript"
    Quit ##super(pEndpoint, pType)
}

/// <p><method>Invoke</method>'s branches as a script (AD-59): a terminate that carries the error
/// flag is the <code>SYS.Process</code> call <method>TerminateWithError</method> makes, behind the
/// same terminable check; a broadcast is the vendor call with <method>BroadcastBody</method>'s body
/// and an empty query, and a pid set <method>PidSetProblem</method> refuses answers no step; every
/// other call is the admin port's script with <parameter>SENDERRORPARAM</parameter> removed from a
/// copy of <var>pQuery</var>.</p>
ClassMethod Snippet(pEndpoint As %String, pType As %String, ByRef pQuery, pBody As %DynamicAbstractObject = "", pContext As %DynamicObject = "") As %DynamicArray
{
    Kill tQuery
    Merge tQuery = pQuery
    Set tSendError = $Get(tQuery(..#SENDERRORPARAM))
    Kill tQuery(..#SENDERRORPARAM)
    If (pEndpoint = ..#PROCESSENDPOINT) && (pType = ..#BROADCASTTYPE) {
        If ..PidSetProblem($Get(tQuery(..#IDPARAM)), .tPids) '= "" Quit []
        Kill tNone
        Quit ##super(pEndpoint, pType, .tNone, ..BroadcastBody($Get(tQuery(..#MESSAGEQUERY)), tPids), pContext)
    }
    If (pEndpoint = ..#PROCESSENDPOINT) && (pType = ..#TERMINATETYPE) && (tSendError = 1) {
        Set tPid = ..Literal($Get(tQuery(..#IDPARAM)))
        Set tSteps = []
        Do tSteps.%Push(..ObjectScriptStep($ListBuild("Set tProcess = ##class(SYS.Process).%OpenId(" _ tPid _ ")", "Set tSC = $Select($IsObject(tProcess) && tProcess.CanBeTerminated: tProcess.Terminate(1), 1: $System.Status.Error(5001, ""that process is gone or cannot be terminated""))", "Do $System.Status.DisplayError(tSC)")))
        Quit tSteps
    }
    Quit ##super(pEndpoint, pType, .tQuery, pBody, pContext)
}

}
