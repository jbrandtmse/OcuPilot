/// <p>Dashboard: the classic System Dashboard's seven meter groups (FR-76, Story 16.7), read as one
/// row merged by <code>source.parts</code> from the vendor's <code>Monitor</code>
/// <code>DASHBOARDMAIN</code> answer, as <code>Dashboard</code>, and the sensors' system-wide CPU
/// use, as <code>Sensors</code>, the one part <class>OcuPilot.Port.MonitorPort</class> answers behind
/// its own gate (AD-2, AD-29, AD-36 as amended). A fault on either part fails the whole read.</p>
/// <p><b>It administers nothing</b>: <code>entityType</code> is <code>""</code> and its <code>id</code>
/// is <code>none</code> -- one row, the instance's own (AD-13, AD-14). It declares no action.</p>
/// <p><b>The client draws the thirty fields as meters in seven groups</b> (its own page, not
/// <code>ListPage</code>): status meters carrying the vendor's own word, percent meters for CPU and
/// license use, and value meters carrying no state; the Task manager group issues Upcoming tasks'
/// own declared read beside this one (AD-5). <code>table</code> still declares every field, with
/// <code>Dashboard.Status.UpTime</code> as the required <code>name</code> column, though this screen
/// draws no literal table.</p>
/// <p><b>It is the ninth screen the shared auto-refresh framework binds</b> (AD-43), at the rates
/// <file>EXPERIENCE.md</file>'s auto-refresh bullet declares, default off.</p>
/// <p><b>The pair set is two</b>: <code>%Admin_Operate:USE</code>, the endpoint's own gate and the
/// monitor port's, and <code>%DB_IRISSYS:READ</code>, since both ports run in <code>%SYS</code>
/// (AD-2, AD-8, AD-29). The OS management area covers both.</p>
/// <p><b>The classic page</b> is <code>%cspapp.op.utildashboard</code> (AD-44); as a
/// <code>meters</code> screen it declares no exemption and links out to nothing.</p>
Class OcuPilot.Screen.Descriptor.Dashboard Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/dashboard",
  "area": "os-management",
  "labelKey": "dashboardLabel",
  "sideBarPosition": 9,
  "archetype": "meters",
  "built": true,
  "refreshes": true,
  "refreshRates": [5, 10, 30, 60],
  "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {
    "fields": ["Sensors.cpuUsage", "Dashboard.Performance.GlobalRefsPerSecond", "Dashboard.Performance.GlobalRefs", "Dashboard.Performance.GlobalSetKill", "Dashboard.Performance.RoutineRefs", "Dashboard.Performance.LogicalRequests", "Dashboard.Performance.DiskReads", "Dashboard.Performance.DiskWrites", "Dashboard.Performance.CacheEfficiency", "Dashboard.ECP.ECPClients", "Dashboard.ECP.ECPClientTraffic", "Dashboard.ECP.ECPServers", "Dashboard.ECP.ECPServerTraffic", "Dashboard.ECP.ShadowConnections", "Dashboard.ECP.Shadows", "Dashboard.Status.UpTime", "Dashboard.Status.LastBackup", "Dashboard.SystemUsage.DatabaseSpace", "Dashboard.SystemUsage.DatabaseJournal", "Dashboard.SystemUsage.JournalSpace", "Dashboard.SystemUsage.JournalEntries", "Dashboard.SystemUsage.LockTable", "Dashboard.SystemUsage.WriteDaemon", "Dashboard.SystemUsage.Processes", "Dashboard.SystemUsage.CSPSessions", "Dashboard.Alerts.SeriousAlerts", "Dashboard.Alerts.ApplicationErrors", "Dashboard.Licensing.LicenseLimit", "Dashboard.Licensing.LicenseUse", "Dashboard.Licensing.LicenseUseHigh"],
    "secretFields": []
  },
  "emptyStateKey": "dashboardEmpty",
  "commandAliases": ["dashboard", "system dashboard", "cpu"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "dashboardPrompt1"},
    {"groupKey": "promptGroupCapacity", "textKey": "dashboardPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "dashboardPrompt3"}
  ],
  "classicPage": "%cspapp.op.utildashboard",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {
      "port": "admin",
      "endpoint": "Monitor",
      "type": "GET",
      "parts": [
        {"type": "DASHBOARDMAIN", "as": "Dashboard"},
        {"port": "monitor", "type": "SENSORS", "as": "Sensors"}
      ]
    },
    "fields": ["Sensors.cpuUsage", "Dashboard.Performance.GlobalRefsPerSecond", "Dashboard.Performance.GlobalRefs", "Dashboard.Performance.GlobalSetKill", "Dashboard.Performance.RoutineRefs", "Dashboard.Performance.LogicalRequests", "Dashboard.Performance.DiskReads", "Dashboard.Performance.DiskWrites", "Dashboard.Performance.CacheEfficiency", "Dashboard.ECP.ECPClients", "Dashboard.ECP.ECPClientTraffic", "Dashboard.ECP.ECPServers", "Dashboard.ECP.ECPServerTraffic", "Dashboard.ECP.ShadowConnections", "Dashboard.ECP.Shadows", "Dashboard.Status.UpTime", "Dashboard.Status.LastBackup", "Dashboard.SystemUsage.DatabaseSpace", "Dashboard.SystemUsage.DatabaseJournal", "Dashboard.SystemUsage.JournalSpace", "Dashboard.SystemUsage.JournalEntries", "Dashboard.SystemUsage.LockTable", "Dashboard.SystemUsage.WriteDaemon", "Dashboard.SystemUsage.Processes", "Dashboard.SystemUsage.CSPSessions", "Dashboard.Alerts.SeriousAlerts", "Dashboard.Alerts.ApplicationErrors", "Dashboard.Licensing.LicenseLimit", "Dashboard.Licensing.LicenseUse", "Dashboard.Licensing.LicenseUseHigh"],
    "filter": ["Sensors.cpuUsage", "Dashboard.Performance.GlobalRefsPerSecond", "Dashboard.Performance.GlobalRefs", "Dashboard.Performance.GlobalSetKill", "Dashboard.Performance.RoutineRefs", "Dashboard.Performance.LogicalRequests", "Dashboard.Performance.DiskReads", "Dashboard.Performance.DiskWrites", "Dashboard.Performance.CacheEfficiency", "Dashboard.ECP.ECPClients", "Dashboard.ECP.ECPClientTraffic", "Dashboard.ECP.ECPServers", "Dashboard.ECP.ECPServerTraffic", "Dashboard.ECP.ShadowConnections", "Dashboard.ECP.Shadows", "Dashboard.Status.UpTime", "Dashboard.Status.LastBackup", "Dashboard.SystemUsage.DatabaseSpace", "Dashboard.SystemUsage.DatabaseJournal", "Dashboard.SystemUsage.JournalSpace", "Dashboard.SystemUsage.JournalEntries", "Dashboard.SystemUsage.LockTable", "Dashboard.SystemUsage.WriteDaemon", "Dashboard.SystemUsage.Processes", "Dashboard.SystemUsage.CSPSessions", "Dashboard.Alerts.SeriousAlerts", "Dashboard.Alerts.ApplicationErrors", "Dashboard.Licensing.LicenseLimit", "Dashboard.Licensing.LicenseUse", "Dashboard.Licensing.LicenseUseHigh"],
    "sort": {
      "fields": ["Sensors.cpuUsage", "Dashboard.Performance.GlobalRefsPerSecond", "Dashboard.Performance.GlobalRefs", "Dashboard.Performance.GlobalSetKill", "Dashboard.Performance.RoutineRefs", "Dashboard.Performance.LogicalRequests", "Dashboard.Performance.DiskReads", "Dashboard.Performance.DiskWrites", "Dashboard.Performance.CacheEfficiency", "Dashboard.ECP.ECPClients", "Dashboard.ECP.ECPClientTraffic", "Dashboard.ECP.ECPServers", "Dashboard.ECP.ECPServerTraffic", "Dashboard.ECP.ShadowConnections", "Dashboard.ECP.Shadows", "Dashboard.Status.UpTime", "Dashboard.Status.LastBackup", "Dashboard.SystemUsage.DatabaseSpace", "Dashboard.SystemUsage.DatabaseJournal", "Dashboard.SystemUsage.JournalSpace", "Dashboard.SystemUsage.JournalEntries", "Dashboard.SystemUsage.LockTable", "Dashboard.SystemUsage.WriteDaemon", "Dashboard.SystemUsage.Processes", "Dashboard.SystemUsage.CSPSessions", "Dashboard.Alerts.SeriousAlerts", "Dashboard.Alerts.ApplicationErrors", "Dashboard.Licensing.LicenseLimit", "Dashboard.Licensing.LicenseUse", "Dashboard.Licensing.LicenseUseHigh"],
      "default": "Dashboard.Status.UpTime",
      "direction": "asc"
    },
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Sensors.cpuUsage", "labelKey": "dashboardCpu", "kind": "number"},
      {"field": "Dashboard.Performance.GlobalRefsPerSecond", "labelKey": "systemUsageGlobalRefsPerSecond", "kind": "number"},
      {"field": "Dashboard.Performance.GlobalRefs", "labelKey": "processDetailsGlobalReferences", "kind": "number"},
      {"field": "Dashboard.Performance.GlobalSetKill", "labelKey": "systemUsageGlobalUpdates", "kind": "number"},
      {"field": "Dashboard.Performance.RoutineRefs", "labelKey": "dashboardRoutineReferences", "kind": "number"},
      {"field": "Dashboard.Performance.LogicalRequests", "labelKey": "systemUsageLogicalBlockRequests", "kind": "number"},
      {"field": "Dashboard.Performance.DiskReads", "labelKey": "performanceDiskReads", "kind": "number"},
      {"field": "Dashboard.Performance.DiskWrites", "labelKey": "performanceDiskWrites", "kind": "number"},
      {"field": "Dashboard.Performance.CacheEfficiency", "labelKey": "systemUsageCacheEfficiency", "kind": "number"},
      {"field": "Dashboard.ECP.ECPClients", "labelKey": "dashboardApplicationServers", "kind": "text"},
      {"field": "Dashboard.ECP.ECPClientTraffic", "labelKey": "dashboardApplicationServerTraffic", "kind": "number"},
      {"field": "Dashboard.ECP.ECPServers", "labelKey": "dashboardDataServers", "kind": "text"},
      {"field": "Dashboard.ECP.ECPServerTraffic", "labelKey": "dashboardDataServerTraffic", "kind": "number"},
      {"field": "Dashboard.ECP.ShadowConnections", "labelKey": "dashboardShadowSource", "kind": "text"},
      {"field": "Dashboard.ECP.Shadows", "labelKey": "dashboardShadowServer", "kind": "text"},
      {"field": "Dashboard.Status.UpTime", "labelKey": "systemInfoUptime", "kind": "name"},
      {"field": "Dashboard.Status.LastBackup", "labelKey": "dashboardLastBackup", "kind": "text"},
      {"field": "Dashboard.SystemUsage.DatabaseSpace", "labelKey": "systemUsageDatabaseSpace", "kind": "text"},
      {"field": "Dashboard.SystemUsage.DatabaseJournal", "labelKey": "dashboardDatabaseJournal", "kind": "text"},
      {"field": "Dashboard.SystemUsage.JournalSpace", "labelKey": "systemUsageJournalSpace", "kind": "text"},
      {"field": "Dashboard.SystemUsage.JournalEntries", "labelKey": "systemUsageJournalEntries", "kind": "number"},
      {"field": "Dashboard.SystemUsage.LockTable", "labelKey": "systemUsageLockTable", "kind": "text"},
      {"field": "Dashboard.SystemUsage.WriteDaemon", "labelKey": "systemUsageWriteDaemon", "kind": "text"},
      {"field": "Dashboard.SystemUsage.Processes", "labelKey": "processListLabel", "kind": "number"},
      {"field": "Dashboard.SystemUsage.CSPSessions", "labelKey": "webSessionListLabel", "kind": "number"},
      {"field": "Dashboard.Alerts.SeriousAlerts", "labelKey": "dashboardSeriousAlerts", "kind": "number"},
      {"field": "Dashboard.Alerts.ApplicationErrors", "labelKey": "errorLogListLabel", "kind": "number"},
      {"field": "Dashboard.Licensing.LicenseLimit", "labelKey": "dashboardLicenseLimit", "kind": "number"},
      {"field": "Dashboard.Licensing.LicenseUse", "labelKey": "dashboardLicenseUse", "kind": "number"},
      {"field": "Dashboard.Licensing.LicenseUseHigh", "labelKey": "dashboardLicenseUseHigh", "kind": "number"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "osmgmt.dashboard"
}
}

}
