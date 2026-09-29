/// <p>License usage's fourth tab, Distributed: the license connections, read as the rows of the
/// <code>ConnectionList</code> member of the vendor's <code>Monitor</code> <code>LICENSEUSAGE</code>
/// answer (<code>source.rows</code>, AD-36 as amended, Story 16.7), drawn as the vendor answers them.
/// On a single-server key they are the instance's own, and the Summary's Distributed column carries
/// the vendor's own words for the missing license server.</p>
/// <p>An unlisted route under the group's first tab, <class>OcuPilot.Screen.Descriptor.LicenseSummaryTab</class>,
/// which carries the side-bar entry (AD-5). It administers nothing, declares no action, does not
/// refresh, and shares that tab's pair set, classic page and suggested prompts.</p>
Class OcuPilot.Screen.Descriptor.LicenseDistributedTab Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/license-usage/distributed",
  "area": "os-management",
  "labelKey": "licenseUsageDistributed",
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
  "context": {"fields": ["UserId", "LicenseUnits", "Connections", "ServerIP", "Instance"], "secretFields": []},
  "emptyStateKey": "licenseUsageDistributedEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupCapacity", "textKey": "licenseUsagePrompt1"},
    {"groupKey": "promptGroupCapacity", "textKey": "licenseUsagePrompt2"},
    {"groupKey": "promptGroupCapacity", "textKey": "licenseUsagePrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.LicenseUsage",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Monitor", "type": "LICENSEUSAGE", "rows": "ConnectionList"},
    "fields": ["UserId", "LicenseUnits", "Connections", "ServerIP", "Instance"],
    "filter": ["UserId", "ServerIP"],
    "sort": {"fields": ["UserId", "LicenseUnits", "Connections", "ServerIP", "Instance"], "default": "UserId", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "UserId", "labelKey": "licenseUsageUserId", "kind": "name"},
      {"field": "LicenseUnits", "labelKey": "licenseUsageLicenseUnits", "kind": "number"},
      {"field": "Connections", "labelKey": "sslPromptGroupConnections", "kind": "number"},
      {"field": "ServerIP", "labelKey": "licenseUsageServerIp", "kind": "identifier"},
      {"field": "Instance", "labelKey": "statusSegmentInstance", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "os-management/license-usage", "position": 4, "labelKey": "licenseUsageDistributed"},
  "toolIdentifier": "osmgmt.licensedistributed"
}
}

}
