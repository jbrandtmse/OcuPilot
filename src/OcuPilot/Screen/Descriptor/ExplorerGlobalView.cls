/// <p>System Explorer's Global nodes: one global's nodes, a bounded page at a time, rendered as a <code>form-page</code> (AD-5, Story
/// 21.5).</p>
/// <p><b>It declares no <code>read</code></b> (AD-36): its grid posts to its own route, <code>POST /explorer/globals/nodes</code>, which
/// answers this screen only. So it has no read tool and no context field, and a page's subscripts and values never reach screen context.</p>
/// <p><b>Its two actions</b> are a person's alone: <code>save</code> sets one node's value
/// (<class>OcuPilot.Screen.Tool.ExplorerGlobalNodeSave</class>) and <code>delete</code> removes one node and every node below it
/// (<class>OcuPilot.Screen.Tool.ExplorerGlobalNodeDelete</class>), both unadvertised (AD-53).</p>
/// <p><b>Its privilege set is <parameter>OcuPilot.Port.GlobalPort.PAIRS</parameter></b>, as the Globals list's; the classic page it
/// replaces, <code>%cspapp.exp.utilexpglobalview</code>, has its own custom resource (AD-44). Its id is the node's reference, and it does
/// not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerGlobalView Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/globals/document",
  "area": "system-explorer",
  "labelKey": "explorerGlobalNodesLabel",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "global-node",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "save", "selfProtection": "protected-global"}, {"id": "delete", "selfProtection": "protected-global"}],
  "context": {"fields": [], "secretFields": []},
  "emptyStateKey": "",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerGlobalListPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerGlobalListPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerGlobalListPrompt3"}
  ],
  "classicPage": "%cspapp.exp.utilexpglobalview",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "explorer.globalnodes"
}
}

}
