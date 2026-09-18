/// <p>System usage: the counters and dashboard meters FR-56 asks for, read through the vendor's
/// <code>Monitor</code> endpoint's three unprefixed request types merged into one row by
/// <code>source.parts</code> (AD-2, AD-26, AD-27, AD-36, Story 6.9) -- <code>SYSTEMUSAGE</code> as
/// <code>Usage</code>, <code>SYSTEMUSAGESHM</code> as <code>SharedMemory</code> and
/// <code>DASHBOARDMAIN</code> as <code>Dashboard</code>, resolved by
/// <class>OcuPilot.Port.AdminPort</class>'s <code>BARETYPES</code> map since none of the three
/// carries the vendor's usual <code>TYPE</code> prefix.</p>
/// <p><b>It administers nothing</b>: <code>entityType</code> is <code>""</code>, so it carries no
/// change-event key, and its <code>id</code> is <code>none</code> -- there is one row, the
/// instance's own, and no per-row identity to encode (AD-13, AD-14).</p>
/// <p><b>The client draws seven meters and a counters group from this one row</b> (its own page,
/// not <code>ListPage</code>): Shared memory as <code>SharedMemory.SMHUsed</code> over
/// <code>SharedMemory.SMHAllocated</code>, a percentage meter; Database space, Journal space, Lock
/// table and Write daemon as status meters carrying the dashboard's own Normal / Warning / Troubled
/// word; and Global references per second and Cache efficiency as value meters with no state. The
/// counters group is the nine <code>Usage.*</code> fields. <code>table</code> still declares all
/// eighteen fields, as every read-declaring descriptor does, with <code>Usage.LastUpdate</code> as
/// the required <code>name</code> column even though this screen draws no literal table.</p>
/// <p><b>It is one of the seven screens the shared auto-refresh framework binds</b> (AD-43), at the
/// rates <file>EXPERIENCE.md</file>'s auto-refresh bullet declares.</p>
/// <p><b>The pair set is two</b>: <code>%Admin_Operate:USE</code>, the endpoint's own gate
/// (<code>ResourcesOR()</code> answers it for every <code>Monitor</code> type), and
/// <code>%DB_IRISSYS:READ</code>, since the port runs every endpoint in <code>%SYS</code> (AD-2,
/// AD-8, AD-29).</p>
/// <p><b>The classic page</b> is the key <code>%SYS.Portal.Resources.NormalizePage</code> answers
/// for <code>/csp/sys/op/UtilSysMonitor.csp</code> (AD-44); this screen declares no exemption
/// (<code>meters</code> is a <code>none</code> link-out archetype), so it links out to nothing.
/// FR-76's full System Dashboard, not this screen, is where a CPU meter and a classic link-out
/// would belong.</p>
/// <p>It declares no primary or row action.</p>
Class OcuPilot.Screen.Descriptor.SystemUsage Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/system-usage",
  "area": "os-management",
  "labelKey": "systemUsageLabel",
  "sideBarPosition": 3,
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
    "fields": ["Usage.AllGlobalReferences", "Usage.GlobalUpdateReferences", "Usage.RoutineCalls", "Usage.LogicalBlockRequests", "Usage.BlockReads", "Usage.BlockWrites", "Usage.JournalEntries", "Usage.JournalBlockWrites", "Usage.LastUpdate", "SharedMemory.SMHAllocated", "SharedMemory.SMHUsed", "SharedMemory.SMHAvailable", "Dashboard.Performance.GlobalRefsPerSecond", "Dashboard.Performance.CacheEfficiency", "Dashboard.SystemUsage.DatabaseSpace", "Dashboard.SystemUsage.JournalSpace", "Dashboard.SystemUsage.LockTable", "Dashboard.SystemUsage.WriteDaemon"],
    "secretFields": []
  },
  "emptyStateKey": "systemUsageEmpty",
  "commandAliases": ["system usage", "memory", "shared memory", "global references"],
  "classicPage": "%cspapp.op.utilsysmonitor",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {
      "port": "admin",
      "endpoint": "Monitor",
      "type": "GET",
      "parts": [
        {"type": "SYSTEMUSAGE", "as": "Usage"},
        {"type": "SYSTEMUSAGESHM", "as": "SharedMemory"},
        {"type": "DASHBOARDMAIN", "as": "Dashboard"}
      ]
    },
    "fields": ["Usage.AllGlobalReferences", "Usage.GlobalUpdateReferences", "Usage.RoutineCalls", "Usage.LogicalBlockRequests", "Usage.BlockReads", "Usage.BlockWrites", "Usage.JournalEntries", "Usage.JournalBlockWrites", "Usage.LastUpdate", "SharedMemory.SMHAllocated", "SharedMemory.SMHUsed", "SharedMemory.SMHAvailable", "Dashboard.Performance.GlobalRefsPerSecond", "Dashboard.Performance.CacheEfficiency", "Dashboard.SystemUsage.DatabaseSpace", "Dashboard.SystemUsage.JournalSpace", "Dashboard.SystemUsage.LockTable", "Dashboard.SystemUsage.WriteDaemon"],
    "filter": ["Usage.AllGlobalReferences", "Usage.GlobalUpdateReferences", "Usage.RoutineCalls", "Usage.LogicalBlockRequests", "Usage.BlockReads", "Usage.BlockWrites", "Usage.JournalEntries", "Usage.JournalBlockWrites", "Usage.LastUpdate", "SharedMemory.SMHAllocated", "SharedMemory.SMHUsed", "SharedMemory.SMHAvailable", "Dashboard.Performance.GlobalRefsPerSecond", "Dashboard.Performance.CacheEfficiency", "Dashboard.SystemUsage.DatabaseSpace", "Dashboard.SystemUsage.JournalSpace", "Dashboard.SystemUsage.LockTable", "Dashboard.SystemUsage.WriteDaemon"],
    "sort": {
      "fields": ["Usage.AllGlobalReferences", "Usage.GlobalUpdateReferences", "Usage.RoutineCalls", "Usage.LogicalBlockRequests", "Usage.BlockReads", "Usage.BlockWrites", "Usage.JournalEntries", "Usage.JournalBlockWrites", "Usage.LastUpdate", "SharedMemory.SMHAllocated", "SharedMemory.SMHUsed", "SharedMemory.SMHAvailable", "Dashboard.Performance.GlobalRefsPerSecond", "Dashboard.Performance.CacheEfficiency", "Dashboard.SystemUsage.DatabaseSpace", "Dashboard.SystemUsage.JournalSpace", "Dashboard.SystemUsage.LockTable", "Dashboard.SystemUsage.WriteDaemon"],
      "default": "Usage.LastUpdate",
      "direction": "asc"
    },
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Usage.AllGlobalReferences", "labelKey": "processDetailsGlobalReferences", "kind": "number"},
      {"field": "Usage.GlobalUpdateReferences", "labelKey": "systemUsageGlobalUpdates", "kind": "number"},
      {"field": "Usage.RoutineCalls", "labelKey": "systemUsageRoutineCalls", "kind": "number"},
      {"field": "Usage.LogicalBlockRequests", "labelKey": "systemUsageLogicalBlockRequests", "kind": "number"},
      {"field": "Usage.BlockReads", "labelKey": "systemUsageBlockReads", "kind": "number"},
      {"field": "Usage.BlockWrites", "labelKey": "systemUsageBlockWrites", "kind": "number"},
      {"field": "Usage.JournalEntries", "labelKey": "systemUsageJournalEntries", "kind": "number"},
      {"field": "Usage.JournalBlockWrites", "labelKey": "systemUsageJournalBlockWrites", "kind": "number"},
      {"field": "Usage.LastUpdate", "labelKey": "systemUsageLastUpdate", "kind": "name"},
      {"field": "SharedMemory.SMHAllocated", "labelKey": "systemUsageSharedMemory", "kind": "number"},
      {"field": "SharedMemory.SMHUsed", "labelKey": "systemUsageSharedMemory", "kind": "number"},
      {"field": "SharedMemory.SMHAvailable", "labelKey": "systemUsageSharedMemory", "kind": "number"},
      {"field": "Dashboard.Performance.GlobalRefsPerSecond", "labelKey": "systemUsageGlobalRefsPerSecond", "kind": "number"},
      {"field": "Dashboard.Performance.CacheEfficiency", "labelKey": "systemUsageCacheEfficiency", "kind": "number"},
      {"field": "Dashboard.SystemUsage.DatabaseSpace", "labelKey": "systemUsageDatabaseSpace", "kind": "text"},
      {"field": "Dashboard.SystemUsage.JournalSpace", "labelKey": "systemUsageJournalSpace", "kind": "text"},
      {"field": "Dashboard.SystemUsage.LockTable", "labelKey": "systemUsageLockTable", "kind": "text"},
      {"field": "Dashboard.SystemUsage.WriteDaemon", "labelKey": "systemUsageWriteDaemon", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "osmgmt.systemusage"
}
}

}
