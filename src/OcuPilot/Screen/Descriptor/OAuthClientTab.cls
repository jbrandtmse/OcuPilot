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
/// <p><b>Its name cells open OcuPilot's own editor</b>,
/// <class>OcuPilot.Screen.Descriptor.OAuthClientForm</class>, at this tab's route with
/// <code>/edit</code> appended and the application name as the id (Story 12.5); it declares no
/// classic link-out. Its Create opens the same editor empty.</p>
/// <p><b>Its row actions are <code>delete</code>, <code>rotatekeys</code> and <code>register</code></b>,
/// carried out by <class>OcuPilot.Screen.Tool.OAuthClientDelete</class>,
/// <class>OcuPilot.Screen.Tool.OAuthClientRotateKeys</class> and
/// <class>OcuPilot.Screen.Tool.OAuthClientRegister</class> (AD-51, AD-53). Its three declared secrets
/// are written only by <class>OcuPilot.Screen.Tool.OAuthClientSetSecrets</class> (AD-56). It does not
/// refresh (AD-43).</p>
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
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [{"id": "delete", "selfProtection": ""}, {"id": "rotatekeys", "selfProtection": ""}, {"id": "register", "selfProtection": ""}],
  "context": {"fields": ["ApplicationName", "ClientType", "DefaultScope", "ServerDefinitionID", "IssuerEndpoint"], "secretFields": []},
  "secretArguments": ["ClientSecret", "ClientPassword", "RegistrationAccessToken"],
  "emptyStateKey": "oauthClientsEmpty",
  "commandAliases": [],
  "classicPage": "%CSP.UI.Portal.OAuth2.Client.ConfigurationList",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
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
