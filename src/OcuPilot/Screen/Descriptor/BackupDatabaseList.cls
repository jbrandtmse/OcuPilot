/// <p>Backup database list: the databases the list backups cover, each with its directory, read through
/// <class>OcuPilot.Port.BackupPort</class> (source kind <code>backup</code>, endpoint <code>Databases</code>) and rendered by the
/// <code>list</code> archetype's page from the declared <code>table</code> (AD-5, AD-29, AD-36, AD-51, AD-53, Story 21.2). It is OS
/// management's twenty-fifth side-bar entry. A list nobody defined answers no rows, and the page says what that means.</p>
/// <p><b>Its pairs</b> are Backup tasks': the classic Backup menu's (AD-8, AD-44). Its id is the database's name, matched without
/// regard to case (AD-13). Its primary action Add database and its row action Remove are the screen's callers of
/// <class>OcuPilot.Screen.Tool.BackupDatabaseAdd</class> and <class>OcuPilot.Screen.Tool.BackupDatabaseRemove</class> (AD-53); Remove is
/// declared as <code>removedatabase</code> so the client's typed-name dialog, which asks a consequence sentence no write here has, is not
/// asked for a write Add database reverses.</p>
Class OcuPilot.Screen.Descriptor.BackupDatabaseList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/backup-databases",
  "area": "os-management",
  "labelKey": "backupDatabasesLabel",
  "sideBarPosition": 25,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}, {"resource": "%DB_IRISSYS", "permission": "WRITE"}],
  "ownPrivileges": [{"resource": "%DB_IRISSYS", "permission": "WRITE"}],
  "entityType": "backup-database",
  "entityLabelKey": "aboutBackupDatabase",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Database"]},
  "primaryAction": {"id": "add", "selfProtection": ""},
  "rowActions": [{"id": "add", "selfProtection": ""}, {"id": "removedatabase", "selfProtection": ""}],
  "context": {"fields": ["Database", "Directory"], "secretFields": []},
  "emptyStateKey": "backupDatabasesEmpty",
  "commandAliases": ["backup database list", "backup databases", "add backup database"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "backupDatabasesPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "backupDatabasesPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "backupDatabasesPrompt3"}
  ],
  "classicPage": "%cspapp.mgr.utilsysbackupdatabases",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "database on the backup list",
    "label": "The databases the list backups cover; a list nobody defined is empty and the list backups then cover every database except IRISTEMP.",
    "source": {"port": "backup", "endpoint": "Databases", "type": "LIST"},
    "fields": ["Database", "Directory"],
    "filter": ["Database", "Directory"],
    "sort": {"fields": ["Database", "Directory"], "default": "Database", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Database", "labelKey": "systemInfoDatabase", "kind": "name"},
      {"field": "Directory", "labelKey": "lockColumnDirectory", "kind": "identifier"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "backupDatabasesEmptyAgent"
  },
  "toolIdentifier": "osmgmt.backupdatabases"
}
}

}
