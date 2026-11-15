/// <p>SQL settings: the settings of <code>Config.SQL</code>, each with its value, whether a change purges the cached queries of every namespace and whether it is offered for change, read through <class>OcuPilot.Port.ConfigPort</class> (source kind <code>config</code>, endpoint
/// <code>SQL</code>) and rendered by the <code>list</code> archetype's page from the declared <code>table</code> (AD-5, AD-29,
/// AD-36, AD-53, Story 21.4). It is OS management's twenty-ninth side-bar entry.</p>
/// <p><b>Its pairs</b> are the classic page's: <code>%Admin_Manage:USE</code> and <code>%DB_IRISSYS:READ</code> (AD-8,
/// AD-44). Its tool adds <code>%DB_IRISSYS:WRITE</code>, which the vendor's <code>Config</code> writes need.</p>
/// <p><b>Its id is the <code>Config.SQL</code> setting's name</b>, kept exactly (AD-13). Its row action Set value is the screen's caller of
/// <class>OcuPilot.Screen.Tool.SqlSettingSet</class> (AD-53), and a row the port reads as shown and never changed offers none. A change
/// takes effect without a restart, so it shows no Restart column. It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.SqlSettingList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/sql-settings",
  "area": "os-management",
  "labelKey": "sqlSettingsLabel",
  "sideBarPosition": 29,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "sql-setting",
  "entityLabelKey": "aboutSqlSetting",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Name"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "set", "selfProtection": ""}],
  "context": {"fields": ["Name", "Value", "Kind", "Accepts", "Restart", "ReadOnly", "Purges"], "secretFields": []},
  "emptyStateKey": "configSettingsEmpty",
  "commandAliases": ["sql settings"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "sqlSettingsPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "sqlSettingsPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "sqlSettingsPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.SQL.Configure.SQL",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "SQL setting",
    "label": "The instance's SQL settings; one marked as shown and never changed is not offered for change. The SQL Shell, TSQL and ISQL settings are in osmgmt.sqlshellsettings, osmgmt.tsqlsettings and osmgmt.isqlsettings.",
    "source": {"port": "config", "endpoint": "SQL", "type": "LIST"},
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
    "emptyAgentKey": "sqlSettingsEmptyAgent"
  },
  "toolIdentifier": "osmgmt.sqlsettings"
}
}

}
