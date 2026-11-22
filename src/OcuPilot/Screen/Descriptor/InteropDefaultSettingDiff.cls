/// <p>Interoperability's Compare default settings: the system default settings that differ between the namespace the person works in and
/// another one, read through <class>OcuPilot.Port.InteropPort</class> (source kind <code>interop</code>, endpoint
/// <code>DefaultSettingsDiff</code>) in each namespace and rendered by the <code>list (server criteria)</code> archetype's page from the
/// declared <code>table</code> (AD-5, AD-29, AD-36, AD-62, Story 24.15).</p>
/// <p><b>Its one criterion is the read itself</b>: <code>target</code>, the other namespace, which the port refuses when it is this one, is
/// unknown, does not run interoperability, or is one the caller may not read. A row is a setting held only here, only there, or held in both
/// with a different value, description or deployable flag; settings that are the same are not listed. A setting whose name matches the
/// credential pattern shows neither value and still compares (AD-35). The screen only reads: its pairs are the System default settings
/// list's, and no classic page compares namespaces, so <code>classicPage</code> is empty (AD-44). It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.InteropDefaultSettingDiff Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/default-settings-diff",
  "area": "interoperability",
  "labelKey": "interopDefaultSettingsDiffLabel",
  "sideBarPosition": 13,
  "archetype": "list (server criteria)",
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
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Production", "Item", "HostClass", "Setting", "Change", "Value", "OtherValue", "Secret"], "secretFields": []},
  "emptyStateKey": "interopDefaultSettingsDiffEmpty",
  "commandAliases": ["compare default settings", "default settings diff"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopDefaultSettingsDiffPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopDefaultSettingsDiffPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopDefaultSettingsDiffPrompt3"}
  ],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "default setting that differs",
    "source": {"port": "interop", "endpoint": "DefaultSettingsDiff", "type": "LIST"},
    "fields": ["Production", "Item", "HostClass", "Setting", "Change", "Value", "OtherValue", "Secret"],
    "filter": ["Production", "Item", "HostClass", "Setting", "Change"],
    "sort": {"fields": ["Production", "Item", "HostClass", "Setting", "Change"], "default": "Production", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "target", "labelKey": "explorerOtherNamespaceLabel", "kind": "text", "maxLength": 64, "hint": "The namespace to compare this one with, spelled as osmgmt.namespaces.read answers its Name."}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Production", "labelKey": "systemInfoProduction", "kind": "text"},
      {"field": "Item", "labelKey": "interopItemSettingsCriterionItem", "kind": "text"},
      {"field": "HostClass", "labelKey": "interopItemColumnClass", "kind": "identifier"},
      {"field": "Setting", "labelKey": "agentGovernanceColumnSetting", "kind": "name"},
      {"field": "Change", "labelKey": "databaseDirectoryChange", "kind": "text"},
      {"field": "Value", "labelKey": "interopDefaultSettingColumnValueHere", "kind": "text"},
      {"field": "OtherValue", "labelKey": "interopDefaultSettingColumnValueThere", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "interop.defaultsettingsdiff"
}
}

}
