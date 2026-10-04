/// <p>ECP application servers' first tab, Connections: the ECP application servers connected to this
/// instance as their data server, read through the vendor's own <code>ECP.AppServerList</code>
/// <code>LIST</code> (AD-2, AD-36, Story 18.21) and rendered by the <code>detail</code> page over the
/// declared <code>table</code> (AD-5).</p>
/// <p><b>These screens rely on the admin API's routes alone</b>: the harvested ECP status implementation
/// was never identified (epics.md Story 18.21), so each status is what the instance reported when the list
/// was read, which the read's note says.</p>
/// <p><b>It is the tab group's first member and its side-bar entry</b>, OS management's nineteenth entry;
/// the SSL/TLS authorizations tab, <class>OcuPilot.Screen.Descriptor.EcpSslConnectionTab</class>, is an
/// unlisted route under it.</p>
/// <p><b>It administers nothing</b>: <code>entityType</code> is <code>""</code> and its <code>id</code>
/// is <code>none</code> (the License usage tabs' model). It declares no action and does not refresh
/// (AD-43). On a license without ECP no application server can connect, so the list is empty.</p>
/// <p><b>Its pairs are OS management's</b>, <code>%Admin_Manage:USE</code> and
/// <code>%DB_IRISSYS:READ</code>, the classic page's <code>RESOURCE</code> (AD-8).</p>
Class OcuPilot.Screen.Descriptor.EcpAppServerTab Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/ecp-application-servers",
  "area": "os-management",
  "labelKey": "ecpAppServersLabel",
  "sideBarPosition": 19,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["ClientName", "Status", "IPAddress", "IPPort"], "secretFields": []},
  "emptyStateKey": "ecpAppServerListEmpty",
  "commandAliases": ["ecp application servers"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "ecpAppServersPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "ecpAppServersPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "ecpAppServersPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.ECPAppServers",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "ECP.AppServerList", "type": "LIST"},
    "fields": ["ClientName", "Status", "IPAddress", "IPPort"],
    "filter": ["ClientName", "Status", "IPAddress"],
    "sort": {"fields": ["ClientName", "Status", "IPAddress", "IPPort"], "default": "ClientName", "direction": "asc"},
    "paging": "cap",
    "note": {"key": "ecpDataServerStatusCaveat", "text": "Each status is what the instance reported when this list was read."}
  },
  "table": {
    "columns": [
      {"field": "ClientName", "labelKey": "processDetailsClientName", "kind": "name"},
      {"field": "Status", "labelKey": "taskHistoryColumnStatus", "kind": "status"},
      {"field": "IPAddress", "labelKey": "ecpClientIp", "kind": "identifier"},
      {"field": "IPPort", "labelKey": "sslTestPort", "kind": "number"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "tab": {"group": "os-management/ecp-application-servers", "position": 1, "labelKey": "sslPromptGroupConnections"},
  "toolIdentifier": "osmgmt.ecpappservers"
}
}

}
