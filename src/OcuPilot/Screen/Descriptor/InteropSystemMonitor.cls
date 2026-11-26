/// <p>Interoperability's System monitor: the classic Interoperability System Monitor's twenty-five scalar meters, read as one row through <class>OcuPilot.Port.InteropPort</class> (source kind
/// <code>interop</code>, endpoint <code>SystemMonitor</code>) from the vendor's <code>%SYS.Ensemble.GetEnsMetrics</code>, the classic page's own call, and drawn as meters in groups by the
/// <code>meters</code> archetype's page (AD-5, AD-29, AD-36, AD-62, Story 24.17 Batch 5). Each field carries the vendor's value as text. The page draws the three drill-downs' tables from
/// their own declared reads and links each heading to its screen.</p>
/// <p><b>It administers nothing</b>: <code>entityType</code> is <code>""</code> and its <code>id</code> is <code>none</code> -- one row, the instance's own (AD-13, AD-14). It declares no action.
/// Its scope is <code>instance</code>: the vendor's call answers every namespace's productions at once, so the screen takes no namespace.</p>
/// <p><b>It refreshes at one rate, default off</b> (AD-43): every 60 seconds, the classic page's own refresh rate (<code>EnsembleMonitor.cls</code>, <code>RefreshRate = 60000</code>). The vendor's
/// call writes its own bookkeeping records each time it is made, so nothing here refreshes faster than the classic page does. <b>Its pairs are three</b>: the portal's <code>%Ens_Portal:USE</code>, the classic page's <code>%Ens_Dashboard:USE</code> and
/// <code>%DB_IRISSYS:READ</code>, since the call is made in <code>%SYS</code> (AD-8, AD-29).</p>
Class OcuPilot.Screen.Descriptor.InteropSystemMonitor Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/system-monitor",
  "area": "interoperability",
  "labelKey": "interopSystemMonitorLabel",
  "sideBarPosition": 29,
  "archetype": "meters",
  "built": true,
  "refreshes": true,
  "refreshRates": [60],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_Dashboard", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_Dashboard", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {
    "fields": ["EnsNamespace", "EnsProductionsRunning", "EnsProductionsTroubled", "EnsIncomingRequests", "EnsLastIncomingRequest", "EnsOutgoingRequests", "EnsLastOutgoingRequest", "Processes", "EnsJobs", "EnsVisitingJobs", "UpTime", "LastBackup", "DatabaseSpace", "DatabaseJournal", "JournalSpace", "JournalEntries", "LockTable", "WriteDaemon", "EnsActiveQueues", "SeriousAlerts", "EnsAlerts", "EnsErrors", "LicenseLimit", "LicenseUse", "LicenseUseHigh"],
    "secretFields": []
  },
  "emptyStateKey": "interopSystemMonitorEmpty",
  "commandAliases": ["system monitor", "interoperability system monitor"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopSystemMonitorPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopSystemMonitorPrompt2"},
    {"groupKey": "promptGroupCapacity", "textKey": "interopSystemMonitorPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.EnsembleMonitor",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "set of System Monitor meters",
    "source": {"port": "interop", "endpoint": "SystemMonitor", "type": "LIST"},
    "fields": ["EnsNamespace", "EnsProductionsRunning", "EnsProductionsTroubled", "EnsIncomingRequests", "EnsLastIncomingRequest", "EnsOutgoingRequests", "EnsLastOutgoingRequest", "Processes", "EnsJobs", "EnsVisitingJobs", "UpTime", "LastBackup", "DatabaseSpace", "DatabaseJournal", "JournalSpace", "JournalEntries", "LockTable", "WriteDaemon", "EnsActiveQueues", "SeriousAlerts", "EnsAlerts", "EnsErrors", "LicenseLimit", "LicenseUse", "LicenseUseHigh"],
    "filter": ["EnsNamespace", "EnsProductionsRunning", "EnsProductionsTroubled", "EnsIncomingRequests", "EnsLastIncomingRequest", "EnsOutgoingRequests", "EnsLastOutgoingRequest", "Processes", "EnsJobs", "EnsVisitingJobs", "UpTime", "LastBackup", "DatabaseSpace", "DatabaseJournal", "JournalSpace", "JournalEntries", "LockTable", "WriteDaemon", "EnsActiveQueues", "SeriousAlerts", "EnsAlerts", "EnsErrors", "LicenseLimit", "LicenseUse", "LicenseUseHigh"],
    "sort": {
      "fields": ["EnsNamespace", "EnsProductionsRunning", "EnsProductionsTroubled", "EnsIncomingRequests", "EnsLastIncomingRequest", "EnsOutgoingRequests", "EnsLastOutgoingRequest", "Processes", "EnsJobs", "EnsVisitingJobs", "UpTime", "LastBackup", "DatabaseSpace", "DatabaseJournal", "JournalSpace", "JournalEntries", "LockTable", "WriteDaemon", "EnsActiveQueues", "SeriousAlerts", "EnsAlerts", "EnsErrors", "LicenseLimit", "LicenseUse", "LicenseUseHigh"],
      "default": "UpTime",
      "direction": "asc"
    },
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "EnsNamespace", "labelKey": "interopSystemMonitorMeterScopes", "kind": "text"},
      {"field": "EnsProductionsRunning", "labelKey": "interopSystemMonitorMeterProductionsRunning", "kind": "text"},
      {"field": "EnsProductionsTroubled", "labelKey": "interopSystemMonitorMeterProductionsTroubled", "kind": "text"},
      {"field": "EnsIncomingRequests", "labelKey": "interopSystemMonitorMeterIncoming", "kind": "text"},
      {"field": "EnsLastIncomingRequest", "labelKey": "interopSystemMonitorMeterLastIncoming", "kind": "text"},
      {"field": "EnsOutgoingRequests", "labelKey": "interopSystemMonitorMeterOutgoing", "kind": "text"},
      {"field": "EnsLastOutgoingRequest", "labelKey": "interopSystemMonitorMeterLastOutgoing", "kind": "text"},
      {"field": "Processes", "labelKey": "processListLabel", "kind": "text"},
      {"field": "EnsJobs", "labelKey": "interopSystemMonitorMeterJobs", "kind": "text"},
      {"field": "EnsVisitingJobs", "labelKey": "interopSystemMonitorMeterVisitingJobs", "kind": "text"},
      {"field": "UpTime", "labelKey": "systemInfoUptime", "kind": "name"},
      {"field": "LastBackup", "labelKey": "dashboardLastBackup", "kind": "text"},
      {"field": "DatabaseSpace", "labelKey": "systemUsageDatabaseSpace", "kind": "text"},
      {"field": "DatabaseJournal", "labelKey": "dashboardDatabaseJournal", "kind": "text"},
      {"field": "JournalSpace", "labelKey": "systemUsageJournalSpace", "kind": "text"},
      {"field": "JournalEntries", "labelKey": "systemUsageJournalEntries", "kind": "text"},
      {"field": "LockTable", "labelKey": "systemUsageLockTable", "kind": "text"},
      {"field": "WriteDaemon", "labelKey": "systemUsageWriteDaemon", "kind": "text"},
      {"field": "EnsActiveQueues", "labelKey": "interopSystemMonitorMeterActiveQueues", "kind": "text"},
      {"field": "SeriousAlerts", "labelKey": "dashboardSeriousAlerts", "kind": "text"},
      {"field": "EnsAlerts", "labelKey": "interopSystemMonitorMeterAlerts", "kind": "text"},
      {"field": "EnsErrors", "labelKey": "interopSystemMonitorMeterErrors", "kind": "text"},
      {"field": "LicenseLimit", "labelKey": "dashboardLicenseLimit", "kind": "text"},
      {"field": "LicenseUse", "labelKey": "dashboardLicenseUse", "kind": "text"},
      {"field": "LicenseUseHigh", "labelKey": "dashboardLicenseUseHigh", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "interop.systemmonitor"
}
}

}
