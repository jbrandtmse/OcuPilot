/// <p>Interoperability's Production items: the items one production of the route's namespace holds, with
/// their host class, kind, effective <code>Enabled</code> and pool size, read through
/// <class>OcuPilot.Port.InteropPort</class> (source kind <code>interop</code>, endpoint <code>Items</code>)
/// and rendered by the <code>list</code> archetype's page from the declared <code>table</code> (AD-5, AD-29,
/// AD-36, AD-62, Story 20.3).</p>
/// <p><b>It is a sub-resource of the Productions list and never listed</b> (<code>sideBarPosition</code> 0):
/// it declares <code>parentScope</code> <code>interoperability/productions</code> and is reached from that
/// list's name cell at <code>interoperability/productions/items/&lt;production&gt;</code>. Its one declared
/// criterion, <code>production</code>, is the route id, required as a single-object read's is (AD-36); the
/// port answers the production on each row, so nothing is seeded.</p>
/// <p><b>Its id is the composite <code>[Production, Name]</code></b>, each part kept exactly (AD-13), and
/// its scope is <code>namespace</code>. It is never the vendor's integer item id, which a recompile
/// renumbers.</p>
/// <p><b>Its row actions</b> Enable, Disable and Remove, and its primary action Add, are the screen's callers
/// of <class>OcuPilot.Screen.Tool.InteropItemEnable</class> and its three siblings (AD-53): each writes the
/// stored production configuration and the production class only, so a running production reads update
/// pending until Productions' confirmed Update applies it. Remove types the item's name and is refused while
/// the item is enabled. Add opens a dialog; it is a person's Save, resolved through the same tool as the
/// agent's (AD-55).</p>
/// <p><b>Its pairs</b> are the Productions list's: <code>%Ens_Portal:USE</code> and, as its own,
/// <code>%Ens_ProductionConfig:READ</code>; the four tools add <code>%Ens_ProductionConfig:WRITE</code> and
/// WRITE on the namespace's globals and routines databases, which the port checks before any vendor call
/// (AD-8, AD-62). It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.InteropItemList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/productions/items",
  "area": "interoperability",
  "labelKey": "interopItemsLabel",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_ProductionConfig", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_ProductionConfig", "permission": "READ"}],
  "entityType": "production-item",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "interoperability/productions",
  "id": {"kind": "composite", "parts": ["Production", "Name"]},
  "primaryAction": {"id": "add", "selfProtection": ""},
  "rowActions": [{"id": "enable", "selfProtection": ""}, {"id": "disable", "selfProtection": ""}, {"id": "remove", "selfProtection": ""}],
  "context": {"fields": ["Name", "ClassName", "Type", "Enabled", "PoolSize"], "secretFields": []},
  "emptyStateKey": "interopItemsEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopItemsPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopItemsPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopItemsPrompt3"}
  ],
  "classicPage": "EnsPortal.ProductionConfig",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "interop", "endpoint": "Items", "type": "LIST"},
    "fields": ["Production", "Name", "ClassName", "Type", "Enabled", "EnabledSource", "PoolSize", "Category", "Comment"],
    "filter": ["Name", "ClassName", "Type"],
    "sort": {"fields": ["Name", "ClassName", "Type", "Enabled", "PoolSize"], "default": "Name", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [{"param": "production", "labelKey": "systemInfoProduction", "kind": "text", "maxLength": 128, "hint": "One production, spelled as interop.productions.read answers its Name."}]
    }
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "ClassName", "labelKey": "interopItemColumnClass", "kind": "identifier"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "Enabled", "labelKey": "tableColumnEnabled", "kind": "status"},
      {"field": "PoolSize", "labelKey": "interopItemColumnPoolSize", "kind": "number"},
      {"field": "Category", "labelKey": "interopItemColumnCategory", "kind": "text"},
      {"field": "Comment", "labelKey": "userFieldComment", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "interopItemsEmptyAgent"
  },
  "toolIdentifier": "interop.items"
}
}

}
