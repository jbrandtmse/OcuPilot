/// <p>Interoperability's Contents tab of one message (Story 20.9): the message body as text lines, rebuilt by OcuPilot and read-only,
/// read through <class>OcuPilot.Port.InteropPort</class> (source kind <code>interop</code>, endpoint <code>MessageContents</code>)
/// and drawn by <code>app-interop-message-contents</code> as one block of text in place of the table (AD-5, AD-11, AD-29, AD-36,
/// AD-62). The vendor's message viewer is not embedded (AD-63).</p>
/// <p><b>It is the second tab of the group</b> <code>interoperability/messages/document</code>, parent-scoped under Messages, with the
/// Header tab's one criterion, <code>message</code>, as its route id (AD-13). A read that opens a body records the vendor's own
/// <code>%Ensemble/%Message/ViewContents</code> audit row, as the classic Contents pane does. A body that is not text is refused
/// <code>INTEROP.MESSAGE.CONTENTS</code>; a message with no body shows the screen's sentence.</p>
/// <p><b>Its pairs add the classic Contents pane's</b> <code>%Ens_MessageContent:USE</code> to the viewer's (AD-8, AD-44), which the
/// Administrator and Web Developer roles hold and the Operator role does not: the tab stays in the strip for a caller without it,
/// <code>aria-disabled</code> with its failed pair. It offers no action and no control that edits the text.</p>
Class OcuPilot.Screen.Descriptor.InteropMessageContentsTab Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/messages/contents",
  "area": "interoperability",
  "labelKey": "interopMessageContentsLabel",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_MessageHeader", "permission": "USE"}, {"resource": "%Ens_MessageContent", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%Ens_MessageHeader", "permission": "USE"}, {"resource": "%Ens_MessageContent", "permission": "USE"}],
  "entityType": "interop-message",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "interoperability/messages",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Line", "Text"], "secretFields": []},
  "emptyStateKey": "interopMessageContentsEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopMessageContentsPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopMessageContentsPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopMessageContentsPrompt3"}
  ],
  "classicPage": "EnsPortal.MessageViewer",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "interop", "endpoint": "MessageContents", "type": "LIST"},
    "fields": ["Message", "Line", "Text"],
    "filter": ["Text"],
    "sort": {"fields": ["Line"], "default": "Line", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [{"param": "message", "labelKey": "interopColumnId", "kind": "text", "maxLength": 19, "hint": "One message, as interop.messages.read answers its ID."}]
    }
  },
  "table": {
    "columns": [
      {"field": "Line", "labelKey": "explorerColumnLine", "kind": "name"},
      {"field": "Text", "labelKey": "explorerSearchTextLabel", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "interoperability/messages/document", "position": 2, "labelKey": "interopMessageTabContents"},
  "toolIdentifier": "interop.messagecontents"
}
}

}
