/// <p>Fixture descriptor: the <b>multi-entity</b> form (AD-5). One screen administering three
/// OAuth 2.0 entity types together, which a single-entity descriptor cannot express -- the
/// primary drives the route and the change-event key, and the two secondaries are declared and
/// participate in AD-14 routing.</p>
/// <p>It also carries the one <code>classicLinkExemption</code> shape AD-44 permits, with its
/// reason, so the exemption field has a declaration to be read from before Story 1.15's check
/// needs one.</p>
/// <p>Its classic page names no class this instance defines, deliberately: the lookup resolves
/// to <code>""</code> and adds nothing, so no fixture can depend on a real operator assignment
/// and no test ever writes one.</p>
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
  "rowActions": [{"id": "edit", "selfProtection": ""}, {"id": "delete", "selfProtection": "never OcuPilot's own registration"}],
  "emptyStateKey": "",
  "commandAliases": ["oauth", "oauth2"],
  "classicPage": "OcuPilotTestClassicPageMulti",
  "classicLinkExemption": {"exempt": true, "reason": "the OAuth 2.0 tabs are a detail archetype and have no rebuilt equivalent yet"},
  "toolIdentifier": "security.oauth"
}
}

}
