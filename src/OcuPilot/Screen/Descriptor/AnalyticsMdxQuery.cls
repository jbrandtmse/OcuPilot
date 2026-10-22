/// <p>Analytics' MDX query: one MDX statement run against the namespace's cubes, rendered as a <code>form-page</code> (AD-5, AD-8,
/// AD-29, AD-36, AD-44, AD-65, Story 20.33). The person writes a statement and runs it as an owner-scoped background run
/// (<class>OcuPilot.Area.Analytics.MdxQuery</class>, the second kind of <class>OcuPilot.Kernel.Shell.BackgroundRun</class>); the answer
/// is a grid of axis labels and cells, and a cell drills through to the vendor's listing for that cell.</p>
/// <p><b>It declares no <code>read</code></b> (AD-36): its page posts the statement to the background run's start, poll and cancel
/// routes under <code>/analytics/mdx/background</code>, which answer this screen only, so it has no declared read and no context field, and
/// a statement, its cells, its listings and the vendor's error text never reach screen context (AD-39's sixth exception). The agent's own
/// MDX read, <class>OcuPilot.Screen.Tool.AnalyticsMdxRead</class> (Story 20.35), is a read tool bound to this screen and listed in its context's
/// <code>tools</code>. It offers no action and does not refresh (AD-43).</p>
/// <p><b>Its pairs</b> are <code>%DeepSee_Portal:USE</code> and, as its own, <code>%Development:USE</code>: the classic MDX Query Tool
/// admits <code>%DeepSee_Admin</code> or <code>%Development</code>, and a pair set is an AND, so this screen names the narrower audience
/// (AD-8, AD-65). <code>AnalyticsPort</code> adds its own gate, including WRITE on the database the vendor's result cache lives in.</p>
Class OcuPilot.Screen.Descriptor.AnalyticsMdxQuery Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "analytics/mdx-query",
  "area": "analytics",
  "labelKey": "analyticsMdxQueryLabel",
  "sideBarPosition": 7,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%DeepSee_Portal", "permission": "USE"}, {"resource": "%Development", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "cube",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": []},
  "emptyStateKey": "",
  "commandAliases": ["mdx query", "run mdx", "mdx"],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "analyticsMdxQueryPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "analyticsMdxQueryPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "analyticsMdxQueryPrompt3"}
  ],
  "classicPage": "%DeepSee.UI.MDXQuery",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "analytics.mdxquery"
}
}

}
