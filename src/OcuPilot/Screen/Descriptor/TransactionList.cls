/// <p>Transactions: the open transactions the System Monitor records, local then remote, read through
/// <class>OcuPilot.Port.MonitorPort</class> (AD-29, AD-36) and rendered by the <code>list</code> archetype's page
/// from the declared <code>table</code> (AD-5). OS management's thirty-eighth side-bar entry (Story 21.20).</p>
/// <p><b>Its scope is <code>instance</code></b> and its id is <code>none</code>: a row is named by its kind and
/// process together, and the screen takes no action. A local row's Process ID opens Process details by
/// <code>ProcessID</code>, unless <code>Remote</code> reads true: a remote row names no local process
/// (AD-5). The status column reads the monitor's own status for the row's kind.</p>
/// <p><b>Its pairs are the port's</b>, <code>%Admin_Operate:USE</code> and <code>%DB_IRISSYS:READ</code>, which OS
/// management's set covers, so it declares no own pair. While the System Monitor is not running the read is
/// answered 409 <code>MONITOR.NOTRUNNING</code>. The classic page is <code>%CSP.UI.Portal.Transactions</code>; as a
/// list archetype it links out to nothing (AD-44).</p>
Class OcuPilot.Screen.Descriptor.TransactionList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/transactions",
  "area": "os-management",
  "labelKey": "transactionsLabel",
  "sideBarPosition": 38,
  "archetype": "list",
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
  "context": {"fields": ["Kind", "ProcessID", "Seconds", "Status", "Remote"], "secretFields": []},
  "emptyStateKey": "transactionsEmpty",
  "commandAliases": ["transactions", "open transactions"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "transactionsPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "sqlActivityPrompt3"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "processListPrompt2"}
  ],
  "classicPage": "%CSP.UI.Portal.Transactions",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "open transaction",
    "source": {"port": "monitor", "endpoint": "Transactions", "type": "LIST"},
    "fields": ["Kind", "ProcessID", "Seconds", "Status", "Remote"],
    "filter": ["Kind", "ProcessID", "Status"],
    "sort": {"fields": ["Kind", "ProcessID", "Seconds", "Status"], "default": "Seconds", "direction": "desc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "ProcessID", "labelKey": "processColumnPid", "kind": "name"},
      {"field": "Kind", "labelKey": "agentLedgerColumnKind", "kind": "text"},
      {"field": "Seconds", "labelKey": "transactionsColumnSeconds", "kind": "number"},
      {"field": "Status", "labelKey": "taskHistoryColumnStatus", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "rowTarget": {"route": "os-management/processes/details", "field": "ProcessID", "unless": "Remote"},
  "toolIdentifier": "osmgmt.transactions"
}
}

}
