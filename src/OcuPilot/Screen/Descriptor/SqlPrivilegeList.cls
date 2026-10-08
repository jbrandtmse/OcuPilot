/// <p>SQL privileges: one user's or role's privileges on tables, views, stored procedures, schemas, ML
/// configurations and foreign servers in one namespace, read through the vendor's own
/// <code>Security.SQLPrivilege.Standard</code> <code>LIST</code> (AD-2, AD-36) and rendered by the
/// <code>list (server criteria)</code> archetype's page from the declared <code>table</code> (AD-5). The user
/// editor's and the role editor's SQL privileges tabs and <code>permissions.sqlprivileges.read</code> share this one
/// declared read (Story 18.9).</p>
/// <p><b>It is a sub-resource of the two editors and never listed</b> (<code>sideBarPosition</code> 0). Its scope is
/// <code>instance</code>, because a principal's SQL privileges are one set reached per namespace
/// (AD-13); it declares no entity type of its own, since its rows are not a value the closed vocabulary needs a
/// key for and it has no write path of its own -- the grants and revokes are the Users and Roles lists' row
/// actions.</p>
/// <p><b>Two criteria, both required by the port</b>: <code>grantee</code>, a user or a role, and
/// <code>namespace</code>. The port refuses a missing or undefined namespace, a missing grantee, a namespace whose
/// databases the caller cannot read and a list or wildcard before the vendor is reached
/// (<method>OcuPilot.Port.AdminPort.SqlPrivilegeGuard</method>). The read sends the fixed
/// <code>includeSystem</code> 0, the classic page's default; the grant and revoke tools still reach system
/// schemas.</p>
/// <p><b>Six fields</b>, the vendor's row without its column-privilege flag (Story 18.28): <code>Type</code>,
/// <code>Object</code>, <code>Action</code>, <code>GrantedBy</code>, <code>GrantOption</code> and
/// <code>GrantedVia</code>, which is <code>Direct</code>, <code>Role:&lt;name&gt;</code>,
/// <code>Schema Privilege</code> or <code>Owner Privilege</code>. A privilege held directly and through a role
/// lists twice. Its id is <code>composite</code> over the five that tell such rows apart. Only a
/// <code>Direct</code> row offers a revoke on the tab.</p>
/// <p><b>The privilege set is Permissions' own</b>, <code>%Admin_Secure:USE</code> and
/// <code>%DB_IRISSYS:READ</code>, declared the way the Users list declares it; the port adds the READ pair on the
/// namespace's databases and names it when the caller lacks it (AD-8). The classic key is the user page's.</p>
Class OcuPilot.Screen.Descriptor.SqlPrivilegeList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "permissions/sql-privileges",
  "area": "permissions",
  "labelKey": "sqlPrivilegesLabel",
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
  "id": {"kind": "composite", "parts": ["Type", "Object", "Action", "GrantedVia", "GrantedBy"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Type", "Object", "Action", "GrantedBy", "GrantOption", "GrantedVia"], "secretFields": []},
  "emptyStateKey": "sqlPrivilegesEmpty",
  "commandAliases": ["sql privileges", "table privileges"],
  "suggestedPrompts": [
    {"groupKey": "userPromptGroupAccess", "textKey": "sqlPrivilegesPrompt1"},
    {"groupKey": "userPromptGroupAccess", "textKey": "sqlPrivilegesPrompt2"},
    {"groupKey": "userPromptGroupAccess", "textKey": "sqlPrivilegesPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.User",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Security.SQLPrivilege.Standard", "type": "LIST", "query": {"includeSystem": "0"}},
    "fields": ["Type", "Object", "Action", "GrantedBy", "GrantOption", "GrantedVia"],
    "filter": ["Type", "Object", "Action", "GrantedBy", "GrantedVia"],
    "sort": {"fields": ["Object", "Type", "Action", "GrantedBy", "GrantedVia"], "default": "Object", "direction": "asc"},
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
      {"field": "Object", "labelKey": "sqlPrivilegeColumnObject", "kind": "name"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "Action", "labelKey": "sqlPrivilegeColumnAction", "kind": "text"},
      {"field": "GrantedBy", "labelKey": "sqlPrivilegeColumnGrantedBy", "kind": "text"},
      {"field": "GrantOption", "labelKey": "sqlPrivilegeColumnGrantOption", "kind": "text"},
      {"field": "GrantedVia", "labelKey": "sqlPrivilegeColumnGrantedVia", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "permissions.sqlprivileges"
}
}

}
