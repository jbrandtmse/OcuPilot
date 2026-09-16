/// <p>Fixture descriptor whose banner matches on a running instance: it compares
/// <code>Task.Manager</code>'s <code>Status</code> to <code>Running</code>, which is what the live
/// endpoint answers while the Task Manager is running. It is how
/// <method>OcuPilot.Screen.Read.BannerKey</method>'s match arm is exercised against the real port
/// without suspending anything -- the shipped descriptor compares the same field to
/// <code>Suspended</code>, and suspending an instance to see a strip is the browser spec's, on the
/// throwaway.</p>
/// <p><b>It declares two cases, and the one that matches is the second</b> (DW-270). A banner is
/// one read over one field with a list of <code>(value -&gt; sentence)</code> cases, and the first
/// whose value matches is the one raised -- so a fixture whose only case matched would pass
/// equally against an engine that read <code>cases[0]</code> and stopped. The first case here
/// names <code>Suspended</code>, which a running instance does not answer.</p>
/// <p>Its own package, enumerated by no registry, so the production roster and the tool registry
/// are unchanged by it.</p>
Class OcuPilot.Test.ReadBanner.Matching Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "tasks/banner-match",
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
      {"equals": "Suspended", "messageKey": "taskManagerStoppedBanner", "severity": "warning"},
      {"equals": "Running", "messageKey": "taskManagerSuspendedBanner", "severity": "info"}
    ]
  },
  "toolIdentifier": "tasks.bannermatch"
}
}

}
