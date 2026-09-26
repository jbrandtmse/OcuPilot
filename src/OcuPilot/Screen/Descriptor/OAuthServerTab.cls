/// <p>The OAuth 2.0 screen's Authorization server tab: this instance's one authorization server
/// configuration, read through the vendor's own <code>Security.OAuth2.Server</code> GET as the tab's
/// one row, and no row at all when the instance has none configured (AD-36).</p>
/// <p><b>It names individual members of the configuration's public discovery metadata</b>,
/// <code>Metadata.scopes_supported</code> and <code>Metadata.grant_types_supported</code>, never
/// <code>Metadata</code> itself. No server password, client secret or key material is among its fields
/// (AD-35).</p>
/// <p><b>The privilege set is <code>%Admin_OAuth2_Server:USE</code> and
/// <code>%DB_IRISSYS:READ</code></b> (AD-8).</p>
/// <p><b>Its name cell opens OcuPilot's own editor</b>,
/// <class>OcuPilot.Screen.Descriptor.OAuthServerForm</class>, at this tab's route with
/// <code>/edit</code> appended (Story 12.7); it declares no classic link-out. Its Create opens the same
/// editor, which opens the stored configuration when the instance has one.</p>
/// <p><b>Its row actions are <code>delete</code> and <code>rotatekeys</code></b>, carried out by
/// <class>OcuPilot.Screen.Tool.OAuthAuthorizationServerDelete</class> and
/// <class>OcuPilot.Screen.Tool.OAuthAuthorizationServerRotateKeys</class> (AD-51, AD-53). Its declared
/// secret is written only by <class>OcuPilot.Screen.Tool.OAuthAuthorizationServerSetPassword</class>
/// (AD-56). It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.OAuthServerTab Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/oauth/server",
  "area": "security",
  "labelKey": "oauthTabServer",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_OAuth2_Server", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "oauth2-server",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [{"id": "delete", "selfProtection": ""}, {"id": "rotatekeys", "selfProtection": ""}],
  "context": {"fields": ["IssuerEndpoint", "Metadata.scopes_supported", "Metadata.grant_types_supported", "SigningAlgorithm", "EncryptionAlgorithm", "KeyAlgorithm", "ServerCredentials"], "secretFields": []},
  "secretArguments": ["ServerPassword"],
  "emptyStateKey": "oauthServerEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "userPromptGroupSignIn", "textKey": "oAuthServerTabPrompt1"},
    {"groupKey": "userPromptGroupSignIn", "textKey": "oAuthServerTabPrompt2"},
    {"groupKey": "userPromptGroupSignIn", "textKey": "oAuthServerTabPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.OAuth2.Server.Configuration",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Security.OAuth2.Server", "type": "GET"},
    "fields": ["IssuerEndpoint", "Metadata.scopes_supported", "Metadata.grant_types_supported", "SigningAlgorithm", "EncryptionAlgorithm", "KeyAlgorithm", "ServerCredentials"],
    "filter": ["IssuerEndpoint", "Metadata.scopes_supported", "Metadata.grant_types_supported", "SigningAlgorithm", "EncryptionAlgorithm", "KeyAlgorithm", "ServerCredentials"],
    "sort": {"fields": ["IssuerEndpoint", "Metadata.scopes_supported", "Metadata.grant_types_supported", "SigningAlgorithm", "EncryptionAlgorithm", "KeyAlgorithm", "ServerCredentials"], "default": "IssuerEndpoint", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "IssuerEndpoint", "labelKey": "x509ColumnIssuer", "kind": "name"},
      {"field": "Metadata.scopes_supported", "labelKey": "oauthColumnScopes", "kind": "text"},
      {"field": "Metadata.grant_types_supported", "labelKey": "oauthColumnGrantTypes", "kind": "text"},
      {"field": "SigningAlgorithm", "labelKey": "oauthColumnSigningAlgorithm", "kind": "text"},
      {"field": "EncryptionAlgorithm", "labelKey": "oauthColumnEncryptionAlgorithm", "kind": "text"},
      {"field": "KeyAlgorithm", "labelKey": "oauthColumnKeyAlgorithm", "kind": "text"},
      {"field": "ServerCredentials", "labelKey": "oauthColumnServerCredentials", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "oauthAuthServerEmptyAgent"
  },
  "tab": {"group": "security/oauth", "position": 4, "labelKey": "oauthTabServer"},
  "toolIdentifier": "security.oauthserver"
}
}

}
