/// <p>Global and routine statistics: the instance's cumulative global and routine counters, read as
/// one row of twelve global and six routine fields from the vendor's <code>Monitor</code>
/// <code>DASHBOARDGLOBALS</code> answer, as <code>Statistics</code> (<code>source.parts</code>, AD-36).
/// An unlisted drill-down of the Dashboard's Performance group (Story 18.36), reached from its link and
/// never from the side bar.</p>
/// <p>It administers nothing: <code>entityType</code> is <code>""</code>, its <code>id</code> is
/// <code>none</code>, it declares no action, it does not refresh (AD-43) and it takes no criterion.</p>
/// <p>Its pairs are the Dashboard's, <code>%Admin_Operate:USE</code> and <code>%DB_IRISSYS:READ</code>
/// (AD-8, AD-29), which OS management's set covers. Its classic page is
/// <code>%cspapp.op.utilsysstatisticsglobal</code> (AD-44); it links out to nothing.</p>
Class OcuPilot.Screen.Descriptor.DashboardGlobals Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/global-statistics",
  "area": "os-management",
  "labelKey": "globalStatisticsLabel",
  "sideBarPosition": 0,
  "archetype": "detail",
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
  "context": {
    "fields": ["Statistics.Globals.RefLocal", "Statistics.Globals.RefUpdateLocal", "Statistics.Globals.RefRemote", "Statistics.Globals.RefUpdateRemote", "Statistics.Globals.RefPrivate", "Statistics.Globals.RefUpdatePrivate", "Statistics.Globals.LogicalBlocks", "Statistics.Globals.PhysBlockReads", "Statistics.Globals.PhysBlockWrites", "Statistics.Globals.WIJWrites", "Statistics.Globals.JrnEntries", "Statistics.Globals.JrnBlocks", "Statistics.Routines.RtnCallsLocal", "Statistics.Routines.RtnFetchLocal", "Statistics.Routines.RtnCallsRemote", "Statistics.Routines.RtnFetchRemote", "Statistics.Routines.RtnCommands", "Statistics.Routines.RtnNotCached"],
    "secretFields": []
  },
  "emptyStateKey": "statisticsEmpty",
  "commandAliases": [],
  "suggestedPrompts": [{"groupKey": "promptGroupTroubleshooting", "textKey": "globalStatisticsPrompt1"}, {"groupKey": "promptGroupTroubleshooting", "textKey": "globalStatisticsPrompt2"}, {"groupKey": "promptGroupCapacity", "textKey": "globalStatisticsPrompt3"}],
  "classicPage": "%cspapp.op.utilsysstatisticsglobal",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Monitor", "type": "GET", "parts": [{"type": "DASHBOARDGLOBALS", "as": "Statistics"}]},
    "fields": ["Statistics.Globals.RefLocal", "Statistics.Globals.RefUpdateLocal", "Statistics.Globals.RefRemote", "Statistics.Globals.RefUpdateRemote", "Statistics.Globals.RefPrivate", "Statistics.Globals.RefUpdatePrivate", "Statistics.Globals.LogicalBlocks", "Statistics.Globals.PhysBlockReads", "Statistics.Globals.PhysBlockWrites", "Statistics.Globals.WIJWrites", "Statistics.Globals.JrnEntries", "Statistics.Globals.JrnBlocks", "Statistics.Routines.RtnCallsLocal", "Statistics.Routines.RtnFetchLocal", "Statistics.Routines.RtnCallsRemote", "Statistics.Routines.RtnFetchRemote", "Statistics.Routines.RtnCommands", "Statistics.Routines.RtnNotCached"],
    "filter": ["Statistics.Globals.RefLocal", "Statistics.Globals.RefUpdateLocal", "Statistics.Globals.RefRemote", "Statistics.Globals.RefUpdateRemote", "Statistics.Globals.RefPrivate", "Statistics.Globals.RefUpdatePrivate", "Statistics.Globals.LogicalBlocks", "Statistics.Globals.PhysBlockReads", "Statistics.Globals.PhysBlockWrites", "Statistics.Globals.WIJWrites", "Statistics.Globals.JrnEntries", "Statistics.Globals.JrnBlocks", "Statistics.Routines.RtnCallsLocal", "Statistics.Routines.RtnFetchLocal", "Statistics.Routines.RtnCallsRemote", "Statistics.Routines.RtnFetchRemote", "Statistics.Routines.RtnCommands", "Statistics.Routines.RtnNotCached"],
    "sort": {
      "fields": ["Statistics.Globals.RefLocal", "Statistics.Globals.RefUpdateLocal", "Statistics.Globals.RefRemote", "Statistics.Globals.RefUpdateRemote", "Statistics.Globals.RefPrivate", "Statistics.Globals.RefUpdatePrivate", "Statistics.Globals.LogicalBlocks", "Statistics.Globals.PhysBlockReads", "Statistics.Globals.PhysBlockWrites", "Statistics.Globals.WIJWrites", "Statistics.Globals.JrnEntries", "Statistics.Globals.JrnBlocks", "Statistics.Routines.RtnCallsLocal", "Statistics.Routines.RtnFetchLocal", "Statistics.Routines.RtnCallsRemote", "Statistics.Routines.RtnFetchRemote", "Statistics.Routines.RtnCommands", "Statistics.Routines.RtnNotCached"],
      "default": "Statistics.Globals.RefLocal",
      "direction": "asc"
    },
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Statistics.Globals.RefLocal", "labelKey": "statsGlobalReferencesLocal", "kind": "name"},
      {"field": "Statistics.Globals.RefUpdateLocal", "labelKey": "statsGlobalUpdatesLocal", "kind": "number"},
      {"field": "Statistics.Globals.RefRemote", "labelKey": "statsGlobalReferencesRemote", "kind": "number"},
      {"field": "Statistics.Globals.RefUpdateRemote", "labelKey": "statsGlobalUpdatesRemote", "kind": "number"},
      {"field": "Statistics.Globals.RefPrivate", "labelKey": "processDetailsPrivateGlobalReferences", "kind": "number"},
      {"field": "Statistics.Globals.RefUpdatePrivate", "labelKey": "statsGlobalUpdatesPrivate", "kind": "number"},
      {"field": "Statistics.Globals.LogicalBlocks", "labelKey": "systemUsageLogicalBlockRequests", "kind": "number"},
      {"field": "Statistics.Globals.PhysBlockReads", "labelKey": "systemUsageBlockReads", "kind": "number"},
      {"field": "Statistics.Globals.PhysBlockWrites", "labelKey": "systemUsageBlockWrites", "kind": "number"},
      {"field": "Statistics.Globals.WIJWrites", "labelKey": "statsWriteImageJournalWrites", "kind": "number"},
      {"field": "Statistics.Globals.JrnEntries", "labelKey": "systemUsageJournalEntries", "kind": "number"},
      {"field": "Statistics.Globals.JrnBlocks", "labelKey": "systemUsageJournalBlockWrites", "kind": "number"},
      {"field": "Statistics.Routines.RtnCallsLocal", "labelKey": "statsRoutineCallsLocal", "kind": "number"},
      {"field": "Statistics.Routines.RtnFetchLocal", "labelKey": "statsRoutineLoadsLocal", "kind": "number"},
      {"field": "Statistics.Routines.RtnCallsRemote", "labelKey": "statsRoutineCallsRemote", "kind": "number"},
      {"field": "Statistics.Routines.RtnFetchRemote", "labelKey": "statsRoutineLoadsRemote", "kind": "number"},
      {"field": "Statistics.Routines.RtnCommands", "labelKey": "statsRoutineCommands", "kind": "number"},
      {"field": "Statistics.Routines.RtnNotCached", "labelKey": "statsRoutinesNotCached", "kind": "number"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "osmgmt.globalstatistics"
}
}

}
