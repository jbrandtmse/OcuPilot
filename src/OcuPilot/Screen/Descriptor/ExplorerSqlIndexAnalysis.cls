/// <p>System Explorer's SQL index analyzer: what the five index reports (Index usage, Table scan, Temporary index, Missing join index and Outlier index)
/// recorded for the namespace's gathered SQL statements, one row per report row, read through the source code API
/// (<class>OcuPilot.Port.AtelierPort</class>, endpoint <code>Catalog.IndexAnalysis</code>) and rendered by the <code>list</code> archetype's page from the
/// declared <code>table</code> (AD-5, AD-36, AD-61, Story 21.27). The agent's <code>explorer.sqlindexanalysis.read</code> answers the same capped rows. A
/// statement's text is a row field, untrusted and cut by the per-field bound like any other value (AD-24, AD-60), and renders as text; a join or outlier row
/// with an exact match is not listed, as on the classic page.</p>
/// <p><b>Its id is the report and the row's number</b>, kept exactly (AD-13). Its scope is <code>namespace</code>.</p>
/// <p><b>Its page actions</b> are <code>gather</code>, <code>run</code> and <code>purge</code>, the page's own actions on the target <code>*</code>, which
/// <class>OcuPilot.Screen.Tool.ExplorerSqlIndexAnalysisGather</class>, <class>OcuPilot.Screen.Tool.ExplorerSqlIndexAnalysisRun</class> and
/// <class>OcuPilot.Screen.Tool.ExplorerSqlIndexAnalysisPurge</class> carry out for both callers (AD-53).</p>
/// <p><b>Its privilege set</b> is <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter>, beside READ on the namespace's code databases (AD-29). It
/// replaces <code>%CSP.UI.Portal.SQL.QButtons.IndexAnalyzer</code>, whose custom resource also gates it (AD-44). It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerSqlIndexAnalysis Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/sql-index-analysis",
  "area": "system-explorer",
  "labelKey": "explorerSqlTabIndexAnalysis",
  "sideBarPosition": 23,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "sql-index-analysis",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Report", "Counter"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "gather", "selfProtection": ""}, {"id": "run", "selfProtection": ""}, {"id": "purge", "selfProtection": ""}],
  "context": {"fields": ["Report", "Counter", "Schema", "Table", "Index", "UsageCount", "ClassOrRoutine", "Statement"], "secretFields": []},
  "emptyStateKey": "explorerSqlIndexAnalysisEmpty",
  "commandAliases": ["index analyzer", "index analysis"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "explorerSqlIndexAnalysisPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "explorerSqlIndexAnalysisPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "explorerSqlIndexAnalysisPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.SQL.QButtons.IndexAnalyzer",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "index analysis row",
    "label": "The namespace's SQL index analysis: one row for each row of the five reports (Index usage, Table scan, Temporary index, Missing join index and Outlier index), with the table, index, statement and sizes each report recorded.",
    "source": {"port": "atelier", "endpoint": "Catalog.IndexAnalysis", "type": "LIST"},
    "fields": ["Report", "Counter", "Schema", "Table", "Index", "UsageCount", "StatementType", "ClassOrRoutine", "Module", "MapType", "IndexFields", "DataFields", "IndexNeeded", "Match", "OutlierField", "ExtentSize", "BlockCount", "Statement"],
    "filter": ["Report", "Schema", "Table", "Index", "ClassOrRoutine", "Statement"],
    "sort": {"fields": ["Report", "Counter", "Schema", "Table", "Index", "UsageCount", "ExtentSize", "BlockCount"], "default": "Counter", "direction": "asc"},
    "paging": "cap",
    "note": {"key": "explorerSqlIndexAnalysisNote", "text": "Reports read the statements last gathered in this namespace. Gather them again after the code changes."}
  },
  "table": {
    "columns": [
      {"field": "Report", "labelKey": "databaseIntegrityStepReport", "kind": "name"},
      {"field": "Schema", "labelKey": "explorerSqlColumnSchema", "kind": "text"},
      {"field": "Table", "labelKey": "explorerSqlColumnTable", "kind": "text"},
      {"field": "Index", "labelKey": "explorerSqlColumnIndex", "kind": "text"},
      {"field": "UsageCount", "labelKey": "indexAnalysisColumnUsageCount", "kind": "number"},
      {"field": "StatementType", "labelKey": "indexAnalysisColumnStatementType", "kind": "text"},
      {"field": "ClassOrRoutine", "labelKey": "indexAnalysisColumnClassOrRoutine", "kind": "text"},
      {"field": "Module", "labelKey": "runtimeStatsColumnModule", "kind": "text"},
      {"field": "MapType", "labelKey": "indexAnalysisColumnMapType", "kind": "text"},
      {"field": "IndexFields", "labelKey": "indexAnalysisColumnIndexFields", "kind": "text"},
      {"field": "DataFields", "labelKey": "indexAnalysisColumnDataFields", "kind": "text"},
      {"field": "IndexNeeded", "labelKey": "indexAnalysisColumnIndexNeeded", "kind": "text"},
      {"field": "Match", "labelKey": "explorerColumnMatch", "kind": "text"},
      {"field": "OutlierField", "labelKey": "indexAnalysisColumnOutlierField", "kind": "text"},
      {"field": "ExtentSize", "labelKey": "explorerSqlColumnExtentSize", "kind": "number"},
      {"field": "BlockCount", "labelKey": "indexAnalysisColumnBlockCount", "kind": "number"},
      {"field": "Statement", "labelKey": "explorerSqlColumnStatement", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "explorerSqlIndexAnalysisEmptyAgent"
  },
  "toolIdentifier": "explorer.sqlindexanalysis"
}
}

}
