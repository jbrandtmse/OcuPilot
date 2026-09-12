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
/// <p>No entity type: Home administers nothing, so it has no change-event key, no id accessor
/// and no read tool. The classic page it replaces is <code>%CSP.Portal.Home</code>, spelled in
/// the class's own case because the custom-resource lookup does not case-fold
/// (<class>OcuPilot.Screen.Gate</class>).</p>
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
  "privileges": [],
  "entityType": "",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "context": {"fields": [], "secretFields": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "emptyStateKey": "",
  "commandAliases": ["home", "start"],
  "classicPage": "%CSP.Portal.Home",
  "classicLinkExemption": {"exempt": false, "reason": ""},
  "toolIdentifier": "shell.home"
}
}

}
