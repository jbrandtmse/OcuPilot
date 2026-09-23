/// <p>The wallet secret form: one key-value secret, created or edited here, rendered by the
/// <code>form-page</code> archetype (AD-5). Its Save and the agent's confirmed
/// <code>security.secrets.create</code> and <code>security.secrets.update</code> are two callers of
/// one tool each (AD-55).</p>
/// <p><b>It is built and routable, and it takes no side-bar position</b> (<code>sideBarPosition</code>
/// 0): it is reached from <class>OcuPilot.Screen.Descriptor.WalletSecretList</class>'s Create, with
/// the collection on screen as its <code>collection</code> query parameter, and from a row's name
/// cell, at that list's own route with <code>/edit</code> appended and the secret's full name as its
/// one id segment.</p>
/// <p><b>It declares no <code>read</code> and no <code>table</code></b> (AD-36): its form read
/// answers the secret it edits, and the list is where the declared read lives.</p>
/// <p><b>Its privilege set is the list's own</b> -- <code>%Admin_Wallet:USE</code> plus
/// <code>%DB_IRISSYS:READ</code> -- so a caller without the wallet resource meets the screen-wide
/// denial naming it, whichever route reached the form (AD-8).</p>
/// <p><b>No classic page exists</b> for the wallet, so <code>classicPage</code> is empty (AD-44). It
/// declares no exemption and does not refresh (AD-43).</p>
/// <p><b>The value is secret-typed in its context</b> (AD-24, AD-35), so a screen-context capture of
/// this form never carries a value being typed.</p>
Class OcuPilot.Screen.Descriptor.WalletSecretForm Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/wallet/secrets/edit",
  "area": "security",
  "labelKey": "walletSecretFormLabel",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Wallet", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "wallet-secret",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": ["Secret"]},
  "secretArguments": [],
  "fingerprintExcludes": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "security.secretform"
}
}

}
