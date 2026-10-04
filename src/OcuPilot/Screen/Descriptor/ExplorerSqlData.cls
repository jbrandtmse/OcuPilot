/// <p>System Explorer's Data browser: a schema tree beside one table's or view's rows, a bounded page
/// at a time, rendered as a <code>form-page</code> (AD-5, Story 19.7).</p>
/// <p><b>It declares no <code>read</code></b> (AD-36): its tree issues the SQL schemas, SQL tables and
/// SQL views screens' declared reads (<code>explorer.sqlschemas</code>, <code>explorer.sqltables</code>,
/// <code>explorer.sqlviews</code>), each under that screen's own gate, and its grid posts to its own
/// route, <code>POST /explorer/sql/data</code>, which answers this screen only. So it has no read
/// tool and no context field, and a page's rows never reach screen context (AD-39's sixth
/// exception).</p>
/// <p><b>Its one action, <code>save</code>, sends the grid's staged rows</b> through
/// <class>OcuPilot.Screen.Tool.ExplorerSqlDataSave</class>, an unadvertised write a person's
/// confirmed Save alone reaches (AD-53, Story 19.8).</p>
/// <p><b>Its privilege set is <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter></b>, as SQL
/// Home's; the port also requires READ on the namespace's code databases, resolved at call time, and
/// the instance checks the caller's SQL privileges at each prepare (AD-29, AD-61). It replaces SQL
/// Home's Open Table, <code>%cspapp.exp.utilsqlopen</code>, whose custom resource gates it, and its
/// route also honors the view page's (AD-44). Its id is <code>none</code>, and it does not refresh
/// (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerSqlData Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/sql-data",
  "area": "system-explorer",
  "labelKey": "explorerSqlDataLabel",
  "sideBarPosition": 11,
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
  "rowActions": [{"id": "save", "selfProtection": ""}],
  "context": {"fields": [], "secretFields": []},
  "emptyStateKey": "",
  "commandAliases": ["data browser", "open table", "browse table", "table rows"],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlDataPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlDataPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSqlDataPrompt3"}
  ],
  "classicPage": "%cspapp.exp.utilsqlopen",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "explorer.sqldata"
}
}

}
