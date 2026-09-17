/// <p>Fixture descriptor: a built sub-resource whose <code>parentScope</code> names
/// <class>OcuPilot.Test.ParentScope.NoId.Parent</class>'s route, which is declared and built but
/// carries <code>id.kind</code> <code>none</code> (Story 6.6, DW-1020). Exercises
/// <method>OcuPilot.Screen.Registry.ParentScopeResolutionProblem</method>'s "found and built but
/// no id" branch.</p>
Class OcuPilot.Test.ParentScope.NoId.Child Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "parent-scope/no-id/child",
  "area": "security",
  "labelKey": "navAreaSecurity",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}],
  "entityType": "ssl-configuration",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "parent-scope/no-id/parent",
  "id": {"kind": "single", "parts": []},
  "context": {"fields": ["name"], "secretFields": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": ""},
  "toolIdentifier": "security.parentscopenoidchild"
}
}

}
