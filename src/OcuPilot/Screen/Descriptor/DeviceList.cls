/// <p>The devices list: every configured I/O device on this instance, read through the vendor's
/// own <code>%Api.Admin.Endpoints.Device.Standard</code> <code>LIST</code> (AD-2, AD-36) and
/// rendered by the <code>list</code> archetype's page from the declared <code>table</code>
/// (AD-5). It is OS management's fifth and last side-bar entry, after Databases.</p>
/// <p><b>Its scope is <code>instance</code>, and its rows are not filtered by namespace.</b> A
/// device is CPF configuration, not a namespace-scoped object: the backing query's storage lives
/// in the manager directory's own database, so the same rows answer whatever namespace the route
/// names -- the same reasoning <class>OcuPilot.Screen.Descriptor.DatabaseList</class> gives for
/// its own instance-wide table.</p>
/// <p><b>Its id is <code>single</code>:</b> the device's name, one percent-encoded path segment,
/// with no second part, the same shape <class>OcuPilot.Screen.Descriptor.ResourceList</class>
/// keys by. It declares no <code>rowTarget</code>: this is the only descriptor that names this
/// entity type, so there is nowhere else for the name cell to link.</p>
/// <p><b>Six fields, not the backing query's nine.</b> <code>Prompt</code>,
/// <code>OpenParameters</code> and <code>AlternateDevice</code> are the device editor's fields
/// (Story 8.8), and <code>Prompt</code> and <code>AlternateDevice</code> are empty on every row
/// of a stock instance. <code>Alias</code> is an integer alternate id, rendered as a
/// <code>number</code> column the same way <code>VolumeNumber</code> is on
/// <class>OcuPilot.Screen.Descriptor.DatabaseVolumeList</class>; it reads empty on every stock
/// row, and an empty <code>Alias</code> or <code>Description</code> means absent -- "(none)"
/// already says that, so neither column declares an <code>emptyKey</code>.</p>
/// <p><b>The privilege set is <code>%Admin_Manage:USE</code> and <code>%DB_IRISSYS:READ</code>,
/// established rather than copied</b> (AD-29): <code>Device.Standard.ResourcesOR()</code> answers
/// <code>%Admin_Manage</code> alone, and the backing query,
/// <code>Config.Devices:List</code>, carries no privilege check of its own, so the pair set is
/// exactly the endpoint's gate plus the port's own namespace-switch requirement -- no third pair
/// a real least-privileged principal still refuses.</p>
/// <p><b>The classic key is <code>%CSP.UI.Portal.Config.Devices</code></b>, the Zen list page
/// whose own <code>queryClass</code>/<code>queryName</code> is the same
/// <code>Config.Devices:List</code> this read calls; its own <code>RESOURCE</code> is
/// <code>%Admin_Manage</code>, which AD-44 unions into the gate above with nothing left to add.
/// As a list archetype it links out to nothing (<code>classicLinkExemption.exempt</code> false);
/// the device editor at <code>%CSP.UI.Portal.Config.Device</code> is Story 8.8's page.</p>
/// <p>It declares no <code>rowGet</code>: every field this screen needs is on the LIST row. It
/// declares no primary or row action, so its empty state names what to do next rather than
/// inviting the agent, and it does not refresh -- Devices is not among AD-43's seven
/// auto-refreshing screens.</p>
Class OcuPilot.Screen.Descriptor.DeviceList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/devices",
  "area": "os-management",
  "labelKey": "deviceListLabel",
  "sideBarPosition": 5,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "device",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Name", "PhysicalDevice", "Type", "SubType", "Description", "Alias"], "secretFields": []},
  "emptyStateKey": "deviceListEmpty",
  "commandAliases": ["devices", "device settings"],
  "classicPage": "%CSP.UI.Portal.Config.Devices",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Device.Standard", "type": "LIST"},
    "fields": ["Name", "PhysicalDevice", "Type", "SubType", "Description", "Alias"],
    "filter": ["Name", "PhysicalDevice", "Type", "SubType", "Description", "Alias"],
    "sort": {"fields": ["Name", "PhysicalDevice", "Type", "SubType", "Description", "Alias"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "PhysicalDevice", "labelKey": "deviceColumnPhysical", "kind": "identifier"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "SubType", "labelKey": "deviceColumnSubtype", "kind": "text"},
      {"field": "Description", "labelKey": "tableColumnDescription", "kind": "text"},
      {"field": "Alias", "labelKey": "x509ColumnAlias", "kind": "number"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "osmgmt.devices"
}
}

}
