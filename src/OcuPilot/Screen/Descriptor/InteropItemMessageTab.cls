/// <p>Interoperability's Messages tab of a production item (Story 20.4): the newest message headers sourced by or targeted at the item, newest first; no message body is read, read through
/// <class>OcuPilot.Port.InteropPort</class> and rendered by the shared page under the item's tab strip (AD-5, AD-29,
/// AD-36, AD-62).</p>
/// <p><b>It is one tab of the item group</b> <code>interoperability/productions/items/document</code>, parent-scoped under Production items: its one
/// criterion, <code>item</code>, is the route id, the item's composite id <code>[Production, Name]</code> or the
/// vendor's <code>Production||Name</code>, and the strip carries it from tab to tab. Its pairs are the classic
/// configuration page's for the tab (AD-8, AD-44), which adds <code>%Ens_MessageHeader:USE</code>; the rows are read by bound SQL after the port's gate. It does not refresh and offers no action.</p>
Class OcuPilot.Screen.Descriptor.InteropItemMessageTab Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/productions/items/messages",
  "area": "interoperability",
  "labelKey": "interopItemMessagesLabel",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_ProductionConfig", "permission": "READ"}, {"resource": "%Ens_MessageHeader", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%Ens_ProductionConfig", "permission": "READ"}, {"resource": "%Ens_MessageHeader", "permission": "USE"}],
  "entityType": "interop-message",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "interoperability/productions/items",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["ID", "TimeCreated", "Status", "Source", "Target", "BodyClass"], "secretFields": []},
  "emptyStateKey": "interopItemMessagesEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopItemMessagesPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopItemMessagesPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopItemMessagesPrompt3"}
  ],
  "classicPage": "EnsPortal.ProductionConfig",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "interop", "endpoint": "ItemMessages", "type": "LIST"},
    "fields": ["Production", "Item", "ID", "TimeCreated", "Status", "Source", "Target", "BodyClass", "SessionId"],
    "filter": ["Status", "Source", "Target", "BodyClass", "SessionId"],
    "sort": {"fields": ["TimeCreated", "Status", "Source", "Target"], "default": "TimeCreated", "direction": "desc"},
    "paging": "cap",
    "criteria": {
      "fields": [{"param": "item", "labelKey": "interopItemSettingsCriterionItem", "kind": "text", "maxLength": 352, "hint": "One item, spelled as interop.items.read answers its Production, then two vertical bars and its Name."}]
    }
  },
  "table": {
    "columns": [
      {"field": "ID", "labelKey": "interopColumnId", "kind": "name"},
      {"field": "TimeCreated", "labelKey": "journalColumnCreated", "kind": "text"},
      {"field": "Status", "labelKey": "taskHistoryColumnStatus", "kind": "status"},
      {"field": "Source", "labelKey": "auditEventFieldSource", "kind": "text"},
      {"field": "Target", "labelKey": "agentLedgerColumnTarget", "kind": "text"},
      {"field": "BodyClass", "labelKey": "interopColumnBodyClass", "kind": "identifier"},
      {"field": "SessionId", "labelKey": "webSessionColumnSession", "kind": "identifier"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "interoperability/productions/items/document", "position": 5, "labelKey": "interopItemTabMessages"},
  "toolIdentifier": "interop.itemmessages"
}
}

}
