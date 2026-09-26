/// <p>Fixture descriptor: the <b>honored exemption</b> on the archetype AD-44 names literally.
/// <class>OcuPilot.Test.Screen.Multi</class> exercises the same shape on <code>form-page</code>,
/// which <class>OcuPilot.Screen.Archetype</class> classifies <code>detail</code>; this declares
/// <code>detail</code> itself, so the honored path is pinned on the word the rule uses and not
/// only on one of the three archetypes that map onto it.</p>
/// <p>Its classic page names no class this instance defines and its href names no page this
/// instance serves, for the reason <class>OcuPilot.Test.Screen.Multi</class> records.</p>
Class OcuPilot.Test.Screen.Detail Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/ssl/detail",
  "area": "security",
  "labelKey": "navAreaSecurity",
  "sideBarPosition": 3,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}],
  "entityType": "ssl-configuration",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "security/ssl",
  "id": {"kind": "single", "parts": []},
  "context": {"fields": ["name", "enabled"], "secretFields": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "emptyStateKey": "",
  "commandAliases": ["ssl detail"],
  "suggestedPrompts": [{"groupKey": "promptGroupTroubleshooting", "textKey": "homeStarterPromptExplainScreen"}, {"groupKey": "promptGroupTroubleshooting", "textKey": "homeStarterPromptExplainLog"}, {"groupKey": "promptGroupTroubleshooting", "textKey": "homeStarterPromptChangeOneThing"}],
  "classicPage": "OcuPilotTestClassicPageDetail",
  "classicLinkExemption": {"exempt": true, "reason": "a detail view with no rebuilt equivalent yet, which is the one shape AD-44 permits", "label": "OcuPilot test classic page (Detail)", "href": "/csp/sys/OcuPilotTestClassicPageDetail.csp"},
  "toolIdentifier": "security.ssl.detail"
}
}

}
