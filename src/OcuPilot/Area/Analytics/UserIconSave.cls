/// <p>User-defined icons' Add icon (AD-55, AD-54, Story 24.13, Batch 3): <code>POST /analytics/user-icons</code> adds one icon to the request's namespace through
/// <class>OcuPilot.Screen.Tool.AnalyticsUserIconAdd</class>, the tool the agent's mint and confirm read. The body's members are <code>Name</code> and, optionally, <code>Path</code> (text, never loaded); a name the
/// namespace holds is 409 <code>ANALYTICS.ICON.TAKEN</code>.</p>
Class OcuPilot.Area.Analytics.UserIconSave Extends OcuPilot.Area.Analytics.SettingEntrySave
{

Parameter CREATETOOL = "OcuPilot.Screen.Tool.AnalyticsUserIconAdd";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsUserIconList";

Parameter TAKENCODE = "ANALYTICS.ICON.TAKEN";

Parameter TAKENREASON = "This namespace already holds a user-defined icon with that name.";

}
