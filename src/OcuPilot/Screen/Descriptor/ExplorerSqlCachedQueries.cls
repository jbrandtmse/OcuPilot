/// <p>A SQL table's Cached queries tab: each cached query on the table that the caller may run, its
/// routine, text, creation time, source flag, type and statement features, the classic SQL page's
/// cached query list read through the source code API (<class>OcuPilot.Port.AtelierPort</class>,
/// endpoint <code>Catalog.CachedQueries</code>) and rendered by the <code>detail</code> archetype's
/// page under the group's tab strip (AD-5, AD-36, AD-61). A cached query's text is a row field,
/// untrusted and cut by the per-field bound like any other value (AD-24, AD-60), and renders as
/// text.</p>
/// <p><b>It is one tab of <class>OcuPilot.Screen.Descriptor.ExplorerSqlTable</class>'s parent-scoped
/// group</b> (AD-5): unlisted, its route id is the SQL tables list row's <code>Table</code>, sent as
/// the one criterion <code>table</code>.</p>
/// <p><b>The table is the one the caller's own privileges show it</b>: the port resolves the name
/// through the information schema before it reads, and answers not found otherwise (AD-61 rule 7).
/// Its privilege set is <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter>, beside READ on the
/// namespace's code databases (AD-29). It replaces <code>%CSP.UI.Portal.SQL.Home</code>, whose
/// custom resource also gates it (AD-44). No action and no refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerSqlCachedQueries Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/sql-tables/cached-queries",
  "area": "system-explorer",
  "labelKey": "explorerSqlTabCachedQueries",
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
  "context": {"fields": ["CachedQuery", "Query", "Created", "Source", "QueryType", "Features"], "secretFields": []},
  "emptyStateKey": "explorerSqlCachedQueriesEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlCachedQueriesPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlCachedQueriesPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlCachedQueriesPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.SQL.Home",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "atelier", "endpoint": "Catalog.CachedQueries", "type": "LIST"},
    "fields": ["CachedQuery", "Query", "Created", "Source", "QueryType", "Features"],
    "filter": ["CachedQuery", "Query", "QueryType"],
    "sort": {"fields": ["CachedQuery", "Created", "QueryType"], "default": "CachedQuery", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "table", "labelKey": "explorerSqlColumnTable", "kind": "text", "maxLength": 257, "hint": "One table, as Schema.Table, spelled as explorer.sqltables.read answers its Table."}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "CachedQuery", "labelKey": "explorerSqlColumnCachedQuery", "kind": "name"},
      {"field": "Query", "labelKey": "auditSqlKindQuery", "kind": "text"},
      {"field": "Created", "labelKey": "journalColumnCreated", "kind": "text"},
      {"field": "Source", "labelKey": "auditEventFieldSource", "kind": "status"},
      {"field": "QueryType", "labelKey": "explorerSqlColumnQueryType", "kind": "text"},
      {"field": "Features", "labelKey": "explorerSqlColumnFeatures", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "system-explorer/sql-tables/document", "position": 8, "labelKey": "explorerSqlTabCachedQueries"},
  "toolIdentifier": "explorer.sqlcachedqueries"
}
}

}
