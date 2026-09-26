/// <p>The OAuth 2.0 screen's Server client descriptions tab: every client registered with this
/// instance's authorization server, read through the vendor's own
/// <code>Security.OAuth2.ServerClients</code> LIST (AD-2, AD-36).</p>
/// <p><b>Its five read fields are the LIST row's whole key set</b>, <code>RedirectURL</code> an array.
/// The row carries no client secret, and this list issues no <code>GET</code>; the editor's reads go
/// through <class>OcuPilot.Port.OAuthRegisteredClientPort</class>, which strips the secret members
/// the vendor's <code>GET</code> answers (AD-35).</p>
/// <p><b>It declares <code>oauth2-server</code> as a secondary type</b>: deleting the authorization
/// server configuration deletes every server client (AD-14).</p>
/// <p><b>The privilege set is <code>%Admin_OAuth2_Registration:USE</code> and
/// <code>%DB_IRISSYS:READ</code></b> (AD-8).</p>
/// <p><b>Its name cell opens OcuPilot's own editor</b>,
/// <class>OcuPilot.Screen.Descriptor.OAuthServerClientForm</class>, at this tab's route with
/// <code>/edit</code> and the client id appended (Story 12.8); it declares no classic link-out. Its
/// Create opens the same editor with no id.</p>
/// <p><b>Rows are keyed by <code>ClientId</code></b>, the vendor's IdKey, declared as a one-part
/// composite id so the row key, the typed name and the target of a delete are the client id while the
/// Name column stays the name cell. <code>Name</code> is not unique on this build.</p>
/// <p><b>Its row actions are <code>delete</code> and <code>updatejwks</code></b>, carried out by
/// <class>OcuPilot.Screen.Tool.OAuthServerClientDelete</class> and
/// <class>OcuPilot.Screen.Tool.OAuthRegisteredClientUpdateJwks</class> (AD-51, AD-53). Its declared
/// secret is written only by <class>OcuPilot.Screen.Tool.OAuthRegisteredClientSetSecret</class>
/// (AD-56). It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.OAuthServerClientTab Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/oauth/server-clients",
  "area": "security",
  "labelKey": "oauthTabServerClients",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_OAuth2_Registration", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "oauth2-server-client",
  "secondaryEntityTypes": ["oauth2-server"],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["ClientId"]},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [{"id": "delete", "selfProtection": ""}, {"id": "updatejwks", "selfProtection": ""}],
  "context": {"fields": ["Name", "ClientId", "ClientType", "RedirectURL", "Description"], "secretFields": []},
  "secretArguments": ["ClientSecret"],
  "emptyStateKey": "oauthServerClientsEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "userPromptGroupSignIn", "textKey": "oAuthServerClientTabPrompt1"},
    {"groupKey": "userPromptGroupSignIn", "textKey": "oAuthServerClientTabPrompt2"},
    {"groupKey": "userPromptGroupSignIn", "textKey": "oAuthServerClientTabPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.OAuth2.Server.ClientList",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Security.OAuth2.ServerClients", "type": "LIST"},
    "fields": ["Name", "ClientId", "ClientType", "RedirectURL", "Description"],
    "filter": ["Name", "ClientId", "ClientType", "RedirectURL", "Description"],
    "sort": {"fields": ["Name", "ClientId", "ClientType", "RedirectURL", "Description"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "ClientId", "labelKey": "oauthColumnClientId", "kind": "identifier"},
      {"field": "ClientType", "labelKey": "oauthColumnClientType", "kind": "text"},
      {"field": "RedirectURL", "labelKey": "oauthColumnRedirectUrls", "kind": "text"},
      {"field": "Description", "labelKey": "tableColumnDescription", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "oauthServerClientsEmptyAgent"
  },
  "tab": {"group": "security/oauth", "position": 5, "labelKey": "oauthTabServerClients"},
  "toolIdentifier": "security.oauthserverclients"
}
}

}
