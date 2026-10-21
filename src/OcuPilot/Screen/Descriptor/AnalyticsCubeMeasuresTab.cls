/// <p>Analytics' Measures tab of a cube: the measures one cube defines, calculated measures included, with their captions, types and whether each is hidden, read through
/// <class>OcuPilot.Port.AnalyticsPort</class> (source kind <code>analytics</code>, endpoint <code>Measures</code>) and rendered by the shared page under the cube's tab strip (AD-5, AD-29, AD-36, AD-44, AD-65,
/// Story 20.11). It is the group's head, the screen a Cubes name cell opens.</p>
/// <p>It is one tab of the cube group <code>analytics/cubes/document</code>, parent-scoped under Cubes: its one criterion, <code>cube</code>, is the route id, the cube's logical name, and the strip carries it from tab
/// to tab. A cube that does not exist, or that the vendor's own resource check refuses the caller, reads no rows. Its pair is the Cubes list's (AD-8, AD-44); it offers no action and does not refresh.</p>
Class OcuPilot.Screen.Descriptor.AnalyticsCubeMeasuresTab Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "analytics/cubes/document",
  "area": "analytics",
  "labelKey": "analyticsTabMeasures",
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
  "context": {"fields": ["Name", "Caption", "Type", "Hidden"], "secretFields": []},
  "emptyStateKey": "analyticsCubeMeasuresEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsCubeMeasuresPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "analyticsCubeMeasuresPrompt2"},
    {"groupKey": "promptGroupCapacity", "textKey": "analyticsCubeMeasuresPrompt3"}
  ],
  "classicPage": "%DeepSee.UI.ModelBrowser",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "analytics", "endpoint": "Measures", "type": "LIST"},
    "fields": ["Name", "Caption", "Type", "Hidden"],
    "filter": ["Name", "Caption", "Type"],
    "sort": {"fields": ["Name", "Caption", "Type", "Hidden"], "default": "Name", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [{"param": "cube", "labelKey": "analyticsCubeCriterion", "kind": "text", "maxLength": 255, "hint": "One cube, spelled as analytics.cubes.read answers its Name."}]
    }
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Caption", "labelKey": "analyticsColumnCaption", "kind": "text"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "Hidden", "labelKey": "explorerSqlColumnHidden", "kind": "status"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "analytics/cubes/document", "position": 1, "labelKey": "analyticsTabMeasures"},
  "toolIdentifier": "analytics.cubemeasures"
}
}

}
