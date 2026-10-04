/// <p>ECP settings: how this instance acts as an ECP application server and as an ECP data server, one
/// <code>form-page</code> over the vendor's <code>ECP.Settings</code> <code>GET</code> (AD-5, AD-36, Story
/// 18.21), so the form and <code>osmgmt.ecpsettings.read</code> answer one read of the six members,
/// projected as <code>&lt;Object&gt;.&lt;member&gt;</code> fields. OS management's eighteenth entry.</p>
/// <p><b>These screens rely on the admin API's routes alone</b>: the harvested ECP status implementation
/// was never identified (epics.md Story 18.21).</p>
/// <p><b>Its pairs are OS management's and <code>%Admin_Secure:USE</code></b>, the screen's own pair: the
/// vendor's read calls <code>Security.System.Get</code> and answers a caller without it 500, and a
/// <code>PUT</code> without it stores its <code>Config.*</code> members before failing (AD-8, measured at
/// Task 0). The classic page's <code>RESOURCE</code> is <code>%Admin_Manage</code>.</p>
/// <p><b>Its write is <class>OcuPilot.Screen.Tool.EcpSettingsUpdate</class></b>, reached by the page's own
/// Save (<class>OcuPilot.Area.OsMgmt.EcpSettingsSave</class>) and by the agent's confirmed proposal
/// (AD-55); its form read is <code>GET /ecp-settings/form</code>
/// (<class>OcuPilot.Area.OsMgmt.EcpSettingsRules</class>). It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.EcpSettings Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/ecp-settings",
  "area": "os-management",
  "labelKey": "ecpSettingsLabel",
  "sideBarPosition": 18,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Admin_Secure", "permission": "USE"}],
  "entityType": "ecp-settings",
  "entityLabelKey": "ecpSettingsLabel",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["AppServerSettings.MaxServers", "AppServerSettings.ClientReconnectDuration", "AppServerSettings.ClientReconnectInterval", "DataServerSettings.MaxServerConn", "DataServerSettings.ServerTroubleDuration", "DataServerSettings.SSLECPServer"], "secretFields": []},
  "emptyStateKey": "",
  "commandAliases": ["ecp settings"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "ecpSettingsPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "ecpSettingsPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "ecpSettingsPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.ECP",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "ECP.Settings", "type": "GET"},
    "fields": ["AppServerSettings.MaxServers", "AppServerSettings.ClientReconnectDuration", "AppServerSettings.ClientReconnectInterval", "DataServerSettings.MaxServerConn", "DataServerSettings.ServerTroubleDuration", "DataServerSettings.SSLECPServer"],
    "filter": ["AppServerSettings.MaxServers"],
    "sort": {"fields": ["AppServerSettings.MaxServers"], "default": "AppServerSettings.MaxServers", "direction": "asc"},
    "paging": "cap"
  },
  "toolIdentifier": "osmgmt.ecpsettings"
}
}

}
