/// <p>System resource statistics: one row per system resource, read as the rows of
/// <code>AdminPort</code>'s composed <code>RESOURCEROWS</code> type over the vendor's
/// <code>DASHBOARDRESOURCES</code> array (<code>source.rows</code>, AD-36), most seized first. An unlisted
/// drill-down of the Dashboard's Performance group (Story 18.36).</p>
/// <p>It administers nothing: <code>entityType</code> is <code>""</code>, its <code>id</code> is
/// <code>none</code>, it declares no action, it does not refresh (AD-43) and it takes no criterion.</p>
/// <p>Its pairs are the Dashboard's, <code>%Admin_Operate:USE</code> and <code>%DB_IRISSYS:READ</code>
/// (AD-8, AD-29), which OS management's set covers. Its classic page is
/// <code>%cspapp.op.utilsysstatisticsresource</code> (AD-44); it links out to nothing.</p>
Class OcuPilot.Screen.Descriptor.DashboardResources Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/resource-statistics",
  "area": "os-management",
  "labelKey": "resourceStatisticsLabel",
  "sideBarPosition": 0,
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
  "context": {
    "fields": ["Name", "Seize", "Nseize", "Aseize", "Bseize", "BusySet"],
    "secretFields": []
  },
  "emptyStateKey": "resourceStatisticsEmpty",
  "commandAliases": [],
  "suggestedPrompts": [{"groupKey": "promptGroupTroubleshooting", "textKey": "resourceStatisticsPrompt1"}, {"groupKey": "promptGroupTroubleshooting", "textKey": "resourceStatisticsPrompt2"}, {"groupKey": "promptGroupCapacity", "textKey": "resourceStatisticsPrompt3"}],
  "classicPage": "%cspapp.op.utilsysstatisticsresource",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Monitor", "type": "RESOURCEROWS", "rows": "Resources"},
    "fields": ["Name", "Seize", "Nseize", "Aseize", "Bseize", "BusySet"],
    "filter": ["Name"],
    "sort": {
      "fields": ["Name", "Seize", "Nseize", "Aseize", "Bseize", "BusySet"],
      "default": "Seize",
      "direction": "desc"
    },
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Seize", "labelKey": "resourceColumnSeizes", "kind": "number"},
      {"field": "Nseize", "labelKey": "resourceColumnNseizes", "kind": "number"},
      {"field": "Aseize", "labelKey": "resourceColumnAseizes", "kind": "number"},
      {"field": "Bseize", "labelKey": "resourceColumnBseizes", "kind": "number"},
      {"field": "BusySet", "labelKey": "resourceColumnBusySets", "kind": "number"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "osmgmt.resourcestatistics"
}
}

}
