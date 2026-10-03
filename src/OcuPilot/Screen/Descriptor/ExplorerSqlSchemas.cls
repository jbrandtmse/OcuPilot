/// <p>System Explorer's SQL schemas list: the schemas the route's namespace holds that the caller's
/// privileges show it, each with whether it holds tables, views and procedures, read through the
/// source code API (<class>OcuPilot.Port.AtelierPort</class>, endpoint <code>Catalog.Schemas</code>)
/// and rendered by the <code>list (server criteria)</code> archetype's page (AD-5, AD-36, AD-61).</p>
/// <p><b>Its one criterion is the classic SQL page's System box</b>: <code>system</code>
/// <code>no</code>, its default, keeps no <code>%</code> or <code>INFORMATION_SCHEMA</code>
/// schema.</p>
/// <p><b>Its privilege set is <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter></b>; the port
/// also requires READ on the namespace's code databases, resolved at call time (AD-29, AD-61). It
/// replaces <code>%CSP.UI.Portal.SQL.Home</code>, whose custom resource also gates it (AD-44). No
/// action and no refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerSqlSchemas Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/sql-schemas",
  "area": "system-explorer",
  "labelKey": "explorerSqlSchemasLabel",
  "sideBarPosition": 6,
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
  "context": {"fields": ["Schema", "Tables", "Views", "Procedures"], "secretFields": []},
  "emptyStateKey": "explorerSqlSchemasEmpty",
  "commandAliases": ["sql schemas", "schemas"],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlSchemasPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlSchemasPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlSchemasPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.SQL.Home",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "atelier", "endpoint": "Catalog.Schemas", "type": "LIST"},
    "fields": ["Schema", "Tables", "Views", "Procedures"],
    "filter": ["Schema"],
    "sort": {"fields": ["Schema"], "default": "Schema", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "system", "labelKey": "explorerSystemLabel", "kind": "choice", "maxLength": 3, "options": ["yes", "no"], "default": "no"}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Schema", "labelKey": "explorerSqlColumnSchema", "kind": "name"},
      {"field": "Tables", "labelKey": "explorerSqlColumnTables", "kind": "status"},
      {"field": "Views", "labelKey": "explorerSqlColumnViews", "kind": "status"},
      {"field": "Procedures", "labelKey": "explorerSqlColumnProcedures", "kind": "status"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "explorer.sqlschemas"
}
}

}
