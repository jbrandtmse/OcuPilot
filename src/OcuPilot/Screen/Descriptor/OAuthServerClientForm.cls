/// <p>The OAuth 2.0 server client description editor: one client registered with this instance's
/// authorization server, registered or edited here, rendered by the <code>form-page</code> archetype
/// over four tabs (AD-5). Its Save and the agent's confirmed
/// <code>security.oauthserverclients.create</code>, <code>.update</code> and <code>.setsecret</code>
/// are two callers of one tool each (AD-55); its Update JWKS and Delete are the tab's own operations
/// (AD-53).</p>
/// <p><b>It is built and routable, and it takes no side-bar position</b> (<code>sideBarPosition</code>
/// 0): it is reached from <class>OcuPilot.Screen.Descriptor.OAuthServerClientTab</class>'s Create and
/// from a row's name cell, at that tab's route with <code>/edit</code> appended and the client id as
/// the id segment.</p>
/// <p><b>It declares no <code>read</code> and no <code>table</code></b> (AD-36): its form read answers
/// the client it edits.</p>
/// <p><b>Its privilege set is the tab's own</b> -- <code>%Admin_OAuth2_Registration:USE</code> and
/// <code>%DB_IRISSYS:READ</code> (AD-8, AD-29).</p>
/// <p><b>Its client secret is secret-typed in its context</b> (AD-24, AD-35), so no screen-context
/// capture carries a value being typed. The confirm channel's declaration is the tab's, whose tool
/// writes it (AD-56).</p>
/// <p><b>Its classic equivalent is <code>%CSP.UI.Portal.OAuth2.Server.Client</code></b> (AD-44). It
/// declares no exemption and does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.OAuthServerClientForm Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/oauth/server-clients/edit",
  "area": "security",
  "labelKey": "oauthRegisteredClientTitle",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_OAuth2_Registration", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "oauth2-server-client",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": ["ClientSecret"]},
  "secretArguments": [],
  "fingerprintExcludes": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "userPromptGroupSignIn", "textKey": "oAuthServerClientFormPrompt1"},
    {"groupKey": "userPromptGroupSignIn", "textKey": "oAuthServerClientFormPrompt2"},
    {"groupKey": "userPromptGroupSignIn", "textKey": "oAuthServerClientFormPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.OAuth2.Server.Client",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "security.oauthserverclientform"
}
}

}
