/// <p>The unified log hub (Story 16.9, FR-77): every Logs source with its entry count and its last
/// entry, beside a timeline merging every readable source's entries newest first over a window
/// that opens on the last hour.</p>
/// <p><b>Its read is composed</b> (AD-36 as amended): <code>port: "timeline"</code> runs each other
/// listed Logs screen's own gate and read, in side-bar order, through
/// <class>OcuPilot.Screen.Timeline</class>, and answers <code>sources</code> beside the rows. The
/// members are the registry's, never a caller's (AD-21); <code>since</code> is the only criterion.</p>
/// <p><b>Its gate is the messages.log viewer's one pair</b>, inside the Logs area's set, and it
/// declares no <code>ownPrivileges</code>: a member the caller may not read is left out and named
/// with its pair, so the Logs area never needs <code>%Ens_EventLog:USE</code> or
/// <code>%DeepSee_Portal:USE</code> (AD-8 as amended for DW-1755).</p>
/// <p>Its page is its own (<code>DESCRIPTOR_PAGES</code>): the Sources list and the Timeline are two
/// sections over this one read. Its id is <code>none</code>, it has no action, no classic page
/// and it never refreshes on its own (AD-13, AD-43, AD-44).</p>
Class OcuPilot.Screen.Descriptor.LogHub Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "logs/hub",
  "area": "logs",
  "labelKey": "logHubLabel",
  "sideBarPosition": 11,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}],
  "entityType": "log-entry",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["time", "source", "severity", "text"], "secretFields": []},
  "emptyStateKey": "logViewerEmpty",
  "commandAliases": ["log hub", "timeline", "all logs"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "logHubPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "logHubPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "logHubPrompt3"}
  ],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "timeline", "endpoint": "logs", "type": "LIST"},
    "fields": ["time", "source", "severity", "text", "id"],
    "filter": ["time", "source", "severity", "text"],
    "sort": {"fields": ["time"], "default": "time", "direction": "desc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "since", "labelKey": "auditCriteriaBegin", "kind": "datetime", "maxLength": 50, "defaultHoursAgo": 1}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "time", "labelKey": "auditColumnTime", "kind": "name"},
      {"field": "source", "labelKey": "auditEventFieldSource", "kind": "text"},
      {"field": "severity", "labelKey": "logViewerColumnSeverity", "kind": "status"},
      {"field": "text", "labelKey": "logViewerColumnMessage", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "logs.hub"
}
}

}
