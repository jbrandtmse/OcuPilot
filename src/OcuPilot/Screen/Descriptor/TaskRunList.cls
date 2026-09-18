/// <p>History: one task's own run history, read through the vendor's own <code>Task.CRUD</code>
/// <code>HISTORY</code> request type with <code>taskId</code> present (AD-2, AD-36) and rendered by
/// the <code>list</code> archetype's page from the declared <code>table</code> (AD-5).</p>
/// <p><b>It is a sub-resource of Task schedule and never listed</b> (<code>sideBarPosition</code>
/// 0). It declares its parent, <code>parentScope</code> <code>tasks/schedule</code> (AD-5), and is
/// reached from that list's name cell at <code>tasks/schedule/history/&lt;Id&gt;</code>, the
/// vendor's own numeric task id <class>OcuPilot.Screen.Descriptor.TaskScheduleList</class>'s id
/// now carries. Its one declared criterion, <code>taskId</code>, is filled by the client from that
/// route id, sent to the vendor under its own name (no <code>vendorParam</code> needed, unlike
/// <class>OcuPilot.Screen.Descriptor.TaskHistoryList</class>'s <code>search</code>).
/// <method>OcuPilot.Screen.Registry.RouteEntityType</method> answers <code>task</code> for this
/// screen, resolved through that parent (DW-1020), while its rows keep their own
/// <code>task-history-entry</code> type.</p>
/// <p><b>A missing or unrecognized <code>taskId</code> is not a refusal.</b> The vendor answers the
/// unscoped <code>DescendingTaskHistoryFilter</code> when <code>taskId</code> is absent (accepted,
/// Story 6.6) and an empty list for one that names no task -- there is no way to tell "wrong id"
/// from "no runs yet" from the vendor's own answer, so the per-task empty state renders either way
/// rather than a refusal (the DW-1021 analog does not arise here).</p>
/// <p><b>Fields, filter, sort and row id are identical to <code>TaskHistoryList</code>'s</b>, the
/// same one vendor row shape read a different way: the id stays <code>composite</code> over
/// <code>TaskId</code>, <code>LogDatetime</code> and <code>Status</code>; any id kind but
/// <code>none</code> makes this screen <code>hasIdRoute</code>, and therefore a valid <code>childListFor</code> target for Task
/// schedule's name cell -- not a per-row dialog channel of its own, since this screen pairs no
/// editor or viewer and declares no classic link, so its own rows are not links (the same reason
/// <class>OcuPilot.Screen.Descriptor.WalletSecretList</class>'s are not).</p>
/// <p><b>It declares no <code>rowGet</code> and lists no parent of its own</b>: every field is in
/// the vendor's history row, so <code>context.secretFields</code> is empty (AD-24, AD-35). The
/// request is synchronous for the reason <code>TaskHistoryList</code>'s is (AD-26), and it declares
/// no <code>refreshes</code>: its one criterion runs when the page opens, with no Search to press,
/// and AD-43's roster of seven auto-refreshing screens does not name it.</p>
/// <p><b>The privilege set is <code>%Admin_Task:USE</code> plus <code>%DB_IRISSYS:READ</code></b>,
/// Task schedule's own pairs (AD-8, AD-29).</p>
/// <p><b>The classic page is <code>%CSP.UI.Portal.TaskHistoryId</code></b> (AD-44). As a list
/// archetype it links out to nothing.</p>
/// <p>It declares no primary or row action, so its empty state names what to do next rather than
/// inviting the agent.</p>
Class OcuPilot.Screen.Descriptor.TaskRunList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "tasks/schedule/history",
  "area": "tasks",
  "labelKey": "taskRunsLabel",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Task", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "task-history-entry",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "tasks/schedule",
  "id": {"kind": "composite", "parts": ["TaskId", "LogDatetime", "Status"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["LastStart", "Completed", "Name", "Status", "Result", "TaskId", "Namespace", "Routine", "Pid", "ErrDate", "ErrNumber", "Username", "LogDatetime"], "secretFields": []},
  "emptyStateKey": "taskRunsEmpty",
  "commandAliases": [],
  "classicPage": "%CSP.UI.Portal.TaskHistoryId",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "HISTORY"},
    "fields": ["LastStart", "Completed", "Name", "Status", "Result", "TaskId", "Namespace", "Routine", "Pid", "ErrDate", "ErrNumber", "Username", "LogDatetime"],
    "filter": ["Name", "Namespace", "Status", "Result", "Username", "Routine"],
    "sort": {"fields": ["LastStart", "Completed", "Name", "Namespace", "Status", "Result", "Username", "LogDatetime"], "default": "LogDatetime", "direction": "desc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "taskId", "labelKey": "taskHistoryColumnTaskId", "kind": "text", "maxLength": 10}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "LastStart", "labelKey": "taskHistoryColumnStarted", "kind": "text"},
      {"field": "Completed", "labelKey": "taskHistoryColumnCompleted", "kind": "text"},
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Status", "labelKey": "taskHistoryColumnStatus", "kind": "text"},
      {"field": "Result", "labelKey": "taskHistoryColumnResult", "kind": "text"},
      {"field": "Username", "labelKey": "processColumnUser", "kind": "text"},
      {"field": "Namespace", "labelKey": "headerNamespaceLabel", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "tasks.taskhistory"
}
}

}
