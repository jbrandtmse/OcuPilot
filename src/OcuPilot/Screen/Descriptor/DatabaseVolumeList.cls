/// <p>Volume files: one database's own volume files, read through the vendor's own
/// <code>Database.SysCRUD</code> <code>VOLUMELIST</code> request type (AD-2, AD-36) and rendered by
/// the <code>list</code> archetype's page from the declared <code>table</code> (AD-5), fed into
/// Database details' own "Volume files" section through the one new client mechanism: a page may
/// issue another built screen's declared read (AD-5, this story).</p>
/// <p><b><code>VOLUMELIST</code> joins the source vocabulary, additively, on the
/// <code>UPCOMING</code>/<code>HISTORY</code> precedent</b> (Stories 6.5 and 6.6):
/// <method>OcuPilot.Screen.Registry.ReadProblem</method>'s <code>READSOURCETYPES</code> and its own
/// arm refusing <code>rowGet</code> and <code>forEach</code>, <file>ui/tools/screen-mirror.mjs</file>'s
/// identical arm, the list branch of <method>OcuPilot.Screen.Read.Execute</method>, and
/// <method>OcuPilot.Port.AdminPort</method>'s <code>TYPESUFFIXES</code> -- the vendor publishes it
/// <code>TYPE</code>-prefixed (<code>TYPEVOLUMELIST</code>), so <code>TYPESUFFIXES</code> rather
/// than <code>BARETYPES</code> is the branch of <code>EndpointType</code> that resolves it.
/// A row is a volume file rather than an object, so it declares no <code>rowGet</code> and no
/// <code>forEach</code>: every field this screen needs is in the one vendor answer.</p>
/// <p><b>It is a sub-resource of Databases and never listed</b> (<code>sideBarPosition</code> 0). It
/// declares its parent, <code>parentScope</code> <code>os-management/databases</code>, and takes the
/// same one route-id criterion <class>OcuPilot.Screen.Descriptor.DatabaseDetails</class> does,
/// <code>dir</code>, filled by the client from the route id -- here from Database details' own
/// route, since this screen is reached only through that page's Volume files section rather than
/// its own route being visited directly. No <code>vendorParam</code> is needed: the vendor's own
/// query parameter is already named <code>dir</code>.
/// <method>OcuPilot.Screen.Registry.RouteEntityType</method> answers <code>database</code> for this
/// screen through that parent, while its rows carry no entity type of their own -- a volume file is
/// not a value the closed vocabulary needs a key for, and this screen declares
/// <code>entityType</code> <code>""</code> (a screen with no entity type declares the empty string,
/// <class>OcuPilot.Kernel.EntityType</class>), since it has no write path to route a change event
/// for in this slice.</p>
/// <p><b>Six fields, the whole of the vendor's bare array.</b> <code>VolumeNumber</code>,
/// <code>VolumeDirectory</code>, <code>File</code>, <code>Size</code>,
/// <code>VolumeDirectoryTotalSize</code> and <code>DiskFree</code> -- every member the endpoint
/// answers, verified on the instance. <code>File</code> is the one <code>name</code> column, because
/// a database's own directory is already named on the parent screen and the volume file is what
/// distinguishes one row from the next; its id is <code>composite</code>, keyed by
/// <code>VolumeNumber</code>, the vendor's own ordinal.</p>
/// <p><b>A single-file database still answers one row</b>: <code>VolumeNumber</code> 0,
/// <code>File</code> <code>IRIS.DAT</code>. A database with none -- unreachable in practice, since
/// every mounted database has at least its primary file, but not excluded by this descriptor --
/// reads the empty state <code>databaseVolumeListEmpty</code>, "No volume files for this database."</p>
/// <p><b>The privilege set is <code>%Admin_Manage:USE</code> and <code>%DB_IRISSYS:READ</code>.</b>
/// <code>TYPEVOLUMELIST</code> takes <code>ResourcesOR()</code>'s Manage-only arm, verified on the
/// instance -- the same arm <code>LIST</code> takes and
/// <class>OcuPilot.Screen.Descriptor.DatabaseList</class> declares, not the Manage-or-Operate arm
/// <code>GET</code> and <code>TYPEINFO</code> take. <code>%DB_IRISSYS:READ</code> is the port's own
/// namespace-switch requirement, declared second (AD-8, AD-29).</p>
/// <p><b>The classic key is <code>%CSP.UI.Portal.DatabaseDetails</code></b>, the same page
/// <class>OcuPilot.Screen.Descriptor.DatabaseDetails</class> declares -- the classic portal shows
/// volume files as a section of the same details page rather than as a page of its own.</p>
/// <p>It does not refresh (AD-43): its one criterion runs when Database details opens rather than
/// from a search form, and Database details' own refresh re-issues it every tick regardless. As a
/// list archetype it links out to nothing; it declares no primary or row action, so its empty state
/// names what to do next rather than inviting the agent.</p>
Class OcuPilot.Screen.Descriptor.DatabaseVolumeList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/databases/volumes",
  "area": "os-management",
  "labelKey": "databaseVolumeListLabel",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "os-management/databases",
  "id": {"kind": "composite", "parts": ["VolumeNumber"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["VolumeNumber", "VolumeDirectory", "File", "Size", "VolumeDirectoryTotalSize", "DiskFree"], "secretFields": []},
  "emptyStateKey": "databaseVolumeListEmpty",
  "commandAliases": ["volume files"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupCapacity", "textKey": "databaseVolumeListPrompt1"},
    {"groupKey": "promptGroupCapacity", "textKey": "databaseVolumeListPrompt2"},
    {"groupKey": "promptGroupCapacity", "textKey": "databaseVolumeListPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.DatabaseDetails",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Database.SysCRUD", "type": "VOLUMELIST"},
    "fields": ["VolumeNumber", "VolumeDirectory", "File", "Size", "VolumeDirectoryTotalSize", "DiskFree"],
    "filter": ["VolumeDirectory", "File"],
    "sort": {"fields": ["VolumeNumber", "File", "VolumeDirectory", "Size", "VolumeDirectoryTotalSize", "DiskFree"], "default": "VolumeNumber", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "dir", "labelKey": "lockColumnDirectory", "kind": "text", "maxLength": 256}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "File", "labelKey": "databaseVolumeColumnFile", "kind": "name"},
      {"field": "VolumeNumber", "labelKey": "databaseVolumeColumnVolume", "kind": "number"},
      {"field": "VolumeDirectory", "labelKey": "lockColumnDirectory", "kind": "identifier"},
      {"field": "Size", "labelKey": "databaseColumnSize", "kind": "number"},
      {"field": "VolumeDirectoryTotalSize", "labelKey": "databaseVolumeColumnDirectoryTotal", "kind": "number"},
      {"field": "DiskFree", "labelKey": "databaseColumnDiskFree", "kind": "number"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "osmgmt.databasevolumes"
}
}

}
