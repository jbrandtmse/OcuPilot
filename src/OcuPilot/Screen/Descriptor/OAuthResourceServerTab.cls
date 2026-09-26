/// <p>The OAuth 2.0 screen's Resource servers tab: every OAuth 2.0 resource server on this instance,
/// read through the vendor's own <code>Security.OAuth2.ResourceServer</code> LIST (AD-2, AD-36).</p>
/// <p><b>Its two read fields are the LIST row's whole key set</b>: <code>Name</code> and
/// <code>ServerDefinition</code>, the issuer URL of the server description it trusts, which is why it
/// declares <code>oauth2-server-definition</code> as a secondary type (AD-14). No client secret is on
/// the row (AD-35).</p>
/// <p><b>The privilege set is <code>%Admin_Secure:USE</code>, <code>%DB_IRISSYS:READ</code> and
/// <code>%Admin_OAuth2_Client:USE</code></b>: the vendor gates this endpoint on the secure resource
/// (AD-8), and its resource server class opens the trusted server description through
/// <code>OAuth2.ServerDefinition.OpenByIssuer</code>, which checks the OAuth 2.0 client resource
/// (AD-29).</p>
/// <p><b>Its name cells open OcuPilot's own editor</b>,
/// <class>OcuPilot.Screen.Descriptor.OAuthResourceServerForm</class>, at this tab's route with
/// <code>/edit</code> appended and the name as the id (Story 12.6); it declares no classic link-out.
/// Its Create opens the same editor empty.</p>
/// <p><b>Its row action is <code>delete</code></b>, carried out by
/// <class>OcuPilot.Screen.Tool.OAuthResourceServerDelete</class> (AD-51, AD-53). Its declared secret
/// is written only by <class>OcuPilot.Screen.Tool.OAuthResourceServerSetSecret</class> (AD-56). It
/// does not refresh (AD-43).</p>
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
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}, {"resource": "%Admin_OAuth2_Client", "permission": "USE"}],
  "entityType": "oauth2-resource-server",
  "secondaryEntityTypes": ["oauth2-server-definition"],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [{"id": "delete", "selfProtection": ""}],
  "context": {"fields": ["Name", "ServerDefinition"], "secretFields": []},
  "secretArguments": ["ClientSecret"],
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
    "emptyNextKey": "",
    "emptyAgentKey": "oauthResourceServersEmptyAgent"
  },
  "tab": {"group": "security/oauth", "position": 3, "labelKey": "oauthTabResourceServers"},
  "toolIdentifier": "security.oauthresourceservers"
}
}

}
