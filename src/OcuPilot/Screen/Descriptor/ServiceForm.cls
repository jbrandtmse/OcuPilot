/// <p>The service editor: one service, edited at its id route as a tabbed <code>form-page</code>
/// (AD-5) whose tabs are the classic Edit Service dialog's groups -- General (whether it is
/// enabled), Authentication methods, and Allowed incoming connections with each address's roles --
/// each drawn only where the service has that group (Story 16.13). It links out to no classic page.
/// Its Save and the agent's confirmed <code>permissions.services.update</code> are two callers of one
/// tool (AD-55).</p>
/// <p><b>It is built and routable, and it takes no side-bar position</b> (<code>sideBarPosition</code>
/// 0): it is reached from <class>OcuPilot.Screen.Descriptor.ServiceList</class>'s name cell, at that
/// list's own route with <code>/edit</code> appended and the name as its one id segment. It never
/// creates.</p>
/// <p><b>It declares no <code>read</code> and no <code>table</code></b> (AD-36); its privilege set is
/// the list's own (AD-8). Its classic equivalent is <code>%CSP.UI.Portal.Dialog.Service</code>, in the
/// class's own case (AD-44). It does not refresh (AD-43), and its context carries no secret.</p>
Class OcuPilot.Screen.Descriptor.ServiceForm Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "permissions/services/edit",
  "area": "permissions",
  "labelKey": "serviceFormLabel",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "service",
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
    {"groupKey": "sslPromptGroupConnections", "textKey": "servicePromptWhoConnects"},
    {"groupKey": "sslPromptGroupConnections", "textKey": "servicePromptEnabled"},
    {"groupKey": "sslPromptGroupConnections", "textKey": "servicePromptUnauthenticated"}
  ],
  "classicPage": "%CSP.UI.Portal.Dialog.Service",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "permissions.serviceform"
}
}

}
