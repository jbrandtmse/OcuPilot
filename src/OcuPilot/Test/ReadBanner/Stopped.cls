/// <p>Fixture descriptor carrying <b>the shipped task schedule's own banner block, verbatim</b>, over
/// a source the port fixture answers (DW-270). It is what resolves the stopped case: the live
/// <code>Task.Manager</code> answers <code>Running</code> on any instance a test may touch, and
/// stopping a scheduler to see a strip is not something a unit test does to an instance.</p>
/// <p>Read through <class>OcuPilot.Test.Read.ReadFixture</class> and
/// <class>OcuPilot.Test.PortFixture</class>, whose <method>EndpointClass</method> answers
/// <class>OcuPilot.Test.EndpointFixture</class> for every endpoint name -- so the list read takes
/// the fixture's armed rows and the banner's <code>GET</code>, which carries no
/// <code>name</code>, takes the detail armed under the empty key.
/// <method>OcuPilot.Test.ScreenRead.TestTheStoppedTaskManagerRaisesItsOwnSentence</method> asserts
/// this block against <class>OcuPilot.Screen.Descriptor.TaskScheduleList</class>'s before driving
/// it, so a fixture that drifted from the shipped mapping pins nothing.</p>
/// <p>Its own package, enumerated by no registry, so the production roster and the tool registry
/// are unchanged by it.</p>
Class OcuPilot.Test.ReadBanner.Stopped Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "tasks/banner-stopped",
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
    "source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"},
    "field": "Status",
    "cases": [
      {"equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"},
      {"equals": "Not running", "messageKey": "taskManagerStoppedBanner", "severity": "warning"}
    ]
  },
  "toolIdentifier": "tasks.bannerstopped"
}
}

}
