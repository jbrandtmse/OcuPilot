/// <p>System Explorer's Document databases: the document databases the route's namespace holds, read
/// through <class>OcuPilot.Port.DocDbPort</class> (source kind <code>docdb</code>, endpoint
/// <code>Databases</code>) and rendered by the <code>list</code> archetype's page from the declared
/// <code>table</code> (AD-5, AD-29, AD-36). It is the area's twelfth side-bar entry.</p>
/// <p><b>Its id is the database's name</b>, which the instance resolves in any case (AD-13's
/// <code>foldcase</code>), and its scope is <code>namespace</code>. Its Create opens the page's create
/// dialog, the screen's caller of <class>OcuPilot.Screen.Tool.ExplorerDocDbCreate</class> through
/// <code>POST /explorer/docdb</code> (AD-55); its row action Delete, labelled Drop, is the screen's caller
/// of <class>OcuPilot.Screen.Tool.ExplorerDocDbDelete</class> (AD-53).</p>
/// <p><b>Its pairs</b> are System Explorer's <code>%Development:USE</code> and, as its own, the two the
/// vendor's DocDB gate checks, <code>%DocDB_Admin:USE</code> and <code>%Service_DocDB:USE</code>; the port
/// adds the namespace's READ pairs at the call and refuses a disabled service 409 (AD-8, AD-29).</p>
/// <p><b>No classic page lists document databases</b>: the classic Doc DB Applications page lists the
/// instance's DocDB application records, a different list, so <code>classicPage</code> is empty (AD-44).
/// It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerDocDbList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/docdb",
  "area": "system-explorer",
  "labelKey": "explorerDocDbListLabel",
  "sideBarPosition": 12,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Development", "permission": "USE"}, {"resource": "%DocDB_Admin", "permission": "USE"}, {"resource": "%Service_DocDB", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%DocDB_Admin", "permission": "USE"}, {"resource": "%Service_DocDB", "permission": "USE"}],
  "entityType": "docdb-database",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [{"id": "delete", "selfProtection": ""}],
  "context": {"fields": ["Name", "Class", "DocumentType", "Resource"], "secretFields": []},
  "emptyStateKey": "explorerDocDbListEmpty",
  "commandAliases": ["document databases", "docdb", "create document database"],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerDocDbListPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerDocDbListPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerDocDbListPrompt3"}
  ],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "docdb", "endpoint": "Databases", "type": "LIST"},
    "fields": ["Name", "Class", "DocumentType", "Resource"],
    "filter": ["Name", "Class", "DocumentType", "Resource"],
    "sort": {"fields": ["Name", "Class", "DocumentType", "Resource"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Class", "labelKey": "explorerClassDocumentLabel", "kind": "identifier"},
      {"field": "DocumentType", "labelKey": "explorerDocDbColumnDocumentType", "kind": "identifier"},
      {"field": "Resource", "labelKey": "webAppColumnResource", "kind": "identifier"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "explorerDocDbListEmptyAgent"
  },
  "toolIdentifier": "explorer.docdb"
}
}

}
