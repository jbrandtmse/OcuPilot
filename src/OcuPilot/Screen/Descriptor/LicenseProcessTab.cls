/// <p>License usage's second tab, By process: one row per process holding a license entry, read as
/// the rows of the <code>UsageByProcess</code> member of the vendor's <code>Monitor</code>
/// <code>LICENSEUSAGE</code> answer (<code>source.rows</code>, AD-36 as amended, Story 16.7).</p>
/// <p>An unlisted route under the group's first tab, <class>OcuPilot.Screen.Descriptor.LicenseSummaryTab</class>,
/// which carries the side-bar entry (AD-5). It administers nothing, declares no action, does not
/// refresh, and shares that tab's pair set, classic page and suggested prompts.</p>
Class OcuPilot.Screen.Descriptor.LicenseProcessTab Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/license-usage/processes",
  "area": "os-management",
  "labelKey": "licenseUsageByProcess",
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
  "context": {"fields": ["PID", "Process", "LID", "Type", "Con", "Active", "CSPCon", "LU", "Grace"], "secretFields": []},
  "emptyStateKey": "licenseUsageProcessesEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupCapacity", "textKey": "licenseUsagePrompt1"},
    {"groupKey": "promptGroupCapacity", "textKey": "licenseUsagePrompt2"},
    {"groupKey": "promptGroupCapacity", "textKey": "licenseUsagePrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.LicenseUsage",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Monitor", "type": "LICENSEUSAGE", "rows": "UsageByProcess"},
    "fields": ["PID", "Process", "LID", "Type", "Con", "Active", "CSPCon", "LU", "Grace"],
    "filter": ["Process", "LID", "Type"],
    "sort": {"fields": ["PID", "Process", "LID", "Type", "Con", "Active", "CSPCon", "LU", "Grace"], "default": "PID", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "PID", "labelKey": "processColumnPid", "kind": "name"},
      {"field": "Process", "labelKey": "licenseUsageLoginId", "kind": "text"},
      {"field": "LID", "labelKey": "licenseUsageUserId", "kind": "text"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "Con", "labelKey": "sslPromptGroupConnections", "kind": "number"},
      {"field": "Active", "labelKey": "licenseUsageActiveTime", "kind": "number"},
      {"field": "CSPCon", "labelKey": "webSessionListLabel", "kind": "number"},
      {"field": "LU", "labelKey": "licenseUsageUnits", "kind": "number"},
      {"field": "Grace", "labelKey": "licenseUsageGraceTime", "kind": "number"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "os-management/license-usage", "position": 2, "labelKey": "licenseUsageByProcess"},
  "toolIdentifier": "osmgmt.licenseprocesses"
}
}

}
