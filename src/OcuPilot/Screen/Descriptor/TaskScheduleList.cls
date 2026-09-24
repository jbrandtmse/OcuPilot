/// <p>The task schedule: every task the instance's Task Manager holds, read through the vendor's own
/// <code>Task.CRUD</code> LIST (AD-2, AD-36) and rendered by the <code>list</code> archetype's page
/// from the declared <code>table</code> (AD-5).</p>
/// <p><b>Its scope is <code>instance</code>, and its rows are not filtered by namespace.</b> The
/// Task Manager is one instance-wide scheduler and its rows span namespaces -- <code>%SYS</code>,
/// <code>HSSYS</code> and the install namespace among them -- so the list is the same whatever
/// namespace the route names, each row carrying its own <code>Namespace</code> as a column (AD-13).
/// That is also why the empty state names the instance rather than a namespace: a
/// <code>&lt;NAMESPACE&gt;</code> sentence would be false here.</p>
/// <p><b>Its id is <code>composite</code> over the single part <code>Id</code></b>: one
/// percent-encoded path segment carrying the vendor's own numeric task id, because Story 6.6's
/// per-task history and Story 6.7's task details both key on it. The name cell's link therefore
/// carries the numeric id rather than the task's name; Story 6.7 re-points it at task details.</p>
/// <p><b><code>Suspended</code> comes from the same endpoint's <code>INFO</code>, never from its
/// LIST</b> (DW-269, AD-36). The vendor LIST answers <code>"Suspended":false</code> for every task
/// on this build, genuinely suspended ones included: <code>RunList</code> applies a Yes/No coercion
/// to a column whose display values are <code>''</code>, <code>'Suspend Leave'</code> and
/// <code>'Suspend Reschedule'</code>, none of which contains "YES". The declared <code>rowGet</code>
/// issues <code>INFO</code> once per surviving row, keyed by the row's own <code>Id</code>, and
/// merges the truthful value into the row -- so the screen and the read tool see one answer
/// (AD-36). It is the Suspended column, which is what makes a suspend or a resume visible in the
/// row: after either, the LIST's field still reads the old value while <code>INFO</code> reads the
/// new one. It stays out of the filter and the sort.</p>
/// <p>The read declares no <code>fingerprintExcludes</code>. Measured on <code>ocupilot-ci</code>,
/// 2026-09-21 over a 20-second window: none of the eight fields <code>INFO</code> answers moved
/// while a task was suspended. The reason it generalizes past that window <b>(inference)</b> is
/// that a suspended task does not run, so its last-run figures, its <code>Status</code> and its
/// stale <code>NextScheduled</code> all stand -- so every one of them is inside the fingerprint and
/// a task another party resumed under a live proposal is refused (AD-6, AD-51). A field that did
/// move would refuse every confirm of a ten-minute-old proposal, which fails closed.</p>
/// <p><code>context.secretFields</code> is empty because the read carries no secret to strip
/// (AD-24, AD-35).</p>
/// <p><b>It declares a <code>banner</code></b>, the first screen to: a second
/// <class>OcuPilot.Port.AdminPort</class> read of <code>Task.Manager</code> whose
/// <code>Status</code> raises a warning strip above the table -- the one fact that decides whether
/// any of the schedule means anything. It rides in the read's own
/// response, so an auto-refresh tick re-evaluates it and the strip is gone the moment the condition
/// clears; a fault in it suppresses the strip and never fails the list. The Resume control beside it
/// is Epic 7's (FR-51): Epic 2 has no write path at all.</p>
/// <p><b>Two cases, one read</b> (DW-270). <code>RunGet</code> answers a closed set of three,
/// read live from <code>%SYS.Task.TASKMGRStatus()</code>: <code>Running</code>,
/// <code>Suspended</code> and <code>Not running</code>. A stopped Task Manager runs no scheduled
/// task either, and the single-case banner left it silent -- the schedule rendered as though it
/// were in force. <b>Stopped is spelled <code>Not running</code></b>, which is the vendor's own
/// word for status 0; the classic portal offers Start there and Resume at 2, which is why the two
/// sentences differ in what they ask for. <code>Running</code> matches no case and raises no
/// strip.</p>
/// <p><b>It is one of the seven screens the shared auto-refresh framework binds</b> (AD-43), at the
/// rates <file>EXPERIENCE.md</file>'s auto-refresh bullet declares. The framework owns the timer, the
/// persisted setting and the silent re-fetch; the screen declares only that it refreshes and at what
/// rates.</p>
/// <p><b>The privilege set is the narrower half of the vendor's <code>ResourcesOR()</code> for this
/// endpoint, <code>%Admin_Task:USE</code>, plus <code>%DB_IRISSYS:READ</code></b>: the endpoint
/// admits <code>%Admin_Task</code> <i>or</i> <code>%Admin_Operate</code> and a pair set is an AND, so
/// declaring both vendor resources would refuse an operator the port would have served
/// (<class>OcuPilot.Screen.Area</class> records that choice). Without the database read the vendor
/// endpoint fails inside <code>%SYS</code> and the port answers 500, so the second pair is what turns
/// that into a named refusal (AD-8).</p>
/// <p><b>The classic page is <code>%CSP.UI.Portal.TaskSchedule</code></b>, spelled in the class's own
/// case because the custom-resource lookup does not case-fold (AD-44). As a list archetype it links
/// out to nothing.</p>
/// <p><b>It declares four row actions</b>, each carried out for both callers by one write tool
/// (AD-51, AD-53): Run (<class>OcuPilot.Screen.Tool.TaskScheduleRun</class>), Suspend
/// (<class>OcuPilot.Screen.Tool.TaskSuspend</class>), Resume
/// (<class>OcuPilot.Screen.Tool.TaskResume</class>) and Delete
/// (<class>OcuPilot.Screen.Tool.TaskDelete</class>). Only Delete opens a dialog. None carries a
/// self-protection rule: a system task is deletable behind the typed name. Because the list is
/// write-capable, its empty state invites the agent.</p>
/// <p><b>Its primary action is Create</b> (Story 9.7), which opens the New Task wizard
/// (<class>OcuPilot.Screen.Descriptor.TaskForm</class>); the agent's twin is
/// <class>OcuPilot.Screen.Tool.TaskCreate</class>.</p>
Class OcuPilot.Screen.Descriptor.TaskScheduleList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "tasks/schedule",
  "area": "tasks",
  "labelKey": "taskListLabel",
  "sideBarPosition": 1,
  "archetype": "list",
  "built": true,
  "refreshes": true,
  "refreshRates": [5, 10, 30, 60],
  "privileges": [{"resource": "%Admin_Task", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "task",
  "entityLabelKey": "proposalEntityTask",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Id"]},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [{"id": "run", "selfProtection": ""}, {"id": "suspend", "selfProtection": ""}, {"id": "resume", "selfProtection": ""}, {"id": "delete", "selfProtection": ""}],
  "context": {"fields": ["Name", "Type", "Namespace", "Description", "Id", "LastFinished", "NextScheduled", "Suspended"], "secretFields": []},
  "emptyStateKey": "taskListEmpty",
  "commandAliases": ["task manager"],
  "classicPage": "%CSP.UI.Portal.TaskSchedule",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {
      "port": "admin",
      "endpoint": "Task.CRUD",
      "type": "LIST",
      "rowGet": {"key": "Id", "param": "id", "type": "INFO", "fields": ["Suspended"], "derived": []}
    },
    "fields": ["Name", "Type", "Namespace", "Description", "Id", "LastFinished", "NextScheduled", "Suspended"],
    "filter": ["Name", "Namespace", "Type", "Description"],
    "sort": {"fields": ["Name", "Namespace", "Type", "Description", "LastFinished", "NextScheduled"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Namespace", "labelKey": "headerNamespaceLabel", "kind": "text"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "Suspended", "labelKey": "taskColumnSuspended", "kind": "status"},
      {"field": "LastFinished", "labelKey": "taskColumnLastRun", "kind": "text"},
      {"field": "NextScheduled", "labelKey": "taskColumnNextRun", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "taskScheduleEmptyAgent"
  },
  "banner": {
    "source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"},
    "field": "Status",
    "cases": [
      {"equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"},
      {"equals": "Not running", "messageKey": "taskManagerStoppedBanner", "severity": "warning"}
    ]
  },
  "toolIdentifier": "tasks.schedule"
}
}

}
