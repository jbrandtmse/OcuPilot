/// <p>Analytics' Term list entries: the keys and values one term list holds, with each extra field joined as <code>field: value</code>, read through
/// <class>OcuPilot.Port.AnalyticsPort</class> (source kind <code>analytics</code>, endpoint <code>TermListEntries</code>) and rendered from the declared <code>table</code> (AD-5, AD-29, AD-36, AD-44, AD-65,
/// Story 20.11). The whole term list is read before the row cap applies.</p>
/// <p><b>It is a sub-resource of the Term lists list and never listed</b> (<code>sideBarPosition</code> 0): it declares <code>parentScope</code> <code>analytics/term-lists</code> and is reached from that list's
/// name cell. Its one declared criterion, <code>termlist</code>, is the route id, required as a single-object read's is (AD-36); a term list that does not exist reads no rows.</p>
/// <p><b>Its id is the composite <code>[TermList, Key]</code></b>, each part kept exactly (AD-13), and its scope is <code>namespace</code>. Its pairs are the Term lists list's; it offers no action and does not
/// refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.AnalyticsTermListEntryList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "analytics/term-lists/entries",
  "area": "analytics",
  "labelKey": "analyticsTermListEntriesLabel",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%DeepSee_Portal", "permission": "USE"}, {"resource": "%DeepSee_PortalEdit", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%DeepSee_PortalEdit", "permission": "USE"}],
  "entityType": "term-list-entry",
  "secondaryEntityTypes": ["term-list"],
  "scope": "namespace",
  "parentScope": "analytics/term-lists",
  "id": {"kind": "composite", "parts": ["TermList", "Key"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["TermList", "Key", "Value", "Fields"], "secretFields": []},
  "emptyStateKey": "analyticsTermListEntriesEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsTermListEntriesPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "analyticsTermListEntriesPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "analyticsTermListEntriesPrompt3"}
  ],
  "classicPage": "%DeepSee.UI.TermListManager",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "analytics", "endpoint": "TermListEntries", "type": "LIST"},
    "fields": ["TermList", "Key", "Value", "Fields"],
    "filter": ["Key", "Value", "Fields"],
    "sort": {"fields": ["Key", "Value"], "default": "Key", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [{"param": "termlist", "labelKey": "analyticsTermListCriterion", "kind": "text", "maxLength": 255, "hint": "One term list, spelled as analytics.termlists.read answers its Name."}]
    }
  },
  "table": {
    "columns": [
      {"field": "Key", "labelKey": "oauthClientAlgKey", "kind": "name"},
      {"field": "Value", "labelKey": "errorLogColumnValue", "kind": "text"},
      {"field": "Fields", "labelKey": "explorerSqlTabFields", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "analytics.termlistentries"
}
}

}
