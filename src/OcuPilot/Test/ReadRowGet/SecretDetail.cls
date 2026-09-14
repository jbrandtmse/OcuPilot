/// <p>Fixture descriptor whose detail call names a secret context field (AD-24, AD-36):
/// <code>Comment</code> is both a <code>read.source.rowGet</code> field and a
/// <code>context.secretFields</code> entry, so the executor must drop it from the merged row. Its rows
/// and details come from <class>OcuPilot.Test.EndpointFixture</class>'s <code>list</code> mode.</p>
/// <p>It lives in a package of its own so no fixture registry enumerates it.</p>
Class OcuPilot.Test.ReadRowGet.SecretDetail Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "permissions/rowget-secret",
  "area": "permissions",
  "labelKey": "userListLabel",
  "sideBarPosition": 2,
  "archetype": "list",
  "built": false,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}],
  "entityType": "user",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Name", "Roles", "Comment"], "secretFields": ["Comment"]},
  "emptyStateKey": "userListEmpty",
  "commandAliases": [],
  "classicPage": "OcuPilotTestClassicPageRowGetSecret",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {
      "port": "admin",
      "endpoint": "Security.User",
      "type": "LIST",
      "rowGet": {"key": "Name", "param": "name", "fields": ["Roles", "Comment"], "derived": []}
    },
    "fields": ["Name", "Roles", "Comment"],
    "filter": ["Name", "Roles"],
    "sort": {"fields": ["Name", "Roles"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [{"field": "Name", "labelKey": "tableColumnName", "kind": "name"}, {"field": "Roles", "labelKey": "userColumnRoles", "kind": "identifier"}],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "permissions.rowgetsecret"
}
}

}
