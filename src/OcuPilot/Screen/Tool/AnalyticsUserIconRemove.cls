/// <p>Analytics' user-defined icon remove (AD-6, AD-10, AD-51, AD-53, AD-65, Story 24.13, Batch 3): remove one icon from the request's namespace (<code>ANALYTICS.ICON.REMOVE</code>).</p>
/// <p><b>It is destructive</b>: a removed icon cannot be restored from OcuPilot, so its card draws the destructive treatment, the User-defined icons tab's row action Remove icon types the icon's name, and its
/// governance key ships disabled (AD-22). Its read-back reads the icon gone on the port's 404. Two callers reach it: that row action through <class>OcuPilot.Api.ScreenAction</class> and the agent's proposal and
/// confirmation.</p>
Class OcuPilot.Screen.Tool.AnalyticsUserIconRemove Extends OcuPilot.Screen.Tool.AnalyticsUserIconAction
{

Parameter TOOLNAME = "analytics.usericons.remove";

Parameter DESCRIPTION = "Propose removing one user-defined icon of the namespace the user is working in, which cannot be undone from OcuPilot. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the icon exactly as the User-defined icons list reports it in its Name column. An icon the list does not report and a settings database that is read-only are refused.";

Parameter SCREENACTIONS = "remove";

Parameter WRITETYPE = "ENTRYREMOVE";

Parameter DESTRUCTIVE As BOOLEAN = 1;

Parameter CHANGEACTION = "deleted";

Parameter CONSEQUENCECODE = "ANALYTICS.ICON.REMOVE";

Parameter ENTRYMEMBERS = "";

Parameter FINGERPRINTSUBJECT = "Name,Path,Namespace";

Parameter PRECONDITIONFIELD = "Path";

Parameter REMOVALROWS = "Name,Path";

Parameter PRECONDITIONCODES = "ANALYTICS.ICON.ABSENT,ANALYTICS.SETTING.READONLY,ANALYTICS.NAMESPACE";

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The icon, named exactly as the User-defined icons list reports it in its Name column. An icon the list does not report is refused.", "string")
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
