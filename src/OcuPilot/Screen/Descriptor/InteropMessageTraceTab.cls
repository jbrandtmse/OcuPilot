/// <p>Interoperability's Trace tab of one message (Story 20.30): the whole session the message belongs to, in <code>ID</code> order,
/// read through <class>OcuPilot.Port.InteropPort</class> (source kind <code>interop</code>, endpoint <code>MessageTrace</code>) and
/// drawn by <code>app-interop-message-trace</code> as a sequence diagram, or as Mermaid text, in place of the table by the detail
/// page's <code>body</code> input (AD-5, AD-29, AD-36, AD-44, AD-62). The vendor's Visual Trace is not embedded (AD-63).</p>
/// <p><b>It is the third tab of the group</b> <code>interoperability/messages/document</code>, parent-scoped under Messages, with the
/// Header tab's one criterion, <code>message</code>, as its route id (AD-13): any header of the session opens the same trace. A
/// message no header holds, or a header saved with no session, reads as no rows and shows the Header tab's sentence. The read's note
/// states the named limit: the classic Visual Trace also shows the session's event, rule and I/O log entries, which this read does not.</p>
/// <p><b>Its pairs add the Visual Trace's</b> <code>%Ens_MessageTrace:USE</code> to the viewer's (AD-8, AD-44), which the Operator
/// role holds: the tab stays in the strip for a caller without it, <code>aria-disabled</code> with its failed pair. It offers no
/// action. The table it declares is the read's contract (<code>Screen/Registry</code> requires one); the page draws the diagram in its
/// place.</p>
Class OcuPilot.Screen.Descriptor.InteropMessageTraceTab Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/messages/trace",
  "area": "interoperability",
  "labelKey": "interopMessageTraceLabel",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_MessageHeader", "permission": "USE"}, {"resource": "%Ens_MessageTrace", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%Ens_MessageHeader", "permission": "USE"}, {"resource": "%Ens_MessageTrace", "permission": "USE"}],
  "entityType": "interop-message",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "interoperability/messages",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Step", "ID", "TimeCreated", "Type", "Status", "Source", "Target", "BodyClass", "Error"], "secretFields": []},
  "emptyStateKey": "interopMessageHeaderEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopMessageTracePrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopMessageTracePrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopMessageTracePrompt3"}
  ],
  "classicPage": "EnsPortal.VisualTrace",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "interop", "endpoint": "MessageTrace", "type": "LIST"},
    "fields": ["Message", "Step", "ID", "TimeCreated", "Type", "Status", "Source", "Target", "BodyClass", "Error", "SessionId"],
    "filter": ["Type", "Status", "Source", "Target", "BodyClass"],
    "sort": {"fields": ["Step"], "default": "Step", "direction": "asc"},
    "paging": "cap",
    "note": {"key": "interopMessageTraceNote", "text": "OcuPilot draws this session's messages. The classic Visual Trace also shows its event, rule and I/O log entries."},
    "criteria": {
      "fields": [{"param": "message", "labelKey": "interopColumnId", "kind": "text", "maxLength": 19, "hint": "One message, as interop.messages.read answers its ID; the trace is that message's whole session."}]
    }
  },
  "table": {
    "columns": [
      {"field": "ID", "labelKey": "interopColumnId", "kind": "name"},
      {"field": "TimeCreated", "labelKey": "journalColumnCreated", "kind": "text"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "Status", "labelKey": "taskHistoryColumnStatus", "kind": "status"},
      {"field": "Source", "labelKey": "auditEventFieldSource", "kind": "text"},
      {"field": "Target", "labelKey": "agentLedgerColumnTarget", "kind": "text"},
      {"field": "BodyClass", "labelKey": "interopColumnBodyClass", "kind": "identifier"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "interoperability/messages/document", "position": 3, "labelKey": "interopMessageTabTrace"},
  "toolIdentifier": "interop.messagetrace"
}
}

}
