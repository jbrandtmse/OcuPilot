/// <p>Activity log: one external language server's activity rows, read through the admin API's own
/// <code>LanguageServer</code> <code>ACTIVITY</code> as a list over its one member
/// <code>Activity</code> (AD-36 as amended, Story 16.10) and rendered by the shared log viewer
/// (<code>log-viewer</code>, AD-5), which maps each row to a line: <code>DateTime</code> as the
/// time, <code>Job</code> as the pid, <code>RecordType</code> as the severity chip and
/// <code>Text</code>.</p>
/// <p><b>It is a sub-resource of External language servers and never listed</b>
/// (<code>sideBarPosition</code> 0). It declares its parent, <code>parentScope</code>
/// <code>os-management/language-servers</code> (AD-5), and is reached from that list's name cell at
/// <code>os-management/language-servers/activity/&lt;name&gt;</code>. Its one criterion,
/// <code>name</code>, is filled from that route id; <code>maxLength</code> 50 is
/// <code>Config.Gateways</code> <code>Name</code>'s <code>MAXLEN</code>.</p>
/// <p><b>The rows are the vendor's, newest first</b>, bounded by the vendor's <code>maxRows</code>
/// sent as the cap plus one. They live in <code>IRISTEMP</code>, so the log empties when the instance
/// restarts (inference). No server path is read: the server's own <code>LogFile</code> is neither
/// shown nor read (AD-21).</p>
/// <p><b>The privilege set is the list's own</b>, <code>%Admin_ExternalLanguageServerEdit:USE</code>
/// as its own pair plus <code>%DB_IRISSYS:READ</code> (AD-8 as amended).</p>
/// <p><b>The classic page is <code>%CSP.UI.Portal.ExternalLanguageServerActivities</code></b>
/// (AD-44), with no exemption.</p>
Class OcuPilot.Screen.Descriptor.LanguageServerActivity Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/language-servers/activity",
  "area": "os-management",
  "labelKey": "languageServerActivityLabel",
  "sideBarPosition": 0,
  "archetype": "log-viewer",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_ExternalLanguageServerEdit", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Admin_ExternalLanguageServerEdit", "permission": "USE"}],
  "entityType": "log-entry",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "os-management/language-servers",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["ID", "DateTime", "RecordType", "Job", "Text"], "secretFields": []},
  "emptyStateKey": "logViewerEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "languageServerActivityPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "languageServerActivityPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "languageServerActivityPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.ExternalLanguageServerActivities",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "LanguageServer", "type": "ACTIVITY", "rows": "Activity"},
    "fields": ["ID", "DateTime", "RecordType", "Job", "Text"],
    "filter": ["DateTime", "RecordType", "Text"],
    "sort": {"fields": ["ID"], "default": "ID", "direction": "desc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "name", "labelKey": "tableColumnName", "kind": "text", "maxLength": 50}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "DateTime", "labelKey": "auditColumnTime", "kind": "name"},
      {"field": "RecordType", "labelKey": "logViewerColumnSeverity", "kind": "status"},
      {"field": "Job", "labelKey": "processColumnPid", "kind": "number"},
      {"field": "Text", "labelKey": "logViewerColumnMessage", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "osmgmt.languageserveractivity"
}
}

}
