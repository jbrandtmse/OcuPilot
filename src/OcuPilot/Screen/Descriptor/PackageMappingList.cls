/// <p>One namespace's package mappings (Story 18.14): a package name and the database the namespace loads its classes from, read through the
/// vendor's own <code>%Api.Admin.Endpoints.Namespace.PackageMappings</code> <code>LIST</code> (AD-2, AD-36)
/// and rendered by the <code>list</code> archetype's page from the declared <code>table</code>
/// (AD-5). It takes no side-bar position: the namespace editor's Mappings line opens it, with the
/// namespace as its route id.</p>
/// <p><b>It is parent-scoped</b> to <class>OcuPilot.Screen.Descriptor.NamespaceList</class>, and its
/// one criterion, <code>namespace</code>, is the route id. The vendor's rows carry no namespace, so
/// the read seeds the criterion's value onto every row under the id's first part
/// (<class>OcuPilot.Screen.Read</class>, AD-36), and a row's composite id
/// <code>[namespace, Name]</code> addresses the mapping its write reaches.</p>
/// <p><b>Its scope is <code>instance</code></b>: a mapping is CPF configuration. It also listens for
/// the <code>namespace</code> entity type, so a copy of mappings into the namespace re-fetches it
/// (AD-14).</p>
/// <p><b>The privilege set is the Namespaces screens' own</b>, <code>%Admin_Manage:USE</code> and
/// <code>%DB_IRISSYS:READ</code>; the mapping tools add <code>%DB_IRISSYS:WRITE</code> (AD-8).</p>
/// <p><b>The classic key is <code>%CSP.UI.Portal.Mappings</code></b> (AD-44), the one classic list of
/// every kind of mapping, whose delete this list's Delete performs. As a list it links out to
/// nothing.</p>
Class OcuPilot.Screen.Descriptor.PackageMappingList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/namespaces/package-mappings",
  "area": "os-management",
  "labelKey": "packageMappingListLabel",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "package-mapping",
  "secondaryEntityTypes": ["namespace"],
  "scope": "instance",
  "parentScope": "os-management/namespaces",
  "id": {"kind": "composite", "parts": ["namespace", "Name"]},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [{"id": "delete", "selfProtection": ""}],
  "context": {"fields": ["namespace", "Name", "Database"], "secretFields": []},
  "emptyStateKey": "packageMappingListEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "packageMappingListPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "packageMappingListPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "packageMappingListPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.Mappings",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Namespace.PackageMappings", "type": "LIST"},
    "fields": ["namespace", "Name", "Database"],
    "filter": ["Name", "Database"],
    "sort": {"fields": ["Name", "Database"], "default": "Name", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [{"param": "namespace", "labelKey": "headerNamespaceLabel", "kind": "text", "maxLength": 64}]
    }
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Database", "labelKey": "systemInfoDatabase", "kind": "identifier"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "packageMappingListEmptyAgent"
  },
  "toolIdentifier": "osmgmt.packagemappings"
}
}

}
