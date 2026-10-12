/// <p>The privileged routine application editor: one application, created or edited here, rendered by its own
/// <code>form-page</code> (AD-5, Story 18.31). Its Save and the agent's confirmed
/// <code>webapp.routineapps.create</code> and <code>webapp.routineapps.update</code> are two callers of one tool each
/// (AD-55).</p>
/// <p><b>It takes no side-bar position</b> (<code>sideBarPosition</code> 0): it is reached from
/// <class>OcuPilot.Screen.Descriptor.RoutineAppList</class>'s Create and a row's name cell, at that list's route with
/// <code>/edit</code> appended. It declares no <code>read</code>: its form read is <code>GET
/// /routine-application/form</code> (<class>OcuPilot.Area.WebApp.RoutineAppRules</class>). It carries the General tab
/// of the classic editor: the name, the description, whether the application is enabled and its resource.</p>
/// <p><b>Its pairs are the list's own</b>, which hold for every operation (AD-8). Its classic key is the classic
/// editor (AD-44).</p>
Class OcuPilot.Screen.Descriptor.RoutineAppForm Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "web-applications/routine-applications/edit",
  "area": "web-applications",
  "labelKey": "aboutRoutineApplication",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "routine-application",
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
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "routineAppFormPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "routineAppFormPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "routineAppFormPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.Applications.PrivRoutine",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "webapp.routineappform"
}
}

}
