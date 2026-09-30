/// <p>Database details' compact (Story 18.4, AD-51, AD-53): move one database's free space to the end
/// of its file, where a truncate can return it. The agent reaches it through a proposal the user
/// confirms; Database details reaches it through its <code>compact</code> row action, whose one value is
/// <code>TargetFreeSpace</code> (AD-56 (ii)). <class>OcuPilot.Port.DatabasePort</class> sends
/// <code>{TargetFreeSpace}</code>; the vendor queues it as a background task (AD-26).</p>
/// <p><b>Its pairs are Database details', <code>%DB_IRISSYS:WRITE</code> and
/// <code>%DB_&lt;resource&gt;:READ</code> on the target</b> (AD-8 as amended 2026-09-29): the vendor
/// saves the background task in the system database and reads the target (measured on
/// <code>ocupilot-b-ci</code>); the target's resource is read through the port
/// (<method>ArgumentPairs</method>).</p>
Class OcuPilot.Screen.Tool.DatabaseCompact Extends OcuPilot.Screen.Tool.DatabaseAction
{

Parameter TOOLNAME = "osmgmt.databasedetails.compact";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.DatabaseDetails";

Parameter DESCRIPTION = "Propose compacting one mounted database: moving its free space to the end of its file, where a truncate can return it. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the database by its directory as the databases list reports it. A dismounted or read-only database is refused.";

Parameter WRITETYPE = "COMPACT";

Parameter SCREENACTIONS = "compact";

Parameter SCREENVALUES = "compact=TargetFreeSpace";

Parameter ARGUMENT = "TargetFreeSpace";

Parameter ARGUMENTDESCRIPTION = "The free space to gather at the end of the file, in whole megabytes, from 0 to the database's free space.";

Parameter PRECONDITIONFIELD = "Mounted";

Parameter FINGERPRINTSUBJECT = "Mounted,ReadOnly,TargetFreeSpace";

Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

Parameter CLASSICPAGES = "%CSP.UI.Portal.Background.Dialog.DatabaseCompact";

/// <p><code>%DB_&lt;resource&gt;:READ</code> on the target's own resource, read through this tool's
/// port as the caller (<method>OcuPilot.Screen.Tool.DatabaseAction.TargetResourcePair</method>).</p>
ClassMethod ArgumentPairs(pDescriptor As %String = "", pArgs As %DynamicObject, Output pResolved As %Boolean) As %List
{
    Quit ..TargetResourcePair(pArgs, .pResolved)
}

}
