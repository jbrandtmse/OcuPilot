/// <p>Fixture descriptor that declares a privilege pair its area does not, so the registry's
/// coverage refusal can be demonstrated (DW-266, AD-8): area <code>logs</code> declares
/// <code>%Admin_Operate:USE</code>, <code>%Admin_Secure:USE</code> and
/// <code>%DB_IRISSYS:READ</code>, and this screen requires <code>%Admin_Manage:USE</code>, which is
/// none of them.</p>
/// <p><b>The pair moved with Story 2.10.</b> It was <code>%Admin_Secure:USE</code> until the audit
/// database viewer made the Logs area declare that pair for itself, at which point this fixture was
/// covered and pinned nothing. A later story that puts <code>%Admin_Manage:USE</code> on the Logs
/// area moves it again, to whatever the area still does not declare.</p>
/// <p>It declares <b>no read</b>, so <method>OcuPilot.Screen.Registry.ReadProblem</method> -- which
/// runs first -- finds nothing to refuse, and the coverage refusal this fixture exists for is the
/// one <method>OcuPilot.Screen.Registry.Validate</method> reports.</p>
/// <p>It lives in a package of its own, with its own registry, for the reason
/// <class>OcuPilot.Test.Pair.Bad</class> does: two malformed fixtures in one package would race to
/// be the first problem reported, and each test would stop pinning the refusal it names.</p>
Class OcuPilot.Test.AreaPair.Bad Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "logs/uncovered",
  "area": "logs",
  "labelKey": "navAreaLogs",
  "sideBarPosition": 1,
  "archetype": "list",
  "built": false,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}],
  "entityType": "log-entry",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "context": {"fields": [], "secretFields": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "logs.uncovered"
}
}

}
