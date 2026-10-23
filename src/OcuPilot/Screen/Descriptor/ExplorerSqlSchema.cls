/// <p>The first of a SQL schema's tabs, Tables: every table the schema holds that the caller's
/// privileges show it, system tables included, read through the source code API
/// (<class>OcuPilot.Port.AtelierPort</class>, endpoint <code>Catalog.SchemaTables</code>, which sends
/// <code>Catalog.Tables</code>' statement with the system flag on) and rendered by the
/// <code>detail</code> archetype's page under the group's tab strip (AD-5, AD-36, AD-61).</p>
/// <p><b>It heads a parent-scoped tab group</b> (AD-5): it is reached from the SQL schemas list's name
/// cell, never listed (<code>sideBarPosition</code> 0), and its route id is the list row's
/// <code>Schema</code>, sent as the one criterion <code>schema</code>; every tab of the group declares
/// the same parent and criterion, and the strip carries the id from tab to tab. Every member's label
/// is the list's, so the locator reads SQL schemas, then the schema, on each tab.</p>
/// <p><b>A row's name cell opens the table's own screen</b>
/// (<class>OcuPilot.Screen.Descriptor.ExplorerSqlTable</class>), through <code>rowTarget</code> on
/// <code>Table</code>. A schema with no tables reads no rows.</p>
/// <p>Its privilege set is <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter>, beside READ on the
/// namespace's code databases (AD-29). It replaces <code>%CSP.UI.Portal.SQL.Home</code>, whose custom
/// resource also gates it (AD-44). No action and no refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerSqlSchema Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/sql-schemas/document",
  "area": "system-explorer",
  "labelKey": "explorerSqlSchemasLabel",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "class",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "system-explorer/sql-schemas",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Table", "Class", "Owner", "Sharded", "Partitioned"], "secretFields": []},
  "emptyStateKey": "explorerSqlSchemaTablesEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlTablesPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlTablesPrompt3"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "homeStarterPromptExplainScreen"}
  ],
  "classicPage": "%CSP.UI.Portal.SQL.Home",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "atelier", "endpoint": "Catalog.SchemaTables", "type": "LIST"},
    "fields": ["Table", "Schema", "Name", "Class", "Owner", "Sharded", "Partitioned"],
    "filter": ["Table", "Schema", "Class"],
    "sort": {"fields": ["Table", "Class", "Owner"], "default": "Table", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "schema", "labelKey": "explorerSqlColumnSchema", "kind": "text", "maxLength": 128, "hint": "One schema, spelled as explorer.sqlschemas.read answers its Schema."}
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
  "tab": {"group": "system-explorer/sql-schemas/document", "position": 1, "labelKey": "explorerSqlColumnTables"},
  "rowTarget": {"route": "system-explorer/sql-tables/document", "field": "Table"},
  "toolIdentifier": "explorer.sqlschematables"
}
}

}
