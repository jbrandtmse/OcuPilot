/// <p>One web application's roles: the application roles it grants and the matching roles it applies them for, read as a
/// list over the <code>MatchRoles</code> member of the application's own <code>WebApp.App</code> <code>GET</code> (AD-36,
/// Story 18.47). Each row is one matching role and the roles granted to a caller holding it; the row whose matching role is
/// empty is the application roles, granted to every caller. The agent reads the list whole before it sends
/// <code>webapp.list.update</code>, which replaces it.</p>
/// <p><b>It is a sub-resource of <class>OcuPilot.Screen.Descriptor.WebAppList</class> and never listed</b>
/// (<code>sideBarPosition</code> 0): the route id is the application's name, filled into the one criterion, <code>name</code>.
/// An application the instance does not hold reads no rows, and an empty list reads no rows. It declares no action: the
/// editor's tabs send the changes.</p>
/// <p><b>Its pairs and its classic page are the list's own</b> (AD-8, AD-44). Its labels, empty state and prompts are
/// <class>OcuPilot.Screen.Descriptor.RoutineAppRoleList</class>'s: the shape of the list is the same.</p>
Class OcuPilot.Screen.Descriptor.WebAppRoleList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "web-applications/list/roles",
  "area": "web-applications",
  "labelKey": "routineAppRolesLabel",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "web-applications/list",
  "id": {"kind": "composite", "parts": ["MatchRole"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["MatchRole", "TargetRoles"], "secretFields": []},
  "emptyStateKey": "routineAppRolesEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "routineAppRolesPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "routineAppRolesPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "routineAppRolesPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.Applications.WebList",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "matching role with its granted roles",
    "source": {"port": "admin", "endpoint": "WebApp.App", "type": "GET", "rows": "MatchRoles"},
    "fields": ["MatchRole", "TargetRoles"],
    "filter": ["MatchRole"],
    "sort": {"fields": ["MatchRole"], "default": "MatchRole", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "name", "labelKey": "tableColumnName", "kind": "text", "maxLength": 256, "hint": "One web application, spelled as webapp.list.read answers its Name."}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "MatchRole", "labelKey": "webAppFieldMatchRole", "kind": "name", "emptyKey": "routineAppRolesEveryCaller"},
      {"field": "TargetRoles", "labelKey": "userColumnRoles", "kind": "identifier"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "webapp.webapproles"
}
}

}
