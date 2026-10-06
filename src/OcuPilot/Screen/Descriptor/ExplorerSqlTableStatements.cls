/// <p>A SQL table's SQL statements tab: each SQL statement that references the table, its plan
/// state, statistics, first day seen, text and locations, read from the information schema's
/// statement tables through the source code API (<class>OcuPilot.Port.AtelierPort</class>, endpoint
/// <code>Catalog.TableStatements</code>) and rendered by the <code>detail</code> archetype's page under
/// the group's tab strip (AD-5, AD-36, AD-61). It lists every account's statements on the table, as
/// the classic tab does, and never a user name, client or call stack; a statement's text is a row
/// field, untrusted and cut by the per-field bound like any other value (AD-24, AD-60), and renders as
/// text.</p>
/// <p><b>It is one tab of <class>OcuPilot.Screen.Descriptor.ExplorerSqlTable</class>'s parent-scoped
/// group</b> (AD-5): unlisted, its route id is the SQL tables list row's <code>Table</code>, sent as
/// the one criterion <code>table</code>.</p>
/// <p><b>The table is the one the caller's own privileges show it</b>: the port resolves the name
/// through the information schema before it reads, and answers not found otherwise (AD-61 rule 7).
/// Its privilege set is <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter>, beside READ on the
/// namespace's code databases (AD-29). It replaces <code>%CSP.UI.Portal.SQL.Home</code>, whose
/// custom resource also gates it (AD-44). No action and no refresh (AD-43).</p>
/// <p>Its read declares a <code>note</code>: the statistics are as of the instance's last
/// aggregation, so a recently run statement can read blank. The page shows it above the rows and the
/// read tool's description ends with it (AD-36).</p>
Class OcuPilot.Screen.Descriptor.ExplorerSqlTableStatements Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/sql-tables/statements",
  "area": "system-explorer",
  "labelKey": "explorerSqlTabStatements",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "class",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "system-explorer/sql-tables",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Statement", "PlanState", "NewPlan", "Executions", "TotalTime", "AverageTime", "StdDevTime", "RowCount", "Commands", "FirstSeen", "Location"], "secretFields": []},
  "emptyStateKey": "explorerSqlTableStatementsEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlTableStatementsPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlTableStatementsPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlTableStatementsPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.SQL.Home",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "atelier", "endpoint": "Catalog.TableStatements", "type": "LIST"},
    "fields": ["Statement", "PlanState", "NewPlan", "Executions", "TotalTime", "AverageTime", "StdDevTime", "RowCount", "Commands", "FirstSeen", "Location"],
    "filter": ["Statement", "PlanState", "Location"],
    "sort": {"fields": ["Statement", "Executions", "TotalTime", "FirstSeen"], "default": "Statement", "direction": "asc"},
    "paging": "cap",
    "note": {"key": "explorerSqlStatementsNote", "text": "Statistics are as of the instance's last aggregation, so a recently run statement can read blank."},
    "criteria": {
      "fields": [
        {"param": "table", "labelKey": "explorerSqlColumnTable", "kind": "text", "maxLength": 257, "hint": "One table, as Schema.Table, spelled as explorer.sqltables.read answers its Table."}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Statement", "labelKey": "explorerSqlColumnStatement", "kind": "name"},
      {"field": "PlanState", "labelKey": "explorerSqlColumnPlanState", "kind": "text"},
      {"field": "NewPlan", "labelKey": "explorerSqlColumnNewPlan", "kind": "status"},
      {"field": "Executions", "labelKey": "explorerSqlColumnExecutions", "kind": "number"},
      {"field": "TotalTime", "labelKey": "explorerSqlColumnTotalTime", "kind": "number"},
      {"field": "AverageTime", "labelKey": "explorerSqlColumnAverageTime", "kind": "number"},
      {"field": "StdDevTime", "labelKey": "explorerSqlColumnStdDevTime", "kind": "number"},
      {"field": "RowCount", "labelKey": "explorerSqlColumnRowCount", "kind": "number"},
      {"field": "Commands", "labelKey": "processColumnCommands", "kind": "number"},
      {"field": "FirstSeen", "labelKey": "explorerSqlColumnFirstSeen", "kind": "text"},
      {"field": "Location", "labelKey": "processDetailsLocation", "kind": "identifier"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "system-explorer/sql-tables/document", "position": 9, "labelKey": "explorerSqlTabStatements"},
  "toolIdentifier": "explorer.sqltablestatements"
}
}

}
