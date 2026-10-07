/// <p>The managed file transfer connection editor: one connection, created or edited here, rendered by its own
/// <code>form-page</code> (AD-5, Story 18.26). Its Save and the agent's confirmed
/// <code>security.mftconnections.create</code> and <code>security.mftconnections.update</code> are two callers of
/// one tool each (AD-55).</p>
/// <p><b>It takes no side-bar position</b> (<code>sideBarPosition</code> 0): it is reached from
/// <class>OcuPilot.Screen.Descriptor.MftConnectionList</class>'s Create and a row's name cell, at that list's
/// route with <code>/edit</code> appended. It declares no <code>read</code>: its form read is
/// <code>GET /mft-connection/form</code> (<class>OcuPilot.Area.Security.MftConnectionRules</class>).</p>
/// <p><b>Its pairs are the list's own</b>, which hold for every operation (AD-8). Its classic key is the classic
/// connection editor (AD-44).</p>
Class OcuPilot.Screen.Descriptor.MftConnectionForm Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/mft-connections/edit",
  "area": "security",
  "labelKey": "aboutMftConnection",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "mft-connection",
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
    {"groupKey": "promptGroupGettingStarted", "textKey": "mftConnectionFormPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "mftConnectionFormPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "mftConnectionFormPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.MFT.Connection",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "security.mftconnectionform"
}
}

}
