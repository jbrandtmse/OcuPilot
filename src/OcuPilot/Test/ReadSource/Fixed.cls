/// <p>Fixture descriptor declaring a LIST with a fixed query parameter (AD-36): <code>Test.Fixed</code>
/// with <code>query {onDemand: "1"}</code> and one text criterion, <code>name</code>. Its answers
/// come from <class>OcuPilot.Test.ReadSource.Endpoint</class>.</p>
/// <p>It lives in a package of its own so no fixture registry enumerates it.</p>
Class OcuPilot.Test.ReadSource.Fixed Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "tasks/readsource-fixed",
  "area": "tasks",
  "labelKey": "taskOnDemandLabel",
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
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Name"], "secretFields": []},
  "emptyStateKey": "taskOnDemandEmpty",
  "commandAliases": [],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Test.Fixed", "type": "LIST", "query": {"onDemand": "1"}},
    "fields": ["Name"],
    "filter": ["Name"],
    "sort": {"fields": ["Name"], "default": "Name", "direction": "asc"},
    "paging": "cap",
    "criteria": {"fields": [{"param": "name", "labelKey": "tableColumnName", "kind": "text", "maxLength": 20}]}
  },
  "table": {
    "columns": [{"field": "Name", "labelKey": "tableColumnName", "kind": "name"}],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "tasks.readsourcefixed"
}
}

}
