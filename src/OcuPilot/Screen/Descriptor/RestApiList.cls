/// <p>The REST API explorer: the REST applications the management API lists for the route's
/// namespace -- which include the instance's own system APIs, whose dispatch classes start with
/// <code>%</code> -- read through the
/// management API's own business logic (<class>OcuPilot.Port.MgmntPort</class>, endpoint
/// <code>Applications</code>) and rendered by the <code>list</code> archetype's page from the
/// declared <code>table</code> (AD-5, AD-36). It is the Web applications area's second screen.</p>
/// <p><b>Its rows are two vendor lists joined.</b> Every web application with a dispatch class the
/// namespace lists, then every spec-based service no listed web application dispatches to. A row
/// carries the web application path or the service's package as <code>Name</code>, its own
/// namespace, its dispatch class, <code>SpecBased</code>, and <code>Enabled</code>, which is
/// <code>null</code> for a service no web application deploys.</p>
/// <p><b>Its scope is <code>namespace</code></b>: the route's namespace is the port's, so switching
/// namespace re-fetches (AD-44). <b>Its id is <code>single</code></b>, the row's <code>Name</code>,
/// which the name cell carries to the OpenAPI document viewer
/// (<class>OcuPilot.Screen.Descriptor.OpenApiViewer</class>).</p>
/// <p><b>The privilege set is <parameter>OcuPilot.Port.MgmntPort.PAIRS</parameter></b>, the
/// web-applications area's own set, which the port evaluates again before any vendor call
/// (AD-8, AD-29).</p>
/// <p>No classic page: the explorer has no classic equivalent, so it declares
/// <code>classicPage</code> empty and links out to nothing (AD-44). It declares no primary or row
/// action and does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.RestApiList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "web-applications/rest-apis",
  "area": "web-applications",
  "labelKey": "restApiListLabel",
  "sideBarPosition": 2,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "rest-service",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Name", "Namespace", "DispatchClass", "SpecBased", "Enabled"], "secretFields": []},
  "emptyStateKey": "restApiListEmpty",
  "commandAliases": ["REST", "REST APIs"],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "mgmnt", "endpoint": "Applications", "type": "LIST"},
    "fields": ["Name", "Namespace", "DispatchClass", "SpecBased", "Enabled"],
    "filter": ["Name", "Namespace", "DispatchClass"],
    "sort": {"fields": ["Name", "Namespace", "DispatchClass"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Namespace", "labelKey": "headerNamespaceLabel", "kind": "identifier"},
      {"field": "DispatchClass", "labelKey": "webAppColumnDispatchClass", "kind": "identifier"},
      {"field": "SpecBased", "labelKey": "restApiColumnSpecBased", "kind": "status"},
      {"field": "Enabled", "labelKey": "tableColumnEnabled", "kind": "status"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "webapp.restapis"
}
}

}
