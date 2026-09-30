/// <p>Database details' mount (Story 18.4, AD-51, AD-53): mount one dismounted database, read-only when
/// asked. The agent reaches it through a proposal the user confirms; Database details reaches it
/// through its <code>mount</code> row action, whose one value is <code>ReadOnly</code> (AD-56 (ii)).
/// <class>OcuPilot.Port.DatabasePort</class> sends <code>{"ReadOnly":true}</code> when asked and
/// <code>{}</code> otherwise; the vendor mounts synchronously.</p>
/// <p><b>Its pairs are Database details' and <code>%Admin_Secure:USE</code></b> (AD-8 as amended
/// 2026-09-29): the vendor's mount looks up the database's resource and is refused without it
/// (measured on <code>ocupilot-b-ci</code>). The classic Mount dialog is its replaced page
/// (AD-44).</p>
Class OcuPilot.Screen.Tool.DatabaseMount Extends OcuPilot.Screen.Tool.DatabaseAction
{

Parameter TOOLNAME = "osmgmt.databasedetails.mount";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.DatabaseDetails";

Parameter DESCRIPTION = "Propose mounting one database that is dismounted, so the namespaces that use it can read and write it again. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the database by its directory as the databases list reports it; set ReadOnly true to mount it read-only. A database that is already mounted is refused.";

Parameter WRITETYPE = "MOUNT";

Parameter SCREENACTIONS = "mount";

Parameter SCREENVALUES = "mount=ReadOnly";

Parameter ARGUMENT = "ReadOnly";

Parameter ARGUMENTTYPE = "boolean";

Parameter ARGUMENTREQUIRED As BOOLEAN = 0;

Parameter ARGUMENTDESCRIPTION = "Whether to mount the database read-only. Omit it, or send false, to mount it for reading and writing.";

Parameter PRECONDITIONFIELD = "Mounted";

Parameter FINGERPRINTSUBJECT = "Mounted,ReadOnly";

Parameter STATEFIELD = "Mounted";

Parameter WRITERESOURCE = "%Admin_Secure";

Parameter CLASSICPAGES = "%CSP.UI.Portal.Dialog.DBActions";

/// <p>One state row: <code>Mounted</code> from <code>false</code> to <code>true</code>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = [{"field": "Mounted", "before": "false", "after": "true"}]
    Set pProblem = ""
    Quit $$$OK
}

}
