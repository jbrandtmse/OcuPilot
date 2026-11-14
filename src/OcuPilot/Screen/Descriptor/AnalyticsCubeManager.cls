/// <p>Analytics' Cube manager: the cubes the namespace holds and the caller may see, each with its fact count, the time it was last built and
/// last updated, whether its source records changes so that it can be synchronized, whether an update runs now, and the cubes that depend on
/// it, read through <class>OcuPilot.Port.AnalyticsPort</class> (source kind <code>analytics</code>, endpoint <code>CubeManager</code>) and
/// rendered by the <code>list</code> archetype's page from the declared <code>table</code> (AD-5, AD-29, AD-36, AD-44, AD-51, AD-53, AD-65,
/// Story 20.34). It adds Build and Synchronize as row actions, the classic Cube Manager's, and a Build is also the classic Repair Build.</p>
/// <p><b>Its pairs</b> are the Model Browser's <code>%DeepSee_Portal:USE</code>, the area's, and, as its own, <code>%DeepSee_Admin:USE</code>,
/// the <code>RESOURCE</code> of <code>%DeepSee.UI.CubeRegistry</code>, which no shipped role but <code>%All</code> holds (AD-8, AD-44). The
/// port requires both whatever the screen is adjusted to (AD-64), and the two actions add WRITE on the database the vendor keeps a cube's
/// facts in.</p>
/// <p><b>A cube's name opens the cube's own screen</b> (<code>rowTarget</code>), the Cubes list's tab group, never this list. Its id is the
/// cube's logical name, kept exactly (AD-13), and its scope is <code>namespace</code>. Its row actions are <code>build</code>, which is
/// destructive and types the cube's name (<code>analytics.cubemanager.build</code>), and <code>synchronize</code>, which is sent at once
/// (<code>analytics.cubemanager.synchronize</code>); each shows the lines the instance answered after it ran. It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.AnalyticsCubeManager Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "analytics/cube-manager",
  "area": "analytics",
  "labelKey": "analyticsCubeManagerLabel",
  "sideBarPosition": 8,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%DeepSee_Portal", "permission": "USE"}, {"resource": "%DeepSee_Admin", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%DeepSee_Admin", "permission": "USE"}],
  "entityType": "cube",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "build", "selfProtection": ""}, {"id": "synchronize", "selfProtection": ""}],
  "context": {"fields": ["Name", "Caption", "Facts", "LastBuild", "LastUpdate", "Synchronizes", "Updating", "DependentCubes"], "secretFields": []},
  "emptyStateKey": "analyticsCubesEmpty",
  "commandAliases": ["cube manager", "build cube", "synchronize cube"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsCubeManagerPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsCubeManagerPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "analyticsCubeManagerPrompt3"}
  ],
  "classicPage": "%DeepSee.UI.CubeRegistry",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "cube with its build state",
    "label": "Cubes with when each was last built and updated, whether it can be synchronized, whether an update runs now and which cubes depend on it; the cube model is in analytics.cubes.",
    "source": {"port": "analytics", "endpoint": "CubeManager", "type": "LIST"},
    "fields": ["Name", "Caption", "Facts", "LastBuild", "LastUpdate", "Synchronizes", "Updating", "DependentCubes"],
    "filter": ["Name", "Caption", "DependentCubes"],
    "sort": {"fields": ["Name", "Caption", "Facts", "LastBuild", "LastUpdate"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Caption", "labelKey": "analyticsColumnCaption", "kind": "text"},
      {"field": "Facts", "labelKey": "analyticsColumnFacts", "kind": "number"},
      {"field": "LastBuild", "labelKey": "analyticsColumnLastBuild", "kind": "text"},
      {"field": "LastUpdate", "labelKey": "systemUsageLastUpdate", "kind": "text"},
      {"field": "Synchronizes", "labelKey": "analyticsColumnSynchronizes", "kind": "status"},
      {"field": "Updating", "labelKey": "analyticsColumnUpdating", "kind": "status"},
      {"field": "DependentCubes", "labelKey": "analyticsColumnDependentCubes", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "analyticsCubeManagerEmptyAgent"
  },
  "rowTarget": {"route": "analytics/cubes/document", "field": "Name"},
  "toolIdentifier": "analytics.cubemanager"
}
}

}
