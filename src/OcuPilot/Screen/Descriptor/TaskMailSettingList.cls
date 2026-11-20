/// <p>Task Manager email: the twelve email settings the Task Manager sends its task mail with, each with its value and the values it accepts,
/// read through <class>OcuPilot.Port.ConfigPort</class> (source kind <code>config</code>, endpoint <code>TaskMail</code>) and rendered by the
/// <code>list</code> archetype's page from the declared <code>table</code> (AD-5, AD-29, AD-35, AD-36, AD-53, Story 21.19). It is the Tasks
/// area's sixth entry. The mail password is not a row and no read of this screen carries it (AD-35).</p>
/// <p><b>Its pairs</b> are the area's <code>%Admin_Task:USE</code> and <code>%DB_IRISSYS:READ</code> with the port's own
/// <code>%Admin_Manage:USE</code>, which the vendor's <code>EmailGet</code> and <code>EmailSet</code> require (AD-8, AD-44); declaring the
/// last in <code>ownPrivileges</code> keeps the other Tasks screens open to a holder of the area's two pairs alone. Its tool adds
/// <code>%DB_IRISSYS:WRITE</code>.</p>
/// <p><b>Its id is the setting's name</b>, kept exactly (AD-13). Its row action Set value is the screen's caller of
/// <class>OcuPilot.Screen.Tool.TaskMailSettingSet</class> (AD-53). It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.TaskMailSettingList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "tasks/email",
  "area": "tasks",
  "labelKey": "taskMailSettingsLabel",
  "sideBarPosition": 6,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Task", "permission": "USE"}, {"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Admin_Manage", "permission": "USE"}],
  "entityType": "task-mail-setting",
  "entityLabelKey": "",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Name"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "set", "selfProtection": ""}],
  "context": {"fields": ["Name", "Value", "Kind", "Accepts", "Restart", "ReadOnly"], "secretFields": []},
  "emptyStateKey": "configSettingsEmpty",
  "commandAliases": ["task email", "task manager email"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "taskMailSettingsPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "taskHistoryListPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "taskHistoryListPrompt3"}
  ],
  "classicPage": "%cspapp.mgr.utilsystaskmail",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "Task Manager email setting",
    "label": "The email settings the Task Manager sends task mail with: the mail server, port, sender and sign-in name, the subject and message of the mail for a task that succeeds and for one that fails. The mail password is never shown.",
    "source": {"port": "config", "endpoint": "TaskMail", "type": "LIST"},
    "fields": ["Name", "Value", "Kind", "Accepts", "Restart", "ReadOnly"],
    "filter": ["Name", "Value"],
    "sort": {"fields": ["Name", "Value"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "agentGovernanceColumnSetting", "kind": "name"},
      {"field": "Value", "labelKey": "errorLogColumnValue", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "taskMailSettingsEmptyAgent"
  },
  "toolIdentifier": "tasks.mail"
}
}

}
