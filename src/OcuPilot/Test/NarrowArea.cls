/// <p>A fixture descriptor for the os-management screen Stories 6.8 and 6.10 will add: one that
/// needs <code>%Admin_Operate:USE</code> and <code>%DB_IRISSYS:READ</code> and <b>not</b>
/// <code>%Admin_Manage:USE</code> (DW-275).</p>
/// <p><b>What it exists to hold.</b> The os-management area declares the union of its screens'
/// pairs, which today is <class>OcuPilot.Screen.Descriptor.ProcessList</class>'s three. A narrower
/// screen inside that area is sound -- <method>OcuPilot.Screen.Registry.AreaCoverageProblem</method>
/// checks containment, so an area that declares more than a screen requires passes -- and the cost
/// is a false denial: an operator holding only the two pairs below sees the whole rail entry
/// denied on a pair this screen does not need.</p>
/// <p><b>What is observed, and what is derived.</b>
/// <method>OcuPilot.Test.WireSecurityRead.TestTheProcessesListsPairSetIsEnforcedForARealPrincipal</method>
/// observes the area denial itself: a real principal holding those two pairs is refused
/// <code>os-management</code>, named on <code>%Admin_Manage:USE</code>. That denial is a
/// <i>true</i> one today, because the only screen in the area needs that pair. That it becomes a
/// <b>false</b> denial once a screen like this one is built is an <b>(inference)</b> from this
/// class's own assertions -- the narrow screen validates and the area covers it -- and cannot be
/// observed until 6.8 or 6.10 lands a built one. This class holds that half.</p>
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
