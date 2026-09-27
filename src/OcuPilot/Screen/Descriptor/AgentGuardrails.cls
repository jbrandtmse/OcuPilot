/// <p>The Guardrails screen (Story 16.22): what the agent refuses outright, what always waits for a
/// Confirm, what it never sees, the switches in force for the caller and the screen-context
/// limits, rendered by its own <code>form-page</code> page from <code>GET /ui/guardrails</code>
/// (AD-5, AD-10, AD-22, AD-24).</p>
/// <p><b>It takes the Agent co-pilot area's third side-bar position</b>, after Switches.</p>
/// <p><b>It never gates.</b> Its privilege set is empty, like Home's, so every signed-in caller
/// reaches it: the page shows declarations every caller's tool set already advertises and the
/// caller's own verdict, nothing more (AD-8).</p>
/// <p><b>It declares no <code>read</code> and no <code>table</code></b>, so it has no read tool and
/// no screen-context rows. Its answer is shell chrome (AD-50), not one of AD-36's two source
/// kinds. It is read-only: no primary action and no row action.</p>
/// <p><b>It has no classic equivalent</b>, so <code>classicPage</code> is <code>""</code> with the
/// exemption false (AD-44). It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.AgentGuardrails Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "agent/guardrails",
  "area": "agent",
  "labelKey": "agentGuardrailsLabel",
  "sideBarPosition": 3,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [],
  "entityType": "",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": []},
  "emptyStateKey": "",
  "commandAliases": ["guardrails", "prohibited actions", "what the agent refuses"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupAgentSetup", "textKey": "agentGuardrailsPrompt1"},
    {"groupKey": "promptGroupAgentSetup", "textKey": "agentGuardrailsPrompt2"},
    {"groupKey": "promptGroupAgentSetup", "textKey": "agentGuardrailsPrompt3"}
  ],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "agent.guardrails"
}
}

}
