/// <p>The Local databases editor's Add a volume (Story 18.4, AD-51, AD-53): add a volume file to one
/// database, created in its configured new volume directory. The agent reaches it through a proposal the
/// user confirms; the editor reaches it through the Local databases list's <code>expand</code> action,
/// whose one value is <code>InitialSize</code> (AD-56 (ii)), drawn by the editor alone.
/// <class>OcuPilot.Port.DatabasePort</class> resolves the configuration's directory and sends
/// <code>{InitialSize}</code>; the vendor queues it (AD-26). No audit event records it (AD-15, AD-53
/// named gaps). The port refuses a database that names no new volume directory, and one whose new
/// volume directory is the manager directory, before any vendor call (the owner's database-directory
/// rule, AD-21's sixth case).</p>
/// <p><b>Its pairs are Local databases' and <code>%Admin_Operate:USE</code></b> (AD-8 as amended
/// 2026-09-29): the vendor refuses the expand without it (measured on <code>ocupilot-b-ci</code>), and the
/// port's poll needs it. The classic volumes page and its Expand dialog are its replaced pages
/// (AD-44).</p>
Class OcuPilot.Screen.Tool.LocalDatabaseExpand Extends OcuPilot.Screen.Tool.DatabaseAction
{

Parameter TOOLNAME = "osmgmt.localdatabases.expand";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LocalDatabaseList";

Parameter DESCRIPTION = "Propose adding a volume file to one local database, created in its configured new volume directory. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the database as the local databases list reports it. A database that is not mounted, one whose new volume directory is unset or is the manager directory, and an initial size above its new volume threshold are refused.";

Parameter IDDESCRIPTION = "The database to add a volume to, as this instance's local databases list reports its name. A name the list does not report is refused.";

Parameter WRITETYPE = "EXPANDVOL";

Parameter SCREENACTIONS = "expand";

Parameter SCREENVALUES = "expand=InitialSize";

Parameter ARGUMENT = "InitialSize";

Parameter ARGUMENTDESCRIPTION = "The new volume's initial size, in whole megabytes, 1 or more, and no larger than the database's new volume threshold when one is set.";

Parameter PRECONDITIONFIELD = "Mounted";

Parameter FINGERPRINTSUBJECT = "Directory,Mounted,NewVolumeDirectory,NewVolumeThreshold,InitialSize";

Parameter POLLRESOURCE = "%Admin_Operate";

Parameter WRITERESOURCE = "%Admin_Manage";

Parameter CLASSICPAGES = "%CSP.UI.Portal.DatabaseVolumes,%CSP.UI.Portal.Dialog.ExpandVolume";

/// <p>A local database is named by its configuration name.</p>
ClassMethod IdArgument() As %String
{
    Quit "Name"
}

ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.DatabasePort).#NAMEPARAM
}

}
