/// <p>The system audit events list: every event IRIS itself defines on this instance, read through the vendor's own
/// <code>Security.Audit.Event</code> LIST with <code>eventOwner</code> fixed to <code>1</code>
/// (AD-2, AD-36), and rendered by the <code>list</code> archetype's page from the declared
/// <code>table</code> (AD-5). <class>OcuPilot.Screen.Descriptor.AuditingConfig</class>'s page embeds
/// the same read beneath its form.</p>
/// <p><b>The five read fields are the live LIST row's whole key set</b>: <code>EventName</code>
/// (<code>Source/Type/Name</code>, the row's key), <code>Enabled</code> (a boolean), and the
/// <code>Total</code>, <code>Written</code> and <code>Lost</code> counters.</p>
/// <p><b>The privilege set is the Auditing configuration's own</b>, <code>%Admin_Secure:USE</code>
/// (the endpoint's <code>ResourcesOR()</code>) and <code>%DB_IRISSYS:READ</code> (AD-8).</p>
/// <p><b>Its row actions are Enable, Disable and Reset counters</b> (Story 7.11, AD-53), carried
/// out by <class>OcuPilot.Screen.Tool.AuditEventUpdate</class> and
/// <class>OcuPilot.Screen.Tool.AuditEventReset</class>, so its empty state invites the agent. It
/// declares no delete: the vendor refuses a system-defined event 409. It does not refresh (AD-43).
/// As a list archetype it links out to nothing (AD-44).</p>
Class OcuPilot.Screen.Descriptor.AuditSystemEventList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/auditing/system-events",
  "area": "security",
  "labelKey": "auditSystemEventListLabel",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "audit-event",
  "entityLabelKey": "auditDialogTitle",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["EventName"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "enable", "selfProtection": ""}, {"id": "disable", "selfProtection": ""}, {"id": "reset", "selfProtection": ""}],
  "context": {"fields": ["EventName", "Enabled", "Total", "Written", "Lost"], "secretFields": []},
  "emptyStateKey": "auditSystemEventListEmpty",
  "commandAliases": [],
  "classicPage": "%CSP.UI.Portal.Audit.SystemEvents",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Security.Audit.Event", "type": "LIST", "query": {"eventOwner": "1"}},
    "fields": ["EventName", "Enabled", "Total", "Written", "Lost"],
    "filter": ["EventName", "Enabled", "Total", "Written", "Lost"],
    "sort": {"fields": ["EventName", "Enabled", "Total", "Written", "Lost"], "default": "EventName", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "EventName", "labelKey": "auditColumnEventName", "kind": "name"},
      {"field": "Enabled", "labelKey": "tableColumnEnabled", "kind": "status"},
      {"field": "Total", "labelKey": "auditEventColumnTotal", "kind": "number"},
      {"field": "Written", "labelKey": "auditEventColumnWritten", "kind": "number"},
      {"field": "Lost", "labelKey": "auditEventColumnLost", "kind": "number"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "auditSystemEventListEmptyAgent"
  },
  "toolIdentifier": "security.auditsystemevents"
}
}

}
