/// <p>System Explorer's Routines list: the routines and include files the route's namespace holds,
/// read through the source code API (<class>OcuPilot.Port.AtelierPort</class>, endpoint
/// <code>Routines</code>) and rendered by the <code>list (server criteria)</code> archetype's page
/// from the declared <code>table</code> (AD-5, AD-36, AD-61). It is the area's second screen.</p>
/// <p><b>Its criteria are the classic Routines page's filters</b>: the name pattern, the system,
/// generated and mapped items, and the modified-time bounds, each applied on the instance before the
/// row cap. A caller that omits one is read with its declared <code>default</code>, the classic
/// page's own, so the screen and its read tool open on the same rows.</p>
/// <p><b>Its scope is <code>namespace</code></b>, and its id is the row's <code>Name</code>, which
/// the name cell carries to the routine viewer
/// (<class>OcuPilot.Screen.Descriptor.ExplorerRoutineDocument</class>).</p>
/// <p><b>Its privilege set is <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter></b>; the port
/// also requires READ on the namespace's code databases, resolved at call time (AD-29, AD-61). It
/// replaces <code>%CSP.UI.Portal.RoutineList</code>, whose custom resource also gates it (AD-44). It
/// declares no action and does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerRoutineList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/routines",
  "area": "system-explorer",
  "labelKey": "explorerRoutineListLabel",
  "sideBarPosition": 2,
  "archetype": "list (server criteria)",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "routine",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Name", "Modified", "Database", "Generated"], "secretFields": []},
  "emptyStateKey": "explorerRoutineListEmpty",
  "commandAliases": ["routines", "include files", "mac routines"],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerRoutineListPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerRoutineListPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerRoutineListPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.RoutineList",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "atelier", "endpoint": "Routines", "type": "LIST"},
    "fields": ["Name", "Modified", "Database", "Generated"],
    "filter": ["Name", "Database"],
    "sort": {"fields": ["Name", "Modified", "Database"], "default": "Name", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "pattern", "labelKey": "explorerRoutinePatternLabel", "kind": "text", "maxLength": 256, "default": "*.mac"},
        {"param": "system", "labelKey": "explorerSystemLabel", "kind": "choice", "maxLength": 3, "options": ["yes", "no"], "default": "no"},
        {"param": "generated", "labelKey": "explorerGeneratedLabel", "kind": "choice", "maxLength": 3, "options": ["yes", "no"], "default": "yes"},
        {"param": "mapped", "labelKey": "explorerMappedLabel", "kind": "choice", "maxLength": 3, "options": ["yes", "no"], "default": "yes"},
        {"param": "from", "labelKey": "auditCriteriaBegin", "kind": "datetime", "maxLength": 30},
        {"param": "to", "labelKey": "auditCriteriaEnd", "kind": "datetime", "maxLength": 30}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Modified", "labelKey": "explorerColumnModified", "kind": "text"},
      {"field": "Database", "labelKey": "systemInfoDatabase", "kind": "identifier"},
      {"field": "Generated", "labelKey": "explorerColumnGenerated", "kind": "status"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "explorer.routines"
}
}

}
