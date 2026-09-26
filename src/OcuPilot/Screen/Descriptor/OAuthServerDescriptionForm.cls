/// <p>The OAuth 2.0 server description editor: one description, created or edited here, rendered by
/// the <code>form-page</code> archetype (AD-5). Its Save and the agent's confirmed
/// <code>security.oauthserverdescriptions.create</code> and <code>.update</code> are two callers of
/// one tool each (AD-55); its Discover, Update JWKS and Delete are the tab's own operations.</p>
/// <p><b>It is built and routable, and it takes no side-bar position</b> (<code>sideBarPosition</code>
/// 0): it is reached from <class>OcuPilot.Screen.Descriptor.OAuthServerDescriptionTab</class>'s Create
/// and from a row's name cell, at that tab's route with <code>/edit</code> appended, with the issuer
/// as its one id segment when it edits.</p>
/// <p><b>It declares no <code>read</code> and no <code>table</code></b> (AD-36): its form read answers
/// the description it edits.</p>
/// <p><b>Its privilege set is the tab's own</b> -- <code>%Admin_OAuth2_Client:USE</code> plus
/// <code>%DB_IRISSYS:READ</code> (AD-8).</p>
/// <p><b>The registration access token is secret-typed in its context</b> (AD-24, AD-35), so no
/// screen-context capture carries a value being typed. The confirm channel's declaration is the
/// tab's, whose token tool writes it (AD-56).</p>
/// <p><b>Its classic equivalent is <code>%CSP.UI.Portal.OAuth2.Client.ServerConfiguration</code></b>
/// (AD-44). It declares no exemption and does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.OAuthServerDescriptionForm Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/oauth/edit",
  "area": "security",
  "labelKey": "oauthServerFormLabel",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_OAuth2_Client", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "oauth2-server-definition",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": ["InitialAccessToken"]},
  "secretArguments": [],
  "fingerprintExcludes": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "userPromptGroupSignIn", "textKey": "oAuthServerDescriptionFormPrompt1"},
    {"groupKey": "userPromptGroupSignIn", "textKey": "oAuthServerDescriptionFormPrompt2"},
    {"groupKey": "userPromptGroupSignIn", "textKey": "oAuthServerDescriptionFormPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.OAuth2.Client.ServerConfiguration",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "security.oauthserverdescriptionform"
}
}

}
