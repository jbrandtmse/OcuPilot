/// <p>Fixture descriptor: a built sub-resource whose <code>parentScope</code> resolves cleanly to
/// <class>OcuPilot.Test.ParentScope.Sound.Parent</class> (Story 6.6, DW-1020) -- the positive
/// control proving the same roster that refuses a bad case validates a good one.</p>
Class OcuPilot.Test.ParentScope.Sound.Child Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "parent-scope/sound/child",
  "area": "security",
  "labelKey": "navAreaSecurity",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}],
  "entityType": "ssl-configuration",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "parent-scope/sound/parent",
  "id": {"kind": "single", "parts": []},
  "context": {"fields": ["name"], "secretFields": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": ""},
  "toolIdentifier": "security.parentscopesoundchild"
}
}

}
