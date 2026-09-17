/// <p>Fixture descriptor declaring a single-object read (AD-36): a <code>GET</code> of
/// <code>Test.Object</code> answered as one row, projecting the member field
/// <code>Metadata.scopes_supported</code>. Its answers come from
/// <class>OcuPilot.Test.ReadSource.Endpoint</class>.</p>
/// <p>It lives in a package of its own so no fixture registry enumerates it.</p>
Class OcuPilot.Test.ReadSource.Object Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/readsource-object",
  "area": "security",
  "labelKey": "oauthTabServer",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": false,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_OAuth2_Server", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "oauth2-server",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Name", "Metadata.scopes_supported", "Missing.member"], "secretFields": []},
  "emptyStateKey": "oauthServerEmpty",
  "commandAliases": [],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Test.Object", "type": "GET", "query": {"fixed": "1"}},
    "fields": ["Name", "Metadata.scopes_supported", "Missing.member"],
    "filter": ["Name"],
    "sort": {"fields": ["Name"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [{"field": "Name", "labelKey": "tableColumnName", "kind": "name"}, {"field": "Metadata.scopes_supported", "labelKey": "oauthColumnScopes", "kind": "text"}],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "security.readsourceobject"
}
}

}
