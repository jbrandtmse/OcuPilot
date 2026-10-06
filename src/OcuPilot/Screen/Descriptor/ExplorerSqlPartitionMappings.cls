/// <p>A SQL table's Partition mappings tab: each mapping rule's buckets, rows, estimated size and
/// target, the classic SQL page's partition mappings query read through the source code API
/// (<class>OcuPilot.Port.AtelierPort</class>, endpoint <code>Catalog.PartitionMappings</code>) and
/// rendered by the <code>detail</code> archetype's page under the group's tab strip (AD-5, AD-36,
/// AD-61). The port sends the query only for a table its resolve reads as partitioned; any other
/// table reads no rows.</p>
/// <p><b>It is one tab of <class>OcuPilot.Screen.Descriptor.ExplorerSqlTable</class>'s parent-scoped
/// group</b> (AD-5): unlisted, its route id is the SQL tables list row's <code>Table</code>, sent as
/// the one criterion <code>table</code>.</p>
/// <p><b>The table is the one the caller's own privileges show it</b>: the port resolves the name
/// through the information schema before it reads, and answers not found otherwise (AD-61 rule 7).
/// Its privilege set is <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter>, beside READ on the
/// namespace's code databases (AD-29). It replaces <code>%CSP.UI.Portal.SQL.Home</code>, whose
/// custom resource also gates it (AD-44). No action and no refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerSqlPartitionMappings Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/sql-tables/partition-mappings",
  "area": "system-explorer",
  "labelKey": "explorerSqlTabPartitionMappings",
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
  "context": {"fields": ["Rule", "Buckets", "Rows", "EstimatedSize", "Location"], "secretFields": []},
  "emptyStateKey": "explorerSqlPartitionMappingsEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlPartitionMappingsPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlPartitionMappingsPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlPartitionMappingsPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.SQL.Home",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "atelier", "endpoint": "Catalog.PartitionMappings", "type": "LIST"},
    "fields": ["Rule", "Buckets", "Rows", "EstimatedSize", "Location"],
    "filter": ["Rule", "Location"],
    "sort": {"fields": ["Rule", "Rows", "EstimatedSize"], "default": "Rule", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "table", "labelKey": "explorerSqlColumnTable", "kind": "text", "maxLength": 257, "hint": "One table, as Schema.Table, spelled as explorer.sqltables.read answers its Table."}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Rule", "labelKey": "explorerSqlColumnRule", "kind": "name"},
      {"field": "Buckets", "labelKey": "explorerSqlColumnBuckets", "kind": "number"},
      {"field": "Rows", "labelKey": "explorerSqlColumnRows", "kind": "number"},
      {"field": "EstimatedSize", "labelKey": "explorerSqlColumnEstimatedSize", "kind": "number"},
      {"field": "Location", "labelKey": "processDetailsLocation", "kind": "identifier"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "system-explorer/sql-tables/document", "position": 5, "labelKey": "explorerSqlTabPartitionMappings"},
  "toolIdentifier": "explorer.sqlpartitionmappings"
}
}

}
