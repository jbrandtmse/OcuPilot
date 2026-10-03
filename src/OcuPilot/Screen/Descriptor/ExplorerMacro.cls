/// <p>System Explorer's Macros: what one macro is defined as, and where, in the context one class or
/// routine of the route's namespace gives it, read through the source code API
/// (<class>OcuPilot.Port.AtelierPort</class>, endpoint <code>Macro</code>) as at most one row (AD-5,
/// AD-36, AD-61).</p>
/// <p><b>Its criteria are the document and the macro</b>, both required by the port. The port reads
/// the document's own text for the include, import and superclass names its macros resolve through,
/// and no caller supplies that context (AD-61 rule 3). A macro nothing in that context defines reads
/// as no row.</p>
/// <p><b>A definition is a row field</b>, untrusted and bounded like any other (AD-24, AD-36,
/// AD-60); the document's text never rides beside the row. Screen context carries the row's macro,
/// document, line and definition.</p>
/// <p><b>Its id is <code>none</code></b>, its scope <code>namespace</code> and its entity type
/// <code>routine</code>, the kind of document a definition lives in. Its privilege set is
/// <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter>, and the port also requires READ on the
/// namespace's code databases (AD-29, AD-61). <b>No classic page looks up a macro</b>, so
/// <code>classicPage</code> is empty (AD-44). It declares no action and does not refresh
/// (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerMacro Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/macros",
  "area": "system-explorer",
  "labelKey": "explorerMacroLabel",
  "sideBarPosition": 5,
  "archetype": "list (server criteria)",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "routine",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Macro", "Document", "Line", "Definition"], "secretFields": []},
  "emptyStateKey": "explorerMacroUndefined",
  "commandAliases": ["macro", "macro definition"],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerMacroPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerMacroPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerMacroPrompt3"}
  ],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "atelier", "endpoint": "Macro", "type": "LIST"},
    "fields": ["Macro", "Document", "Line", "Definition"],
    "filter": ["Macro", "Document", "Definition"],
    "sort": {"fields": ["Macro", "Document"], "default": "Macro", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "document", "labelKey": "explorerColumnDocument", "kind": "text", "maxLength": 256},
        {"param": "macro", "labelKey": "explorerColumnMacro", "kind": "text", "maxLength": 128}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Macro", "labelKey": "explorerColumnMacro", "kind": "name"},
      {"field": "Document", "labelKey": "explorerColumnDocument", "kind": "identifier"},
      {"field": "Line", "labelKey": "explorerColumnLine", "kind": "number"},
      {"field": "Definition", "labelKey": "agentDefinitionFormLabel", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "explorer.macro"
}
}

}
