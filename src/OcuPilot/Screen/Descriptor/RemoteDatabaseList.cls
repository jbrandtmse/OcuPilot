/// <p>Remote databases: every remote database configuration on this instance -- one whose file is on
/// an ECP data server -- keyed by its name, with its data server, its directory there and its status,
/// read through the vendor's own <code>Database.ConfigCRUD</code> <code>LIST</code> narrowed by the
/// fixed <code>remoteOnly</code> parameter (AD-2, AD-36) and rendered by the <code>list</code>
/// archetype's page from the declared <code>table</code> (AD-5). It is OS management's twelfth
/// side-bar entry, after Local databases (Story 18.16).</p>
/// <p><b>It shares the configuration entity type with Local databases</b>
/// (<code>database-configuration</code>, keyed by name, scope <code>instance</code>): a local and a
/// remote configuration share one name space, and Local databases' own read answers none of these
/// rows. The name cell opens <class>OcuPilot.Screen.Descriptor.RemoteDatabaseForm</class> at this
/// route plus <code>/edit</code>.</p>
/// <p><b>The privilege set is <code>%Admin_Manage:USE</code> and <code>%DB_IRISSYS:READ</code></b>, the
/// endpoint's own <code>ResourcesOR()</code> and the port's switch into <code>%SYS</code>. The remote
/// database tools add <code>%DB_IRISSYS:WRITE</code> (AD-8).</p>
/// <p>Its primary action is Create, which opens the form; its row action is Delete, whose typed-name
/// dialog states the removal's impact (AD-8). Each runs a remote database tool (AD-53, AD-55). As a
/// list it links out to nothing and it does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.RemoteDatabaseList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/remote-databases",
  "area": "os-management",
  "labelKey": "remoteDatabaseListLabel",
  "sideBarPosition": 12,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "database-configuration",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [{"id": "delete", "selfProtection": ""}],
  "context": {"fields": ["Name", "Server", "Directory", "Status"], "secretFields": []},
  "emptyStateKey": "remoteDatabaseListEmpty",
  "commandAliases": ["remote databases", "ecp databases", "create remote database"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "remoteDatabaseListPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "remoteDatabaseListPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "remoteDatabaseListPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.RemoteDatabases",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Database.ConfigCRUD", "type": "LIST", "query": {"remoteOnly": "1"}},
    "fields": ["Name", "Server", "Directory", "Status"],
    "filter": ["Name", "Server", "Directory", "Status"],
    "sort": {"fields": ["Name", "Server", "Directory", "Status"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Server", "labelKey": "remoteDatabaseServer", "kind": "identifier"},
      {"field": "Directory", "labelKey": "lockColumnDirectory", "kind": "identifier"},
      {"field": "Status", "labelKey": "taskHistoryColumnStatus", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "remoteDatabaseListEmptyAgent"
  },
  "toolIdentifier": "osmgmt.remotedatabases"
}
}

}
