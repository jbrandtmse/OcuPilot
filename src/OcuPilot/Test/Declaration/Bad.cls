/// <p>Fixture descriptor declaring an unknown top-level key (<code>banners</code>), so
/// <method>OcuPilot.Screen.Registry.Validate</method>'s own call to
/// <method>OcuPilot.Screen.Registry.DeclarationProblem</method> can be demonstrated over a roster
/// rather than over a value (DW-306). <class>OcuPilot.Test.DeclarationCorpus</class> already pins
/// every case of the rule itself, driven directly from <class>OcuPilot.Test.ReadTool</class>; what
/// this adds is that <method>Validate</method> calls the rule at all -- deleting that call site
/// reddens nothing there, because the corpus calls <method>DeclarationProblem</method> directly and
/// the shipped roster is sound either way.</p>
/// <p>Everything else about it is sound, so the refusal <method>Validate</method> reports is the
/// unknown key's and nothing else's. It lives in a package of its own, with its own registry
/// (<class>OcuPilot.Test.DeclarationRegistry</class>), for the reason
/// <class>OcuPilot.Test.Banner.Bad</class> does: two malformed fixtures in one package would race
/// to be the first problem reported, and each test would stop pinning the refusal it names.</p>
Class OcuPilot.Test.Declaration.Bad Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "tasks/bad-declaration",
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
  "toolIdentifier": "tasks.baddeclaration",
  "banners": []
}
}

}
