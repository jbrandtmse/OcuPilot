/// <p>The process terminate-with-error port (AD-52): <class>OcuPilot.Port.AdminPort</class> with one
/// write carried out through the documented <code>%SYS</code> class the vendor endpoint itself calls.
/// A <code>Process</code> <code>TERMINATE</code> whose query carries <parameter>SENDERRORPARAM</parameter>
/// <code>1</code> calls <code>SYS.Process.Terminate(1)</code>; every other call is the admin port's
/// own, with that parameter removed first.</p>
/// <p><b>Why a port.</b> Measured on this build: the vendor's <code>RunTerminate</code> calls
/// <code>Terminate()</code> and never passes its <code>SendError</code> argument, so the admin API
/// cannot express a terminate that logs a <code>&lt;RESJOB&gt;</code> error in the process's
/// namespace. This port repeats that endpoint's guard before the call, in its order: the
/// <code>ResourcesOR()</code> gate (<parameter>GATERESOURCE</parameter> at <code>USE</code>), its
/// not-found answer (404 for a pid no process carries) and its refusal of a process that cannot be
/// terminated (409). Faults are mapped exactly as the admin port maps the vendor's own.</p>
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

/// <p>The admin port's call with <parameter>SENDERRORPARAM</parameter> removed from a copy of
/// <var>pQuery</var>, except for a <parameter>PROCESSENDPOINT</parameter>
/// <parameter>TERMINATETYPE</parameter> that carries it as <code>1</code>, which
/// <method>TerminateWithError</method> answers.</p>
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
    Quit ##super(pEndpoint, pType, .tQuery, pBody, .pResult, .pHttpStatus, .pFault)
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

}
