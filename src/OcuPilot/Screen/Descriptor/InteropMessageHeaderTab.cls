/// <p>Interoperability's Header tab of one message (Story 20.9): the message header's twenty-three properties as name and value
/// rows in the classic Header pane's order, read through <class>OcuPilot.Port.InteropPort</class> (source kind <code>interop</code>,
/// endpoint <code>MessageHeader</code>) and rendered by the shared page under the message's tab strip (AD-5, AD-29, AD-36,
/// AD-62).</p>
/// <p><b>It is the head of the group</b> <code>interoperability/messages/document</code>, parent-scoped under Messages: its one
/// criterion, <code>message</code>, is the route id, the header's ID kept exactly (AD-13), and the strip carries it from tab to tab.
/// A Messages row's ID and a Queue messages row's message id open it. A message no header holds reads as no rows and shows the
/// screen's sentence. Its rows keep the classic pane's order, which no column shows, so it offers no sort. Its pairs are the classic
/// viewer's own (AD-8, AD-44); it does not refresh. Its two actions, Resend and Edit and resend (Story 20.31,
/// <class>OcuPilot.Screen.Tool.InteropMessageResend</class> and <class>OcuPilot.Screen.Tool.InteropMessageEditResend</class>), are the
/// page's own: the rows are properties, so neither has a row to name, and each acts on the message the strip carries.</p>
Class OcuPilot.Screen.Descriptor.InteropMessageHeaderTab Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/messages/document",
  "area": "interoperability",
  "labelKey": "logViewerColumnMessage",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_MessageHeader", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%Ens_MessageHeader", "permission": "USE"}],
  "entityType": "interop-message",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "interoperability/messages",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "resend", "selfProtection": ""},
  "rowActions": [{"id": "resend", "selfProtection": ""}, {"id": "editresend", "selfProtection": ""}],
  "context": {"fields": ["Name", "Value"], "secretFields": []},
  "emptyStateKey": "interopMessageHeaderEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopMessageHeaderPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopMessageHeaderPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopMessageHeaderPrompt3"}
  ],
  "classicPage": "EnsPortal.MessageViewer",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "interop", "endpoint": "MessageHeader", "type": "LIST"},
    "fields": ["Message", "Position", "Name", "Value"],
    "filter": ["Name", "Value"],
    "sort": {"fields": ["Position"], "default": "Position", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [{"param": "message", "labelKey": "interopColumnId", "kind": "text", "maxLength": 19, "hint": "One message, as interop.messages.read answers its ID."}]
    }
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Value", "labelKey": "errorLogColumnValue", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "interopMessagesEmptyAgent"
  },
  "tab": {"group": "interoperability/messages/document", "position": 1, "labelKey": "interopMessageTabHeader"},
  "toolIdentifier": "interop.messageheader"
}
}

}
