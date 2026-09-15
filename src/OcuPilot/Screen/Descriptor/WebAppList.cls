/// <p>The Web applications list: every web application on this instance, read through the vendor's
/// own <code>WebApp.App</code> LIST (AD-2, AD-36) and rendered by the <code>list</code> archetype's
/// page from the declared <code>table</code> (AD-5).</p>
/// <p><b>Its scope is <code>instance</code>, and its rows are not filtered by namespace.</b> A web
/// application is instance configuration keyed by its name alone, so the list is the same whatever
/// namespace the route names (AD-13).</p>
/// <p><b>Its id is <code>single</code>:</b> the application's name, one percent-encoded path segment
/// (<code>/csp/myapp</code> travels as <code>%252Fcsp%252Fmyapp</code>), with no second part.</p>
/// <p><b>The read fields are the LIST row's own keys.</b> The row spells the namespace
/// <code>Namespace</code>; the vendor's GET and PUT bodies spell it <code>NameSpace</code>, and a
/// declared field the row does not carry would project as a <code>null</code> column.
/// <class>OcuPilot.Test.ScreenRead</class> holds every declared field to the live first row.</p>
/// <p><b>The privilege set is the vendor's <code>ResourcesOR()</code> for this endpoint,
/// <code>%Admin_Secure:USE</code>, plus <code>%DB_IRISSYS:READ</code></b>: without the database
/// read the vendor endpoint fails inside <code>%SYS</code> and the port answers 500, so the pair is
/// what turns that into a named refusal (AD-8). <code>%Admin_Secure:USE</code> is also the classic
/// page's own <code>RESOURCE</code>. <class>OcuPilot.Screen.Gate</class> does not add the area's
/// pairs to a screen's, so the screen declares them itself (AD-8, AD-29).</p>
/// <p><b>The classic page is <code>%CSP.UI.Portal.Applications.WebList</code></b>, spelled in the
/// class's own case because the custom-resource lookup does not case-fold (AD-44). As a list
/// archetype it links out to nothing.</p>
/// <p><b>The Namespace column is labelled by <code>headerNamespaceLabel</code></b>, the namespace
/// switch's own accessible name, so the product has one word for a namespace.</p>
/// <p>It declares no primary or row action, so its empty state names what to do next rather than
/// inviting the agent, and it does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.WebAppList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "web-applications/list",
  "area": "web-applications",
  "labelKey": "webAppListLabel",
  "sideBarPosition": 1,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "web-application",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Name", "Namespace", "Type", "Enabled", "DispatchClass", "Resource"], "secretFields": []},
  "emptyStateKey": "webAppListEmpty",
  "commandAliases": ["web apps"],
  "classicPage": "%CSP.UI.Portal.Applications.WebList",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "WebApp.App", "type": "LIST"},
    "fields": ["Name", "Namespace", "Type", "Enabled", "DispatchClass", "Resource"],
    "filter": ["Name", "Namespace", "Type", "DispatchClass", "Resource"],
    "sort": {"fields": ["Name", "Namespace", "Type", "DispatchClass", "Resource"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Namespace", "labelKey": "headerNamespaceLabel", "kind": "identifier"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "Enabled", "labelKey": "tableColumnEnabled", "kind": "status"},
      {"field": "DispatchClass", "labelKey": "webAppColumnDispatchClass", "kind": "identifier"},
      {"field": "Resource", "labelKey": "webAppColumnResource", "kind": "identifier"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "webapp.list"
}
}

}
