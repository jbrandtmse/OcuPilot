/// <p>Analytics' Run-time variables: the third tab of the classic Settings page, the variables the namespace defines for its dashboards, each with its stored expression, comment and context, read
/// through <class>OcuPilot.Port.AnalyticsPort</class> (source kind <code>analytics</code>, endpoint <code>RuntimeVariables</code>) and rendered by the <code>detail</code> page over the declared
/// <code>table</code> (AD-5, AD-29, AD-36, AD-44, AD-65, Story 24.13).</p>
/// <p><b>An expression is text.</b> It is shown and sent to the model as stored (AD-60) and is never evaluated, rendered or run (AD-11): the vendor call that evaluates a variable is never made.</p>
/// <p><b>It is the third tab of the group <code>analytics/settings</code> and never listed</b> (<code>sideBarPosition</code> 0). Its pairs are the first tab's. <b>Its id is the variable's name</b>, kept
/// exactly (AD-13), and its scope is <code>namespace</code>. It writes (Story 24.13, Batch 3): its primary action Add run-time variable and its row actions Change run-time variable and Remove run-time variable
/// are the tools <code>analytics.runtimevariables.add</code>, <code>.set</code> and <code>.remove</code>. It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.AnalyticsRuntimeVariableList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "analytics/settings/variables",
  "area": "analytics",
  "labelKey": "analyticsRuntimeVariablesLabel",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%DeepSee_Portal", "permission": "USE"}, {"resource": "%Development", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "analytics-runtime-variable",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "add", "selfProtection": ""},
  "rowActions": [{"id": "set", "selfProtection": ""}, {"id": "remove", "selfProtection": ""}],
  "context": {"fields": ["Name", "Value", "Comment", "Context"], "secretFields": []},
  "emptyStateKey": "analyticsRuntimeVariablesEmpty",
  "commandAliases": ["run-time variables", "runtime variables"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsRuntimeVariablesPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsRuntimeVariablesPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "analyticsRuntimeVariablesPrompt3"}
  ],
  "classicPage": "%DeepSee.UI.Settings",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "run-time variable",
    "source": {"port": "analytics", "endpoint": "RuntimeVariables", "type": "LIST"},
    "fields": ["Name", "Value", "Comment", "Context"],
    "filter": ["Name", "Value", "Comment", "Context"],
    "sort": {"fields": ["Name", "Comment", "Context"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Value", "labelKey": "errorLogColumnExpression", "kind": "text"},
      {"field": "Comment", "labelKey": "userFieldComment", "kind": "text"},
      {"field": "Context", "labelKey": "analyticsColumnContext", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "analyticsRuntimeVariablesEmptyAgent"
  },
  "tab": {"group": "analytics/settings", "position": 3, "labelKey": "analyticsRuntimeVariablesLabel"},
  "toolIdentifier": "analytics.runtimevariables"
}
}

}
