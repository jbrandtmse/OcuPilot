/// <p>Interoperability's Queues: the namespace's interoperability queues with the messages waiting in each and the
/// jobs working on one, read through <class>OcuPilot.Port.InteropPort</class> (source kind <code>interop</code>,
/// endpoint <code>Queues</code>) and rendered by the <code>list</code> archetype's page (AD-5, AD-29, AD-36, AD-62,
/// Story 20.4). A queue's name cell opens its Queue messages. It refreshes at the shared rates, default off (AD-43),
/// and offers no action: aborting a message or a queue is a later story's.</p>
Class OcuPilot.Screen.Descriptor.InteropQueueList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/queues",
  "area": "interoperability",
  "labelKey": "interopQueuesLabel",
  "sideBarPosition": 6,
  "archetype": "list",
  "built": true,
  "refreshes": true,
  "refreshRates": [5, 10, 30, 60],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_Queues", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_Queues", "permission": "READ"}],
  "entityType": "interop-queue",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Name", "Count", "Active"], "secretFields": []},
  "emptyStateKey": "interopQueuesEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopQueuesPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopQueuesPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopQueuesPrompt3"}
  ],
  "classicPage": "EnsPortal.Queues",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "interop", "endpoint": "Queues", "type": "LIST"},
    "fields": ["Name", "Count", "Active", "Created"],
    "filter": ["Name"],
    "sort": {"fields": ["Name", "Count", "Active", "Created"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Count", "labelKey": "interopColumnCount", "kind": "number"},
      {"field": "Active", "labelKey": "interopColumnActive", "kind": "number"},
      {"field": "Created", "labelKey": "journalColumnCreated", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "interop.queues"
}
}

}
