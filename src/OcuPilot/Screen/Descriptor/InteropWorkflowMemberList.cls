/// <p>Interoperability's Role members: the workflow users one workflow role holds, by user name, as the classic Workflow Roles page's Users popup lists them, read through
/// <class>OcuPilot.Port.InteropPort</class> (source kind <code>interop</code>, endpoint <code>WorkflowMembers</code>) and rendered from the declared <code>table</code> (AD-5, AD-29, AD-36, AD-62,
/// Story 24.17 Batch 3b). Each row is the user, their full name, their rank and title in the role and whether they are active.</p>
/// <p><b>It is a sub-resource of the Workflow roles list and never listed</b> (<code>sideBarPosition</code> 0): it declares <code>parentScope</code> <code>interoperability/workflow-roles</code> and
/// is reached from that list's name cell at <code>interoperability/workflow-roles/members/&lt;role&gt;</code>. Its one declared criterion, <code>role</code>, is the route id, which AD-5 requires
/// of a parent-scoped read. The port's list also answers one workflow user's roles for the criterion <code>user</code>; no screen declares it.</p>
/// <p><b>Its id is the composite <code>[Role, User]</code></b>, each part kept exactly (AD-13), and its scope is <code>namespace</code>. A user name, a full name and a title are untrusted content
/// (AD-11, AD-60), and none is a credential, so <code>secretFields</code> is empty.</p>
/// <p><b>Its primary action</b> Add member and <b>its row action</b> Remove are the screen's callers of <class>OcuPilot.Screen.Tool.InteropWorkflowMemberAdd</class> and
/// <class>OcuPilot.Screen.Tool.InteropWorkflowMemberRemove</class> (AD-53, AD-55); each is stored at once. There is no edit: a rank or a title is changed by removing the member and adding them
/// again. Its pairs are the Workflow roles list's; the two tools add <code>%Ens_WorkflowConfig:WRITE</code> and WRITE on the namespace's globals database (AD-8, AD-62). It does not refresh
/// (AD-43); a role's change event re-reads it, through <code>secondaryEntityTypes</code> (AD-14).</p>
Class OcuPilot.Screen.Descriptor.InteropWorkflowMemberList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/workflow-roles/members",
  "area": "interoperability",
  "labelKey": "interopWorkflowMembersLabel",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_WorkflowConfig", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_WorkflowConfig", "permission": "READ"}],
  "entityType": "interop-workflow-member",
  "secondaryEntityTypes": ["interop-workflow-role"],
  "scope": "namespace",
  "parentScope": "interoperability/workflow-roles",
  "id": {"kind": "composite", "parts": ["Role", "User"]},
  "primaryAction": {"id": "add", "selfProtection": ""},
  "rowActions": [{"id": "remove", "selfProtection": ""}],
  "context": {"fields": ["Role", "User", "FullName", "Ranking", "Title", "IsActive"], "secretFields": []},
  "emptyStateKey": "interopWorkflowMembersEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopWorkflowMembersPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopWorkflowRolesPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopWorkflowMembersPrompt2"}
  ],
  "classicPage": "EnsPortal.WFRoles",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "workflow role member",
    "source": {"port": "interop", "endpoint": "WorkflowMembers", "type": "LIST"},
    "fields": ["Role", "User", "FullName", "Ranking", "Title", "IsActive"],
    "filter": ["User", "FullName", "Title"],
    "sort": {"fields": ["User", "FullName", "Ranking", "Title", "IsActive"], "default": "User", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "role", "labelKey": "userRoleField", "kind": "text", "maxLength": 128, "hint": "One workflow role, spelled as interop.workflowroles.read answers its Name."}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "User", "labelKey": "processColumnUser", "kind": "name"},
      {"field": "FullName", "labelKey": "userColumnFullName", "kind": "text"},
      {"field": "Ranking", "labelKey": "interopWorkflowMemberColumnRank", "kind": "number"},
      {"field": "Title", "labelKey": "interopPartnerFieldTitle", "kind": "text"},
      {"field": "IsActive", "labelKey": "interopColumnActive", "kind": "status"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "interopWorkflowMembersEmptyAgent"
  },
  "toolIdentifier": "interop.workflowmembers"
}
}

}
