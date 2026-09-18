/// <p>The General view of Databases: every database on this instance, read through the vendor's own
/// <code>Database.SysCRUD</code> <code>LIST</code> (AD-2, AD-36) and rendered by the
/// <code>list (two views)</code> archetype's page from the declared <code>table</code> (AD-5). It is
/// OS management's fourth side-bar entry, between System usage and the unbuilt Devices.</p>
/// <p><b>Two descriptors, not one</b> (AD-5, this story). <code>DatabaseFreeSpace</code> is the
/// General view's paired second view, switched to by the command bar's View control; the two
/// cannot share one descriptor because the General view's <code>LIST</code> takes
/// <code>%Admin_Manage:USE</code> alone while the Free-space view's async poll takes
/// <code>%Admin_Operate:USE</code> alone, and a descriptor's gate requires every pair it declares
/// (<method>OcuPilot.Screen.Gate.Evaluate</method>) -- one descriptor would deny each view to a
/// principal who could read it.</p>
/// <p><b>Its scope is <code>instance</code>, and its rows are not filtered by namespace.</b> A
/// database is instance configuration keyed by its directory alone (AD-13), the same reasoning
/// <class>OcuPilot.Screen.Descriptor.LockList</class> and
/// <class>OcuPilot.Screen.Descriptor.ProcessList</class> give for their own instance-wide tables.</p>
/// <p><b>Its id is <code>single</code>:</b> the database's directory, one percent-encoded path
/// segment, with no second part -- the same id <class>DatabaseFreeSpace</class> and this screen's
/// paired detail, <class>DatabaseDetails</class>, key their own rows and route by.</p>
/// <p><b><code>MaxSize</code> and <code>Status</code> answer display strings, not the members their
/// names suggest.</b> LIST's <code>MaxSize</code> is <code>"Unlimited"</code> rather than a number --
/// <code>GET</code>'s own <code>MaxSize</code> answers the numeric maximum instead, which is why
/// <class>DatabaseDetails</class> reads it there. <code>Status</code> carries the mount state inside
/// its own text (<code>"Mounted/RW"</code>, <code>"Mounted/R"</code>); LIST answers no separate
/// <code>Mounted</code> boolean of its own, which is why the Free-space view's <code>Mounted</code>
/// column reads its own <code>INFO</code> call instead.</p>
/// <p><b>Nothing secret is read.</b> LIST answers no key password, and
/// <code>context.secretFields</code> is empty because the read carries no secret to strip (AD-24,
/// AD-35).</p>
/// <p><b>The privilege set is <code>%Admin_Manage:USE</code> and <code>%DB_IRISSYS:READ</code>.</b>
/// The first is <code>Database.SysCRUD.ResourcesOR()</code> for <code>LIST</code>, verified on the
/// instance to answer <code>%Admin_Manage</code> alone -- unlike <code>GET</code> and
/// <code>TYPEINFO</code>, which answer Manage-or-Operate, so a General-view reader need not hold
/// Operate the way <class>DatabaseFreeSpace</class>'s reader must. The second is the port's own
/// namespace-switch requirement, every admin read's last pair (AD-8, AD-29).</p>
/// <p><b>The classic key is <code>%CSP.UI.Portal.OpDatabases</code>, not
/// <code>%CSP.UI.Portal.Databases</code>.</b> <code>OpDatabases</code> is the
/// <code>%Admin_Operate</code> page at <code>/csp/sys/op/</code> that carries the literal
/// General/Free-space toggle this pair of descriptors reproduces; AD-44 unions whatever custom
/// resource an operator has assigned that key into this screen's gate, so the choice of key changes
/// the gate. <code>DatabaseFreeSpace</code> declares the same key for the same reason.</p>
/// <p>It is part of the Databases entry in the roster of seven screens the shared auto-refresh
/// framework binds (AD-43) -- <file>EXPERIENCE.md</file> counts screens, and the one entry covers
/// both of this <code>list (two views)</code> screen's views, so eight descriptors declare
/// <code>refreshes</code> against seven named screens -- at the rates
/// <file>EXPERIENCE.md</file>'s auto-refresh bullet declares. As a list archetype it links out to
/// nothing (<code>classicLinkExemption.exempt</code> false); it declares no primary or row action,
/// so its empty state names what to do next rather than inviting the agent -- the database writes
/// are Stage 2.</p>
Class OcuPilot.Screen.Descriptor.DatabaseList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/databases",
  "area": "os-management",
  "labelKey": "databaseListLabel",
  "sideBarPosition": 4,
  "archetype": "list (two views)",
  "built": true,
  "refreshes": true,
  "refreshRates": [5, 10, 30, 60],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "database",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Directory", "Size", "MaxSize", "Status", "Resource"], "secretFields": []},
  "emptyStateKey": "databaseListEmpty",
  "commandAliases": ["databases", "disks"],
  "classicPage": "%CSP.UI.Portal.OpDatabases",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Database.SysCRUD", "type": "LIST"},
    "fields": ["Directory", "Size", "MaxSize", "Status", "Resource"],
    "filter": ["Directory", "Size", "MaxSize", "Status", "Resource"],
    "sort": {"fields": ["Directory", "Size", "MaxSize", "Status", "Resource"], "default": "Directory", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Directory", "labelKey": "lockColumnDirectory", "kind": "name"},
      {"field": "Size", "labelKey": "databaseColumnSize", "kind": "number"},
      {"field": "MaxSize", "labelKey": "databaseColumnMaxSize", "kind": "text"},
      {"field": "Status", "labelKey": "taskHistoryColumnStatus", "kind": "text"},
      {"field": "Resource", "labelKey": "webAppColumnResource", "kind": "identifier"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "osmgmt.databases"
}
}

}
