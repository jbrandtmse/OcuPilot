/// <p>Interoperability's Archive manager: the last archive run's history of the namespace, the classic Archive Manager page's eight rows (the start and stop time, the four counts, the
/// number of errors and whether a run is running), read through <class>OcuPilot.Port.InteropPort</class> (source kind <code>interop</code>, endpoint <code>Archive</code>) and rendered
/// from the declared <code>table</code> (AD-5, AD-29, AD-36, AD-62, Story 24.16 Batch 4). The rows are always there, so Run archive is reachable before the first run.</p>
/// <p><b>Its row action</b> Run archive is the screen's caller of <class>OcuPilot.Screen.Tool.InteropArchiveRun</class> (AD-53, AD-55): a dialog shows the target, the days, the
/// class and how many messages the run would move, and the confirm types the namespace's name. It runs in the request and is destructive. It archives the namespace whichever row
/// is selected, and names the namespace as its target; the action route admits only a declared row action, so Run archive is one. The agent's tool is the same operation.</p>
/// <p><b>Its pairs</b> are the classic page's: <code>%Ens_Portal:USE</code> and, as its own, <code>%Ens_ArchiveManager:READ</code>; the tool adds WRITE on the page's resource and on the
/// namespace's globals database, and the port WRITE on the target's (AD-8, AD-62). Its scope is <code>namespace</code>. It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.InteropArchiveList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/archive",
  "area": "interoperability",
  "labelKey": "interopArchiveLabel",
  "sideBarPosition": 19,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_ArchiveManager", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_ArchiveManager", "permission": "READ"}],
  "entityType": "interop-archive",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "archive", "selfProtection": ""}],
  "context": {"fields": ["Name", "Value"], "secretFields": []},
  "emptyStateKey": "interopArchiveEmpty",
  "commandAliases": ["archive", "archive old messages", "archive manager"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopArchivePrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopArchivePrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopArchivePrompt3"}
  ],
  "classicPage": "EnsPortal.ArchiveManager",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "archive history line",
    "source": {"port": "interop", "endpoint": "Archive", "type": "LIST"},
    "fields": ["Name", "Value"],
    "filter": ["Name", "Value"],
    "sort": {"fields": ["Name", "Value"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Value", "labelKey": "errorLogColumnValue", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "interopArchiveEmptyAgent"
  },
  "toolIdentifier": "interop.archive"
}
}

}
