/// <p>The OAuth 2.0 client configuration editor: one client configuration, created or edited here,
/// rendered by the <code>form-page</code> archetype (AD-5). Its Save and the agent's confirmed
/// <code>security.oauthclients.create</code>, <code>.update</code> and <code>.setsecrets</code> are
/// two callers of one tool each (AD-55); its Register, Rotate Keys and Delete are the tab's own
/// operations (AD-53).</p>
/// <p><b>It is built and routable, and it takes no side-bar position</b> (<code>sideBarPosition</code>
/// 0): it is reached from <class>OcuPilot.Screen.Descriptor.OAuthClientTab</class>'s Create and from a
/// row's name cell, at that tab's route with <code>/edit</code> appended, with the application name as
/// its one id segment when it edits.</p>
/// <p><b>It declares no <code>read</code> and no <code>table</code></b> (AD-36): its form read answers
/// the configuration it edits.</p>
/// <p><b>Its privilege set is the tab's own</b> -- <code>%Admin_OAuth2_Client:USE</code> plus
/// <code>%DB_IRISSYS:READ</code> (AD-8).</p>
/// <p><b>Its four secrets are secret-typed in its context</b> (AD-24, AD-35), so no screen-context
/// capture carries a value being typed. The confirm channel's declaration is the tab's, whose tools
/// write them (AD-56).</p>
/// <p><b>Its classic equivalent is <code>%CSP.UI.Portal.OAuth2.Client.Configuration</code></b>
/// (AD-44). It declares no exemption and does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.OAuthClientForm Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/oauth/clients/edit",
  "area": "security",
  "labelKey": "oauthClientFormLabel",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_OAuth2_Client", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "oauth2-client-configuration",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": ["ClientSecret", "ClientPassword", "RegistrationAccessToken", "InitialAccessToken"]},
  "secretArguments": [],
  "fingerprintExcludes": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "userPromptGroupSignIn", "textKey": "oAuthClientFormPrompt1"},
    {"groupKey": "userPromptGroupSignIn", "textKey": "oAuthClientFormPrompt2"},
    {"groupKey": "userPromptGroupSignIn", "textKey": "oAuthClientFormPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.OAuth2.Client.Configuration",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "security.oauthclientform"
}
}

}
