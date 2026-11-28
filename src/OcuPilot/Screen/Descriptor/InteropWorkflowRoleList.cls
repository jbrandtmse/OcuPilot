/// <p>Interoperability's Workflow roles: the namespace's workflow roles, by name, as the classic Workflow Roles page lists them, read through <class>OcuPilot.Port.InteropPort</class> (source kind
/// <code>interop</code>, endpoint <code>WorkflowRoles</code>) and rendered from the declared <code>table</code> (AD-5, AD-29, AD-36, AD-62, Story 24.17 Batch 3b). A workflow role is a group of
/// workflow users who are sent the same tasks; the list shows each one's description, its capacity and how many members it has, and a role's name opens its members (Role members).</p>
/// <p><b>Its primary action</b> New workflow role and <b>its row actions</b> Edit and Remove are the screen's callers of <class>OcuPilot.Screen.Tool.InteropWorkflowRoleAdd</class>,
/// <class>OcuPilot.Screen.Tool.InteropWorkflowRoleUpdate</class> and <class>OcuPilot.Screen.Tool.InteropWorkflowRoleRemove</class> (AD-53, AD-55); each is stored at once. New workflow role and
/// Edit open one dialog; Edit shows the name read-only, because a name cannot be changed. Remove types the role's name.</p>
/// <p><b>Its id is the workflow role's name</b>, kept exactly (AD-13), and its scope is <code>namespace</code>. A name, a description and a member count are untrusted content (AD-11, AD-60), and
/// none is a credential, so <code>secretFields</code> is empty. Its pairs are the classic page's: <code>%Ens_Portal:USE</code> and, as its own, <code>%Ens_WorkflowConfig:READ</code>; the three
/// tools add <code>%Ens_WorkflowConfig:WRITE</code> and WRITE on the namespace's globals database (AD-8, AD-62). It does not refresh (AD-43); a member write or a workflow user write re-reads it through
/// <code>secondaryEntityTypes</code> (AD-14).</p>
Class OcuPilot.Screen.Descriptor.InteropWorkflowRoleList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/workflow-roles",
  "area": "interoperability",
  "labelKey": "interopWorkflowRolesLabel",
  "sideBarPosition": 26,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_WorkflowConfig", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_WorkflowConfig", "permission": "READ"}],
  "entityType": "interop-workflow-role",
  "secondaryEntityTypes": ["interop-workflow-member", "interop-workflow-user"],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Name"]},
  "primaryAction": {"id": "add", "selfProtection": ""},
  "rowActions": [{"id": "edit", "selfProtection": ""}, {"id": "remove", "selfProtection": ""}],
  "context": {"fields": ["Name", "Description", "Capacity", "Members"], "secretFields": []},
  "emptyStateKey": "interopWorkflowRolesEmpty",
  "commandAliases": ["workflow roles"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopWorkflowRolesPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopWorkflowRolesPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopWorkflowRolesPrompt3"}
  ],
  "classicPage": "EnsPortal.WFRoles",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "workflow role",
    "source": {"port": "interop", "endpoint": "WorkflowRoles", "type": "LIST"},
    "fields": ["Name", "Description", "Capacity", "Members"],
    "filter": ["Name", "Description"],
    "sort": {"fields": ["Name", "Description", "Capacity", "Members"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Description", "labelKey": "tableColumnDescription", "kind": "text"},
      {"field": "Capacity", "labelKey": "promptGroupCapacity", "kind": "number"},
      {"field": "Members", "labelKey": "roleEditorTabMembers", "kind": "number"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "interopWorkflowRolesEmptyAgent"
  },
  "toolIdentifier": "interop.workflowroles"
}
}

}
