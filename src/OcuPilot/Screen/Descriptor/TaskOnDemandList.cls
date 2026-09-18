/// <p>The tasks the instance can run on demand, read through the vendor's own <code>Task.CRUD</code>
/// LIST with its <code>onDemand</code> parameter fixed at <code>1</code> (AD-2, AD-36) and rendered by
/// the <code>list</code> archetype's page from the declared <code>table</code> (AD-5).</p>
/// <p><b>On demand means the vendor's.</b> <code>RunList</code> keeps the rows whose <code>Id</code>
/// <code>%SYS.Task:OnDemandTasksFilter</code> returns, the same query the classic
/// <code>%CSP.UI.Portal.TasksOnDemand</code> page lists. On this build that query answers every task,
/// not only those whose schedule is the on-demand time period. The parameter is declared as
/// <code>read.source.query</code>, so neither the screen route nor the read tool can send it
/// otherwise.</p>
/// <p><b>Its scope is <code>instance</code></b> and its rows span namespaces, each carrying its own
/// <code>Namespace</code> column, for the reason <class>OcuPilot.Screen.Descriptor.TaskScheduleList</class>
/// gives; its empty state names the instance.</p>
/// <p><b><code>Suspended</code> is absent</b>: the LIST coerces it to <code>false</code> for every
/// task, as <class>OcuPilot.Screen.Descriptor.TaskScheduleList</class> records.</p>
/// <p><b>It is a <code>list</code></b> (<file>EXPERIENCE.md</file>, the On-demand tasks row) that reads
/// when it opens and does not auto-refresh (AD-43).</p>
/// <p><b>It declares no Run.</b> Running a task is a write, and a row action is declared together
/// with its handler (AD-10); Epic 7 adds both. Until then the screen carries no action, and its empty
/// state names what to do next rather than inviting the agent.</p>
/// <p><b>The privilege set is <code>%Admin_Task:USE</code> plus <code>%DB_IRISSYS:READ</code></b>,
/// the narrower half of the endpoint's <code>ResourcesOR()</code> plus the database read the port
/// needs in <code>%SYS</code>, the Task schedule's set, established for this read by a real principal
/// on a throwaway (AD-8, AD-29).</p>
/// <p><b>The classic page is <code>%CSP.UI.Portal.TasksOnDemand</code></b> (AD-44). As a list
/// archetype it links out to nothing.</p>
Class OcuPilot.Screen.Descriptor.TaskOnDemandList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "tasks/on-demand",
  "area": "tasks",
  "labelKey": "taskOnDemandLabel",
  "sideBarPosition": 2,
  "archetype": "list",
  "built": true,
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
  "context": {"fields": ["Name", "Namespace", "Type", "Description", "Id", "LastFinished"], "secretFields": []},
  "emptyStateKey": "taskOnDemandEmpty",
  "commandAliases": ["on demand", "run task"],
  "classicPage": "%CSP.UI.Portal.TasksOnDemand",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "LIST", "query": {"onDemand": "1"}},
    "fields": ["Name", "Namespace", "Type", "Description", "Id", "LastFinished"],
    "filter": ["Name", "Namespace", "Type", "Description"],
    "sort": {"fields": ["Name", "Namespace", "Type", "LastFinished"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Namespace", "labelKey": "headerNamespaceLabel", "kind": "text"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "Description", "labelKey": "tableColumnDescription", "kind": "text"},
      {"field": "LastFinished", "labelKey": "taskColumnLastRun", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "tasks.ondemand"
}
}

}
