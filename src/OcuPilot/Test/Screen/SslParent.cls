/// <p>Fixture descriptor: a built, unlisted parent at <code>security/ssl</code>, the route
/// <class>OcuPilot.Test.Screen.Detail</class> already declared as its <code>parentScope</code>
/// before DW-1020 existed to check that the name resolves. Story 6.6's
/// <method>OcuPilot.Screen.Registry.ParentScopeResolutionProblem</method> refuses a built
/// sub-resource descriptor whose <code>parentScope</code> names no built descriptor with that
/// route and an id, so the fixture package needs one at the route Detail already names, rather
/// than Detail's own literal changing under a test that pins it elsewhere
/// (<method>OcuPilot.Test.Descriptor.TestADetailDescriptorDeclaresAnHonoredExemption</method> does
/// not name this class, but nothing else in the package answered that route until now).</p>
Class OcuPilot.Test.Screen.SslParent Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/ssl",
  "area": "security",
  "labelKey": "navAreaSecurity",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}],
  "entityType": "ssl-configuration",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "context": {"fields": ["name"], "secretFields": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": ""},
  "toolIdentifier": "security.sslparentfixture"
}
}

}
