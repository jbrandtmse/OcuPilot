/// <p>Fixture descriptor: a built sub-resource whose <code>parentScope</code> names a route no
/// descriptor in this package declares at all (Story 6.6, DW-1020). Exercises
/// <method>OcuPilot.Screen.Registry.ParentScopeResolutionProblem</method>'s "not found" branch,
/// isolated in its own package with <class>OcuPilot.Test.ParentScopeNotFoundRegistry</class> so
/// no other fixture's fault is reported first.</p>
Class OcuPilot.Test.ParentScope.NotFound.Child Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "parent-scope/not-found/child",
  "area": "security",
  "labelKey": "navAreaSecurity",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}],
  "entityType": "ssl-configuration",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "parent-scope/not-found/nonexistent",
  "id": {"kind": "single", "parts": []},
  "context": {"fields": ["name"], "secretFields": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "suggestedPrompts": [{"groupKey": "promptGroupTroubleshooting", "textKey": "homeStarterPromptExplainScreen"}, {"groupKey": "promptGroupTroubleshooting", "textKey": "homeStarterPromptExplainLog"}, {"groupKey": "promptGroupTroubleshooting", "textKey": "homeStarterPromptChangeOneThing"}],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": ""},
  "toolIdentifier": "security.parentscopenotfoundchild"
}
}

}
