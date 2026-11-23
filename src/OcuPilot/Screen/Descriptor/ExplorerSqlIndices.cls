/// <p>A SQL table's Maps/Indices tab: each map or index with its SQL map, columns, type, size,
/// whether it is inherited, its global and its status, read through the source code API
/// (<class>OcuPilot.Port.AtelierPort</class>, endpoint <code>Catalog.Indices</code>) and rendered
/// by the <code>detail</code> archetype's page under the group's tab strip (AD-5, AD-36,
/// AD-61).</p>
/// <p><b>It is one tab of <class>OcuPilot.Screen.Descriptor.ExplorerSqlTable</class>'s parent-scoped
/// group</b> (AD-5): unlisted, its route id is the SQL tables list row's <code>Table</code>, sent as
/// the one criterion <code>table</code>.</p>
/// <p><b>The table is the one the caller's own privileges show it</b>: the port resolves the name
/// through the information schema before it reads, and answers not found otherwise (AD-61 rule 7).
/// Its privilege set is <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter>, beside READ on the
/// namespace's code databases (AD-29). It replaces <code>%CSP.UI.Portal.SQL.Home</code>, whose
/// custom resource also gates it (AD-44). It does not refresh (AD-43).</p>
/// <p><b>Its entity type is <code>sql-index</code></b> (Story 21.25): a row's id is the composite <code>[Table, Map]</code>, its <code>Table</code> the
/// one the port names on each row, and the target of <code>rebuild</code>, carried out by
/// <class>OcuPilot.Screen.Tool.ExplorerSqlIndexRebuild</class> for both callers (AD-53). The table's data map has no index to rebuild, and an
/// index of one of OcuPilot's own tables is refused for both.</p>
Class OcuPilot.Screen.Descriptor.ExplorerSqlIndices Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/sql-tables/indices",
  "area": "system-explorer",
  "labelKey": "explorerSqlTabIndices",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "sql-index",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "system-explorer/sql-tables",
  "id": {"kind": "composite", "parts": ["Table", "Map"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "rebuild", "selfProtection": ""}],
  "context": {"fields": ["Table", "Index", "Map", "Fields", "Type", "SizeMB", "Inherited", "Global", "Status"], "secretFields": []},
  "emptyStateKey": "explorerSqlIndicesEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlIndicesPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlIndicesPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlIndicesPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.SQL.Home",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "map or index of one SQL table",
    "source": {"port": "atelier", "endpoint": "Catalog.Indices", "type": "LIST"},
    "fields": ["Table", "Index", "Map", "Fields", "Type", "BitmapArgument", "SizeMB", "Inherited", "Global", "Status"],
    "filter": ["Index", "Map", "Fields", "Global"],
    "sort": {"fields": ["Index", "Map", "Type"], "default": "Index", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "table", "labelKey": "explorerSqlColumnTable", "kind": "text", "maxLength": 257, "hint": "One table, as Schema.Table, spelled as explorer.sqltables.read answers its Table."}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Index", "labelKey": "explorerSqlColumnIndex", "kind": "name"},
      {"field": "Map", "labelKey": "explorerSqlColumnMap", "kind": "identifier"},
      {"field": "Fields", "labelKey": "explorerSqlColumnColumns", "kind": "text"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "SizeMB", "labelKey": "databaseSizeField", "kind": "text"},
      {"field": "Inherited", "labelKey": "explorerSqlColumnInherited", "kind": "status"},
      {"field": "Global", "labelKey": "explorerSqlColumnGlobal", "kind": "identifier"},
      {"field": "Status", "labelKey": "taskHistoryColumnStatus", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "explorerSqlTableMaintenanceEmptyAgent"
  },
  "tab": {"group": "system-explorer/sql-tables/document", "position": 3, "labelKey": "explorerSqlTabIndices"},
  "toolIdentifier": "explorer.sqlindices"
}
}

}
