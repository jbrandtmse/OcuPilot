/// <p>Backup tasks: the instance's backup tasks, its four built-in tasks first, each with its type, when it last ran, its status
/// and whether it is a system task, read through <class>OcuPilot.Port.BackupPort</class> (source kind <code>backup</code>,
/// endpoint <code>Tasks</code>) and rendered by the <code>list</code> archetype's page from the declared <code>table</code>
/// (AD-5, AD-29, AD-36, AD-51, AD-53, Story 21.2). It is OS management's twenty-third side-bar entry.</p>
/// <p><b>Its pairs</b> are the classic Backup menu's: <code>%Admin_Operate:USE</code> and <code>%DB_IRISSYS:READ</code>, the area's,
/// and, as its own, <code>%DB_IRISSYS:WRITE</code>, which the classic menu also needs to show any backup page (AD-8, AD-44).</p>
/// <p><b>Its id is the task's name</b>, kept exactly (AD-13). Its row action Run is the screen's caller of
/// <class>OcuPilot.Screen.Tool.BackupRun</class>; its two screen-level actions Freeze writes and Thaw writes are the callers of
/// <class>OcuPilot.Screen.Tool.BackupFreeze</class> and <class>OcuPilot.Screen.Tool.BackupThaw</class> (AD-53). While the instance's
/// database writes are frozen its banner says so and offers the thaw. It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.BackupTaskList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/backup-tasks",
  "area": "os-management",
  "labelKey": "backupTasksLabel",
  "sideBarPosition": 23,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}, {"resource": "%DB_IRISSYS", "permission": "WRITE"}],
  "ownPrivileges": [{"resource": "%DB_IRISSYS", "permission": "WRITE"}],
  "entityType": "backup-task",
  "entityLabelKey": "aboutBackupTask",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Name"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "run", "selfProtection": ""}, {"id": "freeze", "selfProtection": ""}, {"id": "thaw", "selfProtection": ""}],
  "context": {"fields": ["Name", "Type", "LastRun", "Status", "Description", "SystemTask", "WritesFrozen"], "secretFields": []},
  "emptyStateKey": "backupTasksEmpty",
  "commandAliases": ["backup tasks", "backups", "run backup", "freeze writes"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "backupTasksPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "backupTasksPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "backupTasksPrompt3"}
  ],
  "classicPage": "%cspapp.op.utilsysbackups",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "backup task",
    "label": "Backup tasks, the four built-in tasks first, with when each last ran and its status; the backup history is in osmgmt.backuphistory and the backup database list in osmgmt.backupdatabases.",
    "source": {"port": "backup", "endpoint": "Tasks", "type": "LIST"},
    "fields": ["Name", "Type", "LastRun", "Status", "Description", "SystemTask", "WritesFrozen"],
    "filter": ["Name", "Type", "Status", "Description"],
    "sort": {"fields": ["Name", "Type", "LastRun", "Status"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "LastRun", "labelKey": "taskColumnLastRun", "kind": "text"},
      {"field": "Status", "labelKey": "taskHistoryColumnStatus", "kind": "status"},
      {"field": "Description", "labelKey": "tableColumnDescription", "kind": "text"},
      {"field": "SystemTask", "labelKey": "backupColumnSystemTask", "kind": "status"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "backupTasksEmptyAgent"
  },
  "banner": {
    "source": {"port": "backup", "endpoint": "Writes", "type": "GET"},
    "field": "WriteState",
    "cases": [
      {"equals": "Frozen", "messageKey": "backupFrozenBanner", "severity": "warning", "action": "thaw"}
    ]
  },
  "toolIdentifier": "osmgmt.backuptasks"
}
}

}
