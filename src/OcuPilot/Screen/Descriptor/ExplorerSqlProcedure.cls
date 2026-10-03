/// <p>The first of a stored procedure's catalog tabs, Stored procedure info: the procedure's class,
/// type, method, description as plain text, parameter counts and lists, interface, result columns and
/// return value, the classic SQL page's procedure information read through the source code API
/// (<class>OcuPilot.Port.AtelierPort</class>, endpoint <code>Catalog.Procedure</code>) and rendered by
/// the <code>detail</code> archetype's page under the group's tab strip (AD-5, AD-36, AD-61). The
/// description is a row field, untrusted and cut by the per-field bound in a tool result and in screen
/// context (AD-24, AD-60), and shown whole here, as text.</p>
/// <p><b>It heads a parent-scoped tab group</b> (AD-5): it is reached from the SQL procedures list's
/// name cell, never listed (<code>sideBarPosition</code> 0), and its route id is the list row's
/// <code>Procedure</code>, sent as the one criterion <code>procedure</code>; every tab of the group
/// declares the same parent and criterion, and the strip carries the id from tab to tab.</p>
/// <p><b>The procedure is the one the caller's own privileges show it</b>: the port resolves the name
/// through the information schema before it reads, and answers not found otherwise, since the vendor's
/// procedure queries filter nothing by privilege (AD-61 rules 3 and 7). Its privilege set is
/// <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter>, beside READ on the namespace's code
/// databases (AD-29). It replaces <code>%CSP.UI.Portal.SQL.Home</code>, whose custom resource also
/// gates it (AD-44). No action and no refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerSqlProcedure Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/sql-procedures/document",
  "area": "system-explorer",
  "labelKey": "explorerSqlProcedureLabel",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "class",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "system-explorer/sql-procedures",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Class", "Type", "Method", "Description", "Inputs", "InOuts", "Outputs", "Interface", "Columns", "InputParameters", "InOutParameters", "OutputParameters", "ResultColumns", "ReturnValue"], "secretFields": []},
  "emptyStateKey": "explorerSqlProcedureEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlProcedurePrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlProcedurePrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlProcedurePrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.SQL.Home",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "atelier", "endpoint": "Catalog.Procedure", "type": "LIST"},
    "fields": ["Class", "Type", "Method", "Description", "Inputs", "InOuts", "Outputs", "Interface", "Columns", "InputParameters", "InOutParameters", "OutputParameters", "ResultColumns", "ReturnValue"],
    "filter": ["Class", "Method", "Description"],
    "sort": {"fields": ["Class"], "default": "Class", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "procedure", "labelKey": "explorerSqlColumnProcedure", "kind": "text", "maxLength": 257}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Class", "labelKey": "explorerClassDocumentLabel", "kind": "name"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "Method", "labelKey": "explorerSqlColumnMethod", "kind": "identifier"},
      {"field": "Description", "labelKey": "tableColumnDescription", "kind": "text"},
      {"field": "Inputs", "labelKey": "explorerSqlColumnInputs", "kind": "number"},
      {"field": "InOuts", "labelKey": "explorerSqlColumnInOuts", "kind": "number"},
      {"field": "Outputs", "labelKey": "explorerSqlColumnOutputs", "kind": "number"},
      {"field": "Interface", "labelKey": "explorerSqlColumnInterface", "kind": "number"},
      {"field": "Columns", "labelKey": "explorerSqlColumnColumnCount", "kind": "number"},
      {"field": "InputParameters", "labelKey": "explorerSqlColumnInputParameters", "kind": "text"},
      {"field": "InOutParameters", "labelKey": "explorerSqlColumnInOutParameters", "kind": "text"},
      {"field": "OutputParameters", "labelKey": "explorerSqlColumnOutputParameters", "kind": "text"},
      {"field": "ResultColumns", "labelKey": "explorerSqlColumnResultColumns", "kind": "text"},
      {"field": "ReturnValue", "labelKey": "explorerSqlColumnReturnValue", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "system-explorer/sql-procedures/document", "position": 1, "labelKey": "explorerSqlTabProcedureInfo"},
  "toolIdentifier": "explorer.sqlprocedure"
}
}

}
