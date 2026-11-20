/// <p>Analytics' user-defined icon change (AD-4, AD-6, AD-51, AD-53, AD-56, AD-65, Story 24.13, Batch 3): store a new path for one icon of the request's namespace. A merge over the icon's fresh read. An icon's name is
/// never changed here; a rename is a removal and an add.</p>
/// <p>Two callers reach it: the User-defined icons tab's row action Change icon through <class>OcuPilot.Api.ScreenAction</class>, whose values are strings, and the agent's proposal and confirmation. A path is
/// text and is never loaded or drawn.</p>
Class OcuPilot.Screen.Tool.AnalyticsUserIconSet Extends OcuPilot.Screen.Tool.AnalyticsUserIconAction
{

Parameter TOOLNAME = "analytics.usericons.set";

Parameter DESCRIPTION = "Propose changing the path of one user-defined icon of the namespace the user is working in. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the icon exactly as the User-defined icons list reports it in its Name column and give the new path as text; an empty string clears it. The path is stored as text and never loaded. An icon the list does not report, a path over 2000 characters and a settings database that is read-only are refused. A name is never changed: remove the icon and add another.";

Parameter WRITETYPE = "ENTRYSET";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

Parameter SCREENACTIONS = "set";

Parameter SCREENVALUES = "set=Path";

Parameter SCREENOPTIONAL = "set=Path";

Parameter SCREENEMPTY = "set=Path";

Parameter READBACKFIELDS = "Path";

Parameter PRECONDITIONCODES = "ANALYTICS.ICON.ABSENT,ANALYTICS.SETTING.READONLY,ANALYTICS.NAMESPACE";

Parameter FIELDS = "Path";

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
    Do tProperties.%Get("Name").%Set("description", "The icon, named exactly as the User-defined icons list reports it in its Name column. An icon the list does not report is refused.", "string")
    Do tProperties.%Get("Path").%Set("description", "The icon's new path as text, at most 2000 characters. It is stored as text and never loaded.", "string")
    Quit tSchema
}

}
