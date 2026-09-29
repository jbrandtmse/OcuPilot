/// <p>The background task error log: the newest error rows of the portal's background tasks,
/// whichever namespace each ran in, read through <code>%CSP.UI.System.BackgroundTask</code>. Its
/// classic page declares no resource, so it takes the Logs area's <code>%Admin_Operate:USE</code>,
/// and <code>%DB_IRISSYS:READ</code>, because the task list is read in <code>%SYS</code>.
/// (Story 16.8, AD-21, AD-36)</p>
/// <p>Rows travel on <method>OcuPilot.Port.LogSourcePort.Recent</method> under this screen's own
/// route, and the declared read the tool derives from travels on
/// <method>OcuPilot.Port.LogSourcePort.Rows</method>, which projects the same entries to
/// <code>{time, severity, text}</code>. Its id is <code>none</code>, it has no action and it
/// never refreshes on its own (AD-13, AD-43, AD-44).</p>
Class OcuPilot.Screen.Descriptor.LogTaskErrorViewer Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "logs/taskerrors",
  "area": "logs",
  "labelKey": "taskErrorLogListLabel",
  "sideBarPosition": 6,
  "archetype": "log-viewer",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "log-entry",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["time", "severity", "text"], "secretFields": []},
  "emptyStateKey": "logViewerEmpty",
  "commandAliases": ["background task errors"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "logTaskErrorViewerPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "logTaskErrorViewerPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "logTaskErrorViewerPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.BackgroundTaskError",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "logsource", "endpoint": "taskerrors", "type": "LIST"},
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
  "toolIdentifier": "logs.taskerrors"
}
}

}
