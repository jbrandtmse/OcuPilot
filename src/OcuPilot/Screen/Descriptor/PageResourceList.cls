/// <p>Page resources: every classic page that holds a custom resource, with the resource it holds and the OcuPilot screens that follow it, read
/// through <class>OcuPilot.Port.PortalResourcePort</class> (source kind <code>portalresource</code>, endpoint <code>PortalResource</code>) and
/// rendered by the <code>list</code> archetype's page from the declared <code>table</code> (AD-5, AD-29, AD-36, Story 21.37). It is Permissions'
/// fifth side-bar entry.</p>
/// <p><b>Its pairs</b> are Permissions' own and the port's: <code>%Admin_Secure:USE</code>, which the vendor's call and the classic dialog require, and
/// <code>%DB_IRISSYS:READ</code>, without which the switch to <code>%SYS</code> raises <code>&lt;PROTECT&gt;</code> (AD-8, AD-44).</p>
/// <p><b>Its id is the page's class name</b>, kept exactly (AD-13). The classic page is <code>%CSP.Portal.ResourceDialog</code>, the dialog the
/// classic portal assigns a custom resource from; as a list archetype it links out to nothing. It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.PageResourceList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "permissions/pageresources",
  "area": "permissions",
  "labelKey": "pageResourcesLabel",
  "sideBarPosition": 5,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "page-resource",
  "entityLabelKey": "",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Page", "Resource", "Screen"], "secretFields": []},
  "emptyStateKey": "pageResourcesEmpty",
  "commandAliases": ["page resources"],
  "suggestedPrompts": [
    {"groupKey": "userPromptGroupAccess", "textKey": "pageResourcesPrompt1"},
    {"groupKey": "userPromptGroupAccess", "textKey": "pageResourcesPrompt2"},
    {"groupKey": "userPromptGroupAccess", "textKey": "pageResourcesPrompt3"}
  ],
  "classicPage": "%CSP.Portal.ResourceDialog",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "classic page",
    "source": {"port": "portalresource", "endpoint": "PortalResource", "type": "LIST"},
    "fields": ["Page", "Resource", "Screen"],
    "filter": ["Page", "Resource", "Screen"],
    "sort": {"fields": ["Page", "Resource", "Screen"], "default": "Page", "direction": "asc"},
    "paging": "cap",
    "note": {"key": "pageResourcesNote", "text": "A page's custom resource decides who may open it in the classic portal and in OcuPilot. The instance still checks every read and write."}
  },
  "table": {
    "columns": [
      {"field": "Page", "labelKey": "explorerSqlDataPage", "kind": "name"},
      {"field": "Resource", "labelKey": "webAppColumnResource", "kind": "text"},
      {"field": "Screen", "labelKey": "agentLedgerColumnScreen", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "permissions.pageresources"
}
}

}
