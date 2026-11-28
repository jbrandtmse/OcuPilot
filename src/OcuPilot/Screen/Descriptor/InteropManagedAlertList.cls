/// <p>Interoperability's Managed alerts: the namespace's managed alerts, newest first, as the classic Alerts page and Managed Alert Viewer list them, read through
/// <class>OcuPilot.Port.InteropPort</class> (source kind <code>interop</code>, endpoint <code>ManagedAlerts</code>) and rendered from the declared <code>table</code> (AD-5, AD-29, AD-36, AD-62,
/// Story 24.17 Batch 1). Its one criterion, <code>open</code>, lists the open alerts or the closed ones; a longer list than the cap is reported as truncation, never dropped silently (AD-36).</p>
/// <p><b>Its row action</b> Update is the screen's caller of <class>OcuPilot.Screen.Tool.InteropManagedAlertUpdate</class> (AD-53, AD-55): a dialog shows the alert's owner, state and level and
/// takes a new owner, open state, escalation level or next action time with the reason, and saves each change in the alert's history. The agent's tool is the same operation. A row's name cell opens the
/// alert's history, the child list whose <code>parentScope</code> is this route (AD-5).</p>
/// <p><b>Its pairs</b> are the classic pages': <code>%Ens_Portal:USE</code> and, as its own, <code>%Ens_Alerts:READ</code>; the tool adds WRITE on the Alerts page's resource and on the namespace's
/// globals database (AD-8, AD-62). It shows every owner's alerts to a reader, as the Managed Alert Viewer it replaces does. Its scope is <code>namespace</code>. It does not refresh (AD-43).</p>
/// <p>The classic Alerts page is the tool's <code>CLASSICPAGES</code>, whose Update the screen performs, so neither page's custom resource is lost (AD-44).</p>
Class OcuPilot.Screen.Descriptor.InteropManagedAlertList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/managed-alerts",
  "area": "interoperability",
  "labelKey": "interopManagedAlertsLabel",
  "sideBarPosition": 22,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_Alerts", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_Alerts", "permission": "READ"}],
  "entityType": "interop-managed-alert",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "update", "selfProtection": ""}],
  "context": {"fields": ["ID", "AlertTime", "AlertText", "SourceConfigName", "Production", "CurrentOwner", "EscalationLevel", "IsOpen", "NextActionTime"], "secretFields": []},
  "emptyStateKey": "interopManagedAlertsEmpty",
  "commandAliases": ["managed alerts", "alerts"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopManagedAlertsPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopManagedAlertsPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopManagedAlertsPrompt3"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopManagedAlertsPrompt4"}
  ],
  "classicPage": "EnsPortal.ManagedAlertViewer",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "managed alert",
    "source": {"port": "interop", "endpoint": "ManagedAlerts", "type": "LIST"},
    "fields": ["ID", "AlertTime", "AlertText", "SourceConfigName", "Production", "SessionId", "CurrentOwner", "EscalationLevel", "IsOpen", "LastActionTime", "NextActionTime"],
    "filter": ["AlertText", "SourceConfigName", "Production", "CurrentOwner"],
    "sort": {"fields": ["ID", "AlertTime", "SourceConfigName", "Production", "CurrentOwner", "EscalationLevel", "IsOpen", "LastActionTime", "NextActionTime"], "default": "AlertTime", "direction": "desc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "open", "labelKey": "interopAlertColumnOpen", "kind": "choice", "maxLength": 3, "options": ["yes", "no"]}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "ID", "labelKey": "interopColumnId", "kind": "name"},
      {"field": "AlertTime", "labelKey": "interopAlertColumnTime", "kind": "text"},
      {"field": "AlertText", "labelKey": "interopAlertColumnText", "kind": "text"},
      {"field": "SourceConfigName", "labelKey": "auditEventFieldSource", "kind": "text"},
      {"field": "Production", "labelKey": "systemInfoProduction", "kind": "text"},
      {"field": "SessionId", "labelKey": "webSessionColumnSession", "kind": "identifier"},
      {"field": "CurrentOwner", "labelKey": "interopAlertColumnOwner", "kind": "text"},
      {"field": "EscalationLevel", "labelKey": "interopAlertColumnLevel", "kind": "number"},
      {"field": "IsOpen", "labelKey": "interopAlertColumnOpen", "kind": "status"},
      {"field": "LastActionTime", "labelKey": "interopAlertColumnLastAction", "kind": "text"},
      {"field": "NextActionTime", "labelKey": "interopAlertColumnNextAction", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "interopManagedAlertsEmptyAgent"
  },
  "toolIdentifier": "interop.managedalerts"
}
}

}
