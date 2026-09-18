/// <p>Fixture descriptor: an <b>unbuilt</b> screen at the route
/// <class>OcuPilot.Test.ParentScope.NotBuilt.Child</class> names as its <code>parentScope</code>
/// (Story 6.6, DW-1020). Its own <code>id.kind</code> is a resolving <code>single</code>, so the
/// only reason it fails as a parent is <code>built</code> being <code>false</code>.</p>
Class OcuPilot.Test.ParentScope.NotBuilt.Parent Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "parent-scope/not-built/parent",
  "area": "security",
  "labelKey": "navAreaSecurity",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": false,
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
  "toolIdentifier": "security.parentscopenotbuiltparent"
}
}

}
