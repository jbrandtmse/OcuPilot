/// <p>The processes list's terminate that also logs an error (AD-51, AD-52, AD-53, FR-55): end one
/// process at once and have it record a <code>&lt;RESJOB&gt;</code> error in its namespace's
/// application error log. It is <class>OcuPilot.Screen.Tool.ProcessTerminate</class> in every
/// respect but its name, its screen action, its port and its after-value.</p>
/// <p><b>Its write goes through <class>OcuPilot.Port.ProcessPort</class></b> (AD-52): the vendor's
/// terminate never passes <code>SYS.Process.Terminate</code>'s <code>SendError</code>, so the port
/// makes that call itself after the endpoint's own guard. <method>PortQuery</method> is what asks
/// for it, on the confirm's re-read and write and on the screen caller's read and write alike.</p>
/// <p>The Terminate dialog's checkbox sends this tool's <code>terminate-with-error</code> action,
/// which no surface draws on its own.</p>
Class OcuPilot.Screen.Tool.ProcessTerminateWithError Extends OcuPilot.Screen.Tool.ProcessTerminate
{

Parameter TOOLNAME = "osmgmt.processes.terminatewitherror";

Parameter DESCRIPTION = "Propose terminating one process this instance is running and having it log a <RESJOB> error in its namespace's application error log. It changes nothing by itself: it answers a proposal the user reviews and confirms. A terminated process stops at once without finishing its work, and this cannot be undone. Name the process by the numeric process id the processes list reports for it. A process OcuPilot is itself running in -- this request, or an agent turn -- and an IRIS system process are both refused.";

/// <p>The Terminate dialog's flag, a declared action no menu draws (AD-53).</p>
Parameter SCREENACTIONS = "terminate-with-error";

/// <p>The port that can pass the error-to-job flag (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.ProcessPort";

Parameter STATEAFTER = "Terminated, with a <RESJOB> error logged";

/// <p>Ask <parameter>PORTCLASS</parameter> for the error-to-job flag. The flag is this tool's
/// declaration, not the payload's, so <var>pPayload</var> is not read.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Set pQuery(##class(OcuPilot.Port.ProcessPort).#SENDERRORPARAM) = 1
}

}
