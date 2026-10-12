/// <p>Interoperability's job message abort (AD-6, AD-10, AD-51, AD-53, AD-62, Story 20.23): abort the message one job of the
/// running production keeps retrying. The job moves on to its next message once its current retry wait ends, and the aborted
/// message is never delivered.</p>
/// <p><b>It is destructive</b>: an aborted message cannot be restored, so its card draws the destructive treatment, its row
/// action types the job's process id, and its governance key ships disabled (AD-22).</p>
/// <p>Two callers reach it: the Jobs list's and an item's Jobs tab's row action Abort message through
/// <class>OcuPilot.Api.ScreenAction</class>, and the agent's proposal and confirmation. Its state, fingerprint and refusals are
/// <class>OcuPilot.Screen.Tool.InteropJobAction</class>'s. It declares <code>EnsPortal.Queues</code> beside
/// <code>EnsPortal.ProductionConfig</code>, whose active-message table performs the same abort (AD-44).</p>
Class OcuPilot.Screen.Tool.InteropJobAbort Extends OcuPilot.Screen.Tool.InteropJobAction
{

Parameter TOOLNAME = "interop.jobs.abort";

Parameter DESCRIPTION = "Propose aborting the message one job of the running production keeps retrying. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the job by the process id the Jobs list or an item's Jobs tab reports in its Job column. When the job's current retry wait ends, the message is marked Aborted and is never delivered, and the job moves on to its next message. A job that is not retrying a message, a job whose process has ended and a namespace with no running production are refused. It cannot be undone.";

Parameter SCREENACTIONS = "abort";

Parameter WRITETYPE = "ABORTJOB";

/// <p>Declared: an aborted message is never delivered and cannot be restored.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CLASSICPAGES = "EnsPortal.ProductionConfig,EnsPortal.Queues";

Parameter FINGERPRINTSUBJECT = "Host,Status,ActiveMessage,Dead,Namespace";

Parameter PRECONDITIONFIELD = "Status";

/// <p>The card's row: the message the job is retrying, moving to Aborted.</p>
Parameter STATEFIELD = "ActiveMessage";

Parameter AFTERWORD = "Aborted";

Parameter PRECONDITIONCODES = "INTEROP.JOB.DEAD,INTEROP.JOB.NOTRETRYING,INTEROP.PRODUCTION.NOTRUNNING,INTEROP.NAMESPACE";

Parameter CONSEQUENCECODE = "INTEROP.JOB.ABORT";

}
