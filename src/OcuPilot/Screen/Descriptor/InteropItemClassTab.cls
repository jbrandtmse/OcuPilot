/// <p>Interoperability's Classes tab of a production item (Story 20.41): the compiled classes the item can change to, one row for each, with
/// the item's own marked, read through <class>OcuPilot.Port.InteropPort</class> (the class dictionary, as the classic Change Class dialog
/// reads it through <code>Ens.ContextSearch</code>) and rendered by the shared page under the item's tab strip (AD-5, AD-29, AD-36,
/// AD-62). It is the list the Production items row action Change class offers, and the agent's read of it.</p>
/// <p><b>It is one tab of the item group</b> <code>interoperability/productions/items/document</code>, parent-scoped under Production
/// items: its one criterion, <code>item</code>, is the route id, the item's composite id <code>[Production, Name]</code> or the
/// vendor's <code>Production||Name</code>, and the strip carries it from tab to tab. An item whose class reads as no business host lists
/// the classes of all three kinds. It does not refresh (AD-43) and offers no action.</p>
/// <p><b>Its pairs</b> are the Production items list's and the classic Change Class dialog's (AD-8, AD-44): the Interoperability menu's
/// <code>%Ens_Portal:USE</code>, the configuration page's <code>%Ens_ProductionConfig:READ</code> and the dialog's own
/// <code>%Ens_ProductionConfig:WRITE</code>, so the list is never shown to someone the classic portal would not show it to. They are the
/// pairs of the port's <code>ItemClasses</code> endpoint.</p>
Class OcuPilot.Screen.Descriptor.InteropItemClassTab Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/productions/items/classes",
  "area": "interoperability",
  "labelKey": "interopItemClassesLabel",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_ProductionConfig", "permission": "READ"}, {"resource": "%Ens_ProductionConfig", "permission": "WRITE"}],
  "ownPrivileges": [{"resource": "%Ens_ProductionConfig", "permission": "READ"}, {"resource": "%Ens_ProductionConfig", "permission": "WRITE"}],
  "entityType": "production-item",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "interoperability/productions/items",
  "id": {"kind": "composite", "parts": ["Item", "ClassName"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["ClassName", "Type", "Current"], "secretFields": []},
  "emptyStateKey": "interopItemClassesEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopItemClassesPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopItemClassesPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopItemClassesPrompt3"}
  ],
  "classicPage": "EnsPortal.ProductionConfig",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "class this item can change to",
    "source": {"port": "interop", "endpoint": "ItemClasses", "type": "LIST"},
    "fields": ["Production", "Item", "ClassName", "Type", "Current"],
    "filter": ["ClassName", "Type"],
    "sort": {"fields": ["ClassName", "Type"], "default": "ClassName", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [{"param": "item", "labelKey": "interopItemSettingsCriterionItem", "kind": "text", "maxLength": 352, "hint": "One item, spelled as interop.items.read answers its Production, then two vertical bars and its Name."}]
    }
  },
  "table": {
    "columns": [
      {"field": "ClassName", "labelKey": "interopItemColumnClass", "kind": "name"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "Current", "labelKey": "interopItemClassesColumnCurrent", "kind": "status"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "interoperability/productions/items/document", "position": 8, "labelKey": "explorerClassListLabel"},
  "toolIdentifier": "interop.itemclasses"
}
}

}
