/// <p>Fixture descriptor whose banner names an endpoint no compiled class answers, so the port
/// refuses it with <code>PORT.NOTIMPLEMENTED</code> while its list reads normally. It is how the
/// fault rule is exercised: <method>OcuPilot.Screen.Read.BannerKey</method> answers <code>""</code>
/// and the read still returns its rows and 200 -- the opposite of the <code>rowGet</code> fault
/// rule, deliberately, because a strip that cannot be resolved is one the user does not see while a
/// list that will not load is a screen the user cannot use.</p>
/// <p>The endpoint name is a well-formed package-relative one, so
/// <method>OcuPilot.Screen.Registry.BannerProblem</method> admits the declaration and the refusal is
/// the port's at call time, which is the shape a vendor rename would take.</p>
/// <p>Its own package, enumerated by no registry, so the production roster and the tool registry
/// are unchanged by it.</p>
Class OcuPilot.Test.ReadBanner.Faulting Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "tasks/banner-fault",
  "area": "tasks",
  "labelKey": "taskListLabel",
  "sideBarPosition": 1,
  "archetype": "list",
  "built": false,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Task", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "task",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "context": {"fields": ["Name"], "secretFields": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "emptyStateKey": "taskListEmpty",
  "commandAliases": [],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "LIST"},
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
  "banner": {
    "source": {"port": "admin", "endpoint": "Task.NoSuchManager", "type": "GET"},
    "field": "Status",
    "equals": "Running",
    "messageKey": "taskManagerSuspendedBanner",
    "severity": "warning"
  },
  "toolIdentifier": "tasks.bannerfault"
}
}

}
