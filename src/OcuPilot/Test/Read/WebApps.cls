/// <p>Fixture descriptor declaring a read over the instance's real <code>WebApp.App</code> list,
/// so a read's cap and truncation are observed against the vendor's own class query.</p>
Class OcuPilot.Test.Read.WebApps Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "web-applications/probe",
  "area": "web-applications",
  "labelKey": "navAreaWebApplications",
  "sideBarPosition": 2,
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
  "context": {"fields": ["Name", "NameSpace", "Enabled"], "secretFields": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "classicPage": "OcuPilotTestClassicPageWebApps",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "WebApp.App", "type": "LIST"},
    "fields": ["Name", "NameSpace", "Enabled"],
    "filter": ["Name", "NameSpace"],
    "sort": {"fields": ["Name", "NameSpace"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "toolIdentifier": "webapp.probe"
}
}

}
