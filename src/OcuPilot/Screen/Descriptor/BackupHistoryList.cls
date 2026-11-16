/// <p>Backup history: the instance's most recent backups, newest first, at most fifty, each with its type, whether it covered every database or the backup list,
/// its status and its description, read through the harvested backup body behind <class>OcuPilot.Port.BackupPort</class> (source
/// kind <code>backup</code>, endpoint <code>History</code>) and rendered by the <code>list</code> archetype's page from the declared
/// <code>table</code> (AD-5, AD-23, AD-29, AD-36, Story 21.2). It is OS management's twenty-fourth side-bar entry and it is read-only.</p>
/// <p><b>Its pairs</b> are Backup tasks': the classic Backup menu's (AD-8, AD-44). A further history entry beyond the fifty is
/// reported as truncation, never dropped silently (AD-36).</p>
Class OcuPilot.Screen.Descriptor.BackupHistoryList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/backup-history",
  "area": "os-management",
  "labelKey": "backupHistoryLabel",
  "sideBarPosition": 24,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}, {"resource": "%DB_IRISSYS", "permission": "WRITE"}],
  "ownPrivileges": [{"resource": "%DB_IRISSYS", "permission": "WRITE"}],
  "entityType": "",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Time", "Type", "Status", "Databases", "Description"], "secretFields": []},
  "emptyStateKey": "backupHistoryEmpty",
  "commandAliases": ["backup history", "backup log"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "backupHistoryPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "backupHistoryPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "backupHistoryPrompt3"}
  ],
  "classicPage": "%cspapp.op.utilsysbackuplogs",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "backup",
    "label": "The most recent backups, newest first, at most fifty, with each one's type, status and whether it covered every database (All) or the backup list (List).",
    "source": {"port": "backup", "endpoint": "History", "type": "LIST"},
    "fields": ["Time", "Type", "Status", "Databases", "Description"],
    "filter": ["Type", "Status", "Databases", "Description"],
    "sort": {"fields": ["Time", "Type", "Status"], "default": "Time", "direction": "desc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Time", "labelKey": "auditColumnTime", "kind": "name"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "Databases", "labelKey": "databaseListLabel", "kind": "text"},
      {"field": "Status", "labelKey": "taskHistoryColumnStatus", "kind": "status"},
      {"field": "Description", "labelKey": "tableColumnDescription", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "osmgmt.backuphistory"
}
}

}
