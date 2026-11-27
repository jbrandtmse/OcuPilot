/// <p>System Explorer's SQL troubleshooting reports: the queries saved in the namespace for InterSystems support cases, one row per saved query with its
/// support case number, when it was saved, its status, whether it allows delimited identifiers, its schema and its statement text, read through the source
/// code API (<class>OcuPilot.Port.AtelierPort</class>, endpoint <code>Catalog.SqlReports</code>) and rendered by the <code>list</code> archetype's page
/// from the declared <code>table</code> (AD-5, AD-36, AD-61, Story 21.29). The agent's <code>explorer.sqlreports.read</code> answers the same capped rows.
/// The instance shows each caller the saved queries its own row-level security admits: the person who saved a query and every holder of the roles
/// <code>%All</code> or <code>%Developer</code>. A statement's text is a row field, untrusted and cut by the per-field bound like any other value (AD-24,
/// AD-60), and renders as text.</p>
/// <p><b>Its id is the saved query's own</b>, kept exactly (AD-13). Its scope is <code>namespace</code>.</p>
/// <p><b>Its page actions</b> are <code>save</code> and <code>generate</code>, on the target <code>*</code>, which
/// <class>OcuPilot.Screen.Tool.ExplorerSqlReportSave</class> and <class>OcuPilot.Screen.Tool.ExplorerSqlReportGenerate</class> carry out for both callers
/// (AD-53), and its row action is <code>delete</code> (<class>OcuPilot.Screen.Tool.ExplorerSqlReportDelete</class>). It offers no action that sends a
/// report to a vendor.</p>
/// <p><b>Its privilege set</b> is <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter>, beside READ on the namespace's code databases (AD-29). It
/// replaces <code>%CSP.UI.Portal.SQL.QButtons.ReportGenerator</code>, whose custom resource also gates it (AD-44). It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerSqlReports Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/sql-reports",
  "area": "system-explorer",
  "labelKey": "explorerSqlTabReports",
  "sideBarPosition": 24,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "sql-saved-query",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "save", "selfProtection": ""},
  "rowActions": [{"id": "save", "selfProtection": ""}, {"id": "generate", "selfProtection": ""}, {"id": "generate-browser", "selfProtection": ""}, {"id": "delete", "selfProtection": ""}],
  "context": {"fields": ["ID", "WRCNumber", "Saved", "Status", "Schema", "Statement"], "secretFields": []},
  "emptyStateKey": "explorerSqlReportsEmpty",
  "commandAliases": ["troubleshooting report", "report generator", "WRC report"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "explorerSqlReportsPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "explorerSqlReportsPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "explorerSqlReportsPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.SQL.QButtons.ReportGenerator",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "saved troubleshooting report query",
    "label": "Queries saved in this namespace for InterSystems support cases: case number, time saved, status, schema and statement. Lists the caller's own, or all for holders of %All or %Developer.",
    "source": {"port": "atelier", "endpoint": "Catalog.SqlReports", "type": "LIST"},
    "fields": ["ID", "WRCNumber", "Saved", "Status", "DelimitedIdentifiers", "Schema", "Statement"],
    "filter": ["ID", "Status", "Schema", "Statement"],
    "sort": {"fields": ["ID", "WRCNumber", "Saved", "Status", "Schema"], "default": "WRCNumber", "direction": "asc"},
    "paging": "cap",
    "note": {"key": "explorerSqlReportsNote", "text": "A saved query is listed for the person who saved it and for holders of %All or %Developer."}
  },
  "table": {
    "columns": [
      {"field": "ID", "labelKey": "interopColumnId", "kind": "name"},
      {"field": "WRCNumber", "labelKey": "explorerSqlReportsColumnWrc", "kind": "number"},
      {"field": "Saved", "labelKey": "formSaved", "kind": "text"},
      {"field": "Status", "labelKey": "taskHistoryColumnStatus", "kind": "text"},
      {"field": "DelimitedIdentifiers", "labelKey": "explorerSqlReportsColumnDelimited", "kind": "text"},
      {"field": "Schema", "labelKey": "explorerSqlColumnSchema", "kind": "text"},
      {"field": "Statement", "labelKey": "explorerSqlColumnStatement", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "explorerSqlReportsEmptyAgent"
  },
  "toolIdentifier": "explorer.sqlreports"
}
}

}
