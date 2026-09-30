/// <p>A fixture descriptor for a narrower os-management screen: one that needs
/// <code>%Admin_Operate:USE</code> and <code>%DB_IRISSYS:READ</code> and <b>not</b>
/// <code>%Admin_Manage:USE</code> (DW-275), as Locks and System usage do.</p>
/// <p><b>What it exists to hold.</b> The os-management area declares the union of its screens'
/// pairs, which includes <class>OcuPilot.Screen.Descriptor.ProcessList</class>'s three. A narrower
/// screen inside that area is sound -- <method>OcuPilot.Screen.Registry.AreaCoverageProblem</method>
/// checks containment, so an area that declares more than a screen requires passes, and the area
/// opens for a holder of any listed screen's pairs (<method>OcuPilot.Screen.Gate.EvaluateArea</method>,
/// AD-8), so the union costs such a holder nothing.</p>
/// <p><b>It is a fixture, not a screen.</b> It sits under <code>OcuPilot.Test.</code>, so
/// <method>OcuPilot.Screen.Registry.Descriptors</method> -- which reads the
/// <code>OcuPilot.Screen.Descriptor.</code> package -- never lists it, the mirror's own glob over
/// that folder never reads it, and no route, navigation entry or tool comes from it.
/// <code>built: false</code> says the same thing a second way.</p>
Class OcuPilot.Test.NarrowArea Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/narrow-probe",
  "area": "os-management",
  "labelKey": "navAreaOsManagement",
  "sideBarPosition": 9,
  "archetype": "list",
  "built": false,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "process",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": []},
  "emptyStateKey": "processListEmpty",
  "commandAliases": [],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "osmgmt.narrowprobe"
}
}

}
