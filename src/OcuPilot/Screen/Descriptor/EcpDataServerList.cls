/// <p>ECP data servers: the data servers this instance connects to as an ECP application server, read
/// through the vendor's own <code>ECP.DataServer</code> <code>LIST</code> (AD-2, AD-36, Story 18.20) and
/// rendered by its page from the declared <code>table</code> (AD-5). It is OS management's seventeenth
/// side-bar entry.</p>
/// <p><b>These screens rely on the admin API's routes alone</b>: the harvested ECP status implementation
/// was never identified (epics.md Story 18.20), so each status is what the instance reported when the
/// list was read, and the page says so.</p>
/// <p><b>Its id is the server's name</b>, which the instance stores upper-cased and resolves in any
/// case (AD-13's <code>foldcase</code>). Its Create opens
/// <class>OcuPilot.Screen.Descriptor.EcpDataServerForm</class>, as does a row's name cell; its row
/// actions Change status and Delete are the screen's callers of
/// <class>OcuPilot.Screen.Tool.EcpDataServerChangeStatus</class> and
/// <class>OcuPilot.Screen.Tool.EcpDataServerDelete</class> (AD-53).</p>
/// <p><b>Its pairs are OS management's</b>, <code>%Admin_Manage:USE</code> and
/// <code>%DB_IRISSYS:READ</code>, the classic page's <code>RESOURCE</code>; the create, update and
/// delete add <code>%DB_IRISSYS:WRITE</code> and the status change <code>%Admin_Operate:USE</code>
/// (AD-8, measured at Story 18.20's Task 0).</p>
Class OcuPilot.Screen.Descriptor.EcpDataServerList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/ecp-data-servers",
  "area": "os-management",
  "labelKey": "ecpDataServerListLabel",
  "sideBarPosition": 17,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "ecp-data-server",
  "entityLabelKey": "aboutEcpDataServer",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [{"id": "changestatus", "selfProtection": ""}, {"id": "delete", "selfProtection": ""}],
  "context": {"fields": ["Name", "RemoteAddress", "RemotePort", "Status", "MirrorConnection", "SSLConfig", "BatchMode"], "secretFields": []},
  "emptyStateKey": "ecpDataServerListEmpty",
  "commandAliases": ["ecp data servers", "create ecp data server"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "ecpDataServerListPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "ecpDataServerListPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "ecpDataServerListPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.ECPDataServers",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "ECP.DataServer", "type": "LIST"},
    "fields": ["Name", "RemoteAddress", "RemotePort", "Status", "MirrorConnection", "SSLConfig", "BatchMode"],
    "filter": ["Name", "RemoteAddress", "RemotePort", "Status"],
    "sort": {"fields": ["Name", "RemoteAddress", "RemotePort", "Status"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "RemoteAddress", "labelKey": "languageServerFieldAddress", "kind": "identifier"},
      {"field": "RemotePort", "labelKey": "sslTestPort", "kind": "number"},
      {"field": "Status", "labelKey": "taskHistoryColumnStatus", "kind": "status"},
      {"field": "MirrorConnection", "labelKey": "ecpDataServerMirrorConnection", "kind": "status"},
      {"field": "SSLConfig", "labelKey": "sslListLabel", "kind": "status"},
      {"field": "BatchMode", "labelKey": "ecpDataServerBatchMode", "kind": "status"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "ecpDataServerListEmptyAgent"
  },
  "toolIdentifier": "osmgmt.ecpdataservers"
}
}

}
