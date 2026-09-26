/// <p>The OAuth 2.0 screen's first tab, Client server descriptions: every OAuth 2.0 server this
/// instance's clients are described against, read through the vendor's own
/// <code>Security.OAuth2.Client.ServerDefinition</code> LIST (AD-2, AD-36) and rendered by the
/// <code>detail</code> page over the declared <code>table</code> (AD-5).</p>
/// <p><b>It is the tab group's first member and its side-bar entry.</b> <code>tab.group</code> is its
/// own route; the other four tabs are unlisted routes under it, each a descriptor of its own.</p>
/// <p><b>It declares two secondary entity types</b>, <code>oauth2-client-configuration</code> and
/// <code>oauth2-resource-server</code>, because its rows count both, so a change to either re-reads
/// it (AD-14).</p>
/// <p><b>The four read fields are the LIST row's whole key set</b>; the row carries no secret, and
/// <code>context.secretFields</code> is empty (AD-35).</p>
/// <p><b>The privilege set is <code>%Admin_OAuth2_Client:USE</code> and <code>%DB_IRISSYS:READ</code></b>:
/// the vendor's <code>ResourcesOR()</code>, and the database the port runs every endpoint in (AD-8).</p>
/// <p><b>Its name cells open the classic server description editor in a new tab</b>, under the
/// Release 1 exemption the five OAuth 2.0 tabs declare together (AD-44): <code>rowLink</code> sends the
/// description's <code>ID</code> as <code>PID</code>, the parameter the classic list sends.</p>
/// <p>It declares no primary or row action, so its empty state names what to do next, and it does
/// not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.OAuthServerDescriptionTab Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/oauth",
  "area": "security",
  "labelKey": "oauthLabel",
  "sideBarPosition": 5,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_OAuth2_Client", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "oauth2-server-definition",
  "secondaryEntityTypes": ["oauth2-client-configuration", "oauth2-resource-server"],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["ID", "IssuerEndpoint", "ClientCount", "ResourceCount"], "secretFields": []},
  "emptyStateKey": "oauthServerDescriptionsEmpty",
  "commandAliases": ["oauth"],
  "suggestedPrompts": [
    {"groupKey": "userPromptGroupSignIn", "textKey": "oAuthServerDescriptionTabPrompt1"},
    {"groupKey": "userPromptGroupSignIn", "textKey": "oAuthServerDescriptionTabPrompt2"},
    {"groupKey": "userPromptGroupSignIn", "textKey": "oAuthServerDescriptionTabPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.OAuth2.Client.ServerList",
  "classicLinkExemption": {
    "exempt": true,
    "reason": "Edited in the classic portal until the OAuth 2.0 editors ship (Epic 12); counted against SM-C1",
    "label": "OAuth 2.0 Client Configuration",
    "href": "/csp/sys/sec/%25CSP.UI.Portal.OAuth2.Client.ServerConfiguration.zen",
    "rowLink": {"params": [{"name": "PID", "field": "ID"}]}
  },
  "read": {
    "source": {"port": "admin", "endpoint": "Security.OAuth2.Client.ServerDefinition", "type": "LIST"},
    "fields": ["ID", "IssuerEndpoint", "ClientCount", "ResourceCount"],
    "filter": ["IssuerEndpoint"],
    "sort": {"fields": ["IssuerEndpoint", "ClientCount", "ResourceCount"], "default": "IssuerEndpoint", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "IssuerEndpoint", "labelKey": "x509ColumnIssuer", "kind": "name"},
      {"field": "ClientCount", "labelKey": "oauthTabClients", "kind": "number"},
      {"field": "ResourceCount", "labelKey": "oauthTabResourceServers", "kind": "number"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "security/oauth", "position": 1, "labelKey": "oauthTabServerDescriptions"},
  "toolIdentifier": "security.oauthserverdescriptions"
}
}

}
