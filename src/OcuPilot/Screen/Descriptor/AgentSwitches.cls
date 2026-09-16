/// <p>The Switches screen: the kill switch, the users it is on for, enforced read-only and the
/// instance default for screen-context sharing, rendered by the <code>form-page</code> archetype's
/// page (AD-5, FR-19, FR-20, FR-29).</p>
/// <p><b>It takes the Agent co-pilot area's second side-bar position</b>, after Definitions' first,
/// which is the order EXPERIENCE.md's side-bar list gives the area. It is a navigation target, so
/// unlike <class>OcuPilot.Screen.Descriptor.AgentDefinitionForm</class> its
/// <code>sideBarPosition</code> is not the routable-but-unlisted sentinel.</p>
/// <p><b>It declares no <code>read</code> and no <code>table</code></b>, and that is not an omission
/// (AD-36). A form is one entity, not a list of rows: it loads <code>GET /agent/switches</code> and
/// posts the writable set back. The existing machinery would serve it only through the read grammar
/// -- <class>OcuPilot.Screen.Read</class> pins <code>READTYPE = "LIST"</code> and
/// <method>OcuPilot.Screen.Registry.ReadProblem</method> always ends in
/// <method>TableProblem</method>, so a descriptor that declares a read must also declare columns
/// this screen does not render. The Definition form declares neither for the same reason, and this
/// follows it exactly.</p>
/// <p><b>Its actions carry its own labels</b> (DW-370). <code>create</code> here is "Switch off a
/// user" and <code>delete</code> is "Switch the agent back on"; the same <code>create</code> on
/// <class>OcuPilot.Screen.Descriptor.AgentDefinitionList</class> is "Create". The client's label map
/// is therefore keyed by descriptor, with the shared entry as the fallback.</p>
/// <p><b>Its privilege set is OcuPilot's own administrative resource</b>, which is what
/// EXPERIENCE.md's Privilege Gating requires of this screen; the <code>agent</code> area declares
/// none, because the rail item never gates.</p>
/// <p><b>Its scope is <code>instance</code></b>: the switches are OcuPilot's own configuration, held
/// in one protected database, so the screen is the same whatever namespace the route names (AD-13,
/// AD-44). <b>It has no classic equivalent</b> -- the classic portal has no agent kill switch -- so
/// <code>classicPage</code> is <code>""</code> with <code>classicLinkExemption.exempt</code> false,
/// AD-44's explicit way to say so. It does not refresh (AD-43): a form whose fields moved under the
/// operator's cursor is the one thing auto-refresh must not do.</p>
Class OcuPilot.Screen.Descriptor.AgentSwitches Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "agent/switches",
  "area": "agent",
  "labelKey": "agentSwitchesLabel",
  "sideBarPosition": 2,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "OcuPilotAdmin", "permission": "USE"}],
  "entityType": "agent-switch",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [{"id": "delete", "selfProtection": ""}],
  "context": {"fields": [], "secretFields": []},
  "emptyStateKey": "",
  "commandAliases": ["kill switch", "read-only", "switches"],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "agent.switches"
}
}

}
