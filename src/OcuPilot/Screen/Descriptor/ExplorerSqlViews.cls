/// <p>System Explorer's SQL views list: the views the route's namespace holds that the caller's
/// privileges show it, read through the source code API (<class>OcuPilot.Port.AtelierPort</class>,
/// endpoint <code>Catalog.Views</code>) and rendered by the <code>list (server criteria)</code>
/// archetype's page (AD-5, AD-36, AD-61).</p>
/// <p><b>Its criteria are the classic SQL page's System box and a schema</b>: <code>system</code>
/// <code>no</code>, its default, keeps no <code>%</code> or <code>INFORMATION_SCHEMA</code> view, and
/// <code>schema</code> keeps one schema's views. A view's own SQL is read by its View info tab
/// (<class>OcuPilot.Screen.Descriptor.ExplorerSqlView</class>), which a row's name opens.</p>
/// <p><b>Its privilege set is <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter></b>; the port
/// also requires READ on the namespace's code databases, resolved at call time (AD-29, AD-61). It
/// replaces <code>%CSP.UI.Portal.SQL.Home</code>, whose custom resource also gates it (AD-44). No
/// action and no refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerSqlViews Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/sql-views",
  "area": "system-explorer",
  "labelKey": "explorerSqlViewsLabel",
  "sideBarPosition": 8,
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
  "context": {"fields": ["View", "Class", "Owner", "Updatable", "CheckOption"], "secretFields": []},
  "emptyStateKey": "explorerSqlViewsEmpty",
  "commandAliases": ["sql views", "views"],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlViewsPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlViewsPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlViewsPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.SQL.Home",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "atelier", "endpoint": "Catalog.Views", "type": "LIST"},
    "fields": ["View", "Schema", "Name", "Class", "Owner", "Updatable", "CheckOption"],
    "filter": ["View", "Schema", "Class"],
    "sort": {"fields": ["View", "Class", "Owner"], "default": "View", "direction": "asc"},
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
      {"field": "View", "labelKey": "viewMenuLabel", "kind": "name"},
      {"field": "Class", "labelKey": "explorerClassDocumentLabel", "kind": "identifier"},
      {"field": "Owner", "labelKey": "explorerSqlColumnOwner", "kind": "text"},
      {"field": "Updatable", "labelKey": "explorerSqlColumnUpdatable", "kind": "status"},
      {"field": "CheckOption", "labelKey": "explorerSqlColumnCheckOption", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "explorer.sqlviews"
}
}

}
