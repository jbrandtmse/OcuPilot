/// <p>Upcoming tasks: the tasks the Task Manager will run next, one row each, read through <class>OcuPilot.Port.InteropPort</class> (source kind <code>interop</code>, endpoint
/// <code>SystemMonitorTasks</code>) from the table the vendor's <code>%SYS.Ensemble.GetEnsMetrics</code> answers, as the classic Interoperability System Monitor lists them (AD-5, AD-36, AD-62,
/// Story 24.17 Batch 5). An unlisted drill-down of System monitor; the page draws the same table from this declared read. The Task manager's own Upcoming tasks screen is a different read of
/// the same tasks, with a horizon.</p>
/// <p>It administers nothing: <code>entityType</code> is <code>""</code>, its <code>id</code> is <code>none</code>, its scope is <code>instance</code>, it declares no action, it does not refresh
/// (AD-43) and it takes no criterion. Its pairs are System monitor's (AD-8, AD-29); its classic page is <code>%CSP.UI.Portal.EnsembleMonitor</code> (AD-44).</p>
Class OcuPilot.Screen.Descriptor.InteropSystemMonitorTasks Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/system-monitor/tasks",
  "area": "interoperability",
  "labelKey": "taskUpcomingLabel",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_Dashboard", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_Dashboard", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Task", "ScheduledFor", "Status"], "secretFields": []},
  "emptyStateKey": "interopSystemMonitorTasksEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "taskPromptGroupSchedule", "textKey": "taskUpcomingListPrompt1"},
    {"groupKey": "taskPromptGroupSchedule", "textKey": "taskUpcomingListPrompt2"},
    {"groupKey": "taskPromptGroupSchedule", "textKey": "taskUpcomingListPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.EnsembleMonitor",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "upcoming task",
    "source": {"port": "interop", "endpoint": "SystemMonitorTasks", "type": "LIST"},
    "fields": ["Task", "ScheduledFor", "Status"],
    "filter": ["Task", "Status"],
    "sort": {"fields": ["Task", "ScheduledFor", "Status"], "default": "ScheduledFor", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Task", "labelKey": "proposalEntityTask", "kind": "name"},
      {"field": "ScheduledFor", "labelKey": "taskUpcomingColumnAt", "kind": "text"},
      {"field": "Status", "labelKey": "taskHistoryColumnStatus", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "interop.systemmonitortasks"
}
}

}
