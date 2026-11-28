/// <p>System Explorer's SQL statements: the namespace's statement index, one row per statement with its hash, text, tables, plan state, plan
/// error, plan time and version, run statistics and locations, read through the source code API
/// (<class>OcuPilot.Port.AtelierPort</class>, endpoint <code>Catalog.Statements</code>) and rendered by the <code>list</code> archetype's page
/// from the declared <code>table</code> (AD-5, AD-36, AD-61). The agent's <code>explorer.sqlstatements.read</code> answers the same capped rows.
/// It lists every account's statements, as the classic page does, and never a user name, client or call stack. A statement's text is a row field,
/// untrusted and cut by the per-field bound like any other value (AD-24, AD-60), and renders as text.</p>
/// <p><b>Its id is the statement's hash</b>, which holds <code>/</code>, <code>+</code> and <code>=</code> and is kept exactly (AD-13); no route
/// carries it, since a screen action's id travels in the request's body. Its scope is <code>namespace</code>.</p>
/// <p><b>Its row actions</b> are Freeze plan, Unfreeze plan, Clear statistics and Clear plan error, which the shell's handler draws and which
/// <class>OcuPilot.Screen.Tool.ExplorerSqlStatementFreeze</class>, <class>OcuPilot.Screen.Tool.ExplorerSqlStatementUnfreeze</class>,
/// <class>OcuPilot.Screen.Tool.ExplorerSqlStatementClearStatistics</class> and <class>OcuPilot.Screen.Tool.ExplorerSqlStatementClearError</class>
/// carry out for both callers (AD-53); and <code>clean</code>, the page's own action on the target <code>*</code>, which
/// <class>OcuPilot.Screen.Tool.ExplorerSqlStatementClean</class> carries out. A statement over OcuPilot's own tables is refused by the kernel's
/// own-statement arm on both callers.</p>
/// <p><b>Its privilege set</b> is <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter>, beside READ on the namespace's code databases (AD-29).
/// It replaces <code>%CSP.UI.Portal.SQL.Home</code>, whose custom resource also gates it (AD-44). It does not refresh (AD-43).</p>
/// <p>Its read declares a <code>note</code>: the statistics are as of the instance's last aggregation, so a recently run statement can read
/// blank.</p>
Class OcuPilot.Screen.Descriptor.ExplorerSqlStatementList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/sql-statements",
  "area": "system-explorer",
  "labelKey": "explorerSqlTabStatements",
  "sideBarPosition": 20,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "statement-index-entry",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "freeze", "selfProtection": ""}, {"id": "unfreeze", "selfProtection": ""}, {"id": "clear-statistics", "selfProtection": ""}, {"id": "clear-error", "selfProtection": ""}, {"id": "clean", "selfProtection": ""}],
  "context": {"fields": ["Hash", "Statement", "Tables", "PlanState", "NewPlan", "PlanError", "Executions", "AverageTime"], "secretFields": []},
  "emptyStateKey": "explorerSqlStatementListEmpty",
  "commandAliases": ["statement index", "frozen plans"],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlStatementListPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlStatementListPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlStatementListPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.SQL.Home",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "statement in the index",
    "label": "Every SQL statement the namespace's statement index holds, with plan state, plan error and run statistics; statements running now are in osmgmt.sqlactivity.",
    "source": {"port": "atelier", "endpoint": "Catalog.Statements", "type": "LIST"},
    "fields": ["Hash", "Statement", "Tables", "PlanState", "NewPlan", "PlanError", "PlanSaved", "PlanVersion", "Executions", "TotalTime", "AverageTime", "StdDevTime", "RowCount", "Commands", "FirstSeen", "Location"],
    "filter": ["Hash", "Statement", "Tables", "PlanState", "PlanError", "Location"],
    "sort": {"fields": ["Statement", "PlanState", "Executions", "TotalTime", "AverageTime", "FirstSeen"], "default": "AverageTime", "direction": "desc"},
    "paging": "cap",
    "note": {"key": "explorerSqlStatementsNote", "text": "Statistics are as of the instance's last aggregation, so a recently run statement can read blank."}
  },
  "table": {
    "columns": [
      {"field": "Hash", "labelKey": "explorerSqlColumnStatementHash", "kind": "name"},
      {"field": "Statement", "labelKey": "explorerSqlColumnStatement", "kind": "text"},
      {"field": "Tables", "labelKey": "explorerSqlColumnTables", "kind": "text"},
      {"field": "PlanState", "labelKey": "explorerSqlColumnPlanState", "kind": "text"},
      {"field": "NewPlan", "labelKey": "explorerSqlColumnNewPlan", "kind": "status"},
      {"field": "PlanError", "labelKey": "explorerSqlColumnPlanError", "kind": "text"},
      {"field": "PlanSaved", "labelKey": "explorerSqlColumnPlanSaved", "kind": "text"},
      {"field": "PlanVersion", "labelKey": "explorerSqlColumnPlanVersion", "kind": "text"},
      {"field": "Executions", "labelKey": "explorerSqlColumnExecutions", "kind": "number"},
      {"field": "TotalTime", "labelKey": "explorerSqlColumnTotalTime", "kind": "number"},
      {"field": "AverageTime", "labelKey": "explorerSqlColumnAverageTime", "kind": "number"},
      {"field": "StdDevTime", "labelKey": "explorerSqlColumnStdDevTime", "kind": "number"},
      {"field": "RowCount", "labelKey": "explorerSqlColumnRowCount", "kind": "number"},
      {"field": "Commands", "labelKey": "processColumnCommands", "kind": "number"},
      {"field": "FirstSeen", "labelKey": "explorerSqlColumnFirstSeen", "kind": "text"},
      {"field": "Location", "labelKey": "processDetailsLocation", "kind": "identifier"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "explorerSqlStatementListEmptyAgent"
  },
  "toolIdentifier": "explorer.sqlstatements"
}
}

}
