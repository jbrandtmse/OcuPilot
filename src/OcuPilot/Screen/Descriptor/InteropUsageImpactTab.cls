/// <p>Interoperability usage's third tab, Database impact: the data message activity created, in
/// megabytes, one row per database, read through <class>OcuPilot.Port.MonitorPort</class>
/// (<code>DatabaseImpact</code>, AD-29, AD-36) and rendered by the <code>detail</code> page over the
/// declared <code>table</code> (AD-5).</p>
/// <p>An unlisted route under the group's first tab, <class>OcuPilot.Screen.Descriptor.InteropUsageTab</class>,
/// which carries the side-bar entry (AD-5). It administers nothing, declares no action, does not
/// refresh, and shares that tab's pair set, classic page, note and suggested prompts. There is no
/// per-namespace view: the vendor's own documentation says a database shared by several namespaces
/// is counted once for each.</p>
Class OcuPilot.Screen.Descriptor.InteropUsageImpactTab Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/interoperability-usage/impact",
  "area": "os-management",
  "labelKey": "interopUsageImpactLabel",
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
  "context": {"fields": ["Database", "DataCreated"], "secretFields": []},
  "emptyStateKey": "interopUsageImpactEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupCapacity", "textKey": "interopUsagePrompt1"},
    {"groupKey": "promptGroupCapacity", "textKey": "interopUsagePrompt2"},
    {"groupKey": "promptGroupCapacity", "textKey": "interopUsagePrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.InteroperabilityUsage",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "database with its message data",
    "source": {"port": "monitor", "endpoint": "DatabaseImpact", "type": "LIST"},
    "fields": ["Database", "DataCreated"],
    "filter": ["Database"],
    "sort": {"fields": ["Database", "DataCreated"], "default": "DataCreated", "direction": "desc"},
    "paging": "cap",
    "note": {"key": "interopUsageNote", "text": "Counts cover all the usage data the instance still keeps, with no date range."}
  },
  "table": {
    "columns": [
      {"field": "Database", "labelKey": "systemInfoDatabase", "kind": "name"},
      {"field": "DataCreated", "labelKey": "interopUsageColumnDataCreated", "kind": "number"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "os-management/interoperability-usage", "position": 3, "labelKey": "interopUsageImpactLabel"},
  "toolIdentifier": "osmgmt.interopimpact"
}
}

}
