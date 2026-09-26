/// <p>The alert log: a bounded tail of the lines the instance wrote to <code>alerts.log</code>,
/// read from the file itself (FR-9, AD-36). It is the Logs area's first screen.</p>
/// <p><b>One file, one reader.</b> The screen's rows travel on
/// <method>OcuPilot.Port.LogSourcePort.Page</method> under this screen's own route, and the declared
/// read the tool derives from travels on <method>OcuPilot.Port.LogSourcePort.Rows</method> -- the
/// same window projected into <code>{time, severity, text}</code> rows instead of raw lines. Neither
/// path reaches the monitoring API, whose reading of this same file drops the pid and the bracketed
/// category, quotes the severity and appends a <code>Z</code> to a local stamp nothing converted,
/// and whose every call advances the instance-wide SAM cursor another scraper shares (DW-1116).</p>
/// <p><b>The privilege set is one pair.</b> <code>%Admin_Operate:USE</code> is the resource the
/// classic page that shows alerts.log carries (<code>/csp/sys/op</code>), and
/// <code>%SYS_Portal.Resources</code> holds no custom assignment for it. It is exactly
/// <parameter>OcuPilot.Port.LogSourcePort.ALERTSPAIRS</parameter>, so the gate a user meets is the
/// same whichever way the screen reads; reading a file off disk consults no database resource and
/// this path never enters <code>%SYS</code>. It is already in the <code>logs</code> area's own set,
/// so the area's declaration is untouched. <code>%Admin_Secure:USE</code> is deliberately
/// <b>not</b> declared: this screen reads no security endpoint, and the area's set is a union
/// rather than a per-screen requirement (DW-278).</p>
/// <p><b>Nothing streams</b> (AD-43). <code>refreshes</code> is false and
/// <code>refreshRates</code> empty: <file>EXPERIENCE.md</file>'s Auto-refresh controls roster does
/// not name this screen, and rows arrive only on an explicit Load newer.</p>
/// <p><b>Its id is <code>none</code></b>: a log line is not an entity the instance can be asked for
/// again, so the screen has no detail route and the viewer opens no row (AD-13). <b>No primary or
/// row action</b>, and as a <code>log-viewer</code> archetype, which
/// <class>OcuPilot.Screen.Archetype</class> classifies <code>list</code>, it links out to nothing
/// (AD-44).</p>
/// <p><b>The classic page is <code>%cspapp.op.utilsysconsolelog</code></b>, which shows alerts.log
/// first (<file>irislib/%CSP/UI/System/ViewTextFilePane.cls</file>), spelled in the class's own case
/// because the custom-resource lookup does not case-fold (AD-44).</p>
Class OcuPilot.Screen.Descriptor.LogAlertViewer Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "logs/alerts",
  "area": "logs",
  "labelKey": "alertLogListLabel",
  "sideBarPosition": 1,
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
  "commandAliases": ["alerts", "alerts.log"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "logAlertViewerPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "logAlertViewerPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "logAlertViewerPrompt3"}
  ],
  "classicPage": "%cspapp.op.utilsysconsolelog",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "logsource", "endpoint": "alerts", "type": "LIST"},
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
  "toolIdentifier": "logs.alerts"
}
}

}
