/// <p>Fixture descriptor whose <code>rowTarget</code> is a sound shape naming a route no descriptor
/// declares, so the roster-wide refusal can be demonstrated through
/// <method>OcuPilot.Screen.Registry.Validate</method> rather than by calling
/// <method>OcuPilot.Screen.Registry.RowTargetResolutionProblem</method> on a roster value (AD-5,
/// Story 6.10). Its own shape passes <method>OcuPilot.Screen.Registry.RowTargetProblem</method>,
/// so the only rule left to refuse it is the resolution one.</p>
/// <p>It lives in a package of its own, with
/// <class>OcuPilot.Test.RowTargetRosterRegistry</class>, and is the only descriptor in it, so the
/// named route cannot resolve.</p>
Class OcuPilot.Test.RowTargetRoster.A Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/row-target-roster-a",
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
  "rowTarget": {"route": "security/row-target-nowhere", "field": "Name"},
  "toolIdentifier": "security.rowtargetrostera"
}
}

}
