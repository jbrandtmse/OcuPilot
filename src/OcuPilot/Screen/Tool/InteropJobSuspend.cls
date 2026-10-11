/// <p>Interoperability's job message suspend (AD-6, AD-51, AD-53, AD-62, Story 20.23): set aside the message one job of the
/// running production keeps retrying, as Suspended, once its current retry wait ends. The job moves on to its next message, and
/// a suspended message can be resent later (Story 20.9). It is not destructive, and its governance key ships enabled
/// (AD-22).</p>
/// <p>Two callers reach it: the Jobs list's and an item's Jobs tab's row action Suspend message through
/// <class>OcuPilot.Api.ScreenAction</class>, and the agent's proposal and confirmation. Its state, fingerprint and refusals are
/// <class>OcuPilot.Screen.Tool.InteropJobAction</class>'s. The vendor's own check is <code>%Ens_MessageSuspend:USE</code>.</p>
Class OcuPilot.Screen.Tool.InteropJobSuspend Extends OcuPilot.Screen.Tool.InteropJobAction
{

Parameter TOOLNAME = "interop.jobs.suspend";

Parameter DESCRIPTION = "Propose suspending the message one job of the running production keeps retrying. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the job by the process id the Jobs list or an item's Jobs tab reports in its Job column. When the job's current retry wait ends, the message is set aside as Suspended, which can be resent later, and the job moves on to its next message. A job that is not retrying a message, a job whose process has ended and a namespace with no running production are refused.";

Parameter SCREENACTIONS = "suspend";

Parameter WRITETYPE = "SUSPENDJOB";

Parameter WRITERESOURCE = "%Ens_MessageSuspend";

Parameter WRITEPERMISSION = "USE";

Parameter CLASSICPAGES = "EnsPortal.ProductionConfig,EnsPortal.Queues";

Parameter FINGERPRINTSUBJECT = "Host,Status,ActiveMessage,Dead,Namespace";

Parameter PRECONDITIONFIELD = "Status";

/// <p>The card's row: the message the job is retrying, moving to Suspended.</p>
Parameter STATEFIELD = "ActiveMessage";

Parameter AFTERWORD = "Suspended";

Parameter PRECONDITIONCODES = "INTEROP.JOB.DEAD,INTEROP.JOB.NOTRETRYING,INTEROP.PRODUCTION.NOTRUNNING,INTEROP.NAMESPACE";

Parameter CONSEQUENCECODE = "INTEROP.JOB.SUSPEND";

}
