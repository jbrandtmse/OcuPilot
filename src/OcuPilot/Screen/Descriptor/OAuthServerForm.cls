/// <p>The OAuth 2.0 authorization server editor: this instance's one authorization server
/// configuration, created or edited here, rendered by the <code>form-page</code> archetype over five
/// tabs (AD-5). Its Save and the agent's confirmed <code>security.oauthserver.create</code>,
/// <code>.update</code> and <code>.setpassword</code> are two callers of one tool each (AD-55); its
/// Rotate Keys and Delete are the tab's own operations (AD-53).</p>
/// <p><b>It is built and routable, and it takes no side-bar position</b> (<code>sideBarPosition</code>
/// 0): it is reached from <class>OcuPilot.Screen.Descriptor.OAuthServerTab</class>'s Create and from
/// its row's name cell, at that tab's route with <code>/edit</code> appended. The configuration is a
/// singleton, so whatever id segment the route carries, the editor opens the stored configuration,
/// or a new one when the instance has none.</p>
/// <p><b>It declares no <code>read</code> and no <code>table</code></b> (AD-36): its form read answers
/// the configuration it edits.</p>
/// <p><b>Its privilege set is the tab's own</b> -- <code>%Admin_OAuth2_Server:USE</code> and
/// <code>%DB_IRISSYS:READ</code> (AD-8, AD-29).</p>
/// <p><b>Its key password is secret-typed in its context</b> (AD-24, AD-35), so no screen-context
/// capture carries a value being typed. The confirm channel's declaration is the tab's, whose tool
/// writes it (AD-56).</p>
/// <p><b>Its classic equivalent is <code>%CSP.UI.Portal.OAuth2.Server.Configuration</code></b>
/// (AD-44). It declares no exemption and does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.OAuthServerForm Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/oauth/server/edit",
  "area": "security",
  "labelKey": "oauthTabServer",
  "sideBarPosition": 0,
  "archetype": "form-page",
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
  "context": {"fields": [], "secretFields": ["ServerPassword"]},
  "secretArguments": [],
  "fingerprintExcludes": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "classicPage": "%CSP.UI.Portal.OAuth2.Server.Configuration",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "security.oauthserverform"
}
}

}
