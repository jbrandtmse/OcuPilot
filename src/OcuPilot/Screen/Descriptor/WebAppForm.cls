/// <p>The Web application form: one web application, created here and edited here from Epic 9,
/// rendered by the <code>form-page</code> archetype (AD-5). It is the first <code>form-page</code>
/// over an object that lives on the instance rather than in OcuPilot's own state, so it is the
/// first screen whose Save passes AD-10's prohibited set (AD-55).</p>
/// <p><b>It is built and routable, and it takes no side-bar position.</b>
/// <code>sideBarPosition</code> is <b>0</b>, the sentinel for routable-but-unlisted: the route
/// table reads every <i>built</i> screen while the side bar, the command box, Home's tile caption,
/// the locator bar's area target and the rail's landing all read an area's <i>listed</i> ones. The
/// form is reached from <class>OcuPilot.Screen.Descriptor.WebAppList</class>'s Create, and its
/// route is that list's own with <code>/edit</code> appended -- the convention
/// <method>editorScreenFor</method> resolves, never a declaration key.</p>
/// <p><b>It declares no <code>read</code> and no <code>table</code>,</b> and that is not an
/// omission (AD-36). A form is one entity, not a list of rows: the create route answers the
/// application it just made, and the list beside it is where the declared read lives.
/// <method>OcuPilot.Screen.Tool.Registry.Claim</method> refuses a tool name two sources hold, so
/// giving this descriptor a read later would be refused rather than resolve to either.</p>
/// <p><b>Its privilege set is the list's own</b> -- <code>%Admin_Secure:USE</code> plus
/// <code>%DB_IRISSYS:READ</code> -- because the form reads and writes the same vendor endpoint the
/// list reads, and AD-8 makes a write tool's pair set the screen's own.</p>
/// <p><b>Its classic equivalent is <code>%CSP.UI.Portal.Applications.Web</code></b>, spelled in the
/// class's own case because the custom-resource lookup does not case-fold (AD-44). It declares no
/// exemption: a detail view <i>may</i> link out, and this one does not, because the form is a
/// replacement for that page rather than a reduced view of it. It does not refresh (AD-43): a form
/// whose fields moved under the operator's cursor is the one thing auto-refresh must not do.</p>
/// <p><b>No argument of its write tool is secret</b> (AD-3, AD-6): a web application's body carries
/// no credential. The list declares the same, and the two are separate declarations because each
/// is what the registry's credential-pattern refusal is evaluated against.</p>
Class OcuPilot.Screen.Descriptor.WebAppForm Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "web-applications/list/edit",
  "area": "web-applications",
  "labelKey": "webAppFormLabel",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "web-application",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": []},
  "secretArguments": [],
  "fingerprintExcludes": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "classicPage": "%CSP.UI.Portal.Applications.Web",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "webapp.form"
}
}

}
