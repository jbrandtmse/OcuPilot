/// <p>Fixture descriptor: a sound read declared under the tool identifier
/// <code>webapp.twin</code>, which the other descriptor in this package declares too, so
/// <method>OcuPilot.Screen.Registry.Validate</method> and
/// <method>OcuPilot.Screen.Tool.Registry.ListTools</method> are observed refusing the identifier
/// claimed twice.</p>
Class OcuPilot.Test.ReadTwin.One Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "web-applications/twin-one",
  "area": "web-applications",
  "labelKey": "navAreaWebApplications",
  "sideBarPosition": 1,
  "archetype": "list",
  "built": false,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "web-application",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "context": {"fields": ["Name"], "secretFields": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "emptyStateKey": "commandBoxNoMatch",
  "commandAliases": [],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "WebApp.App", "type": "LIST"},
    "fields": ["Name"],
    "filter": ["Name"],
    "sort": {"fields": ["Name"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [{"field": "Name", "labelKey": "fieldUserName", "kind": "name"}],
    "emptyNextKey": "classicLinkCardCaption",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "webapp.twin"
}
}

}
