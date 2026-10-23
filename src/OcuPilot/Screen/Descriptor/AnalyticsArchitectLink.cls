/// <p>Analytics' Architect link: a listed screen of archetype <code>external</code> that opens Architect, the cube designer, in a new tab, in
/// the namespace the shell is scoped to (AD-5, AD-47, AD-65, Story 20.32). OcuPilot loads, frames and draws nothing of the vendor
/// page.</p>
/// <p><b>The address is the instance's.</b> The navigation map carries it as the screen's <code>href</code>, composed by
/// <method>OcuPilot.Screen.ExternalPage.Href</method> from this screen's tool identifier, when the Analytics area applies in the
/// namespace; the side bar and the command box open it in a new tab with no opener, and the screen's own route shows the
/// classic-link card (or why the page cannot open). It declares no read, table, action, tab or id, and it does not refresh
/// (AD-43).</p>
/// <p><b>Its pairs</b> are the Analytics menu's and, as its own, <code>%DeepSee_Architect:USE</code>, a named narrower audience than the page's any-of <code>RESOURCE</code> (AD-8), so a holder of the area's pair without it keeps the other Analytics screens and this one is drawn unavailable, naming it.</p>
/// <p><b>It replaces</b> the classic page <code>%DeepSee.UI.Architect</code> (AD-44), declared as the class name
/// <method>OcuPilot.Screen.ExternalPage.ClassicPage</method> names for this identifier, never as a URL.</p>
Class OcuPilot.Screen.Descriptor.AnalyticsArchitectLink Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "analytics/architect",
  "area": "analytics",
  "labelKey": "analyticsArchitectLabel",
  "sideBarPosition": 4,
  "archetype": "external",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%DeepSee_Portal", "permission": "USE"}, {"resource": "%DeepSee_Architect", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%DeepSee_Architect", "permission": "USE"}],
  "entityType": "",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": []},
  "emptyStateKey": "",
  "commandAliases": ["architect", "cube designer", "deepsee architect"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsArchitectPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsArchitectPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsArchitectPrompt3"}
  ],
  "classicPage": "%DeepSee.UI.Architect",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "analytics.architect"
}
}

}
