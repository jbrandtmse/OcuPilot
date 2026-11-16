/// <p>Backup database list's Remove (Story 21.2, AD-6, AD-51, AD-53, AD-58): take one database off the backup database list. The
/// agent reaches it through a proposal the user confirms; Backup database list reaches it through its
/// <code>removedatabase</code> row action. Its screen action id is not <code>remove</code>: the client's verb-global
/// <code>remove</code> asks for a typed-name dialog for a write that Add database reverses. A database that is not on the list is
/// refused before any vendor call.</p>
Class OcuPilot.Screen.Tool.BackupDatabaseRemove Extends OcuPilot.Screen.Tool.BackupAction
{

Parameter TOOLNAME = "osmgmt.backupdatabases.remove";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.BackupDatabaseList";

Parameter DESCRIPTION = "Propose taking one database off the backup database list that the list backups use. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the database as the backup database list reports it. A database that is not on the list is refused.";

Parameter ENDPOINTNAME = "Databases";

Parameter WRITETYPE = "REMOVE";

Parameter SCREENACTIONS = "removedatabase";

Parameter READANSWERS = "Database,Directory,Listed";

Parameter PRECONDITIONFIELD = "Listed";

Parameter FINGERPRINTSUBJECT = "Listed";

Parameter IDDESCRIPTION = "The database to remove, as the backup database list reports it. A database that is not on the list is refused.";

}
