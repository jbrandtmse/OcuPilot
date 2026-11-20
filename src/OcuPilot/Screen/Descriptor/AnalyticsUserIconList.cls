/// <p>Analytics' User-defined icons: the fourth tab of the classic Settings page, the icons the namespace defines for its dashboards, each a name and a path, read through
/// <class>OcuPilot.Port.AnalyticsPort</class> (source kind <code>analytics</code>, endpoint <code>UserIcons</code>) and rendered by the <code>detail</code> page over the declared
/// <code>table</code> (AD-5, AD-29, AD-36, AD-44, AD-65, Story 24.13). A path is shown as text and never loaded (AD-11).</p>
/// <p><b>It is the fourth tab of the group <code>analytics/settings</code> and never listed</b> (<code>sideBarPosition</code> 0). Its pairs are the first tab's. <b>Its id is the icon's name</b>, kept
/// exactly (AD-13), and its scope is <code>namespace</code>. It writes (Story 24.13, Batch 3): its primary action Add icon and its row actions Change icon and Remove icon are the tools
/// <code>analytics.usericons.add</code>, <code>.set</code> and <code>.remove</code>. It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.AnalyticsUserIconList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "analytics/settings/icons",
  "area": "analytics",
  "labelKey": "analyticsUserIconsLabel",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%DeepSee_Portal", "permission": "USE"}, {"resource": "%Development", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "analytics-user-icon",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "add", "selfProtection": ""},
  "rowActions": [{"id": "set", "selfProtection": ""}, {"id": "remove", "selfProtection": ""}],
  "context": {"fields": ["Name", "Path"], "secretFields": []},
  "emptyStateKey": "analyticsUserIconsEmpty",
  "commandAliases": ["user-defined icons", "user icons"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsUserIconsPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "analyticsUserIconsPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsUserIconsPrompt3"}
  ],
  "classicPage": "%DeepSee.UI.Settings",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "user-defined icon",
    "source": {"port": "analytics", "endpoint": "UserIcons", "type": "LIST"},
    "fields": ["Name", "Path"],
    "filter": ["Name", "Path"],
    "sort": {"fields": ["Name", "Path"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Path", "labelKey": "openApiColumnPath", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "analyticsUserIconsEmptyAgent"
  },
  "tab": {"group": "analytics/settings", "position": 4, "labelKey": "analyticsUserIconsLabel"},
  "toolIdentifier": "analytics.usericons"
}
}

}
