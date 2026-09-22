/// <p>The instance's auditing configuration: one <code>form-page</code> over the vendor's
/// <code>Security.Audit.Enabled</code> endpoint, declared so the agent's write tool and the screen
/// Story 7.4 builds are two callers of one operation (AD-5, FR-47).</p>
/// <p><b>It is declared <code>built: false</code>, which is a first in this tree.</b> A
/// <code>built: true</code> descriptor's archetype is emitted as a
/// <code>BuiltArchetypeKey</code> that <file>ui/src/app/shell/screen-outlet.ts</file> requires a
/// page for, so declaring it built with no Angular page would fail <code>ng build</code>. Unbuilt
/// means nothing lists it, nothing routes it and no page is required, while
/// <class>OcuPilot.Screen.Tool.AuditingUpdate</class> still resolves its entity type, its scope
/// and its privilege set through it -- which is the whole reason the descriptor exists now rather
/// than with the screen. <code>sideBarPosition</code> is declared 0 and is exempt from the
/// side-bar rule while the screen is unbuilt
/// (<method>OcuPilot.Screen.Registry.SideBarPositionProblem</method>).</p>
/// <p><b>It declares no <code>read</code> and no <code>table</code></b> (AD-36), the shape
/// <class>OcuPilot.Screen.Descriptor.AgentDefinitionForm</class> already uses: the endpoint answers
/// one object, not rows, and the write tool names its own endpoint rather than falling back to a
/// declared read's.</p>
/// <p><b>Its entity type is the instance's auditing configuration, not an audit event.</b>
/// <code>audit-event</code> is one row of the event roster and its identity is a three-part query
/// key; this type names the single configuration object whose <code>Enabled</code> flag turns
/// auditing on and off, and <class>OcuPilot.Kernel.EntityRef</class>'s <code>singleton</code> rule
/// canonicalizes every spelling of its id to one key (AD-13).</p>
/// <p><b>Its privilege set is the endpoint's own <code>ResourcesOR()</code> resource at
/// <code>USE</code> and read on the code database the port runs it from</b> (AD-8 as amended
/// 2026-09-21, AD-29) -- the same pair set every other <code>security</code> screen declares, which
/// is what the area's own coverage requires.</p>
/// <p><b>The classic page is the System Audit Events page</b>, which is where the classic portal
/// administers auditing (AD-44 keys a custom resource by normalized class name). The instance-wide
/// enable and disable are classic <i>actions</i> on a CSP page rather than a page class, so they
/// carry no resource key of their own and cannot be named here.</p>
/// <p><b>Its singular noun is the published sentence EXPERIENCE.md already carries</b> for the
/// link beside the auditing-off banner, so the proposal card's title reads the same words the
/// banner's link does rather than a second name for one thing.</p>
/// <p>It does not refresh (AD-43): a form whose fields move under the operator's cursor is what
/// auto-refresh must not do, and EXPERIENCE.md's roster does not name it.</p>
Class OcuPilot.Screen.Descriptor.AuditingConfig Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/auditing",
  "area": "security",
  "labelKey": "auditingConfigurationLink",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": false,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "auditing-configuration",
  "entityLabelKey": "auditingConfigurationLink",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": []},
  "emptyStateKey": "",
  "commandAliases": [],
  "classicPage": "%CSP.UI.Portal.Audit.SystemEvents",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "security.auditing"
}
}

}
