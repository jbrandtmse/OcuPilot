/// <p>License key: the instance's active license key, read through the vendor's own
/// <code>License.Key</code> <code>GET</code> (AD-2, AD-36, Story 18.6) and rendered by its own page
/// over the thirteen fields; <code>osmgmt.licensekey.read</code> answers the same row. It is OS
/// management's fifteenth side-bar entry.</p>
/// <p><b>The authorization key is never returned</b> (AD-36): <code>AuthorizationKey</code> is in the
/// read's fields and in <code>context.secretFields</code>, so neither the screen read nor the tool
/// answers it.</p>
/// <p><b>Its one action is Activate</b>, the screen's caller of
/// <class>OcuPilot.Screen.Tool.LicenseKeyActivate</class> (AD-53), which carries the key's text as the
/// declared secret <code>Key</code> (AD-56); the tool is unadvertised, so no agent tool, dispatch or
/// context lists it. Validate is the page's own check, <code>POST /license/key/validate</code>
/// (<class>OcuPilot.Area.OsMgmt.LicenseRules</class>), and Print is the browser's.</p>
/// <p><b>Its pairs are OS management's</b>, <code>%Admin_Manage:USE</code> and
/// <code>%DB_IRISSYS:READ</code>: the endpoint's <code>ResourcesOR()</code> and the classic page's
/// <code>RESOURCE</code> are <code>%Admin_Manage</code>, and the port runs in <code>%SYS</code>.</p>
Class OcuPilot.Screen.Descriptor.LicenseKey Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/license-key",
  "area": "os-management",
  "labelKey": "licenseKeyLabel",
  "sideBarPosition": 15,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "license-key",
  "entityLabelKey": "licenseKeyLabel",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "activate", "selfProtection": ""},
  "rowActions": [{"id": "activate", "selfProtection": ""}],
  "context": {"fields": ["LicenseCapacity", "CustomerName", "OrderNumber", "Product", "LicenseType", "Server", "Platform", "LicenseUnits", "CoresLicensed", "CoresEnforced", "ExpirationDate", "ExtendedFeaturesList", "AuthorizedApplications"], "secretFields": ["AuthorizationKey"]},
  "secretArguments": ["Key"],
  "emptyStateKey": "licenseKeyEmpty",
  "commandAliases": ["license key", "activate license key"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupCapacity", "textKey": "licenseKeyPrompt1"},
    {"groupKey": "promptGroupCapacity", "textKey": "licenseKeyPrompt2"},
    {"groupKey": "promptGroupCapacity", "textKey": "licenseKeyPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.License.Key",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "License.Key", "type": "GET"},
    "fields": ["LicenseCapacity", "CustomerName", "OrderNumber", "AuthorizationKey", "Product", "LicenseType", "Server", "Platform", "LicenseUnits", "CoresLicensed", "CoresEnforced", "ExpirationDate", "ExtendedFeaturesList", "AuthorizedApplications"],
    "filter": ["CustomerName"],
    "sort": {"fields": ["CustomerName"], "default": "CustomerName", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "CustomerName", "labelKey": "licenseKeyCustomerName", "kind": "name"},
      {"field": "LicenseCapacity", "labelKey": "licenseKeyLicenseCapacity", "kind": "text"},
      {"field": "OrderNumber", "labelKey": "licenseKeyOrderNumber", "kind": "number"},
      {"field": "ExpirationDate", "labelKey": "licenseKeyExpirationDate", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "licenseKeyEmptyAgent"
  },
  "toolIdentifier": "osmgmt.licensekey"
}
}

}
