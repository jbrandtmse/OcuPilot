/// <p>The analytics log: the newest lines of each readable namespace's
/// <code>DeepSeeTasks_&lt;NS&gt;.log</code>, merged, each led by its namespace. The pair is its
/// classic page's, which carries public <code>USE</code>, so the readable set is what narrows it.
/// (Story 16.8, AD-21, AD-36)</p>
/// <p>Rows travel on <method>OcuPilot.Port.LogSourcePort.Recent</method> under this screen's own
/// route, and the declared read the tool derives from travels on
/// <method>OcuPilot.Port.LogSourcePort.Rows</method>, which projects the same entries to
/// <code>{time, severity, text}</code>. Its id is <code>none</code>, it has no action and it
/// never refreshes on its own (AD-13, AD-43, AD-44).</p>
Class OcuPilot.Screen.Descriptor.LogAnalyticsViewer Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "logs/analytics",
  "area": "logs",
  "labelKey": "analyticsLogListLabel",
  "sideBarPosition": 10,
  "archetype": "log-viewer",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%DeepSee_Portal", "permission": "USE"}],
  "entityType": "log-entry",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["time", "severity", "text"], "secretFields": []},
  "emptyStateKey": "logViewerEmpty",
  "commandAliases": ["analytics", "deepsee"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "logAnalyticsViewerPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "logAnalyticsViewerPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "logAnalyticsViewerPrompt3"}
  ],
  "classicPage": "%DeepSee.UI.LogViewer",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "logsource", "endpoint": "analytics", "type": "LIST"},
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
  "toolIdentifier": "logs.analytics"
}
}

}
