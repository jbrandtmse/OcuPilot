/// <p>Analytics' run-time variable change (AD-4, AD-6, AD-51, AD-53, AD-56, AD-65, Story 24.13, Batch 3): store a new expression, comment or context for one run-time variable of the request's namespace. A merge over
/// the variable's fresh read: a member the call leaves out keeps its value. A variable's name is never changed here; a rename is a removal and an add.</p>
/// <p>Two callers reach it: the Run-time variables tab's row action Change run-time variable through <class>OcuPilot.Api.ScreenAction</class>, whose values are strings, and the agent's proposal and
/// confirmation. The expression is stored as text and checked for syntax, never run; its card carries <code>ANALYTICS.VARIABLE.CODE</code>.</p>
Class OcuPilot.Screen.Tool.AnalyticsRuntimeVariableSet Extends OcuPilot.Screen.Tool.AnalyticsRuntimeVariableAction
{

Parameter TOOLNAME = "analytics.runtimevariables.set";

Parameter DESCRIPTION = "Propose changing one run-time variable of the namespace the user is working in: its expression, its comment or its context. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the variable exactly as the Run-time variables list reports it in its Name column and give only what changes; a member you leave out keeps its value, and an empty string clears one. The expression is code that runs with the rights of whoever opens a dashboard that uses it; it is checked for syntax and never run here. A variable the list does not report, an expression that is not valid ObjectScript, a text over 2000 characters and a settings database that is read-only are refused. A name is never changed: remove the variable and add another.";

Parameter WRITETYPE = "ENTRYSET";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

Parameter SCREENACTIONS = "set";

Parameter SCREENVALUES = "set=Value:Comment:Context";

Parameter SCREENOPTIONAL = "set=Value:Comment:Context";

Parameter SCREENEMPTY = "set=Value:Comment:Context";

Parameter READBACKFIELDS = "Value,Comment,Context";

Parameter PRECONDITIONCODES = "ANALYTICS.VARIABLE.ABSENT,ANALYTICS.SETTING.READONLY,ANALYTICS.NAMESPACE";

Parameter FIELDS = "Value,Comment,Context";

ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

ClassMethod FieldRows(Output pRows) As %Status
{
    Quit ..EntryFieldRows(0, .pRows)
}

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Get("Name").%Set("description", "The variable, named exactly as the Run-time variables list reports it in its Name column. A variable the list does not report is refused.", "string")
    Do tProperties.%Get("Value").%Set("description", "The variable's expression as text, at most 2000 characters, in ObjectScript. It runs when a dashboard uses the variable and is never run here; it is checked for syntax.", "string")
    Quit tSchema
}

}
