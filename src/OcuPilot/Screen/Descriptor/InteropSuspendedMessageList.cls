/// <p>Interoperability's Suspended messages: the namespace's message headers whose status is Suspended, newest first, at most 2,000, which the classic Suspended Messages page
/// lists, read through <class>OcuPilot.Port.InteropPort</class> (source kind <code>interop</code>, endpoint <code>SuspendedMessages</code>) and rendered from the declared
/// <code>table</code> (AD-5, AD-29, AD-36, AD-62, Story 24.16). No message body is read.</p>
/// <p><b>Its row actions</b> are the classic page's four, each the screen's caller of its tool (AD-53, AD-55): Resubmit, Discard and Delete over the checked rows (at most
/// 100, <code>multiSelect</code>), each after a dry run that lists what every message would do and sends nothing
/// (<class>OcuPilot.Screen.Tool.InteropSuspendedResubmit</class>, <class>OcuPilot.Screen.Tool.InteropSuspendedDiscard</class>,
/// <class>OcuPilot.Screen.Tool.InteropSuspendedDelete</class>), and Edit and resubmit over the one row
/// (<class>OcuPilot.Screen.Tool.InteropSuspendedEditResubmit</class>). Resubmit, Edit and resubmit and Delete are destructive and Delete is last. The classic page's Discard
/// All and Delete All run in the background over every suspended message, and stay in the classic page.</p>
/// <p><b>Its pairs</b> are the classic page's: <code>%Ens_Portal:USE</code> and, as its own, <code>%Ens_MessageHeader:USE</code>; each tool adds its own resource and WRITE on the
/// namespace's globals database (AD-8, AD-62). Its scope is <code>namespace</code>. It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.InteropSuspendedMessageList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/suspended-messages",
  "area": "interoperability",
  "labelKey": "interopSuspendedLabel",
  "sideBarPosition": 18,
  "archetype": "list",
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
  "rowActions": [{"id": "resubmit", "selfProtection": ""}, {"id": "editresubmit", "selfProtection": ""}, {"id": "discard", "selfProtection": ""}, {"id": "delete", "selfProtection": ""}],
  "multiSelect": {"action": "resubmit", "max": 100, "extraActions": ["discard", "delete"]},
  "context": {"fields": ["ID", "TimeCreated", "SessionId", "Error", "Type", "Source", "Target", "BodyClass"], "secretFields": []},
  "emptyStateKey": "interopSuspendedEmpty",
  "commandAliases": ["suspended messages"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopSuspendedPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopSuspendedPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopSuspendedPrompt3"}
  ],
  "classicPage": "EnsPortal.SuspendedMsg",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "suspended message",
    "label": "Interoperability message headers in this namespace whose status is Suspended, newest first, at most 2,000; message headers of every status are interop.messages.",
    "source": {"port": "interop", "endpoint": "SuspendedMessages", "type": "LIST"},
    "fields": ["ID", "TimeCreated", "SessionId", "Error", "Type", "Source", "Target", "BodyClass"],
    "filter": ["Type", "Source", "Target", "BodyClass", "SessionId"],
    "sort": {"fields": ["TimeCreated", "Type", "Source", "Target", "BodyClass", "SessionId"], "default": "TimeCreated", "direction": "desc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "ID", "labelKey": "interopColumnId", "kind": "name"},
      {"field": "TimeCreated", "labelKey": "journalColumnCreated", "kind": "text"},
      {"field": "SessionId", "labelKey": "webSessionColumnSession", "kind": "identifier"},
      {"field": "Error", "labelKey": "errorLogColumnText", "kind": "status"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "Source", "labelKey": "auditEventFieldSource", "kind": "text"},
      {"field": "Target", "labelKey": "agentLedgerColumnTarget", "kind": "text"},
      {"field": "BodyClass", "labelKey": "interopColumnBodyClass", "kind": "identifier"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "interopSuspendedEmptyAgent"
  },
  "toolIdentifier": "interop.suspendedmessages"
}
}

}
