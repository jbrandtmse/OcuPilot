/// <p>Interoperability's Jobs tab of a production item (Story 20.4): the item's jobs while its production is running or troubled, each with the message it is working on; a job no process holds reads <code>Dead</code> and is never repaired (AD-7), read through
/// <class>OcuPilot.Port.InteropPort</class> and rendered by the shared page under the item's tab strip (AD-5, AD-29,
/// AD-36, AD-62).</p>
/// <p><b>It is one tab of the item group</b> <code>interoperability/productions/items/document</code>, parent-scoped under Production items: its one
/// criterion, <code>item</code>, is the route id, the item's composite id <code>[Production, Name]</code> or the
/// vendor's <code>Production||Name</code>, and the strip carries it from tab to tab. Its pairs are the classic
/// configuration page's for the tab (AD-8, AD-44), which adds <code>%Ens_Jobs:READ</code>. It does not refresh and offers no action.</p>
Class OcuPilot.Screen.Descriptor.InteropItemJobTab Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/productions/items/jobs",
  "area": "interoperability",
  "labelKey": "interopItemJobsLabel",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_ProductionConfig", "permission": "READ"}, {"resource": "%Ens_Jobs", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_ProductionConfig", "permission": "READ"}, {"resource": "%Ens_Jobs", "permission": "READ"}],
  "entityType": "interop-job",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "interoperability/productions/items",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Job", "Status", "AdapterState", "LastActivity", "ActiveMessage", "Dead"], "secretFields": []},
  "emptyStateKey": "interopItemJobsEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopItemJobsPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopItemJobsPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopItemJobsPrompt3"}
  ],
  "classicPage": "EnsPortal.ProductionConfig",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "interop", "endpoint": "ItemJobs", "type": "LIST"},
    "fields": ["Production", "Item", "Job", "Host", "Status", "AdapterState", "LastActivity", "Retry", "ActiveMessage", "Dead"],
    "filter": ["Job", "Status", "ActiveMessage"],
    "sort": {"fields": ["Job", "Status", "LastActivity", "Retry"], "default": "Job", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [{"param": "item", "labelKey": "interopItemSettingsCriterionItem", "kind": "text", "maxLength": 352, "hint": "One item, spelled as interop.items.read answers its Production, then two vertical bars and its Name."}]
    }
  },
  "table": {
    "columns": [
      {"field": "Job", "labelKey": "interopColumnJob", "kind": "name"},
      {"field": "Status", "labelKey": "taskHistoryColumnStatus", "kind": "status"},
      {"field": "AdapterState", "labelKey": "interopColumnAdapterState", "kind": "text"},
      {"field": "LastActivity", "labelKey": "agentTranscriptsColumnLastActivity", "kind": "text"},
      {"field": "Retry", "labelKey": "actionRetry", "kind": "number"},
      {"field": "ActiveMessage", "labelKey": "interopColumnActiveMessage", "kind": "identifier"},
      {"field": "Dead", "labelKey": "interopColumnDead", "kind": "status"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "interoperability/productions/items/document", "position": 6, "labelKey": "interopJobsLabel"},
  "toolIdentifier": "interop.itemjobs"
}
}

}
