/// <p>The remote database form: one remote database configuration, created or re-pointed here,
/// rendered by the <code>form-page</code> archetype (AD-5). Its Saves and the agent's confirmed
/// <code>osmgmt.remotedatabases.create</code> and <code>osmgmt.remotedatabases.update</code> are two
/// callers of one tool each (AD-55).</p>
/// <p>It takes no side-bar position: it is reached from
/// <class>OcuPilot.Screen.Descriptor.RemoteDatabaseList</class>'s Create and from a row's name cell,
/// with the database's name as its one id segment when it edits. It declares no <code>read</code>;
/// its form read answers the configuration and the instance's data servers, and choosing a data
/// server lists its databases through the bounded listing (AD-21's seventh case).</p>
/// <p><b>Its privilege set is the list's own</b>, so a caller who can read the remote databases can
/// open the form (AD-8). Saving needs the pair the remote database tools declare, which
/// <class>OcuPilot.Area.OsMgmt.RemoteDatabaseSave</class> asks before anything is sent.</p>
/// <p><b>Its classic equivalent is <code>%CSP.UI.Portal.Dialog.RemoteDatabase</code></b> (AD-44). It
/// declares no exemption and does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.RemoteDatabaseForm Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/remote-databases/edit",
  "area": "os-management",
  "labelKey": "remoteDatabaseFormLabel",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "database-configuration",
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
    {"groupKey": "promptGroupGettingStarted", "textKey": "remoteDatabaseFormPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "remoteDatabaseFormPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "remoteDatabaseFormPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.Dialog.RemoteDatabase",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "osmgmt.remotedatabaseform"
}
}

}
