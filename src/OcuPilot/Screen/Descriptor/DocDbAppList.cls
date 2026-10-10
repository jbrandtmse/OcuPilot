/// <p>The Doc DB applications list: every Doc DB application record this instance holds, read through the vendor's own
/// <code>DocDB</code> <code>LIST</code> (AD-2, AD-36, Story 18.30) and rendered by the <code>list</code> archetype's
/// page from the declared <code>table</code> (AD-5). It is the Web applications area's fourth side-bar entry.</p>
/// <p><b>Its id is the composite <code>[Namespace, Name]</code></b> (AD-13): the instance resolves both parts in any
/// case, so the id takes <code>foldcase</code>. It declares no <code>rowGet</code>; the editor reads through its own
/// form route (<class>OcuPilot.Area.WebApp.DocDbAppRules</class>). These are the <code>Security.DocDBs</code> records
/// behind the classic Doc DB applications pages and nothing else: the document databases of System Explorer are
/// another screen.</p>
/// <p>Its Create opens <class>OcuPilot.Screen.Descriptor.DocDbAppForm</class>, as does a row's name cell; its row
/// action Delete is the screen's caller of <class>OcuPilot.Screen.Tool.DocDbAppDelete</class> (AD-53).</p>
/// <p><b>Its pairs are the Web applications area's</b>, <code>%Admin_Secure:USE</code> and
/// <code>%DB_IRISSYS:READ</code>: a principal holding exactly those two and read on the install namespace's code
/// database listed, created and deleted a record (AD-8, measured at Story 18.30's plan). The classic page is
/// <code>%CSP.UI.Portal.Applications.DocDBList</code> (AD-44).</p>
Class OcuPilot.Screen.Descriptor.DocDbAppList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "web-applications/docdb-applications",
  "area": "web-applications",
  "labelKey": "docDbAppListLabel",
  "sideBarPosition": 4,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "docdb-application",
  "entityLabelKey": "aboutDocDbApplication",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Namespace", "Name"]},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [{"id": "delete", "selfProtection": ""}],
  "context": {"fields": ["Name", "Namespace", "Enabled", "Resource", "Description"], "secretFields": []},
  "emptyStateKey": "docDbAppListEmpty",
  "commandAliases": ["doc db applications", "create doc db application"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "docDbAppListPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "docDbAppListPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "docDbAppListPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.Applications.DocDBList",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "DocDB", "type": "LIST"},
    "fields": ["Name", "Namespace", "Enabled", "Resource", "Description"],
    "filter": ["Name", "Namespace", "Resource", "Description"],
    "sort": {"fields": ["Name", "Namespace", "Enabled", "Resource", "Description"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Namespace", "labelKey": "headerNamespaceLabel", "kind": "identifier"},
      {"field": "Enabled", "labelKey": "tableColumnEnabled", "kind": "status"},
      {"field": "Resource", "labelKey": "webAppColumnResource", "kind": "identifier"},
      {"field": "Description", "labelKey": "tableColumnDescription", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "docDbAppListEmptyAgent"
  },
  "toolIdentifier": "webapp.docdbapps"
}
}

}
