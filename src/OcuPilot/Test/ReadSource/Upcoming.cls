/// <p>Fixture descriptor declaring an <code>UPCOMING</code> read (AD-36) of <code>Test.Upcoming</code>
/// with one choice criterion, <code>hoursOffset</code>. Its answers come from
/// <class>OcuPilot.Test.ReadSource.Endpoint</class>.</p>
/// <p>It lives in a package of its own so no fixture registry enumerates it.</p>
Class OcuPilot.Test.ReadSource.Upcoming Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "tasks/readsource-upcoming",
  "area": "tasks",
  "labelKey": "taskUpcomingLabel",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": false,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Task", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "task",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Id", "Datetime"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Id", "Datetime"], "secretFields": []},
  "emptyStateKey": "taskUpcomingEmpty",
  "commandAliases": [],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Test.Upcoming", "type": "UPCOMING"},
    "fields": ["Id", "Datetime"],
    "filter": ["Datetime"],
    "sort": {"fields": ["Datetime"], "default": "Datetime", "direction": "asc"},
    "paging": "cap",
    "criteria": {"fields": [{"param": "hoursOffset", "labelKey": "taskUpcomingHorizon", "kind": "choice", "maxLength": 3, "options": ["1", "24"]}]}
  },
  "table": {
    "columns": [{"field": "Datetime", "labelKey": "taskUpcomingColumnAt", "kind": "text"}],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "tasks.readsourceupcoming"
}
}

}
