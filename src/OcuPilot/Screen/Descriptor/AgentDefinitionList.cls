/// <p>The Definitions list: every agent definition on this instance, read through
/// <b>OcuPilot's own protected state</b> rather than through a port (AD-9, AD-36), and rendered by
/// the <code>list</code> archetype's page from the declared <code>table</code> (AD-5).</p>
/// <p><b>It is the first descriptor whose read names the <code>state</code> source kind.</b>
/// <code>read.source</code> is <code>{port: "state", endpoint: "Agent", type: "LIST"}</code>: the
/// rows come from <method>OcuPilot.Kernel.State.Agent.GuardedScreenRows</method>, which is also
/// what <method>OcuPilot.Api.Definitions.SelectionProjection</method> answers, so the switcher,
/// this list and this screen's read tool cannot disagree about what a definition row is. Everything
/// else about the read is a declared read's: the same six fields, the same filter and sort, the
/// same row cap and the same truncation signal.</p>
/// <p><b>It is also the project's first write-capable descriptor.</b> Three row actions --
/// <code>enable</code>, <code>disable</code> and <code>set-default</code> -- act on the selected
/// row in place and publish AD-14's <code>(agent-definition, instance, id)</code> change event, so
/// the row re-fetches without a reload. Being write-capable is what makes the empty state invite
/// the agent: <code>table.emptyAgentKey</code> is declared and <code>emptyNextKey</code> is empty,
/// which <method>OcuPilot.Screen.Registry.TableProblem</method> requires of each other.</p>
/// <p><b>Its id is <code>composite</code> over one part, <code>id</code></b>, and that is not a
/// degenerate composite: the row's key is the definition's own identifier, which is what a row
/// action calls and what a change event names, where the single-part accessor would take the name
/// column's text instead and key both on a value an operator can change (AD-13).</p>
/// <p><b>Its scope is <code>instance</code>.</b> An agent definition is OcuPilot's own
/// configuration, keyed by its identifier alone and held in one protected database, so the list is
/// the same whatever namespace the route names (AD-13, AD-44).</p>
/// <p><b>The privilege set is OcuPilot's own administrative resource</b>, which is what
/// EXPERIENCE.md's Privilege Gating requires of this screen ("Agent co-pilot &#8250; Definitions
/// and Switches"). It names no <code>%DB_IRISSYS:READ</code>, and does not need one: that pair is
/// the admin port's, because the port runs every vendor endpoint in <code>%SYS</code>, and this
/// read runs in the install namespace against a kernel store. The <code>agent</code> area declares
/// <b>no</b> pairs, because EXPERIENCE.md requires the rail item never to gate -- a never-gating
/// area whose screens gate independently, which
/// <method>OcuPilot.Screen.Registry.AreaCoverageProblem</method> admits and an area that declares
/// a non-empty, non-covering set still does not.</p>
/// <p><b>It has no classic equivalent</b>, so <code>classicPage</code> is <code>""</code> with
/// <code>classicLinkExemption.exempt</code> false -- AD-44's explicit way to say so, rather than a
/// key left absent. As a list archetype it would link out to nothing in any case. It does not
/// refresh: EXPERIENCE.md's auto-refresh roster is the six live lists and details, and this is not
/// one of them (AD-43).</p>
Class OcuPilot.Screen.Descriptor.AgentDefinitionList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "agent/definitions",
  "area": "agent",
  "labelKey": "agentDefinitionListLabel",
  "sideBarPosition": 1,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "OcuPilotAdmin", "permission": "USE"}],
  "entityType": "agent-definition",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["id"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [
    {"id": "enable", "selfProtection": ""},
    {"id": "disable", "selfProtection": ""},
    {"id": "set-default", "selfProtection": ""}
  ],
  "context": {"fields": ["id", "name", "provider", "model", "enabled", "default"], "secretFields": []},
  "emptyStateKey": "agentDefinitionListEmpty",
  "commandAliases": ["agent definitions", "definitions", "api key"],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "state", "endpoint": "Agent", "type": "LIST"},
    "fields": ["id", "name", "provider", "model", "enabled", "default"],
    "filter": ["name", "provider", "model"],
    "sort": {"fields": ["name", "provider", "model"], "default": "name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "provider", "labelKey": "tableColumnProvider", "kind": "text"},
      {"field": "model", "labelKey": "tableColumnModel", "kind": "text"},
      {"field": "enabled", "labelKey": "tableColumnEnabled", "kind": "status"},
      {"field": "default", "labelKey": "tableColumnDefault", "kind": "status"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "agentDefinitionListEmptyAgent"
  },
  "toolIdentifier": "agent.definitions"
}
}

}
