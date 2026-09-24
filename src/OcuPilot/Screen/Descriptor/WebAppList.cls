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
/// <p><b>The singular entity noun is <code>proposalEntityWebApplication</code></b> (AD-5, AD-14):
/// a proposal card's title reads the noun and the target's name, and neither the
/// <code>web-application</code> slug on the wire nor this screen's plural label is that noun.</p>
/// <p><b>The Namespace column is labelled by <code>headerNamespaceLabel</code></b>, the namespace
/// switch's own accessible name, so the product has one word for a namespace.</p>
/// <p><b>No argument of its write tool is secret and no payload field is left out of the
/// fingerprint</b> (AD-3, AD-6): a web application's body carries no credential, and
/// <code>Security.Applications</code> moves no field of its own as a side effect of a PUT. Both
/// lists are declared empty rather than omitted, because a declaration is what the registry's
/// credential-pattern refusal is evaluated against.</p>
/// <p><b>It declares one primary action, <code>create</code></b>, which is what makes it
/// write-capable: the command bar offers Create, the route it opens is the paired form
/// (<class>OcuPilot.Screen.Descriptor.WebAppForm</class>) resolved by convention rather than by a
/// declaration, and the empty state invites the agent instead of naming a next step --
/// <method>OcuPilot.Screen.Registry.TableProblem</method> holds those two keys as a pair. It does
/// not refresh (AD-43). Its write tools, <class>OcuPilot.Screen.Tool.WebAppUpdate</class>,
/// <class>OcuPilot.Screen.Tool.WebAppCreate</class> and <class>OcuPilot.Screen.Tool.WebAppDelete</class>,
/// register by class scan.</p>
/// <p><b>It declares three row actions</b> (AD-5, AD-53), in command-bar order with the
/// destructive one last: <code>enable</code> and <code>disable</code>, both carried out by
/// <class>OcuPilot.Screen.Tool.WebAppUpdate</class> over its one <code>Enabled</code> field, and
/// <code>delete</code>, carried out by <class>OcuPilot.Screen.Tool.WebAppDelete</class>. Each
/// declares the self-protection rule that <i>explains</i> its refusal on OcuPilot's own
/// applications; the refusal itself is AD-10's, evaluated at the write whatever the caller, and no
/// predicate here decides what may be deleted.</p>
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
  "entityLabelKey": "proposalEntityWebApplication",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [
    {"id": "enable", "selfProtection": "serves-ocupilot"},
    {"id": "disable", "selfProtection": "serves-ocupilot"},
    {"id": "delete", "selfProtection": "serves-ocupilot"}
  ],
  "context": {"fields": ["Name", "Namespace", "Type", "Enabled", "DispatchClass", "Resource"], "secretFields": []},
  "secretArguments": [],
  "fingerprintExcludes": [],
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
    "emptyNextKey": "",
    "emptyAgentKey": "webAppListEmptyAgent"
  },
  "toolIdentifier": "webapp.list"
}
}

}
