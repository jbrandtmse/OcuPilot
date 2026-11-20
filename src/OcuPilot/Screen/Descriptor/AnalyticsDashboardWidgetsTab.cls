/// <p>Analytics' Widgets tab of a folder item: the widgets one saved dashboard holds, one row per widget in its stored order, read through <class>OcuPilot.Port.AnalyticsPort</class>
/// (source kind <code>analytics</code>, endpoint <code>DashboardWidgets</code>) and rendered by the shared page under the item's tab strip (AD-5, AD-29, AD-36, AD-44, AD-65, Story 24.14). It is the
/// second tab of the group <code>analytics/folder-items/document</code>, parent-scoped under Folder items, whose one criterion, <code>item</code>, is the route id, the dashboard's full name.
/// An item that is missing, hidden from the caller or not a dashboard reads no rows.</p>
/// <p><b>A widget's data source opens its pivot</b>: the name cell of a row whose <code>NotPivot</code> is false links to that pivot's Definition tab (<code>rowTarget</code>). A KPI, a metric or a worksheet
/// data source, and a widget with none, is not a saved pivot, so its cell is text and nothing about it is run. <code>LinkedTo</code> is the widget this one takes its data from.
/// Its pairs are Folder items' (AD-8, AD-65). It offers no action and does not refresh.</p>
Class OcuPilot.Screen.Descriptor.AnalyticsDashboardWidgetsTab Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "analytics/folder-items/widgets",
  "area": "analytics",
  "labelKey": "analyticsTabWidgets",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%DeepSee_Portal", "permission": "USE"}, {"resource": "%Development", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "dashboard-widget",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "analytics/folder-items",
  "id": {"kind": "composite", "parts": ["Dashboard", "Position"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Dashboard", "Position", "Title", "Type", "DataSource", "LinkedTo", "NotPivot"], "secretFields": []},
  "emptyStateKey": "analyticsDashboardWidgetsEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsDashboardWidgetsPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsDashboardWidgetsPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "analyticsDashboardWidgetsPrompt3"}
  ],
  "classicPage": "%DeepSee.UserPortal.DashboardViewer",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "dashboard widget",
    "source": {"port": "analytics", "endpoint": "DashboardWidgets", "type": "LIST"},
    "fields": ["Dashboard", "Position", "Title", "Type", "DataSource", "LinkedTo", "NotPivot"],
    "filter": ["Title", "Type", "DataSource", "LinkedTo"],
    "sort": {"fields": ["Position", "Title", "Type", "DataSource"], "default": "Position", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [{"param": "item", "labelKey": "dashboardLabel", "kind": "text", "maxLength": 600, "hint": "One saved dashboard, spelled as analytics.folderitems.read answers its Name."}]
    }
  },
  "table": {
    "columns": [
      {"field": "Position", "labelKey": "analyticsColumnPosition", "kind": "number"},
      {"field": "Title", "labelKey": "interopPartnerFieldTitle", "kind": "text"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "DataSource", "labelKey": "analyticsColumnDataSource", "kind": "name"},
      {"field": "LinkedTo", "labelKey": "analyticsQualityMeasureLinkedToLabel", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "rowTarget": {"route": "analytics/folder-items/document", "field": "DataSource", "unless": "NotPivot"},
  "tab": {"group": "analytics/folder-items/document", "position": 2, "labelKey": "analyticsTabWidgets"},
  "toolIdentifier": "analytics.dashboardwidgets"
}
}

}
