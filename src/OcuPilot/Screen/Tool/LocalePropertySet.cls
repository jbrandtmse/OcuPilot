/// <p>Locale properties' Set value (Story 21.16, AD-4, AD-6, AD-51, AD-52, AD-53, AD-55, AD-58): store a value for one property of one custom
/// locale that is not the current locale, through <class>OcuPilot.Port.LocalePort</class>. Two callers reach it: the Locale properties
/// screen's row action Set value, whose dialog sends the value as text, and the agent's proposal and confirmation.</p>
/// <p>It is a merge over the property's fresh read, so its card shows one <code>Value</code> row and the port sends the complete settable
/// set with that one key changed (AD-4). A locale InterSystems ships, the current locale, a row shown and never changed, and a value the
/// property does not accept are refused before any vendor call (<class>OcuPilot.Area.OsMgmt.LocaleRules</class>).</p>
Class OcuPilot.Screen.Tool.LocalePropertySet Extends OcuPilot.Screen.Tool.LocalePropertyAction
{

Parameter TOOLNAME = "osmgmt.localeproperties.set";

Parameter DESCRIPTION = "Propose setting one property of one custom locale, whose name starts with y and which is not the current locale. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the locale and the property exactly as the Locale properties list reports them, and give the new value as text in the form the row's Accepts line states. A locale InterSystems ships, the current locale, a row the list marks as shown and never changed, and a value the property does not accept are refused.";

Parameter WRITETYPE = "SET";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter SCREENACTIONS = "set";

/// <p>The dialog sends the value as this tool's one value, which may be empty: a text property may be cleared (AD-56 (ii)).</p>
Parameter SCREENVALUES = "set=Value";

Parameter SCREENEMPTY = "set=Value";

Parameter READBACKFIELDS = "Value";

Parameter ARGUMENT = "Value";

Parameter IDDESCRIPTION = "The property to set, named exactly as the Locale properties list reports it in its Name column.";

ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..#ARGUMENT)
}

/// <p>The one field a set sends, a string (AD-3).</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 1
    Set pRows(1) = $ListBuild(..#ARGUMENT, "string", 0)
    Quit $$$OK
}

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..#ARGUMENT) = "object" {
        Do tProperties.%Get(..#ARGUMENT).%Set("description", "The new value, as text, in the form the row's Accepts line states. A value the property does not accept is refused.", "string")
        If tSchema.%GetTypeOf("required") = "array" Do tSchema.%Get("required").%Push(..#ARGUMENT)
    }
    Quit tSchema
}

/// <p>The dialog's value as this tool's argument; the rules judge it at the write.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If $IsObject(pValues) && (pValues.%GetTypeOf(..#ARGUMENT) = "string") Do pArgs.%Set(..#ARGUMENT, pValues.%Get(..#ARGUMENT), "string")
    Quit $$$OK
}

}
