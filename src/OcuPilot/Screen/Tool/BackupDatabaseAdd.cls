/// <p>Backup database list's Add database (Story 21.2, AD-6, AD-51, AD-53, AD-58): put one local database on the backup
/// database list the list backups use. The agent reaches it through a proposal the user confirms; Backup database list reaches
/// it through its <code>add</code> action, which names the database. The database is named from the databases the instance
/// configures, so no caller value is a path (AD-21); a database already on the list, the temporary database and a name the
/// instance does not hold are refused before any vendor call.</p>
Class OcuPilot.Screen.Tool.BackupDatabaseAdd Extends OcuPilot.Screen.Tool.BackupAction
{

Parameter TOOLNAME = "osmgmt.backupdatabases.add";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.BackupDatabaseList";

Parameter DESCRIPTION = "Propose adding one local database to the backup database list that the list backups use. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the database as this instance configures it. A database already on the list, a database the instance does not hold and the temporary database are refused.";

Parameter ENDPOINTNAME = "Databases";

Parameter WRITETYPE = "ADD";

Parameter SCREENACTIONS = "add";

Parameter READANSWERS = "Database,Directory,Listed";

Parameter PRECONDITIONFIELD = "Listed";

Parameter FINGERPRINTSUBJECT = "Listed";

Parameter IDDESCRIPTION = "The database to add, as this instance configures it. A name the instance does not hold is refused.";

}
