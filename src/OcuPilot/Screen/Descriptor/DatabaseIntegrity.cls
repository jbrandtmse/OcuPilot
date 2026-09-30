/// <p>Check integrity: the three-step flow (databases, globals, report) that checks one database or a
/// set of them, rendered by the <code>form-page</code> archetype (AD-5, Story 18.4). With the Integrity
/// log (<class>OcuPilot.Screen.Descriptor.DatabaseIntegrityLog</class>) it replaces the classic
/// <code>Dialog.Integ</code>, <code>Dialog.IntegOutput</code>, <code>Dialog.IntegLog</code> and
/// <code>Dialog.IntegLogContent</code>.</p>
/// <p>It takes no side-bar position: it is reached from the Databases list's Check integrity. It
/// declares no <code>read</code>: its Databases step issues the Databases list's declared read, and its
/// Report step the Integrity log's (AD-5). Its check is the Databases list's <code>integrity</code>
/// action (<class>OcuPilot.Screen.Tool.DatabaseIntegrityCheck</class>, AD-53), whose target is the
/// checked set of directories.</p>
/// <p><b>Its privilege set is the Databases list's own</b> (AD-8); the check needs the pairs its tool
/// declares. Its classic equivalent is <code>%CSP.UI.Portal.Dialog.Integ</code> (AD-44). It declares no
/// exemption and does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.DatabaseIntegrity Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/databases/integrity",
  "area": "os-management",
  "labelKey": "databaseIntegrityLabel",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "database",
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
  "commandAliases": ["check integrity", "integrity check"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "databaseIntegrityPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "databaseIntegrityPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "databaseIntegrityPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.Dialog.Integ",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "osmgmt.databaseintegrity"
}
}

}
