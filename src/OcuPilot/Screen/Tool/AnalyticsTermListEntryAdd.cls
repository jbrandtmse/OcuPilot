/// <p>Analytics' term list entry add (AD-3, AD-6, AD-54, AD-55, AD-65, Story 24.2): add one entry, with its value and its extra fields'
/// values, to a term list of the request's namespace. Two callers reach it: the Entries screen's Add entry dialog through
/// <class>OcuPilot.Area.Analytics.TermListEntrySave</class>, and the agent's proposal and confirmation.</p>
/// <p><b>A create</b> (AD-54): its fresh read must find no entry of that key, and a key added since the mint closes the proposal
/// target-changed (<code>ANALYTICS.TERMLIST.ENTRYTAKEN</code>). A list that is not there is <code>ANALYTICS.TERMLIST.ABSENT</code>. The
/// fields are declared here (<method>FieldRows</method>, AD-3), and its read-back compares the value and the field values
/// (<parameter>READBACKFIELDS</parameter>, AD-58).</p>
Class OcuPilot.Screen.Tool.AnalyticsTermListEntryAdd Extends OcuPilot.Screen.Tool.AnalyticsTermListEntryAction
{

Parameter TOOLNAME = "analytics.termlistentries.add";

Parameter DESCRIPTION = "Propose adding one entry to a term list of the namespace the user is working in. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the term list as the Term lists list reports it, the new entry's key, its value, and optionally values for the list's extra fields. Cubes and pivots that look the key up see the entry at once. A key the list already holds, a list that does not exist, a field the list does not hold, a key or value over its limits and a database that is read-only or not journaled are refused.";

Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter WRITETYPE = "ENTRYADD";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter READBACKFIELDS = "Value,FieldValues";

Parameter READBACKTOOL = "OcuPilot.Screen.Tool.AnalyticsTermListEntrySet";

Parameter PRECONDITIONCODES = "ANALYTICS.TERMLIST.ENTRYTAKEN,ANALYTICS.TERMLIST.ABSENT,ANALYTICS.TERMLIST.READONLY,ANALYTICS.TERMLIST.NOTJOURNALED,ANALYTICS.NAMESPACE";

Parameter FIELDS = "Key,Value,FieldValues";

ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 3
    Set pRows(1) = $ListBuild("Key", "string", 0)
    Set pRows(2) = $ListBuild("Value", "string", 0)
    Set pRows(3) = $ListBuild("FieldValues", "string", 1)
    Quit $$$OK
}

ClassMethod NameDescription() As %String
{
    Quit "The new entry's key: 1 to 255 characters with no control character and no ^. A key the list already holds is refused, so check its entries list first."
}

/// <p>The composed payload and diff of the create (AD-54), and the namespace the request is scoped to. The namespace adds no diff row.</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") || '$IsObject(pPayload) Quit tSC
    Do pPayload.%Set(..#NAMESPACEFIELD, ##class(OcuPilot.Kernel.Scope).Current(), "string")
    Quit tSC
}

/// <p>The composite id of the entry the confirmed add <var>pWritten</var> created, or <code>""</code>.</p>
ClassMethod CreatedId(pWritten) As %String
{
    If '$IsObject(pWritten) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    If (pWritten.%GetTypeOf("TermList") '= "string") || (pWritten.%GetTypeOf("Key") '= "string") Quit ""
    Quit ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pWritten.%Get("TermList"), pWritten.%Get("Key")))
}

/// <p>The add always asks its read for the add: held is <code>ENTRYTAKEN</code> and absent is the 404 a create expects (AD-54).</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Set pQuery(##class(OcuPilot.Port.AnalyticsPort).#ACTIONKEY) = ..#WRITETYPE
    If '$IsObject(pPayload) Quit
    If (pPayload.%GetTypeOf(..#NAMESPACEFIELD) = "string") && (pPayload.%Get(..#NAMESPACEFIELD) '= "") {
        Set pQuery(##class(OcuPilot.Port.AnalyticsPort).#NAMESPACEKEY) = pPayload.%Get(..#NAMESPACEFIELD)
    }
}

}
