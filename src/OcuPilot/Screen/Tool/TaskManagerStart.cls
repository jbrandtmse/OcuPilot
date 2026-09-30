/// <p>The Task schedule's Task Manager start tool (AD-6, AD-8, AD-9, AD-51, AD-53, Story 16.11):
/// <class>OcuPilot.Screen.Tool.TaskManagerSuspend</class> with the vendor's <code>RUN</code>
/// (<code>StartTASKMGR()</code>), acting only from <code>Not running</code>. The stopped banner's
/// Start Task Manager sends it at once, with no dialog, and the agent proposes it.</p>
/// <p><b>It requires <code>%Admin_Secure:USE</code> beyond the screen's pairs</b> (AD-8 as amended).
/// The vendor starts the Task Manager as a job with the caller's roles and switches its user to
/// <code>TASKMGR</code> only when the caller holds that pair; without it the new Task Manager runs as
/// the caller and a due task fails. A caller without it is refused by name before any port call. The
/// port call runs in no escalated frame, so the job takes the caller's own roles (AD-9).</p>
/// <p>The vendor answers 409 for a start while the process is alive, suspended included, and never
/// resumes, so a suspended Task Manager is refused with the sentence that says to resume it. A start
/// records no audit event (AD-15 and AD-53's ninth named case). It carries no consequence.</p>
Class OcuPilot.Screen.Tool.TaskManagerStart Extends OcuPilot.Screen.Tool.TaskManagerSuspend
{

Parameter TOOLNAME = "tasks.schedule.startmanager";

Parameter DESCRIPTION = "Propose starting this instance's Task Manager when it is not running, so scheduled tasks run again. It changes nothing by itself: it answers a proposal the user reviews and confirms. Send the literal 'manager' as the id. A Task Manager that is running is refused, and so is a suspended one, which is resumed instead.";

/// <p>The stopped banner's own action, which sends no argument (AD-51, AD-53).</p>
Parameter SCREENACTIONS = "startmanager";

Parameter WRITETYPE = "RUN";

Parameter FROMSTATUS = "Not running";

Parameter TOSTATUS = "Running";

/// <p>The pair the start declares beyond the screen's own (AD-8 as amended).</p>
Parameter STARTRESOURCE = "%Admin_Secure";

Parameter STARTPERMISSION = "USE";

/// <p>The suspend's pairs, then <parameter>STARTRESOURCE</parameter>:<parameter>STARTPERMISSION</parameter>
/// once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##super(pDescriptor, .pResolved)
    If 'pResolved Quit ""
    Set tStart = $ListBuild(..#STARTRESOURCE, ..#STARTPERMISSION)
    If $ListFind(tPairs, tStart) Quit tPairs
    Quit tPairs _ $ListBuild(tStart)
}

/// <p>None: a start carries no consequence.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ""
}

}
