/// <p>Run-time variables' Add run-time variable (AD-55, AD-54, Story 24.13, Batch 3): <code>POST /analytics/runtime-variables</code> adds one run-time variable to the request's namespace through
/// <class>OcuPilot.Screen.Tool.AnalyticsRuntimeVariableAdd</class>, the tool the agent's mint and confirm read. The body's members are <code>Name</code> and, optionally, <code>Value</code> (the expression, stored
/// as text and never run), <code>Comment</code> and <code>Context</code>; a name the namespace holds is 409 <code>ANALYTICS.VARIABLE.TAKEN</code>.</p>
Class OcuPilot.Area.Analytics.RuntimeVariableSave Extends OcuPilot.Area.Analytics.SettingEntrySave
{

Parameter CREATETOOL = "OcuPilot.Screen.Tool.AnalyticsRuntimeVariableAdd";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsRuntimeVariableList";

Parameter TAKENCODE = "ANALYTICS.VARIABLE.TAKEN";

Parameter TAKENREASON = "This namespace already holds a run-time variable with that name.";

}
