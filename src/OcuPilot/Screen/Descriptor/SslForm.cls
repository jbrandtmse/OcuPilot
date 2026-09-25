/// <p>The SSL/TLS configuration form: one configuration, created at its bare route and edited at its
/// id route on one tabbed page, rendered by the <code>form-page</code> archetype (AD-5). Its create
/// Save and the agent's confirmed <code>security.ssl.create</code> are two callers of one tool, and
/// so are its edit Save and <code>security.ssl.update</code> (AD-55).</p>
/// <p><b>It is built and routable, and it takes no side-bar position</b> (<code>sideBarPosition</code>
/// 0): it is reached from <class>OcuPilot.Screen.Descriptor.SslConfigList</class>'s Create and from a
/// row's name cell, at that list's own route with <code>/edit</code> appended, with the name as its
/// one id segment when it edits.</p>
/// <p><b>It declares no <code>read</code> and no <code>table</code></b> (AD-36): its form read
/// answers the configuration it edits, and the list is where the declared read lives.</p>
/// <p><b>Its privilege set is the list's own</b> -- <code>%Admin_Secure:USE</code> plus
/// <code>%DB_IRISSYS:READ</code> -- because the form writes the endpoint the list reads (AD-8); Test
/// connection is gated by the same pairs.</p>
/// <p><b>Its classic equivalent is <code>%CSP.UI.Portal.SSL</code></b>, in the class's own case
/// (AD-44). It declares no exemption and does not refresh (AD-43).</p>
/// <p><b>The private key password is secret-typed in its context</b> (AD-24, AD-35), so a
/// screen-context capture of this form never carries a value being typed. It declares three
/// suggested prompts (Story 11.3's contract).</p>
Class OcuPilot.Screen.Descriptor.SslForm Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/ssl/edit",
  "area": "security",
  "labelKey": "sslFormLabel",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "ssl-configuration",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": ["PrivateKeyPassword"]},
  "secretArguments": [],
  "fingerprintExcludes": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "sslPromptGroupConnections", "textKey": "sslPromptVerifies"},
    {"groupKey": "sslPromptGroupConnections", "textKey": "sslPromptProtocols"},
    {"groupKey": "sslPromptGroupConnections", "textKey": "sslPromptOutbound"}
  ],
  "classicPage": "%CSP.UI.Portal.SSL",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "security.sslform"
}
}

}
