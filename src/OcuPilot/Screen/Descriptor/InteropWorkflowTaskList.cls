/// <p>Interoperability's Workflow tasks: the namespace's workflow tasks, newest first, as the classic Workflow Tasks page lists them, read through <class>OcuPilot.Port.InteropPort</class>
/// (source kind <code>interop</code>, endpoint <code>WorkflowTasks</code>) and rendered from the declared <code>table</code> (AD-5, AD-29, AD-36, AD-62, Story 24.17 Batch 4). A workflow task is
/// the work a business process sent to a workflow role and waits on; the list shows each one's role, status, priority and assignee. <code>Status</code> is the vendor's own word, shown as data.</p>
/// <p><b>Its row actions</b> Assign and Cancel task are the screen's callers of <class>OcuPilot.Screen.Tool.InteropWorkflowTaskAssign</class> and
/// <class>OcuPilot.Screen.Tool.InteropWorkflowTaskCancel</class> (AD-53). Assign opens the one dialog the classic Assign or Reassign Task dialog is, after a dry run a person reviews; Cancel task
/// types the task's ID. The list has no primary action: a task is made by a business process.</p>
/// <p><b>Its id is the task's ID</b>, a whole number sent as text, and its scope is <code>namespace</code>. A subject is untrusted content (AD-11, AD-60), and none is a credential, so
/// <code>secretFields</code> is empty. Its pairs are the classic page's: <code>%Ens_Portal:USE</code> alone, the page declaring no resource of its own; the two tools add
/// <code>%Ens_WorkflowConfig:WRITE</code> and WRITE on the namespace's globals database (AD-8, AD-62). It does not refresh (AD-43); a workflow user's, role's or member's change event re-reads
/// it, since each can move a task, through <code>secondaryEntityTypes</code> (AD-14).</p>
Class OcuPilot.Screen.Descriptor.InteropWorkflowTaskList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/workflow-tasks",
  "area": "interoperability",
  "labelKey": "interopWorkflowTasksLabel",
  "sideBarPosition": 27,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}],
  "entityType": "interop-workflow-task",
  "secondaryEntityTypes": ["interop-workflow-user", "interop-workflow-member"],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["TaskId"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "assign", "selfProtection": ""}, {"id": "cancel", "selfProtection": ""}],
  "context": {"fields": ["TaskId", "RoleName", "IsComplete", "Status", "Priority", "AssignedTo", "Subject", "TimeCreated"], "secretFields": []},
  "emptyStateKey": "interopWorkflowTasksEmpty",
  "commandAliases": ["workflow tasks"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopWorkflowTasksPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopWorkflowTasksPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopWorkflowTasksPrompt3"}
  ],
  "classicPage": "EnsPortal.WFTasklist",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "workflow task",
    "source": {"port": "interop", "endpoint": "WorkflowTasks", "type": "LIST"},
    "fields": ["TaskId", "RoleName", "IsComplete", "Status", "Priority", "Source", "AssignedTo", "Subject", "TimeCreated", "TimeCompleted", "Duration"],
    "filter": ["RoleName", "AssignedTo", "Status", "Subject"],
    "sort": {"fields": ["TaskId", "RoleName", "IsComplete", "Status", "Priority", "Source", "AssignedTo", "TimeCreated", "TimeCompleted"], "default": "TaskId", "direction": "desc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "TaskId", "labelKey": "taskHistoryColumnTaskId", "kind": "name"},
      {"field": "RoleName", "labelKey": "userRoleField", "kind": "text"},
      {"field": "Status", "labelKey": "taskHistoryColumnStatus", "kind": "text"},
      {"field": "Priority", "labelKey": "taskDetailsPriority", "kind": "number"},
      {"field": "IsComplete", "labelKey": "interopLogColumnCompleted", "kind": "status"},
      {"field": "Source", "labelKey": "auditEventFieldSource", "kind": "text"},
      {"field": "AssignedTo", "labelKey": "roleEditorTabAssignedTo", "kind": "text"},
      {"field": "Subject", "labelKey": "x509ColumnSubject", "kind": "text"},
      {"field": "TimeCreated", "labelKey": "journalColumnCreated", "kind": "text"},
      {"field": "TimeCompleted", "labelKey": "taskHistoryColumnCompleted", "kind": "text"},
      {"field": "Duration", "labelKey": "explorerUnitTestsColumnDuration", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "interopWorkflowTasksEmptyAgent"
  },
  "toolIdentifier": "interop.workflowtasks"
}
}

}
