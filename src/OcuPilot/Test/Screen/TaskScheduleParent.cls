/// <p>Fixture descriptor: a built, unlisted parent at <code>tasks/schedule</code>, the route
/// <class>OcuPilot.Test.Screen.Sub</class> already declared as its <code>parentScope</code>
/// before DW-1020 existed to check that the name resolves -- see
/// <class>OcuPilot.Test.Screen.SslParent</class>'s own header for why a new fixture is added here
/// rather than Sub's literal changing (its exact value is pinned by
/// <method>OcuPilot.Test.Descriptor.TestASubResourceDescriptorNamesItsParentScope</method>).</p>
Class OcuPilot.Test.Screen.TaskScheduleParent Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "tasks/schedule",
  "area": "tasks",
  "labelKey": "navAreaTasks",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "privileges": [{"resource": "%Admin_Task", "permission": "USE"}],
  "entityType": "task",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "context": {"fields": ["name"], "secretFields": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "suggestedPrompts": [{"groupKey": "promptGroupTroubleshooting", "textKey": "homeStarterPromptExplainScreen"}, {"groupKey": "promptGroupTroubleshooting", "textKey": "homeStarterPromptExplainLog"}, {"groupKey": "promptGroupTroubleshooting", "textKey": "homeStarterPromptChangeOneThing"}],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": ""},
  "toolIdentifier": "tasks.taskscheduleparentfixture"
}
}

}
