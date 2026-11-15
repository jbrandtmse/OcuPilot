/// <p>System Explorer's Code metrics: the lines of the route's namespace's classes, routines and include
/// files that a name pattern matches, totalled by kind, read through the developer-tool port
/// (<class>OcuPilot.Port.DevToolPort</class>, endpoint <code>CodeMetrics</code>) as one row (AD-5, AD-23,
/// AD-36).</p>
/// <p><b>Its criteria are the read itself</b>: <code>spec</code>, which the port refuses when it is absent,
/// is a bare <code>*</code> or matches more documents than one read covers, and <code>generated</code>, which
/// counts generated routines when it is <code>yes</code>. The row carries the totals and no per-document list.</p>
/// <p><b>Its id is <code>none</code></b>: the row is a total, not an entity. Its scope is
/// <code>namespace</code>, its primary entity type <code>class</code> and its secondary <code>routine</code>, so
/// a change to either re-reads it (AD-14).</p>
/// <p><b>Its privilege set is <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter></b>; the port also
/// requires READ on the namespace's code databases (AD-29). <b>No classic page counts code</b>, so
/// <code>classicPage</code> is empty (AD-44). It declares no action and does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerCodeMetrics Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/code-metrics",
  "area": "system-explorer",
  "labelKey": "explorerCodeMetricsLabel",
  "sideBarPosition": 13,
  "archetype": "list (server criteria)",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "class",
  "secondaryEntityTypes": ["routine"],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Documents", "Lines", "Code", "CodePercent", "SourceCode", "TestCode", "Comments", "CommentPercent", "Blank", "BlankPercent"], "secretFields": []},
  "emptyStateKey": "explorerDevToolEmpty",
  "commandAliases": ["code metrics", "lines of code", "loc"],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerCodeMetricsPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerCodeMetricsPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerCodeMetricsPrompt3"}
  ],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "line totals of a document set",
    "source": {"port": "devtool", "endpoint": "CodeMetrics", "type": "LIST"},
    "fields": ["Documents", "Lines", "Code", "CodePercent", "SourceCode", "TestCode", "Comments", "CommentPercent", "Blank", "BlankPercent"],
    "filter": [],
    "sort": {"fields": ["Documents", "Lines"], "default": "Documents", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "spec", "labelKey": "explorerDocumentsLabel", "kind": "text", "maxLength": 256, "hint": "Names separated by commas, with * and ? as wildcards, such as MyApp.*.cls,*.mac."},
        {"param": "generated", "labelKey": "explorerIncludeGeneratedLabel", "kind": "choice", "maxLength": 3, "options": ["yes", "no"], "default": "no"}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Documents", "labelKey": "explorerDocumentsLabel", "kind": "name"},
      {"field": "Lines", "labelKey": "explorerColumnLines", "kind": "number"},
      {"field": "Code", "labelKey": "webAppPromptGroupCode", "kind": "number"},
      {"field": "CodePercent", "labelKey": "explorerColumnCodePercent", "kind": "number"},
      {"field": "SourceCode", "labelKey": "explorerColumnSourceCode", "kind": "number"},
      {"field": "TestCode", "labelKey": "explorerColumnTestCode", "kind": "number"},
      {"field": "Comments", "labelKey": "explorerColumnComments", "kind": "number"},
      {"field": "CommentPercent", "labelKey": "explorerColumnCommentPercent", "kind": "number"},
      {"field": "Blank", "labelKey": "explorerColumnBlank", "kind": "number"},
      {"field": "BlankPercent", "labelKey": "explorerColumnBlankPercent", "kind": "number"}
    ],
    "emptyNextKey": "explorerCodeMetricsInvite",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "explorer.codemetrics"
}
}

}
