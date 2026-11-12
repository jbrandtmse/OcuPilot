/// <p>Analytics' Dimensions tab of a cube: the levels one cube defines, one row per level in the model's order, with the dimension and hierarchy each belongs to, read through
/// <class>OcuPilot.Port.AnalyticsPort</class> (source kind <code>analytics</code>, endpoint <code>Dimensions</code>) and rendered by the shared page under the cube's tab strip (AD-5, AD-29, AD-36, AD-44, AD-65,
/// Story 20.11). It shows levels, not their members: reading members runs a query and writes the vendor's cache.</p>
/// <p>It is one tab of the cube group <code>analytics/cubes/document</code>, parent-scoped under Cubes: its one criterion, <code>cube</code>, is the route id, the cube's logical name, and the strip carries it from tab
/// to tab. A cube that does not exist, or that the vendor's own resource check refuses the caller, reads no rows. Its pair is the Cubes list's (AD-8, AD-44); it offers no action and does not refresh.</p>
Class OcuPilot.Screen.Descriptor.AnalyticsCubeDimensionsTab Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "analytics/cubes/dimensions",
  "area": "analytics",
  "labelKey": "analyticsTabDimensions",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%DeepSee_Portal", "permission": "USE"}],
  "entityType": "cube",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "analytics/cubes",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Position", "Dimension", "Hierarchy", "Level"], "secretFields": []},
  "emptyStateKey": "analyticsCubeDimensionsEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsCubeDimensionsPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "analyticsCubeDimensionsPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsCubeDimensionsPrompt3"}
  ],
  "classicPage": "%DeepSee.UI.ModelBrowser",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "dimension level of a cube",
    "source": {"port": "analytics", "endpoint": "Dimensions", "type": "LIST"},
    "fields": ["Position", "Dimension", "Hierarchy", "Level"],
    "filter": ["Dimension", "Hierarchy", "Level"],
    "sort": {"fields": ["Position", "Dimension", "Hierarchy", "Level"], "default": "Position", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [{"param": "cube", "labelKey": "analyticsCubeCriterion", "kind": "text", "maxLength": 255, "hint": "One cube, spelled as analytics.cubes.read answers its Name."}]
    }
  },
  "table": {
    "columns": [
      {"field": "Position", "labelKey": "analyticsColumnPosition", "kind": "number"},
      {"field": "Dimension", "labelKey": "analyticsColumnDimension", "kind": "text"},
      {"field": "Hierarchy", "labelKey": "analyticsColumnHierarchy", "kind": "text"},
      {"field": "Level", "labelKey": "errorLogColumnLevel", "kind": "name"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "analytics/cubes/document", "position": 2, "labelKey": "analyticsTabDimensions"},
  "toolIdentifier": "analytics.cubedimensions"
}
}

}
