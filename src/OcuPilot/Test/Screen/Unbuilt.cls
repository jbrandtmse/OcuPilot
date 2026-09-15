/// <p>Fixture descriptor for a screen that is declared and <b>not yet built</b>. Every screen
/// in Epics 2 to 22 is in this state for a while, and the rule is that it appears in no side
/// bar and gets no route -- "a screen that is not yet built does not appear in the side-bar"
/// (<file>EXPERIENCE.md</file> "Entries in daily-use order."). Its area is the same as
/// <class>OcuPilot.Test.Screen.Composite</class>'s, so the built filter has something to
/// exclude from a list that is not empty either way.</p>
Class OcuPilot.Test.Screen.Unbuilt Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "web-applications/rest-explorer",
  "area": "web-applications",
  "labelKey": "navAreaWebApplications",
  "sideBarPosition": 2,
  "archetype": "list",
  "built": false,
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}],
  "entityType": "rest-service",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "context": {"fields": ["name"], "secretFields": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "emptyStateKey": "",
  "commandAliases": ["rest"],
  "classicPage": "OcuPilotTestClassicPageUnbuilt",
  "classicLinkExemption": {"exempt": false, "reason": ""},
  "toolIdentifier": "webapp.rest"
}
}

}
