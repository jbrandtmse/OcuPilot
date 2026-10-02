/// <p>The class viewer: one class's structure as rows, read through the source code API
/// (<class>OcuPilot.Port.AtelierPort</class>, endpoint <code>Class</code>), with its text in the
/// chosen form beside them, and rendered by the <code>viewer (source)</code> archetype's page
/// (AD-5, AD-36, AD-61).</p>
/// <p><b>Its rows are the class and its members</b>: one <code>class</code> row, then one row per
/// parameter, property and method. The read's answer also carries <code>document</code>, the class's
/// source, XML export or generated intermediate code, which the row cap never cuts, the read tool
/// never sees (<method>OcuPilot.Screen.Tool.Read.View</method> keeps only the rows) and screen
/// context never carries; screen context carries each row's kind, name, type and flags.</p>
/// <p><b>It is reached from the Classes list's name cell and never listed</b>
/// (<code>sideBarPosition</code> 0). Its id is the list row's <code>Name</code>, which the page sends
/// as the read's <code>name</code> criterion; <code>form</code> chooses the text.</p>
/// <p><b>Its scope is <code>namespace</code></b> and its privilege set is the list's, which the port
/// evaluates again with the namespace's code databases before any vendor call (AD-29, AD-61). It
/// replaces the classic Classes page's documentation pane, so that page's custom resource gates it
/// too (AD-44). Document text is untrusted and renders as text (AD-11). No action and no refresh
/// declaration (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerClassDocument Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/classes/document",
  "area": "system-explorer",
  "labelKey": "explorerClassDocumentLabel",
  "sideBarPosition": 0,
  "archetype": "viewer (source)",
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
  "rowActions": [],
  "context": {"fields": ["Kind", "Name", "Type", "Flags"], "secretFields": []},
  "emptyStateKey": "explorerClassDocumentEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerClassDocumentPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerClassDocumentPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerClassDocumentPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.ClassList",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "atelier", "endpoint": "Class", "type": "LIST"},
    "fields": ["Order", "Kind", "Name", "Type", "Flags", "Description", "Modified", "Database", "Generates"],
    "filter": ["Name", "Kind"],
    "sort": {"fields": ["Order", "Kind", "Name"], "default": "Order", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "name", "labelKey": "tableColumnName", "kind": "text", "maxLength": 256},
        {"param": "form", "labelKey": "explorerFormLabel", "kind": "choice", "maxLength": 3, "options": ["udl", "xml", "int"], "default": "udl"}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Kind", "labelKey": "agentLedgerColumnKind", "kind": "text"},
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "identifier"},
      {"field": "Flags", "labelKey": "explorerColumnFlags", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "explorer.class"
}
}

}
