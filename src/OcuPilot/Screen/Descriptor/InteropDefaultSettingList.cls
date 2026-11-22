/// <p>Interoperability's System default settings: the values the namespace gives a setting in every production, item and host class its
/// key matches, which the classic System Default Settings page keeps, read through <class>OcuPilot.Port.InteropPort</class> (source kind
/// <code>interop</code>, endpoint <code>DefaultSettings</code>) and rendered from the declared <code>table</code> (AD-5, AD-29, AD-36,
/// AD-62, Story 24.15).</p>
/// <p><b>Its primary action</b> New default setting and <b>its row actions</b> Edit and Remove are the screen's callers of
/// <class>OcuPilot.Screen.Tool.InteropDefaultSettingAdd</class>, <class>OcuPilot.Screen.Tool.InteropDefaultSettingUpdate</class> and
/// <class>OcuPilot.Screen.Tool.InteropDefaultSettingRemove</class> (AD-53, AD-55); each is stored at once, and a running production uses
/// the change once it is updated. New default setting and Edit open one dialog; Edit shows the key read-only, because a key cannot be
/// changed. Remove types the setting's name.</p>
/// <p><b>A setting whose name matches the credential pattern is listed with an empty value and <code>Secret</code> true</b>, by the port,
/// so the value never reaches the screen, the context, the read tool or the ledger (AD-35, AD-36); that is why <code>secretFields</code> is
/// empty here. A value, a description and a name are untrusted content (AD-11, AD-60).</p>
/// <p><b>Its id is the composite <code>[Production, Item, HostClass, Setting]</code></b>, each part kept exactly (AD-13), and its scope is
/// <code>namespace</code>. Its pairs are the classic page's: <code>%Ens_Portal:USE</code> and, as its own,
/// <code>%Ens_SystemDefaultConfig:READ</code>; the three tools add <code>%Ens_SystemDefaultConfig:WRITE</code> and WRITE on the namespace's
/// globals database, and the port asks the classic page's per-setting rules at each write (AD-8, AD-62). It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.InteropDefaultSettingList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/default-settings",
  "area": "interoperability",
  "labelKey": "interopDefaultSettingsLabel",
  "sideBarPosition": 12,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_SystemDefaultConfig", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_SystemDefaultConfig", "permission": "READ"}],
  "entityType": "default-setting",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Production", "Item", "HostClass", "Setting"]},
  "primaryAction": {"id": "add", "selfProtection": ""},
  "rowActions": [{"id": "edit", "selfProtection": ""}, {"id": "remove", "selfProtection": ""}],
  "context": {"fields": ["Production", "Item", "HostClass", "Setting", "Value", "Description", "Deployable", "Secret"], "secretFields": []},
  "emptyStateKey": "interopDefaultSettingsEmpty",
  "commandAliases": ["default settings", "system default settings"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopDefaultSettingsPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopDefaultSettingsPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopDefaultSettingsPrompt3"}
  ],
  "classicPage": "EnsPortal.DefaultSettings",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "system default setting",
    "source": {"port": "interop", "endpoint": "DefaultSettings", "type": "LIST"},
    "fields": ["Production", "Item", "HostClass", "Setting", "Value", "Description", "Deployable", "Secret"],
    "filter": ["Production", "Item", "HostClass", "Setting", "Value"],
    "sort": {"fields": ["Production", "Item", "HostClass", "Setting"], "default": "Production", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Production", "labelKey": "systemInfoProduction", "kind": "text"},
      {"field": "Item", "labelKey": "interopItemSettingsCriterionItem", "kind": "text"},
      {"field": "HostClass", "labelKey": "interopItemColumnClass", "kind": "identifier"},
      {"field": "Setting", "labelKey": "agentGovernanceColumnSetting", "kind": "name"},
      {"field": "Value", "labelKey": "errorLogColumnValue", "kind": "text"},
      {"field": "Deployable", "labelKey": "interopDefaultSettingColumnDeployable", "kind": "status"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "interopDefaultSettingsEmptyAgent"
  },
  "toolIdentifier": "interop.defaultsettings"
}
}

}
