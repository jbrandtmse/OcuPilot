/// <p>System Explorer's SQL procedures list: the stored procedures and functions the route's
/// namespace holds that the caller's privileges show it, read through the source code API
/// (<class>OcuPilot.Port.AtelierPort</class>, endpoint <code>Catalog.Procedures</code>) and rendered
/// by the <code>list (server criteria)</code> archetype's page (AD-5, AD-36, AD-61).</p>
/// <p><b>Its criteria are the classic SQL page's System box and a schema</b>: <code>system</code>
/// <code>no</code>, its default, keeps no <code>%</code> or <code>INFORMATION_SCHEMA</code>
/// procedure, and <code>schema</code> keeps one schema's. A procedure's definition is never read.</p>
/// <p><b>Its privilege set is <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter></b>; the port
/// also requires READ on the namespace's code databases, resolved at call time (AD-29, AD-61). It
/// replaces <code>%CSP.UI.Portal.SQL.Home</code>, whose custom resource also gates it (AD-44). No
/// action and no refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerSqlProcedures Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/sql-procedures",
  "area": "system-explorer",
  "labelKey": "explorerSqlProceduresLabel",
  "sideBarPosition": 9,
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
  "context": {"fields": ["Procedure", "Type", "Class", "Method"], "secretFields": []},
  "emptyStateKey": "explorerSqlProceduresEmpty",
  "commandAliases": ["sql procedures", "stored procedures"],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlProceduresPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlProceduresPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlProceduresPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.SQL.Home",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "atelier", "endpoint": "Catalog.Procedures", "type": "LIST"},
    "fields": ["Procedure", "Schema", "Name", "Type", "Class", "Method"],
    "filter": ["Procedure", "Schema", "Class"],
    "sort": {"fields": ["Procedure", "Type", "Class"], "default": "Procedure", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "system", "labelKey": "explorerSystemLabel", "kind": "choice", "maxLength": 3, "options": ["yes", "no"], "default": "no"},
        {"param": "schema", "labelKey": "explorerSqlColumnSchema", "kind": "text", "maxLength": 128}
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
  "toolIdentifier": "explorer.sqlprocedures"
}
}

}
