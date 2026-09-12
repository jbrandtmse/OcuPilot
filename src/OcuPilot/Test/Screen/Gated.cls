/// <p>Fixture descriptor: a screen whose privilege set holds <b>two</b> pairs, which is the
/// shape AD-8 exists for -- the security APIs need <code>%DB_IRISSYS:READ</code> <i>and</i>
/// <code>%Admin_Secure:USE</code> together on 2026.2, and a descriptor field holding one
/// string cannot express it. The gate requires both and names whichever failed.</p>
/// <p>Its own set is not empty <b>and</b> it names a classic page, so
/// <class>OcuPilot.Test.Navigation</class> can exercise the union of the two on the same
/// descriptor.</p>
Class OcuPilot.Test.Screen.Gated Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "permissions/users",
  "area": "permissions",
  "labelKey": "navAreaPermissions",
  "sideBarPosition": 1,
  "archetype": "list",
  "built": true,
  "privileges": [{"resource": "%DB_IRISSYS", "permission": "READ"}, {"resource": "%Admin_Secure", "permission": "USE"}],
  "entityType": "user",
  "secondaryEntityTypes": ["role"],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "context": {"fields": ["name", "enabled"], "secretFields": ["password"]},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [{"id": "delete", "selfProtection": "never the current user"}],
  "emptyStateKey": "",
  "commandAliases": ["users"],
  "classicPage": "OcuPilotTestClassicPageGated",
  "classicLinkExemption": {"exempt": false, "reason": ""},
  "toolIdentifier": "permissions.users"
}
}

}
