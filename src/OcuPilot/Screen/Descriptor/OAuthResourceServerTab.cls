/// <p>The OAuth 2.0 screen's Resource servers tab: every OAuth 2.0 resource server on this instance,
/// read through the vendor's own <code>Security.OAuth2.ResourceServer</code> LIST (AD-2, AD-36).</p>
/// <p><b>Its two read fields are the LIST row's whole key set</b>: <code>Name</code> and
/// <code>ServerDefinition</code>, the issuer URL of the server description it trusts, which is why it
/// declares <code>oauth2-server-definition</code> as a secondary type (AD-14). No client secret is on
/// the row (AD-35).</p>
/// <p><b>The privilege set is <code>%Admin_Secure:USE</code> and <code>%DB_IRISSYS:READ</code></b>:
/// the vendor gates this endpoint on the secure resource rather than an OAuth one (AD-8).</p>
/// <p><b>Its name cells open the classic resource server editor in a new tab</b>, sending the name as
/// <code>PID</code> (AD-44).</p>
/// <p>It declares no primary or row action and does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.OAuthResourceServerTab Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/oauth/resource-servers",
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
  "suggestedPrompts": [
    {"groupKey": "userPromptGroupSignIn", "textKey": "oAuthResourceServerTabPrompt1"},
    {"groupKey": "userPromptGroupSignIn", "textKey": "oAuthResourceServerTabPrompt2"},
    {"groupKey": "userPromptGroupSignIn", "textKey": "oAuthResourceServerTabPrompt3"}
  ],
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
  "tab": {"group": "security/oauth", "position": 3, "labelKey": "oauthTabResourceServers"},
  "toolIdentifier": "security.oauthresourceservers"
}
}

}
