/// <p>Interoperability's Productions: the productions the route's namespace configures, with their
/// state, read through <class>OcuPilot.Port.InteropPort</class> (source kind <code>interop</code>,
/// endpoint <code>Productions</code>) and rendered by the <code>list</code> archetype's page from the
/// declared <code>table</code> (AD-5, AD-29, AD-36, AD-62, Story 20.2). It is the area's first side-bar
/// entry and lives in <code>interoperability</code>, so it is offered only in a namespace that runs
/// interoperability (AD-44).</p>
/// <p><b>Its id is the production's class name</b>, kept exactly (AD-13), and its scope is
/// <code>namespace</code>. Its row actions Start, Stop, Restart, Update and Recover are the screen's
/// callers of <class>OcuPilot.Screen.Tool.InteropProductionStart</class> and its four siblings
/// (AD-53): Start is sent at once, and each of the others states what it does and waits in a warning
/// dialog first. An action that does not fit the row's state is refused by its own named code before
/// any vendor call.</p>
/// <p><b>Its pairs</b> are the classic menu's <code>%Ens_Portal:USE</code> and, as its own,
/// <code>EnsPortal.Productions</code>'s <code>%Ens_ProductionConfig:READ</code>; the five tools add
/// <code>%Ens_ProductionRun:USE</code> and WRITE on the namespace's globals database, which the port
/// checks before any vendor call (AD-8, AD-62). It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.InteropProductionList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/productions",
  "area": "interoperability",
  "labelKey": "interopProductionsLabel",
  "sideBarPosition": 1,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_ProductionConfig", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_ProductionConfig", "permission": "READ"}],
  "entityType": "production",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "start", "selfProtection": ""}, {"id": "stop", "selfProtection": ""}, {"id": "restart", "selfProtection": ""}, {"id": "update", "selfProtection": ""}, {"id": "recover", "selfProtection": ""}],
  "context": {"fields": ["Name", "Status", "LastStartTime", "LastStopTime"], "secretFields": []},
  "emptyStateKey": "interopProductionsEmpty",
  "commandAliases": ["productions", "production control", "start production", "stop production"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopProductionsPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopProductionsPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopProductionsPrompt3"}
  ],
  "classicPage": "EnsPortal.Productions",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "interop", "endpoint": "Productions", "type": "LIST"},
    "fields": ["Name", "Status", "LastStartTime", "LastStopTime"],
    "filter": ["Name", "Status"],
    "sort": {"fields": ["Name", "Status", "LastStartTime", "LastStopTime"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Status", "labelKey": "taskHistoryColumnStatus", "kind": "status"},
      {"field": "LastStartTime", "labelKey": "interopProductionColumnLastStarted", "kind": "text"},
      {"field": "LastStopTime", "labelKey": "interopProductionColumnLastStopped", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "interopProductionsEmptyAgent"
  },
  "toolIdentifier": "interop.productions"
}
}

}
