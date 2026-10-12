/// <p>One privileged routine application's routines and classes, read as a list over the <code>Routines</code> member of
/// the application's own <code>Security.PrivilegedRoutine</code> <code>GET</code> (AD-36, Story 18.12). Each row is one
/// routine or class, the database it lives in and its type. The agent reads the list whole before it sends
/// <code>webapp.routineapps.update</code>, which replaces it.</p>
/// <p><b>It is a sub-resource of <class>OcuPilot.Screen.Descriptor.RoutineAppList</class> and never listed</b>
/// (<code>sideBarPosition</code> 0), and declares the same criterion, refusals, pairs and classic page as
/// <class>OcuPilot.Screen.Descriptor.RoutineAppRoleList</class>. A row is keyed by the routine, its type and its
/// database.</p>
Class OcuPilot.Screen.Descriptor.RoutineAppRoutineList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "web-applications/routine-applications/routines",
  "area": "web-applications",
  "labelKey": "routineAppTabRoutines",
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
  "id": {"kind": "composite", "parts": ["RoutineOrClass", "Type", "Db"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["RoutineOrClass", "Db", "Type"], "secretFields": []},
  "emptyStateKey": "routineAppRoutinesEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "routineAppRoutinesPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "routineAppRoutinesPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "routineAppRoutinesPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.Applications.PrivRoutine",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Security.PrivilegedRoutine", "type": "GET", "rows": "Routines"},
    "fields": ["RoutineOrClass", "Db", "Type"],
    "filter": ["RoutineOrClass", "Db"],
    "sort": {"fields": ["RoutineOrClass", "Db", "Type"], "default": "RoutineOrClass", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "name", "labelKey": "tableColumnName", "kind": "text", "maxLength": 64, "hint": "One privileged routine application, spelled as webapp.routineapps.read answers its Name."}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "RoutineOrClass", "labelKey": "routineAppFieldRoutine", "kind": "name"},
      {"field": "Db", "labelKey": "systemInfoDatabase", "kind": "identifier"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "webapp.routineapproutines"
}
}

}
