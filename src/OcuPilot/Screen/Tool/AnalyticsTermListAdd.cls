/// <p>Analytics' term list create (AD-3, AD-6, AD-54, AD-55, AD-65, Story 24.2): make one term list in the request's namespace. Two callers
/// reach it: the Term lists screen's New term list dialog through <class>OcuPilot.Area.Analytics.TermListSave</class>, and the agent's
/// proposal and confirmation.</p>
/// <p><b>A create</b> (AD-54): its fresh read must find no list of that name, compared without regard to case, and a name taken since the
/// mint closes the proposal target-changed. The vendor's own create kills a list of the same name, so the port refuses a taken name by its
/// code (<code>ANALYTICS.TERMLIST.TAKEN</code>) before it. Its fields are declared here (<method>FieldRows</method>, AD-3): the port has no
/// body template, and its read-back compares each (<parameter>READBACKFIELDS</parameter>, AD-58).</p>
Class OcuPilot.Screen.Tool.AnalyticsTermListAdd Extends OcuPilot.Screen.Tool.AnalyticsTermListAction
{

Parameter TOOLNAME = "analytics.termlists.add";

Parameter DESCRIPTION = "Propose creating one term list in the namespace the user is working in: a named list of keys and values that cubes and pivots look up. It changes nothing by itself: it answers a proposal the user reviews and confirms. Give the new list's name, and optionally its caption, description, pattern, subject area, extra field names and whether its value column is hidden. A name the namespace already holds (compared without regard to case), a name, field or text over its limits and a database that is read-only or not journaled are refused.";

Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter WRITETYPE = "ADD";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter READBACKFIELDS = "Caption,Description,Pattern,SubjectArea,Fields,HideValue";

/// <p>The read-back re-reads the created list through the update's read, because the add's own read is composed for an add.</p>
Parameter READBACKTOOL = "OcuPilot.Screen.Tool.AnalyticsTermListUpdate";

Parameter PRECONDITIONCODES = "ANALYTICS.TERMLIST.TAKEN,ANALYTICS.TERMLIST.READONLY,ANALYTICS.TERMLIST.NOTJOURNALED,ANALYTICS.NAMESPACE";

Parameter FIELDS = "Name,Caption,Description,Pattern,SubjectArea,Fields,HideValue";

ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

/// <p>The fields as the rows the input schema is derived from (AD-3).</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 7
    Set pRows(1) = $ListBuild("Name", "string", 0)
    Set pRows(2) = $ListBuild("Caption", "string", 0)
    Set pRows(3) = $ListBuild("Description", "string", 0)
    Set pRows(4) = $ListBuild("Pattern", "string", 0)
    Set pRows(5) = $ListBuild("SubjectArea", "string", 0)
    Set pRows(6) = $ListBuild("Fields", "string", 1)
    Set pRows(7) = $ListBuild("HideValue", "boolean", 0)
    Quit $$$OK
}

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Get("Name").%Set("description", "The new term list's name: 1 to 255 characters with no control character. A name the namespace already holds is refused, compared without regard to case, so check the Term lists list first.", "string")
    Do tProperties.%Get("Fields").%Set("description", "The names of the extra fields each entry can hold besides its value: at most 50, each 1 to 255 characters with no ^, none named Value, no two the same without regard to case.", "string")
    Do tProperties.%Get("HideValue").%Set("description", "True to hide the value column of the list's entries. Omit it for false.", "string")
    Quit tSchema
}

/// <p>The composed payload and diff of the create (AD-54), and the namespace the request is scoped to, which the port query and the
/// prohibited set read. The namespace adds no diff row.</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") || '$IsObject(pPayload) Quit tSC
    Do pPayload.%Set(..#NAMESPACEFIELD, ##class(OcuPilot.Kernel.Scope).Current(), "string")
    Quit tSC
}

/// <p>The name of the list the confirmed add <var>pWritten</var> created, or <code>""</code>.</p>
ClassMethod CreatedId(pWritten) As %String
{
    If '$IsObject(pWritten) || 'pWritten.%IsA("%Library.DynamicObject") || (pWritten.%GetTypeOf("Name") '= "string") Quit ""
    Quit pWritten.%Get("Name")
}

/// <p>The rules over the caller's fields, as one sentence naming each field and its published sentence, or <code>""</code> (AD-55). The
/// screen's save and the mint apply them alike.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Quit ..RuleProblem(..#WRITETYPE, pIdValue, "", pArgs, .pProblem, 0)
}

/// <p>The add always asks its read for the add: held is <code>TAKEN</code> and absent is the 404 a create expects (AD-54), at the mint and
/// at the confirm alike.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Set pQuery(##class(OcuPilot.Port.AnalyticsPort).#ACTIONKEY) = ..#WRITETYPE
    If '$IsObject(pPayload) Quit
    If (pPayload.%GetTypeOf(..#NAMESPACEFIELD) = "string") && (pPayload.%Get(..#NAMESPACEFIELD) '= "") {
        Set pQuery(##class(OcuPilot.Port.AnalyticsPort).#NAMESPACEKEY) = pPayload.%Get(..#NAMESPACEFIELD)
    }
}

}
