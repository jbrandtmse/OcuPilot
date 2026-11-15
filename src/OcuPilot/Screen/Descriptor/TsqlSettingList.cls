/// <p>TSQL settings: the TSQL compatibility settings, read through <code>%SYSTEM.TSQL</code>, read through <class>OcuPilot.Port.ConfigPort</class> (source kind <code>config</code>, endpoint
/// <code>TSQL</code>) and rendered by the <code>list</code> archetype's page from the declared <code>table</code> (AD-5, AD-29,
/// AD-36, AD-53, Story 21.4). It is OS management's thirty-first side-bar entry.</p>
/// <p><b>Its pairs</b> are the classic page's: <code>%Admin_Manage:USE</code> and <code>%DB_IRISSYS:READ</code> (AD-8,
/// AD-44). Its tool adds <code>%DB_IRISSYS:WRITE</code>, which the settings' <code>^%SYS</code> nodes need.</p>
/// <p><b>Its id is the TSQL setting's name</b>, kept exactly (AD-13). Its row action Set value is the screen's caller of
/// <class>OcuPilot.Screen.Tool.TsqlSettingSet</class> (AD-53), and a row the port reads as shown and never changed offers none. A change
/// takes effect without a restart, so it shows no Restart column. It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.TsqlSettingList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/tsql-settings",
  "area": "os-management",
  "labelKey": "tsqlSettingsLabel",
  "sideBarPosition": 31,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "tsql-setting",
  "entityLabelKey": "aboutTsqlSetting",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Name"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "set", "selfProtection": ""}],
  "context": {"fields": ["Name", "Value", "Kind", "Accepts", "Restart", "ReadOnly", "Purges"], "secretFields": []},
  "emptyStateKey": "configSettingsEmpty",
  "commandAliases": ["tsql settings"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "tsqlSettingsPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "tsqlSettingsPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "tsqlSettingsPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.SQL.Configure.TSQL",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "TSQL setting",
    "label": "The instance's TSQL compatibility settings; one marked as shown and never changed is not offered for change. The SQL settings are in osmgmt.sqlsettings, the SQL Shell in osmgmt.sqlshellsettings and ISQL in osmgmt.isqlsettings.",
    "source": {"port": "config", "endpoint": "TSQL", "type": "LIST"},
    "fields": ["Name", "Value", "Kind", "Accepts", "Restart", "ReadOnly", "Purges"],
    "filter": ["Name", "Value"],
    "sort": {"fields": ["Name", "Value"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "agentGovernanceColumnSetting", "kind": "name"},
      {"field": "Value", "labelKey": "errorLogColumnValue", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "tsqlSettingsEmptyAgent"
  },
  "toolIdentifier": "osmgmt.tsqlsettings"
}
}

}
