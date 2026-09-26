/// <p>Database details: one database's own properties, read through the vendor's own
/// <code>Database.SysCRUD</code> <code>GET</code> (AD-2, AD-36) with its three free-space figures
/// and mount state merged from one <code>INFO</code> call, and rendered by this screen's own page
/// from the declared <code>table</code> doubling as the field list (AD-5) -- properties and volume
/// files only. <code>%SYS.BackgroundTask:RunningInDatabase</code> is a <code>Final Internal</code>
/// class query no <code>%Api.Admin.*</code> class references, so a background-tasks section is out
/// of reach here and is chartered to the owner's decision sheet as <b>DW-1080</b>.</p>
/// <p><b>It is a sub-resource of Databases and never listed</b> (<code>sideBarPosition</code> 0). It
/// declares its parent, <code>parentScope</code> <code>os-management/databases</code>, and is
/// reached from the General view's name cell at
/// <code>os-management/databases/details/&lt;Directory&gt;</code> -- from that view alone, since the
/// client resolves a list's paired detail screen by <code>parentScope</code>
/// (<file>ui/src/app/core/navigation.ts</file> <code>detailScreenFor</code>) and this screen names
/// the General view's route, which is the one link <file>EXPERIENCE.md</file> asks for.
/// <method>OcuPilot.Screen.Registry.RouteEntityType</method> answers <code>database</code> for this
/// screen, resolved through that parent.</p>
/// <p><b><code>rowGet.type</code> <code>INFO</code>, never <code>parts</code>.</b>
/// <code>PartsProblem</code> refuses <code>parts</code> alongside <code>read.criteria</code>, and
/// every field a parts read declares must be <code>&lt;as&gt;.&lt;member&gt;</code> -- which would
/// leave this screen no plain field to key its <code>Directory</code> id from. The
/// <class>OcuPilot.Screen.Descriptor.TaskDetails</class> shape -- a parent-scoped
/// <code>GET</code> with one route-id criterion and a keyed <code>rowGet</code> -- already carries
/// exactly this, so it needs no amendment (Story 6.7). The one criterion, <code>dir</code>, is
/// filled by the client from the route id and doubles as the <code>rowGet</code>'s own key
/// (<code>ObjectCriterionParam</code>), since neither <code>GET</code> nor <code>INFO</code>
/// answers a <code>Directory</code> property of its own -- <method>OcuPilot.Screen.Read.Execute</method>
/// seeds the criterion's value onto the fetched object under that name (<code>:313</code>).</p>
/// <p><b>Fifteen fields, one <code>name</code> column.</b> <code>Directory</code> (seeded from the
/// criterion, since neither call answers it); <code>GET</code>'s own ten --
/// <code>MaxSize</code> (the numeric maximum; <code>LIST</code>'s own <code>MaxSize</code> is the
/// display string <code>"Unlimited"</code> instead, which is why <class>DatabaseList</class> never
/// declares this one), <code>ExpansionSize</code>, <code>NewVolumeThreshold</code>,
/// <code>NewVolumeDirectory</code>, <code>ResourceName</code>, <code>NewGlobalIsKeep</code>,
/// <code>NewGlobalCollation</code>, <code>ClusterMountMode</code>, <code>ReadOnly</code>,
/// <code>GlobalJournalState</code>; and the <code>rowGet</code>'s four --
/// <code>Size</code>, <code>AvailableSpace</code>, <code>DiskFree</code>, <code>Mounted</code>, the
/// same four figures <class>OcuPilot.Screen.Descriptor.DatabaseFreeSpace</class> merges the same
/// way. <code>Directory</code> is the one <code>name</code> column.</p>
/// <p><b>An unknown directory reads as zero rows, never a refusal</b> (AD-37, verified against the
/// instance): the vendor 404s an unrecognized <code>dir</code> on the <code>GET</code> call, before
/// the async hand-off ever runs, and <method>OcuPilot.Screen.Read.Execute</method>'s generic
/// single-object handling answers that 404 as an empty read (HTTP 200, zero rows) rather than
/// passing the fault through -- the same path <class>OcuPilot.Screen.Descriptor.ProcessDetails</class>
/// documents for an exited process. This screen's stale-id empty state is
/// <code>databaseDetailsGone</code>, "This database no longer exists.", the Task details and
/// Process details pattern.</p>
/// <p><b>A faulted refresh keeps the last values and raises the refresh strip.</b> An auto-refresh
/// tick's <code>INFO</code> call answering non-404 never blanks this screen -- the shared refresh
/// framework's fault handling, not a per-page diff -- because this is one of the seven screens the
/// auto-refresh framework binds (AD-43), at the rates <file>EXPERIENCE.md</file>'s auto-refresh
/// bullet declares.</p>
/// <p><b>One value meter, reusing Story 6.9's component.</b> <code>AvailableSpace</code> and
/// <code>Size</code> are not published in the same unit, so this screen declares its own
/// <code>METER_CONFIGS</code> entry rather than a percentage of the two -- a value meter, no
/// percentage and no state.</p>
/// <p><b>The pair set is Operate alone, not Manage.</b>
/// <code>Database.SysCRUD.ResourcesOR()</code> answers Manage-or-Operate for <code>GET</code> and
/// <code>TYPEINFO</code>, verified on the instance, and the <code>AsyncResult</code> poll
/// <code>TYPEINFO</code> needs requires <code>%Admin_Operate:USE</code> on its own -- so adding
/// <code>%Admin_Manage:USE</code> here would deny the screen to a principal who can read it, the
/// opposite of AD-8's intent. <code>%DB_IRISSYS:READ</code> is the port's own namespace-switch
/// requirement, declared second (AD-8, AD-29).</p>
/// <p><b>The classic page is <code>%CSP.UI.Portal.DatabaseDetails</code></b>, in the class's own
/// case (AD-44). It declares no exemption, so it links out to nothing; it declares no primary or
/// row action, since the database writes are Stage 2.</p>
Class OcuPilot.Screen.Descriptor.DatabaseDetails Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/databases/details",
  "area": "os-management",
  "labelKey": "databaseDetailsLabel",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": true,
  "refreshRates": [5, 10, 30, 60],
  "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "database",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "os-management/databases",
  "id": {"kind": "composite", "parts": ["Directory"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {
    "fields": ["Directory", "MaxSize", "ExpansionSize", "NewVolumeThreshold", "NewVolumeDirectory", "ResourceName", "NewGlobalIsKeep", "NewGlobalCollation", "ClusterMountMode", "ReadOnly", "GlobalJournalState", "Size", "AvailableSpace", "DiskFree", "Mounted"],
    "secretFields": []
  },
  "emptyStateKey": "databaseDetailsGone",
  "commandAliases": ["database details"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupCapacity", "textKey": "databaseDetailsPrompt1"},
    {"groupKey": "promptGroupCapacity", "textKey": "databaseDetailsPrompt2"},
    {"groupKey": "promptGroupCapacity", "textKey": "databaseDetailsPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.DatabaseDetails",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {
      "port": "admin",
      "endpoint": "Database.SysCRUD",
      "type": "GET",
      "rowGet": {
        "key": "dir",
        "param": "dir",
        "type": "INFO",
        "fields": ["Size", "AvailableSpace", "DiskFree", "Mounted"],
        "derived": []
      }
    },
    "fields": ["Directory", "MaxSize", "ExpansionSize", "NewVolumeThreshold", "NewVolumeDirectory", "ResourceName", "NewGlobalIsKeep", "NewGlobalCollation", "ClusterMountMode", "ReadOnly", "GlobalJournalState", "Size", "AvailableSpace", "DiskFree", "Mounted"],
    "filter": ["Directory", "MaxSize", "ExpansionSize", "NewVolumeThreshold", "NewVolumeDirectory", "ResourceName", "NewGlobalIsKeep", "NewGlobalCollation", "ClusterMountMode", "ReadOnly", "GlobalJournalState", "Size", "AvailableSpace", "DiskFree", "Mounted"],
    "sort": {"fields": ["Directory", "MaxSize", "ExpansionSize", "NewVolumeThreshold", "NewVolumeDirectory", "ResourceName", "NewGlobalIsKeep", "NewGlobalCollation", "ClusterMountMode", "ReadOnly", "GlobalJournalState", "Size", "AvailableSpace", "DiskFree", "Mounted"], "default": "Directory", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "dir", "labelKey": "lockColumnDirectory", "kind": "text", "maxLength": 256}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Directory", "labelKey": "lockColumnDirectory", "kind": "name"},
      {"field": "Size", "labelKey": "databaseColumnSize", "kind": "number"},
      {"field": "MaxSize", "labelKey": "databaseColumnMaxSize", "kind": "number"},
      {"field": "AvailableSpace", "labelKey": "databaseColumnAvailable", "kind": "number"},
      {"field": "DiskFree", "labelKey": "databaseColumnDiskFree", "kind": "text"},
      {"field": "Mounted", "labelKey": "databaseColumnMounted", "kind": "status"},
      {"field": "ExpansionSize", "labelKey": "databaseDetailsExpansionSize", "kind": "number"},
      {"field": "NewVolumeThreshold", "labelKey": "databaseDetailsNewVolumeThreshold", "kind": "number"},
      {"field": "NewVolumeDirectory", "labelKey": "databaseDetailsNewVolumeDirectory", "kind": "identifier"},
      {"field": "ResourceName", "labelKey": "webAppColumnResource", "kind": "identifier"},
      {"field": "NewGlobalIsKeep", "labelKey": "databaseDetailsKeepNewGlobals", "kind": "status"},
      {"field": "NewGlobalCollation", "labelKey": "databaseDetailsNewGlobalCollation", "kind": "number"},
      {"field": "ClusterMountMode", "labelKey": "databaseDetailsClusterMountMode", "kind": "status"},
      {"field": "ReadOnly", "labelKey": "databaseDetailsReadOnly", "kind": "status"},
      {"field": "GlobalJournalState", "labelKey": "databaseDetailsJournalNewGlobals", "kind": "status"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "osmgmt.databasedetails"
}
}

}
