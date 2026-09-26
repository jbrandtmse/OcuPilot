/// <p>Fixture descriptor declaring a <code>classicLinkExemption</code> on a <code>list</code>
/// archetype, so the registry's refusal (AD-44) can be demonstrated over a real roster rather
/// than only over values. A list screen never links out, and this is the declaration that says
/// otherwise.</p>
/// <p>It lives in a package of its own, with its own registry, for the reason
/// <class>OcuPilot.Test.Refresh.Bad</class> does:
/// <method>OcuPilot.Screen.Registry.Validate</method> reports the first problem it meets, so two
/// malformed fixtures in one package would race and each test would stop pinning the refusal it
/// names. The other malformed shapes -- an archetype outside the vocabulary, a missing reason,
/// label or href, an off-origin href, link parts without an exemption, an exemption with no
/// classic equivalent -- are exercised as values through
/// <method>OcuPilot.Screen.Registry.ClassicLinkProblem</method>, which is why they need no
/// fixture each.</p>
Class OcuPilot.Test.ClassicLink.Bad Extends OcuPilot.Screen.Descriptor.Base
{

/// <p>The archetype this fixture declares. Named so the test asserts the refusal quotes this
/// rather than a second copy of the string.</p>
Parameter BADARCHETYPE = "list";

XData Declaration
{
{
  "route": "permissions/linking-list",
  "area": "permissions",
  "labelKey": "navAreaPermissions",
  "sideBarPosition": 1,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [],
  "entityType": "user",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "context": {"fields": [], "secretFields": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "suggestedPrompts": [{"groupKey": "promptGroupTroubleshooting", "textKey": "homeStarterPromptExplainScreen"}, {"groupKey": "promptGroupTroubleshooting", "textKey": "homeStarterPromptExplainLog"}, {"groupKey": "promptGroupTroubleshooting", "textKey": "homeStarterPromptChangeOneThing"}],
  "classicPage": "OcuPilotTestClassicPageBad",
  "classicLinkExemption": {"exempt": true, "reason": "a list screen claiming the exemption only a detail view may hold", "label": "OcuPilot test classic page (Bad)", "href": "/csp/sys/OcuPilotTestClassicPageBad.csp"},
  "toolIdentifier": "test.badclassiclink"
}
}

}
