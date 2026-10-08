/// <p>SQL column privileges: one user's or role's privileges on the columns of one table or view in one namespace,
/// read through the vendor's own <code>Security.SQLPrivilege.Column</code> <code>LIST</code> (AD-2, AD-36) and
/// rendered by the <code>list (server criteria)</code> archetype's page from the declared <code>table</code> (AD-5).
/// The user editor's and the role editor's SQL privileges tabs (their Columns section) and
/// <code>permissions.sqlcolumnprivileges.read</code> share this one declared read (Story 18.28).</p>
/// <p><b>It is a sub-resource of the two editors and never listed</b> (<code>sideBarPosition</code> 0), and has no
/// entity type or write path of its own: the grants and revokes are the Users and Roles lists' <code>grant-sql</code>
/// and <code>revoke-sql</code> row actions, with a <code>Column</code>.</p>
/// <p><b>Three criteria, all required by the port</b>: <code>grantee</code>, <code>namespace</code> and
/// <code>object</code>, one table or view as <code>schema.name</code>. The vendor matches the object's letter case
/// exactly, so another case lists no rows, and answers one part with an invalid object reference; the guard
/// (<method>OcuPilot.Port.AdminPort.SqlPrivilegeGuard</method>) refuses an object that is not two name parts. The
/// read sends the fixed <code>includeSystem</code> 1, because it reads one object.</p>
/// <p><b>Five fields</b>: <code>Column</code>, <code>Action</code>, <code>GrantedBy</code>,
/// <code>GrantOption</code> and <code>GrantedVia</code>, which is <code>Direct</code> or <code>Role - &lt;name&gt;</code>.
/// Its id is <code>composite</code> over the four that tell rows apart. Only a <code>Direct</code> row offers a
/// revoke on the tab.</p>
/// <p><b>The privilege set is Permissions' own</b>, as <class>OcuPilot.Screen.Descriptor.SqlPrivilegeList</class>
/// declares it; the port adds the READ pair on the namespace's databases and names it when the caller lacks it
/// (AD-8). The classic page is the column dialog.</p>
Class OcuPilot.Screen.Descriptor.SqlColumnPrivilegeList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "permissions/sql-column-privileges",
  "area": "permissions",
  "labelKey": "sqlColumnPrivilegesLabel",
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
  "id": {"kind": "composite", "parts": ["Column", "Action", "GrantedVia", "GrantedBy"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Column", "Action", "GrantedBy", "GrantOption", "GrantedVia"], "secretFields": []},
  "emptyStateKey": "sqlColumnPrivilegesEmpty",
  "commandAliases": ["sql column privileges", "column privileges"],
  "suggestedPrompts": [
    {"groupKey": "userPromptGroupAccess", "textKey": "sqlColumnPrivilegesPrompt1"},
    {"groupKey": "userPromptGroupAccess", "textKey": "sqlColumnPrivilegesPrompt2"},
    {"groupKey": "userPromptGroupAccess", "textKey": "sqlColumnPrivilegesPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.Dialog.ColumnPriv",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Security.SQLPrivilege.Column", "type": "LIST", "query": {"includeSystem": "1"}},
    "fields": ["Column", "Action", "GrantedBy", "GrantOption", "GrantedVia"],
    "filter": ["Column", "Action", "GrantedBy", "GrantedVia"],
    "sort": {"fields": ["Column", "Action", "GrantedBy", "GrantedVia"], "default": "Column", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "grantee", "labelKey": "sqlPrivilegeCriterionGrantee", "kind": "text", "maxLength": 160, "hint": "One user or role, exactly as the Users or Roles list reports it. A list or a wildcard is refused."},
        {"param": "namespace", "labelKey": "headerNamespaceLabel", "kind": "text", "maxLength": 64, "hint": "One namespace this instance defines, exactly as its namespace list reports it."},
        {"param": "object", "labelKey": "sqlPrivilegeColumnObject", "kind": "text", "maxLength": 257, "hint": "One table or view as schema.name, spelled exactly as the SQL privileges read lists it. Another letter case lists no rows."}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Column", "labelKey": "explorerSqlColumnNumber", "kind": "name"},
      {"field": "Action", "labelKey": "sqlPrivilegeColumnAction", "kind": "text"},
      {"field": "GrantedBy", "labelKey": "sqlPrivilegeColumnGrantedBy", "kind": "text"},
      {"field": "GrantOption", "labelKey": "sqlPrivilegeColumnGrantOption", "kind": "text"},
      {"field": "GrantedVia", "labelKey": "sqlPrivilegeColumnGrantedVia", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "permissions.sqlcolumnprivileges"
}
}

}
