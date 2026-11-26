/// <p>Most active queues: the production queues that hold messages, one row each, read through <class>OcuPilot.Port.InteropPort</class> (source kind <code>interop</code>, endpoint
/// <code>SystemMonitorQueues</code>) from the table the vendor's <code>%SYS.Ensemble.GetEnsMetrics</code> answers, most messages first (AD-5, AD-36, AD-62, Story 24.17 Batch 5). An unlisted
/// drill-down of System monitor; the page draws the same table from this declared read.</p>
/// <p>It administers nothing: <code>entityType</code> is <code>""</code>, its <code>id</code> is <code>none</code>, its scope is <code>instance</code>, it declares no action, it does not refresh
/// (AD-43) and it takes no criterion. Its pairs are System monitor's (AD-8, AD-29); its classic page is <code>%CSP.UI.Portal.EnsembleMonitor</code> (AD-44).</p>
Class OcuPilot.Screen.Descriptor.InteropSystemMonitorQueues Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/system-monitor/queues",
  "area": "interoperability",
  "labelKey": "interopSystemMonitorQueuesLabel",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_Dashboard", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_Dashboard", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Namespace", "Queue", "Messages"], "secretFields": []},
  "emptyStateKey": "interopSystemMonitorQueuesEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopQueuesPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopSystemMonitorQueuesPrompt2"},
    {"groupKey": "promptGroupCapacity", "textKey": "interopSystemMonitorQueuesPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.EnsembleMonitor",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "busy production queue",
    "source": {"port": "interop", "endpoint": "SystemMonitorQueues", "type": "LIST"},
    "fields": ["Namespace", "Queue", "Messages"],
    "filter": ["Namespace", "Queue"],
    "sort": {"fields": ["Namespace", "Queue", "Messages"], "default": "Messages", "direction": "desc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Namespace", "labelKey": "headerNamespaceLabel", "kind": "text"},
      {"field": "Queue", "labelKey": "interopColumnQueue", "kind": "name"},
      {"field": "Messages", "labelKey": "interopItemTabMessages", "kind": "number"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "interop.systemmonitorqueues"
}
}

}
