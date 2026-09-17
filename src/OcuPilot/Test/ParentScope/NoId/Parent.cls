/// <p>Fixture descriptor: a built screen at the route
/// <class>OcuPilot.Test.ParentScope.NoId.Child</class> names as its <code>parentScope</code>
/// (Story 6.6, DW-1020), declaring <code>id.kind</code> <code>none</code> -- a route with
/// nothing to identify resolves no entity for a child's id to name.</p>
Class OcuPilot.Test.ParentScope.NoId.Parent Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "parent-scope/no-id/parent",
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
  "id": {"kind": "none", "parts": []},
  "context": {"fields": ["name"], "secretFields": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": ""},
  "toolIdentifier": "security.parentscopenoidparent"
}
}

}
