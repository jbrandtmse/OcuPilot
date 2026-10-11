/// <p>The Doc DB application editor: one record, created or edited here, rendered by its own <code>form-page</code>
/// (AD-5, Story 18.30). Its Save and the agent's confirmed <code>webapp.docdbapps.create</code> and
/// <code>webapp.docdbapps.update</code> are two callers of one tool each (AD-55).</p>
/// <p><b>It takes no side-bar position</b> (<code>sideBarPosition</code> 0): it is reached from
/// <class>OcuPilot.Screen.Descriptor.DocDbAppList</class>'s Create and a row's name cell, at that list's route with
/// <code>/edit</code> appended. It declares no <code>read</code>: its form read is <code>GET
/// /docdb-application/form</code> (<class>OcuPilot.Area.WebApp.DocDbAppRules</class>).</p>
/// <p><b>Its pairs are the list's own</b>, which hold for every operation (AD-8). Its classic key is the classic
/// Doc DB editor (AD-44).</p>
Class OcuPilot.Screen.Descriptor.DocDbAppForm Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "web-applications/docdb-applications/edit",
  "area": "web-applications",
  "labelKey": "aboutDocDbApplication",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "docdb-application",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Namespace", "Name"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": []},
  "secretArguments": [],
  "fingerprintExcludes": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "docDbAppFormPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "docDbAppFormPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "docDbAppFormPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.Applications.DocDB",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "webapp.docdbappform"
}
}

}
