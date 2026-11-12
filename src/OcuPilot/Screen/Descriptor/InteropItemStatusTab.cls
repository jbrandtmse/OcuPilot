/// <p>Interoperability's Status tab of a production item (Story 20.4): the item's configuration facts and, while its production is the namespace's running or troubled one, its host monitor's status, adapter state and last activity, read through
/// <class>OcuPilot.Port.InteropPort</class> and rendered by the shared page under the item's tab strip (AD-5, AD-29,
/// AD-36, AD-62).</p>
/// <p><b>It is one tab of the item group</b> <code>interoperability/productions/items/document</code>, parent-scoped under Production items: its one
/// criterion, <code>item</code>, is the route id, the item's composite id <code>[Production, Name]</code> or the
/// vendor's <code>Production||Name</code>, and the strip carries it from tab to tab. Its pairs are the classic
/// configuration page's for the tab (AD-8, AD-44); it is the group's head, the screen a Production items or Production monitor name cell opens. It does not refresh and offers no action.</p>
Class OcuPilot.Screen.Descriptor.InteropItemStatusTab Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/productions/items/document",
  "area": "interoperability",
  "labelKey": "interopItemStatusLabel",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_ProductionConfig", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_ProductionConfig", "permission": "READ"}],
  "entityType": "production-item",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "interoperability/productions/items",
  "id": {"kind": "composite", "parts": ["Production", "Name"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Name", "ClassName", "Type", "Enabled", "Status", "AdapterState", "LastActivity"], "secretFields": []},
  "emptyStateKey": "interopItemStatusEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopItemStatusPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopItemStatusPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopItemStatusPrompt3"}
  ],
  "classicPage": "EnsPortal.ProductionConfig",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "status of one production item",
    "source": {"port": "interop", "endpoint": "ItemStatus", "type": "LIST"},
    "fields": ["Production", "Name", "ClassName", "Type", "Enabled", "Status", "AdapterState", "LastActivity"],
    "filter": ["Name", "ClassName", "Type", "Status"],
    "sort": {"fields": ["Name"], "default": "Name", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [{"param": "item", "labelKey": "interopItemSettingsCriterionItem", "kind": "text", "maxLength": 352, "hint": "One item, spelled as interop.items.read answers its Production, then two vertical bars and its Name."}]
    }
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "ClassName", "labelKey": "interopItemColumnClass", "kind": "identifier"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "Enabled", "labelKey": "tableColumnEnabled", "kind": "status"},
      {"field": "Status", "labelKey": "taskHistoryColumnStatus", "kind": "status"},
      {"field": "AdapterState", "labelKey": "interopColumnAdapterState", "kind": "text"},
      {"field": "LastActivity", "labelKey": "agentTranscriptsColumnLastActivity", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "interoperability/productions/items/document", "position": 1, "labelKey": "taskHistoryColumnStatus"},
  "toolIdentifier": "interop.itemstatus"
}
}

}
