/// <p>The Transcripts list (Story 14.4): the conversations OcuPilot keeps, read through
/// <b>OcuPilot's own protected state</b> (AD-9, AD-36) from
/// <method>OcuPilot.Kernel.State.Convo.GuardedScreenRows</method> and rendered by the
/// <code>list</code> archetype's page from the declared <code>table</code> (AD-5).</p>
/// <p><b>The rows are scoped to the caller by the store</b> (AD-36 as amended 2026-09-27): a caller
/// reads their own conversations, and a holder of <code>OcuPilotAdmin:USE</code> every user's, with
/// <code>title</code> -- the first message -- only on the caller's own rows. The read contract gains
/// no caller argument, and this descriptor declares no pair of its own: the screen is open to every
/// signed-in user, whose own history it is. The name cell opens
/// <class>OcuPilot.Screen.Descriptor.AgentTranscript</class>, whose route answers through the
/// ledger's own gate.</p>
/// <p><b>No entity type.</b> A conversation is OcuPilot's own record, nothing writes it from a screen,
/// and no change event names it, so the list declares none; its id is <code>composite</code> over
/// <code>id</code>, the conversation key. Its scope is <code>instance</code>, and it has no classic
/// equivalent (AD-44). It declares no action, so its empty state points to another screen rather
/// than to the agent.</p>
Class OcuPilot.Screen.Descriptor.AgentTranscripts Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "agent/transcripts",
  "area": "agent",
  "labelKey": "agentTranscriptsLabel",
  "sideBarPosition": 4,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [],
  "entityType": "",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["id"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["id", "user", "started", "lastActivity", "turns", "title"], "secretFields": []},
  "emptyStateKey": "agentTranscriptsEmpty",
  "commandAliases": ["transcripts", "conversation history"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupAgentSetup", "textKey": "agentTranscriptsPrompt1"},
    {"groupKey": "promptGroupAgentSetup", "textKey": "agentTranscriptsPrompt2"},
    {"groupKey": "promptGroupAgentSetup", "textKey": "agentTranscriptsPrompt3"}
  ],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "state", "endpoint": "Convo", "type": "LIST"},
    "fields": ["id", "user", "started", "lastActivity", "turns", "title"],
    "filter": ["user", "started", "lastActivity", "title"],
    "sort": {"fields": ["user", "started", "lastActivity", "turns", "title"], "default": "lastActivity", "direction": "desc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "started", "labelKey": "taskHistoryColumnStarted", "kind": "name"},
      {"field": "user", "labelKey": "processColumnUser", "kind": "text"},
      {"field": "turns", "labelKey": "agentTranscriptsColumnTurns", "kind": "number"},
      {"field": "lastActivity", "labelKey": "agentTranscriptsColumnLastActivity", "kind": "text"},
      {"field": "title", "labelKey": "agentTranscriptsColumnTitle", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "agent.transcripts"
}
}

}
