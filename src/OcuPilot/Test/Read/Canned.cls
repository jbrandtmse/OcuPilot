/// <p>Fixture descriptor declaring a read over a canned list (AD-36): four fields, one of them
/// secret, two filterable and sortable. Its rows come from
/// <class>OcuPilot.Test.EndpointFixture</class>'s <code>list</code> mode, reached through
/// <class>OcuPilot.Test.Read.ReadFixture</class> and <class>OcuPilot.Test.PortFixture</class>.</p>
/// <p>Its <code>context.fields</code> deliberately differ from <code>read.fields</code>, so a tool
/// view projected from the context list rather than the read's fields is observable.</p>
Class OcuPilot.Test.Read.Canned Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "web-applications/canned",
  "area": "web-applications",
  "labelKey": "navAreaWebApplications",
  "sideBarPosition": 1,
  "archetype": "list",
  "built": false,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}],
  "entityType": "web-application",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "context": {"fields": ["Name", "NameSpace", "Secret"], "secretFields": ["Secret"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "classicPage": "OcuPilotTestClassicPageCanned",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "WebApp.App", "type": "LIST"},
    "fields": ["Name", "NameSpace", "Enabled", "Secret"],
    "filter": ["Name", "NameSpace"],
    "sort": {"fields": ["Name", "NameSpace"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "toolIdentifier": "webapp.canned"
}
}

}
