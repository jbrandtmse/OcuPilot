/// <p>Interoperability's Log tab of a production item (Story 20.4): the event log rows whose configuration name is the item's, newest first, read through
/// <class>OcuPilot.Port.InteropPort</class> and rendered by the shared page under the item's tab strip (AD-5, AD-29,
/// AD-36, AD-62).</p>
/// <p><b>It is one tab of the item group</b> <code>interoperability/productions/items/document</code>, parent-scoped under Production items: its one
/// criterion, <code>item</code>, is the route id, the item's composite id <code>[Production, Name]</code> or the
/// vendor's <code>Production||Name</code>, and the strip carries it from tab to tab. Its pairs are the classic
/// configuration page's for the tab (AD-8, AD-44), which adds <code>%Ens_EventLog:USE</code>; the rows are read by bound SQL after the port's gate, and their text reaches the model only through AD-60. It does not refresh and offers no action.</p>
Class OcuPilot.Screen.Descriptor.InteropItemLogTab Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/productions/items/log",
  "area": "interoperability",
  "labelKey": "interopItemLogLabel",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_ProductionConfig", "permission": "READ"}, {"resource": "%Ens_EventLog", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%Ens_ProductionConfig", "permission": "READ"}, {"resource": "%Ens_EventLog", "permission": "USE"}],
  "entityType": "log-entry",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "interoperability/productions/items",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["ID", "TimeLogged", "Type", "Text", "Job"], "secretFields": []},
  "emptyStateKey": "interopItemLogEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopItemLogPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopItemLogPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopItemLogPrompt3"}
  ],
  "classicPage": "EnsPortal.ProductionConfig",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "event log entry of one item",
    "source": {"port": "interop", "endpoint": "ItemLog", "type": "LIST"},
    "fields": ["Production", "Item", "ID", "TimeLogged", "Type", "Text", "Job", "SessionId"],
    "filter": ["Type", "Text", "Job", "SessionId"],
    "sort": {"fields": ["TimeLogged", "Type", "Job"], "default": "TimeLogged", "direction": "desc"},
    "paging": "cap",
    "criteria": {
      "fields": [{"param": "item", "labelKey": "interopItemSettingsCriterionItem", "kind": "text", "maxLength": 352, "hint": "One item, spelled as interop.items.read answers its Production, then two vertical bars and its Name."}]
    }
  },
  "table": {
    "columns": [
      {"field": "ID", "labelKey": "interopColumnId", "kind": "name"},
      {"field": "TimeLogged", "labelKey": "auditColumnTime", "kind": "text"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "status"},
      {"field": "Text", "labelKey": "logViewerColumnMessage", "kind": "text"},
      {"field": "Job", "labelKey": "interopColumnJob", "kind": "identifier"},
      {"field": "SessionId", "labelKey": "webSessionColumnSession", "kind": "identifier"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "interoperability/productions/items/document", "position": 4, "labelKey": "interopItemTabLog"},
  "toolIdentifier": "interop.itemlog"
}
}

}
