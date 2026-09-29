/// <p>Local databases: every local database configuration on this instance, keyed by its name, with
/// its directory and status, read through the vendor's own <code>Database.ConfigCRUD</code>
/// <code>LIST</code> narrowed by the fixed <code>localOnly</code> parameter (AD-2, AD-36) and rendered
/// by the <code>list</code> archetype's page from the declared <code>table</code> (AD-5). It is OS
/// management's tenth side-bar entry, after External language servers.</p>
/// <p><b>It sits beside Databases, not inside it</b> (Story 18.3): Databases is the operations view,
/// keyed by directory (<code>database</code>), and this is the configuration view, keyed by name
/// (<code>database-configuration</code>), as the classic portal separates
/// <code>%CSP.UI.Portal.OpDatabases</code> and <code>%CSP.UI.Portal.Databases</code>. Its scope is
/// <code>instance</code>, and the name cell opens <class>OcuPilot.Screen.Descriptor.LocalDatabaseForm</class>
/// at this route plus <code>/edit</code>.</p>
/// <p><b>The privilege set is <code>%Admin_Manage:USE</code> and <code>%DB_IRISSYS:READ</code></b>, the
/// endpoint's own <code>ResourcesOR()</code> and the port's switch into <code>%SYS</code>. The database
/// tools add the pairs their writes need beyond it (AD-8 as amended 2026-09-29).</p>
/// <p>Its primary action is Create, which opens the wizard; its row action is Delete, whose typed-name
/// dialog states the removal's impact (AD-8) and carries the choice to delete the file too (AD-56
/// (ii)). Each runs a database tool (AD-53, AD-55). A second row action, <code>expand</code>, is Add a
/// volume (<class>OcuPilot.Screen.Tool.LocalDatabaseExpand</class>, Story 18.4), which the editor's
/// volume files section draws and no row does. Because a mount or a dismount on Database details
/// changes this list's Status, it declares <code>database</code> as a secondary entity type and
/// re-fetches after one (AD-14). As a list it links out to nothing and it does not refresh
/// (AD-43).</p>
Class OcuPilot.Screen.Descriptor.LocalDatabaseList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/local-databases",
  "area": "os-management",
  "labelKey": "localDatabaseListLabel",
  "sideBarPosition": 10,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "database-configuration",
  "secondaryEntityTypes": ["database"],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [{"id": "delete", "selfProtection": ""}, {"id": "expand", "selfProtection": ""}],
  "context": {"fields": ["Name", "Directory", "Status"], "secretFields": []},
  "emptyStateKey": "localDatabaseListEmpty",
  "commandAliases": ["local databases", "configure database", "create database"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "localDatabaseListPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "localDatabaseListPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "localDatabaseListPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.Databases",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Database.ConfigCRUD", "type": "LIST", "query": {"localOnly": "1"}},
    "fields": ["Name", "Directory", "Status"],
    "filter": ["Name", "Directory", "Status"],
    "sort": {"fields": ["Name", "Directory", "Status"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Directory", "labelKey": "lockColumnDirectory", "kind": "identifier"},
      {"field": "Status", "labelKey": "taskHistoryColumnStatus", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "localDatabaseListEmptyAgent"
  },
  "toolIdentifier": "osmgmt.localdatabases"
}
}

}
