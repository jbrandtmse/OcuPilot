/// <p>The Local databases editor's size grow (Story 18.4, AD-51, AD-55): grow one database's file to a
/// larger size. The agent reaches it through a proposal the user confirms; the editor reaches it through
/// its Save's <code>size</code> group (<class>OcuPilot.Area.OsMgmt.DatabaseSave</class>), written after
/// the other groups. <class>OcuPilot.Port.DatabasePort</class> resolves the configuration's directory
/// and sends <code>{Size}</code>; the vendor queues it (AD-26).</p>
/// <p>The size must be larger than the current size and no larger than a non-zero maximum: the vendor
/// silently does nothing with a smaller one and clamps a larger one (measured), so the rules refuse
/// both. <b>Its pairs are Local databases' and <code>%Admin_Operate:USE</code></b> for the port's poll
/// (AD-8 as amended 2026-09-29); the classic Database page is its replaced page (AD-44).</p>
Class OcuPilot.Screen.Tool.LocalDatabaseGrow Extends OcuPilot.Screen.Tool.DatabaseAction
{

Parameter TOOLNAME = "osmgmt.localdatabases.grow";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.LocalDatabaseList";

Parameter DESCRIPTION = "Propose growing one local database's file to a larger size. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the database as the local databases list reports it. A size at or below the current size, above the maximum size, or of a database that is not mounted is refused, and so is a grow of a database with a new volume threshold whose new volume directory is unset or is the manager directory.";

Parameter IDDESCRIPTION = "The database to grow, as this instance's local databases list reports its name. A name the list does not report is refused.";

Parameter WRITETYPE = "MODIFYSIZE";

Parameter ARGUMENT = "Size";

Parameter ARGUMENTDESCRIPTION = "The new size of the database's file, in whole megabytes, larger than its current size and no larger than its maximum size when one is set.";

Parameter PRECONDITIONFIELD = "Size";

Parameter FINGERPRINTSUBJECT = "Directory,Mounted,Size,MaxSize,NewVolumeDirectory,NewVolumeThreshold";

Parameter POLLRESOURCE = "%Admin_Operate";

Parameter WRITERESOURCE = "%Admin_Manage";

Parameter CLASSICPAGES = "%CSP.UI.Portal.Database";

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
