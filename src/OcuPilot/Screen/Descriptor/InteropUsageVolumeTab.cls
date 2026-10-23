/// <p>Interoperability usage's second tab, Message volume: the messages the instance recorded, one row
/// per namespace and direction, read through <class>OcuPilot.Port.MonitorPort</class>
/// (<code>MessageVolume</code>, AD-29, AD-36) and rendered by the <code>detail</code> page over the
/// declared <code>table</code> (AD-5).</p>
/// <p>An unlisted route under the group's first tab, <class>OcuPilot.Screen.Descriptor.InteropUsageTab</class>,
/// which carries the side-bar entry (AD-5). It administers nothing, declares no action, does not
/// refresh, and shares that tab's pair set, classic page, note and suggested prompts.</p>
Class OcuPilot.Screen.Descriptor.InteropUsageVolumeTab Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/interoperability-usage/volume",
  "area": "os-management",
  "labelKey": "interopUsageVolumeLabel",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Namespace", "Type", "Volume"], "secretFields": []},
  "emptyStateKey": "interopUsageVolumeEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupCapacity", "textKey": "interopUsagePrompt1"},
    {"groupKey": "promptGroupCapacity", "textKey": "interopUsagePrompt2"},
    {"groupKey": "promptGroupCapacity", "textKey": "interopUsagePrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.InteroperabilityUsage",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "namespace's message volume by direction",
    "source": {"port": "monitor", "endpoint": "MessageVolume", "type": "LIST"},
    "fields": ["Namespace", "Type", "Volume"],
    "filter": ["Namespace", "Type"],
    "sort": {"fields": ["Namespace", "Type", "Volume"], "default": "Volume", "direction": "desc"},
    "paging": "cap",
    "note": {"key": "interopUsageNote", "text": "Counts cover all the usage data the instance still keeps, with no date range."}
  },
  "table": {
    "columns": [
      {"field": "Namespace", "labelKey": "headerNamespaceLabel", "kind": "name"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "Volume", "labelKey": "interopItemTabMessages", "kind": "number"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "os-management/interoperability-usage", "position": 2, "labelKey": "interopUsageVolumeLabel"},
  "toolIdentifier": "osmgmt.interopvolume"
}
}

}
