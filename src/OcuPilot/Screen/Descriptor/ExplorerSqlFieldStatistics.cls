/// <p>A SQL table's Field statistics tab (Story 21.25): each field's collected selectivity, outlier value, outlier selectivity and average size, beside the
/// fixed ones the table holds, which the optimizer uses in place of them, the join the classic Tune Table window draws
/// (<code>%CSP.UI.Portal.SQL.TuneTable</code>), read through the source code API (<class>OcuPilot.Port.AtelierPort</class>, endpoint
/// <code>Catalog.FieldStatistics</code>) and rendered by the <code>detail</code> archetype's page under the group's tab strip (AD-5, AD-36, AD-61).</p>
/// <p><b>It is one tab of <class>OcuPilot.Screen.Descriptor.ExplorerSqlTable</class>'s parent-scoped group</b> (AD-5): unlisted, its route id is the SQL
/// tables list row's <code>Table</code>, sent as the one criterion <code>table</code>. The tab and the agent's read answer the same rows.</p>
/// <p><b>The table is the one the caller's own privileges show it</b>: the port resolves the name through the information schema before it reads, and
/// answers not found otherwise (AD-61 rule 7). Its privilege set is <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter>, beside READ on the
/// namespace's code databases (AD-29). It replaces <code>%CSP.UI.Portal.SQL.TuneTable</code>, whose custom resource also gates it (AD-44). It is a read:
/// no action and no refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerSqlFieldStatistics Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/sql-tables/field-statistics",
  "area": "system-explorer",
  "labelKey": "explorerSqlTabFieldStatistics",
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
  "context": {"fields": ["Field", "Selectivity", "OutlierValue", "OutlierSelectivity", "AverageFieldSize", "FixedSelectivity", "FixedOutlierValue", "FixedOutlierSelectivity", "FixedAverageFieldSize"], "secretFields": []},
  "emptyStateKey": "explorerSqlFieldStatisticsEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlFieldStatisticsPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlFieldStatisticsPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlFieldStatisticsPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.SQL.TuneTable",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "field statistics of one SQL table",
    "source": {"port": "atelier", "endpoint": "Catalog.FieldStatistics", "type": "LIST"},
    "fields": ["Field", "Selectivity", "OutlierValue", "OutlierSelectivity", "AverageFieldSize", "FixedSelectivity", "FixedOutlierValue", "FixedOutlierSelectivity", "FixedAverageFieldSize"],
    "filter": ["Field", "Selectivity", "FixedSelectivity"],
    "sort": {"fields": ["Field", "Selectivity", "FixedSelectivity"], "default": "Field", "direction": "asc"},
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
      {"field": "Selectivity", "labelKey": "explorerSqlColumnSelectivity", "kind": "text"},
      {"field": "OutlierValue", "labelKey": "explorerSqlColumnOutlierValue", "kind": "text"},
      {"field": "OutlierSelectivity", "labelKey": "explorerSqlColumnOutlierSelectivity", "kind": "text"},
      {"field": "AverageFieldSize", "labelKey": "explorerSqlColumnAverageFieldSize", "kind": "number"},
      {"field": "FixedSelectivity", "labelKey": "explorerSqlColumnFixedSelectivity", "kind": "text"},
      {"field": "FixedOutlierValue", "labelKey": "explorerSqlColumnFixedOutlierValue", "kind": "text"},
      {"field": "FixedOutlierSelectivity", "labelKey": "explorerSqlColumnFixedOutlierSelectivity", "kind": "text"},
      {"field": "FixedAverageFieldSize", "labelKey": "explorerSqlColumnFixedAverageFieldSize", "kind": "number"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "system-explorer/sql-tables/document", "position": 10, "labelKey": "explorerSqlTabFieldStatistics"},
  "toolIdentifier": "explorer.sqlfieldstatistics"
}
}

}
