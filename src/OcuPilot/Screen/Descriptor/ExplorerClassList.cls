/// <p>System Explorer's Classes list: the classes the route's namespace holds, read through the
/// source code API (<class>OcuPilot.Port.AtelierPort</class>, endpoint <code>Classes</code>) and
/// rendered by the <code>list (server criteria)</code> archetype's page from the declared
/// <code>table</code> (AD-5, AD-36, AD-61). It is the area's first screen.</p>
/// <p><b>Its criteria are the classic Classes page's filters</b>: the name pattern, the system,
/// generated and mapped items, and the modified-time bounds, each applied on the instance before the
/// row cap. A caller that omits one is read with its declared <code>default</code>, the classic
/// page's own, so the screen and its read tool open on the same rows.</p>
/// <p><b>Its scope is <code>namespace</code></b>, and its id is the row's <code>Name</code>, which
/// the name cell carries to the class viewer
/// (<class>OcuPilot.Screen.Descriptor.ExplorerClassDocument</class>).</p>
/// <p><b>Its privilege set is <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter></b>; the port
/// also requires READ on the namespace's code databases, resolved at call time (AD-29, AD-61). It
/// replaces <code>%CSP.UI.Portal.ClassList</code>, whose custom resource also gates it (AD-44). It
/// does not refresh (AD-43).</p>
/// <p><b>Its two row actions act on the checked rows</b> (AD-5, Story 19.2): <code>compile</code>,
/// its <code>multiSelect</code> action, and <code>delete</code>, its one extra action, each over at
/// most <parameter>OcuPilot.Port.AtelierPort.MAXDOCUMENTS</parameter> documents, every row checkable.
/// Their tools are <class>OcuPilot.Screen.Tool.ExplorerClassCompile</class> and
/// <class>OcuPilot.Screen.Tool.ExplorerClassDelete</class>; the page sends one compile per checked
/// document and one delete for the whole set.</p>
Class OcuPilot.Screen.Descriptor.ExplorerClassList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/classes",
  "area": "system-explorer",
  "labelKey": "explorerClassListLabel",
  "sideBarPosition": 1,
  "archetype": "list (server criteria)",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "class",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "compile", "selfProtection": ""}, {"id": "delete", "selfProtection": ""}],
  "context": {"fields": ["Name", "Modified", "Database", "Generated"], "secretFields": []},
  "emptyStateKey": "explorerClassListEmpty",
  "commandAliases": ["classes", "class list", "source code"],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerClassListPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerClassListPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerClassListPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.ClassList",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "atelier", "endpoint": "Classes", "type": "LIST"},
    "fields": ["Name", "Modified", "Database", "Generated"],
    "filter": ["Name", "Database"],
    "sort": {"fields": ["Name", "Modified", "Database"], "default": "Name", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "pattern", "labelKey": "explorerClassPatternLabel", "kind": "text", "maxLength": 256, "default": "*"},
        {"param": "system", "labelKey": "explorerSystemLabel", "kind": "choice", "maxLength": 3, "options": ["yes", "no"], "default": "no"},
        {"param": "generated", "labelKey": "explorerGeneratedLabel", "kind": "choice", "maxLength": 3, "options": ["yes", "no"], "default": "no"},
        {"param": "mapped", "labelKey": "explorerMappedLabel", "kind": "choice", "maxLength": 3, "options": ["yes", "no"], "default": "yes"},
        {"param": "from", "labelKey": "auditCriteriaBegin", "kind": "datetime", "maxLength": 30},
        {"param": "to", "labelKey": "auditCriteriaEnd", "kind": "datetime", "maxLength": 30}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Modified", "labelKey": "explorerColumnModified", "kind": "text"},
      {"field": "Database", "labelKey": "systemInfoDatabase", "kind": "identifier"},
      {"field": "Generated", "labelKey": "explorerColumnGenerated", "kind": "status"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "explorerClassListEmptyAgent"
  },
  "toolIdentifier": "explorer.classes",
  "multiSelect": {"action": "compile", "max": 100, "extraActions": ["delete"]}
}
}

}
