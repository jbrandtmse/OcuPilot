/// <p>Fixture descriptor that declares server-search criteria outside the grammar, so the
/// registry's criteria refusal can be demonstrated over a roster rather than over a value: its one
/// <code>choice</code> criterion declares its <code>maxLength</code> and no <code>options</code>,
/// which
/// <method>OcuPilot.Screen.Registry.CriteriaOptionsProblem</method> refuses because the executor
/// validates a supplied value against that enum before the port is called (AD-21).</p>
/// <p>Everything else about it is sound -- its area covers its pairs, its read and table are the
/// declared grammar -- so the refusal <method>OcuPilot.Screen.Registry.Validate</method> reports is
/// the criteria block's and nothing else's, which is what makes deleting the
/// <code>CriteriaProblem</code> call from <method>Validate</method> observable. The client's own
/// half of that wiring is pinned by <file>ui/tools/screen-mirror.test.mjs</file>, which asserts
/// <code>buildMirror</code> throws for the same shape.</p>
/// <p>It lives in a package of its own, with its own registry, for the reason
/// <class>OcuPilot.Test.Banner.Bad</class> does: two malformed fixtures in one package would race
/// to be the first problem reported, and each test would stop pinning the refusal it names.</p>
Class OcuPilot.Test.Criteria.Bad Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "logs/bad-criteria",
  "area": "logs",
  "labelKey": "auditListLabel",
  "sideBarPosition": 1,
  "archetype": "list (server criteria)",
  "built": false,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "audit-record",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "context": {"fields": ["Event"], "secretFields": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "emptyStateKey": "auditListEmpty",
  "commandAliases": [],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Security.Audit.Record", "type": "LIST"},
    "fields": ["Event"],
    "filter": ["Event"],
    "sort": {"fields": ["Event"], "default": "Event", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [{"param": "authentication", "labelKey": "auditCriteriaAuthentication", "kind": "choice", "maxLength": 50}]
    }
  },
  "table": {
    "columns": [{"field": "Event", "labelKey": "auditColumnEventName", "kind": "name"}],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "logs.badcriteria"
}
}

}
