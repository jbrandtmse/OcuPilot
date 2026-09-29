/// <p>License usage's first tab, Summary: the instance's license summary, read as the rows of the
/// <code>Summary</code> member of the vendor's <code>Monitor</code> <code>LICENSEUSAGE</code> answer
/// (<code>source.rows</code>, AD-2, AD-36 as amended, Story 16.7) and rendered by the
/// <code>detail</code> page over the declared <code>table</code> (AD-5).</p>
/// <p><b>It is the tab group's first member and its side-bar entry</b>, the seventh OS management
/// entry; the other three tabs, By process, By user and Distributed, are unlisted routes under it, one
/// descriptor each over the same answer's other members.</p>
/// <p><b>It administers nothing</b>: <code>entityType</code> is <code>""</code> and its <code>id</code>
/// is <code>none</code>, so it carries no change-event key and no row identity (AD-13, AD-14). It
/// declares no action and does not refresh (AD-43).</p>
/// <p><b>The pair set is two</b>: <code>%Admin_Operate:USE</code>, the endpoint's own gate, and
/// <code>%DB_IRISSYS:READ</code>, since the port runs every endpoint in <code>%SYS</code> (AD-2,
/// AD-8, AD-29). The OS management area covers both.</p>
/// <p><b>The classic page</b> is <code>%CSP.UI.Portal.LicenseUsage</code> (AD-44), whose four views
/// these four tabs replace; it declares no exemption.</p>
Class OcuPilot.Screen.Descriptor.LicenseSummaryTab Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/license-usage",
  "area": "os-management",
  "labelKey": "licenseUsageLabel",
  "sideBarPosition": 7,
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
  "context": {"fields": ["LicenseUnitUse", "Local", "Distributed"], "secretFields": []},
  "emptyStateKey": "licenseUsageSummaryEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupCapacity", "textKey": "licenseUsagePrompt1"},
    {"groupKey": "promptGroupCapacity", "textKey": "licenseUsagePrompt2"},
    {"groupKey": "promptGroupCapacity", "textKey": "licenseUsagePrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.LicenseUsage",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Monitor", "type": "LICENSEUSAGE", "rows": "Summary"},
    "fields": ["LicenseUnitUse", "Local", "Distributed"],
    "filter": [],
    "sort": {"fields": ["LicenseUnitUse", "Local", "Distributed"], "default": "LicenseUnitUse", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "LicenseUnitUse", "labelKey": "licenseUsageUnitUse", "kind": "name"},
      {"field": "Local", "labelKey": "licenseUsageLocal", "kind": "text"},
      {"field": "Distributed", "labelKey": "licenseUsageDistributed", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "os-management/license-usage", "position": 1, "labelKey": "openApiColumnSummary"},
  "toolIdentifier": "osmgmt.licensesummary"
}
}

}
