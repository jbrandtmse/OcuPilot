/// <p>The New Task wizard and Edit task: one scheduled task, created at its bare route on a four-step
/// page and edited at <code>&lt;route&gt;/&lt;id&gt;</code> on four tabs drawn from the same field
/// model, rendered by the <code>form-page</code> archetype (AD-5). Create task and the agent's
/// confirmed <code>tasks.schedule.create</code> are two callers of one tool, and Save and the agent's
/// confirmed <code>tasks.schedule.update</code> of another (AD-55).</p>
/// <p><b>It is built and routable, and it takes no side-bar position</b> (<code>sideBarPosition</code>
/// 0): it is reached from <class>OcuPilot.Screen.Descriptor.TaskScheduleList</class>'s Create, at that
/// list's own route with <code>/edit</code> appended, and from Task details' Edit. The list's name
/// cell keeps opening task details. Its label is the neutral entity word, because the one declaration
/// titles both the create and the edit.</p>
/// <p><b>It declares no <code>read</code> and no <code>table</code></b> (AD-36): its form read answers
/// the types and defaults it offers, and the list is where the declared read lives.</p>
/// <p><b>Its privilege set is the list's own</b> -- <code>%Admin_Task:USE</code> plus
/// <code>%DB_IRISSYS:READ</code> -- because the form writes the endpoint the list reads (AD-8); a
/// principal holding those two created a task (measured).</p>
/// <p><b>Its classic equivalent is <code>%cspapp.op.utilsystaskbuilder</code></b>, the class the
/// classic <code>UtilSysTaskBuilder.csp</code> compiles to, as
/// <code>%SYS.Portal.Resources.NormalizePage</code> answers it on this build (AD-44). It declares no
/// exemption and does not refresh (AD-43). It declares three suggested prompts (Story 11.3's
/// contract).</p>
Class OcuPilot.Screen.Descriptor.TaskForm Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "tasks/schedule/edit",
  "area": "tasks",
  "labelKey": "proposalEntityTask",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Task", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "task",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": []},
  "secretArguments": [],
  "fingerprintExcludes": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "taskPromptGroupSchedule", "textKey": "taskPromptNightly"},
    {"groupKey": "taskPromptGroupSchedule", "textKey": "taskPromptWeekly"},
    {"groupKey": "taskPromptGroupSchedule", "textKey": "taskPromptWhichType"}
  ],
  "classicPage": "%cspapp.op.utilsystaskbuilder",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "tasks.scheduleform"
}
}

}
