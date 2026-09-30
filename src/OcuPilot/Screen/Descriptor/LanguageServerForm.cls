/// <p>The external language server editor (Story 16.25): one server, created or edited here, rendered
/// by the <code>form-page</code> archetype (AD-5). Its Save and the agent's confirmed
/// <code>osmgmt.languageservers.create</code> and <code>osmgmt.languageservers.update</code> are two
/// callers of one tool each (AD-55).</p>
/// <p>It takes no side-bar position: it is reached from
/// <class>OcuPilot.Screen.Descriptor.LanguageServerList</class>'s Create and from a row's name cell,
/// with the server's name as its one id segment when it edits. It declares no <code>read</code>; its
/// form read answers the server it edits, with its running state, and the editor links the server's
/// Activity log.</p>
/// <p><b>Its privilege set is the list's own</b>, the own pair included, so a caller who can read the
/// servers can open the form (AD-8). Saving needs <code>%Admin_Manage:USE</code> and
/// <code>%DB_IRISSYS:WRITE</code> as well, which the tools declare and
/// <class>OcuPilot.Area.OsMgmt.LanguageServerSave</class> asks before anything is sent.</p>
/// <p><b>Its classic equivalent is <code>%CSP.UI.Portal.ExternalLanguageServer</code></b> (AD-44). It
/// declares no exemption and does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.LanguageServerForm Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/language-servers/edit",
  "area": "os-management",
  "labelKey": "languageServerFormLabel",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_ExternalLanguageServerEdit", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Admin_ExternalLanguageServerEdit", "permission": "USE"}],
  "entityType": "language-server",
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
    {"groupKey": "promptGroupGettingStarted", "textKey": "languageServerFormPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "languageServerFormPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "languageServerFormPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.ExternalLanguageServer",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "osmgmt.languageserverform"
}
}

}
