/// <p>Analytics' Worklists: the second tab of the classic Settings page, which of the four worklists each panel of the home and dashboard pages shows, one row per page, panel and worklist
/// class (sixteen), read through <class>OcuPilot.Port.AnalyticsPort</class> (source kind <code>analytics</code>, endpoint <code>Worklists</code>) and rendered by the <code>detail</code> page
/// over the declared <code>table</code> (AD-5, AD-29, AD-36, AD-44, AD-65, Story 24.13). <code>Shown</code> is whether the option is stored.</p>
/// <p><b>It is the second tab of the group <code>analytics/settings</code> and never listed</b> (<code>sideBarPosition</code> 0). Its pairs are the first tab's. <b>Its id is the composite
/// <code>[Page, Panel, Class]</code></b>, each part kept exactly (AD-13), and its scope is <code>namespace</code>. It offers no action and does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.AnalyticsWorklistList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "analytics/settings/worklists",
  "area": "analytics",
  "labelKey": "analyticsWorklistsLabel",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%DeepSee_Portal", "permission": "USE"}, {"resource": "%Development", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "analytics-worklist",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Page", "Panel", "Class"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Page", "Panel", "Worklist", "Class", "Shown"], "secretFields": []},
  "emptyStateKey": "analyticsWorklistsEmpty",
  "commandAliases": ["worklists"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsWorklistsPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsWorklistsPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsWorklistsPrompt3"}
  ],
  "classicPage": "%DeepSee.UI.Settings",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "worklist option",
    "source": {"port": "analytics", "endpoint": "Worklists", "type": "LIST"},
    "fields": ["Page", "Panel", "Worklist", "Class", "Shown"],
    "filter": ["Page", "Worklist", "Class"],
    "sort": {"fields": ["Page", "Panel", "Worklist", "Shown"], "default": "Page", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Page", "labelKey": "explorerSqlDataPage", "kind": "name"},
      {"field": "Panel", "labelKey": "analyticsColumnPanel", "kind": "number"},
      {"field": "Worklist", "labelKey": "analyticsColumnWorklist", "kind": "text"},
      {"field": "Shown", "labelKey": "analyticsColumnShown", "kind": "status"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "analytics/settings", "position": 2, "labelKey": "analyticsWorklistsLabel"},
  "toolIdentifier": "analytics.worklists"
}
}

}
