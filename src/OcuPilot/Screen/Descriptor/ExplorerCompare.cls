/// <p>System Explorer's Compare: two classes or routines, in one namespace or two, drawn as a line
/// diff, rendered as a <code>form-page</code> (AD-5, Story 19.4).</p>
/// <p><b>It declares no <code>read</code></b> (AD-36): its page issues the class or routine
/// viewer's declared read once per side (<class>OcuPilot.Screen.Descriptor.ExplorerClassDocument</class>,
/// <class>OcuPilot.Screen.Descriptor.ExplorerRoutineDocument</class>), each under that viewer's own
/// gate and each in its side's namespace, and computes the diff in the browser. So it has no read
/// tool and no context field, and the agent has no compare.</p>
/// <p><b>Its id is <code>none</code></b>, its scope <code>namespace</code>, its primary entity type
/// <code>class</code> and its secondary <code>routine</code>. Its privilege set is
/// <parameter>OcuPilot.Port.AtelierPort.PAIRS</parameter>, the viewers' own.</p>
/// <p><b>It replaces the classic Compare Routines page</b>,
/// <code>%CSP.UI.Portal.RoutineCompare</code>, whose custom resource also gates it (AD-44). It
/// declares no action and does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerCompare Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/compare",
  "area": "system-explorer",
  "labelKey": "explorerCompareLabel",
  "sideBarPosition": 4,
  "archetype": "form-page",
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
  "context": {"fields": [], "secretFields": []},
  "emptyStateKey": "",
  "commandAliases": ["compare", "diff"],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerComparePrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerComparePrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerComparePrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.RoutineCompare",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "explorer.compare"
}
}

}
