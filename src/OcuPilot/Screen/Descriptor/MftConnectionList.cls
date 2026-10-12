/// <p>The managed file transfer connections list: every connection this instance defines to a file service
/// (Box, Dropbox or Kiteworks), read through the vendor's own <code>Security.MFT</code> <code>LIST</code> (AD-2,
/// AD-36, Story 18.26) and rendered by the <code>list</code> archetype's page from the declared <code>table</code>
/// (AD-5). It is Security's thirteenth side-bar entry.</p>
/// <p><b>Its id is the connection's name, kept exactly</b> (AD-13): the vendor matches it case-sensitively. It
/// declares no <code>rowGet</code>; the editor reads through its own form route
/// (<class>OcuPilot.Area.Security.MftConnectionRules</class>). <code>IsAuthorized</code> is shown and never set:
/// authorizing a connection is a person's sign-in at the file service, performed on the classic page.</p>
/// <p>Its Create opens <class>OcuPilot.Screen.Descriptor.MftConnectionForm</class>, as does a row's name cell; its
/// row actions Delete and Revoke token are the screen's callers of
/// <class>OcuPilot.Screen.Tool.MftConnectionDelete</class> and <class>OcuPilot.Screen.Tool.MftConnectionRevoke</class>
/// (AD-53).</p>
/// <p><b>Its pairs are Security's</b>, <code>%Admin_Secure:USE</code> and <code>%DB_IRISSYS:READ</code>: a
/// principal holding exactly the two listed, created, read, changed, revoked and deleted a connection (AD-8,
/// measured at Story 18.26's plan). The classic page is <code>%CSP.UI.Portal.MFT.ConnectionList</code>
/// (AD-44).</p>
Class OcuPilot.Screen.Descriptor.MftConnectionList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/mft-connections",
  "area": "security",
  "labelKey": "mftConnectionListLabel",
  "sideBarPosition": 13,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "mft-connection",
  "entityLabelKey": "aboutMftConnection",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [{"id": "delete", "selfProtection": ""}, {"id": "revoke-token", "selfProtection": ""}],
  "context": {"fields": ["Name", "Service", "IsAuthorized"], "secretFields": []},
  "emptyStateKey": "mftConnectionListEmpty",
  "commandAliases": ["managed file transfer", "create mft connection"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "mftConnectionListPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "mftConnectionListPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "mftConnectionListPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.MFT.ConnectionList",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Security.MFT", "type": "LIST"},
    "fields": ["Name", "Service", "IsAuthorized"],
    "filter": ["Name", "Service"],
    "sort": {"fields": ["Name", "Service", "IsAuthorized"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Service", "labelKey": "mftConnectionService", "kind": "text"},
      {"field": "IsAuthorized", "labelKey": "mftConnectionAuthorization", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "mftConnectionListEmptyAgent"
  },
  "toolIdentifier": "security.mftconnections"
}
}

}
