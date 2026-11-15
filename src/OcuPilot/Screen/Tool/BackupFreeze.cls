/// <p>Backup tasks' Freeze writes (Story 21.2, AD-6, AD-10, AD-51, AD-53, AD-58): suspend the instance's database writes for an
/// external backup, with a suspend limit of 1 to <parameter>OcuPilot.Port.BackupPort.FREEZELIMITMAX</parameter> seconds the
/// instance enforces itself (<code>WDSuspendLimit</code>): after the limit it resumes writes without a thaw. The agent reaches
/// it through a proposal the user confirms; Backup tasks reaches it through its <code>freeze</code> action, whose one value is
/// the limit (AD-56 (ii)).</p>
/// <p>Its target is the literal <parameter>FIXEDID</parameter>, the instance's write state. A freeze is refused before any
/// vendor call when the limit is not a whole number in range, when writes are already frozen, and when the instance would
/// ignore the limit (<class>OcuPilot.Area.OsMgmt.BackupRules</class>). Its card carries the freeze consequence
/// (<parameter>CONSEQUENCECODE</parameter>); thawing is its opposite, so it is not destructive.</p>
Class OcuPilot.Screen.Tool.BackupFreeze Extends OcuPilot.Screen.Tool.BackupAction
{

Parameter TOOLNAME = "osmgmt.backuptasks.freeze";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.BackupTaskList";

Parameter DESCRIPTION = "Propose freezing the instance's database writes for an external backup, for a suspend limit you name in whole seconds from 1 to 600: the instance resumes writes by itself when the limit passes, and a thaw resumes them sooner. It changes nothing by itself: it answers a proposal the user reviews and confirms. Send the literal 'SYSTEM' as the target. A freeze while writes are already frozen is refused.";

Parameter ENDPOINTNAME = "Writes";

Parameter WRITETYPE = "FREEZE";

Parameter SCREENACTIONS = "freeze";

Parameter SCREENVALUES = "freeze=limit";

Parameter ARGUMENT = "limit";

Parameter ARGUMENTDESCRIPTION = "The suspend limit in whole seconds, from 1 to 600: the instance resumes database writes by itself after this long.";

Parameter FIXEDID = "SYSTEM";

Parameter IDDESCRIPTION = "Send the literal 'SYSTEM': a freeze acts on all of the instance's database writes. Any other value is refused.";

Parameter READANSWERS = "WriteState,Clustered,LimitMax,limit";

Parameter PRECONDITIONFIELD = "WriteState";

/// <p>The write state the freeze moves, whether the instance would honour a limit, and the limit itself, so a confirm is the freeze the person
/// reviewed (AD-51: an action-style write's payload is its fingerprint subject).</p>
Parameter FINGERPRINTSUBJECT = "WriteState,Clustered,limit";

/// <p>The client maps it to the freeze consequence.</p>
Parameter CONSEQUENCECODE = "BACKUP.FREEZE";

/// <p><parameter>CONSEQUENCECODE</parameter>, the warning the card states.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    Quit ..#CONSEQUENCECODE
}

}
