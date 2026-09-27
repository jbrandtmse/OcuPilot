/// <p>The interoperability event log: the newest <code>Ens_Util.Log</code> rows of every
/// interoperability-enabled namespace the user can read, merged, each led by its namespace. The
/// pair is its classic page's; the port adds each namespace's globals database <code>READ</code>.
/// The pair is declared its own, beyond the Logs area's set, so a caller without it loses this
/// screen alone (AD-8). (Story 16.8, AD-21, AD-36)</p>
/// <p>Rows travel on <method>OcuPilot.Port.LogSourcePort.Recent</method> under this screen's own
/// route, and the declared read the tool derives from travels on
/// <method>OcuPilot.Port.LogSourcePort.Rows</method>, which projects the same entries to
/// <code>{time, severity, text}</code>. Its id is <code>none</code>, it has no action and it
/// never refreshes on its own (AD-13, AD-43, AD-44).</p>
Class OcuPilot.Screen.Descriptor.LogEventViewer Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "logs/eventlog",
  "area": "logs",
  "labelKey": "eventLogListLabel",
  "sideBarPosition": 9,
  "archetype": "log-viewer",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_EventLog", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%Ens_EventLog", "permission": "USE"}],
  "entityType": "log-entry",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["time", "severity", "text"], "secretFields": []},
  "emptyStateKey": "logViewerEmpty",
  "commandAliases": ["event log", "interoperability"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "logEventViewerPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "logEventViewerPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "logEventViewerPrompt3"}
  ],
  "classicPage": "EnsPortal.EventLog",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "logsource", "endpoint": "eventlog", "type": "LIST"},
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
  "toolIdentifier": "logs.eventlog"
}
}

}
