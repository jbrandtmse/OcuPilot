/// <p>Compatibility settings: the settings of <code>Config.Miscellaneous</code>, each with its value and whether a change takes effect only at the next
/// restart, read through <class>OcuPilot.Port.ConfigPort</class> (source kind <code>config</code>, endpoint
/// <code>Compatibility</code>) and rendered by the <code>list</code> archetype's page from the declared <code>table</code> (AD-5, AD-29,
/// AD-36, AD-53, Story 21.3). It is OS management's twenty-eighth side-bar entry.</p>
/// <p><b>Its pairs</b> are the classic page's: <code>%Admin_Manage:USE</code> and <code>%DB_IRISSYS:READ</code>, and, as its own, <code>%Admin_Secure:USE</code>, which the classic menu gates its Compatibility page on (AD-8,
/// AD-44). Its tool adds <code>%DB_IRISSYS:WRITE</code>, which the vendor's <code>Config</code> writes need.</p>
/// <p><b>Its id is the setting's name</b>, kept exactly (AD-13). Its row action Set value is the screen's caller of
/// <class>OcuPilot.Screen.Tool.CompatibilitySettingSet</class> (AD-53), and a row the port reads as shown and never changed offers none. The
/// Memory and Startup page's own settings are rows of these tables, so no separate form is built. It does not refresh
/// (AD-43).</p>
Class OcuPilot.Screen.Descriptor.CompatibilitySettingList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/compatibility-settings",
  "area": "os-management",
  "labelKey": "compatibilitySettingsLabel",
  "sideBarPosition": 28,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Admin_Secure", "permission": "USE"}],
  "entityType": "compatibility-setting",
  "entityLabelKey": "aboutCompatibilitySetting",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Name"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "set", "selfProtection": ""}],
  "context": {"fields": ["Name", "Value", "Kind", "Accepts", "Restart", "ReadOnly"], "secretFields": []},
  "emptyStateKey": "configSettingsEmpty",
  "commandAliases": ["compatibility settings"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "compatibilitySettingsPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "compatibilitySettingsPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "compatibilitySettingsPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.Config.Compatibility",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "compatibility setting",
    "label": "The instance's compatibility settings: how the language treats null subscripts, undefined variables and list format. The startup settings are in osmgmt.startupsettings and the memory settings in osmgmt.memorysettings.",
    "source": {"port": "config", "endpoint": "Compatibility", "type": "LIST"},
    "fields": ["Name", "Value", "Kind", "Accepts", "Restart", "ReadOnly"],
    "filter": ["Name", "Value"],
    "sort": {"fields": ["Name", "Value"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "agentGovernanceColumnSetting", "kind": "name"},
      {"field": "Value", "labelKey": "errorLogColumnValue", "kind": "text"},
      {"field": "Restart", "labelKey": "actionRestart", "kind": "status"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "compatibilitySettingsEmptyAgent"
  },
  "toolIdentifier": "osmgmt.compatibilitysettings"
}
}

}
