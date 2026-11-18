/// <p>System Explorer's Globals list: the globals the route's namespace holds, read through
/// <class>OcuPilot.Port.GlobalPort</class> (endpoint <code>Globals</code>) and rendered by the
/// <code>list (server criteria)</code> archetype's page from the declared <code>table</code> (AD-5, AD-36, AD-29). The agent's
/// <code>explorer.globals.read</code> answers the same rows.</p>
/// <p><b>Its criteria are the classic Globals page's filters</b>: the name pattern and whether system globals are shown, each applied on
/// the instance before the row cap. A caller that omits one is read with its declared <code>default</code>, so the screen and its read
/// tool open on the same rows. A row of a subscript-level mapping is not a global and is never listed.</p>
/// <p><b>Its scope is <code>namespace</code></b>, and its id is the row's <code>Name</code> without a <code>^</code>, which the name
/// cell carries to the node page (<class>OcuPilot.Screen.Descriptor.ExplorerGlobalView</class>), the list's paired document screen.</p>
/// <p><b>Its privilege set is <parameter>OcuPilot.Port.GlobalPort.PAIRS</parameter></b>; the port also requires READ on the namespace's
/// databases, resolved at call time (AD-29). It replaces <code>%CSP.UI.Portal.GlobalList</code>, whose custom resource also gates it
/// (AD-44). It does not refresh (AD-43).</p>
/// <p><b>Its one row action</b>, <code>delete</code>, deletes the whole global through
/// <class>OcuPilot.Screen.Tool.ExplorerGlobalDelete</class>.</p>
Class OcuPilot.Screen.Descriptor.ExplorerGlobalList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/globals",
  "area": "system-explorer",
  "labelKey": "processColumnGlobals",
  "sideBarPosition": 15,
  "archetype": "list (server criteria)",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "global",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "delete", "selfProtection": "protected-global"}],
  "context": {"fields": ["Name", "Database", "Collation", "Journal"], "secretFields": []},
  "emptyStateKey": "explorerGlobalListEmpty",
  "commandAliases": ["globals", "global list"],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerGlobalListPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerGlobalListPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerGlobalListPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.GlobalList",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "global",
    "source": {"port": "global", "endpoint": "Globals", "type": "LIST"},
    "fields": ["Name", "Database", "Collation", "Journal"],
    "filter": ["Name", "Database"],
    "sort": {"fields": ["Name", "Database"], "default": "Name", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "pattern", "labelKey": "tableColumnName", "kind": "text", "maxLength": 256, "default": "*"},
        {"param": "system", "labelKey": "explorerSystemLabel", "kind": "choice", "maxLength": 3, "options": ["yes", "no"], "default": "no"}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Database", "labelKey": "systemInfoDatabase", "kind": "identifier"},
      {"field": "Collation", "labelKey": "mappingColumnCollation", "kind": "text"},
      {"field": "Journal", "labelKey": "systemInfoJournal", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "explorerGlobalListEmptyAgent"
  },
  "toolIdentifier": "explorer.globals"
}
}

}
