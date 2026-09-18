/// <p>Fixture descriptor: a built sub-resource whose <code>parentScope</code> names
/// <class>OcuPilot.Test.ParentScope.NotBuilt.Parent</class>'s route, which is declared but not
/// built (Story 6.6, DW-1020). Exercises
/// <method>OcuPilot.Screen.Registry.ParentScopeResolutionProblem</method>'s "found but not
/// built" branch.</p>
Class OcuPilot.Test.ParentScope.NotBuilt.Child Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "parent-scope/not-built/child",
  "area": "security",
  "labelKey": "navAreaSecurity",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}],
  "entityType": "ssl-configuration",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "parent-scope/not-built/parent",
  "id": {"kind": "single", "parts": []},
  "context": {"fields": ["name"], "secretFields": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": ""},
  "toolIdentifier": "security.parentscopenotbuiltchild"
}
}

}
