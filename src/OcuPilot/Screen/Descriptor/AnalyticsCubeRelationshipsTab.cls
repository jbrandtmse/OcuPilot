/// <p>Analytics' Relationships tab of a cube: the relationships one cube defines and the cube each relates to, read through
/// <class>OcuPilot.Port.AnalyticsPort</class> (source kind <code>analytics</code>, endpoint <code>Relationships</code>) and rendered by the shared page under the cube's tab strip (AD-5, AD-29, AD-36, AD-44, AD-65,
/// Story 20.11). <b>A row's name cell opens the related cube's Measures tab</b>, through <code>rowTarget</code> on <code>RelatedCube</code>; a related cube the caller cannot see is still named, and its tab reads no rows.</p>
/// <p>It is one tab of the cube group <code>analytics/cubes/document</code>, parent-scoped under Cubes: its one criterion, <code>cube</code>, is the route id, the cube's logical name, and the strip carries it from tab
/// to tab. A cube that does not exist, or that the vendor's own resource check refuses the caller, reads no rows. Its pair is the Cubes list's (AD-8, AD-44); it offers no action and does not refresh.</p>
Class OcuPilot.Screen.Descriptor.AnalyticsCubeRelationshipsTab Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "analytics/cubes/relationships",
  "area": "analytics",
  "labelKey": "analyticsTabRelationships",
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
  "context": {"fields": ["Name", "RelatedCube"], "secretFields": []},
  "emptyStateKey": "analyticsCubeRelationshipsEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsCubeRelationshipsPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "analyticsCubeRelationshipsPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsCubeRelationshipsPrompt3"}
  ],
  "classicPage": "%DeepSee.UI.ModelBrowser",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "relationship of a cube",
    "source": {"port": "analytics", "endpoint": "Relationships", "type": "LIST"},
    "fields": ["Name", "RelatedCube"],
    "filter": ["Name", "RelatedCube"],
    "sort": {"fields": ["Name", "RelatedCube"], "default": "Name", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [{"param": "cube", "labelKey": "analyticsCubeCriterion", "kind": "text", "maxLength": 255, "hint": "One cube, spelled as analytics.cubes.read answers its Name."}]
    }
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "RelatedCube", "labelKey": "analyticsColumnRelatedCube", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "analytics/cubes/document", "position": 3, "labelKey": "analyticsTabRelationships"},
  "rowTarget": {"route": "analytics/cubes/document", "field": "RelatedCube"},
  "toolIdentifier": "analytics.cuberelationships"
}
}

}
