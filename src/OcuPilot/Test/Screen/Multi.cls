/// <p>Fixture descriptor: the <b>multi-entity</b> form (AD-5). One screen administering three
/// OAuth 2.0 entity types together, which a single-entity descriptor cannot express -- the
/// primary drives the route and the change-event key, and the two secondaries are declared and
/// participate in AD-14 routing.</p>
/// <p>It also carries a complete <code>classicLinkExemption</code> -- the reason, the page name
/// the card's action is labelled with, and the root-relative href the card opens -- on
/// <code>form-page</code>, which <class>OcuPilot.Screen.Archetype</class> classifies
/// <code>detail</code> and may therefore link out (AD-44).</p>
/// <p>Its classic page names no class this instance defines, and its href names no page this
/// instance serves, deliberately: the resource lookup resolves to <code>""</code> and adds
/// nothing, so no fixture can depend on a real operator assignment and no test ever writes
/// one, and nothing here is a target any test is tempted to fetch.</p>
Class OcuPilot.Test.Screen.Multi Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/oauth",
  "area": "security",
  "labelKey": "navAreaSecurity",
  "sideBarPosition": 2,
  "archetype": "form-page",
  "built": true,
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}],
  "entityType": "oauth2-client-configuration",
  "secondaryEntityTypes": ["oauth2-server-definition", "oauth2-resource-server"],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "context": {"fields": ["name", "enabled"], "secretFields": ["clientSecret"]},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [{"id": "edit", "selfProtection": ""}, {"id": "delete", "selfProtection": ""}],
  "emptyStateKey": "",
  "commandAliases": ["oauth", "oauth2"],
  "classicPage": "OcuPilotTestClassicPageMulti",
  "classicLinkExemption": {"exempt": true, "reason": "a test detail view that keeps its classic page", "label": "OcuPilot test classic page (Multi)", "href": "/csp/sys/OcuPilotTestClassicPageMulti.csp"},
  "toolIdentifier": "security.oauth"
}
}

}
