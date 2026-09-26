/// <p>The console log: a bounded tail of the lines the instance wrote to <code>messages.log</code>,
/// read from the file itself (FR-9, AD-36). It is the Logs area's second screen.</p>
/// <p><b>One file, one reader.</b> The screen's rows travel on
/// <method>OcuPilot.Port.LogSourcePort.Page</method> under <code>GET /logs/messages</code>, and the
/// declared read the tool derives from travels on
/// <method>OcuPilot.Port.LogSourcePort.Rows</method> -- the same window projected into
/// <code>{time, severity, text}</code> rows instead of raw lines. Neither path reaches the
/// monitoring API. Nothing is added for this screen: the source key, the route and the shared
/// <code>log-viewer</code> page all ship already, so this declaration is the whole screen.</p>
/// <p><b>The privilege set is one pair.</b> <code>%Admin_Operate:USE</code> is exactly
/// <parameter>OcuPilot.Port.LogSourcePort.MESSAGESPAIRS</parameter>, so the gate a user meets is the
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
/// <p><b>The classic page is <code>%cspapp.op.utilsysconsolelog</code></b>, the same page
/// <class>OcuPilot.Screen.Descriptor.LogAlertViewer</class> names: one classic page shows both
/// files, selected by a control inside it (<file>irislib/%CSP/UI/System/ViewTextFilePane.cls</file>).
/// Spelled in the class's own case because the custom-resource lookup does not case-fold
/// (AD-44).</p>
/// <p><b>The <code>messages.log</code> alias is load-bearing.</b> The shell's fault banner resolves
/// "Open messages.log" from it rather than from a route string typed in the shell (AD-5), so
/// renaming it moves that control's destination.</p>
Class OcuPilot.Screen.Descriptor.LogMessageViewer Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "logs/messages",
  "area": "logs",
  "labelKey": "messagesLogListLabel",
  "sideBarPosition": 2,
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
  "commandAliases": ["messages", "messages.log"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "logMessageViewerPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "logMessageViewerPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "logMessageViewerPrompt3"}
  ],
  "classicPage": "%cspapp.op.utilsysconsolelog",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "logsource", "endpoint": "messages", "type": "LIST"},
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
  "toolIdentifier": "logs.messages"
}
}

}
