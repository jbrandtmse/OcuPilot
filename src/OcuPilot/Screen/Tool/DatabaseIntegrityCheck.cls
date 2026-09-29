/// <p>Databases' integrity check (Story 18.4, AD-51, AD-53): check one database or a set of them, or
/// only named globals of one. The agent reaches it through a proposal the user confirms; the Check
/// integrity flow reaches it through the Databases list's <code>integrity</code> action, whose target is
/// the set of directories as a JSON array (AD-13 as amended 2026-09-29) and whose one value is
/// <code>Globals</code> (AD-56 (ii)). <class>OcuPilot.Port.DatabasePort</class> sends
/// <code>{Databases:[{Directory, Globals?}]}</code>, never an empty array, which the vendor reads as
/// every database; the vendor queues it as a background task (AD-26), whose report the Integrity log
/// reads (<class>OcuPilot.Port.LogSourcePort</class>).</p>
/// <p><b>Its pairs are the Databases list's, <code>%Admin_Operate:USE</code> and
/// <code>%DB_IRISSYS:WRITE</code></b> (AD-8 as amended 2026-09-29): the vendor's own gate names
/// <code>%Admin_Operate</code>, which the port's poll needs too, and the check saves its task in the
/// system database (measured on <code>ocupilot-b-ci</code>). The classic Integrity check dialogs are its
/// replaced pages (AD-44).</p>
Class OcuPilot.Screen.Tool.DatabaseIntegrityCheck Extends OcuPilot.Screen.Tool.DatabaseAction
{

Parameter TOOLNAME = "osmgmt.databases.integrity";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.DatabaseList";

Parameter DESCRIPTION = "Propose an integrity check of one or more mounted databases, or of named globals in one database. It reads the databases and changes nothing in them; it answers a proposal the user reviews and confirms. Name one database by its directory as the databases list reports it, or several as a JSON array of such directories. A database that is not mounted is refused.";

Parameter IDDESCRIPTION = "The database to check, named by the directory this instance's databases list reports, or several as a JSON array of such directories, such as [""/a/"",""/b/""]. A directory the list does not report is refused.";

Parameter WRITETYPE = "INTEGRITYCHECK";

Parameter SCREENACTIONS = "integrity";

Parameter SCREENVALUES = "integrity=Globals";

Parameter ARGUMENT = "Globals";

Parameter ARGUMENTTYPE = "array";

Parameter ARGUMENTREQUIRED As BOOLEAN = 0;

Parameter ARGUMENTDESCRIPTION = "Only these globals, named without a leading caret, each starting with a letter or %. Omit it to check every global. Globals can be named only when one database is checked.";

Parameter PRECONDITIONFIELD = "Dismounted";

Parameter FINGERPRINTSUBJECT = "Dismounted,Globals";

Parameter POLLRESOURCE = "%Admin_Operate";

Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

Parameter CLASSICPAGES = "%CSP.UI.Portal.Dialog.Integ,%CSP.UI.Portal.Dialog.IntegOutput";

}
