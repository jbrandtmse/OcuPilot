/// <p>Fixture descriptor: the <b>refreshing</b> form (AD-43), carrying the shapes the production
/// roster does not: a <code>namespace</code>-scoped refreshing screen and a declared row action.
/// Processes is the first of the six screens <file>EXPERIENCE.md</file> "**Auto-refresh controls.** On Processes" names, which is why
/// this fixture wears its route.</p>
/// <p><b>It is not the shipped processes list, and never rosters with it.</b> Since Story 2.9
/// <class>OcuPilot.Screen.Descriptor.ProcessList</class> declares that route and that tool
/// identifier for real; this class is reached only through the fixture registries, which override
/// <method>DescriptorPackage</method>, so the two never meet in one roster and neither shadows the
/// other. Nothing here is a model for the shipped screen: this declaration is
/// <code>namespace</code>-scoped where the real one is <code>instance</code>-scoped, and it carries
/// a <code>terminate</code> row action that Epic 2 ships no write path for at all.</p>
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
