/// <p>Fixture descriptor: the <b>refreshing</b> form (AD-43). The production roster's one screen
/// is Home, which does not refresh, so a sound declaration of the refresh pair has no subject
/// there. Processes is one of the six screens <file>EXPERIENCE.md</file> `:561` names, which is
/// why this fixture wears its route.</p>
/// <p>One rate, not four: Release 1 publishes chip copy for <code>10 s</code> and nothing else,
/// so a second rate could not be rendered without inventing a literal (DW-126). The mechanism
/// takes a list; the list has one entry until the copy lands.</p>
Class OcuPilot.Test.Screen.Refreshing Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/processes",
  "area": "os-management",
  "labelKey": "navAreaOsManagement",
  "sideBarPosition": 1,
  "archetype": "list",
  "built": true,
  "refreshes": true,
  "refreshRates": [10],
  "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}],
  "entityType": "process",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "context": {"fields": ["pid", "user", "routine"], "secretFields": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "terminate", "selfProtection": "never an IRIS system process"}],
  "emptyStateKey": "",
  "commandAliases": ["processes"],
  "classicPage": "OcuPilotTestClassicPageRefreshing",
  "classicLinkExemption": {"exempt": false, "reason": ""},
  "toolIdentifier": "osmgmt.processes"
}
}

}
