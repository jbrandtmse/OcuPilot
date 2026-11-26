/// <p>Interoperability's Workflow worklist: the namespace's worklist items, newest first, one for each workflow user a task was sent to, as the classic Workflow Worklist page lists them, read
/// through <class>OcuPilot.Port.InteropPort</class> (source kind <code>interop</code>, endpoint <code>WorkflowWorklist</code>) and rendered by the <code>list</code> archetype's page over the
/// declared <code>table</code> (AD-5, AD-29, AD-36, AD-62, Story 24.17 Batch 4). It is read-only: a longer worklist than the cap is reported as truncation, never dropped silently (AD-36), and a
/// subject is untrusted content, shown and never run (AD-11).</p>
/// <p><b>Its id</b> is the task's ID and the user's name, together. Its pairs are the classic page's: <code>%Ens_Portal:USE</code> alone, the page declaring no resource of its own. Its scope is
/// <code>namespace</code>. It does not refresh (AD-43); a task's, workflow user's or member's change event re-reads it, since each moves the items (AD-14).</p>
Class OcuPilot.Screen.Descriptor.InteropWorkflowWorklist Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/workflow-worklist",
  "area": "interoperability",
  "labelKey": "interopWorkflowWorklistLabel",
  "sideBarPosition": 28,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}],
  "entityType": "",
  "secondaryEntityTypes": ["interop-workflow-task", "interop-workflow-user", "interop-workflow-member"],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["TaskId", "UserName"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["TaskId", "UserName", "RoleName", "Priority", "TimeCreated", "Age", "AssignedTo", "Subject"], "secretFields": []},
  "emptyStateKey": "interopWorkflowWorklistEmpty",
  "commandAliases": ["workflow worklist", "worklist"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopWorkflowWorklistPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopWorkflowWorklistPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopWorkflowTasksPrompt2"}
  ],
  "classicPage": "EnsPortal.WFWorklist",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "worklist item",
    "source": {"port": "interop", "endpoint": "WorkflowWorklist", "type": "LIST"},
    "fields": ["TaskId", "UserName", "RoleName", "Priority", "TimeCreated", "Age", "AssignedTo", "Subject"],
    "filter": ["UserName", "RoleName", "Subject"],
    "sort": {"fields": ["TaskId", "UserName", "RoleName", "Priority", "TimeCreated", "AssignedTo"], "default": "TimeCreated", "direction": "desc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "TaskId", "labelKey": "taskHistoryColumnTaskId", "kind": "name"},
      {"field": "UserName", "labelKey": "processColumnUser", "kind": "text"},
      {"field": "RoleName", "labelKey": "userRoleField", "kind": "text"},
      {"field": "Priority", "labelKey": "taskDetailsPriority", "kind": "number"},
      {"field": "TimeCreated", "labelKey": "journalColumnCreated", "kind": "text"},
      {"field": "Age", "labelKey": "interopWorkflowWorklistColumnAge", "kind": "text"},
      {"field": "AssignedTo", "labelKey": "roleEditorTabAssignedTo", "kind": "text"},
      {"field": "Subject", "labelKey": "x509ColumnSubject", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "interop.workflowworklist"
}
}

}
