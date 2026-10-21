/// <p>Analytics' Cubes: the cubes the namespace holds and the caller may see, each with its caption, its class, the time it was last built and its fact count, read through
/// <class>OcuPilot.Port.AnalyticsPort</class> (source kind <code>analytics</code>, endpoint <code>Cubes</code>) and rendered by the <code>list</code> archetype's page from the declared
/// <code>table</code> (AD-5, AD-29, AD-36, AD-44, AD-65, Story 20.11). Subject areas and abstract cubes are not listed. A cube the vendor's own resource check refuses the caller is absent.</p>
/// <p><b>A cube's name opens its model</b>: <code>analytics/cubes/document/&lt;cube&gt;</code> is the Measures tab of the cube's tab group, whose Dimensions and Relationships tabs declare this list's route as their
/// <code>parentScope</code>. <b>Its id is the cube's logical name</b>, kept exactly (AD-13), and its scope is <code>namespace</code>.</p>
/// <p><b>Its pair</b> is the classic Model Browser's <code>%DeepSee_Portal:USE</code>, the area's own; the port also checks READ on the namespace's globals and routines databases before any vendor call
/// (AD-8, AD-65). It offers no action and does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.AnalyticsCubeList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "analytics/cubes",
  "area": "analytics",
  "labelKey": "analyticsCubesLabel",
  "sideBarPosition": 1,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%DeepSee_Portal", "permission": "USE"}],
  "entityType": "cube",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Name", "Caption", "Class", "LastBuild", "Facts"], "secretFields": []},
  "emptyStateKey": "analyticsCubesEmpty",
  "commandAliases": ["cubes", "cube"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupCapacity", "textKey": "analyticsCubesPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "analyticsCubesPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "analyticsCubesPrompt3"}
  ],
  "classicPage": "%DeepSee.UI.ModelBrowser",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "analytics", "endpoint": "Cubes", "type": "LIST"},
    "fields": ["Name", "Caption", "Class", "LastBuild", "Facts"],
    "filter": ["Name", "Caption", "Class"],
    "sort": {"fields": ["Name", "Caption", "Class", "LastBuild", "Facts"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Caption", "labelKey": "analyticsColumnCaption", "kind": "text"},
      {"field": "Class", "labelKey": "explorerClassDocumentLabel", "kind": "identifier"},
      {"field": "LastBuild", "labelKey": "analyticsColumnLastBuild", "kind": "text"},
      {"field": "Facts", "labelKey": "analyticsColumnFacts", "kind": "number"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "analytics.cubes"
}
}

}
