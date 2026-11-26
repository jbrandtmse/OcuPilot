/// <p>Interoperability's Workflow users: the namespace's workflow users, by name, as the classic Workflow Users page lists them, read through <class>OcuPilot.Port.InteropPort</class> (source kind
/// <code>interop</code>, endpoint <code>WorkflowUsers</code>) and rendered from the declared <code>table</code> (AD-5, AD-29, AD-36, AD-62, Story 24.17 Batch 3a). A workflow user is a user of
/// the instance who can be sent workflow tasks through the workflow roles they belong to; the list shows each one's full name, whether it is active and how many roles it belongs to.</p>
/// <p><b>Its primary action</b> New workflow user and <b>its row actions</b> Edit and Remove are the screen's callers of <class>OcuPilot.Screen.Tool.InteropWorkflowUserAdd</class>,
/// <class>OcuPilot.Screen.Tool.InteropWorkflowUserUpdate</class> and <class>OcuPilot.Screen.Tool.InteropWorkflowUserRemove</class> (AD-53, AD-55); each is stored at once. New workflow user and
/// Edit open one dialog; Edit shows the name read-only, because a name cannot be changed. Remove types the user's name.</p>
/// <p><b>Its id is the workflow user's name</b>, kept exactly (AD-13), and its scope is <code>namespace</code>. A name, a full name and a role count are untrusted content (AD-11, AD-60), and none
/// is a credential, so <code>secretFields</code> is empty. Its pairs are the classic page's: <code>%Ens_Portal:USE</code> and, as its own, <code>%Ens_WorkflowConfig:READ</code>; the three tools
/// add <code>%Ens_WorkflowConfig:WRITE</code> and WRITE on the namespace's globals database (AD-8, AD-62). It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.InteropWorkflowUserList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/workflow-users",
  "area": "interoperability",
  "labelKey": "interopWorkflowUsersLabel",
  "sideBarPosition": 25,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_WorkflowConfig", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_WorkflowConfig", "permission": "READ"}],
  "entityType": "interop-workflow-user",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Name"]},
  "primaryAction": {"id": "add", "selfProtection": ""},
  "rowActions": [{"id": "edit", "selfProtection": ""}, {"id": "remove", "selfProtection": ""}],
  "context": {"fields": ["Name", "FullName", "IsActive", "Roles"], "secretFields": []},
  "emptyStateKey": "interopWorkflowUsersEmpty",
  "commandAliases": ["workflow users", "workflow"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopWorkflowUsersPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopWorkflowUsersPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopWorkflowUsersPrompt3"}
  ],
  "classicPage": "EnsPortal.WFUsers",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "workflow user",
    "source": {"port": "interop", "endpoint": "WorkflowUsers", "type": "LIST"},
    "fields": ["Name", "FullName", "IsActive", "Roles"],
    "filter": ["Name", "FullName"],
    "sort": {"fields": ["Name", "FullName", "IsActive", "Roles"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "FullName", "labelKey": "userColumnFullName", "kind": "text"},
      {"field": "IsActive", "labelKey": "interopColumnActive", "kind": "status"},
      {"field": "Roles", "labelKey": "userColumnRoles", "kind": "number"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "interopWorkflowUsersEmptyAgent"
  },
  "toolIdentifier": "interop.workflowusers"
}
}

}
