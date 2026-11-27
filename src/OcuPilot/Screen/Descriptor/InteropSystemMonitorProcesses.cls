/// <p>Most active processes: the processes the classic Interoperability System Monitor counts commands for, one row each, read through <class>OcuPilot.Port.InteropPort</class> (source kind
/// <code>interop</code>, endpoint <code>SystemMonitorProcesses</code>) from the table the vendor's <code>%SYS.Ensemble.GetEnsMetrics</code> answers, without the rows the vendor pads it with, most
/// commands first (AD-5, AD-36, AD-62, Story 24.17 Batch 5). An unlisted drill-down of System monitor; the page draws the same table from this declared read.</p>
/// <p>It administers nothing: <code>entityType</code> is <code>""</code>, its <code>id</code> is <code>none</code>, its scope is <code>instance</code>, it declares no action, it does not refresh
/// (AD-43) and it takes no criterion. Its pairs are System monitor's (AD-8, AD-29); its classic page is <code>%CSP.UI.Portal.EnsembleMonitor</code> (AD-44).</p>
Class OcuPilot.Screen.Descriptor.InteropSystemMonitorProcesses Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/system-monitor/processes",
  "area": "interoperability",
  "labelKey": "activeProcessesLabel",
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
  "context": {"fields": ["Namespace", "Item", "Pid", "Commands"], "secretFields": []},
  "emptyStateKey": "activeProcessesEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "activeProcessesPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "activeProcessesPrompt2"},
    {"groupKey": "promptGroupCapacity", "textKey": "activeProcessesPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.EnsembleMonitor",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "busy production process",
    "source": {"port": "interop", "endpoint": "SystemMonitorProcesses", "type": "LIST"},
    "fields": ["Namespace", "Item", "Pid", "Commands"],
    "filter": ["Namespace", "Item"],
    "sort": {"fields": ["Namespace", "Item", "Pid", "Commands"], "default": "Commands", "direction": "desc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Namespace", "labelKey": "headerNamespaceLabel", "kind": "text"},
      {"field": "Item", "labelKey": "interopItemSettingsCriterionItem", "kind": "name"},
      {"field": "Pid", "labelKey": "processColumnPid", "kind": "number"},
      {"field": "Commands", "labelKey": "processColumnCommands", "kind": "number"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "interop.systemmonitorprocesses"
}
}

}
