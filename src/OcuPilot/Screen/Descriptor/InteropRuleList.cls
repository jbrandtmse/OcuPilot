/// <p>Interoperability's business rules: the classes the route's namespace holds that the classic
/// <code>EnsPortal.Rules</code> page lists, read through <class>OcuPilot.Port.InteropPort</class> (source kind
/// <code>interop</code>, endpoint <code>Rules</code>) and rendered by the <code>list</code> archetype's page
/// from the declared <code>table</code> (AD-5, AD-29, AD-36, AD-62, Story 20.2). It is the area's
/// side-bar entry 4 and lives in <code>interoperability</code>, so it is offered only in a namespace that
/// runs interoperability (AD-44).</p>
/// <p><b>Its id is the class's document name</b> (<code>&lt;class&gt;.cls</code>, AD-13), and its scope is
/// <code>namespace</code>. It declares no action: editing a business rule stays on the classic
/// page.</p>
/// <p><b>Its pairs</b> are the classic menu's <code>%Ens_Portal:USE</code> and, as its own,
/// <code>%Ens_Code:READ</code>, which every shipped role that reaches the page holds; the classic page's
/// own resource is an OR list a pair set cannot express (AD-8, Story 20.2). The port adds READ on the
/// namespace's globals database at the call. It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.InteropRuleList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/rules",
  "area": "interoperability",
  "labelKey": "interopRulesLabel",
  "sideBarPosition": 4,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_Code", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_Code", "permission": "READ"}],
  "entityType": "class",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Name", "Modified"], "secretFields": []},
  "emptyStateKey": "interopRulesEmpty",
  "commandAliases": ["business rules", "rules", "routing rules"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopRulesPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopRulesPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopRulesPrompt3"}
  ],
  "classicPage": "EnsPortal.Rules",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "interop", "endpoint": "Rules", "type": "LIST"},
    "fields": ["Name", "Modified"],
    "filter": ["Name"],
    "sort": {"fields": ["Name", "Modified"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Modified", "labelKey": "explorerColumnModified", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "interop.rules"
}
}

}
