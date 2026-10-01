/// <p>The Integrity log: the integrity checks this instance holds, newest first, and the report of the
/// one selected, read through <class>OcuPilot.Port.LogSourcePort</class>'s <code>integrity</code> source
/// (Story 18.4, AD-36). The port lists the checks through <code>SYS.BackgroundIntegrity</code>'s own
/// query and renders a check's report with the <code>Display^Integrity</code> call the admin API's own
/// integrity task makes, because the admin API keeps a report only in its one-read task result (the
/// Design Paradigm's <code>LogSourcePort</code> list, AD-26).</p>
/// <p>Its rows travel on <method>OcuPilot.Port.LogSourcePort.Page</method> under
/// <code>GET /logs/integrity</code>, a check chosen by its id, and its checks on
/// <method>OcuPilot.Port.LogSourcePort.Files</method> under <code>GET /logs/integrity/files</code>; the
/// declared read the tool derives from travels on <method>OcuPilot.Port.LogSourcePort.Rows</method>, the
/// newest check's report as <code>{time, severity, text}</code> rows.</p>
/// <p><b>The privilege set is <code>%Admin_Operate:USE</code> and <code>%DB_IRISSYS:READ</code></b>,
/// the port's own for this source: a principal holding exactly these read the checks and their reports
/// (measured on <code>ocupilot-b-ci</code>, Story 18.4 Task 0). It is OS management's fifth side-bar
/// entry, right after Databases, and the Check integrity flow also opens it. Its id is <code>none</code>, it has no action and it
/// never refreshes on its own (AD-13, AD-43); its classic equivalent is
/// <code>%CSP.UI.Portal.Dialog.IntegLog</code> (AD-44).</p>
Class OcuPilot.Screen.Descriptor.DatabaseIntegrityLog Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/databases/integrity-log",
  "area": "os-management",
  "labelKey": "databaseIntegrityLogLabel",
  "sideBarPosition": 5,
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
  "emptyStateKey": "databaseIntegrityNone",
  "commandAliases": ["integrity log"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "databaseIntegrityLogPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "databaseIntegrityLogPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "databaseIntegrityLogPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.Dialog.IntegLog",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "logsource", "endpoint": "integrity", "type": "LIST"},
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
  "toolIdentifier": "osmgmt.integritylog"
}
}

}
