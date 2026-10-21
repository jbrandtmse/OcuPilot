/// <p>Analytics' User Portal link: a listed screen of archetype <code>external</code> that opens the User Portal, the dashboard home, in a new tab, in
/// the namespace the shell is scoped to (AD-5, AD-47, AD-65, Story 20.32). OcuPilot loads, frames and draws nothing of the vendor
/// page.</p>
/// <p><b>The address is the instance's.</b> The navigation map carries it as the screen's <code>href</code>, composed by
/// <method>OcuPilot.Screen.ExternalPage.Href</method> from this screen's tool identifier, when the Analytics area applies in the
/// namespace; the side bar and the command box open it in a new tab with no opener, and the screen's own route shows the
/// classic-link card (or why the page cannot open). It declares no read, table, action, tab or id, and it does not refresh
/// (AD-43).</p>
/// <p><b>Its pairs</b> are the Analytics menu's alone, <code>%DeepSee_Portal:USE</code> (AD-8), the one pair the area declares, so every caller who opens Analytics opens this link.</p>
/// <p><b>It replaces</b> the classic page <code>%DeepSee.UserPortal.Home</code> (AD-44), declared as the class name
/// <method>OcuPilot.Screen.ExternalPage.ClassicPage</method> names for this identifier, never as a URL.</p>
Class OcuPilot.Screen.Descriptor.AnalyticsUserPortalLink Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "analytics/user-portal",
  "area": "analytics",
  "labelKey": "analyticsUserPortalLabel",
  "sideBarPosition": 6,
  "archetype": "external",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%DeepSee_Portal", "permission": "USE"}],
  "entityType": "",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": []},
  "emptyStateKey": "",
  "commandAliases": ["user portal", "dashboards", "deepsee portal"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsUserPortalPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsUserPortalPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsUserPortalPrompt3"}
  ],
  "classicPage": "%DeepSee.UserPortal.Home",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "analytics.userportal"
}
}

}
