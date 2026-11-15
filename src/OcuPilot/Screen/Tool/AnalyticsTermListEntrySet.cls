/// <p>Analytics' term list entry change (AD-4, AD-6, AD-51, AD-53, AD-56, AD-65, Story 24.2): store a new value, and new values for extra
/// fields, in one entry of a term list. A merge over the entry's fresh read, member by member over its fields: a field the call leaves out
/// keeps its value (<method>MergeUpdate</method>). The change is in effect at once, and all of it or none (the port runs its vendor calls in
/// one transaction).</p>
/// <p>Two callers reach it: the Entries screen's row action Change entry through <class>OcuPilot.Api.ScreenAction</class>, whose values are
/// strings (the field values travel as JSON text), and the agent's proposal and confirmation.</p>
Class OcuPilot.Screen.Tool.AnalyticsTermListEntrySet Extends OcuPilot.Screen.Tool.AnalyticsTermListEntryAction
{

Parameter TOOLNAME = "analytics.termlistentries.set";

Parameter DESCRIPTION = "Propose changing one entry of a term list of the namespace the user is working in: its value, and the values of its extra fields. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the term list and the entry's key as the Term lists and entries lists report them, and give only what changes; a field you leave out keeps its value, and an empty string clears one. Cubes and pivots that look the key up see the change at once. An entry the list does not hold, a field the list does not hold, a value over 32,000 characters and a database that is read-only or not journaled are refused.";

Parameter WRITETYPE = "ENTRYSET";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

Parameter SCREENACTIONS = "set";

Parameter SCREENVALUES = "set=Value:FieldValues";

Parameter SCREENOPTIONAL = "set=Value:FieldValues";

Parameter SCREENEMPTY = "set=Value";

Parameter READBACKFIELDS = "Value,FieldValues";

Parameter PRECONDITIONCODES = "ANALYTICS.TERMLIST.ABSENT,ANALYTICS.TERMLIST.READONLY,ANALYTICS.TERMLIST.NOTJOURNALED,ANALYTICS.NAMESPACE";

Parameter FIELDS = "Value,FieldValues";

ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 2
    Set pRows(1) = $ListBuild("Value", "string", 0)
    Set pRows(2) = $ListBuild("FieldValues", "string", 1)
    Quit $$$OK
}

/// <p>The merge over the fresh read, with <code>FieldValues</code> overlaid member by member (<method>OverlaidPairs</method>) before the
/// kernel's own merge compares and carries it.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tArgs = pArgs
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("FieldValues") = "array") {
        Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
        Do tArgs.%Set("FieldValues", ..OverlaidPairs(pFresh, pArgs))
    }
    Quit ##super(pFresh, tArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
}

/// <p>The dialog's values as this tool's arguments: <code>Value</code> as sent, which may be empty, and <code>FieldValues</code> as the JSON
/// array text it is; the port judges them.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If '$IsObject(pValues) Quit $$$OK
    If pValues.%GetTypeOf("Value") = "string" Do pArgs.%Set("Value", pValues.%Get("Value"), "string")
    If pValues.%GetTypeOf("FieldValues") = "string" {
        Set pProblem = ..ArrayFromText(pValues.%Get("FieldValues"), "FieldValues", .tPairs)
        If pProblem '= "" Quit $$$OK
        Do pArgs.%Set("FieldValues", tPairs)
    }
    Quit $$$OK
}

}
