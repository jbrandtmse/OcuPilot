/// <p>Fixture descriptor for <class>OcuPilot.Test.ReadDescriptions</class>: a screen whose
/// <code>labelKey</code> names no string in <file>ui/src/app/core/strings.ts</file>, so the generated
/// <class>OcuPilot.Screen.Titles</class> holds no title for it, and whose read declares no <code>row</code>
/// and one secret field. A read tool's description built from it must name the tool identifier alone and
/// carry no row clause.</p>
/// <p>It lives under <package>OcuPilot.Test</package>, which
/// <parameter>OcuPilot.Screen.Registry.DESCRIPTORPACKAGE</parameter> does not enumerate, so it reaches no
/// roster, no route table and no read tool. Nothing but a test names it.</p>
Class OcuPilot.Test.ReadDescriptionsProbe Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "web-applications/read-descriptions-probe",
  "area": "web-applications",
  "labelKey": "readDescriptionsProbeHasNoTitle",
  "sideBarPosition": 0,
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
  "context": {"fields": [], "secretFields": ["Secret"]},
  "secretArguments": [],
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "emptyStateKey": "webAppListEmpty",
  "commandAliases": [],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "WebApp.App", "type": "LIST"},
    "fields": ["Name", "Secret", "Id"],
    "filter": ["Name"],
    "sort": {"fields": ["Name"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [{"field": "Name", "labelKey": "tableColumnName", "kind": "name"}],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "probe.readdescriptions"
}
}

}
