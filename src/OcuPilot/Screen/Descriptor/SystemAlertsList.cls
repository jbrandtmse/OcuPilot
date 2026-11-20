/// <p>System alerts: the instance's system alert state, one row of its state, alert count and last alert, read
/// through <class>OcuPilot.Port.MonitorPort</class> (AD-23, AD-29, AD-36) and rendered by the <code>list</code>
/// archetype's page from the declared <code>table</code> (AD-5). OS management's thirty-ninth side-bar entry
/// (Story 21.20), not Logs: the log hub composes every listed Logs screen, and a member it cannot read fails the hub.</p>
/// <p><b>Its scope is <code>instance</code></b> and its id is <code>none</code>: the state is the instance's alone.
/// Its entity type is the singleton <code>system-alerts</code>. Its one row action, Reset alerts, is the screen's
/// caller of <class>OcuPilot.Screen.Tool.SystemAlertsReset</class> (AD-53); the reset sets the alert count to 0 and
/// the state to OK, and <code>alerts.log</code> keeps every entry.</p>
/// <p><b>Its pairs are the port's</b>, <code>%Admin_Operate:USE</code> and <code>%DB_IRISSYS:READ</code>, which OS
/// management's set covers; the reset adds <code>%Admin_Manage:USE</code>. It has no classic page: the classic
/// portal has no alert reset (AD-44).</p>
Class OcuPilot.Screen.Descriptor.SystemAlertsList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/system-alerts",
  "area": "os-management",
  "labelKey": "systemAlertsLabel",
  "sideBarPosition": 39,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "system-alerts",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "reset", "selfProtection": ""}],
  "context": {"fields": ["State", "StateText", "AlertCount", "LastAlert"], "secretFields": []},
  "emptyStateKey": "explorerSqlDataNoRows",
  "commandAliases": ["system alerts", "alerts", "system state"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "systemAlertsPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "systemUsagePrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "processListPrompt2"}
  ],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "system alert state",
    "source": {"port": "monitor", "endpoint": "Alerts", "type": "LIST"},
    "fields": ["State", "StateText", "AlertCount", "LastAlert"],
    "filter": ["StateText", "LastAlert"],
    "sort": {"fields": ["State", "AlertCount"], "default": "State", "direction": "desc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "StateText", "labelKey": "processColumnState", "kind": "name"},
      {"field": "AlertCount", "labelKey": "systemAlertsColumnAlerts", "kind": "number"},
      {"field": "LastAlert", "labelKey": "systemAlertsColumnLast", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "systemAlertsEmptyAgent"
  },
  "toolIdentifier": "osmgmt.systemalerts"
}
}

}
