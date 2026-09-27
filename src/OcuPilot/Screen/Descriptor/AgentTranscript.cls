/// <p>One stored conversation (Story 14.4), opened from the Transcripts list's name cell and rendered
/// by the client's own transcript page over <code>GET /transcripts/:id</code>
/// (<class>OcuPilot.Api.Transcripts</class>). It declares <b>no read</b>: a transcript is not a
/// declared read's rows, and its tool results and screen context reach another user only through
/// the ledger's per-row gate (AD-46), which that route asks.</p>
/// <p>It takes no side-bar position and names <code>agent/transcripts</code> as its parent, whose
/// route id it carries; like its list it declares no pair, no entity type and no classic page, and
/// it has no action.</p>
Class OcuPilot.Screen.Descriptor.AgentTranscript Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "agent/transcripts/details",
  "area": "agent",
  "labelKey": "agentTranscriptLabel",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [],
  "entityType": "",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "agent/transcripts",
  "id": {"kind": "composite", "parts": ["id"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": []},
  "emptyStateKey": "",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupAgentSetup", "textKey": "agentTranscriptsPrompt1"},
    {"groupKey": "promptGroupAgentSetup", "textKey": "agentTranscriptsPrompt2"},
    {"groupKey": "promptGroupAgentSetup", "textKey": "agentTranscriptsPrompt3"}
  ],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "agent.transcript"
}
}

}
