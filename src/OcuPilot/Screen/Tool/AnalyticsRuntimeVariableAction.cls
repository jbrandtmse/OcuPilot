/// <p>What the Run-time variables tab's three write tools share (AD-6, AD-13, AD-51, AD-53, AD-65, Story 24.13, Batch 3): adding, changing and removing one run-time variable of the request's namespace by its name,
/// through <class>OcuPilot.Port.AnalyticsPort</class> and <code>%DeepSee.UserPortal.Utils</code>' own setters. It is <class>OcuPilot.Screen.Tool.AnalyticsSettingEntryAction</class> over the variables' global,
/// <code>^DeepSee.User.Settings</code>, with the port's <code>RUNTIMEVARIABLE</code> row <code>{Name, Value, Comment, Context, Namespace}</code> as its fresh read.</p>
/// <p><b>The expression is code.</b> <code>Value</code> is stored as text and run by the dashboards that use the variable, with the rights of whoever opens one. It is checked for syntax, never run here, and
/// the add and the change carry the consequence <parameter>CONSEQUENCECODE</parameter> (the syntax check is not a safety check).</p>
Class OcuPilot.Screen.Tool.AnalyticsRuntimeVariableAction Extends OcuPilot.Screen.Tool.AnalyticsSettingEntryAction [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsRuntimeVariableList";

Parameter DESTINATIONGLOBAL = "^DeepSee.User.Settings";

/// <p>The fresh read: one run-time variable.</p>
Parameter READTYPE = "RUNTIMEVARIABLE";

Parameter READANSWERS = "Name,Value,Comment,Context,Namespace";

Parameter ENTRYMEMBERS = "Value,Comment,Context";

/// <p>The consequence of an add and a change: the expression is code, checked and never run.</p>
Parameter CONSEQUENCECODE = "ANALYTICS.VARIABLE.CODE";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).#ENDPOINTRUNTIMEVARIABLES
}

}
