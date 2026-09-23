/// <p>The Resources list: every resource on this instance, read through the vendor's own
/// <code>Security.Resource</code> LIST (AD-2, AD-36) and rendered by the <code>list</code>
/// archetype's page from the declared <code>table</code> (AD-5).</p>
/// <p><b>Its scope is <code>instance</code>, and its rows are not filtered by namespace.</b> A
/// resource is instance security configuration keyed by its name alone (AD-13).</p>
/// <p><b>Its id is <code>single</code>:</b> the resource's name, one percent-encoded path segment,
/// with no second part.</p>
/// <p><b>The five read fields are the live LIST row's whole key set</b>, in the vendor's own order:
/// <code>Name</code>, <code>Description</code>, <code>PublicPermission</code>,
/// <code>ResourceType</code> and <code>AllowDelete</code>, the last a boolean. It declares no
/// <code>rowGet</code>, because every field the screen shows is already on the LIST row.</p>
/// <p><b>Deletable is the vendor's own <code>AllowDelete</code>, as a <code>text</code> column.</b>
/// A system resource reads No; a status disc would draw a deletable resource in the healthy colour,
/// so the word carries the state.</p>
/// <p><b>The privilege set is <code>%Admin_Secure:USE</code> and <code>%DB_IRISSYS:READ</code></b>,
/// the Users list's set and order. The first is the vendor's <code>ResourcesOR()</code> and the
/// classic page's own resource; without the second the vendor endpoint fails inside
/// <code>%SYS</code> and the port answers 500 (AD-8).
/// <class>OcuPilot.Test.WireSecurityRead</class> reads the list as a principal holding exactly
/// these pairs and holds its rows to the test account's.</p>
/// <p><b>The classic page is <code>%CSP.UI.Portal.Resources</code></b>, in the class's own case
/// (AD-44). As a list archetype it links out to nothing. The context carries no secret field.</p>
/// <p><b>Its primary action is Create</b>, which opens the resource editor as a dialog over the
/// list; a row's name cell opens the same editor for that resource through the list's own id route.
/// Both save through the resource tools (AD-55). It declares no row action, and its empty state
/// invites the agent. It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ResourceList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "permissions/resources",
  "area": "permissions",
  "labelKey": "resourceListLabel",
  "sideBarPosition": 3,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "resource",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Name", "Description", "PublicPermission", "ResourceType", "AllowDelete"], "secretFields": []},
  "emptyStateKey": "resourceListEmpty",
  "commandAliases": ["security resources"],
  "classicPage": "%CSP.UI.Portal.Resources",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Security.Resource", "type": "LIST"},
    "fields": ["Name", "Description", "PublicPermission", "ResourceType", "AllowDelete"],
    "filter": ["Name", "Description", "PublicPermission", "ResourceType"],
    "sort": {"fields": ["Name", "Description", "PublicPermission", "ResourceType"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Description", "labelKey": "tableColumnDescription", "kind": "text"},
      {"field": "PublicPermission", "labelKey": "resourceColumnPublicPermission", "kind": "text"},
      {"field": "ResourceType", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "AllowDelete", "labelKey": "resourceColumnDeletable", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "resourceListEmptyAgent"
  },
  "toolIdentifier": "permissions.resources"
}
}

}
