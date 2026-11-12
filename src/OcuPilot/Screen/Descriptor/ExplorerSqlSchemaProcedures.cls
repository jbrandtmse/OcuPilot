/// <p>A SQL schema's Procedures tab: every stored procedure and function the schema holds that the
/// caller's privileges show it, system ones included, read through the source code API
/// (<class>OcuPilot.Port.AtelierPort</class>, endpoint <code>Catalog.SchemaProcedures</code>, which
/// sends <code>Catalog.Procedures</code>' statement with the system flag on) and rendered by the
/// <code>detail</code> archetype's page under the group's tab strip (AD-5, AD-36, AD-61).</p>
/// <p><b>It is one tab of <class>OcuPilot.Screen.Descriptor.ExplorerSqlSchema</class>'s parent-scoped
/// group</b> (AD-5): unlisted, its route id is the SQL schemas list row's <code>Schema</code>, sent as
/// the one criterion <code>schema</code>.</p>
/// <p><b>A row's name cell opens the procedure's own screen</b>
/// (<class>OcuPilot.Screen.Descriptor.ExplorerSqlProcedure</class>), through <code>rowTarget</code> on
/// <code>Procedure</code>. A schema with no procedures reads no rows.</p>
/// <p>Its privilege set is <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter>, beside READ on the
/// namespace's code databases (AD-29). It replaces <code>%CSP.UI.Portal.SQL.Home</code>, whose custom
/// resource also gates it (AD-44). No action and no refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerSqlSchemaProcedures Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/sql-schemas/procedures",
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
  "context": {"fields": ["Procedure", "Type", "Class", "Method"], "secretFields": []},
  "emptyStateKey": "explorerSqlSchemaProceduresEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlProceduresPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlProceduresPrompt3"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "homeStarterPromptExplainScreen"}
  ],
  "classicPage": "%CSP.UI.Portal.SQL.Home",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "procedure or function of one schema",
    "label": "Stored procedures and functions of one schema, named by its criterion, system ones included; those across every schema are in explorer.sqlprocedures.",
    "source": {"port": "atelier", "endpoint": "Catalog.SchemaProcedures", "type": "LIST"},
    "fields": ["Procedure", "Schema", "Name", "Type", "Class", "Method"],
    "filter": ["Procedure", "Schema", "Class"],
    "sort": {"fields": ["Procedure", "Type", "Class"], "default": "Procedure", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "schema", "labelKey": "explorerSqlColumnSchema", "kind": "text", "maxLength": 128, "hint": "One schema, spelled as explorer.sqlschemas.read answers its Schema."}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Procedure", "labelKey": "explorerSqlColumnProcedure", "kind": "name"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "Class", "labelKey": "explorerClassDocumentLabel", "kind": "identifier"},
      {"field": "Method", "labelKey": "explorerSqlColumnMethod", "kind": "identifier"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "system-explorer/sql-schemas/document", "position": 3, "labelKey": "explorerSqlColumnProcedures"},
  "rowTarget": {"route": "system-explorer/sql-procedures/document", "field": "Procedure"},
  "toolIdentifier": "explorer.sqlschemaprocedures"
}
}

}
