/// <p>SQL admin privileges: one user's or role's SQL administrative privileges (<code>%CREATE_TABLE</code> and the
/// other 30 the instance takes) in one namespace, read through the vendor's own
/// <code>Security.SQLPrivilege.Admin</code> <code>LIST</code> (AD-2, AD-36) and rendered by the
/// <code>list (server criteria)</code> archetype's page from the declared <code>table</code> (AD-5). The user
/// editor's and the role editor's SQL privileges tabs (their Admin privileges section) and
/// <code>permissions.sqladminprivileges.read</code> share this one declared read (Story 18.28).</p>
/// <p><b>It is a sub-resource of the two editors and never listed</b> (<code>sideBarPosition</code> 0), and has no
/// entity type or write path of its own: the grants and revokes are the Users and Roles lists' <code>grant-sql</code>
/// and <code>revoke-sql</code> row actions, with the type <code>ADMIN</code>.</p>
/// <p><b>Two criteria, both required by the port</b>: <code>grantee</code> and <code>namespace</code>; the guard
/// (<method>OcuPilot.Port.AdminPort.SqlPrivilegeGuard</method>) refuses what it refuses for the object read.</p>
/// <p><b>Three fields</b>: <code>Privilege</code>, <code>GrantOption</code> and <code>GrantedVia</code>, which is
/// <code>Direct</code>, <code>Role - &lt;name&gt;</code> or <code>SuperUser</code>. Its id is <code>composite</code>
/// over the two that tell rows apart. Only a <code>Direct</code> row offers a revoke on the tab.</p>
/// <p><b>The privilege set is Permissions' own</b>, as <class>OcuPilot.Screen.Descriptor.SqlPrivilegeList</class>
/// declares it. The classic page is the user editor's, where admin privileges are set.</p>
Class OcuPilot.Screen.Descriptor.SqlAdminPrivilegeList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "permissions/sql-admin-privileges",
  "area": "permissions",
  "labelKey": "sqlAdminPrivilegesLabel",
  "sideBarPosition": 0,
  "archetype": "list (server criteria)",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Privilege", "GrantedVia"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Privilege", "GrantOption", "GrantedVia"], "secretFields": []},
  "emptyStateKey": "sqlAdminPrivilegesEmpty",
  "commandAliases": ["sql admin privileges", "admin privileges"],
  "suggestedPrompts": [
    {"groupKey": "userPromptGroupAccess", "textKey": "sqlAdminPrivilegesPrompt1"},
    {"groupKey": "userPromptGroupAccess", "textKey": "sqlAdminPrivilegesPrompt2"},
    {"groupKey": "userPromptGroupAccess", "textKey": "sqlAdminPrivilegesPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.User",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Security.SQLPrivilege.Admin", "type": "LIST"},
    "fields": ["Privilege", "GrantOption", "GrantedVia"],
    "filter": ["Privilege", "GrantedVia"],
    "sort": {"fields": ["Privilege", "GrantedVia"], "default": "Privilege", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "grantee", "labelKey": "sqlPrivilegeCriterionGrantee", "kind": "text", "maxLength": 160, "hint": "One user or role, exactly as the Users or Roles list reports it. A list or a wildcard is refused."},
        {"param": "namespace", "labelKey": "headerNamespaceLabel", "kind": "text", "maxLength": 64, "hint": "One namespace this instance defines, exactly as its namespace list reports it."}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Privilege", "labelKey": "sqlPrivilegeColumnPrivilege", "kind": "name"},
      {"field": "GrantOption", "labelKey": "sqlPrivilegeColumnGrantOption", "kind": "text"},
      {"field": "GrantedVia", "labelKey": "sqlPrivilegeColumnGrantedVia", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "permissions.sqladminprivileges"
}
}

}
