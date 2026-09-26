/// <p>The OAuth 2.0 screen's Client configurations tab: every client configuration on this instance,
/// with the server description it is configured against (AD-5, AD-36).</p>
/// <p><b>It is a per-parent read.</b> The vendor's <code>Security.OAuth2.Client.ClientConfiguration</code>
/// LIST answers one server description's clients and requires <code>serverId</code>, so
/// <code>read.source.forEach</code> lists <code>Security.OAuth2.Client.ServerDefinition</code> first
/// and then each description's clients, copying its <code>ID</code> and <code>IssuerEndpoint</code>
/// into each row. The cap bounds the rows held and the parents listed.</p>
/// <p><b>It declares <code>oauth2-server-definition</code> as a secondary type</b>, because each row
/// shows its description's issuer (AD-14).</p>
/// <p><b>Nothing secret is read.</b> The LIST row carries no client secret; the endpoint's GET, which
/// carries the client's unmasked <code>Metadata</code>, is never issued (AD-35).</p>
/// <p><b>The privilege set is <code>%Admin_OAuth2_Client:USE</code> and
/// <code>%DB_IRISSYS:READ</code></b> (AD-8).</p>
/// <p><b>Its name cells open the classic client configuration editor in a new tab</b> (AD-44), with
/// <code>PID</code>, <code>IssuerEndpointID</code> and <code>IssuerEndpoint</code> as the classic list
/// sends them. The editor treats an empty <code>IssuerEndpointID</code> as a new server description,
/// so a row whose description id reads empty renders its name as text.</p>
/// <p><b>Its one row action is <code>delete</code></b>, carried out by
/// <class>OcuPilot.Screen.Tool.OAuthClientDelete</class> (AD-51, AD-53). It declares no primary action
/// and does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.OAuthClientTab Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/oauth/clients",
  "area": "security",
  "labelKey": "oauthTabClients",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_OAuth2_Client", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "oauth2-client-configuration",
  "secondaryEntityTypes": ["oauth2-server-definition"],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "delete", "selfProtection": ""}],
  "context": {"fields": ["ApplicationName", "ClientType", "DefaultScope", "ServerDefinitionID", "IssuerEndpoint"], "secretFields": []},
  "emptyStateKey": "oauthClientsEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "userPromptGroupSignIn", "textKey": "oAuthClientTabPrompt1"},
    {"groupKey": "userPromptGroupSignIn", "textKey": "oAuthClientTabPrompt2"},
    {"groupKey": "userPromptGroupSignIn", "textKey": "oAuthClientTabPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.OAuth2.Client.ConfigurationList",
  "classicLinkExemption": {
    "exempt": true,
    "reason": "Edited in the classic portal until the OAuth 2.0 editors ship (Epic 12); counted against SM-C1",
    "label": "OAuth 2.0 Client Configuration",
    "href": "/csp/sys/sec/%25CSP.UI.Portal.OAuth2.Client.Configuration.zen",
    "rowLink": {"params": [{"name": "PID", "field": "ApplicationName"}, {"name": "IssuerEndpointID", "field": "ServerDefinitionID"}, {"name": "IssuerEndpoint", "field": "IssuerEndpoint"}]}
  },
  "read": {
    "source": {
      "port": "admin",
      "endpoint": "Security.OAuth2.Client.ClientConfiguration",
      "type": "LIST",
      "forEach": {
        "endpoint": "Security.OAuth2.Client.ServerDefinition",
        "key": "ID",
        "param": "serverId",
        "fields": [{"field": "ServerDefinitionID", "from": "ID"}, {"field": "IssuerEndpoint", "from": "IssuerEndpoint"}]
      }
    },
    "fields": ["ApplicationName", "ClientType", "DefaultScope", "ServerDefinitionID", "IssuerEndpoint"],
    "filter": ["ApplicationName", "IssuerEndpoint", "ClientType", "DefaultScope"],
    "sort": {"fields": ["ApplicationName", "IssuerEndpoint", "ClientType", "DefaultScope"], "default": "ApplicationName", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "ApplicationName", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "IssuerEndpoint", "labelKey": "x509ColumnIssuer", "kind": "text"},
      {"field": "ClientType", "labelKey": "oauthColumnClientType", "kind": "text"},
      {"field": "DefaultScope", "labelKey": "oauthColumnDefaultScope", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "oauthClientsEmptyAgent"
  },
  "tab": {"group": "security/oauth", "position": 2, "labelKey": "oauthTabClients"},
  "toolIdentifier": "security.oauthclients"
}
}

}
