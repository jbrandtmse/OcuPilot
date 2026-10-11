/// <p>Interoperability's Queue tab of a production item (Story 20.4): the messages waiting in the item's queue, each with its header (a business process of pool size 0 reads the shared actor queue's entries addressed to it), read through
/// <class>OcuPilot.Port.InteropPort</class> and rendered by the shared page under the item's tab strip (AD-5, AD-29,
/// AD-36, AD-62).</p>
/// <p><b>It is one tab of the item group</b> <code>interoperability/productions/items/document</code>, parent-scoped under Production items: its one
/// criterion, <code>item</code>, is the route id, the item's composite id <code>[Production, Name]</code> or the
/// vendor's <code>Production||Name</code>, and the strip carries it from tab to tab. Its pairs are the classic
/// configuration page's for the tab (AD-8, AD-44), which adds <code>%Ens_Queues:READ</code>. It does not refresh and offers no action.</p>
Class OcuPilot.Screen.Descriptor.InteropItemQueueTab Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/productions/items/queue",
  "area": "interoperability",
  "labelKey": "interopItemQueueLabel",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_ProductionConfig", "permission": "READ"}, {"resource": "%Ens_Queues", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_ProductionConfig", "permission": "READ"}, {"resource": "%Ens_Queues", "permission": "READ"}],
  "entityType": "interop-message",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "interoperability/productions/items",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["MessageId", "Source", "Target", "BodyClass", "TimeCreated", "Status"], "secretFields": []},
  "emptyStateKey": "interopItemQueueEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopItemQueuePrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopItemQueuePrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopItemQueuePrompt3"}
  ],
  "classicPage": "EnsPortal.ProductionConfig",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "interop", "endpoint": "ItemQueue", "type": "LIST"},
    "fields": ["Production", "Item", "Queue", "Priority", "Index", "MessageId", "Source", "Target", "BodyClass", "TimeCreated", "Status"],
    "filter": ["MessageId", "Source", "Target", "BodyClass", "Status"],
    "sort": {"fields": ["Priority", "Index", "MessageId", "Source", "Target", "TimeCreated", "Status"], "default": "Index", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [{"param": "item", "labelKey": "interopItemSettingsCriterionItem", "kind": "text", "maxLength": 352, "hint": "One item, spelled as interop.items.read answers its Production, then two vertical bars and its Name."}]
    }
  },
  "table": {
    "columns": [
      {"field": "MessageId", "labelKey": "interopColumnMessageId", "kind": "name"},
      {"field": "Priority", "labelKey": "taskDetailsPriority", "kind": "number"},
      {"field": "Index", "labelKey": "explorerSqlColumnIndex", "kind": "number"},
      {"field": "Source", "labelKey": "auditEventFieldSource", "kind": "text"},
      {"field": "Target", "labelKey": "agentLedgerColumnTarget", "kind": "text"},
      {"field": "BodyClass", "labelKey": "interopColumnBodyClass", "kind": "identifier"},
      {"field": "TimeCreated", "labelKey": "journalColumnCreated", "kind": "text"},
      {"field": "Status", "labelKey": "taskHistoryColumnStatus", "kind": "status"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "interoperability/productions/items/document", "position": 3, "labelKey": "interopColumnQueue"},
  "toolIdentifier": "interop.itemqueue"
}
}

}
