/// <p>System Explorer's SQL runtime statistics: what the instance collected for the namespace's SQL statements, one row per statement and module
/// (a summary row, module <code>INFO</code>, and one row per module of its plan) with its runs, averages per run and statement text, read through the
/// source code API (<class>OcuPilot.Port.AtelierPort</class>, endpoint <code>Catalog.RuntimeStats</code>) and rendered by the <code>list</code>
/// archetype's page from the declared <code>table</code> (AD-5, AD-36, AD-61, Story 21.26). The agent's <code>explorer.sqlruntimestats.read</code>
/// answers the same capped rows. It lists every account's statistics, as the classic page does, and never a user name, client, process or the
/// values a statement ran with. A statement's text is a row field, untrusted and cut by the per-field bound like any other value (AD-24, AD-60), and
/// renders as text.</p>
/// <p><b>Its id is the routine, the cursor and the module</b>, kept exactly (AD-13). Its scope is <code>namespace</code>.</p>
/// <p><b>Its page action</b> is <code>purge</code>, the page's own action on the target <code>*</code>, which
/// <class>OcuPilot.Screen.Tool.ExplorerSqlRuntimeStatsPurge</class> carries out for both callers (AD-53). Whether collection is on, and its stop, are
/// <class>OcuPilot.Screen.Descriptor.ExplorerSqlRuntimeStatsSettings</class>'s.</p>
/// <p><b>Its privilege set</b> is <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter>, beside READ on the namespace's code databases (AD-29). It
/// replaces <code>%CSP.UI.Portal.SQL.QButtons.RuntimeStats</code>, whose custom resource also gates it (AD-44). It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerSqlRuntimeStats Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/sql-runtime-stats",
  "area": "system-explorer",
  "labelKey": "explorerSqlTabRuntimeStats",
  "sideBarPosition": 21,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "sql-runtime-stat",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Routine", "Cursor", "Module"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "purge", "selfProtection": ""}],
  "context": {"fields": ["Routine", "Cursor", "Module", "Runs", "AverageRows", "AverageTime", "Statement"], "secretFields": []},
  "emptyStateKey": "explorerSqlRuntimeStatsEmpty",
  "commandAliases": ["runtime statistics", "sql stats"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "explorerSqlStatementListPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "explorerSqlRuntimeStatsPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "explorerSqlRuntimeStatsPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.SQL.QButtons.RuntimeStats",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "runtime statistics row",
    "label": "Runtime statistics of this namespace, a summary row and one row per module for each statement, with runs and averages per run. Plan with statistics runs the statement without its values, so a filtered query can show zero rows.",
    "source": {"port": "atelier", "endpoint": "Catalog.RuntimeStats", "type": "LIST"},
    "fields": ["Routine", "Cursor", "Module", "Runs", "AverageRows", "AverageGlobalRefs", "AverageCommands", "AverageDiskWait", "AverageTime", "ModuleRuns", "Statement"],
    "filter": ["Routine", "Cursor", "Module", "Statement"],
    "sort": {"fields": ["Routine", "Module", "Runs", "AverageRows", "AverageGlobalRefs", "AverageCommands", "AverageDiskWait", "AverageTime", "ModuleRuns"], "default": "AverageTime", "direction": "desc"},
    "paging": "cap",
    "note": {"key": "explorerSqlRuntimeStatsNote", "text": "Statistics are recorded only while collection is on, and by Plan with statistics on SQL query."}
  },
  "table": {
    "columns": [
      {"field": "Routine", "labelKey": "processColumnRoutine", "kind": "name"},
      {"field": "Cursor", "labelKey": "runtimeStatsColumnCursor", "kind": "text"},
      {"field": "Module", "labelKey": "runtimeStatsColumnModule", "kind": "text"},
      {"field": "Runs", "labelKey": "runtimeStatsColumnRuns", "kind": "number"},
      {"field": "AverageRows", "labelKey": "runtimeStatsColumnAverageRows", "kind": "number"},
      {"field": "AverageGlobalRefs", "labelKey": "runtimeStatsColumnAverageGlobalRefs", "kind": "number"},
      {"field": "AverageCommands", "labelKey": "runtimeStatsColumnAverageCommands", "kind": "number"},
      {"field": "AverageDiskWait", "labelKey": "runtimeStatsColumnAverageDiskWait", "kind": "number"},
      {"field": "AverageTime", "labelKey": "explorerSqlColumnAverageTime", "kind": "number"},
      {"field": "ModuleRuns", "labelKey": "runtimeStatsColumnModuleRuns", "kind": "number"},
      {"field": "Statement", "labelKey": "explorerSqlColumnStatement", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "explorerSqlRuntimeStatsEmptyAgent"
  },
  "toolIdentifier": "explorer.sqlruntimestats"
}
}

}
