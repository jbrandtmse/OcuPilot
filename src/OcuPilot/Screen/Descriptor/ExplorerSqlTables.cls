/// <p>System Explorer's SQL tables list: the tables the route's namespace holds that the caller's
/// privileges show it, read through the source code API (<class>OcuPilot.Port.AtelierPort</class>,
/// endpoint <code>Catalog.Tables</code>) and rendered by the <code>list (server criteria)</code>
/// archetype's page (AD-5, AD-36, AD-61).</p>
/// <p><b>Its criteria are the classic SQL page's System box and a schema</b>: <code>system</code>
/// <code>no</code>, its default, keeps no system table, and <code>schema</code> keeps one schema's
/// tables.</p>
/// <p><b>Its id is the row's <code>Table</code></b>, <code>Schema.Name</code>, which the name cell
/// carries to the table's catalog tabs
/// (<class>OcuPilot.Screen.Descriptor.ExplorerSqlTable</class>, the parent-scoped group at this
/// route plus <code>/document</code>).</p>
/// <p><b>Its privilege set is <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter></b>; the port
/// also requires READ on the namespace's code databases, resolved at call time (AD-29, AD-61). It
/// replaces <code>%CSP.UI.Portal.SQL.Home</code>, whose custom resource also gates it (AD-44). No
/// action and no refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerSqlTables Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/sql-tables",
  "area": "system-explorer",
  "labelKey": "explorerSqlTablesLabel",
  "sideBarPosition": 7,
  "archetype": "list (server criteria)",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "class",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Table", "Class", "Owner", "Sharded", "Partitioned"], "secretFields": []},
  "emptyStateKey": "explorerSqlTablesEmpty",
  "commandAliases": ["sql tables", "tables"],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlTablesPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlTablesPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlTablesPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.SQL.Home",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "atelier", "endpoint": "Catalog.Tables", "type": "LIST"},
    "fields": ["Table", "Schema", "Name", "Class", "Owner", "Sharded", "Partitioned"],
    "filter": ["Table", "Schema", "Class"],
    "sort": {"fields": ["Table", "Class", "Owner"], "default": "Table", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "system", "labelKey": "explorerSystemLabel", "kind": "choice", "maxLength": 3, "options": ["yes", "no"], "default": "no"},
        {"param": "schema", "labelKey": "explorerSqlColumnSchema", "kind": "text", "maxLength": 128, "hint": "One schema, spelled as explorer.sqlschemas.read answers its Schema; omit it to list every schema's tables."}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Table", "labelKey": "explorerSqlColumnTable", "kind": "name"},
      {"field": "Class", "labelKey": "explorerClassDocumentLabel", "kind": "identifier"},
      {"field": "Owner", "labelKey": "explorerSqlColumnOwner", "kind": "text"},
      {"field": "Sharded", "labelKey": "explorerSqlColumnSharded", "kind": "status"},
      {"field": "Partitioned", "labelKey": "explorerSqlColumnPartitioned", "kind": "status"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "explorer.sqltables"
}
}

}
