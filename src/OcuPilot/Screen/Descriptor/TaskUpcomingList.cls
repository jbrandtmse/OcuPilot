/// <p>The occurrences the Task Manager will run over a chosen horizon, read through the vendor's own
/// <code>Task.CRUD</code> <code>UPCOMING</code> request type (AD-2, AD-36) and drawn by
/// <file>ui/src/app/areas/tasks/upcoming.page.ts</file>, which puts the horizon control above the
/// shared data table.</p>
/// <p><b>Rows are occurrences, not tasks.</b> <code>RunUpcoming</code> answers
/// <code>%SYS.Task:UpcomingTasksFilter</code>, one row per scheduled run in ascending date and time,
/// so a task can appear more than once, and a suspended task's past-due occurrences are included.
/// <code>Datetime</code> is <code>YYYY-MM-DD HH:MM:SS</code>, which is why the default sort is
/// <code>Datetime</code> ascending, and why the id is composite, <code>Id</code> and
/// <code>Datetime</code>. <code>Suspended</code> here is a plain boolean the vendor does not
/// coerce.</p>
/// <p><b>The horizon is two server criteria</b> (AD-21). <code>hoursOffset</code> is one of six preset
/// hour counts, because the vendor reads any other text as zero rows; <code>toDatetime</code> is a
/// date and time. The vendor answers 24 hours when neither is sent and honours the hours when both
/// are, so the page sends exactly one. The request type is synchronous: <code>Task.CRUD</code> defines
/// no <code>ShouldRunAsync</code> and <code>RunUpcoming</code> queues nothing (AD-26).</p>
/// <p><b>It is a <code>list</code></b> (<file>EXPERIENCE.md</file>, the Upcoming tasks row), not a
/// <code>list (server criteria)</code>: the horizon scopes the query rather than searching it, so the
/// page reads when it opens, at 24 hours, and does not auto-refresh (AD-43).</p>
/// <p><b>It declares no Run</b>, for the reason <class>OcuPilot.Screen.Descriptor.TaskOnDemandList</class>
/// gives (AD-10).</p>
/// <p><b>The privilege set is <code>%Admin_Task:USE</code> plus <code>%DB_IRISSYS:READ</code></b>, the
/// Task schedule's set, established for this read by a real principal on a throwaway (AD-8,
/// AD-29).</p>
/// <p><b>The classic page is <code>%CSP.UI.Portal.TasksUpcoming</code></b> (AD-44). As a list
/// archetype it links out to nothing.</p>
Class OcuPilot.Screen.Descriptor.TaskUpcomingList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "tasks/upcoming",
  "area": "tasks",
  "labelKey": "taskUpcomingLabel",
  "sideBarPosition": 3,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Task", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "task",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Id", "Datetime"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Id", "Name", "Namespace", "Datetime", "Suspended"], "secretFields": []},
  "emptyStateKey": "taskUpcomingEmpty",
  "commandAliases": ["upcoming", "next runs"],
  "suggestedPrompts": [
    {"groupKey": "taskPromptGroupSchedule", "textKey": "taskUpcomingListPrompt1"},
    {"groupKey": "taskPromptGroupSchedule", "textKey": "taskUpcomingListPrompt2"},
    {"groupKey": "taskPromptGroupSchedule", "textKey": "taskUpcomingListPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.TasksUpcoming",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "UPCOMING"},
    "fields": ["Id", "Name", "Namespace", "Datetime", "Suspended"],
    "filter": ["Name", "Namespace"],
    "sort": {"fields": ["Datetime", "Name", "Namespace"], "default": "Datetime", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "hoursOffset", "labelKey": "taskUpcomingHorizon", "kind": "choice", "maxLength": 3, "options": ["1", "4", "12", "24", "72", "168"]},
        {"param": "toDatetime", "labelKey": "taskUpcomingUntil", "kind": "datetime", "maxLength": 19}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Datetime", "labelKey": "taskUpcomingColumnAt", "kind": "text"},
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Namespace", "labelKey": "headerNamespaceLabel", "kind": "text"},
      {"field": "Suspended", "labelKey": "taskColumnSuspended", "kind": "status"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "tasks.upcoming"
}
}

}
