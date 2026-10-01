/// <p>The Namespaces list: every namespace on this instance with the databases it reads its globals,
/// its routines and its temporary globals from, read through the vendor's own
/// <code>%Api.Admin.Endpoints.Namespace.Namespace</code> <code>LIST</code> (AD-2, AD-36) and rendered
/// by the <code>list</code> archetype's page from the declared <code>table</code> (AD-5). It is OS
/// management's seventh side-bar entry, after Devices.</p>
/// <p><b>Its scope is <code>instance</code></b>: a namespace is CPF configuration, so the same rows
/// answer whatever namespace the route names. Its id is <code>single</code>, the namespace's name,
/// and the name cell opens <class>OcuPilot.Screen.Descriptor.NamespaceForm</class> at this route
/// plus <code>/edit</code>.</p>
/// <p><b>The privilege set is <code>%Admin_Manage:USE</code> and <code>%DB_IRISSYS:READ</code></b>,
/// the endpoint's own <code>ResourcesOR()</code> and the port's switch into <code>%SYS</code>. The
/// namespace tools add the pairs their writes need beyond it (AD-8).</p>
/// <p><b>The classic key is <code>%CSP.UI.Portal.Namespaces</code></b> (AD-44); as a list it links
/// out to nothing. It does not refresh (AD-43).</p>
/// <p>Its primary action is Create, which opens the form. Its row actions are Delete, whose
/// typed-name dialog states the removal's impact (AD-8); Copy mappings, whose dialog names the
/// source namespace and runs <code>osmgmt.namespaces.copymappings</code> (Story 18.14); and Enable
/// interoperability, whose typed-name dialog states the enable's consequence and runs
/// <code>osmgmt.namespaces.enableinterop</code> (Story 18.15). Each runs a namespace tool (AD-53,
/// AD-55).</p>
Class OcuPilot.Screen.Descriptor.NamespaceList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/namespaces",
  "area": "os-management",
  "labelKey": "namespaceListLabel",
  "sideBarPosition": 7,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "namespace",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [{"id": "delete", "selfProtection": ""}, {"id": "copy-mappings", "selfProtection": ""}, {"id": "enable-interop", "selfProtection": ""}],
  "context": {"fields": ["Name", "Globals", "Routines", "TempGlobals"], "secretFields": []},
  "emptyStateKey": "namespaceListEmpty",
  "commandAliases": ["namespaces", "configure namespace"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "namespaceListPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "namespaceListPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "namespaceListPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.Namespaces",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Namespace.Namespace", "type": "LIST"},
    "fields": ["Name", "Globals", "Routines", "TempGlobals"],
    "filter": ["Name", "Globals", "Routines", "TempGlobals"],
    "sort": {"fields": ["Name", "Globals", "Routines", "TempGlobals"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Globals", "labelKey": "namespaceColumnGlobals", "kind": "identifier"},
      {"field": "Routines", "labelKey": "namespaceColumnRoutines", "kind": "identifier"},
      {"field": "TempGlobals", "labelKey": "namespaceColumnTemp", "kind": "identifier"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "namespaceListEmptyAgent"
  },
  "toolIdentifier": "osmgmt.namespaces"
}
}

}
