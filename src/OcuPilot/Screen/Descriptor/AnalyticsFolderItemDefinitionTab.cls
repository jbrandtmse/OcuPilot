/// <p>Analytics' Definition tab of a folder item: what one saved pivot or dashboard holds, one row, read through <class>OcuPilot.Port.AnalyticsPort</class> (source kind <code>analytics</code>,
/// endpoint <code>FolderItemDefinition</code>) and rendered by the shared page under the item's tab strip (AD-5, AD-29, AD-36, AD-44, AD-65, Story 24.14). It is the first tab of the group
/// <code>analytics/folder-items/document</code>, which the Folder items list's name cell opens as the cube tabs are opened from Cubes; its Widgets tab declares the same parent.</p>
/// <p><b>Its row</b> is the item's name, type, title, description, owner and last change and, for a pivot, its cube, its rows, columns, measures and filters (each level's spec, one per line), its
/// calculated members' names, its own MDX when it is in manual mode, and its SQL restriction; for a dashboard those are empty. An item that is missing, that the vendor's own resource check refuses
/// the caller (a locked item included, which is stricter than the classic viewer), or that is neither a pivot nor a dashboard reads no row. Reading opens the item and its properties and nothing else:
/// nothing is composed or run, and the item's last-access time and the person's recent items are not touched.</p>
/// <p><b>A pivot is run from this tab</b> by <class>OcuPilot.Area.Analytics.PivotRun</class>, MDX query's own run over the pivot's composed MDX, which asks first when the stored restriction runs SQL.
/// Its pairs are Folder items' (AD-8, AD-65); its one criterion, <code>item</code>, is the route id, the item's full name, kept exactly (AD-13). It offers no action and does not refresh.</p>
Class OcuPilot.Screen.Descriptor.AnalyticsFolderItemDefinitionTab Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "analytics/folder-items/document",
  "area": "analytics",
  "labelKey": "agentDefinitionFormLabel",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%DeepSee_Portal", "permission": "USE"}, {"resource": "%Development", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "folder-item",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "analytics/folder-items",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Name", "Type", "Title", "Description", "Owner", "Modified", "Cube", "Rows", "Columns", "Measures", "Filters", "Calculated", "MDX", "Restriction"], "secretFields": []},
  "emptyStateKey": "analyticsFolderItemDefinitionEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsFolderItemDefinitionPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsFolderItemDefinitionPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "analyticsFolderItemDefinitionPrompt3"}
  ],
  "classicPage": "%DeepSee.UserPortal.DashboardViewer",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "pivot or dashboard definition",
    "source": {"port": "analytics", "endpoint": "FolderItemDefinition", "type": "LIST"},
    "fields": ["Name", "Type", "Title", "Description", "Owner", "Modified", "Cube", "Rows", "Columns", "Measures", "Filters", "Calculated", "MDX", "Restriction"],
    "filter": ["Name", "Type", "Title", "Cube"],
    "sort": {"fields": ["Name", "Type", "Title", "Owner", "Modified", "Cube"], "default": "Name", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [{"param": "item", "labelKey": "tableColumnName", "kind": "text", "maxLength": 600, "hint": "One saved pivot or dashboard, spelled as analytics.folderitems.read answers its Name."}]
    }
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "Title", "labelKey": "interopPartnerFieldTitle", "kind": "text"},
      {"field": "Description", "labelKey": "tableColumnDescription", "kind": "text", "long": true},
      {"field": "Owner", "labelKey": "explorerSqlColumnOwner", "kind": "text"},
      {"field": "Modified", "labelKey": "analyticsColumnModified", "kind": "text"},
      {"field": "Cube", "labelKey": "analyticsCubeCriterion", "kind": "text"},
      {"field": "Rows", "labelKey": "explorerSqlColumnRows", "kind": "text", "long": true},
      {"field": "Columns", "labelKey": "explorerSqlColumnColumns", "kind": "text", "long": true},
      {"field": "Measures", "labelKey": "analyticsTabMeasures", "kind": "text", "long": true},
      {"field": "Filters", "labelKey": "analyticsColumnFilters", "kind": "text", "long": true},
      {"field": "Calculated", "labelKey": "analyticsColumnCalculated", "kind": "text", "long": true},
      {"field": "MDX", "labelKey": "analyticsColumnMdx", "kind": "text", "long": true},
      {"field": "Restriction", "labelKey": "analyticsColumnRestriction", "kind": "text", "long": true}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "analytics/folder-items/document", "position": 1, "labelKey": "agentDefinitionFormLabel"},
  "toolIdentifier": "analytics.folderitemdefinition"
}
}

}
