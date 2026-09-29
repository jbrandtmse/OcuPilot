/// <p>The local database editor and wizard: one database configuration, created by a three-step
/// wizard or edited here, rendered by the <code>form-page</code> archetype (AD-5). Its Saves and the
/// agent's confirmed <code>osmgmt.localdatabases.create</code>,
/// <code>osmgmt.localdatabases.updatemount</code> and <code>osmgmt.localdatabases.update</code> are two
/// callers of one tool each (AD-55).</p>
/// <p>It takes no side-bar position: it is reached from
/// <class>OcuPilot.Screen.Descriptor.LocalDatabaseList</class>'s Create and from a row's name cell,
/// with the database's name as its one id segment when it edits. It declares no <code>read</code>;
/// its form read answers the configuration and the file it edits, and its volume files section issues
/// <class>OcuPilot.Screen.Descriptor.DatabaseVolumeList</class>'s declared read (AD-5).</p>
/// <p><b>Its privilege set is the list's own</b>, so a caller who can read the databases can open the
/// form (AD-8). Saving needs the pairs the database tools declare, which
/// <class>OcuPilot.Area.OsMgmt.DatabaseSave</class> asks before anything is sent.</p>
/// <p><b>Its classic equivalent is <code>%CSP.UI.Portal.Database</code></b> (AD-44). It declares no
/// exemption and does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.LocalDatabaseForm Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/local-databases/edit",
  "area": "os-management",
  "labelKey": "systemInfoDatabase",
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
    {"groupKey": "promptGroupGettingStarted", "textKey": "localDatabaseFormPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "databaseDetailsPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "localDatabaseFormPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.Database",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "osmgmt.localdatabaseform"
}
}

}
