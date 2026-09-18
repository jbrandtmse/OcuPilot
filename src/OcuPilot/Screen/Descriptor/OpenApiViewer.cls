/// <p>The OpenAPI document viewer: one REST application's OpenAPI document, read through the
/// management API's own business logic (<class>OcuPilot.Port.MgmntPort</class>, endpoint
/// <code>Document</code>) and rendered by the <code>viewer (OpenAPI)</code> archetype's page
/// (AD-5, AD-36).</p>
/// <p><b>Its rows are the document's operations</b>, one per path and verb in document order, each
/// carrying its parameters and response codes; the read's answer also carries the unmodified
/// document as <code>document</code>, which the row cap never cuts and the read tool never sees
/// (<method>OcuPilot.Screen.Tool.Read.View</method> keeps only the rows).</p>
/// <p><b>It is reached from the REST API explorer's name cell and never listed</b>
/// (<code>sideBarPosition</code> 0). Its id is <code>single</code>, the explorer row's
/// <code>Name</code>; the page sends it as the read's one declared criterion,
/// <code>application</code>, which the port accepts only as one exact web application path or one
/// package name.</p>
/// <p><b>Its scope is <code>namespace</code></b> and its privilege set is the explorer's, which the
/// port evaluates again before any vendor call (AD-8, AD-29). Document text is untrusted and renders
/// as text (AD-11).</p>
/// <p>No classic page and no link out (AD-44); no action; no refresh declaration, so Refresh is the
/// page's manual re-read (AD-43).</p>
Class OcuPilot.Screen.Descriptor.OpenApiViewer Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "web-applications/rest-apis/document",
  "area": "web-applications",
  "labelKey": "openApiViewerLabel",
  "sideBarPosition": 0,
  "archetype": "viewer (OpenAPI)",
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
  "context": {"fields": ["Path", "Verb", "Summary", "OperationId"], "secretFields": []},
  "emptyStateKey": "openApiViewerEmpty",
  "commandAliases": [],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "mgmnt", "endpoint": "Document", "type": "LIST"},
    "fields": ["Order", "Path", "Verb", "Summary", "OperationId", "Parameters", "Responses"],
    "filter": ["Path", "Verb", "Summary"],
    "sort": {"fields": ["Order", "Path", "Verb"], "default": "Order", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [{"param": "application", "labelKey": "tableColumnName", "kind": "text", "maxLength": 256}]
    }
  },
  "table": {
    "columns": [
      {"field": "Path", "labelKey": "openApiColumnPath", "kind": "name"},
      {"field": "Verb", "labelKey": "openApiColumnVerb", "kind": "text"},
      {"field": "Summary", "labelKey": "openApiColumnSummary", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "webapp.openapi"
}
}

}
