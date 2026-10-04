/// <p>The ECP data server editor: one data server, created or edited here, rendered by its own
/// <code>form-page</code> (AD-5, Story 18.20). Its Save and the agent's confirmed
/// <code>osmgmt.ecpdataservers.create</code> and <code>osmgmt.ecpdataservers.update</code> are two
/// callers of one tool each (AD-55).</p>
/// <p><b>These screens rely on the admin API's routes alone</b>: the harvested ECP status implementation
/// was never identified (epics.md Story 18.20).</p>
/// <p><b>It takes no side-bar position</b> (<code>sideBarPosition</code> 0): it is reached from
/// <class>OcuPilot.Screen.Descriptor.EcpDataServerList</class>'s Create and a row's name cell, at that
/// list's route with <code>/edit</code> appended. It declares no <code>read</code>: its form read is
/// <code>GET /ecp-data-server/form</code> (<class>OcuPilot.Area.OsMgmt.EcpRules</class>).</p>
/// <p><b>Its pairs are the list's own</b>; saving needs <code>%DB_IRISSYS:WRITE</code> as well, which
/// <class>OcuPilot.Area.OsMgmt.EcpDataServerSave</class> asks before anything is sent. Its classic key
/// is the classic data server dialog (AD-44).</p>
Class OcuPilot.Screen.Descriptor.EcpDataServerForm Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/ecp-data-servers/edit",
  "area": "os-management",
  "labelKey": "aboutEcpDataServer",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "ecp-data-server",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": []},
  "secretArguments": [],
  "fingerprintExcludes": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "ecpDataServerFormPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "ecpDataServerFormPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "ecpDataServerFormPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.Dialog.ECPDataServer",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "osmgmt.ecpdataserverform"
}
}

}
