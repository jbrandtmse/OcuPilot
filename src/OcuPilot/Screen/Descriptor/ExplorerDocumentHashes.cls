/// <p>System Explorer's Document hashes: a SHA-256 hash of the text of each class, routine and include file
/// in the route's namespace that a name pattern matches, with its last-modified time, read through the
/// developer-tool port (<class>OcuPilot.Port.DevToolPort</class>, endpoint <code>DocumentHashes</code>), one
/// row for each document (AD-5, AD-23, AD-36).</p>
/// <p><b>Its criteria are the read itself</b>: <code>spec</code>, which the port refuses when it is absent,
/// is a bare <code>*</code> or matches more documents than one read covers, and <code>generated</code>, which
/// lists generated routines when it is <code>yes</code>.</p>
/// <p><b>Its id is <code>none</code></b>: a row is a document's hash, not an entity. Its scope is
/// <code>namespace</code>, its primary entity type <code>class</code> and its secondary <code>routine</code>, so
/// a change to either re-reads it (AD-14).</p>
/// <p><b>Its privilege set is <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter></b>; the port also
/// requires READ on the namespace's code databases (AD-29). <b>No classic page hashes code</b>, so
/// <code>classicPage</code> is empty (AD-44). It declares no action and does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerDocumentHashes Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/document-hashes",
  "area": "system-explorer",
  "labelKey": "explorerDocumentHashesLabel",
  "sideBarPosition": 14,
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
  "context": {"fields": ["Document", "Hash", "Modified"], "secretFields": []},
  "emptyStateKey": "explorerDevToolEmpty",
  "commandAliases": ["document hashes", "drift hashes"],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerDocumentHashesPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerDocumentHashesPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerDocumentHashesPrompt3"}
  ],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "document with its content hash",
    "source": {"port": "devtool", "endpoint": "DocumentHashes", "type": "LIST"},
    "fields": ["Document", "Hash", "Modified"],
    "filter": ["Document", "Hash"],
    "sort": {"fields": ["Document", "Modified"], "default": "Document", "direction": "asc"},
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
      {"field": "Document", "labelKey": "explorerColumnDocument", "kind": "name"},
      {"field": "Hash", "labelKey": "explorerColumnSha256", "kind": "text"},
      {"field": "Modified", "labelKey": "explorerColumnModified", "kind": "text"}
    ],
    "emptyNextKey": "explorerDocumentHashesInvite",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "explorer.documenthashes"
}
}

}
