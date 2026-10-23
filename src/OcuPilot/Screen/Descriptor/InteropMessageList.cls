/// <p>Interoperability's Messages: a search over the namespace's message headers by time window, status, type, source, target, body
/// class, session and error flag, newest first, read through <class>OcuPilot.Port.InteropPort</class> (source kind
/// <code>interop</code>, endpoint <code>Messages</code>) and rendered by the <code>list (server criteria)</code> archetype's page
/// (AD-5, AD-29, AD-36, AD-62, Story 20.9). No message body is read.</p>
/// <p><b>The criteria are the read's</b>: <code>beginDateTime</code> opens on the last 24 hours and is required by the port, so a
/// search that clears it is refused rather than scanning the store; <code>endDateTime</code>, <code>status</code>, <code>type</code>,
/// <code>source</code>, <code>target</code>, <code>bodyClass</code>, <code>session</code> and <code>errors</code> narrow it. The
/// window is turned into ID bounds as the classic message viewer turns it. Saved searches, and the classic viewer's body, search-table
/// and virtual-document criteria, stay in the classic page.</p>
/// <p><b>A row's ID opens that message's Header tab</b> (<code>interoperability/messages/document</code>, the head of the group
/// <class>OcuPilot.Screen.Descriptor.InteropMessageHeaderTab</class>, <class>OcuPilot.Screen.Descriptor.InteropMessageContentsTab</class>
/// and <class>OcuPilot.Screen.Descriptor.InteropMessageTraceTab</class> form). Its pairs are the classic viewer's own
/// (<code>%Ens_MessageHeader:USE</code> beside the area's <code>%Ens_Portal:USE</code>), which the Operator role holds (AD-8, AD-44).
/// It does not refresh. The checked rows (at most 100) resend after a dry run lists what each would do (Story 20.31,
/// <class>OcuPilot.Screen.Tool.InteropMessageResend</class>).</p>
Class OcuPilot.Screen.Descriptor.InteropMessageList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/messages",
  "area": "interoperability",
  "labelKey": "interopItemTabMessages",
  "sideBarPosition": 11,
  "archetype": "list (server criteria)",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_MessageHeader", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%Ens_MessageHeader", "permission": "USE"}],
  "entityType": "interop-message",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "resend", "selfProtection": ""}],
  "multiSelect": {"action": "resend", "max": 100},
  "context": {"fields": ["ID", "TimeCreated", "Status", "Type", "Source", "Target", "BodyClass", "SessionId"], "secretFields": []},
  "emptyStateKey": "interopMessagesEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopMessagesPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopMessagesPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopMessagesPrompt3"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopMessagesWorkflowResend", "workflow": "resendmessages"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopMessagesWorkflowTrace", "workflow": "tracemessage"}
  ],
  "classicPage": "EnsPortal.MessageViewer",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "interoperability message header",
    "label": "Interoperability message headers in this namespace, the last 24 hours unless asked; the console log messages.log is logs.messages.",
    "source": {"port": "interop", "endpoint": "Messages", "type": "LIST"},
    "fields": ["ID", "TimeCreated", "Status", "Type", "Source", "Target", "BodyClass", "SessionId", "Error"],
    "filter": ["Status", "Type", "Source", "Target", "BodyClass", "SessionId"],
    "sort": {"fields": ["TimeCreated", "Status", "Type", "Source", "Target", "BodyClass", "SessionId"], "default": "TimeCreated", "direction": "desc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "beginDateTime", "labelKey": "auditCriteriaBegin", "kind": "datetime", "maxLength": 50, "defaultHoursAgo": 24},
        {"param": "endDateTime", "labelKey": "auditCriteriaEnd", "kind": "datetime", "maxLength": 50},
        {"param": "status", "labelKey": "taskHistoryColumnStatus", "kind": "choice", "maxLength": 9, "options": ["Created", "Queued", "Delivered", "Discarded", "Suspended", "Deferred", "Aborted", "Error", "Completed"]},
        {"param": "type", "labelKey": "tableColumnType", "kind": "choice", "maxLength": 8, "options": ["Request", "Response"]},
        {"param": "source", "labelKey": "auditEventFieldSource", "kind": "text", "maxLength": 128, "hint": "The configuration name of the business host that sent the message, spelled as interop.messages.read answers its Source."},
        {"param": "target", "labelKey": "agentLedgerColumnTarget", "kind": "text", "maxLength": 128, "hint": "The configuration name of the business host the message was sent to, spelled as interop.messages.read answers its Target."},
        {"param": "bodyClass", "labelKey": "interopColumnBodyClass", "kind": "text", "maxLength": 220, "hint": "One message body class, spelled as interop.messages.read answers its BodyClass."},
        {"param": "session", "labelKey": "webSessionColumnSession", "kind": "text", "maxLength": 19, "hint": "One session's whole-number id, as interop.messages.read answers its SessionId."},
        {"param": "errors", "labelKey": "interopMessagesCriterionErrors", "kind": "choice", "maxLength": 3, "options": ["yes", "no"]}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "ID", "labelKey": "interopColumnId", "kind": "name"},
      {"field": "TimeCreated", "labelKey": "journalColumnCreated", "kind": "text"},
      {"field": "Status", "labelKey": "taskHistoryColumnStatus", "kind": "status"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "Source", "labelKey": "auditEventFieldSource", "kind": "text"},
      {"field": "Target", "labelKey": "agentLedgerColumnTarget", "kind": "text"},
      {"field": "BodyClass", "labelKey": "interopColumnBodyClass", "kind": "identifier"},
      {"field": "SessionId", "labelKey": "webSessionColumnSession", "kind": "identifier"},
      {"field": "Error", "labelKey": "errorLogColumnText", "kind": "status"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "interopMessagesEmptyAgent"
  },
  "toolIdentifier": "interop.messages"
}
}

}
