/// <p>Fixture descriptor that declares a singular entity noun for no entity type, so the registry's
/// entity-label refusal can be demonstrated over a roster rather than over a value: it declares
/// <code>entityLabelKey</code> while its <code>entityType</code> is empty, which names a label for
/// nothing (AD-5, AD-14).</p>
/// <p>Everything else about it is sound -- its area covers its pairs, its read, table and banner are
/// the declared grammar, and an empty primary entity type is skipped by
/// <method>OcuPilot.Screen.Descriptor.Base.EntityTypes</method> rather than refused by the closed-enum
/// rule above -- so the refusal <method>OcuPilot.Screen.Registry.Validate</method> reports is the
/// entity label's and nothing else's, which is what makes deleting the
/// <method>OcuPilot.Screen.Registry.EntityLabelProblem</method> call from
/// <method>OcuPilot.Screen.Registry.Validate</method> observable.</p>
/// <p>It lives in a package of its own, with its own registry, for the reason
/// <class>OcuPilot.Test.Banner.Bad</class> does: two malformed fixtures in one package would race
/// to be the first problem reported, and each test would stop pinning the refusal it names.</p>
Class OcuPilot.Test.EntityLabel.Bad Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "tasks/bad-entity-label",
  "area": "tasks",
  "labelKey": "taskListLabel",
  "sideBarPosition": 1,
  "archetype": "list",
  "built": false,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Task", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "",
  "entityLabelKey": "proposalEntityTask",
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
  "toolIdentifier": "tasks.badentitylabel"
}
}

}
