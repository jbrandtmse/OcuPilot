/// <p>The Background tasks list: the admin API's async tasks the caller queued beside the classic
/// portal's background jobs, read through <class>OcuPilot.Port.BackgroundTaskPort</class>
/// (AD-27, AD-36) and rendered by the <code>list</code> archetype's page from the declared
/// <code>table</code> (AD-5). It is the Tasks area's fifth entry.</p>
/// <p><b>Its scope is <code>instance</code>.</b> The portal's rows are the instance's, whatever
/// namespace each job ran in, and the admin API's are the caller's own, so the same rows answer
/// whatever namespace the route names. Each row names its <code>Source</code>.</p>
/// <p><b>Its id is <code>composite</code></b>, the source and then the portal job's number or the
/// admin API task's GUID, compared exactly (AD-13).</p>
/// <p><b>The privilege set is two pairs, and one of them is the screen's own</b> (AD-8).
/// <code>%Admin_Operate:USE</code> is what controlling a portal job and the admin API's
/// <code>AsyncResult</code> both require; <code>%DB_IRISSYS:READ</code> is the port's
/// namespace-switch requirement. Declaring the first in <code>ownPrivileges</code> keeps the other
/// Tasks screens open to a holder of the area's two pairs alone.</p>
/// <p>It declares three row actions, <code>cancel</code>, <code>pause</code> and
/// <code>resume</code>, carried out by <class>OcuPilot.Screen.Tool.BackgroundTaskCancel</class>,
/// <class>OcuPilot.Screen.Tool.BackgroundTaskPause</class> and
/// <class>OcuPilot.Screen.Tool.BackgroundTaskResume</class>, none self-protected. It declares no
/// refresh (AD-43).</p>
/// <p>The classic page is <code>%CSP.UI.Portal.BackgroundTaskList</code>. As a list archetype it
/// links out to nothing.</p>
Class OcuPilot.Screen.Descriptor.BackgroundTaskList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "tasks/background",
  "area": "tasks",
  "labelKey": "backgroundTaskListLabel",
  "sideBarPosition": 5,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Admin_Operate", "permission": "USE"}],
  "entityType": "background-task",
  "entityLabelKey": "proposalEntityBackgroundTask",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Source", "Id"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "cancel", "selfProtection": ""}, {"id": "pause", "selfProtection": ""}, {"id": "resume", "selfProtection": ""}],
  "context": {"fields": ["Source", "Id", "Task", "Namespace", "Status", "Details", "ErrorCount", "StartTime"], "secretFields": []},
  "secretArguments": [],
  "fingerprintExcludes": [],
  "emptyStateKey": "backgroundTaskListEmpty",
  "commandAliases": ["background tasks", "background jobs"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "backgroundTaskListPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "backgroundTaskListPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "backgroundTaskListPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.BackgroundTaskList",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "background", "endpoint": "BackgroundTask", "type": "LIST"},
    "fields": ["Source", "Id", "Task", "Namespace", "Status", "Details", "ErrorCount", "StartTime"],
    "filter": ["Source", "Task", "Namespace", "Status", "Details"],
    "sort": {"fields": ["StartTime", "Task", "Source", "Namespace", "Status"], "default": "StartTime", "direction": "desc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Task", "labelKey": "proposalEntityTask", "kind": "name"},
      {"field": "Source", "labelKey": "auditEventFieldSource", "kind": "text"},
      {"field": "Status", "labelKey": "taskHistoryColumnStatus", "kind": "status"},
      {"field": "Namespace", "labelKey": "headerNamespaceLabel", "kind": "text"},
      {"field": "Details", "labelKey": "backgroundTaskColumnDetails", "kind": "text"},
      {"field": "ErrorCount", "labelKey": "backgroundTaskColumnErrorCount", "kind": "text"},
      {"field": "StartTime", "labelKey": "taskStartTime", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "backgroundTaskListEmptyAgent"
  },
  "toolIdentifier": "tasks.background"
}
}

}
