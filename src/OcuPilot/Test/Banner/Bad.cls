/// <p>Fixture descriptor that declares a banner outside the grammar, so the registry's banner
/// refusal can be demonstrated over a roster rather than over a value: its
/// <code>banner.cases entry #1 severity</code> is <code>error</code>, which
/// <parameter>OcuPilot.Screen.Registry.BANNERSEVERITIES</parameter> does not hold because the
/// stylesheet carries no <code>.ocu-banner-error</code> variant.</p>
/// <p>Everything else about it is sound -- its area covers its pairs, its read and table are the
/// declared grammar -- so the refusal <method>OcuPilot.Screen.Registry.Validate</method> reports is
/// the banner's and nothing else's, which is what makes deleting the <code>BannerProblem</code> call
/// from <method>Validate</method> observable.</p>
/// <p>It lives in a package of its own, with its own registry, for the reason
/// <class>OcuPilot.Test.AreaPair.Bad</class> does: two malformed fixtures in one package would race
/// to be the first problem reported, and each test would stop pinning the refusal it names.</p>
Class OcuPilot.Test.Banner.Bad Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "tasks/bad-banner",
  "area": "tasks",
  "labelKey": "taskListLabel",
  "sideBarPosition": 1,
  "archetype": "list",
  "built": false,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Task", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "task",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "context": {"fields": ["Name"], "secretFields": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "emptyStateKey": "taskListEmpty",
  "commandAliases": [],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "LIST"},
    "fields": ["Name"],
    "filter": ["Name"],
    "sort": {"fields": ["Name"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [{"field": "Name", "labelKey": "tableColumnName", "kind": "name"}],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "banner": {
    "source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"},
    "field": "Status",
    "cases": [{"equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "error"}]
  },
  "toolIdentifier": "tasks.badbanner"
}
}

}
