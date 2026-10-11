/// <p>Interoperability's Item settings: the Core, Host and Adapter settings one production item holds, with their
/// value, source, default and type, read through <class>OcuPilot.Port.InteropPort</class> (source kind
/// <code>interop</code>, endpoint <code>Settings</code>) and rendered by the <code>list</code> archetype's page from the
/// declared <code>table</code> (AD-5, AD-29, AD-36, AD-62, Story 20.22).</p>
/// <p><b>It is a sub-resource of the Production items list and never listed</b> (<code>sideBarPosition</code> 0): it
/// declares <code>parentScope</code> <code>interoperability/productions/items</code> and is reached from that list's
/// name cell at <code>interoperability/productions/items/settings/&lt;item&gt;</code>. Its one declared criterion,
/// <code>item</code>, is the route id, required as a single-object read's is (AD-36); it is the item's composite
/// id <code>[Production, Name]</code>, which the Production items rows carry, or the vendor's config name
/// <code>Production||Name</code>, which the read tool's hint asks for. The port answers the production and the item
/// on each row, so nothing is seeded.</p>
/// <p><b>Its id is the composite <code>[Production, Item, Target, Name]</code></b>, each part kept exactly (AD-13),
/// and its scope is <code>namespace</code>. <code>Target</code> is <code>Core</code> (one of the item's own
/// properties), <code>Host</code> or <code>Adapter</code>.</p>
/// <p><b>A setting whose name the credential pattern matches is listed with an empty value and default and
/// <code>Secret</code> true</b>, by the port, so neither reaches the screen, the context, the read tool or the ledger
/// (AD-35, AD-36); that is why <code>secretFields</code> is empty here.</p>
/// <p><b>Its row actions</b> Set value and Reset to default are the screen's callers of
/// <class>OcuPilot.Screen.Tool.InteropSettingSet</class> and <class>OcuPilot.Screen.Tool.InteropSettingReset</class>
/// (AD-53): each writes the stored production configuration and the production class only, so a running production reads
/// update pending until Productions' confirmed Update applies it. Set value opens a dialog; a server path is named a
/// location on the server.</p>
/// <p><b>Its pairs</b> are the Production items list's; the two tools add the item writes' (AD-8, AD-62). It does not
/// refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.InteropItemSettingList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/productions/items/settings",
  "area": "interoperability",
  "labelKey": "interopItemSettingsLabel",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_ProductionConfig", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_ProductionConfig", "permission": "READ"}],
  "entityType": "production-item-setting",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "interoperability/productions/items",
  "id": {"kind": "composite", "parts": ["Production", "Item", "Target", "Name"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "set", "selfProtection": ""}, {"id": "reset", "selfProtection": ""}],
  "context": {"fields": ["Target", "Name", "Value", "Source"], "secretFields": []},
  "emptyStateKey": "interopItemSettingsEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopItemSettingsPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopItemSettingsPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopItemSettingsPrompt3"}
  ],
  "classicPage": "EnsPortal.ProductionConfig",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "interop", "endpoint": "Settings", "type": "LIST"},
    "fields": ["Production", "Item", "Target", "Name", "Value", "Source", "Default", "DefaultSource", "Type", "Category", "Location", "Secret"],
    "filter": ["Name", "Target", "Source"],
    "sort": {"fields": ["Name", "Target", "Value", "Source"], "default": "Name", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [{"param": "item", "labelKey": "interopItemSettingsCriterionItem", "kind": "text", "maxLength": 352, "hint": "One item, spelled as interop.items.read answers its Production, then two vertical bars and its Name."}]
    }
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Target", "labelKey": "agentLedgerColumnTarget", "kind": "text"},
      {"field": "Value", "labelKey": "errorLogColumnValue", "kind": "text"},
      {"field": "Source", "labelKey": "auditEventFieldSource", "kind": "text"},
      {"field": "Default", "labelKey": "tableColumnDefault", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "interopItemSettingsEmptyAgent"
  },
  "toolIdentifier": "interop.itemsettings"
}
}

}
