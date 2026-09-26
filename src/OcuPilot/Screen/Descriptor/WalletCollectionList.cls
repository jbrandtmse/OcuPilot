/// <p>The Wallet list: every wallet collection on this instance, read through the vendor's own
/// <code>Wallet.Collection</code> LIST (AD-2, AD-36) and rendered by the <code>list</code>
/// archetype's page from the declared <code>table</code> (AD-5).</p>
/// <p><b>Its scope is <code>instance</code>, and its rows are not filtered by namespace.</b> A wallet
/// collection is instance security configuration keyed by its name alone (AD-13).</p>
/// <p><b>Its id is <code>single</code>:</b> the collection's name, one percent-encoded path segment.
/// The name cell opens the collection's secrets
/// (<class>OcuPilot.Screen.Descriptor.WalletSecretList</class>), the screen whose
/// <code>parentScope</code> is this list's route.</p>
/// <p><b>The three read fields are the live LIST row's whole key set</b>, in the vendor's own order:
/// <code>Name</code>, <code>EditResource</code> and <code>UseResource</code>. A collection holds no
/// secret value of its own, so <code>context.secretFields</code> is empty (AD-35).</p>
/// <p><b>The privilege set is <code>%Admin_Wallet:USE</code> and <code>%DB_IRISSYS:READ</code></b>,
/// in that order, so a caller without the wallet resource is refused naming it. The first is the
/// vendor's <code>ResourcesOR()</code>; without the second the vendor endpoint fails inside
/// <code>%SYS</code> and the port answers 500 (AD-8).</p>
/// <p><b>No classic page exists</b>, so <code>classicPage</code> is empty and the list links out to
/// nothing (AD-44).</p>
/// <p>It declares no primary or row action, so its empty state names what to do next, and it does
/// not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.WalletCollectionList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/wallet",
  "area": "security",
  "labelKey": "walletListLabel",
  "sideBarPosition": 4,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Wallet", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "wallet-collection",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Name", "EditResource", "UseResource"], "secretFields": []},
  "emptyStateKey": "walletListEmpty",
  "commandAliases": ["secrets"],
  "suggestedPrompts": [
    {"groupKey": "userPromptGroupAccess", "textKey": "walletCollectionListPrompt1"},
    {"groupKey": "userPromptGroupAccess", "textKey": "walletCollectionListPrompt2"},
    {"groupKey": "userPromptGroupAccess", "textKey": "walletCollectionListPrompt3"}
  ],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Wallet.Collection", "type": "LIST"},
    "fields": ["Name", "EditResource", "UseResource"],
    "filter": ["Name", "UseResource", "EditResource"],
    "sort": {"fields": ["Name", "UseResource", "EditResource"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "UseResource", "labelKey": "walletColumnUseResource", "kind": "text"},
      {"field": "EditResource", "labelKey": "walletColumnEditResource", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "security.wallet"
}
}

}
