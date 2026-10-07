/// <p>The superservers list: every superserver this instance listens on, read through the vendor's own
/// <code>Security.Superserver</code> <code>LIST</code> (AD-2, AD-36, Story 18.25) and rendered by the
/// <code>list</code> archetype's page from the declared <code>table</code> (AD-5). It is Security's twelfth
/// side-bar entry.</p>
/// <p><b>Its id is the composite <code>[Port, BindAddress]</code></b> (AD-13): the vendor addresses one
/// superserver by both, and the list row answers <code>BindAddress</code> <code>0.0.0.0</code> for the
/// all-interfaces one. It declares no <code>rowGet</code>, because the vendor's <code>GET</code> takes two
/// query parameters; the editor reads through its own form route
/// (<class>OcuPilot.Area.Security.SuperserverRules</class>). <code>SystemDefault</code> is shown and never set.</p>
/// <p>Its Create opens <class>OcuPilot.Screen.Descriptor.SuperserverForm</class>, as does a row's port cell;
/// its row action Delete is the screen's caller of <class>OcuPilot.Screen.Tool.SuperserverDelete</class>
/// (AD-53), refused on the superserver the web gateway connects through (AD-10).</p>
/// <p><b>Its pairs are Security's</b>, <code>%Admin_Secure:USE</code> and <code>%DB_IRISSYS:READ</code>: a
/// principal holding exactly the two listed, read, created, changed and deleted a superserver (AD-8, measured
/// at Story 18.25's plan). The classic page is <code>%CSP.UI.Portal.Servers</code> (AD-44).</p>
Class OcuPilot.Screen.Descriptor.SuperserverList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/superservers",
  "area": "security",
  "labelKey": "superserverListLabel",
  "sideBarPosition": 12,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "superserver",
  "entityLabelKey": "aboutSuperserver",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Port", "BindAddress"]},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [{"id": "delete", "selfProtection": ""}],
  "context": {"fields": ["Port", "BindAddress", "Enabled", "SystemDefault"], "secretFields": []},
  "emptyStateKey": "superserverListEmpty",
  "commandAliases": ["superservers", "create superserver"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "superserverListPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "superserverListPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "superserverListPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.Servers",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Security.Superserver", "type": "LIST"},
    "fields": ["Port", "BindAddress", "Enabled", "SystemDefault"],
    "filter": ["Port", "BindAddress"],
    "sort": {"fields": ["Port", "BindAddress", "Enabled", "SystemDefault"], "default": "Port", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Port", "labelKey": "sslTestPort", "kind": "name"},
      {"field": "BindAddress", "labelKey": "languageServerFieldBindAddress", "kind": "identifier"},
      {"field": "Enabled", "labelKey": "tableColumnEnabled", "kind": "status"},
      {"field": "SystemDefault", "labelKey": "superserverSystemDefault", "kind": "status"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "superserverListEmptyAgent"
  },
  "toolIdentifier": "security.superservers"
}
}

}
