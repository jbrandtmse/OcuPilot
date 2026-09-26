/// <p>The Services list: every service on this instance, read through the vendor's own
/// <code>Security.Service</code> LIST (AD-2, AD-36) and rendered by the <code>list</code>
/// archetype's page from the declared <code>table</code> (AD-5).</p>
/// <p><b>Its scope is <code>instance</code>, and its rows are not filtered by namespace.</b> A
/// service is instance security configuration keyed by its name alone (AD-13).</p>
/// <p><b>Its id is <code>single</code>:</b> the service's name, one percent-encoded path segment,
/// with no second part.</p>
/// <p><b>The eight read fields are the live LIST row's whole key set</b>, in the vendor's own order:
/// <code>Name</code>, <code>Enabled</code>, <code>Public</code>,
/// <code>AuthenticationMethods</code>, <code>AllowedConnections</code>, <code>Description</code>,
/// <code>HttpOnlyCookies</code> and <code>TwoFactorEnabled</code>. <code>Enabled</code> and the last
/// two are booleans, and the two list fields are arrays on every row. It declares no
/// <code>rowGet</code>, because every field the screen shows is already on the LIST row.</p>
/// <p><b>An empty <code>AllowedConnections</code> means unrestricted.</b> The vendor encodes the
/// unrestricted case as <code>[]</code>, and the read and the tool carry that array as it comes;
/// the column declares <code>emptyKey</code> so its empty cell reads "Unrestricted" rather than
/// "(none)", which would read as no address allowed.</p>
/// <p><b>The privilege set is <code>%Admin_Secure:USE</code> and <code>%DB_IRISSYS:READ</code></b>,
/// the Users list's set and order. The first is the vendor's <code>ResourcesOR()</code> and the
/// classic page's own resource; without the second the vendor endpoint fails inside
/// <code>%SYS</code> and the port answers 500 (AD-8).
/// <class>OcuPilot.Test.WireSecurityRead</class> reads the list as a principal holding exactly
/// these pairs and holds its rows to the test account's.</p>
/// <p><b>The classic page is <code>%CSP.UI.Portal.Services</code></b>, in the class's own case
/// (AD-44). As a list archetype it links out to nothing. The context carries no secret field.</p>
/// <p><b>A row's name cell opens <class>OcuPilot.Screen.Descriptor.ServiceForm</class></b>, the reduced
/// form at this list's route with <code>/edit</code> appended (Story 9.9); the form, not this list,
/// carries the classic-portal card. This list's write tool is
/// <class>OcuPilot.Screen.Tool.ServiceUpdate</class>.</p>
/// <p>It declares no primary or row action, so its empty state names what to do next, and it does
/// not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ServiceList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "permissions/services",
  "area": "permissions",
  "labelKey": "serviceListLabel",
  "sideBarPosition": 4,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "service",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Name", "Enabled", "Public", "AuthenticationMethods", "AllowedConnections", "Description", "HttpOnlyCookies", "TwoFactorEnabled"], "secretFields": []},
  "emptyStateKey": "serviceListEmpty",
  "commandAliases": ["security services"],
  "suggestedPrompts": [
    {"groupKey": "sslPromptGroupConnections", "textKey": "serviceListPrompt1"},
    {"groupKey": "userPromptGroupSignIn", "textKey": "serviceListPrompt2"},
    {"groupKey": "sslPromptGroupConnections", "textKey": "serviceListPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.Services",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Security.Service", "type": "LIST"},
    "fields": ["Name", "Enabled", "Public", "AuthenticationMethods", "AllowedConnections", "Description", "HttpOnlyCookies", "TwoFactorEnabled"],
    "filter": ["Name", "Description", "AuthenticationMethods", "AllowedConnections"],
    "sort": {"fields": ["Name", "Description"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Enabled", "labelKey": "tableColumnEnabled", "kind": "status"},
      {"field": "AuthenticationMethods", "labelKey": "serviceColumnAuthentication", "kind": "text"},
      {"field": "AllowedConnections", "labelKey": "serviceColumnAllowedAddresses", "kind": "identifier", "emptyKey": "serviceAllowedUnrestricted"},
      {"field": "Description", "labelKey": "tableColumnDescription", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "permissions.services"
}
}

}
