/// <p>The Task schedule's Task Manager resume tool (AD-6, AD-51, AD-53, Story 16.11):
/// <class>OcuPilot.Screen.Tool.TaskManagerSuspend</class> with the vendor's <code>RESUME</code>
/// (<code>SuspendSet(0)</code>), acting only from <code>Suspended</code>. The suspended banner's
/// Resume Task Manager sends it at once, with no dialog, and the agent proposes it.</p>
/// <p>A resume that changes the state leaves <code>%System/%System/ConfigurationChange</code>
/// ("Modify Task Config.Suspend"). It carries no consequence.</p>
Class OcuPilot.Screen.Tool.TaskManagerResume Extends OcuPilot.Screen.Tool.TaskManagerSuspend
{

Parameter TOOLNAME = "tasks.schedule.resumemanager";

Parameter DESCRIPTION = "Propose resuming this instance's suspended Task Manager, so scheduled tasks run again. It changes nothing by itself: it answers a proposal the user reviews and confirms. Send the literal 'manager' as the id. A Task Manager that is running is refused, and so is one that is not running, which is started instead.";

/// <p>The suspended banner's own action, which sends no argument (AD-51, AD-53).</p>
Parameter SCREENACTIONS = "resumemanager";

Parameter WRITETYPE = "RESUME";

Parameter FROMSTATUS = "Suspended";

Parameter TOSTATUS = "Running";

/// <p>None: a resume carries no consequence.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ""
}

}
