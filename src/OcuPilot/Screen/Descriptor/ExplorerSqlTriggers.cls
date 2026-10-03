/// <p>A SQL table's Triggers tab: each trigger's time and event, order and code, read through the
/// source code API (<class>OcuPilot.Port.AtelierPort</class>, endpoint
/// <code>Catalog.Triggers</code>) and rendered by the <code>detail</code> archetype's page under
/// the group's tab strip (AD-5, AD-36, AD-61). A trigger's code is a row field, untrusted and cut
/// by the per-field bound like any other value (AD-24, AD-60), and renders as text.</p>
/// <p><b>It is one tab of <class>OcuPilot.Screen.Descriptor.ExplorerSqlTable</class>'s parent-scoped
/// group</b> (AD-5): unlisted, its route id is the SQL tables list row's <code>Table</code>, sent as
/// the one criterion <code>table</code>.</p>
/// <p><b>The table is the one the caller's own privileges show it</b>: the port resolves the name
/// through the information schema before it reads, and answers not found otherwise (AD-61 rule 7).
/// Its privilege set is <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter>, beside READ on the
/// namespace's code databases (AD-29). It replaces <code>%CSP.UI.Portal.SQL.Home</code>, whose
/// custom resource also gates it (AD-44). No action and no refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerSqlTriggers Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/sql-tables/triggers",
  "area": "system-explorer",
  "labelKey": "explorerSqlTabTriggers",
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
  "context": {"fields": ["Trigger", "Event", "Order", "Code"], "secretFields": []},
  "emptyStateKey": "explorerSqlTriggersEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlTriggersPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlTriggersPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlTriggersPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.SQL.Home",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "atelier", "endpoint": "Catalog.Triggers", "type": "LIST"},
    "fields": ["Trigger", "Event", "Order", "Code"],
    "filter": ["Trigger", "Event", "Code"],
    "sort": {"fields": ["Trigger", "Event", "Order"], "default": "Trigger", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "table", "labelKey": "explorerSqlColumnTable", "kind": "text", "maxLength": 257}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Trigger", "labelKey": "explorerSqlColumnTrigger", "kind": "name"},
      {"field": "Event", "labelKey": "explorerSqlColumnEvent", "kind": "text"},
      {"field": "Order", "labelKey": "explorerSqlColumnOrder", "kind": "number"},
      {"field": "Code", "labelKey": "webAppPromptGroupCode", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "system-explorer/sql-tables/document", "position": 6, "labelKey": "explorerSqlTabTriggers"},
  "toolIdentifier": "explorer.sqltriggers"
}
}

}
