/// <p>The Role form: one role, created at its bare route with its resource grants and granted roles,
/// and edited at its id route by the role editor, rendered by the <code>form-page</code> archetype
/// (AD-5). Its create Save and the agent's confirmed <code>permissions.roles.create</code> are two
/// callers of one tool, and so are its edit Save and <code>permissions.roles.update</code>
/// (AD-55).</p>
/// <p><b>It is built and routable, and it takes no side-bar position</b> (<code>sideBarPosition</code>
/// 0): it is reached from <class>OcuPilot.Screen.Descriptor.RoleList</class>'s Create, at that list's
/// own route with <code>/edit</code> appended.</p>
/// <p><b>It declares no <code>read</code> and no <code>table</code></b> (AD-36): the create route
/// answers the role it made, and the list is where the declared read lives.</p>
/// <p><b>Its privilege set is the list's own</b> -- <code>%Admin_Secure:USE</code> plus
/// <code>%DB_IRISSYS:READ</code> -- because the form writes the endpoint the list reads (AD-8).</p>
/// <p><b>Its classic equivalent is <code>%CSP.UI.Portal.Role</code></b>, in the class's own case
/// (AD-44). It declares no exemption, does not refresh (AD-43) and carries no secret field. It
/// declares three suggested prompts (Story 11.3's contract).</p>
Class OcuPilot.Screen.Descriptor.RoleForm Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "permissions/roles/edit",
  "area": "permissions",
  "labelKey": "userRoleField",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "role",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": []},
  "secretArguments": [],
  "fingerprintExcludes": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "userPromptGroupAccess", "textKey": "rolePromptHolders"},
    {"groupKey": "userPromptGroupAccess", "textKey": "rolePromptPrivilege"},
    {"groupKey": "userPromptGroupAccess", "textKey": "rolePromptGrantedRoles"}
  ],
  "classicPage": "%CSP.UI.Portal.Role",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "permissions.roleform"
}
}

}
