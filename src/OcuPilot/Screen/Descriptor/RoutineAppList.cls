/// <p>The privileged routine applications list: every application of the routine type this instance holds, read
/// through the vendor's own <code>Security.PrivilegedRoutine</code> <code>LIST</code> (AD-2, AD-36, Story 18.31) and
/// rendered by the <code>list</code> archetype's page from the declared <code>table</code> (AD-5). It is the Web
/// applications area's fifth side-bar entry.</p>
/// <p><b>Its id is the application's name</b> (AD-13): the instance resolves it in any case, so the id takes
/// <code>foldcase</code>. The vendor's <code>LIST</code> answers <code>Enabled</code> false on every row, so the read
/// declares a <code>rowGet</code> whose <code>GET</code> supplies <code>Enabled</code> and <code>Description</code>,
/// neither of which the list carries. The editor reads through its own form route
/// (<class>OcuPilot.Area.WebApp.RoutineAppRules</class>).</p>
/// <p>Its Create opens <class>OcuPilot.Screen.Descriptor.RoutineAppForm</class>, as does a row's name cell; its row
/// action Delete is the screen's caller of <class>OcuPilot.Screen.Tool.RoutineAppDelete</class> (AD-53) and carries the
/// <code>ocupilot-routine-application</code> rule, which explains the refusal OcuPilot's own two applications earn. The
/// editor's Application roles, Matching roles and Routines and classes tabs send the six other row actions, each the
/// screen's caller of <class>OcuPilot.Screen.Tool.RoutineAppUpdate</class> and each carrying the same rule (Story
/// 18.33).</p>
/// <p><b>Its pairs are the Web applications area's</b>, <code>%Admin_Secure:USE</code> and
/// <code>%DB_IRISSYS:READ</code>: a principal holding exactly those two listed, created and deleted a privileged
/// routine application (AD-8, measured at Story 18.31's plan). The classic page is
/// <code>%CSP.UI.Portal.Applications.PrivRoutineList</code> (AD-44).</p>
Class OcuPilot.Screen.Descriptor.RoutineAppList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "web-applications/routine-applications",
  "area": "web-applications",
  "labelKey": "routineAppListLabel",
  "sideBarPosition": 5,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "routine-application",
  "entityLabelKey": "aboutRoutineApplication",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [
    {"id": "add-application-role", "selfProtection": "ocupilot-routine-application"},
    {"id": "remove-application-role", "selfProtection": "ocupilot-routine-application"},
    {"id": "add-matching-role", "selfProtection": "ocupilot-routine-application"},
    {"id": "remove-matching-role", "selfProtection": "ocupilot-routine-application"},
    {"id": "add-routine", "selfProtection": "ocupilot-routine-application"},
    {"id": "remove-routine", "selfProtection": "ocupilot-routine-application"},
    {"id": "delete", "selfProtection": "ocupilot-routine-application"}
  ],
  "context": {"fields": ["Name", "Enabled", "Resource", "Description"], "secretFields": []},
  "emptyStateKey": "routineAppListEmpty",
  "commandAliases": ["privileged routine applications", "create privileged routine application"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "routineAppListPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "routineAppListPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "routineAppListPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.Applications.PrivRoutineList",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "privileged routine application",
    "source": {
      "port": "admin",
      "endpoint": "Security.PrivilegedRoutine",
      "type": "LIST",
      "rowGet": {"key": "Name", "param": "name", "fields": ["Enabled", "Description"], "derived": []}
    },
    "fields": ["Name", "Enabled", "Resource", "Description"],
    "filter": ["Name", "Resource", "Description"],
    "sort": {"fields": ["Name", "Enabled", "Resource", "Description"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Enabled", "labelKey": "tableColumnEnabled", "kind": "status"},
      {"field": "Resource", "labelKey": "webAppColumnResource", "kind": "identifier"},
      {"field": "Description", "labelKey": "tableColumnDescription", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "routineAppListEmptyAgent"
  },
  "toolIdentifier": "webapp.routineapps"
}
}

}
