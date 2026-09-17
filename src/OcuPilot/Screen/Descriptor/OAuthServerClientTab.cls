/// <p>The OAuth 2.0 screen's Server client descriptions tab: every client registered with this
/// instance's authorization server, read through the vendor's own
/// <code>Security.OAuth2.ServerClients</code> LIST (AD-2, AD-36).</p>
/// <p><b>Its five read fields are the LIST row's whole key set</b>, <code>RedirectURL</code> an array.
/// The row carries no client secret; the endpoint's GET, which carries the unmasked
/// <code>Metadata</code>, is never issued (AD-35).</p>
/// <p><b>It declares <code>oauth2-server</code> as a secondary type</b>: deleting the authorization
/// server configuration deletes every server client (AD-14).</p>
/// <p><b>The privilege set is <code>%Admin_OAuth2_Registration:USE</code> and
/// <code>%DB_IRISSYS:READ</code></b> (AD-8).</p>
/// <p><b>Its name cells open the classic server client editor in a new tab</b>, sending the client id
/// as <code>ClientId</code> (AD-44).</p>
/// <p>It declares no primary or row action and does not refresh (AD-43).</p>
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
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Name", "ClientId", "ClientType", "RedirectURL", "Description"], "secretFields": []},
  "emptyStateKey": "oauthServerClientsEmpty",
  "commandAliases": [],
  "classicPage": "%CSP.UI.Portal.OAuth2.Server.ClientList",
  "classicLinkExemption": {
    "exempt": true,
    "reason": "Edited in the classic portal until the OAuth 2.0 editors ship (Epic 12); counted against SM-C1",
    "label": "OAuth 2.0 Authorization Server Client Configuration",
    "href": "/csp/sys/sec/%25CSP.UI.Portal.OAuth2.Server.Client.zen",
    "rowLink": {"params": [{"name": "ClientId", "field": "ClientId"}]}
  },
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
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "security/oauth", "position": 5, "labelKey": "oauthTabServerClients"},
  "toolIdentifier": "security.oauthserverclients"
}
}

}
