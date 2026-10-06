/// <p>The first of a SQL table's catalog tabs, Table info: the table's owner, last compile,
/// external and read-only flags, partitioning, class and extent size, the table's row of the classic
/// SQL page's tables query (<code>TablesOnly</code>), read through the source code API
/// (<class>OcuPilot.Port.AtelierPort</class>, endpoint <code>Catalog.Table</code>) and rendered by
/// the <code>detail</code> archetype's page under the group's tab strip (AD-5, AD-36, AD-61).</p>
/// <p><b>It heads a parent-scoped tab group</b> (AD-5): it is reached from the SQL tables list's name
/// cell, never listed (<code>sideBarPosition</code> 0), and its route id is the list row's
/// <code>Table</code>, sent as the one criterion <code>table</code>; every tab of the group declares the
/// same parent and criterion, and the strip carries the id from tab to tab.</p>
/// <p><b>The table is the one the caller's own privileges show it</b>: the port resolves the name
/// through the information schema before it reads, and answers not found otherwise (AD-61 rule 7).
/// Its privilege set is <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter>, beside READ on the
/// namespace's code databases (AD-29). It replaces <code>%CSP.UI.Portal.SQL.Home</code>, whose
/// custom resource also gates it (AD-44). No action and no refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerSqlTable Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/sql-tables/document",
  "area": "system-explorer",
  "labelKey": "explorerSqlTableLabel",
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
  "context": {"fields": ["Name", "Owner", "LastCompiled", "External", "ReadOnly", "Partitioned", "Class", "ExtentSize", "ExternalType"], "secretFields": []},
  "emptyStateKey": "explorerSqlTableEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlTablePrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlTablePrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlTablePrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.SQL.Home",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "atelier", "endpoint": "Catalog.Table", "type": "LIST"},
    "fields": ["Name", "Owner", "LastCompiled", "External", "ReadOnly", "Partitioned", "Class", "ExtentSize", "ExternalType"],
    "filter": ["Name", "Class"],
    "sort": {"fields": ["Name"], "default": "Name", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "table", "labelKey": "explorerSqlColumnTable", "kind": "text", "maxLength": 257, "hint": "One table, as Schema.Table, spelled as explorer.sqltables.read answers its Table."}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Owner", "labelKey": "explorerSqlColumnOwner", "kind": "text"},
      {"field": "LastCompiled", "labelKey": "explorerSqlColumnLastCompiled", "kind": "text"},
      {"field": "External", "labelKey": "explorerSqlColumnExternal", "kind": "status"},
      {"field": "ReadOnly", "labelKey": "agentDefinitionFieldReadOnly", "kind": "status"},
      {"field": "Partitioned", "labelKey": "explorerSqlColumnPartitioned", "kind": "status"},
      {"field": "Class", "labelKey": "explorerClassDocumentLabel", "kind": "identifier"},
      {"field": "ExtentSize", "labelKey": "explorerSqlColumnExtentSize", "kind": "number"},
      {"field": "ExternalType", "labelKey": "explorerSqlColumnExternalType", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "system-explorer/sql-tables/document", "position": 1, "labelKey": "explorerSqlTabInfo"},
  "toolIdentifier": "explorer.sqltable"
}
}

}
