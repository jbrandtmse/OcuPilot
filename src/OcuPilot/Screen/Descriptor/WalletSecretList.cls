/// <p>The Secrets list: the secrets of one wallet collection, read through the vendor's own
/// <code>Wallet.Secret</code> LIST (AD-2, AD-36) and rendered by the <code>list</code> archetype's
/// page from the declared <code>table</code> (AD-5).</p>
/// <p><b>It is a sub-resource of the Wallet list and never listed</b> (<code>sideBarPosition</code>
/// 0). It declares its parent, <code>parentScope</code> <code>security/wallet</code> (AD-5), and is
/// reached from that list's name cell at <code>security/wallet/secrets/&lt;collection&gt;</code>. Its
/// one declared criterion, <code>collection</code>, is filled by the client from that route id; the
/// vendor answers 400 when it is missing and 404 when it names no collection.</p>
/// <p><b>Its scope is <code>instance</code></b> and its id is <code>single</code>: the route's id
/// segment is the parent collection's name, and a row is keyed by the secret's <code>Name</code>,
/// which carries that collection as a prefix (<code>&lt;collection&gt;.&lt;secret&gt;</code>).</p>
/// <p><b>The two read fields are the live LIST row's whole key set</b>: <code>Name</code> and
/// <code>Type</code>, the secret's class. <b>Nothing secret is read:</b> the LIST row carries no
/// value, and the endpoint has no GET a <code>rowGet</code> could issue, so
/// <code>context.secretFields</code> is empty (AD-35).</p>
/// <p><b>The privilege set is <code>%Admin_Wallet:USE</code> and <code>%DB_IRISSYS:READ</code></b>,
/// the Wallet list's set and order (AD-8).</p>
/// <p><b>No classic page exists</b>, so <code>classicPage</code> is empty and the list links out to
/// nothing (AD-44).</p>
/// <p><b>Its primary action is Create</b>: it opens
/// <class>OcuPilot.Screen.Descriptor.WalletSecretForm</class> at
/// <code>security/wallet/secrets/edit</code> for the collection on screen, and a row's name cell
/// opens the same form for that secret. Both save through the wallet secret tools (AD-55). Its row
/// action is Delete (AD-53), through <class>OcuPilot.Screen.Tool.WalletSecretDelete</class>, with no
/// self-protection rule: OcuPilot stores no wallet secret of its own. Its empty state invites the
/// agent, and it does not refresh (AD-43).</p>
/// <p><b><code>Secret</code> is its <code>secretArguments</code></b> (AD-3, AD-6): the value, supplied
/// only at confirm and never read back by any read.</p>
Class OcuPilot.Screen.Descriptor.WalletSecretList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/wallet/secrets",
  "area": "security",
  "labelKey": "walletSecretListLabel",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Wallet", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "wallet-secret",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "security/wallet",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [{"id": "delete", "selfProtection": ""}],
  "context": {"fields": ["Name", "Type"], "secretFields": []},
  "secretArguments": ["Secret"],
  "emptyStateKey": "walletSecretListEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "userPromptGroupAccess", "textKey": "walletSecretListPrompt1"},
    {"groupKey": "userPromptGroupAccess", "textKey": "walletSecretListPrompt2"},
    {"groupKey": "userPromptGroupAccess", "textKey": "walletSecretListPrompt3"}
  ],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Wallet.Secret", "type": "LIST"},
    "fields": ["Name", "Type"],
    "filter": ["Name", "Type"],
    "sort": {"fields": ["Name", "Type"], "default": "Name", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [{"param": "collection", "labelKey": "tableColumnName", "kind": "text", "maxLength": 64}]
    }
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "walletSecretListEmptyAgent"
  },
  "toolIdentifier": "security.secrets"
}
}

}
