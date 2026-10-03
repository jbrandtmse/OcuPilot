/// <p>The first of a SQL view's catalog tabs, View info: the view's owner, last compile, read-only
/// and updatable flags, class, check option, class type and text, the classic SQL page's view
/// information read through the source code API (<class>OcuPilot.Port.AtelierPort</class>, endpoint
/// <code>Catalog.View</code>) and rendered by the <code>detail</code> archetype's page under the
/// group's tab strip (AD-5, AD-36, AD-61). The view's text is a row field, untrusted and cut by the
/// per-field bound in a tool result and in screen context (AD-24, AD-60), and shown whole here, as
/// text.</p>
/// <p><b>It heads a parent-scoped tab group</b> (AD-5): it is reached from the SQL views list's name
/// cell, never listed (<code>sideBarPosition</code> 0), and its route id is the list row's
/// <code>View</code>, sent as the one criterion <code>view</code>; every tab of the group declares the
/// same parent and criterion, and the strip carries the id from tab to tab.</p>
/// <p><b>The view is the one the caller's own privileges show it</b>: the port resolves the name
/// through the information schema before it reads, and answers not found otherwise, since the vendor's
/// view queries filter nothing by privilege (AD-61 rules 3 and 7). Its privilege set is
/// <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter>, beside READ on the namespace's code
/// databases (AD-29). It replaces <code>%CSP.UI.Portal.SQL.Home</code>, whose custom resource also
/// gates it (AD-44). No action and no refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerSqlView Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/sql-views/document",
  "area": "system-explorer",
  "labelKey": "explorerSqlViewLabel",
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
  "context": {"fields": ["Class", "Owner", "LastCompiled", "ReadOnly", "Updatable", "CheckOption", "ClassType", "Text"], "secretFields": []},
  "emptyStateKey": "explorerSqlViewEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlViewPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlViewPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlViewPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.SQL.Home",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "atelier", "endpoint": "Catalog.View", "type": "LIST"},
    "fields": ["Owner", "LastCompiled", "ReadOnly", "Updatable", "Class", "CheckOption", "ClassType", "Text"],
    "filter": ["Class", "Owner", "Text"],
    "sort": {"fields": ["Class"], "default": "Class", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "view", "labelKey": "viewMenuLabel", "kind": "text", "maxLength": 257}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Class", "labelKey": "explorerClassDocumentLabel", "kind": "name"},
      {"field": "Owner", "labelKey": "explorerSqlColumnOwner", "kind": "text"},
      {"field": "LastCompiled", "labelKey": "explorerSqlColumnLastCompiled", "kind": "text"},
      {"field": "ReadOnly", "labelKey": "agentDefinitionFieldReadOnly", "kind": "status"},
      {"field": "Updatable", "labelKey": "explorerSqlColumnUpdatable", "kind": "status"},
      {"field": "CheckOption", "labelKey": "explorerSqlColumnCheckOption", "kind": "text"},
      {"field": "ClassType", "labelKey": "explorerSqlColumnClassType", "kind": "text"},
      {"field": "Text", "labelKey": "explorerSearchTextLabel", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "system-explorer/sql-views/document", "position": 1, "labelKey": "explorerSqlTabViewInfo"},
  "toolIdentifier": "explorer.sqlview"
}
}

}
