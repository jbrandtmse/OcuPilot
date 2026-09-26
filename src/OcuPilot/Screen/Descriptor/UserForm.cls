/// <p>The User form: one user account, created at this route and edited at
/// <code>permissions/users/edit/&lt;id&gt;</code>, rendered by the <code>form-page</code> archetype
/// (AD-5). The create's Save and the agent's confirmed <code>permissions.users.create</code> are two
/// callers of one tool, and the editor's Save and <code>permissions.users.update</code> two callers of
/// another (AD-55). The editor's actions are the Users list's own (AD-53).</p>
/// <p><b>It is built and routable, and it takes no side-bar position</b> (<code>sideBarPosition</code>
/// 0): it is reached from <class>OcuPilot.Screen.Descriptor.UserList</class>'s Create, at that list's
/// own route with <code>/edit</code> appended.</p>
/// <p><b>It declares no <code>read</code> and no <code>table</code></b> (AD-36): the form read
/// answers the account an edit names, and the list is where the declared read lives.</p>
/// <p><b>It declares three suggested prompts</b>, grouped by task (Story 11.3).</p>
/// <p><b>Its privilege set is the list's own</b> -- <code>%Admin_Secure:USE</code> plus
/// <code>%DB_IRISSYS:READ</code> -- because the form writes the endpoint the list reads (AD-8).</p>
/// <p><b>Its classic equivalent is <code>%CSP.UI.Portal.User</code></b>, in the class's own case
/// (AD-44). It declares no exemption and does not refresh (AD-43).</p>
/// <p><b><code>Password</code> is secret-typed in its context</b> (AD-24, AD-35), so a screen-context
/// capture of this form never carries the value being typed.</p>
Class OcuPilot.Screen.Descriptor.UserForm Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "permissions/users/edit",
  "area": "permissions",
  "labelKey": "processColumnUser",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "user",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": ["Password"]},
  "secretArguments": [],
  "fingerprintExcludes": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "userPromptGroupSignIn", "textKey": "userPromptSignIn"},
    {"groupKey": "userPromptGroupAccess", "textKey": "userPromptPrivilege"},
    {"groupKey": "userPromptGroupAccess", "textKey": "userPromptTwoFactor"}
  ],
  "classicPage": "%CSP.UI.Portal.User",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "permissions.userform"
}
}

}
