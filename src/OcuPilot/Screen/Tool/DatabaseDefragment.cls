/// <p>Database details' defragment (Story 18.4, AD-51, AD-53): rearrange one database's globals so each
/// is stored contiguously. The database can grow while it works, and the task cannot be paused. The
/// agent reaches it through a proposal the user confirms; Database details reaches it through its
/// <code>defragment</code> row action. It sends no body; the vendor queues it as a background task
/// (AD-26).</p>
/// <p><b>Its pairs are the compact's</b> (AD-8 as amended 2026-09-29).</p>
Class OcuPilot.Screen.Tool.DatabaseDefragment Extends OcuPilot.Screen.Tool.DatabaseAction
{

Parameter TOOLNAME = "osmgmt.databasedetails.defragment";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.DatabaseDetails";

Parameter DESCRIPTION = "Propose defragmenting one mounted database, which can grow the database while it works and cannot be paused. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the database by its directory as the databases list reports it. A dismounted or read-only database is refused.";

Parameter WRITETYPE = "DEFRAGMENT";

Parameter SCREENACTIONS = "defragment";

Parameter PRECONDITIONFIELD = "Mounted";

Parameter FINGERPRINTSUBJECT = "Mounted,ReadOnly";

Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

Parameter CLASSICPAGES = "%CSP.UI.Portal.Background.Dialog.DatabaseDefragment";

/// <p>The compact's: <code>%DB_&lt;resource&gt;:READ</code> on the target.</p>
ClassMethod ArgumentPairs(pDescriptor As %String = "", pArgs As %DynamicObject, Output pResolved As %Boolean) As %List
{
    Quit ..TargetResourcePair(pArgs, .pResolved)
}

}
