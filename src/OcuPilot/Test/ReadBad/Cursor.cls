/// <p>Fixture descriptor declaring a read paged by cursor, which no admin source accepts, so
/// <method>OcuPilot.Screen.Registry.Validate</method>'s read refusal is observed over a roster
/// rather than only as a value. It lives in a package of its own for the reason
/// <class>OcuPilot.Test.Refresh.Bad</class> does.</p>
Class OcuPilot.Test.ReadBad.Cursor Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "web-applications/cursor",
  "area": "web-applications",
  "labelKey": "navAreaWebApplications",
  "sideBarPosition": 1,
  "archetype": "list",
  "built": false,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [],
  "entityType": "web-application",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "context": {"fields": ["Name"], "secretFields": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "WebApp.App", "type": "LIST"},
    "fields": ["Name"],
    "filter": ["Name"],
    "sort": {"fields": ["Name"], "default": "Name", "direction": "asc"},
    "paging": "cursor"
  },
  "toolIdentifier": "webapp.cursor"
}
}

}
