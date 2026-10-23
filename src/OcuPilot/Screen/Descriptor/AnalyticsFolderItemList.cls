/// <p>Analytics' Folder items: the pivots, dashboards and other folder items the namespace holds and the caller may see, with each one's type, owner and last change, and whether it is one of the signed-in person's
/// favorites, read through <class>OcuPilot.Port.AnalyticsPort</class> (source kind <code>analytics</code>, endpoint <code>FolderItems</code>) and rendered by the <code>list</code> archetype's page from the declared
/// <code>table</code> (AD-5, AD-29, AD-36, AD-44, AD-65, Story 20.11). An item the vendor's own resource check refuses the caller is absent, which is stricter than the classic Folder Manager. The vendor opens every item
/// before the row cap applies.</p>
/// <p><b>Its id is the item's full name</b>, folder and extension included, kept exactly (AD-13), and its scope is <code>namespace</code>.</p>
/// <p><b>Its pairs</b> are <code>%DeepSee_Portal:USE</code> and, as its own, <code>%Development:USE</code>: the classic Folder Manager admits <code>%DeepSee_Admin</code> or <code>%Development</code>, and a pair set is an AND, so
/// this screen names the narrower audience (AD-8, AD-65). It offers no action and does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.AnalyticsFolderItemList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "analytics/folder-items",
  "area": "analytics",
  "labelKey": "analyticsFolderItemsLabel",
  "sideBarPosition": 3,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%DeepSee_Portal", "permission": "USE"}, {"resource": "%Development", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "folder-item",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Name", "Type", "Owner", "Modified", "Favorite"], "secretFields": []},
  "emptyStateKey": "analyticsFolderItemsEmpty",
  "commandAliases": ["folder items", "folder item"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsFolderItemsPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsFolderItemsPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "analyticsFolderItemsPrompt3"}
  ],
  "classicPage": "%DeepSee.UI.FolderManager",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "analytics", "endpoint": "FolderItems", "type": "LIST"},
    "fields": ["Name", "Type", "Owner", "Modified", "Favorite"],
    "filter": ["Name", "Type", "Owner"],
    "sort": {"fields": ["Name", "Type", "Owner", "Modified", "Favorite"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "Owner", "labelKey": "explorerSqlColumnOwner", "kind": "text"},
      {"field": "Modified", "labelKey": "analyticsColumnModified", "kind": "text"},
      {"field": "Favorite", "labelKey": "analyticsColumnFavorite", "kind": "status"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "analytics.folderitems"
}
}

}
