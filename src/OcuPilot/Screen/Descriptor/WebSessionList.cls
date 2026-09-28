/// <p>The Web sessions list: every CSP session the instance holds, read through the vendor's own
/// <code>WebSession</code> <code>LIST</code> (AD-2, AD-36) and rendered by the <code>list</code>
/// archetype's page from the declared <code>table</code> (AD-5). It is the Web applications area's
/// third entry, after Web applications and the REST API explorer.</p>
/// <p><b>Its scope is <code>instance</code>, and its rows are not filtered by namespace.</b> The
/// session table is one instance-wide list, so the same rows answer whatever namespace the route
/// names.</p>
/// <p><b>Its id is <code>composite</code>, keyed by <code>ID</code></b>, the session id exactly as
/// the instance answers it. <code>SesProcessId</code> is the <code>name</code> column, and its
/// <code>rowTarget</code> opens Process details by that pid, as the Locks list's owner cell does.
/// A session with no process of its own reads "(none)" there and links nowhere.</p>
/// <p><b>The privilege set is two pairs, and one of them is the screen's own</b> (AD-8).
/// <code>%Admin_Operate:USE</code> is the endpoint's gate
/// (<method>%Api.Admin.Endpoints.WebSession.ResourcesOR</method>), which the area's
/// <code>%Admin_Secure:USE</code> does not stand in for; <code>%DB_IRISSYS:READ</code> is the
/// port's namespace-switch requirement. Declaring the first in <code>ownPrivileges</code> keeps Web
/// applications and the REST API explorer open to a holder of the area's two pairs alone.</p>
/// <p>It declares one row action, <code>end</code>, carried out by
/// <class>OcuPilot.Screen.Tool.WebSessionEnd</class>, and its self-protection rule
/// <code>ocupilot-session</code> explains the refusals the kernel makes for a session OcuPilot is
/// itself running in and for a preserve-mode session (AD-10). It declares no refresh (AD-43).</p>
/// <p>The classic page is <code>%CSP.UI.Portal.CSPSessions</code>. As a list archetype it links
/// out to nothing.</p>
Class OcuPilot.Screen.Descriptor.WebSessionList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "web-applications/sessions",
  "area": "web-applications",
  "labelKey": "webSessionListLabel",
  "sideBarPosition": 3,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Admin_Operate", "permission": "USE"}],
  "entityType": "web-session",
  "entityLabelKey": "proposalEntityWebSession",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["ID"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "end", "selfProtection": "ocupilot-session"}],
  "context": {"fields": ["ID", "Username", "Application", "SesProcessId", "Timeout"], "secretFields": []},
  "secretArguments": [],
  "fingerprintExcludes": [],
  "emptyStateKey": "webSessionListEmpty",
  "commandAliases": ["sessions", "CSP sessions"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "webSessionListPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "webSessionListPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "webSessionListPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.CSPSessions",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "WebSession", "type": "LIST"},
    "fields": ["ID", "Username", "Application", "SesProcessId", "Timeout", "Preserve"],
    "filter": ["ID", "Username", "Application", "SesProcessId"],
    "sort": {"fields": ["ID", "Username", "Application", "SesProcessId", "Timeout"], "default": "Application", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "SesProcessId", "labelKey": "processColumnPid", "kind": "name"},
      {"field": "ID", "labelKey": "webSessionColumnSession", "kind": "identifier"},
      {"field": "Username", "labelKey": "processColumnUser", "kind": "text"},
      {"field": "Application", "labelKey": "oauthResourceServerFieldApplication", "kind": "identifier"},
      {"field": "Timeout", "labelKey": "webSessionColumnExpires", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "webSessionListEmptyAgent"
  },
  "rowTarget": {"route": "os-management/processes/details", "field": "SesProcessId"},
  "toolIdentifier": "webapp.sessions"
}
}

}
