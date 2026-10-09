/// <p>The percent-class access list: the entries a web application grants access to percent classes and packages
/// of, read through the vendor's <code>WebApp.PctClassAccess</code> <code>LIST</code> (AD-2, AD-36, Story 18.10) and
/// rendered by the <code>list</code> archetype's page from the declared <code>table</code> (AD-5). It is the Web
/// applications area's fifth editor tab, and the list lives on the web application editor, not in the side bar
/// (<code>sideBarPosition</code> 0).</p>
/// <p><b>Its id is the composite <code>[Name, AllowType, Class]</code></b> (AD-13): the vendor addresses one entry by
/// all three, and the first part is folded to lower case (<code>foldfirst</code>), the rest kept exact.</p>
/// <p><b>Its read is filtered by one criterion, <code>application</code></b>, which the editor sends as
/// <code>&lt;name&gt;,all-applications</code>, so an application's own entries and the instance-wide ones are listed
/// together.</p>
/// <p><b>Its pairs are the Web applications area's</b>, <code>%Admin_Secure:USE</code> and <code>%DB_IRISSYS:READ</code>,
/// the pair the vendor's own gate requires (AD-8). The classic page is <code>%CSP.UI.Portal.Applications.Web</code>
/// (AD-44).</p>
Class OcuPilot.Screen.Descriptor.WebAppPctAccessList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "web-applications/list/class-access",
  "area": "web-applications",
  "labelKey": "webAppPctAccessListLabel",
  "sideBarPosition": 0,
  "archetype": "list (server criteria)",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "pct-class-access",
  "entityLabelKey": "pctAccessEntityLabel",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Name", "AllowType", "Class"]},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [{"id": "delete", "selfProtection": "system-pct-access"}],
  "context": {"fields": ["Name", "AllowType", "Class", "AllowAccess", "System"], "secretFields": []},
  "secretArguments": [],
  "fingerprintExcludes": [],
  "emptyStateKey": "webAppPctAccessListEmpty",
  "commandAliases": ["class access", "percent class access"],
  "suggestedPrompts": [
    {"groupKey": "userPromptGroupAccess", "textKey": "webAppPctAccessListPrompt1"},
    {"groupKey": "userPromptGroupAccess", "textKey": "webAppPctAccessListPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "webAppPctAccessListPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.Applications.Web",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "WebApp.PctClassAccess", "type": "LIST"},
    "fields": ["Name", "AllowType", "Class", "AllowAccess", "System"],
    "filter": ["Name", "AllowType", "Class"],
    "sort": {"fields": ["Name", "AllowType", "Class", "AllowAccess", "System"], "default": "Name", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "application", "labelKey": "webAppPctAccessApplication", "kind": "text", "maxLength": 256, "vendorParam": "names", "hint": "The web application whose entries to list, with all-applications for the entries that cover every application."}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "AllowType", "labelKey": "webAppPctAccessColumnAllowType", "kind": "text"},
      {"field": "Class", "labelKey": "webAppPctAccessColumnClass", "kind": "identifier"},
      {"field": "AllowAccess", "labelKey": "webAppPctAccessColumnAllowAccess", "kind": "status"},
      {"field": "System", "labelKey": "webAppPctAccessColumnSystem", "kind": "status"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "webAppPctAccessListEmptyAgent"
  },
  "toolIdentifier": "webapp.pctaccess"
}
}

}
