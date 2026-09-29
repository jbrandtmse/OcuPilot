/// <p>License usage's third tab, By user: one row per user holding a license unit, read as the rows
/// of the <code>UsageByUser</code> member of the vendor's <code>Monitor</code>
/// <code>LICENSEUSAGE</code> answer (<code>source.rows</code>, AD-36 as amended, Story 16.7). An
/// instance serving only REST traffic answers none, and the tab shows its empty state.</p>
/// <p>An unlisted route under the group's first tab, <class>OcuPilot.Screen.Descriptor.LicenseSummaryTab</class>,
/// which carries the side-bar entry (AD-5). It administers nothing, declares no action, does not
/// refresh, and shares that tab's pair set, classic page and suggested prompts.</p>
Class OcuPilot.Screen.Descriptor.LicenseUserTab Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/license-usage/users",
  "area": "os-management",
  "labelKey": "licenseUsageByUser",
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
  "context": {"fields": ["UserId", "Type", "Connects", "MaxCon", "CSPCon", "LU", "Active", "Grace"], "secretFields": []},
  "emptyStateKey": "licenseUsageUsersEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupCapacity", "textKey": "licenseUsagePrompt1"},
    {"groupKey": "promptGroupCapacity", "textKey": "licenseUsagePrompt2"},
    {"groupKey": "promptGroupCapacity", "textKey": "licenseUsagePrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.LicenseUsage",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Monitor", "type": "LICENSEUSAGE", "rows": "UsageByUser"},
    "fields": ["UserId", "Type", "Connects", "MaxCon", "CSPCon", "LU", "Active", "Grace"],
    "filter": ["UserId", "Type"],
    "sort": {"fields": ["UserId", "Type", "Connects", "MaxCon", "CSPCon", "LU", "Active", "Grace"], "default": "UserId", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "UserId", "labelKey": "licenseUsageUserId", "kind": "name"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "Connects", "labelKey": "sslPromptGroupConnections", "kind": "number"},
      {"field": "MaxCon", "labelKey": "licenseUsageMaxConnections", "kind": "number"},
      {"field": "CSPCon", "labelKey": "webSessionListLabel", "kind": "number"},
      {"field": "LU", "labelKey": "licenseUsageUnits", "kind": "number"},
      {"field": "Active", "labelKey": "licenseUsageActiveTime", "kind": "number"},
      {"field": "Grace", "labelKey": "licenseUsageGraceTime", "kind": "number"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "os-management/license-usage", "position": 3, "labelKey": "licenseUsageByUser"},
  "toolIdentifier": "osmgmt.licenseusers"
}
}

}
