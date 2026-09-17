/// <p>Fixture descriptor declaring a per-parent read (AD-36): <code>Test.Parents</code> listed first,
/// then <code>Test.Children</code> once per parent with <code>parentKey</code> set to the parent's
/// <code>ID</code>, each row taking its parent's <code>ID</code> and <code>IssuerEndpoint</code>. Its
/// answers come from <class>OcuPilot.Test.ReadSource.Endpoint</class>.</p>
/// <p>It lives in a package of its own so no fixture registry enumerates it.</p>
Class OcuPilot.Test.ReadSource.Children Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/readsource-children",
  "area": "security",
  "labelKey": "oauthTabClients",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": false,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_OAuth2_Client", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "oauth2-client-configuration",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Name", "ParentID", "Issuer"], "secretFields": []},
  "emptyStateKey": "oauthClientsEmpty",
  "commandAliases": [],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {
      "port": "admin",
      "endpoint": "Test.Children",
      "type": "LIST",
      "query": {"fixed": "1"},
      "forEach": {
        "endpoint": "Test.Parents",
        "key": "ID",
        "param": "parentKey",
        "fields": [{"field": "ParentID", "from": "ID"}, {"field": "Issuer", "from": "IssuerEndpoint"}]
      }
    },
    "fields": ["Name", "ParentID", "Issuer"],
    "filter": ["Name"],
    "sort": {"fields": ["Name"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [{"field": "Name", "labelKey": "tableColumnName", "kind": "name"}, {"field": "Issuer", "labelKey": "x509ColumnIssuer", "kind": "text"}],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "security.readsourcechildren"
}
}

}
