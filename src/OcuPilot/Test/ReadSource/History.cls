/// <p>Fixture descriptor declaring a <code>HISTORY</code> read (AD-36, Story 6.6) of
/// <code>Test.History</code> with one text criterion, <code>search</code>, sent to the vendor under
/// the declared <code>vendorParam</code> <code>filter</code> -- the mechanism
/// <class>OcuPilot.Screen.Descriptor.TaskHistoryList</class> uses so the vendor's own reserved name
/// never collides with the tool's <code>filter</code> argument. Its answers come from
/// <class>OcuPilot.Test.ReadSource.Endpoint</class>.</p>
/// <p>It lives in a package of its own so no fixture registry enumerates it.</p>
Class OcuPilot.Test.ReadSource.History Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "tasks/readsource-history",
  "area": "tasks",
  "labelKey": "taskHistoryLabel",
  "sideBarPosition": 0,
  "archetype": "list (server criteria)",
  "built": false,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Task", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "task-history-entry",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Name"], "secretFields": []},
  "emptyStateKey": "taskHistoryEmpty",
  "commandAliases": [],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Test.History", "type": "HISTORY"},
    "fields": ["Name"],
    "filter": ["Name"],
    "sort": {"fields": ["Name"], "default": "Name", "direction": "asc"},
    "paging": "cap",
    "criteria": {"fields": [{"param": "search", "labelKey": "taskHistorySearch", "kind": "text", "maxLength": 100, "vendorParam": "filter"}]}
  },
  "table": {
    "columns": [{"field": "Name", "labelKey": "tableColumnName", "kind": "name"}],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "tasks.readsourcehistory"
}
}

}
