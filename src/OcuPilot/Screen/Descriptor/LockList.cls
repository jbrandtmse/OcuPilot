/// <p>The locks view: every lock the instance holds, read through the vendor's own
/// <class>%Api.Admin.Endpoints.Lock</class> <code>LIST</code> (AD-2, AD-36) and rendered by the
/// <code>list</code> archetype's page from the declared <code>table</code> (AD-5). It is the OS
/// management area's second screen, between Processes and System usage.</p>
/// <p><b>Its scope is <code>instance</code>, and its rows are not filtered by namespace.</b> The
/// lock table is one instance-wide list, so the same rows answer whatever namespace the route
/// names (<class>OcuPilot.Screen.Descriptor.ProcessList</class> records the same reasoning for
/// its own instance-wide table).</p>
/// <p><b>Its id is <code>composite</code>, keyed by <code>DeleteID</code>, not <code>Pid</code>.</b>
/// A process commonly holds several locks, so the row's own key is the vendor's removal
/// identifier -- the single-part composite form <class>OcuPilot.Screen.Descriptor.TaskDetails</class>
/// already uses for <code>Id</code>. <code>Pid</code> is still the <code>name</code> column, but its
/// link opens a different screen (below), not this row's own route.</p>
/// <p><b>The owner cell's <code>rowTarget</code> opens Process details by <code>Pid</code>, not by
/// this row's own id.</b> A row's name cell links to one place (AD-5's <code>rowTarget</code>
/// bullet, added by this story): the field the client encodes is <code>Pid</code>, resolved by
/// <method>OcuPilot.Screen.Registry.RowTargetProblem</method> and
/// <method>OcuPilot.Screen.Registry.RowTargetResolutionProblem</method> and, on the client,
/// ahead of the paired-surface chain in <file>ui/src/app/shell/data-table.ts</file>. Its
/// <code>unless</code> names <code>RemoteOwner</code>: a row a remote client owns has no local pid,
/// so its Process ID cell is text (Story 16.12, DW-1074).</p>
/// <p><b>Its three row actions remove locks</b> (Story 16.12): <code>remove</code>, this lock
/// (<class>OcuPilot.Screen.Tool.LockRemove</class>); <code>removeprocess</code>, every lock of its
/// local owner (<class>OcuPilot.Screen.Tool.LockRemoveProcess</class>); and <code>removeclient</code>,
/// every lock of its remote client (<class>OcuPilot.Screen.Tool.LockRemoveClient</class>). The row
/// menu draws one entry, Remove locks, whose dialog maps the chosen scope to its action. The
/// in-transaction warning is the vendor's own refusal at the removal (DW-1073), so the read carries
/// no <code>Removable</code>, <code>CanBeExamined</code> or transaction field and issues no
/// in-transaction check of its own. <code>RemoteOwner</code> is read and sent as context, and has no
/// column.</p>
/// <p><b>The privilege set is two pairs.</b> <code>%Admin_Operate:USE</code> is the endpoint's own
/// gate (<method>%Api.Admin.Endpoints.Lock.ResourcesOR</method>), which the backing query
/// (<class>%SYS.LockQuery</class>) also checks directly -- the backing query is not stricter, so no
/// third pair is needed the way <class>OcuPilot.Screen.Descriptor.ProcessList</class> needs
/// <code>%Admin_Manage:USE</code>. <code>%DB_IRISSYS:READ</code> is the port's own namespace-switch
/// requirement (<method>OcuPilot.Screen.Registry.ReadProblem</method>'s last arm).</p>
/// <p>It declares no <code>rowGet</code>: every field this screen needs is in the LIST, and
/// <code>context.secretFields</code> is empty because the read carries no secret to strip (AD-24,
/// AD-35). It declares no <code>banner</code>, no primary action, and no refresh pair -- Locks is not
/// among AD-43's auto-refreshing screens.</p>
/// <p>The classic page is <code>%CSP.UI.Portal.LocksView</code>, whose normalized key answers on
/// slot B for the bare class name -- a <code>.zen</code> page normalizes that way, unlike Story
/// 6.9's <code>%cspapp.*</code> key. As a list archetype it links out to nothing
/// (<code>classicLinkExemption.exempt</code> false). The removals perform the classic Manage Locks
/// page's operation and declare it themselves (AD-44).</p>
Class OcuPilot.Screen.Descriptor.LockList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/locks",
  "area": "os-management",
  "labelKey": "lockListLabel",
  "sideBarPosition": 2,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "lock",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["DeleteID"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "remove", "selfProtection": ""}, {"id": "removeprocess", "selfProtection": ""}, {"id": "removeclient", "selfProtection": ""}],
  "context": {"fields": ["Pid", "OSUserName", "RoutineInfo", "ModeCount", "Reference", "Directory", "System", "DeleteID", "RemoteOwner"], "secretFields": []},
  "emptyStateKey": "lockListEmpty",
  "commandAliases": ["locks", "lock table"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "lockListPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "lockListPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "lockListPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.LocksView",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Lock", "type": "LIST"},
    "fields": ["Pid", "OSUserName", "RoutineInfo", "ModeCount", "Reference", "Directory", "System", "DeleteID", "RemoteOwner"],
    "filter": ["Pid", "OSUserName", "RoutineInfo", "ModeCount", "Reference", "Directory", "System"],
    "sort": {"fields": ["Pid", "OSUserName", "RoutineInfo", "ModeCount", "Reference", "Directory", "System"], "default": "Pid", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Pid", "labelKey": "processColumnPid", "kind": "name"},
      {"field": "OSUserName", "labelKey": "processColumnUser", "kind": "text"},
      {"field": "RoutineInfo", "labelKey": "processColumnRoutine", "kind": "identifier"},
      {"field": "ModeCount", "labelKey": "lockColumnMode", "kind": "text"},
      {"field": "Reference", "labelKey": "lockColumnReference", "kind": "identifier"},
      {"field": "Directory", "labelKey": "lockColumnDirectory", "kind": "identifier"},
      {"field": "System", "labelKey": "lockColumnSystem", "kind": "text", "emptyKey": "lockSystemLocal"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "lockListEmptyAgent"
  },
  "rowTarget": {"route": "os-management/processes/details", "field": "Pid", "unless": "RemoteOwner"},
  "toolIdentifier": "osmgmt.locks"
}
}

}
