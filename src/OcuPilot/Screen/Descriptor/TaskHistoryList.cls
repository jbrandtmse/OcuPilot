/// <p>Task history, across every task: the Task Manager's run history, read through the vendor's own
/// <code>Task.CRUD</code> <code>HISTORY</code> request type (AD-2, AD-36) and rendered by the
/// <code>list (server criteria)</code> archetype's page from the declared <code>table</code>
/// (AD-5). It is the Tasks area's fourth screen, and the second Release 1 list whose API searches
/// on the <b>server</b> (Story 6.6, after <class>OcuPilot.Screen.Descriptor.AuditList</class>).</p>
/// <p><b>It declares two <code>read.criteria</code> fields.</b> <code>search</code> sends the
/// vendor's own <code>filter</code> -- named <code>vendorParam</code> because <code>filter</code>
/// is the read tool's own view argument (<parameter>OcuPilot.Screen.Registry.CRITERIARESERVEDPARAMS</parameter>)
/// -- an upper-cased substring match across every column. <code>userOnly</code> is a
/// <code>choice</code> of one option, <code>"1"</code>, drawn as a checkbox rather than a select:
/// checked sends <code>userOnly=1</code>, unchecked sends nothing, which is the vendor's own
/// <code>DescendingTaskHistoryFilter(filter, userOnly)</code> distinction.</p>
/// <p><b>Rows are runs, not tasks.</b> A failed run is <b>two</b> rows -- <code>Status</code> 1
/// with <code>Result</code> carrying the <code>&lt;THROW&gt;</code> text, then <code>Status</code>
/// 0 reading "TASK Suspended due to error" -- so <code>Status</code> 1 does not mean success and
/// <code>Result</code> is where the error text lives. No vendor key is unique across the
/// population, so the row id is <code>composite</code> over <code>TaskId</code>,
/// <code>LogDatetime</code> and <code>Status</code>, which separates a failed run's two rows.
/// That composite id also gives this screen its own <code>/:id</code> route: the Name cell's link
/// navigates to it, the page opens a dialog listing every declared read field of that row, and
/// closing it returns to the bare route with no second read.</p>
/// <p><b>It reaches no per-row detail call and lists no parent</b>: every field this screen needs
/// is in the vendor's own history row, so <code>context.secretFields</code> is empty because the
/// read carries no secret to strip (AD-24, AD-35).</p>
/// <p><b>The request is synchronous</b>: <code>Task.CRUD</code> defines no
/// <code>ShouldRunAsync</code> and its <code>RunHistory</code> queues nothing (AD-26).</p>
/// <p><b>It declares no <code>refreshes</code>.</b> Like <class>OcuPilot.Screen.Descriptor.AuditList</class>,
/// it renders nothing until Search is pressed, so a timer would have no rows to re-read (AD-43).</p>
/// <p><b>The privilege set is <code>%Admin_Task:USE</code> plus <code>%DB_IRISSYS:READ</code></b>,
/// the Tasks area's own pairs, unchanged by this screen (AD-8, AD-29).</p>
/// <p><b>The classic page is <code>%CSP.UI.Portal.TaskHistory</code></b> (AD-44). As a list
/// archetype it links out to nothing.</p>
/// <p>It declares no primary or row action, so its empty state names what to do next rather than
/// inviting the agent.</p>
Class OcuPilot.Screen.Descriptor.TaskHistoryList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "tasks/history",
  "area": "tasks",
  "labelKey": "taskHistoryLabel",
  "sideBarPosition": 4,
  "archetype": "list (server criteria)",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Task", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "task-history-entry",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["TaskId", "LogDatetime", "Status"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["LastStart", "Completed", "Name", "Status", "Result", "TaskId", "Namespace", "Routine", "Pid", "ErrDate", "ErrNumber", "Username", "LogDatetime"], "secretFields": []},
  "emptyStateKey": "taskHistoryEmpty",
  "commandAliases": ["task history", "task runs"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "taskHistoryListPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "taskHistoryListPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "taskHistoryListPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.TaskHistory",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "HISTORY"},
    "fields": ["LastStart", "Completed", "Name", "Status", "Result", "TaskId", "Namespace", "Routine", "Pid", "ErrDate", "ErrNumber", "Username", "LogDatetime"],
    "filter": ["Name", "Namespace", "Status", "Result", "Username", "Routine"],
    "sort": {"fields": ["LastStart", "Completed", "Name", "Namespace", "Status", "Result", "Username", "LogDatetime"], "default": "LogDatetime", "direction": "desc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "search", "labelKey": "taskHistorySearch", "kind": "text", "maxLength": 100, "vendorParam": "filter"},
        {"param": "userOnly", "labelKey": "taskHistoryUserOnly", "kind": "choice", "maxLength": 1, "options": ["1"]}
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
  "toolIdentifier": "tasks.history"
}
}

}
