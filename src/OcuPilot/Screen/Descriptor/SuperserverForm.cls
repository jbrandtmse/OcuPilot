/// <p>The superserver editor: one superserver, created or edited here, rendered by its own
/// <code>form-page</code> (AD-5, Story 18.25). Its Save and the agent's confirmed
/// <code>security.superservers.create</code> and <code>security.superservers.update</code> are two callers of
/// one tool each (AD-55).</p>
/// <p><b>It takes no side-bar position</b> (<code>sideBarPosition</code> 0): it is reached from
/// <class>OcuPilot.Screen.Descriptor.SuperserverList</class>'s Create and a row's port cell, at that list's
/// route with <code>/edit</code> appended. It declares no <code>read</code>: its form read is
/// <code>GET /superserver/form</code> (<class>OcuPilot.Area.Security.SuperserverRules</class>), which also
/// answers whether the superserver is the one OcuPilot is served through.</p>
/// <p><b>Its pairs are the list's own</b>, which hold for every operation (AD-8). Its classic key is the
/// classic superserver editor (AD-44).</p>
Class OcuPilot.Screen.Descriptor.SuperserverForm Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/superservers/edit",
  "area": "security",
  "labelKey": "aboutSuperserver",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "superserver",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Port", "BindAddress"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": []},
  "secretArguments": [],
  "fingerprintExcludes": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "superserverFormPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "superserverFormPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "superserverFormPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.Server",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "security.superserverform"
}
}

}
