/// <p>System Explorer's Command console: one ObjectScript command run in the route's namespace as the signed-in person,
/// rendered as a <code>form-page</code> (AD-5, AD-10, Story 24.6).</p>
/// <p><b>It declares no <code>read</code></b> (AD-36): its page posts the command through the screen action route, so it has no
/// read tool and no context field, and a command, its output and its error never reach screen context (AD-39's eighth
/// exception).</p>
/// <p><b>Its one row action is <code>run</code></b>, a person's alone and off by default: it runs the command in this namespace
/// as the signed-in person, behind a warning dialog, through <class>OcuPilot.Screen.Tool.ExplorerCommandRun</class>, whose
/// governance key ships disabled and which the agent can never reach (AD-10's run-code exception, AD-53). Its target is the
/// literal <code>command</code> under <code>class</code> in the route's namespace (AD-13); its id is <code>none</code>.</p>
/// <p><b>Its privilege set is <code>%Development:USE</code></b>; the port also requires READ on each of the namespace's code
/// databases and WRITE on its routines database (AD-29). No classic page runs a command (AD-44). It does not refresh
/// (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerCommand Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/command",
  "area": "system-explorer",
  "labelKey": "explorerCommandLabel",
  "sideBarPosition": 18,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "class",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "run", "selfProtection": ""}],
  "context": {"fields": [], "secretFields": []},
  "emptyStateKey": "",
  "commandAliases": ["command console", "run command", "execute command"],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerCommandPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerCommandPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerCommandPrompt3"}
  ],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "explorer.command"
}
}

}
