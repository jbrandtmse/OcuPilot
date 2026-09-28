/// <p>The namespace editor: one namespace, created or edited here, rendered by the
/// <code>form-page</code> archetype (AD-5). Its Save and the agent's confirmed
/// <code>osmgmt.namespaces.create</code> and <code>osmgmt.namespaces.update</code> are two callers of
/// one tool each (AD-55).</p>
/// <p>It takes no side-bar position: it is reached from
/// <class>OcuPilot.Screen.Descriptor.NamespaceList</class>'s Create and from a row's name cell, with
/// the namespace's name as its one id segment when it edits. It declares no <code>read</code>; its
/// form read answers the namespace it edits.</p>
/// <p><b>Its privilege set is the list's own</b>, so a caller who can read the namespaces can open
/// the form (AD-8). Saving needs <code>%DB_IRISSYS:WRITE</code> as well, which the namespace tools
/// declare and <class>OcuPilot.Area.OsMgmt.NamespaceSave</class> asks before anything is sent.</p>
/// <p><b>Its classic equivalent is <code>%CSP.UI.Portal.NamespaceEdit</code></b> (AD-44). It declares
/// no exemption and does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.NamespaceForm Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/namespaces/edit",
  "area": "os-management",
  "labelKey": "headerNamespaceLabel",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "namespace",
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
    {"groupKey": "promptGroupGettingStarted", "textKey": "namespaceFormPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "namespaceFormPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "namespaceFormPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.NamespaceEdit",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "osmgmt.namespaceform"
}
}

}
