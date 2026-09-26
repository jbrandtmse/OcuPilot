/// <p>The instance's auditing configuration: one <code>form-page</code> over the vendor's
/// <code>Security.Audit.Enabled</code> endpoint, declared so the agent's write tool and the screen
/// Story 7.4 builds are two callers of one operation (AD-5, FR-47).</p>
/// <p><b>It is a built <code>form-page</code> with a single-object read</b> (AD-36): the
/// <code>Security.Audit.Enabled</code> <code>GET</code>, whose one row is the instance-wide
/// <code>Enabled</code> flag. The page renders that flag as a status line and one action, and
/// embeds <class>OcuPilot.Screen.Descriptor.AuditSystemEventList</class> and
/// <class>OcuPilot.Screen.Descriptor.AuditUserEventList</class> beneath it by issuing their own
/// declared reads (AD-5). A form renders no grid, so it declares no <code>table</code> and no
/// empty-state sentence (<class>OcuPilot.Screen.Registry</class>'s <code>RendersNoTable</code>).</p>
/// <p><b>Its two row actions are the screen's caller of
/// <class>OcuPilot.Screen.Tool.AuditingUpdate</class></b> (AD-53): <code>enable</code> and
/// <code>disable</code> reach the same tool the agent's proposal does, through
/// <code>POST /screens/security.auditing/action</code> with the singleton id.</p>
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
/// <p><b>Its <code>copy</code> and <code>purge</code> row actions act on the audit database</b>
/// (Story 12.3): <class>OcuPilot.Screen.Tool.AuditCopy</class> and
/// <class>OcuPilot.Screen.Tool.AuditPurge</class>, each carrying one value -- the namespace, the
/// cut-off day -- to the same singleton. The purge tool is unadvertised, so this screen's context
/// lists the copy tool and not it (AD-53).</p>
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
  "sideBarPosition": 6,
  "archetype": "form-page",
  "built": true,
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
  "rowActions": [{"id": "enable", "selfProtection": ""}, {"id": "disable", "selfProtection": ""}, {"id": "copy", "selfProtection": ""}, {"id": "purge", "selfProtection": ""}],
  "context": {"fields": ["Enabled"], "secretFields": []},
  "emptyStateKey": "",
  "commandAliases": ["auditing"],
  "suggestedPrompts": [
    {"groupKey": "auditUserEventPromptGroup", "textKey": "auditingConfigPrompt1"},
    {"groupKey": "auditUserEventPromptGroup", "textKey": "auditingConfigPrompt2"},
    {"groupKey": "auditUserEventPromptGroup", "textKey": "auditingConfigPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.Audit.SystemEvents",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Security.Audit.Enabled", "type": "GET"},
    "fields": ["Enabled"],
    "filter": ["Enabled"],
    "sort": {"fields": ["Enabled"], "default": "Enabled", "direction": "asc"},
    "paging": "cap"
  },
  "toolIdentifier": "security.auditing"
}
}

}
