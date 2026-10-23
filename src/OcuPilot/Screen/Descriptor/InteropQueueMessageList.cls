/// <p>Interoperability's Queue messages: the entries of one queue, each with its message header's source, target, body
/// class, creation time and status, read through <class>OcuPilot.Port.InteropPort</class> (source kind
/// <code>interop</code>, endpoint <code>QueueItems</code>) and rendered by the <code>list</code> archetype's page (AD-5,
/// AD-29, AD-36, AD-62, Story 20.4). No message body is read.</p>
/// <p><b>It is a sub-resource of the Queues list and never listed</b> (<code>sideBarPosition</code> 0): it declares
/// <code>parentScope</code> <code>interoperability/queues</code>, and its one criterion, <code>queue</code>, is the
/// route id, required as a single-object read's is (AD-36). Its id is the message header's id, and its one row action is
/// <code>abort</code> (Story 20.23): <code>interop.queuemessages.abort</code> aborts one waiting message, destructive, with the
/// message id typed. An item's Queue tab posts its own Abort to this list's route (AD-53). A waiting message's id opens that
/// message's Header tab (<code>rowTarget</code> on <code>MessageId</code>, Story 20.9).</p>
Class OcuPilot.Screen.Descriptor.InteropQueueMessageList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/queues/messages",
  "area": "interoperability",
  "labelKey": "interopQueueMessagesLabel",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_Queues", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_Queues", "permission": "READ"}],
  "entityType": "interop-message",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "interoperability/queues",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "abort", "selfProtection": ""}],
  "context": {"fields": ["MessageId", "Source", "Target", "BodyClass", "TimeCreated", "Status"], "secretFields": []},
  "emptyStateKey": "interopQueueMessagesEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopQueueMessagesPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopQueueMessagesPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopQueueMessagesPrompt3"}
  ],
  "classicPage": "EnsPortal.Queues",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "message in one queue",
    "source": {"port": "interop", "endpoint": "QueueItems", "type": "LIST"},
    "fields": ["Queue", "Priority", "Index", "MessageId", "Source", "Target", "BodyClass", "TimeCreated", "Status"],
    "filter": ["MessageId", "Source", "Target", "BodyClass", "Status"],
    "sort": {"fields": ["Priority", "Index", "MessageId", "Source", "Target", "TimeCreated", "Status"], "default": "Index", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [{"param": "queue", "labelKey": "interopColumnQueue", "kind": "text", "maxLength": 256, "hint": "One queue, spelled as interop.queues.read answers its Name."}]
    }
  },
  "table": {
    "columns": [
      {"field": "MessageId", "labelKey": "interopColumnMessageId", "kind": "name"},
      {"field": "Priority", "labelKey": "taskDetailsPriority", "kind": "number"},
      {"field": "Index", "labelKey": "explorerSqlColumnIndex", "kind": "number"},
      {"field": "Source", "labelKey": "auditEventFieldSource", "kind": "text"},
      {"field": "Target", "labelKey": "agentLedgerColumnTarget", "kind": "text"},
      {"field": "BodyClass", "labelKey": "interopColumnBodyClass", "kind": "identifier"},
      {"field": "TimeCreated", "labelKey": "journalColumnCreated", "kind": "text"},
      {"field": "Status", "labelKey": "taskHistoryColumnStatus", "kind": "status"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "interopQueueMessagesEmptyAgent"
  },
  "rowTarget": {"route": "interoperability/messages/document", "field": "MessageId"},
  "toolIdentifier": "interop.queuemessages"
}
}

}
