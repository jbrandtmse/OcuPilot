/// <p>The routine editor: one routine's or include file's text, edited and saved, rendered as a
/// <code>form-page</code> (AD-5, Story 19.3). Its Save is the Routines list's <code>save</code>
/// action, which <class>OcuPilot.Screen.Tool.ExplorerRoutineSave</class> carries out through the
/// source code API port against the version the editor read (AD-53, AD-61).</p>
/// <p><b>It is reached from the routine viewer and never listed</b> (<code>sideBarPosition</code> 0),
/// at the Routines list's route with <code>/editor</code> appended and the document's name as its one
/// id segment.</p>
/// <p><b>It declares no <code>read</code> and no <code>table</code></b> (AD-36): its page issues the
/// routine viewer's declared read for the text, which never enters screen context, and declares no
/// context field. Its privilege set is the list's, which the port evaluates again with the
/// namespace's code databases, and the Save also needs WRITE on the namespace's routines database
/// (AD-8, AD-61).</p>
/// <p><b>No classic page has an editor</b>, so <code>classicPage</code> is empty and the page carries
/// no classic link (AD-44): it is new capability, not parity. It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerRoutineEditor Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/routines/editor",
  "area": "system-explorer",
  "labelKey": "explorerRoutineEditorLabel",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "routine",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": []},
  "emptyStateKey": "",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerRoutineDocumentPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerRoutineDocumentPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerRoutineDocumentPrompt3"}
  ],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "explorer.routineeditor"
}
}

}
