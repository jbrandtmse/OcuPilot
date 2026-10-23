/// <p>A SQL schema's Views tab: every view the schema holds that the caller's privileges show it,
/// system views included, read through the source code API
/// (<class>OcuPilot.Port.AtelierPort</class>, endpoint <code>Catalog.SchemaViews</code>, which sends
/// <code>Catalog.Views</code>' statement with the system flag on) and rendered by the
/// <code>detail</code> archetype's page under the group's tab strip (AD-5, AD-36, AD-61).</p>
/// <p><b>It is one tab of <class>OcuPilot.Screen.Descriptor.ExplorerSqlSchema</class>'s parent-scoped
/// group</b> (AD-5): unlisted, its route id is the SQL schemas list row's <code>Schema</code>, sent as
/// the one criterion <code>schema</code>.</p>
/// <p><b>A row's name cell opens the view's own screen</b>
/// (<class>OcuPilot.Screen.Descriptor.ExplorerSqlView</class>), through <code>rowTarget</code> on
/// <code>View</code>. A schema with no views reads no rows.</p>
/// <p>Its privilege set is <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter>, beside READ on the
/// namespace's code databases (AD-29). It replaces <code>%CSP.UI.Portal.SQL.Home</code>, whose custom
/// resource also gates it (AD-44). No action and no refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerSqlSchemaViews Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/sql-schemas/views",
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
  "context": {"fields": ["View", "Class", "Owner", "Updatable", "CheckOption"], "secretFields": []},
  "emptyStateKey": "explorerSqlSchemaViewsEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlViewsPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlViewsPrompt3"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "homeStarterPromptExplainScreen"}
  ],
  "classicPage": "%CSP.UI.Portal.SQL.Home",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "atelier", "endpoint": "Catalog.SchemaViews", "type": "LIST"},
    "fields": ["View", "Schema", "Name", "Class", "Owner", "Updatable", "CheckOption"],
    "filter": ["View", "Schema", "Class"],
    "sort": {"fields": ["View", "Class", "Owner"], "default": "View", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "schema", "labelKey": "explorerSqlColumnSchema", "kind": "text", "maxLength": 128, "hint": "One schema, spelled as explorer.sqlschemas.read answers its Schema."}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "View", "labelKey": "viewMenuLabel", "kind": "name"},
      {"field": "Class", "labelKey": "explorerClassDocumentLabel", "kind": "identifier"},
      {"field": "Owner", "labelKey": "explorerSqlColumnOwner", "kind": "text"},
      {"field": "Updatable", "labelKey": "explorerSqlColumnUpdatable", "kind": "status"},
      {"field": "CheckOption", "labelKey": "explorerSqlColumnCheckOption", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "system-explorer/sql-schemas/document", "position": 2, "labelKey": "explorerSqlColumnViews"},
  "rowTarget": {"route": "system-explorer/sql-views/document", "field": "View"},
  "toolIdentifier": "explorer.sqlschemaviews"
}
}

}
