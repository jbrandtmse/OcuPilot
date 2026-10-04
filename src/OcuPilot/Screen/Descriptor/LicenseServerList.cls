/// <p>License servers: the license servers this instance defines, read through the vendor's own
/// <code>License.Server</code> <code>LIST</code> (AD-2, AD-36, Story 18.6) and rendered by the
/// <code>list</code> archetype's page from the declared <code>table</code> (AD-5). It is OS
/// management's sixteenth side-bar entry.</p>
/// <p><b>Its id is the server's name</b>, which the instance stores upper-cased and resolves in any
/// case (AD-13's <code>foldcase</code>). Its Create opens
/// <class>OcuPilot.Screen.Descriptor.LicenseServerForm</class>, as does a row's name cell; its row
/// action Delete is the screen's caller of <class>OcuPilot.Screen.Tool.LicenseServerDelete</class>
/// (AD-53). <code>KeyDirectory</code> is shown and never set (AD-21).</p>
/// <p><b>Its pairs are OS management's</b>, <code>%Admin_Manage:USE</code> and
/// <code>%DB_IRISSYS:READ</code>, the classic page's <code>RESOURCE</code>; the three write tools add
/// <code>%DB_IRISSYS:WRITE</code> (AD-8, measured at Story 18.6's Task 0).</p>
Class OcuPilot.Screen.Descriptor.LicenseServerList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/license-servers",
  "area": "os-management",
  "labelKey": "licenseServerListLabel",
  "sideBarPosition": 16,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "license-server",
  "entityLabelKey": "aboutLicenseServer",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [{"id": "delete", "selfProtection": ""}],
  "context": {"fields": ["Name", "Address", "Port", "KeyDirectory"], "secretFields": []},
  "emptyStateKey": "licenseServerListEmpty",
  "commandAliases": ["license servers", "create license server"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupCapacity", "textKey": "licenseServerListPrompt1"},
    {"groupKey": "promptGroupCapacity", "textKey": "licenseServerListPrompt2"},
    {"groupKey": "promptGroupCapacity", "textKey": "licenseServerListPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.LicenseServers",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "License.Server", "type": "LIST"},
    "fields": ["Name", "Address", "Port", "KeyDirectory"],
    "filter": ["Name", "Address", "Port", "KeyDirectory"],
    "sort": {"fields": ["Name", "Address", "Port", "KeyDirectory"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Address", "labelKey": "languageServerFieldAddress", "kind": "identifier"},
      {"field": "Port", "labelKey": "sslTestPort", "kind": "number"},
      {"field": "KeyDirectory", "labelKey": "licenseServerKeyDirectory", "kind": "identifier"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "licenseServerListEmptyAgent"
  },
  "toolIdentifier": "osmgmt.licenseservers"
}
}

}
