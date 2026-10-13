/// <p>Interoperability usage's first tab, Interfaces: the instance's interoperability interfaces, one
/// row per type, namespace and protocol the classic page counts, plus the totals rows, read through
/// <class>OcuPilot.Port.MonitorPort</class> (<code>Interfaces</code>, AD-29, AD-36) and rendered by
/// the <code>detail</code> page over the declared <code>table</code> (AD-5).</p>
/// <p><b>It is the tab group's first member and its side-bar entry</b>, at position 22 of OS
/// management; Message volume and Database impact are unlisted routes under it, one descriptor each,
/// over the monitor port's other two usage endpoints.</p>
/// <p><b>It administers nothing</b>: <code>entityType</code> is <code>""</code> and its <code>id</code>
/// is <code>none</code>, so it carries no change-event key and no row identity (AD-13, AD-14). It
/// declares no action and does not refresh (AD-43). A totals row leaves its namespace and protocol
/// empty, and the table reads those cells as "All".</p>
/// <p><b>The pair set is the port's</b>: <code>%Admin_Operate:USE</code>, the classic page's own
/// requirement, and <code>%DB_IRISSYS:READ</code>, since the port runs the page's queries in
/// <code>%SYS</code> (AD-8, AD-16, AD-29). The OS management area covers both.</p>
/// <p><b>The classic page</b> is <code>%CSP.UI.Portal.InteroperabilityUsage</code> (AD-44), whose
/// three views these three tabs replace; it declares no exemption. The classic page's date range is
/// not carried over: a <code>monitor</code> read takes no criteria, so every count covers all the
/// usage data the instance still keeps, as the note says.</p>
Class OcuPilot.Screen.Descriptor.InteropUsageTab Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/interoperability-usage",
  "area": "os-management",
  "labelKey": "interopUsageLabel",
  "sideBarPosition": 22,
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
  "context": {"fields": ["Type", "Namespace", "Protocol", "Active", "Count"], "secretFields": []},
  "emptyStateKey": "interopUsageInterfacesEmpty",
  "commandAliases": ["interoperability usage", "interop usage"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupCapacity", "textKey": "interopUsagePrompt1"},
    {"groupKey": "promptGroupCapacity", "textKey": "interopUsagePrompt2"},
    {"groupKey": "promptGroupCapacity", "textKey": "interopUsagePrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.InteroperabilityUsage",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "monitor", "endpoint": "Interfaces", "type": "LIST"},
    "fields": ["Type", "Namespace", "Protocol", "Active", "Count"],
    "filter": ["Type", "Namespace", "Protocol"],
    "sort": {"fields": ["Type", "Namespace", "Protocol", "Active", "Count"], "default": "Type", "direction": "asc"},
    "paging": "cap",
    "note": {"key": "interopUsageNote", "text": "Counts cover all the usage data the instance still keeps, with no date range."}
  },
  "table": {
    "columns": [
      {"field": "Type", "labelKey": "tableColumnType", "kind": "name"},
      {"field": "Namespace", "labelKey": "headerNamespaceLabel", "kind": "identifier", "emptyKey": "interopUsageAll"},
      {"field": "Protocol", "labelKey": "interopUsageColumnProtocol", "kind": "text", "emptyKey": "interopUsageAll"},
      {"field": "Active", "labelKey": "interopColumnActive", "kind": "status"},
      {"field": "Count", "labelKey": "interopColumnCount", "kind": "number"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "os-management/interoperability-usage", "position": 1, "labelKey": "interopUsageInterfacesTab"},
  "toolIdentifier": "osmgmt.interopusage"
}
}

}
