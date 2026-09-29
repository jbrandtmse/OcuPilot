/// <p>The Background tasks list's pause tool (AD-6, AD-51, AD-52, AD-53): pause one background
/// task. It is <class>OcuPilot.Screen.Tool.BackgroundTaskCancel</class> with the
/// <code>PAUSE</code> request type and <code>Paused</code> as the state it leaves, the same in
/// both halves' spelling. The screen sends it at once, with no dialog.</p>
Class OcuPilot.Screen.Tool.BackgroundTaskPause Extends OcuPilot.Screen.Tool.BackgroundTaskCancel
{

Parameter TOOLNAME = "tasks.background.pause";

Parameter DESCRIPTION = "Propose pausing one running background task: a Management Portal job such as a database compact, or an admin API task you queued. It changes nothing by itself: it answers a proposal the user reviews and confirms. A paused task holds its place until it is resumed or canceled. Name the task by its source and its id exactly as the background tasks list reports them. A task whose current state does not allow it is refused.";

/// <p>The screen's own row action, which sends no argument (AD-51, AD-53).</p>
Parameter SCREENACTIONS = "pause";

Parameter WRITETYPE = "PAUSE";

Parameter ADMINAFTER = "Paused";

Parameter PORTALAFTER = "Paused";

}
