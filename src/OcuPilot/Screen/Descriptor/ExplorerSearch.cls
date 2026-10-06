/// <p>System Explorer's Search: a plain-text search of the route's namespace's classes and routines,
/// read through the source code API (<class>OcuPilot.Port.AtelierPort</class>, endpoint
/// <code>Search</code>), one row per match in the instance's order (AD-5, AD-36, AD-61).</p>
/// <p><b>Its criteria are the search itself</b>: <code>text</code>, which the port refuses when it
/// is absent, <code>scope</code> (classes and routines, classes, or routines) and <code>case</code>.
/// The port sends the text as plain text over the declared scope's documents and nothing else, so no
/// caller's text runs as a pattern or reaches SQL (AD-61 rule 7).</p>
/// <p><b>A match's line is a row field</b>, untrusted and bounded like any other (AD-24, AD-36,
/// AD-60); no document's text rides beside the rows. Screen context carries each row's document,
/// member, line and text.</p>
/// <p><b>Its id is <code>none</code></b>: a row is a match, not an entity. Its page links each
/// match's document to that document's viewer. Its scope is <code>namespace</code>, its primary
/// entity type <code>class</code> and its secondary <code>routine</code>, so a change to either
/// re-reads it (AD-14).</p>
/// <p><b>Its privilege set is <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter></b>; the port
/// also requires READ on the namespace's code databases (AD-29, AD-61). <b>No classic page searches
/// code</b>, so <code>classicPage</code> is empty (AD-44). It declares no action and does not
/// refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerSearch Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/search",
  "area": "system-explorer",
  "labelKey": "auditCriteriaSearch",
  "sideBarPosition": 3,
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
  "context": {"fields": ["Document", "Member", "Line", "Text"], "secretFields": []},
  "emptyStateKey": "explorerSearchEmpty",
  "commandAliases": ["search code", "find in files"],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSearchPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSearchPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerSearchPrompt3"}
  ],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "atelier", "endpoint": "Search", "type": "LIST"},
    "fields": ["Order", "Document", "Member", "Line", "Attribute", "Text"],
    "filter": ["Document", "Member", "Text"],
    "sort": {"fields": ["Order", "Document"], "default": "Order", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "text", "labelKey": "explorerSearchTextLabel", "kind": "text", "maxLength": 256, "hint": "The text to find, matched literally, so * and commas are searched for as themselves."},
        {"param": "scope", "labelKey": "explorerSearchScopeLabel", "kind": "choice", "maxLength": 8, "options": ["all", "classes", "routines"], "default": "all"},
        {"param": "case", "labelKey": "explorerSearchCaseLabel", "kind": "choice", "maxLength": 3, "options": ["yes", "no"], "default": "no"}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Document", "labelKey": "explorerColumnDocument", "kind": "name"},
      {"field": "Member", "labelKey": "explorerColumnMember", "kind": "identifier"},
      {"field": "Line", "labelKey": "explorerColumnLine", "kind": "number"},
      {"field": "Text", "labelKey": "explorerColumnMatch", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "explorer.search"
}
}

}
