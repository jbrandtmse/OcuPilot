/// <p>The Governance policy screen (Story 14.2, AD-22): the preset and a per-key setting for every
/// registered write tool, with the baseline beside each and what is in effect, rendered by its own
/// <code>form-page</code> page over <code>GET</code> and <code>PUT /agent/governance</code>.</p>
/// <p><b>It takes the Agent co-pilot area's fourth side-bar position</b>, the place EXPERIENCE.md's
/// side-bar list gives it among the area's screens, ahead of Transcripts.</p>
/// <p><b>It declares no <code>read</code>, no <code>table</code> and no action</b>, for the reason
/// <class>OcuPilot.Screen.Descriptor.AgentSwitches</class> declares none: a form over OcuPilot's own
/// configuration loads and saves its own route. Its privilege set is OcuPilot's administrative
/// resource; its scope is <code>instance</code>; it has no classic equivalent (AD-44) and does not
/// refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.AgentGovernance Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "agent/governance",
  "area": "agent",
  "labelKey": "agentGovernanceLabel",
  "sideBarPosition": 4,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "OcuPilotAdmin", "permission": "USE"}],
  "entityType": "agent-policy",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": []},
  "emptyStateKey": "",
  "commandAliases": ["governance", "tool policy"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupAgentSetup", "textKey": "agentGovernancePrompt1"},
    {"groupKey": "promptGroupAgentSetup", "textKey": "agentGovernancePrompt2"},
    {"groupKey": "promptGroupAgentSetup", "textKey": "agentGovernancePrompt3"}
  ],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "agent.governance"
}
}

}
