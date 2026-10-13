/// <p>The business rule editor screen: InterSystems' rule editor, loaded from the instance in a frame and signed in through the
/// browser-level login (AD-63, Story 20.7). It is reached from the Business rules list's name cell and never listed
/// (<code>sideBarPosition</code> 0), at that list's route with <code>/document</code> appended and the class's document name
/// (<code>&lt;class&gt;.cls</code>) as its one id segment, a <code>viewer (source)</code> screen (AD-5).</p>
/// <p><b>It declares no <code>read</code> and no <code>table</code></b> (AD-36): its page issues the Business rules list's
/// declared read and draws the frame only for a row that read answers. The page reaches nothing in the frame and
/// declares no context field.</p>
/// <p><b>Its pairs</b> are the list's: <code>%Ens_Portal:USE</code> and, as its own, <code>%Ens_Code:READ</code>
/// (AD-8, AD-64). The classic page is <code>EnsPortal.RuleEditor</code>, which the page-resource normalization names for the
/// <code>.zen</code> page and whose resource shares <code>%Ens_Code:READ</code> (AD-44). It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.InteropRuleEditor Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/rules/document",
  "area": "interoperability",
  "labelKey": "interopRuleEditorTitle",
  "sideBarPosition": 0,
  "archetype": "viewer (source)",
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
  "context": {"fields": [], "secretFields": []},
  "emptyStateKey": "interopRuleEditorEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopRuleEditorPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopRuleEditorPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopRuleEditorPrompt3"}
  ],
  "classicPage": "EnsPortal.RuleEditor",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "interop.ruleeditor"
}
}

}
