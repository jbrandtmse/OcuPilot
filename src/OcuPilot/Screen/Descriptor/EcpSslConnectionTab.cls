/// <p>ECP application servers' second tab, SSL/TLS authorizations: the SSL/TLS computer names this
/// instance has authorized, and the requests pending its authorization, read through the vendor's own
/// <code>ECP.AppServerSSLConnection</code> <code>LIST</code> (AD-2, AD-36, Story 18.21).</p>
/// <p><b>These screens rely on the admin API's routes alone</b>: the harvested ECP status implementation
/// was never identified (epics.md Story 18.21).</p>
/// <p>An unlisted route under the group's first tab, <class>OcuPilot.Screen.Descriptor.EcpAppServerTab</class>,
/// which carries the side-bar entry (AD-5).</p>
/// <p><b>Its id is the SSL computer name</b>, a certificate's distinguished name, kept exactly, because the
/// vendor stores and matches it as given (AD-13). Its row actions are the screen's callers of
/// <class>OcuPilot.Screen.Tool.EcpSslConnectionAuthorize</class>,
/// <class>OcuPilot.Screen.Tool.EcpSslConnectionReject</class> and
/// <class>OcuPilot.Screen.Tool.EcpSslConnectionDelete</class> (AD-53): Authorize and Reject need a row
/// reading <code>Pending</code> (rule <code>ecp-ssl-pending</code>) and Delete one reading
/// <code>Authorized</code> (rule <code>ecp-ssl-authorized</code>), each refused by its tool on both
/// callers with the rule's sentence. A pending request exists only after a real SSL/TLS ECP connection,
/// so on a license without ECP the list holds authorized names alone.</p>
/// <p><b>Its pairs are OS management's</b>; each action adds <code>%DB_IRISSYS:WRITE</code> (AD-8,
/// measured at Task 0). It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.EcpSslConnectionTab Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/ecp-application-servers/ssl",
  "area": "os-management",
  "labelKey": "ecpSslConnectionsLabel",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "ecp-ssl-connection",
  "entityLabelKey": "ecpSslConnectionEntity",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "authorize", "selfProtection": "ecp-ssl-pending"}, {"id": "reject", "selfProtection": "ecp-ssl-pending"}, {"id": "delete", "selfProtection": "ecp-ssl-authorized"}],
  "context": {"fields": ["SSLComputerName", "ClientIP", "Status"], "secretFields": []},
  "emptyStateKey": "ecpSslConnectionListEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "ecpSslConnectionsPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "ecpSslConnectionsPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "ecpSslConnectionsPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.ECPAppServers",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "ECP.AppServerSSLConnection", "type": "LIST"},
    "fields": ["SSLComputerName", "ClientIP", "Status"],
    "filter": ["SSLComputerName", "ClientIP", "Status"],
    "sort": {"fields": ["SSLComputerName", "ClientIP", "Status"], "default": "SSLComputerName", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "SSLComputerName", "labelKey": "ecpSslComputerName", "kind": "name"},
      {"field": "ClientIP", "labelKey": "ecpClientIp", "kind": "identifier"},
      {"field": "Status", "labelKey": "taskHistoryColumnStatus", "kind": "status"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "ecpSslConnectionListEmptyAgent"
  },
  "tab": {"group": "os-management/ecp-application-servers", "position": 2, "labelKey": "ecpSslConnectionsLabel"},
  "toolIdentifier": "osmgmt.ecpsslconnections"
}
}

}
