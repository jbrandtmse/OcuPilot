/// <p>The Roles list: every role on this instance, read through the vendor's own
/// <code>Security.Role</code> LIST (AD-2, AD-36) and rendered by the <code>list</code> archetype's
/// page from the declared <code>table</code> (AD-5).</p>
/// <p><b>Its scope is <code>instance</code>, and its rows are not filtered by namespace.</b> A role
/// is instance security configuration keyed by its name alone (AD-13).</p>
/// <p><b>Its id is <code>single</code>:</b> the role's name, one percent-encoded path segment, with
/// no second part.</p>
/// <p><b>The four read fields are the live LIST row's whole key set</b>, in the vendor's own order:
/// <code>Name</code>, <code>Description</code>, <code>CreatedBy</code> and
/// <code>EscalationOnly</code>, the last a boolean. It declares no <code>rowGet</code>, because every
/// field the screen shows is already on the LIST row.</p>
/// <p><b>The privilege set is <code>%Admin_Secure:USE</code> and <code>%DB_IRISSYS:READ</code></b>,
/// the Users list's set and order. The first is the vendor's <code>ResourcesOR()</code> and the
/// classic page's own resource; without the second the vendor endpoint fails inside
/// <code>%SYS</code> and the port answers 500 (AD-8).
/// <class>OcuPilot.Test.WireSecurityRead</class> reads the list as a principal holding exactly
/// these pairs and holds its rows to the test account's.</p>
/// <p><b>The classic page is <code>%CSP.UI.Portal.Roles</code></b>, in the class's own case
/// (AD-44). As a list archetype it links out to nothing. The context carries no secret field.</p>
/// <p>It declares a Create primary action, which opens <class>OcuPilot.Screen.Descriptor.RoleForm</class>,
/// so its empty state invites the agent rather than naming a next step. Its row actions (AD-53) are
/// Delete, drawn refused for a predefined role (<code>system-role</code>), and the four value actions
/// the role editor sends -- add and remove a granted role, set and remove a resource grant -- which
/// no menu draws. It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.RoleList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "permissions/roles",
  "area": "permissions",
  "labelKey": "userColumnRoles",
  "sideBarPosition": 2,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "role",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [
    {"id": "delete", "selfProtection": "system-role"},
    {"id": "add-granted-role", "selfProtection": ""},
    {"id": "remove-granted-role", "selfProtection": ""},
    {"id": "set-resource-grant", "selfProtection": ""},
    {"id": "remove-resource-grant", "selfProtection": ""}
  ],
  "context": {"fields": ["Name", "Description", "CreatedBy", "EscalationOnly"], "secretFields": []},
  "emptyStateKey": "roleListEmpty",
  "commandAliases": ["security roles"],
  "classicPage": "%CSP.UI.Portal.Roles",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Security.Role", "type": "LIST"},
    "fields": ["Name", "Description", "CreatedBy", "EscalationOnly"],
    "filter": ["Name", "Description", "CreatedBy"],
    "sort": {"fields": ["Name", "Description", "CreatedBy"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Description", "labelKey": "tableColumnDescription", "kind": "text"},
      {"field": "CreatedBy", "labelKey": "roleColumnCreatedBy", "kind": "text"},
      {"field": "EscalationOnly", "labelKey": "roleColumnEscalationOnly", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "roleListEmptyAgent"
  },
  "toolIdentifier": "permissions.roles"
}
}

}
