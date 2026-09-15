/// <p>The Definition form: one agent definition, created or edited, rendered by the
/// <code>form-page</code> archetype's page (AD-5). It is the first <code>form-page</code> in the
/// product and the surface the first-login gate lands on (FR-24 to FR-27).</p>
/// <p><b>It is built and routable, and it takes no side-bar position.</b>
/// <code>sideBarPosition</code> is <b>0</b>, the sentinel for routable-but-unlisted: the side bar,
/// the command box, Home's tile caption, the locator bar's area target and the rail's landing all
/// read an area's <i>listed</i> screens, while the route table reads every <i>built</i> one. So
/// the form is reachable and never advertised, and the Agent co-pilot area has the one Release 1
/// side-bar entry EXPERIENCE.md gives it rather than a third. The form is reached from
/// <class>OcuPilot.Screen.Descriptor.AgentDefinitionList</class>'s name cell and from that list's
/// Create. The command box is excluded deliberately as well as by the sentinel: this screen
/// declares a <code>single</code> id, so a search result landing on it with no id would open a
/// create form the user did not ask for.</p>
/// <p><b>It declares no <code>read</code> and no <code>table</code>,</b> and that is not an
/// omission (AD-36). A form is one entity, not a list of rows: it loads
/// <code>GET /agent/definitions/:id</code> for the definition its route names and posts the whole
/// writable field set back (AD-4). The list beside it is where the declared read lives, and
/// <method>OcuPilot.Screen.Tool.Registry.Claim</method> refuses a tool name two sources hold, so
/// giving this descriptor a read later would be refused rather than resolve to either.</p>
/// <p><b><code>context.secretFields</code> names the key</b>, so AD-24's serializer can never put
/// it in a turn's screen context and AD-35's rule that a secret never reaches a surface OcuPilot
/// displays is declared where the screen is. There is nothing for it to strip today -- no route
/// returns a key and the field is never pre-filled -- which is exactly why it is declared: the
/// absence is the guarantee, and a later field added to <code>context.fields</code> meets a
/// declaration that already names the secret.</p>
/// <p><b>Its privilege set is OcuPilot's own administrative resource</b>, the same pair the list
/// declares and the same one every write route checks server-side. The <code>agent</code> area
/// declares none, because the rail item never gates.</p>
/// <p><b>It has no classic equivalent</b> -- the classic portal has no agent definition --
/// so <code>classicPage</code> is <code>""</code> with <code>classicLinkExemption.exempt</code>
/// false, AD-44's explicit way to say so. It does not refresh (AD-43): a form whose fields moved
/// under the operator's cursor is the one thing auto-refresh must not do.</p>
Class OcuPilot.Screen.Descriptor.AgentDefinitionForm Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "agent/definitions/edit",
  "area": "agent",
  "labelKey": "agentDefinitionFormLabel",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "OcuPilotAdmin", "permission": "USE"}],
  "entityType": "agent-definition",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": ["apiKey"]},
  "emptyStateKey": "",
  "commandAliases": [],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "agent.definition"
}
}

}
