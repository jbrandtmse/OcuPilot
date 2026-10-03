/// <p>System Explorer's SQL query: one SQL statement run in the route's namespace, rendered as a
/// <code>form-page</code> (AD-5, Story 19.6).</p>
/// <p><b>It declares no <code>read</code></b> (AD-36): its page posts the statement to the console's
/// own routes, <code>POST /explorer/sql/run</code> and <code>POST /explorer/sql/plan</code>, which
/// answer this screen only, so it has no read tool and no context field, and a statement, its values,
/// its rows and its plan never reach screen context (AD-39's sixth exception).</p>
/// <p><b>Its one row action is <code>run</code></b>: the confirmed run of a statement that changes
/// data, the schema or calls a procedure, carried by
/// <class>OcuPilot.Screen.Tool.ExplorerSqlRun</class> (AD-53), whose target is the literal
/// <code>sql</code> under <code>class</code> in the route's namespace (AD-13). Its id is
/// <code>none</code>.</p>
/// <p><b>Its privilege set is <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter></b>; the port
/// also requires READ on the namespace's code databases, resolved at call time (AD-29, AD-61). It
/// replaces <code>%CSP.UI.Portal.SQL.Home</code>, whose custom resource also gates it and both of its
/// routes (AD-44). It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerSqlQuery Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/sql-query",
  "area": "system-explorer",
  "labelKey": "explorerSqlQueryLabel",
  "sideBarPosition": 10,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "class",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "run", "selfProtection": ""}],
  "context": {"fields": [], "secretFields": []},
  "emptyStateKey": "",
  "commandAliases": ["sql query", "execute query", "run sql"],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlQueryPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlQueryPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlQueryPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.SQL.Home",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "explorer.sqlquery"
}
}

}
