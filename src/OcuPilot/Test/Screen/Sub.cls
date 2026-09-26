/// <p>Fixture descriptor: the <b>sub-resource</b> form (AD-5). Task history is not a task, and
/// its rows are not the entity its route identifies -- so it declares its own entity type and
/// a <code>parentScope</code> naming the route of the screen whose entity it hangs from.</p>
Class OcuPilot.Test.Screen.Sub Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "tasks/history",
  "area": "tasks",
  "labelKey": "navAreaTasks",
  "sideBarPosition": 4,
  "archetype": "list",
  "built": true,
  "privileges": [{"resource": "%Admin_Task", "permission": "USE"}],
  "entityType": "task-history-entry",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "tasks/schedule",
  "id": {"kind": "single", "parts": []},
  "context": {"fields": ["task", "startedAt", "status"], "secretFields": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "emptyStateKey": "",
  "commandAliases": ["task history", "history"],
  "suggestedPrompts": [{"groupKey": "promptGroupTroubleshooting", "textKey": "homeStarterPromptExplainScreen"}, {"groupKey": "promptGroupTroubleshooting", "textKey": "homeStarterPromptExplainLog"}, {"groupKey": "promptGroupTroubleshooting", "textKey": "homeStarterPromptChangeOneThing"}],
  "classicPage": "OcuPilotTestClassicPageSub",
  "classicLinkExemption": {"exempt": false, "reason": ""},
  "toolIdentifier": "task.history"
}
}

}
