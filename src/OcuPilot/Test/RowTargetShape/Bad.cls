/// <p>Fixture descriptor whose <code>rowTarget</code> is outside the grammar, so the registry's
/// per-entry <code>rowTarget</code> refusal can be demonstrated through
/// <method>OcuPilot.Screen.Registry.Validate</method> rather than by calling
/// <method>OcuPilot.Screen.Registry.RowTargetProblem</method> on a value: its
/// <code>rowTarget.field</code> is not one of its <code>read.fields</code>. Everything else is a
/// sound <code>list</code> declaration, so the refusal <code>Validate</code> reports is the row
/// target's and nothing else's.</p>
/// <p>It lives in a package of its own, with
/// <class>OcuPilot.Test.RowTargetShapeRegistry</class>, so no other fixture's fault is reported
/// first.</p>
Class OcuPilot.Test.RowTargetShape.Bad Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/row-target-shape-bad",
  "area": "security",
  "labelKey": "navAreaSecurity",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "ssl-configuration",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Name"], "secretFields": []},
  "emptyStateKey": "oauthResourceServersEmpty",
  "commandAliases": [],
  "suggestedPrompts": [{"groupKey": "promptGroupTroubleshooting", "textKey": "homeStarterPromptExplainScreen"}, {"groupKey": "promptGroupTroubleshooting", "textKey": "homeStarterPromptExplainLog"}, {"groupKey": "promptGroupTroubleshooting", "textKey": "homeStarterPromptChangeOneThing"}],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Security.SSLConfigs", "type": "LIST"},
    "fields": ["Name"],
    "filter": ["Name"],
    "sort": {"fields": ["Name"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [{"field": "Name", "labelKey": "tableColumnName", "kind": "name"}],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "rowTarget": {"route": "security/ssl", "field": "Bogus"},
  "toolIdentifier": "security.rowtargetshapebad"
}
}

}
