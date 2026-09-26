/// <p>The user audit events list: every event an application has registered on this instance, read through the vendor's own
/// <code>Security.Audit.Event</code> LIST with <code>eventOwner</code> fixed to <code>0</code>
/// (AD-2, AD-36), and rendered by the <code>list</code> archetype's page from the declared
/// <code>table</code> (AD-5). <class>OcuPilot.Screen.Descriptor.AuditingConfig</class>'s page embeds
/// the same read beneath its form.</p>
/// <p><b>The five read fields are the live LIST row's whole key set</b>: <code>EventName</code>
/// (<code>Source/Type/Name</code>, the row's key), <code>Enabled</code> (a boolean), and the
/// <code>Total</code>, <code>Written</code> and <code>Lost</code> counters.</p>
/// <p><b>The privilege set is the Auditing configuration's own</b>, <code>%Admin_Secure:USE</code>
/// (the endpoint's <code>ResourcesOR()</code>) and <code>%DB_IRISSYS:READ</code> (AD-8).</p>
/// <p><b>Its row actions are Enable, Disable, Reset counters and Delete</b> (Story 7.11, AD-53),
/// carried out by <class>OcuPilot.Screen.Tool.AuditUserEventUpdate</class>,
/// <class>OcuPilot.Screen.Tool.AuditUserEventReset</class> and
/// <class>OcuPilot.Screen.Tool.AuditUserEventDelete</class>, so its empty state invites the agent.
/// <b>Its Create and its name cell open the user audit event editor</b> (Story 9.10), a dialog over
/// this list that registers an event through <class>OcuPilot.Screen.Tool.AuditUserEventCreate</class>
/// and edits one's Description through the update tool (AD-55); it declares three suggested prompts
/// (Story 11.3). Its entity type is <code>audit-user-event</code>, so a change to one of its rows routes here
/// rather than to the system list (DW-1529). It does not refresh (AD-43). As a list archetype it
/// links out to nothing (AD-44).</p>
Class OcuPilot.Screen.Descriptor.AuditUserEventList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/auditing/user-events",
  "area": "security",
  "labelKey": "auditUserEventListLabel",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "audit-user-event",
  "entityLabelKey": "auditDialogTitle",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["EventName"]},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [{"id": "enable", "selfProtection": ""}, {"id": "disable", "selfProtection": ""}, {"id": "reset", "selfProtection": ""}, {"id": "delete", "selfProtection": ""}],
  "context": {"fields": ["EventName", "Enabled", "Total", "Written", "Lost"], "secretFields": []},
  "emptyStateKey": "auditUserEventListEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "auditUserEventPromptGroup", "textKey": "auditUserEventPromptEnabled"},
    {"groupKey": "auditUserEventPromptGroup", "textKey": "auditUserEventPromptBusiest"},
    {"groupKey": "auditUserEventPromptGroup", "textKey": "auditUserEventPromptRegister"}
  ],
  "classicPage": "%CSP.UI.Portal.Audit.UserEvents",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Security.Audit.Event", "type": "LIST", "query": {"eventOwner": "0"}},
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
    "emptyAgentKey": "auditUserEventListEmptyAgent"
  },
  "toolIdentifier": "security.audituserevents"
}
}

}
