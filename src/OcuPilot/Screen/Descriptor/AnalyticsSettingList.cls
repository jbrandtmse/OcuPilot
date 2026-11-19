/// <p>Analytics' Settings: the first tab, General, of the classic Settings page's four, one name and value row per analytics setting the namespace stores, read through
/// <class>OcuPilot.Port.AnalyticsPort</class> (source kind <code>analytics</code>, endpoint <code>Settings</code>) and rendered by the <code>detail</code> page over the declared
/// <code>table</code> (AD-5, AD-29, AD-36, AD-44, AD-65, Story 24.13). A setting that is not stored reads the classic page's default, with <code>Stored</code> false.</p>
/// <p><b>It is the tab group's first member and its side-bar entry.</b> <code>tab.group</code> is its own route; Worklists, Run-time variables and User-defined icons are unlisted routes
/// under it, each a descriptor of its own.</p>
/// <p><b>The Google Maps key is never shown.</b> Its row's <code>Value</code> is the credential mask when a key is stored and empty when not (AD-35); the key reaches no screen and no tool.</p>
/// <p><b>Its pairs</b> are <code>%DeepSee_Portal:USE</code> and, as its own, <code>%Development:USE</code>, because a run-time variable is code; the port also checks READ on the namespace's databases
/// before any vendor call (AD-8, AD-65). <b>Its id is the setting's name</b>, kept exactly (AD-13), and its scope is <code>namespace</code>. It offers no action and does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.AnalyticsSettingList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "analytics/settings",
  "area": "analytics",
  "labelKey": "interopItemTabSettings",
  "sideBarPosition": 11,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%DeepSee_Portal", "permission": "USE"}, {"resource": "%Development", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "analytics-setting",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Name", "Value", "Stored"], "secretFields": []},
  "emptyStateKey": "analyticsSettingsEmpty",
  "commandAliases": ["analytics settings"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsSettingsPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "analyticsSettingsPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsSettingsPrompt3"}
  ],
  "classicPage": "%DeepSee.UI.Settings",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "analytics setting",
    "source": {"port": "analytics", "endpoint": "Settings", "type": "LIST"},
    "fields": ["Name", "Value", "Stored"],
    "filter": ["Name", "Value"],
    "sort": {"fields": ["Name", "Value", "Stored"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "agentGovernanceColumnSetting", "kind": "name"},
      {"field": "Value", "labelKey": "errorLogColumnValue", "kind": "text"},
      {"field": "Stored", "labelKey": "analyticsColumnStored", "kind": "status"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "analytics/settings", "position": 1, "labelKey": "processDetailsGroupGeneral"},
  "toolIdentifier": "analytics.settings"
}
}

}
