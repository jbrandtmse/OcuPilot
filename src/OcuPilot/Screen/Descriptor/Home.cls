/// <p>Home's declaration -- the one real screen descriptor Epic 1 authors. The page behind it
/// is Story 1.12's; this is the route, the navigation entry and the gate that page will
/// arrive into.</p>
/// <p><b>Its route is the empty string</b>, which the route-table adapter emits as the
/// application root. Home is reached from the rail's Home item, from the logo lockup and
/// straight after sign-in (<file>EXPERIENCE.md</file> Surfaces), all three of which mean
/// <code>/ocupilot/</code>; it is the one screen not spelled
/// <code>/&lt;area&gt;/&lt;screen&gt;</code>.</p>
/// <p><b>It never gates.</b> Its privilege set is empty and its area's is too, so every
/// signed-in caller reaches it -- which is what keeps the rail's one navigating item working
/// for a caller who holds a single administrative resource.</p>
/// <p><b>It refreshes, and it is the one screen whose default rate is not off</b> (AD-43).
/// EXPERIENCE.md's Auto-refresh controls roster names it; a tick re-reads only its performance row
/// (<code>GET /ui/performance</code>, Story 16.18), every 10 s until the person sets another rate or
/// turns it off. That choice is remembered under the name <code>home</code>, because its route is
/// empty.</p>
/// <p><b>Its context carries the performance row</b> (AD-24): <code>context.fields</code> are the
/// row's five values, and the one row the page publishes into its store is what a turn's screen
/// context sends. A caller who may not read the metrics publishes no row.</p>
/// <p>No entity type: Home administers nothing, so it has no change-event key, no id accessor
/// and no read tool. The classic page it replaces is <code>%CSP.Portal.Home</code>, spelled in
/// the class's own case because the custom-resource lookup does not case-fold
/// (<class>OcuPilot.Screen.Gate</class>).</p>
/// <p><b>It links out to nothing.</b> Its archetype is <code>home</code>, which
/// <class>OcuPilot.Screen.Archetype</class> classifies <code>none</code>, so the exemption is
/// declared false with no reason, label or href -- the four link-out facts stated together
/// rather than left to be read as absent (AD-44).</p>
Class OcuPilot.Screen.Descriptor.Home Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "",
  "area": "home",
  "labelKey": "navAreaHome",
  "sideBarPosition": 1,
  "archetype": "home",
  "built": true,
  "refreshes": true,
  "refreshRates": [5, 10, 30, 60],
  "refreshDefault": 10,
  "privileges": [],
  "entityType": "",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "context": {"fields": ["cacheEfficiency", "globalReferencesPerSecond", "globalUpdatesPerSecond", "diskReadsPerSecond", "diskWritesPerSecond"], "secretFields": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "emptyStateKey": "",
  "commandAliases": ["home", "start"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "homeStarterPromptExplainScreen"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "homeStarterPromptExplainLog"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "homeStarterPromptChangeOneThing"}
  ],
  "classicPage": "%CSP.Portal.Home",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "shell.home"
}
}

}
