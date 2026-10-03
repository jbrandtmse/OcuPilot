/// <p>A SQL view's Fields tab: each column of the view the caller may see, its type, collation,
/// length, precision, scale and whether it is a stream, the classic SQL page's view fields query read
/// through the source code API (<class>OcuPilot.Port.AtelierPort</class>, endpoint
/// <code>Catalog.ViewFields</code>) and rendered by the <code>detail</code> archetype's page under the
/// group's tab strip (AD-5, AD-36, AD-61).</p>
/// <p><b>It is one tab of <class>OcuPilot.Screen.Descriptor.ExplorerSqlView</class>'s parent-scoped
/// group</b> (AD-5): unlisted, its route id is the SQL views list row's <code>View</code>, sent as the
/// one criterion <code>view</code>.</p>
/// <p><b>The view is the one the caller's own privileges show it</b>: the port resolves the name
/// through the information schema before it reads, and answers not found otherwise, since the vendor's
/// view information queries filter nothing by privilege (AD-61 rules 3 and 7). Its privilege set is
/// <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter>, beside READ on the namespace's code
/// databases (AD-29). It replaces <code>%CSP.UI.Portal.SQL.Home</code>, whose custom resource also
/// gates it (AD-44). No action and no refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerSqlViewFields Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/sql-views/fields",
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
  "parentScope": "system-explorer/sql-views",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Field", "Type", "Collation", "MaxLength", "Length", "Precision", "Scale", "Stream"], "secretFields": []},
  "emptyStateKey": "explorerSqlViewFieldsEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlViewFieldsPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlViewFieldsPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlViewFieldsPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.SQL.Home",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "atelier", "endpoint": "Catalog.ViewFields", "type": "LIST"},
    "fields": ["Field", "Type", "Collation", "MaxLength", "MaxValue", "MinValue", "Stream", "Length", "Precision", "Scale"],
    "filter": ["Field", "Type"],
    "sort": {"fields": ["Field", "Type"], "default": "Field", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "view", "labelKey": "viewMenuLabel", "kind": "text", "maxLength": 257}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Field", "labelKey": "explorerSqlColumnField", "kind": "name"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "identifier"},
      {"field": "Collation", "labelKey": "mappingColumnCollation", "kind": "text"},
      {"field": "MaxLength", "labelKey": "explorerSqlColumnMaxLength", "kind": "number"},
      {"field": "Length", "labelKey": "explorerSqlColumnLength", "kind": "number"},
      {"field": "Precision", "labelKey": "explorerSqlColumnPrecision", "kind": "number"},
      {"field": "Scale", "labelKey": "explorerSqlColumnScale", "kind": "number"},
      {"field": "Stream", "labelKey": "explorerSqlColumnStream", "kind": "status"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "system-explorer/sql-views/document", "position": 2, "labelKey": "explorerSqlTabFields"},
  "toolIdentifier": "explorer.sqlviewfields"
}
}

}
