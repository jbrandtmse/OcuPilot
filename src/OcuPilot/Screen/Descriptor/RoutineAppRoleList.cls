/// <p>One privileged routine application's roles: the application roles it grants and the matching roles it applies
/// them for, read as a list over the <code>MatchRoles</code> member of the application's own
/// <code>Security.PrivilegedRoutine</code> <code>GET</code> (AD-36, Story 18.12). Each row is one matching role and the
/// roles granted to a caller holding it; the row whose matching role is empty is the application roles, granted to every
/// caller. The agent reads the list whole before it sends <code>webapp.routineapps.update</code>, which replaces it.</p>
/// <p><b>It is a sub-resource of <class>OcuPilot.Screen.Descriptor.RoutineAppList</class> and never listed</b>
/// (<code>sideBarPosition</code> 0): the route id is the application's name, filled into the one criterion, <code>name</code>.
/// An application the instance does not hold reads no rows, an empty list reads no rows, and a name another kind of
/// application holds is refused 404 <code>PRIVROUTINE.TYPE</code> (AD-10). It declares no action: the editor's tabs send
/// the changes.</p>
/// <p><b>Its pairs are the list's own</b>, and so is its classic page (AD-8, AD-44).</p>
Class OcuPilot.Screen.Descriptor.RoutineAppRoleList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "web-applications/routine-applications/roles",
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
  "parentScope": "web-applications/routine-applications",
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
  "classicPage": "%CSP.UI.Portal.Applications.PrivRoutine",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "matching role with its granted roles",
    "source": {"port": "admin", "endpoint": "Security.PrivilegedRoutine", "type": "GET", "rows": "MatchRoles"},
    "fields": ["MatchRole", "TargetRoles"],
    "filter": ["MatchRole"],
    "sort": {"fields": ["MatchRole"], "default": "MatchRole", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "name", "labelKey": "tableColumnName", "kind": "text", "maxLength": 64, "hint": "One privileged routine application, spelled as webapp.routineapps.read answers its Name."}
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
  "toolIdentifier": "webapp.routineapproles"
}
}

}
