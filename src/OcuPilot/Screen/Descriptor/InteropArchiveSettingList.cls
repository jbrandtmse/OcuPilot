/// <p>Interoperability's Archive settings: the three settings of the classic Archive Manager page, one name and value row each, which the next archive run of the namespace uses,
/// read through <class>OcuPilot.Port.InteropPort</class> (source kind <code>interop</code>, endpoint <code>ArchiveSettings</code>) and rendered by the <code>list</code> archetype's page
/// over the declared <code>table</code> (AD-5, AD-29, AD-36, AD-44, AD-62, Story 24.16 Batch 4). A setting that is not stored reads the vendor's default, with <code>Stored</code> false.</p>
/// <p><b>Its row action</b> Set value changes one setting through <class>OcuPilot.Screen.Tool.InteropArchiveSettingSet</class> (AD-53, AD-55); it is stored at once, and each setting is
/// set by itself rather than through a whole-form Save. The archive class row is shown and never changed.</p>
/// <p><b>Its pairs</b> are the classic page's: <code>%Ens_Portal:USE</code> and, as its own, <code>%Ens_ArchiveManager:READ</code>; the tool adds WRITE on the page's resource and on the
/// namespace's globals database (AD-8, AD-62). <b>Its id is the setting's name</b>, kept exactly (AD-13), and its scope is <code>namespace</code>. It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.InteropArchiveSettingList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/archive-settings",
  "area": "interoperability",
  "labelKey": "interopArchiveSettingsLabel",
  "sideBarPosition": 20,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_ArchiveManager", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_ArchiveManager", "permission": "READ"}],
  "entityType": "interop-archive-setting",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "set", "selfProtection": ""}],
  "context": {"fields": ["Name", "Value", "Stored", "Kind", "Accepts", "ReadOnly"], "secretFields": []},
  "emptyStateKey": "interopArchiveSettingsEmpty",
  "commandAliases": ["archive settings", "change an archive setting"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopArchivePrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopArchivePrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopArchiveSettingsPrompt1"}
  ],
  "classicPage": "EnsPortal.ArchiveManager",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "archive setting",
    "source": {"port": "interop", "endpoint": "ArchiveSettings", "type": "LIST"},
    "fields": ["Name", "Value", "Stored", "Kind", "Accepts", "ReadOnly"],
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
    "emptyAgentKey": "interopArchiveSettingsEmptyAgent"
  },
  "toolIdentifier": "interop.archivesettings"
}
}

}
