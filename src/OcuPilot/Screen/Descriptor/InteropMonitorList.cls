/// <p>Interoperability's Production monitor: the items the namespace's running production configures, with the status,
/// adapter state, last activity, queue count and message count the vendor's host monitor keeps, read through
/// <class>OcuPilot.Port.InteropPort</class> (source kind <code>interop</code>, endpoint <code>Monitor</code>) and
/// rendered by the <code>list</code> archetype's page from the declared <code>table</code> (AD-5, AD-29, AD-36, AD-62,
/// Story 20.4). It lists none while no production is running or troubled, and none of the vendor's own hosts.</p>
/// <p><b>Its id is the composite <code>[Production, Name]</code></b> (AD-13), and a row's name cell opens that item's
/// Status tab through <code>rowTarget</code> on <code>Item</code>, the item's <code>Production||Name</code>. It
/// refreshes at the shared rates, default off (AD-43). Its pairs are its classic page's own: <code>%Ens_Dashboard:USE</code>
/// beside the area's <code>%Ens_Portal:USE</code>, which is also what the Monitor role holds (AD-8).</p>
Class OcuPilot.Screen.Descriptor.InteropMonitorList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/monitor",
  "area": "interoperability",
  "labelKey": "interopMonitorLabel",
  "sideBarPosition": 5,
  "archetype": "list",
  "built": true,
  "refreshes": true,
  "refreshRates": [5, 10, 30, 60],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_Dashboard", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%Ens_Dashboard", "permission": "USE"}],
  "entityType": "production-item",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Production", "Name"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Name", "Type", "Status", "AdapterState", "LastActivity", "Queue", "Count"], "secretFields": []},
  "emptyStateKey": "interopMonitorEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopMonitorPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopMonitorPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopMonitorPrompt3"}
  ],
  "classicPage": "EnsPortal.ProductionMonitor",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "interop", "endpoint": "Monitor", "type": "LIST"},
    "fields": ["Production", "Item", "Name", "Type", "Status", "AdapterState", "LastActivity", "ElapsedTime", "Queue", "Count"],
    "filter": ["Name", "Type", "Status"],
    "sort": {"fields": ["Name", "Type", "Status", "LastActivity", "ElapsedTime", "Queue", "Count"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "Status", "labelKey": "taskHistoryColumnStatus", "kind": "status"},
      {"field": "AdapterState", "labelKey": "interopColumnAdapterState", "kind": "text"},
      {"field": "LastActivity", "labelKey": "agentTranscriptsColumnLastActivity", "kind": "text"},
      {"field": "ElapsedTime", "labelKey": "sqlActivityColumnElapsed", "kind": "number"},
      {"field": "Queue", "labelKey": "interopColumnQueue", "kind": "number"},
      {"field": "Count", "labelKey": "interopColumnCount", "kind": "number"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "rowTarget": {"route": "interoperability/productions/items/document", "field": "Item"},
  "toolIdentifier": "interop.monitor"
}
}

}
