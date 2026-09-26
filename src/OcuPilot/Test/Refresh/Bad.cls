/// <p>Fixture descriptor declaring rates on a screen that does not refresh, so the registry's
/// refusal (AD-43) can be demonstrated over a real roster rather than only over values.</p>
/// <p>It lives in a package of its own, with its own registry, for the reason
/// <class>OcuPilot.Test.Scope.Bad</class> does: <method>OcuPilot.Screen.Registry.Validate</method>
/// reports the first problem it meets, so two malformed fixtures in one package would race and
/// each test would stop pinning the refusal it names. The other malformed shapes -- a rate of
/// zero, a fraction, a repeat, a descent -- are exercised as values through
/// <method>OcuPilot.Screen.Registry.RefreshProblem</method>, which is why they need no fixture
/// each.</p>
Class OcuPilot.Test.Refresh.Bad Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/unrefreshing",
  "area": "os-management",
  "labelKey": "navAreaOsManagement",
  "sideBarPosition": 1,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [10],
  "privileges": [],
  "entityType": "process",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "context": {"fields": [], "secretFields": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "suggestedPrompts": [{"groupKey": "promptGroupTroubleshooting", "textKey": "homeStarterPromptExplainScreen"}, {"groupKey": "promptGroupTroubleshooting", "textKey": "homeStarterPromptExplainLog"}, {"groupKey": "promptGroupTroubleshooting", "textKey": "homeStarterPromptChangeOneThing"}],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": ""},
  "toolIdentifier": "test.badrefresh"
}
}

}
