/// <p>Analytics' Term lists: the term lists the namespace holds, with each one's caption and the date it was last changed, read through
/// <class>OcuPilot.Port.AnalyticsPort</class> (source kind <code>analytics</code>, endpoint <code>TermLists</code>) and rendered by the <code>list</code> archetype's page from the declared
/// <code>table</code> (AD-5, AD-29, AD-36, AD-44, AD-65, Story 20.11).</p>
/// <p><b>A term list's name opens its entries</b>: <code>analytics/term-lists/entries/&lt;term list&gt;</code> declares this list's route as its <code>parentScope</code>. <b>Its id is the term list's name</b>,
/// kept exactly (AD-13), and its scope is <code>namespace</code>.</p>
/// <p><b>Its pairs</b> are the classic Term List Manager's: <code>%DeepSee_Portal:USE</code> and, as its own, <code>%DeepSee_PortalEdit:USE</code>; the port also checks READ on the namespace's databases
/// before any vendor call (AD-8, AD-65). It offers no action and does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.AnalyticsTermListList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "analytics/term-lists",
  "area": "analytics",
  "labelKey": "analyticsTermListsLabel",
  "sideBarPosition": 2,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%DeepSee_Portal", "permission": "USE"}, {"resource": "%DeepSee_PortalEdit", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%DeepSee_PortalEdit", "permission": "USE"}],
  "entityType": "term-list",
  "secondaryEntityTypes": ["term-list-entry"],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Name", "Caption", "Modified"], "secretFields": []},
  "emptyStateKey": "analyticsTermListsEmpty",
  "commandAliases": ["term lists", "term list"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsTermListsPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "analyticsTermListsPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsTermListsPrompt3"}
  ],
  "classicPage": "%DeepSee.UI.TermListManager",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "term list",
    "source": {"port": "analytics", "endpoint": "TermLists", "type": "LIST"},
    "fields": ["Name", "Caption", "Modified"],
    "filter": ["Name", "Caption"],
    "sort": {"fields": ["Name", "Caption", "Modified"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Caption", "labelKey": "analyticsColumnCaption", "kind": "text"},
      {"field": "Modified", "labelKey": "analyticsColumnModified", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "analytics.termlists"
}
}

}
