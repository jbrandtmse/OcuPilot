/// <p>The OAuth 2.0 resource server editor: one resource server, created or edited here, rendered by
/// the <code>form-page</code> archetype over four tabs (AD-5). Its Save and the agent's confirmed
/// <code>security.oauthresourceservers.create</code>, <code>.update</code>, <code>.setsecret</code>,
/// <code>.addmapping</code> and <code>.removemapping</code> are two callers of one tool each (AD-55);
/// its Delete is the tab's own operation (AD-53).</p>
/// <p><b>It is built and routable, and it takes no side-bar position</b> (<code>sideBarPosition</code>
/// 0): it is reached from <class>OcuPilot.Screen.Descriptor.OAuthResourceServerTab</class>'s Create
/// and from a row's name cell, at that tab's route with <code>/edit</code> appended, with the name as
/// its one id segment when it edits.</p>
/// <p><b>It declares no <code>read</code> and no <code>table</code></b> (AD-36): its form read answers
/// the server it edits.</p>
/// <p><b>Its privilege set is the tab's own</b> -- <code>%Admin_Secure:USE</code> plus
/// <code>%DB_IRISSYS:READ</code> (AD-8).</p>
/// <p><b>Its client secret is secret-typed in its context</b> (AD-24, AD-35), so no screen-context
/// capture carries a value being typed. The confirm channel's declaration is the tab's, whose tool
/// writes it (AD-56).</p>
/// <p><b>Its classic equivalent is <code>%CSP.UI.Portal.OAuth2.ResourceServer.Configuration</code></b>
/// (AD-44). It declares no exemption and does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.OAuthResourceServerForm Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/oauth/resource-servers/edit",
  "area": "security",
  "labelKey": "oauthClientTypeResource",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "oauth2-resource-server",
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
  "classicPage": "%CSP.UI.Portal.OAuth2.ResourceServer.Configuration",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "security.oauthresourceserverform"
}
}

}
