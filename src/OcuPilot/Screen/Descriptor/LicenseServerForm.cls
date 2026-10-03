/// <p>The license server editor: one license server, created or edited here, rendered by its own
/// <code>form-page</code> (AD-5, Story 18.6). Its Save and the agent's confirmed
/// <code>osmgmt.licenseservers.create</code> and <code>osmgmt.licenseservers.update</code> are two
/// callers of one tool each (AD-55).</p>
/// <p><b>It takes no side-bar position</b> (<code>sideBarPosition</code> 0): it is reached from
/// <class>OcuPilot.Screen.Descriptor.LicenseServerList</class>'s Create and a row's name cell, at that
/// list's route with <code>/edit</code> appended. It declares no <code>read</code>: its form read is
/// <code>GET /license-server/form</code> (<class>OcuPilot.Area.OsMgmt.LicenseRules</class>).</p>
/// <p><b>Its pairs are the list's own</b>; saving needs <code>%DB_IRISSYS:WRITE</code> as well, which
/// <class>OcuPilot.Area.OsMgmt.LicenseServerSave</class> asks before anything is sent. The classic
/// License Servers page edits in place, so its classic key is that page (AD-44).</p>
Class OcuPilot.Screen.Descriptor.LicenseServerForm Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/license-servers/edit",
  "area": "os-management",
  "labelKey": "aboutLicenseServer",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "license-server",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": []},
  "secretArguments": [],
  "fingerprintExcludes": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupCapacity", "textKey": "licenseServerFormPrompt1"},
    {"groupKey": "promptGroupCapacity", "textKey": "licenseServerFormPrompt2"},
    {"groupKey": "promptGroupCapacity", "textKey": "licenseServerFormPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.LicenseServers",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "osmgmt.licenseserverform"
}
}

}
