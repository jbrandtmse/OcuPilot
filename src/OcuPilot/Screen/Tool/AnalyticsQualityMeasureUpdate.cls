/// <p>Analytics' quality measure change (AD-4, AD-6, AD-51, AD-53, AD-56, AD-61, AD-65, Story 24.12): change a quality measure's caption, description, subject area, expression, link,
/// published flag, format and URL. A merge over the measure's fresh read: the card shows the rows it moves. The write replaces only the class's <code>QualityMeasure</code> XData,
/// composed from the model read at the write, so the measure's groups, elements and documentation, and every other line of the class, are kept as stored. A measure's name and class are
/// never changed here. A measure linked to another takes its expression, format and URL from the master, so those three are refused while it is linked.</p>
/// <p>Two callers reach it: the Quality measures screen's row action Edit through <class>OcuPilot.Api.ScreenAction</class>, whose values are strings (the published flag travels as
/// <code>true</code> or <code>false</code>), and the agent's proposal and confirmation.</p>
Class OcuPilot.Screen.Tool.AnalyticsQualityMeasureUpdate Extends OcuPilot.Screen.Tool.AnalyticsQualityMeasureAction
{

Parameter TOOLNAME = "analytics.qualitymeasures.update";

Parameter DESCRIPTION = "Propose changing one quality measure's caption, description, subject area, expression, link, published flag, format or URL in the namespace the user is working in. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the measure as the Quality measures list reports it and give only what changes. The measure's class is saved and compiled, its groups, elements and documentation are never touched, and a failed compile puts the class back. A measure the namespace does not hold, one that two classes define, an expression that names a group the measure does not hold or whose brackets do not match, and a change of the expression, format or URL of a linked measure are refused.";

Parameter WRITETYPE = "UPDATE";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

Parameter SCREENACTIONS = "update";

Parameter SCREENVALUES = "update=Caption:Description:SubjectArea:Expression:LinkedTo:Published:Format:Href";

Parameter SCREENOPTIONAL = "update=Caption:Description:SubjectArea:Expression:LinkedTo:Published:Format:Href";

Parameter SCREENEMPTY = "update=Caption:Description:LinkedTo:Format:Href";

Parameter READBACKFIELDS = "Caption,Description,SubjectArea,Expression,LinkedTo,Published,Format,Href";

Parameter PRECONDITIONCODES = "ANALYTICS.QUALITYMEASURE.ABSENT,ANALYTICS.QUALITYMEASURE.AMBIGUOUS,ANALYTICS.QUALITYMEASURE.READONLY,ANALYTICS.NAMESPACE";

Parameter FIELDS = "Caption,Description,SubjectArea,Expression,LinkedTo,Published,Format,Href";

ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 8
    Set pRows(1) = $ListBuild("Caption", "string", 0)
    Set pRows(2) = $ListBuild("Description", "string", 0)
    Set pRows(3) = $ListBuild("SubjectArea", "string", 0)
    Set pRows(4) = $ListBuild("Expression", "string", 0)
    Set pRows(5) = $ListBuild("LinkedTo", "string", 0)
    Set pRows(6) = $ListBuild("Published", "boolean", 0)
    Set pRows(7) = $ListBuild("Format", "string", 0)
    Set pRows(8) = $ListBuild("Href", "string", 0)
    Quit $$$OK
}

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Get("Name").%Set("description", "The quality measure, named as the Quality measures list reports it in its Name column. A measure the namespace does not hold is refused.", "string")
    Do tProperties.%Get("Expression").%Set("description", "The expression that computes the measure, written over the measure's groups, such as [Numerator]/[Denominator]: every [name] must be an enabled group that holds an enabled element, and every [ must be closed.", "string")
    Do tProperties.%Get("LinkedTo").%Set("description", "The full name of another quality measure this one follows, or empty to unlink it. A linked measure's expression, format and URL cannot be changed.", "string")
    Quit tSchema
}

/// <p>The dialog's values as this tool's arguments: the strings as sent, <code>Published</code> as <code>true</code> or <code>false</code>; the port judges them.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    For tName = "Caption", "Description", "SubjectArea", "Expression", "LinkedTo", "Format", "Href" {
        Do ..CarryText(pValues, pArgs, tName)
    }
    Set pProblem = ..CarryBoolean(pValues, pArgs, "Published")
    Quit $$$OK
}

}
