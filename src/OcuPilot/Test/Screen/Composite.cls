/// <p>Fixture descriptor: the <b>composite id</b> form (AD-5, AD-13). A web application's
/// natural key has parts, and a composite id is still <b>one</b> path segment -- the descriptor
/// names the parts and the one shared codec joins them, so a slice never invents a second
/// composite grammar.</p>
/// <p>Its tool identifier is deliberately unlike its route and its label, which is what
/// <class>OcuPilot.Test.Descriptor</class> asserts: renaming a screen must not silently orphan
/// its write tools or their governance keys.</p>
Class OcuPilot.Test.Screen.Composite Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "web-applications/applications",
  "area": "web-applications",
  "labelKey": "navAreaWebApplications",
  "sideBarPosition": 1,
  "archetype": "list",
  "built": true,
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}],
  "entityType": "web-application",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["namespace", "name"]},
  "context": {"fields": ["name", "namespace", "enabled"], "secretFields": []},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [{"id": "disable", "selfProtection": "serves-ocupilot"}],
  "emptyStateKey": "",
  "commandAliases": ["web apps", "applications"],
  "suggestedPrompts": [{"groupKey": "promptGroupTroubleshooting", "textKey": "homeStarterPromptExplainScreen"}, {"groupKey": "promptGroupTroubleshooting", "textKey": "homeStarterPromptExplainLog"}, {"groupKey": "promptGroupTroubleshooting", "textKey": "homeStarterPromptChangeOneThing"}],
  "classicPage": "OcuPilotTestClassicPageComposite",
  "classicLinkExemption": {"exempt": false, "reason": ""},
  "toolIdentifier": "webapp.list"
}
}

}
