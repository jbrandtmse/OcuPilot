/// <p>A SQL view's SQL statements tab: each SQL statement that references the view, its plan state,
/// statistics, first day seen, text and location, read from the information schema's statement
/// tables through the source code API (<class>OcuPilot.Port.AtelierPort</class>, endpoint
/// <code>Catalog.ViewStatements</code>) and rendered by the <code>detail</code> archetype's page under
/// the group's tab strip (AD-5, AD-36, AD-61). It lists every account's statements on the view, as the
/// classic tab does, and never a user name, client or call stack; a statement's text is a row field,
/// untrusted and cut by the per-field bound like any other value (AD-24, AD-60).</p>
/// <p><b>It is one tab of <class>OcuPilot.Screen.Descriptor.ExplorerSqlView</class>'s parent-scoped
/// group</b> (AD-5): unlisted, its route id is the SQL views list row's <code>View</code>, sent as the
/// one criterion <code>view</code>.</p>
/// <p><b>The view is the one the caller's own privileges show it</b>: the port resolves the name
/// through the information schema before it reads, and answers not found otherwise, since the vendor's
/// view queries filter nothing by privilege (AD-61 rules 3 and 7). Its privilege set is
/// <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter>, beside READ on the namespace's code
/// databases (AD-29). It replaces <code>%CSP.UI.Portal.SQL.Home</code>, whose custom resource also
/// gates it (AD-44). No action and no refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerSqlViewStatements Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/sql-views/statements",
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
  "parentScope": "system-explorer/sql-views",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Statement", "PlanState", "NewPlan", "Executions", "TotalTime", "AverageTime", "StdDevTime", "RowCount", "Commands", "FirstSeen", "Location"], "secretFields": []},
  "emptyStateKey": "explorerSqlViewStatementsEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlViewStatementsPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlViewStatementsPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlViewStatementsPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.SQL.Home",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "atelier", "endpoint": "Catalog.ViewStatements", "type": "LIST"},
    "fields": ["Statement", "PlanState", "NewPlan", "Executions", "TotalTime", "AverageTime", "StdDevTime", "RowCount", "Commands", "FirstSeen", "Location"],
    "filter": ["Statement", "PlanState", "Location"],
    "sort": {"fields": ["Statement", "Executions", "TotalTime", "FirstSeen"], "default": "Statement", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "view", "labelKey": "viewMenuLabel", "kind": "text", "maxLength": 257}
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
  "tab": {"group": "system-explorer/sql-views/document", "position": 3, "labelKey": "explorerSqlTabStatements"},
  "toolIdentifier": "explorer.sqlviewstatements"
}
}

}
