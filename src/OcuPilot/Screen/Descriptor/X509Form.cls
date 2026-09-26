/// <p>The X.509 credential form: one credential, imported or edited here, rendered by the
/// <code>form-page</code> archetype (AD-5). Its Save and the agent's confirmed
/// <code>security.x509.import</code> and <code>security.x509.update</code> are two callers of one
/// tool each (AD-55).</p>
/// <p><b>It is built and routable, and it takes no side-bar position</b> (<code>sideBarPosition</code>
/// 0): it is reached from <class>OcuPilot.Screen.Descriptor.X509CredentialList</class>'s Create and
/// from a row's name cell, at that list's own route with <code>/edit</code> appended, with the alias
/// as its one id segment when it edits.</p>
/// <p><b>It declares no <code>read</code> and no <code>table</code></b> (AD-36): its form read
/// answers the credential it edits, and the list is where the declared read lives.</p>
/// <p><b>Its privilege set is the list's own</b> -- <code>%Admin_Secure:USE</code> plus
/// <code>%DB_IRISSYS:READ</code> -- because the form writes the endpoint the list reads (AD-8).</p>
/// <p><b>Its classic equivalent is <code>%CSP.UI.Portal.X509Credential</code></b>, in the class's
/// own case (AD-44). It declares no exemption and does not refresh (AD-43).</p>
/// <p><b>The certificate, the private key and its password are secret-typed in its context</b>
/// (AD-24, AD-35), so a screen-context capture of this form never carries a value being typed.</p>
Class OcuPilot.Screen.Descriptor.X509Form Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/x509/edit",
  "area": "security",
  "labelKey": "x509FormLabel",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "x509-credential",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": ["Certificate", "PrivateKey", "PrivateKeyPassword"]},
  "secretArguments": [],
  "fingerprintExcludes": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "sslPromptGroupConnections", "textKey": "x509FormPrompt1"},
    {"groupKey": "sslPromptGroupConnections", "textKey": "x509FormPrompt2"},
    {"groupKey": "sslPromptGroupConnections", "textKey": "x509FormPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.X509Credential",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "security.x509form"
}
}

}
