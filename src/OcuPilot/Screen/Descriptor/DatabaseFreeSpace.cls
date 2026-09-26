/// <p>The Free-space view of Databases: the same fourteen databases as
/// <class>OcuPilot.Screen.Descriptor.DatabaseList</class>, with three figures merged in from the
/// vendor's own asynchronous <code>Database.SysCRUD</code> <code>TYPEINFO</code> call (AD-2, AD-26,
/// AD-36), one per surviving row. The command bar's View control switches to and from the General
/// view; this screen is never listed on its own (<code>sideBarPosition</code> 0).</p>
/// <p><b>The route is <code>os-management/database-free-space</code>, not
/// <code>os-management/databases/free-space</code>.</b> <code>buildRoutes</code> emits a
/// <code>/:id</code> route for every built screen (<file>ui/src/app/app.routes.ts:62-80</file>), and
/// a one-segment suffix under <code>databases</code> would race that generated route -- the router
/// could not tell the literal segment <code>free-space</code> from a database directory encoded as
/// one path segment. A sibling route under <code>os-management</code> has no such collision.</p>
/// <p><b>One read, one <code>rowGet</code> per row -- never a per-figure stream.</b>
/// <method>OcuPilot.Screen.Read.Execute</method> answers one envelope and issues the declared
/// <code>rowGet</code> once per row inside that one call, so per-figure arrival is not declarable;
/// the vendor's own <code>Result</code> is written once by <code>SaveResult</code>, so no partial
/// answer exists either. The client therefore paints every row from the fast <code>LIST</code>
/// fields immediately, with skeleton cells where <code>AvailableSpace</code>, <code>DiskFree</code>
/// and <code>Mounted</code> go, and fills all three together in one tick when this read resolves;
/// the table cannot reflow while it waits, because <file>ui/src/app/shell/data-table.ts:611-617</file>
/// derives the grid's column tracks from the declared column kinds, never from cell content. Probed:
/// fourteen databases cost 0.852 s against NFR-1's 2 s budget.</p>
/// <p><b><code>MaxSize</code> is deliberately not declared here.</b> LIST answers the display string
/// <code>"Unlimited"</code> and <code>INFO</code> answers the numeric maximum, and
/// <code>rowGet.fields</code> is exactly the mechanism that keeps a disagreeing member out of a
/// merged row -- the maximum is the General view's column, asked for once (<file>epics.md</file>
/// AC1).</p>
/// <p><b>A bounded wait that is not met refuses the whole read.</b> This read queues one
/// <code>TYPEINFO</code> task per row, and <method>OcuPilot.Port.AdminPort.AwaitTask</method>
/// bounds each of them separately -- at most <code>ASYNCTIMEOUT</code> (30 s) at
/// <code>POLLINTERVAL</code> (0.05 s) per task, so the bound is per row and not per read. A task
/// still <code>Queued</code> or <code>Running</code> at its own bound answers HTTP 503,
/// <code>PORT.TIMEOUT</code>, and <method>OcuPilot.Screen.Read.Execute</method> abandons the
/// remaining rows, so the read is refused whole with no row carrying a partial figure -- the vendor
/// task row is left in place for whichever worker still owns it. This screen writes no polling of
/// its own.</p>
/// <p><b>Its id is <code>single</code>, the same <code>Directory</code>
/// <class>DatabaseList</class> keys its rows by</b> -- the two views are the same rows, read two
/// ways. <class>DatabaseDetails</class> is reached from <class>DatabaseList</class>'s name cell and
/// not from this view's: <method>OcuPilot.Screen.Read</method> declares no pairing here and the
/// client's row-link chain resolves a detail screen by <code>parentScope</code>
/// (<file>ui/src/app/core/navigation.ts</file> <code>detailScreenFor</code>), which names the
/// General view's route alone, so this view's name cell resolves to its own route. A
/// <code>rowTarget</code> is not available to change that -- both engines refuse one on a screen
/// that already pairs its own surface -- and <file>EXPERIENCE.md</file> asks for the link from the
/// Databases name cell only.</p>
/// <p><b>The pair set is three, and Operate is the AsyncResult poll's, not the List's own.</b>
/// <code>%Admin_Manage:USE</code> is <code>LIST</code>'s <code>ResourcesOR()</code>, the same pair
/// <class>DatabaseList</class> declares; <code>%Admin_Operate:USE</code> is
/// <code>%Api.Admin.Endpoints.AsyncResult.ResourcesOR()</code>, which the port polls the queued
/// <code>TYPEINFO</code> task through and which answers Operate alone -- verified on the instance,
/// distinct from <code>TYPEINFO</code>'s own Manage-or-Operate gate, so a caller could pass the
/// endpoint's own check and still be refused inside the poll without this second pair declared.
/// <code>%DB_IRISSYS:READ</code> is the port's own namespace-switch requirement, declared last so a
/// caller short of Manage or Operate is named that pair first (AD-8, AD-29).</p>
/// <p><b>The classic key is <code>%CSP.UI.Portal.OpDatabases</code>,</b> the same page and the same
/// reasoning <class>DatabaseList</class> gives -- the one classic page that carries both views.</p>
/// <p>It is part of the Databases entry in the roster of seven screens the shared auto-refresh
/// framework binds (AD-43) -- <file>EXPERIENCE.md</file> counts screens, and the one entry covers
/// both of this <code>list (two views)</code> screen's views, so eight descriptors declare
/// <code>refreshes</code> against seven named screens -- at the rates
/// <file>EXPERIENCE.md</file>'s auto-refresh bullet declares. As a list archetype it links out to
/// nothing; it declares no primary or row action, and reuses <class>DatabaseList</class>'s
/// <code>databaseListEmpty</code> empty-state sentence, since an empty instance has no rows in
/// either view.</p>
Class OcuPilot.Screen.Descriptor.DatabaseFreeSpace Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/database-free-space",
  "area": "os-management",
  "labelKey": "databaseFreeSpaceLabel",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "refreshes": true,
  "refreshRates": [5, 10, 30, 60],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "database",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Directory", "Size", "AvailableSpace", "DiskFree", "Mounted"], "secretFields": []},
  "emptyStateKey": "databaseListEmpty",
  "commandAliases": ["free space", "database free space"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupCapacity", "textKey": "databaseFreeSpacePrompt1"},
    {"groupKey": "promptGroupCapacity", "textKey": "databaseFreeSpacePrompt2"},
    {"groupKey": "promptGroupCapacity", "textKey": "databaseFreeSpacePrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.OpDatabases",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {
      "port": "admin",
      "endpoint": "Database.SysCRUD",
      "type": "LIST",
      "rowGet": {
        "key": "Directory",
        "param": "dir",
        "type": "INFO",
        "fields": ["AvailableSpace", "DiskFree", "Mounted"],
        "derived": []
      }
    },
    "fields": ["Directory", "Size", "AvailableSpace", "DiskFree", "Mounted"],
    "filter": ["Directory", "Size", "AvailableSpace", "DiskFree", "Mounted"],
    "sort": {"fields": ["Directory", "Size", "AvailableSpace", "DiskFree"], "default": "Directory", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Directory", "labelKey": "lockColumnDirectory", "kind": "name"},
      {"field": "Size", "labelKey": "databaseColumnSize", "kind": "number"},
      {"field": "AvailableSpace", "labelKey": "databaseColumnAvailable", "kind": "number"},
      {"field": "DiskFree", "labelKey": "databaseColumnDiskFree", "kind": "text"},
      {"field": "Mounted", "labelKey": "databaseColumnMounted", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "osmgmt.databasefreespace"
}
}

}
