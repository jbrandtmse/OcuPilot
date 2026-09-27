/// <p>The System Monitor's log: the newest entries of <code>SystemMonitor.log</code> in the manager
/// directory, read from the file's own tail. The pair is the one its classic page
/// (<code>%CSP.UI.Portal.ViewLog</code>) carries. (Story 16.8, AD-21, AD-36)</p>
/// <p>Rows travel on <method>OcuPilot.Port.LogSourcePort.Recent</method> under this screen's own
/// route, and the declared read the tool derives from travels on
/// <method>OcuPilot.Port.LogSourcePort.Rows</method>, which projects the same entries to
/// <code>{time, severity, text}</code>. Its id is <code>none</code>, it has no action and it
/// never refreshes on its own (AD-13, AD-43, AD-44).</p>
Class OcuPilot.Screen.Descriptor.LogSystemMonitorViewer Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "logs/systemmonitor",
  "area": "logs",
  "labelKey": "systemMonitorLogListLabel",
  "sideBarPosition": 5,
  "archetype": "log-viewer",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}],
  "entityType": "log-entry",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["time", "severity", "text"], "secretFields": []},
  "emptyStateKey": "logViewerEmpty",
  "commandAliases": ["system monitor", "SystemMonitor.log"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "logSystemMonitorViewerPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "logSystemMonitorViewerPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "logSystemMonitorViewerPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.ViewLog",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "logsource", "endpoint": "systemmonitor", "type": "LIST"},
    "fields": ["time", "severity", "text"],
    "filter": ["time", "severity", "text"],
    "sort": {"fields": ["time", "severity"], "default": "time", "direction": "desc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "time", "labelKey": "auditColumnTime", "kind": "name"},
      {"field": "severity", "labelKey": "logViewerColumnSeverity", "kind": "status"},
      {"field": "text", "labelKey": "logViewerColumnMessage", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "logs.systemmonitor"
}
}

}
