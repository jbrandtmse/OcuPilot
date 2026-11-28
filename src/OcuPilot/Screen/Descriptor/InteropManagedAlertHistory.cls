/// <p>Interoperability's Alert history: what has been done to one managed alert, newest first, as the classic Managed Alert Viewer's alert page lists it, each row the time, the user, the action in the
/// vendor's own words, the reason and the old and new values, read through <class>OcuPilot.Port.InteropPort</class> (source kind <code>interop</code>, endpoint <code>ManagedAlertActions</code>) and
/// rendered by the <code>list</code> archetype's page (AD-5, AD-29, AD-36, AD-62, Story 24.17 Batch 1). The action and the values are the vendor's text, shown and never run (AD-11).</p>
/// <p><b>It is a sub-resource of the Managed alerts list and never listed</b> (<code>sideBarPosition</code> 0): it declares <code>parentScope</code> <code>interoperability/managed-alerts</code>, and its
/// one criterion, <code>alert</code>, is the route id, required as a single-object read's is (AD-36). It is read-only.</p>
Class OcuPilot.Screen.Descriptor.InteropManagedAlertHistory Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/managed-alerts/history",
  "area": "interoperability",
  "labelKey": "interopManagedAlertHistoryLabel",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_Alerts", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_Alerts", "permission": "READ"}],
  "entityType": "",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "interoperability/managed-alerts",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["ActionTime", "Username", "Action", "Reason", "OldValues", "NewValues"], "secretFields": []},
  "emptyStateKey": "interopManagedAlertHistoryEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopManagedAlertHistoryPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopManagedAlertsPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopManagedAlertsPrompt4"}
  ],
  "classicPage": "EnsPortal.ManagedAlertViewer",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "managed alert action",
    "source": {"port": "interop", "endpoint": "ManagedAlertActions", "type": "LIST"},
    "fields": ["ActionTime", "Username", "Action", "Reason", "OldValues", "NewValues"],
    "filter": ["Username", "Action", "Reason"],
    "sort": {"fields": ["ActionTime", "Username", "Action"], "default": "ActionTime", "direction": "desc"},
    "paging": "cap",
    "criteria": {
      "fields": [{"param": "alert", "labelKey": "interopColumnId", "kind": "text", "maxLength": 18, "hint": "One managed alert's ID, spelled as interop.managedalerts.read answers its ID."}]
    }
  },
  "table": {
    "columns": [
      {"field": "ActionTime", "labelKey": "auditColumnTime", "kind": "name"},
      {"field": "Username", "labelKey": "processColumnUser", "kind": "text"},
      {"field": "Action", "labelKey": "sqlPrivilegeColumnAction", "kind": "text"},
      {"field": "Reason", "labelKey": "agentSwitchesFieldReason", "kind": "text"},
      {"field": "OldValues", "labelKey": "interopAlertColumnOldValues", "kind": "text"},
      {"field": "NewValues", "labelKey": "interopAlertColumnNewValues", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "interop.managedalerthistory"
}
}

}
