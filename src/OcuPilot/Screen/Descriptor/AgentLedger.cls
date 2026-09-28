/// <p>The Agent audit ledger (Story 16.16): the agent ledger's rows, searched by user, screen and
/// time and opened one at a time, rendered by its own page from <code>GET /agent/ledger</code>
/// (<method>OcuPilot.Kernel.Audit.Ledger.ViewForUser</method>, AD-46).</p>
/// <p><b>It declares no <code>read</code> and no <code>table</code></b>: the ledger is read by
/// people, not by the agent (AD-46). Every declared read derives an advertised read tool, so this
/// screen has none, and its <code>context</code> declares no field, so no ledger row enters screen
/// context. Every decision about which rows a caller sees is the ledger's own, over the one
/// route.</p>
/// <p><b>It never gates.</b> Its privilege set is empty: every signed-in user sees their own rows,
/// and an <code>OcuPilotAdmin:USE</code> holder every user's, each other user's row gated by the
/// pairs it records. Its id is <code>composite</code> over <code>ledgerId</code>, so a row opens
/// at <code>agent/ledger/&lt;ledgerId&gt;</code>. No entity type, scope <code>instance</code>, no
/// action, and no classic equivalent (AD-44). It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.AgentLedger Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "agent/ledger",
  "area": "agent",
  "labelKey": "agentLedgerLabel",
  "sideBarPosition": 5,
  "archetype": "list (server criteria)",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [],
  "entityType": "",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["ledgerId"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": []},
  "emptyStateKey": "agentLedgerEmpty",
  "commandAliases": ["agent audit ledger", "ledger", "agent activity"],
  "suggestedPrompts": [
    {"groupKey": "auditUserEventPromptGroup", "textKey": "agentLedgerPrompt1"},
    {"groupKey": "auditUserEventPromptGroup", "textKey": "agentLedgerPrompt2"},
    {"groupKey": "auditUserEventPromptGroup", "textKey": "agentLedgerPrompt3"}
  ],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "agent.ledger"
}
}

}
