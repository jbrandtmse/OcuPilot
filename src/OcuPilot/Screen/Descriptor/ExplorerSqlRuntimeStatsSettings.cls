/// <p>System Explorer's Runtime statistics collection: the instance-wide setting behind SQL runtime statistics as four rows, the collection level, the
/// stop in minutes, the level after the stop, and when the stop falls, read through <class>OcuPilot.Port.ConfigPort</class> (source kind
/// <code>config</code>, endpoint <code>SQLStats</code>) and rendered by the <code>list</code> archetype's page from the declared <code>table</code>
/// (AD-5, AD-29, AD-36, AD-53, Story 21.26). It is System Explorer's twenty-second side-bar entry, after SQL runtime statistics.</p>
/// <p><b>Its pairs</b> are the classic page's <code>%Development:USE</code> and <code>%DB_IRISSYS:READ</code>, the system database the setting lives
/// in (AD-8, AD-44). Its tool adds <code>%DB_IRISSYS:WRITE</code>.</p>
/// <p><b>Its id is the row's name</b>, kept exactly (AD-13). Its row action Set value is the screen's caller of
/// <class>OcuPilot.Screen.Tool.ExplorerSqlRuntimeStatsSettingSet</class> (AD-53), and the row the port reads as shown and never changed offers none.
/// It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerSqlRuntimeStatsSettings Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/sql-runtime-stats-settings",
  "area": "system-explorer",
  "labelKey": "runtimeStatsSettingsLabel",
  "sideBarPosition": 22,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Development", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "sql-runtime-stats-setting",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Name"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "set", "selfProtection": ""}],
  "context": {"fields": ["Name", "Value", "Kind", "Accepts", "Restart", "ReadOnly", "Purges"], "secretFields": []},
  "emptyStateKey": "configSettingsEmpty",
  "commandAliases": ["runtime statistics settings"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "runtimeStatsSettingsPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "explorerSqlRuntimeStatsPrompt3"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "explorerSqlRuntimeStatsPrompt2"}
  ],
  "classicPage": "%CSP.UI.Portal.SQL.QButtons.RuntimeStatsSettings",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "runtime statistics setting",
    "label": "Whether this instance collects SQL runtime statistics, when the collection stops and what it falls back to; the statistics themselves are in explorer.sqlruntimestats.",
    "source": {"port": "config", "endpoint": "SQLStats", "type": "LIST"},
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
    "emptyAgentKey": "runtimeStatsSettingsEmptyAgent"
  },
  "toolIdentifier": "explorer.sqlruntimestatssettings"
}
}

}
