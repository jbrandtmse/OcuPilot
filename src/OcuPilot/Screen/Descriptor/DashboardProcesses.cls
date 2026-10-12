/// <p>Most active processes: the processes the Dashboard counts commands for, read as the rows of
/// <code>AdminPort</code>'s composed <code>BUSYPROCESSES</code> type over the vendor's
/// <code>DASHBOARDMAIN</code> answer, without the rows the vendor pads the list with, whose process is
/// empty (<code>source.rows</code>, AD-36), most commands first. An unlisted drill-down of the
/// Dashboard's System usage group (Story 18.36).</p>
/// <p>It administers nothing: <code>entityType</code> is <code>""</code>, its <code>id</code> is
/// <code>none</code>, it declares no action, it does not refresh (AD-43) and it takes no criterion.</p>
/// <p>Its pairs are the Dashboard's, <code>%Admin_Operate:USE</code> and <code>%DB_IRISSYS:READ</code>
/// (AD-8, AD-29), which OS management's set covers. Its classic page is
/// <code>%cspapp.op.utildashboard</code> (AD-44); it links out to nothing.</p>
Class OcuPilot.Screen.Descriptor.DashboardProcesses Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/active-processes",
  "area": "os-management",
  "labelKey": "activeProcessesLabel",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {
    "fields": ["Process", "Commands"],
    "secretFields": []
  },
  "emptyStateKey": "activeProcessesEmpty",
  "commandAliases": [],
  "suggestedPrompts": [{"groupKey": "promptGroupTroubleshooting", "textKey": "activeProcessesPrompt1"}, {"groupKey": "promptGroupTroubleshooting", "textKey": "activeProcessesPrompt2"}, {"groupKey": "promptGroupCapacity", "textKey": "activeProcessesPrompt3"}],
  "classicPage": "%cspapp.op.utildashboard",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Monitor", "type": "BUSYPROCESSES", "rows": "BusyProcesses"},
    "fields": ["Process", "Commands"],
    "filter": ["Process"],
    "sort": {
      "fields": ["Process", "Commands"],
      "default": "Commands",
      "direction": "desc"
    },
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Process", "labelKey": "processColumnPid", "kind": "name"},
      {"field": "Commands", "labelKey": "processColumnCommands", "kind": "number"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "osmgmt.activeprocesses"
}
}

}
