/// <p>Fixture descriptor: a built screen whose <code>parentScope</code> names its own
/// <code>route</code> (Story 6.6, review pass 1, DW-1020). Its own <code>id.kind</code> is a
/// resolving <code>single</code>, so without self-exclusion
/// <method>OcuPilot.Screen.Registry.ParentScopeResolutionProblem</method> would find this entry
/// as its own resolving parent and pass it; the rule must exclude the entry being checked from
/// its own candidate search.</p>
Class OcuPilot.Test.ParentScope.Self.Child Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "parent-scope/self/child",
  "area": "security",
  "labelKey": "navAreaSecurity",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}],
  "entityType": "ssl-configuration",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "parent-scope/self/child",
  "id": {"kind": "single", "parts": []},
  "context": {"fields": ["name"], "secretFields": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "suggestedPrompts": [{"groupKey": "promptGroupTroubleshooting", "textKey": "homeStarterPromptExplainScreen"}, {"groupKey": "promptGroupTroubleshooting", "textKey": "homeStarterPromptExplainLog"}, {"groupKey": "promptGroupTroubleshooting", "textKey": "homeStarterPromptChangeOneThing"}],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": ""},
  "toolIdentifier": "security.parentscopeselfchild"
}
}

}
