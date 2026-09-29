/// <p>The routine mapping editor (Story 18.14): one mapping of one namespace, created or edited here,
/// rendered by the <code>form-page</code> archetype (AD-5). Its Save and the agent's confirmed
/// <code>osmgmt.routinemappings.create</code> and <code>osmgmt.routinemappings.update</code> are two
/// callers of one tool each (AD-55).</p>
/// <p>It takes no side-bar position: it is reached from
/// <class>OcuPilot.Screen.Descriptor.RoutineMappingList</class>'s Create, with the namespace as a query
/// parameter, and from a row's name cell, with the row's composite id <code>[namespace, Name]</code>
/// as its one id segment. It declares no <code>read</code>; its form read answers the mapping it
/// edits.</p>
/// <p><b>Its privilege set is the list's own</b> (AD-8). Saving needs <code>%DB_IRISSYS:WRITE</code>
/// as well, which the mapping tools declare and <class>OcuPilot.Area.OsMgmt.MappingSave</class> asks
/// before anything is sent.</p>
/// <p><b>Its classic equivalent is <code>%CSP.UI.Portal.Mappings.Routine</code></b> (AD-44), the classic
/// routine mapping dialog. It declares no exemption and does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.RoutineMappingForm Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/namespaces/routine-mappings/edit",
  "area": "os-management",
  "labelKey": "routineMappingFormLabel",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "routine-mapping",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["namespace", "Name"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": []},
  "secretArguments": [],
  "fingerprintExcludes": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "routineMappingFormPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "routineMappingFormPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "routineMappingFormPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.Mappings.Routine",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "osmgmt.routinemappingform"
}
}

}
