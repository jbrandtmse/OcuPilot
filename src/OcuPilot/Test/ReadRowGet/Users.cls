/// <p>Fixture descriptor declaring the users list's read shape (AD-36): a LIST whose rows are
/// completed by one detail call each, merging <code>Roles</code> and <code>ExpirationDate</code> and
/// deriving <code>Expired</code>. Its rows and details come from
/// <class>OcuPilot.Test.EndpointFixture</class>'s <code>list</code> mode, reached through
/// <class>OcuPilot.Test.Read.ReadFixture</class> and <class>OcuPilot.Test.PortFixture</class>.</p>
/// <p>It lives in a package of its own so no fixture registry enumerates it.</p>
Class OcuPilot.Test.ReadRowGet.Users Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "permissions/rowget-users",
  "area": "permissions",
  "labelKey": "userListLabel",
  "sideBarPosition": 1,
  "archetype": "list",
  "built": false,
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
  "context": {"fields": ["Name", "FullName", "Enabled", "Roles", "ExpirationDate", "Expired"], "secretFields": []},
  "emptyStateKey": "userListEmpty",
  "commandAliases": [],
  "classicPage": "OcuPilotTestClassicPageRowGetUsers",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {
      "port": "admin",
      "endpoint": "Security.User",
      "type": "LIST",
      "rowGet": {"key": "Name", "param": "name", "fields": ["Roles", "ExpirationDate"], "derived": [{"field": "Expired", "rule": "beforeToday", "from": "ExpirationDate"}]}
    },
    "fields": ["Name", "FullName", "Enabled", "Roles", "ExpirationDate", "Expired"],
    "filter": ["Name", "FullName", "Roles"],
    "sort": {"fields": ["Name", "FullName", "Roles"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [{"field": "Name", "labelKey": "tableColumnName", "kind": "name"}, {"field": "Enabled", "labelKey": "tableColumnEnabled", "kind": "status"}, {"field": "Expired", "labelKey": "userColumnExpired", "kind": "text"}, {"field": "Roles", "labelKey": "userColumnRoles", "kind": "identifier"}],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "permissions.rowgetusers"
}
}

}
