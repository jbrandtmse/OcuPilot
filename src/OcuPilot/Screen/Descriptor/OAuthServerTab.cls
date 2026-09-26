/// <p>The OAuth 2.0 screen's Authorization server tab: this instance's one authorization server
/// configuration, read through the vendor's own <code>Security.OAuth2.Server</code> GET as the tab's
/// one row, and no row at all when the instance has none configured (AD-36).</p>
/// <p><b>It names individual members of the configuration's public discovery metadata</b>,
/// <code>Metadata.scopes_supported</code> and <code>Metadata.grant_types_supported</code>, never
/// <code>Metadata</code> itself. No server password, client secret or key material is declared
/// (AD-35).</p>
/// <p><b>The privilege set is <code>%Admin_OAuth2_Server:USE</code> and
/// <code>%DB_IRISSYS:READ</code></b> (AD-8).</p>
/// <p><b>Its name cell opens the classic authorization server editor in a new tab</b>, which takes no
/// parameter (AD-44).</p>
/// <p>It declares no primary or row action and does not refresh (AD-43).</p>
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
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["IssuerEndpoint", "Metadata.scopes_supported", "Metadata.grant_types_supported", "SigningAlgorithm", "EncryptionAlgorithm", "KeyAlgorithm", "ServerCredentials"], "secretFields": []},
  "emptyStateKey": "oauthServerEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "userPromptGroupSignIn", "textKey": "oAuthServerTabPrompt1"},
    {"groupKey": "userPromptGroupSignIn", "textKey": "oAuthServerTabPrompt2"},
    {"groupKey": "userPromptGroupSignIn", "textKey": "oAuthServerTabPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.OAuth2.Server.Configuration",
  "classicLinkExemption": {
    "exempt": true,
    "reason": "Edited in the classic portal until the OAuth 2.0 editors ship (Epic 12); counted against SM-C1",
    "label": "OAuth 2.0 Authorization Server Configuration",
    "href": "/csp/sys/sec/%25CSP.UI.Portal.OAuth2.Server.Configuration.zen",
    "rowLink": {"params": []}
  },
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
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "security/oauth", "position": 4, "labelKey": "oauthTabServer"},
  "toolIdentifier": "security.oauthserver"
}
}

}
