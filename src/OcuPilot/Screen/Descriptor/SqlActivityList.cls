/// <p>SQL activity: the SQL statements running on the instance right now, slowest first, read through
/// <class>OcuPilot.Port.SqlActivityPort</class> (AD-29, AD-36) and rendered by the <code>list</code>
/// archetype's page from the declared <code>table</code> (AD-5). OS management's twentieth screen.</p>
/// <p><b>Its scope is <code>instance</code></b>: the rows are every namespace's, so the same rows
/// answer whatever namespace the route names. Its id is the vendor's IdKey, <code>Server</code>,
/// <code>ProcessID</code> and <code>StatementHash</code>.</p>
/// <p><b>Its pairs are the port's</b>, <code>%Admin_Operate:USE</code> and <code>%DB_IRISSYS:READ</code>,
/// which OS management's set covers, so it declares no own pair.</p>
/// <p>The Process ID cell opens Process details by <code>ProcessID</code>, unless <code>Remote</code>
/// reads true: a statement running on another instance has no local process to open (AD-5). A
/// statement whose text the port withholds reads "Not shown". It declares no action: canceling a
/// query is a later catalog row.</p>
/// <p>It joins auto-refresh, default off, as its classic page refreshes (AD-43). The classic page is
/// <code>%CSP.UI.Portal.SQL.CurrentStatements</code>, as <code>NormalizePage</code> answers it; as a
/// list archetype it links out to nothing (AD-44).</p>
Class OcuPilot.Screen.Descriptor.SqlActivityList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/sql-activity",
  "area": "os-management",
  "labelKey": "sqlActivityLabel",
  "sideBarPosition": 20,
  "archetype": "list",
  "built": true,
  "refreshes": true,
  "refreshRates": [5, 10, 30, 60],
  "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "sql-statement",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Server", "ProcessID", "StatementHash"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Server", "ProcessID", "UserName", "Namespace", "RunType", "Elapsed", "Started", "StatementId", "StatementHash", "Statement", "Routine", "CachedQuery", "Workers", "TransactionLevel", "Remote"], "secretFields": []},
  "emptyStateKey": "sqlActivityEmpty",
  "commandAliases": ["sql activity", "running queries", "current statements"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "sqlActivityPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "sqlActivityPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "sqlActivityPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.SQL.CurrentStatements",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "sqlactivity", "endpoint": "CurrentStatements", "type": "LIST"},
    "fields": ["Server", "ProcessID", "UserName", "Namespace", "RunType", "Elapsed", "Started", "StatementId", "StatementHash", "Statement", "Routine", "CachedQuery", "Workers", "TransactionLevel", "Remote"],
    "filter": ["ProcessID", "UserName", "Namespace", "RunType", "Statement", "Routine"],
    "sort": {"fields": ["ProcessID", "UserName", "Namespace", "RunType", "Elapsed", "Started"], "default": "Elapsed", "direction": "desc"},
    "paging": "cap",
    "note": {"key": "sqlActivityNote", "text": "Statement text shows for your own statements, and for another user's when you hold %Development:USE and READ on its namespace's database."}
  },
  "table": {
    "columns": [
      {"field": "ProcessID", "labelKey": "processColumnPid", "kind": "name"},
      {"field": "UserName", "labelKey": "processColumnUser", "kind": "text"},
      {"field": "Namespace", "labelKey": "headerNamespaceLabel", "kind": "text"},
      {"field": "RunType", "labelKey": "sqlActivityColumnRunType", "kind": "text"},
      {"field": "Elapsed", "labelKey": "sqlActivityColumnElapsed", "kind": "number"},
      {"field": "Statement", "labelKey": "explorerSqlColumnStatement", "kind": "identifier", "emptyKey": "sqlActivityTextWithheld"},
      {"field": "Routine", "labelKey": "processColumnRoutine", "kind": "identifier"},
      {"field": "Started", "labelKey": "taskHistoryColumnStarted", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "rowTarget": {"route": "os-management/processes/details", "field": "ProcessID", "unless": "Remote"},
  "toolIdentifier": "osmgmt.sqlactivity"
}
}

}
