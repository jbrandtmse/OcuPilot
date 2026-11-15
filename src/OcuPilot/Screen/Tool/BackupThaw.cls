/// <p>Backup tasks' Thaw writes (Story 21.2, AD-6, AD-51, AD-53, AD-58): resume the instance's database writes after a freeze.
/// The agent reaches it through a proposal the user confirms; Backup tasks reaches it through its <code>thaw</code> action and
/// through the frozen banner's own. Its target is the literal <parameter>FIXEDID</parameter>, as
/// <class>OcuPilot.Screen.Tool.BackupFreeze</class>'s is; a thaw of writes that are not frozen is refused before any vendor
/// call.</p>
Class OcuPilot.Screen.Tool.BackupThaw Extends OcuPilot.Screen.Tool.BackupAction
{

Parameter TOOLNAME = "osmgmt.backuptasks.thaw";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.BackupTaskList";

Parameter DESCRIPTION = "Propose thawing the instance's database writes after a freeze, so they resume. It changes nothing by itself: it answers a proposal the user reviews and confirms. Send the literal 'SYSTEM' as the target. A thaw while writes are not frozen is refused.";

Parameter ENDPOINTNAME = "Writes";

Parameter WRITETYPE = "THAW";

Parameter SCREENACTIONS = "thaw";

Parameter FIXEDID = "SYSTEM";

Parameter IDDESCRIPTION = "Send the literal 'SYSTEM': a thaw acts on all of the instance's database writes. Any other value is refused.";

Parameter READANSWERS = "WriteState,Clustered,LimitMax,limit";

Parameter PRECONDITIONFIELD = "WriteState";

Parameter FINGERPRINTSUBJECT = "WriteState";

}
