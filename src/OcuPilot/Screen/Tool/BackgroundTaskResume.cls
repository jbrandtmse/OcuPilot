/// <p>The Background tasks list's resume tool (AD-6, AD-51, AD-52, AD-53): resume one paused
/// background task. It is <class>OcuPilot.Screen.Tool.BackgroundTaskCancel</class> with the
/// <code>RESUME</code> request type and <code>Running</code> as the state it leaves, the same in
/// both halves' spelling. The screen sends it at once, with no dialog.</p>
Class OcuPilot.Screen.Tool.BackgroundTaskResume Extends OcuPilot.Screen.Tool.BackgroundTaskCancel
{

Parameter TOOLNAME = "tasks.background.resume";

Parameter DESCRIPTION = "Propose resuming one paused background task: a Management Portal job such as a database compact, or an admin API task you queued. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the task by its source and its id exactly as the background tasks list reports them. A task whose current state does not allow it is refused.";

/// <p>The screen's own row action, which sends no argument (AD-51, AD-53).</p>
Parameter SCREENACTIONS = "resume";

Parameter WRITETYPE = "RESUME";

Parameter ADMINAFTER = "Running";

Parameter PORTALAFTER = "Running";

}
