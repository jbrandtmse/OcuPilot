/// <p>Interoperability's Purge data settings: the four settings of the classic Purge Data Settings page, one name and value row each, which the next purge of the namespace uses,
/// read through <class>OcuPilot.Port.InteropPort</class> (source kind <code>interop</code>, endpoint <code>PurgeSettings</code>) and rendered by the <code>list</code> archetype's page over the
/// declared <code>table</code> (AD-5, AD-29, AD-36, AD-44, AD-62, Story 24.16). A setting that is not stored reads the classic page's default, with <code>Stored</code> false.</p>
/// <p><b>Its row action</b> Set value changes one setting through <class>OcuPilot.Screen.Tool.InteropPurgeSettingSet</class> (AD-53, AD-55); it is stored at once, and each
/// setting is set by itself rather than through a whole-form Save.</p>
/// <p><b>Its pairs</b> are the classic page's: <code>%Ens_Portal:USE</code> and, as its own, <code>%Ens_PurgeSettings:WRITE</code>, which the classic page asks to show itself
/// at all; the tool adds WRITE on the namespace's globals database (AD-8, AD-62). <b>Its id is the setting's name</b>, kept exactly (AD-13), and its scope is
/// <code>namespace</code>. A description is untrusted text, shown and never run (AD-11). It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.InteropPurgeSettingList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/purge-settings",
  "area": "interoperability",
  "labelKey": "interopPurgeSettingsLabel",
  "sideBarPosition": 17,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_PurgeSettings", "permission": "WRITE"}],
  "ownPrivileges": [{"resource": "%Ens_PurgeSettings", "permission": "WRITE"}],
  "entityType": "interop-purge-setting",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "set", "selfProtection": ""}],
  "context": {"fields": ["Name", "Value", "Stored", "Kind", "Accepts"], "secretFields": []},
  "emptyStateKey": "interopPurgeSettingsEmpty",
  "commandAliases": ["purge settings", "purge data settings"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopPurgeSettingsPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopPurgeSettingsPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopPurgeSettingsPrompt3"}
  ],
  "classicPage": "EnsPortal.PurgeSettings",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "purge setting",
    "source": {"port": "interop", "endpoint": "PurgeSettings", "type": "LIST"},
    "fields": ["Name", "Value", "Stored", "Kind", "Accepts"],
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
    "emptyNextKey": "",
    "emptyAgentKey": "interopPurgeSettingsEmptyAgent"
  },
  "toolIdentifier": "interop.purgesettings"
}
}

}
