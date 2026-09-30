/// <p>Database details' truncate (Story 18.4, AD-51, AD-53): return the unused space at the end of one
/// database's file to the operating system, down to a target size. No data is removed. The agent
/// reaches it through a proposal the user confirms; Database details reaches it through its
/// <code>truncate</code> row action, whose one value is <code>TargetSize</code> (AD-56 (ii)).
/// <class>OcuPilot.Port.DatabasePort</class> sends <code>{TargetSize}</code>; the vendor queues it
/// (AD-26).</p>
/// <p>The target is 0, which returns all unused space, or a whole number of megabytes below the
/// current size; the vendor silently does nothing with a larger one (measured), so the rules refuse it.
/// Its pairs are Database details' own (measured on <code>ocupilot-b-ci</code>).</p>
Class OcuPilot.Screen.Tool.DatabaseTruncate Extends OcuPilot.Screen.Tool.DatabaseAction
{

Parameter TOOLNAME = "osmgmt.databasedetails.truncate";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.DatabaseDetails";

Parameter DESCRIPTION = "Propose truncating one mounted database: returning the unused space at the end of its file to the operating system, down to a target size. No data is removed. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the database by its directory as the databases list reports it. A dismounted or read-only database is refused.";

Parameter WRITETYPE = "TRUNCATE";

Parameter SCREENACTIONS = "truncate";

Parameter SCREENVALUES = "truncate=TargetSize";

Parameter ARGUMENT = "TargetSize";

Parameter ARGUMENTDESCRIPTION = "The file size to truncate to, in whole megabytes: 0 returns all unused space, and any other value must be smaller than the database's current size.";

Parameter PRECONDITIONFIELD = "Mounted";

Parameter FINGERPRINTSUBJECT = "Mounted,ReadOnly,Size,TargetSize";

Parameter CLASSICPAGES = "%CSP.UI.Portal.Background.Dialog.DatabaseTruncate";

}
