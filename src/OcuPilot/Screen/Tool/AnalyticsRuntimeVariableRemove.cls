/// <p>Analytics' run-time variable remove (AD-6, AD-10, AD-51, AD-53, AD-65, Story 24.13, Batch 3): remove one run-time variable from the request's namespace. A dashboard that uses it then gets an empty value
/// (<code>ANALYTICS.VARIABLE.REMOVE</code>).</p>
/// <p><b>It is destructive</b>: a removed variable cannot be restored from OcuPilot, so its card draws the destructive treatment, the Run-time variables tab's row action Remove run-time variable types the
/// variable's name, and its governance key ships disabled (AD-22). Its read-back reads the variable gone on the port's 404. Two callers reach it: that row action through
/// <class>OcuPilot.Api.ScreenAction</class> and the agent's proposal and confirmation.</p>
Class OcuPilot.Screen.Tool.AnalyticsRuntimeVariableRemove Extends OcuPilot.Screen.Tool.AnalyticsRuntimeVariableAction
{

Parameter TOOLNAME = "analytics.runtimevariables.remove";

Parameter DESCRIPTION = "Propose removing one run-time variable of the namespace the user is working in, which cannot be undone from OcuPilot: a dashboard that uses it then gets an empty value. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the variable exactly as the Run-time variables list reports it in its Name column. A variable the list does not report and a settings database that is read-only are refused.";

Parameter SCREENACTIONS = "remove";

Parameter WRITETYPE = "ENTRYREMOVE";

Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "deleted";

Parameter CONSEQUENCECODE = "ANALYTICS.VARIABLE.REMOVE";

Parameter ENTRYMEMBERS = "";

Parameter FINGERPRINTSUBJECT = "Name,Value,Comment,Context,Namespace";

Parameter PRECONDITIONFIELD = "Value";

Parameter REMOVALROWS = "Name,Value,Comment,Context";

Parameter PRECONDITIONCODES = "ANALYTICS.VARIABLE.ABSENT,ANALYTICS.SETTING.READONLY,ANALYTICS.NAMESPACE";

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The variable, named exactly as the Run-time variables list reports it in its Name column. A variable the list does not report is refused.", "string")
    }
    Quit tSchema
}

/// <p>A removal has no argument beyond the target.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Quit $$$OK
}

}
