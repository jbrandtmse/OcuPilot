/// <p>Backup tasks' Run (Story 21.2, AD-6, AD-51, AD-53, AD-58): start one backup task, in the background, through the
/// harvested backup body behind <class>OcuPilot.Port.BackupPort</class>. The agent reaches it through a proposal the user
/// confirms; Backup tasks reaches it through its <code>run</code> row action. The task is named from the instance's own
/// list, and nothing starts while any task reads Running.</p>
/// <p><b>It is destructive</b> by <class>OcuPilot.Screen.Tool.Write</class>'s definition: a started backup cannot be
/// withdrawn here (<class>OcuPilot.Screen.Tool.ExplorerSqlRun</class> is the model). Its card carries the run note
/// (<parameter>CONSEQUENCECODE</parameter>). Its fingerprint covers the task's status and whether any task runs: a change
/// since the mint refuses the confirm. The classic page that starts it is <parameter>CLASSICPAGES</parameter>.</p>
Class OcuPilot.Screen.Tool.BackupRun Extends OcuPilot.Screen.Tool.BackupAction
{

Parameter TOOLNAME = "osmgmt.backuptasks.run";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.BackupTaskList";

Parameter DESCRIPTION = "Propose starting one backup task: the instance runs it in the background and its result appears in the backup history. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the task as the backup tasks list reports it. A name the list does not report, and a run while any backup task is running, are refused.";

Parameter ENDPOINTNAME = "Tasks";

Parameter WRITETYPE = "RUN";

Parameter SCREENACTIONS = "run";

/// <p>A started backup cannot be withdrawn here.</p>
Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter READANSWERS = "Name,Type,LastRun,Status,Description,SystemTask,WritesFrozen,AnyRunning";

Parameter PRECONDITIONFIELD = "AnyRunning";

Parameter FINGERPRINTSUBJECT = "Status,AnyRunning";

Parameter IDDESCRIPTION = "The backup task, named as this instance's own backup tasks list reports it. A name the list does not report is refused.";

Parameter CLASSICPAGES = "%cspapp.op.utilsysbackup";

/// <p>The client maps it to the run note.</p>
Parameter CONSEQUENCECODE = "BACKUP.RUN";

/// <p><parameter>CONSEQUENCECODE</parameter>, the note the card states.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCECODE
}

}
