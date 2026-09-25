/// <p>Fixture descriptor: the first tab of a group whose only other member,
/// <class>OcuPilot.Test.TabGroup.Third</class>, declares position 3, so the positions leave a gap
/// and <method>OcuPilot.Screen.Registry.Validate</method> refuses the roster through the group rule
/// alone. Each member's own <code>tab</code> is sound.</p>
Class OcuPilot.Test.TabGroup.First Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/tab-group",
  "area": "security",
  "labelKey": "oauthTabResourceServers",
  "sideBarPosition": 6,
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
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
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
  "tab": {"group": "security/tab-group", "position": 1, "labelKey": "oauthTabServerDescriptions"},
  "toolIdentifier": "security.tabgroupfirst"
}
}

}
