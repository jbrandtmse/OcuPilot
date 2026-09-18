/// <p>Task details: one task's own properties and schedule, read through the vendor's own
/// <code>Task.CRUD</code> <code>GET</code> (AD-2, AD-36) with its last and next run merged from one
/// <code>INFO</code> call, and rendered by this screen's own page from the declared
/// <code>table</code> doubling as the field list (AD-5).</p>
/// <p><b>It is a sub-resource of Task schedule and never listed</b> (<code>sideBarPosition</code>
/// 0). It declares its parent, <code>parentScope</code> <code>tasks/schedule</code> (AD-5, Story
/// 6.7), and is reached from that list's name cell -- re-pointed here from the one-task History --
/// at <code>tasks/schedule/details/&lt;Id&gt;</code>, the vendor's own numeric task id. Its one
/// declared criterion, <code>taskId</code>, is filled by the client from that route id and sent to
/// the vendor under its own name, <code>id</code> (<code>vendorParam</code>), because
/// <code>Task.CRUD</code> reads its query parameter by that name rather than by the descriptor's
/// own. <method>OcuPilot.Screen.Registry.RouteEntityType</method> answers <code>task</code> for this
/// screen, resolved through that parent (DW-1020).</p>
/// <p><b>GET carries properties and schedule, never run times.</b> <code>TaskToJson</code> answers
/// <code>Name</code>, <code>Description</code>, <code>NameSpace</code>, <code>TaskClass</code>,
/// <code>RunAsUser</code>, <code>Priority</code> as display text, the schedule fields
/// (<code>TimePeriod</code>, <code>TimePeriodEvery</code>, <code>TimePeriodDay</code>,
/// <code>DailyFrequency</code>, <code>DailyFrequencyTime</code>, <code>DailyIncrement</code>,
/// <code>DailyStartTime</code>, <code>DailyEndTime</code> as <code>HH:MM:SS</code>,
/// <code>StartDate</code> and <code>EndDate</code> as <code>YYYY-MM-DD</code>) and no run history at
/// all. The list's own <code>Suspended</code> is wrong on this build (see
/// <class>OcuPilot.Screen.Descriptor.TaskScheduleList</class>), so this screen's
/// <code>Type</code>, <code>Suspended</code>, <code>Error</code>, <code>LastStarted</code>,
/// <code>LastFinished</code> and <code>NextScheduled</code> come from the declared
/// <code>rowGet</code>'s <code>INFO</code> call instead, keyed by <code>taskId</code>, the route-id
/// criterion's param, because GET's own answer carries no property to key it by (AD-36, Story 6.7). <code>Error</code> is the vendor's raw
/// <code>&lt;THROW&gt;</code> text and is untrusted (AD-11). GET's own answer carries no
/// <code>Id</code> either -- <code>TaskToJson</code> sets none -- so <code>Id</code> is seeded from
/// the same criterion value, which is what this screen's composite <code>id</code> reads its row's
/// own key from (<class>OcuPilot.Screen.Read</class>).</p>
/// <p><b><code>Settings</code> is never named.</b> GET's own answer carries a <code>Settings</code>
/// object of arbitrary task-class properties, passwords among them, so no field, no context field
/// and no test names it (AD-24, AD-35).</p>
/// <p><b>The schedule in words is composed on the client</b> from these display values (AD-3),
/// never from the vendor's own <code>%SYS.Task</code> <code>DisplayRunCalc</code> /
/// <code>DisplayIntervalCalc</code>, which a screen read cannot call without bypassing the port. A
/// suspended task's <code>NextScheduled</code> is a stale past time, so the page reads it as "Not
/// scheduled while suspended" instead (inference).</p>
/// <p><b>It is one of the seven screens the shared auto-refresh framework binds</b> (AD-43), at the
/// rates <file>EXPERIENCE.md</file>'s auto-refresh bullet declares. Refreshing a parent-scoped read
/// is sound here because its one criterion is the route id rather than a server search the user ran
/// (Story 6.7's grammar widening).</p>
/// <p><b>The privilege set is Task schedule's own,</b> <code>%Admin_Task:USE</code> plus
/// <code>%DB_IRISSYS:READ</code> (AD-8, AD-29).</p>
/// <p><b>The classic page is <code>%CSP.UI.Portal.TaskInfo</code></b>, spelled in the class's own
/// case (AD-44); this screen declares no exemption, so it links out to nothing.</p>
/// <p>It declares no primary or row action. A deleted or unrecognized id reads as zero rows (AD-37)
/// rather than a refusal, and the page shows "This task no longer exists."</p>
Class OcuPilot.Screen.Descriptor.TaskDetails Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "tasks/schedule/details",
  "area": "tasks",
  "labelKey": "taskDetailsLabel",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": true,
  "refreshRates": [5, 10, 30, 60],
  "privileges": [{"resource": "%Admin_Task", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "task",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "tasks/schedule",
  "id": {"kind": "composite", "parts": ["Id"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {
    "fields": ["Id", "Name", "Description", "NameSpace", "TaskClass", "Priority", "RunAsUser", "TimePeriod", "TimePeriodEvery", "TimePeriodDay", "DailyFrequency", "DailyFrequencyTime", "DailyIncrement", "DailyStartTime", "DailyEndTime", "StartDate", "EndDate", "Type", "Suspended", "Error", "LastStarted", "LastFinished", "NextScheduled"],
    "secretFields": []
  },
  "emptyStateKey": "taskDetailsGone",
  "commandAliases": ["task details"],
  "classicPage": "%CSP.UI.Portal.TaskInfo",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {
      "port": "admin",
      "endpoint": "Task.CRUD",
      "type": "GET",
      "rowGet": {
        "key": "taskId",
        "param": "id",
        "type": "INFO",
        "fields": ["Type", "Suspended", "Error", "LastStarted", "LastFinished", "NextScheduled"],
        "derived": []
      }
    },
    "fields": ["Id", "Name", "Description", "NameSpace", "TaskClass", "Priority", "RunAsUser", "TimePeriod", "TimePeriodEvery", "TimePeriodDay", "DailyFrequency", "DailyFrequencyTime", "DailyIncrement", "DailyStartTime", "DailyEndTime", "StartDate", "EndDate", "Type", "Suspended", "Error", "LastStarted", "LastFinished", "NextScheduled"],
    "filter": ["Name", "Description", "NameSpace", "TaskClass", "Priority", "RunAsUser", "TimePeriod", "TimePeriodEvery", "TimePeriodDay", "DailyFrequency", "DailyFrequencyTime", "DailyIncrement", "DailyStartTime", "DailyEndTime", "StartDate", "EndDate", "Type", "Suspended", "Error", "LastStarted", "LastFinished", "NextScheduled"],
    "sort": {
      "fields": ["Name", "Description", "NameSpace", "TaskClass", "Priority", "RunAsUser", "TimePeriod", "TimePeriodEvery", "TimePeriodDay", "DailyFrequency", "DailyFrequencyTime", "DailyIncrement", "DailyStartTime", "DailyEndTime", "StartDate", "EndDate", "Type", "Suspended", "Error", "LastStarted", "LastFinished", "NextScheduled"],
      "default": "Name",
      "direction": "asc"
    },
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "taskId", "labelKey": "taskHistoryColumnTaskId", "kind": "text", "maxLength": 10, "vendorParam": "id"}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Description", "labelKey": "tableColumnDescription", "kind": "text"},
      {"field": "NameSpace", "labelKey": "headerNamespaceLabel", "kind": "text"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "Suspended", "labelKey": "taskColumnSuspended", "kind": "status"},
      {"field": "TaskClass", "labelKey": "taskDetailsTaskClass", "kind": "text"},
      {"field": "Priority", "labelKey": "taskDetailsPriority", "kind": "text"},
      {"field": "RunAsUser", "labelKey": "taskDetailsRunAs", "kind": "text"},
      {"field": "LastStarted", "labelKey": "taskHistoryColumnStarted", "kind": "text"},
      {"field": "LastFinished", "labelKey": "taskHistoryColumnCompleted", "kind": "text"},
      {"field": "NextScheduled", "labelKey": "taskColumnNextRun", "kind": "text"},
      {"field": "Error", "labelKey": "taskDetailsLastError", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "tasks.taskdetails"
}
}

}
