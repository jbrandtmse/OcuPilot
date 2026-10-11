/// <p>Interoperability's job stop (AD-6, AD-51, AD-53, AD-62, Story 20.23): stop one job of the running production. The job is
/// asked to finish its current message within the production's update timeout, at most
/// <parameter>OcuPilot.Port.InteropPort.STOPSECONDS</parameter> seconds, and forced if it does not, as the classic Jobs page
/// stops it; a job that had to be forced has its message put back on its queue. The item runs a job short until Productions'
/// confirmed Update starts one again.</p>
/// <p>It is not destructive: the job is started again by an Update, so its governance key ships enabled (AD-22). Its change
/// event is <code>deleted</code>: the job's row leaves the Jobs list.</p>
/// <p>Two callers reach it: the Jobs list's and an item's Jobs tab's row action Stop job through
/// <class>OcuPilot.Api.ScreenAction</class>, and the agent's proposal and confirmation. Its state, fingerprint and refusals are
/// <class>OcuPilot.Screen.Tool.InteropJobAction</class>'s. A job whose process has ended is refused, and so is a pid no job of the
/// running production holds, so a system process is never reached (AD-10).</p>
Class OcuPilot.Screen.Tool.InteropJobStop Extends OcuPilot.Screen.Tool.InteropJobAction
{

Parameter TOOLNAME = "interop.jobs.stop";

Parameter DESCRIPTION = "Propose stopping one job of the running production. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the job by the process id the Jobs list or an item's Jobs tab reports in its Job column. The job is asked to finish its current message within 15 seconds, or sooner when the production's update timeout is shorter; a job that does not is ended, and its message goes back on its queue. The item runs a job short until the production is updated. A job whose process has ended and a namespace with no running production are refused.";

Parameter SCREENACTIONS = "stop";

Parameter WRITETYPE = "STOPJOB";

Parameter CHANGEACTION = "deleted";

Parameter FINGERPRINTSUBJECT = "Host,Dead,Namespace";

Parameter PRECONDITIONFIELD = "Dead";

/// <p>The card's row: the job's status, moving to Stopped.</p>
Parameter STATEFIELD = "Status";

Parameter AFTERWORD = "Stopped";

Parameter PRECONDITIONCODES = "INTEROP.JOB.DEAD,INTEROP.PRODUCTION.NOTRUNNING,INTEROP.NAMESPACE";

Parameter CONSEQUENCECODE = "INTEROP.JOB.STOP";

}
