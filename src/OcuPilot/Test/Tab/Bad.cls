/// <p>Fixture descriptor whose <code>tab</code> is outside the grammar, so the registry's tab refusal
/// can be demonstrated over a roster: it is tab 2 of its group and still takes side-bar position 3.
/// Everything else is the Resource servers tab's sound declaration, so the refusal
/// <method>OcuPilot.Screen.Registry.Validate</method> reports is the tab's and nothing else's.</p>
/// <p>It lives in a package of its own, with <class>OcuPilot.Test.TabRegistry</class>, so no other
/// fixture's fault is reported first.</p>
Class OcuPilot.Test.Tab.Bad Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/tab-bad",
  "area": "security",
  "labelKey": "oauthTabResourceServers",
  "sideBarPosition": 3,
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
  "suggestedPrompts": [{"groupKey": "promptGroupTroubleshooting", "textKey": "homeStarterPromptExplainScreen"}, {"groupKey": "promptGroupTroubleshooting", "textKey": "homeStarterPromptExplainLog"}, {"groupKey": "promptGroupTroubleshooting", "textKey": "homeStarterPromptChangeOneThing"}],
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
  "tab": {"group": "security/tab-bad-group", "position": 2, "labelKey": "oauthTabResourceServers"},
  "toolIdentifier": "security.tabbad"
}
}

}
