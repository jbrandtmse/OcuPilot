/// <p>System-wide security: the system-wide security parameters of <code>Security.System</code> that the classic Parameters page shows, each with its
/// value and the values it accepts, read through <class>OcuPilot.Port.ConfigPort</class> (source kind <code>config</code>, endpoint
/// <code>Security</code>) and rendered by the <code>list</code> archetype's page from the declared <code>table</code> (AD-5, AD-29, AD-35, AD-36,
/// AD-53, Story 21.10). It is Security's fourteenth side-bar entry.</p>
/// <p><b>Its pairs</b> are the port's read set: <code>%Admin_Manage:USE</code> as its own beyond Security's, <code>%Admin_Secure:USE</code>, which the
/// vendor's <code>Get</code> and <code>Modify</code> need, and <code>%DB_IRISSYS:READ</code> (AD-8, AD-44). Its tool adds
/// <code>%DB_IRISSYS:WRITE</code>.</p>
/// <p><b>Its id is the parameter's name</b>, kept exactly (AD-13). Its row action Set value is the screen's caller of
/// <class>OcuPilot.Screen.Tool.SystemSecuritySettingSet</class> (AD-53), and a row the port reads as shown and never changed offers none. The
/// rows are the port's roster and no other property of the class (AD-35). It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.SystemSecuritySettingList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/system-security",
  "area": "security",
  "labelKey": "systemSecuritySettingsLabel",
  "sideBarPosition": 14,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Admin_Manage", "permission": "USE"}],
  "entityType": "system-security-setting",
  "entityLabelKey": "aboutSystemSecuritySetting",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Name"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "set", "selfProtection": ""}],
  "context": {"fields": ["Name", "Value", "Kind", "Accepts", "Restart", "ReadOnly"], "secretFields": []},
  "emptyStateKey": "configSettingsEmpty",
  "commandAliases": ["system security", "system-wide security"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "systemSecuritySettingsPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "systemSecuritySettingsPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "systemSecuritySettingsPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.Parameters",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "system-wide security parameter",
    "label": "The instance's system-wide security parameters: how sign-in, lockout, password expiry and audit flags behave for every user. Each row says whether it is shown and never changed here.",
    "source": {"port": "config", "endpoint": "Security", "type": "LIST"},
    "fields": ["Name", "Value", "Kind", "Accepts", "Restart", "ReadOnly"],
    "filter": ["Name", "Value"],
    "sort": {"fields": ["Name", "Value"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "agentGovernanceColumnSetting", "kind": "name"},
      {"field": "Value", "labelKey": "errorLogColumnValue", "kind": "text"},
      {"field": "Restart", "labelKey": "actionRestart", "kind": "status"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "systemSecuritySettingsEmptyAgent"
  },
  "toolIdentifier": "security.systemsecurity"
}
}

}
