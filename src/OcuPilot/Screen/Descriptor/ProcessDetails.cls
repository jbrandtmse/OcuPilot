/// <p>Process details: one process's own metrics and identity, read through the vendor's own
/// <code>Process</code> <code>GET</code> (AD-2, AD-26, AD-27, AD-36) and rendered by this screen's
/// own page from the declared <code>table</code> doubling as the field list, grouped into three
/// labeled sections the page draws (AD-5).</p>
/// <p><b>It is a sub-resource of Processes and never listed</b> (<code>sideBarPosition</code> 0). It
/// declares its parent, <code>parentScope</code> <code>os-management/processes</code>, and is
/// reached from that list's <code>Pid</code> cell at
/// <code>os-management/processes/details/&lt;Pid&gt;</code> through 6.7's <code>detailScreenFor</code>
/// chain. Its one declared criterion, <code>pid</code>, is filled by the client from that route id
/// and sent to the vendor under its own name, <code>id</code> (<code>vendorParam</code>).
/// <method>OcuPilot.Screen.Registry.RouteEntityType</method> answers <code>process</code> for this
/// screen, resolved through that parent. <b>Id is <code>Pid</code>, the parent list's own id</b>; GET
/// answers a <code>Pid</code> key of its own, so <method>OcuPilot.Screen.Read</method>'s seeding of
/// the criterion value onto it writes the same value either way.</p>
/// <p><b>An exited process reads as zero rows</b> (AD-37), never a refusal: the vendor answers 404
/// for an unknown pid and this screen's page shows "This process no longer exists." instead of the
/// fields.</p>
/// <p><b>The pair set is three, and the middle one is not the endpoint's own</b> --
/// <code>%Admin_Operate:USE</code> (the endpoint's gate), <code>%Admin_Manage:USE</code> (GET runs
/// <code>SYS.Process:VariableByPid</code> to populate the vendor's own <code>Variables</code> object,
/// which requires it or IRISSYS write) and <code>%DB_IRISSYS:READ</code> (the port runs every
/// endpoint in <code>%SYS</code>) -- the same three <code>OcuPilot.Screen.Descriptor.ProcessList</code>
/// declares, in the same order, since both read the same endpoint (AD-8, AD-29).</p>
/// <p><b>Never named, anywhere</b> (AD-24, AD-35, AD-48): <code>Variables</code> (the process's whole
/// local variable table, which GET always populates whether or not a caller asks for it),
/// <code>CSPSessionID</code>, <code>CurrentSrcLine</code> (source text with literals),
/// <code>LastGlobalReference</code> (subscripts can hold patient identifiers), <code>UserInfo</code>,
/// <code>Roles</code> and <code>LicenseUserId</code>. No <code>CanBe*</code> field either.</p>
/// <p><b>Its row actions are the parent list's four</b> (Story 7.8, AD-53): Suspend, Resume,
/// Terminate and the Terminate dialog's undrawn <code>terminate-with-error</code>. Their write tools
/// name <class>OcuPilot.Screen.Descriptor.ProcessList</class>, so this screen's actions are sent to
/// that list's action route and act on the pid this page shows. Declaring them here is what makes
/// the command bar offer them; its empty state therefore invites the agent with the list's own
/// verbs, though the page draws "This process no longer exists." for a process that has
/// ended.</p>
/// <p><b><code>JobType</code> is declared because a refusal rests on it.</b> It is the
/// authoritative kind of a process -- <code>GET</code>-only, absent from the <code>CONTROLPANEL</code>
/// row behind LIST -- and <method>OcuPilot.Kernel.Proposal.Prohibited.Process</method> refuses a
/// suspend, a resume or a terminate on it, so the operator is shown the field the refusal reads. It takes no
/// table column: the page's three labeled groups are the classic page's, and this is the agent's
/// context rather than a figure a reader compares.</p>
/// <p><b>It is one of the seven screens the shared auto-refresh framework binds</b> (AD-43), at the
/// rates <file>EXPERIENCE.md</file>'s auto-refresh bullet declares. It shows the classic page's
/// three labeled value groups rather than the meter component, which Story 6.9 builds.</p>
/// <p><b>The classic page is <code>%CSP.UI.Portal.ProcessDetails</code></b>, spelled in the class's
/// own case (AD-44); this screen declares no exemption, so it links out to nothing.</p>
Class OcuPilot.Screen.Descriptor.ProcessDetails Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/processes/details",
  "area": "os-management",
  "labelKey": "processDetailsLabel",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": true,
  "refreshRates": [5, 10, 30, 60],
  "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "process",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "os-management/processes",
  "id": {"kind": "composite", "parts": ["Pid"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "suspend", "selfProtection": ""}, {"id": "resume", "selfProtection": ""}, {"id": "terminate", "selfProtection": ""}, {"id": "terminate-with-error", "selfProtection": ""}],
  "context": {
    "fields": ["Pid", "JobType", "ParentPid", "UserName", "LoginRoles", "EscalatedRoles", "OSUserName", "NameSpace", "Priority", "StartTimeUTC", "CPUTime", "CommandsExecuted", "GlobalReferences", "PrivateGlobalReferences", "PrivateGlobalBlockCount", "MemoryAllocated", "MemoryPeak", "MemoryUsed", "CurrentDevice", "OpenDevices", "State", "InTransaction", "Routine", "CurrentLineAndRoutine", "Location", "ClientNodeName", "ClientExecutableName", "ClientIPAddress"],
    "secretFields": []
  },
  "emptyStateKey": "processDetailsGone",
  "commandAliases": ["process details"],
  "classicPage": "%CSP.UI.Portal.ProcessDetails",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {
      "port": "admin",
      "endpoint": "Process",
      "type": "GET"
    },
    "fields": ["Pid", "JobType", "ParentPid", "UserName", "LoginRoles", "EscalatedRoles", "OSUserName", "NameSpace", "Priority", "StartTimeUTC", "CPUTime", "CommandsExecuted", "GlobalReferences", "PrivateGlobalReferences", "PrivateGlobalBlockCount", "MemoryAllocated", "MemoryPeak", "MemoryUsed", "CurrentDevice", "OpenDevices", "State", "InTransaction", "Routine", "CurrentLineAndRoutine", "Location", "ClientNodeName", "ClientExecutableName", "ClientIPAddress"],
    "filter": ["Pid", "ParentPid", "UserName", "LoginRoles", "EscalatedRoles", "OSUserName", "NameSpace", "Priority", "StartTimeUTC", "CPUTime", "CommandsExecuted", "GlobalReferences", "PrivateGlobalReferences", "PrivateGlobalBlockCount", "MemoryAllocated", "MemoryPeak", "MemoryUsed", "CurrentDevice", "OpenDevices", "State", "InTransaction", "Routine", "CurrentLineAndRoutine", "Location", "ClientNodeName", "ClientExecutableName", "ClientIPAddress"],
    "sort": {
      "fields": ["Pid", "ParentPid", "UserName", "LoginRoles", "EscalatedRoles", "OSUserName", "NameSpace", "Priority", "StartTimeUTC", "CPUTime", "CommandsExecuted", "GlobalReferences", "PrivateGlobalReferences", "PrivateGlobalBlockCount", "MemoryAllocated", "MemoryPeak", "MemoryUsed", "CurrentDevice", "OpenDevices", "State", "InTransaction", "Routine", "CurrentLineAndRoutine", "Location", "ClientNodeName", "ClientExecutableName", "ClientIPAddress"],
      "default": "Pid",
      "direction": "asc"
    },
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "pid", "labelKey": "processColumnPid", "kind": "text", "maxLength": 10, "vendorParam": "id"}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Pid", "labelKey": "processColumnPid", "kind": "name"},
      {"field": "ParentPid", "labelKey": "processDetailsParentPid", "kind": "text"},
      {"field": "UserName", "labelKey": "processColumnUser", "kind": "text"},
      {"field": "LoginRoles", "labelKey": "processDetailsLoginRoles", "kind": "text"},
      {"field": "EscalatedRoles", "labelKey": "processDetailsEscalatedRoles", "kind": "text"},
      {"field": "OSUserName", "labelKey": "processDetailsOsUser", "kind": "text"},
      {"field": "NameSpace", "labelKey": "headerNamespaceLabel", "kind": "text"},
      {"field": "Priority", "labelKey": "taskDetailsPriority", "kind": "number"},
      {"field": "StartTimeUTC", "labelKey": "taskHistoryColumnStarted", "kind": "text"},
      {"field": "CPUTime", "labelKey": "processDetailsCpuTime", "kind": "number"},
      {"field": "CommandsExecuted", "labelKey": "processColumnCommands", "kind": "number"},
      {"field": "GlobalReferences", "labelKey": "processDetailsGlobalReferences", "kind": "number"},
      {"field": "PrivateGlobalReferences", "labelKey": "processDetailsPrivateGlobalReferences", "kind": "number"},
      {"field": "PrivateGlobalBlockCount", "labelKey": "processDetailsPrivateGlobalBlocks", "kind": "number"},
      {"field": "MemoryAllocated", "labelKey": "processDetailsMemoryLimit", "kind": "number"},
      {"field": "MemoryPeak", "labelKey": "processDetailsMemoryPeak", "kind": "number"},
      {"field": "MemoryUsed", "labelKey": "processDetailsMemoryUsed", "kind": "number"},
      {"field": "CurrentDevice", "labelKey": "processDetailsCurrentDevice", "kind": "text"},
      {"field": "OpenDevices", "labelKey": "processDetailsOpenDevices", "kind": "text"},
      {"field": "State", "labelKey": "processColumnState", "kind": "text"},
      {"field": "InTransaction", "labelKey": "processDetailsInTransaction", "kind": "text"},
      {"field": "Routine", "labelKey": "processColumnRoutine", "kind": "identifier"},
      {"field": "CurrentLineAndRoutine", "labelKey": "processDetailsSourceLocation", "kind": "identifier"},
      {"field": "Location", "labelKey": "processDetailsLocation", "kind": "text"},
      {"field": "ClientNodeName", "labelKey": "processDetailsClientName", "kind": "text"},
      {"field": "ClientExecutableName", "labelKey": "processDetailsClientExecutable", "kind": "text"},
      {"field": "ClientIPAddress", "labelKey": "processDetailsClientIpAddress", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "processListEmptyAgent"
  },
  "toolIdentifier": "osmgmt.processdetails"
}
}

}
