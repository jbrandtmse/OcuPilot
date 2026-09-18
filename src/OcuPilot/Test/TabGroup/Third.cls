/// <p>Fixture descriptor: tab 3 of <class>OcuPilot.Test.TabGroup.First</class>'s group, which holds no
/// tab 2.</p>
Class OcuPilot.Test.TabGroup.Third Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/tab-group/third",
  "area": "security",
  "labelKey": "oauthTabResourceServers",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "oauth2-resource-server",
  "secondaryEntityTypes": ["oauth2-server-definition"],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Name", "ServerDefinition"], "secretFields": []},
  "emptyStateKey": "oauthResourceServersEmpty",
  "commandAliases": [],
  "classicPage": "%CSP.UI.Portal.OAuth2.ResourceServer.ConfigurationList",
  "classicLinkExemption": {
    "exempt": true,
    "reason": "Edited in the classic portal until the OAuth 2.0 editors ship (Epic 12); counted against SM-C1",
    "label": "OAuth 2.0 Resource Server Configuration",
    "href": "/csp/sys/sec/%25CSP.UI.Portal.OAuth2.ResourceServer.Configuration.zen",
    "rowLink": {"params": [{"name": "PID", "field": "Name"}]}
  },
  "read": {
    "source": {"port": "admin", "endpoint": "Security.OAuth2.ResourceServer", "type": "LIST"},
    "fields": ["Name", "ServerDefinition"],
    "filter": ["Name", "ServerDefinition"],
    "sort": {"fields": ["Name", "ServerDefinition"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "ServerDefinition", "labelKey": "x509ColumnIssuer", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "security/tab-group", "position": 3, "labelKey": "oauthTabResourceServers"},
  "toolIdentifier": "security.tabgroupthird"
}
}

}
