/// <p>Mirror monitor: the members of the instance's mirror, each with its role, its status and its journal transfer and dejournal
/// latencies, read through <class>OcuPilot.Port.MirrorPort</class> (source kind <code>mirror</code>, endpoint <code>Members</code>) and
/// rendered by the <code>list</code> archetype's page from the declared <code>table</code> (AD-5, AD-29, AD-36, Story 21.12). It is OS
/// management's thirty-third side-bar entry and it is read-only.</p>
/// <p><b>Its pairs</b> are the classic System Operation menu's: <code>%Admin_Operate:USE</code> and <code>%DB_IRISSYS:READ</code>, the
/// area's, and, as its own, <code>%DB_IRISSYS:WRITE</code>, which the classic menu also needs to show the page (AD-8, AD-44).</p>
/// <p><b>An instance that is not a mirror member</b> has no rows, and its banner says so, adding that the license does not allow
/// mirroring when it does not. It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.MirrorMonitor Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/mirror-monitor",
  "area": "os-management",
  "labelKey": "mirrorMonitorLabel",
  "sideBarPosition": 33,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}, {"resource": "%DB_IRISSYS", "permission": "WRITE"}],
  "ownPrivileges": [{"resource": "%DB_IRISSYS", "permission": "WRITE"}],
  "entityType": "",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["MemberName", "CurrentRole", "CurrentStatus", "JournalLatency", "DatabaseLatency"], "secretFields": []},
  "emptyStateKey": "mirrorMonitorEmpty",
  "commandAliases": ["mirror monitor", "mirroring", "mirror status"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "mirrorMonitorPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "mirrorMonitorPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "mirrorMonitorPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.Mirror.Monitor",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "mirror member",
    "source": {"port": "mirror", "endpoint": "Members", "type": "LIST"},
    "fields": ["MemberName", "CurrentRole", "CurrentStatus", "JournalLatency", "DatabaseLatency"],
    "filter": ["MemberName", "CurrentRole", "CurrentStatus"],
    "sort": {"fields": ["MemberName", "CurrentRole", "CurrentStatus"], "default": "MemberName", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "MemberName", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "CurrentRole", "labelKey": "userRoleField", "kind": "text"},
      {"field": "CurrentStatus", "labelKey": "taskHistoryColumnStatus", "kind": "status"},
      {"field": "JournalLatency", "labelKey": "mirrorColumnJournalLatency", "kind": "text"},
      {"field": "DatabaseLatency", "labelKey": "mirrorColumnDatabaseLatency", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "banner": {
    "source": {"port": "mirror", "endpoint": "State", "type": "GET"},
    "field": "State",
    "cases": [
      {"equals": "NotMember", "messageKey": "mirrorNotMemberBanner", "severity": "info"},
      {"equals": "Unlicensed", "messageKey": "mirrorUnlicensedBanner", "severity": "info"}
    ]
  },
  "toolIdentifier": "osmgmt.mirrormonitor"
}
}

}
