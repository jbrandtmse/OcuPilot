/// <p>External language servers: the instance's gateways (Java, .NET, Python and the rest), read
/// through the admin API's own <code>LanguageServer</code> <code>LIST</code> (AD-2, AD-36) and rendered
/// by the <code>list</code> archetype's page from the declared <code>table</code> (AD-5).</p>
/// <p><b>Running is the vendor's own <code>CurrentlyRunning</code></b>, which the list does not
/// answer: a <code>rowGet</code> issues <code>ACTIVITY</code> per surviving row with the vendor's
/// <code>maxRows</code> 1 and merges that one field (AD-36 as amended, Story 16.10). The table draws it
/// as a <code>status</code> column, Yes or No with its disc.</p>
/// <p><b>Start and Stop are action-style row actions</b> (AD-51), carried out by
/// <class>OcuPilot.Screen.Tool.LanguageServerStart</class> and
/// <class>OcuPilot.Screen.Tool.LanguageServerStop</class> for both callers (AD-53). A server's name
/// opens its Activity log, <class>OcuPilot.Screen.Descriptor.LanguageServerActivity</class>, the list's
/// one parent-scoped child.</p>
/// <p><b>The privilege set is <code>%Admin_ExternalLanguageServerEdit:USE</code> plus
/// <code>%DB_IRISSYS:READ</code></b>, the first declared as the screen's own pair (AD-8 as amended):
/// <code>LanguageServer</code>'s <code>ResourcesOR()</code> names only that resource, and a principal
/// holding exactly these two pairs listed, read, started and stopped servers (measured on
/// <code>ocupilot-ci</code>), so a holder of OS management's set keeps every other OS management
/// screen.</p>
/// <p><b>The classic page is <code>%CSP.UI.Portal.ExternalLanguageServers</code></b> (AD-44). As a list
/// archetype it links out to nothing.</p>
Class OcuPilot.Screen.Descriptor.LanguageServerList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/language-servers",
  "area": "os-management",
  "labelKey": "languageServersLabel",
  "sideBarPosition": 9,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_ExternalLanguageServerEdit", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Admin_ExternalLanguageServerEdit", "permission": "USE"}],
  "entityType": "language-server",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "start", "selfProtection": ""}, {"id": "stop", "selfProtection": ""}],
  "context": {"fields": ["Name", "Type", "Port", "CurrentlyRunning"], "secretFields": []},
  "secretArguments": [],
  "fingerprintExcludes": [],
  "emptyStateKey": "languageServerListEmpty",
  "commandAliases": ["language servers", "gateways", "external servers"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "languageServerListPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "languageServerListPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "languageServerListPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.ExternalLanguageServers",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "LanguageServer", "type": "LIST", "rowGet": {"key": "Name", "param": "name", "type": "ACTIVITY", "fields": ["CurrentlyRunning"], "derived": []}},
    "fields": ["Name", "Type", "Port", "CurrentlyRunning"],
    "filter": ["Name", "Type"],
    "sort": {"fields": ["Name"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "Port", "labelKey": "sslTestPort", "kind": "number"},
      {"field": "CurrentlyRunning", "labelKey": "languageServerColumnRunning", "kind": "status"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "languageServerListEmptyAgent"
  },
  "toolIdentifier": "osmgmt.languageservers"
}
}

}
