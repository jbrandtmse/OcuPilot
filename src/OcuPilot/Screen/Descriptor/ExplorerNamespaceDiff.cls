/// <p>System Explorer's Compare namespaces: which classes, routines and include files differ between the route's
/// namespace and another namespace of this instance, one row for each document that is in one only or whose content
/// hash differs, read through the developer-tool port (<class>OcuPilot.Port.DevToolPort</class>, endpoint
/// <code>NamespaceDiff</code>) (AD-5, AD-23, AD-36). Nothing leaves the instance.</p>
/// <p><b>Its criteria are the read itself</b>: <code>target</code>, the other namespace, which the port refuses when
/// it is this one, is unknown, or is one the caller may not read; <code>spec</code>, which the port refuses when it is
/// absent, is a bare <code>*</code> or matches more documents than one read covers in either namespace; and
/// <code>generated</code>, which compares generated routines when it is <code>yes</code>.</p>
/// <p><b>Its id is <code>none</code></b>: a row is a document's difference, not an entity. Its scope is
/// <code>namespace</code>, its primary entity type <code>class</code> and its secondary <code>routine</code>, so
/// a change to either re-reads it (AD-14).</p>
/// <p><b>Its privilege set is <code>%Development:USE</code></b>; the port also requires READ on each namespace's code
/// databases (AD-29). <b>No classic page compares namespaces</b>, so <code>classicPage</code> is empty (AD-44). It
/// declares no action and does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerNamespaceDiff Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/namespace-diff",
  "area": "system-explorer",
  "labelKey": "explorerNamespaceDiffLabel",
  "sideBarPosition": 16,
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
  "context": {"fields": ["Document", "Change", "Hash", "OtherHash", "Modified", "OtherModified"], "secretFields": []},
  "emptyStateKey": "explorerNamespaceDiffEmpty",
  "commandAliases": ["compare namespaces", "namespace diff", "environment diff"],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerNamespaceDiffPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerNamespaceDiffPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerNamespaceDiffPrompt3"}
  ],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "document that differs between namespaces",
    "source": {"port": "devtool", "endpoint": "NamespaceDiff", "type": "LIST"},
    "fields": ["Document", "Change", "Hash", "OtherHash", "Modified", "OtherModified"],
    "filter": ["Document", "Change"],
    "sort": {"fields": ["Document", "Modified"], "default": "Document", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "target", "labelKey": "explorerOtherNamespaceLabel", "kind": "text", "maxLength": 64, "hint": "The namespace to compare this one with, spelled as osmgmt.namespaces.read answers its Name."},
        {"param": "spec", "labelKey": "explorerDocumentsLabel", "kind": "text", "maxLength": 256, "hint": "Names separated by commas, with * and ? as wildcards, such as MyApp.*.cls,*.mac."},
        {"param": "generated", "labelKey": "explorerIncludeGeneratedLabel", "kind": "choice", "maxLength": 3, "options": ["yes", "no"], "default": "no"}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Document", "labelKey": "explorerColumnDocument", "kind": "name"},
      {"field": "Change", "labelKey": "databaseDirectoryChange", "kind": "text"},
      {"field": "Modified", "labelKey": "explorerColumnModifiedHere", "kind": "text"},
      {"field": "OtherModified", "labelKey": "explorerColumnModifiedThere", "kind": "text"}
    ],
    "emptyNextKey": "explorerNamespaceDiffInvite",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "explorer.namespacediff"
}
}

}
