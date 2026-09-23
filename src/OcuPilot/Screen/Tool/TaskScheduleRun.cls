/// <p>The Task schedule's run tool (AD-51, AD-53, FR-52): <class>OcuPilot.Screen.Tool.TaskRun</class>
/// on the schedule list. It reads, writes, diffs and fingerprints exactly as that tool does; only
/// its name and the screen it belongs to differ.</p>
Class OcuPilot.Screen.Tool.TaskScheduleRun Extends OcuPilot.Screen.Tool.TaskRun
{

Parameter TOOLNAME = "tasks.schedule.run";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.TaskScheduleList";

}
