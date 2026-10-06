/// <p>A SQL table's Fields tab: each column's type, number, required, unique and hidden flags,
/// collation, bounds, stream flag, xDBC type, referenced table, version flag and selectivity, and
/// never a field's data values, read through the source code API
/// (<class>OcuPilot.Port.AtelierPort</class>, endpoint <code>Catalog.Fields</code>) and rendered by
/// the <code>detail</code> archetype's page under the group's tab strip (AD-5, AD-36, AD-61).</p>
/// <p><b>It is one tab of <class>OcuPilot.Screen.Descriptor.ExplorerSqlTable</class>'s parent-scoped
/// group</b> (AD-5): unlisted, its route id is the SQL tables list row's <code>Table</code>, sent as
/// the one criterion <code>table</code>.</p>
/// <p><b>The table is the one the caller's own privileges show it</b>: the port resolves the name
/// through the information schema before it reads, and answers not found otherwise (AD-61 rule 7).
/// Its privilege set is <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter>, beside READ on the
/// namespace's code databases (AD-29). It replaces <code>%CSP.UI.Portal.SQL.Home</code>, whose
/// custom resource also gates it (AD-44). No action and no refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerSqlFields Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/sql-tables/fields",
  "area": "system-explorer",
  "labelKey": "explorerSqlTabFields",
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
  "context": {"fields": ["Field", "Type", "Column", "Required", "Unique", "Collation", "Hidden", "MaxLength", "ReferenceTo", "Selectivity"], "secretFields": []},
  "emptyStateKey": "explorerSqlFieldsEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlFieldsPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlFieldsPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlFieldsPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.SQL.Home",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "atelier", "endpoint": "Catalog.Fields", "type": "LIST"},
    "fields": ["Field", "Type", "Column", "Required", "Unique", "Collation", "Hidden", "MaxLength", "MinValue", "MaxValue", "Stream", "XdbcType", "ReferenceTo", "VersionColumn", "Selectivity"],
    "filter": ["Field", "Type", "ReferenceTo"],
    "sort": {"fields": ["Column", "Field", "Type"], "default": "Column", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "table", "labelKey": "explorerSqlColumnTable", "kind": "text", "maxLength": 257, "hint": "One table, as Schema.Table, spelled as explorer.sqltables.read answers its Table."}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Field", "labelKey": "explorerSqlColumnField", "kind": "name"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "identifier"},
      {"field": "Column", "labelKey": "explorerSqlColumnNumber", "kind": "number"},
      {"field": "Required", "labelKey": "openApiRequired", "kind": "status"},
      {"field": "Unique", "labelKey": "explorerSqlColumnUnique", "kind": "status"},
      {"field": "Collation", "labelKey": "mappingColumnCollation", "kind": "text"},
      {"field": "Hidden", "labelKey": "explorerSqlColumnHidden", "kind": "status"},
      {"field": "MaxLength", "labelKey": "explorerSqlColumnMaxLength", "kind": "number"},
      {"field": "ReferenceTo", "labelKey": "explorerSqlColumnReferenceTo", "kind": "identifier"},
      {"field": "Selectivity", "labelKey": "explorerSqlColumnSelectivity", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "system-explorer/sql-tables/document", "position": 2, "labelKey": "explorerSqlTabFields"},
  "toolIdentifier": "explorer.sqlfields"
}
}

}
