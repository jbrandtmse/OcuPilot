/// <p>Analytics' term list change (AD-4, AD-6, AD-51, AD-53, AD-56, AD-65, Story 24.2): change a term list's caption, description, pattern,
/// subject area, fields and hide-value flag. A merge over the list's fresh read: the card shows the rows it moves and the write sends the
/// complete header, never an entry. A field that leaves the list while an entry holds a value for it is refused
/// (<code>ANALYTICS.TERMLIST.FIELDINUSE</code>), so a change never drops data.</p>
/// <p>Two callers reach it: the Term lists screen's row action Edit term list through <class>OcuPilot.Api.ScreenAction</class>, whose
/// values are strings (a list of fields travels as JSON text, the hide-value flag as <code>true</code> or <code>false</code>), and the
/// agent's proposal and confirmation.</p>
Class OcuPilot.Screen.Tool.AnalyticsTermListUpdate Extends OcuPilot.Screen.Tool.AnalyticsTermListAction
{

Parameter TOOLNAME = "analytics.termlists.update";

Parameter DESCRIPTION = "Propose changing one term list's caption, description, pattern, subject area, extra field names or hide-value flag in the namespace the user is working in. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the list as the Term lists list reports it and give only what changes; Fields is the whole new list of field names. The entries are never touched, and a field that some entry holds a value for cannot be removed: clear those values first. A list the namespace does not hold, a field or text over its limits and a database that is read-only or not journaled are refused.";

Parameter WRITETYPE = "UPDATE";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

Parameter SCREENACTIONS = "update";

Parameter SCREENVALUES = "update=Caption:Description:Pattern:SubjectArea:Fields:HideValue";

Parameter SCREENOPTIONAL = "update=Caption:Description:Pattern:SubjectArea:Fields:HideValue";

Parameter SCREENEMPTY = "update=Caption:Description:Pattern:SubjectArea";

Parameter READBACKFIELDS = "Caption,Description,Pattern,SubjectArea,Fields,HideValue";

Parameter PRECONDITIONCODES = "ANALYTICS.TERMLIST.READONLY,ANALYTICS.TERMLIST.NOTJOURNALED,ANALYTICS.NAMESPACE";

Parameter FIELDS = "Caption,Description,Pattern,SubjectArea,Fields,HideValue";

ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 6
    Set pRows(1) = $ListBuild("Caption", "string", 0)
    Set pRows(2) = $ListBuild("Description", "string", 0)
    Set pRows(3) = $ListBuild("Pattern", "string", 0)
    Set pRows(4) = $ListBuild("SubjectArea", "string", 0)
    Set pRows(5) = $ListBuild("Fields", "string", 1)
    Set pRows(6) = $ListBuild("HideValue", "boolean", 0)
    Quit $$$OK
}

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Get("Name").%Set("description", "The term list, named as the Term lists list reports it in its Name column. A list the namespace does not hold is refused.", "string")
    Do tProperties.%Get("Fields").%Set("description", "The whole new list of extra field names, at most 50, each 1 to 255 characters with no ^, none named Value, no two the same without regard to case. A field some entry holds a value for cannot be left out.", "string")
    Quit tSchema
}

/// <p>The dialog's values as this tool's arguments: the strings as sent, <code>Fields</code> as the JSON array text it is, and
/// <code>HideValue</code> as <code>true</code> or <code>false</code>; the port judges them.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If '$IsObject(pValues) Quit $$$OK
    For tName = "Caption", "Description", "Pattern", "SubjectArea" {
        If pValues.%GetTypeOf(tName) = "string" Do pArgs.%Set(tName, pValues.%Get(tName), "string")
    }
    If pValues.%GetTypeOf("Fields") = "string" {
        Set pProblem = ..ArrayFromText(pValues.%Get("Fields"), "Fields", .tFields)
        If pProblem '= "" Quit $$$OK
        Do pArgs.%Set("Fields", tFields)
    }
    If pValues.%GetTypeOf("HideValue") = "string" {
        If '$ListFind($ListBuild("true", "false"), pValues.%Get("HideValue")) {
            Set pProblem = "'HideValue' is true or false"
            Quit $$$OK
        }
        Do pArgs.%Set("HideValue", (pValues.%Get("HideValue") = "true"), "boolean")
    }
    Quit $$$OK
}

/// <p>The rules over the call: the port's shape rules, then the rules that need the list's state (a field in use).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Quit ..RuleProblem(..#WRITETYPE, pIdValue, "", pArgs, .pProblem)
}

}
