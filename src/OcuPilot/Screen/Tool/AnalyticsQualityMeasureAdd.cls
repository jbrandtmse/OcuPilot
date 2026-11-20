/// <p>Analytics' quality measure create (AD-3, AD-6, AD-54, AD-55, AD-61, AD-65, Story 24.12): make one quality measure, with its class, in the request's namespace. Two callers
/// reach it: the Quality measures screen's New quality measure dialog through <class>OcuPilot.Area.Analytics.QualityMeasureSave</class>, and the agent's proposal and confirmation.</p>
/// <p><b>A create</b> (AD-54): its fresh read must find no measure of that name, and a name taken since the mint closes the proposal target-changed. The new measure starts from the
/// classic page's new model, a numerator and a denominator group of one element each and the expression dividing them, because it can hold no group otherwise and an expression must
/// name one. The port refuses a name or class already in use and a class that is malformed, begins with <code>%</code> or <code>OcuPilot</code>, each by its own code before anything is
/// saved. Its fields are declared here (<method>FieldRows</method>, AD-3), and its read-back compares each (<parameter>READBACKFIELDS</parameter>, AD-58). It follows
/// <class>OcuPilot.Screen.Tool.AnalyticsListingGroupAdd</class>'s shape with a measure's own fields: a measure has none of a group's cubes or resources.</p>
Class OcuPilot.Screen.Tool.AnalyticsQualityMeasureAdd Extends OcuPilot.Screen.Tool.AnalyticsQualityMeasureAction
{

Parameter TOOLNAME = "analytics.qualitymeasures.add";

Parameter DESCRIPTION = "Propose creating one quality measure in the namespace the user is working in: a class that holds a measure (an expression over groups of MDX elements) for a subject area. It changes nothing by itself: it answers a proposal the user reviews and confirms. Give the new measure's name as catalog/set/id, the new class that holds it, and optionally a caption, description and subject area. The measure starts with a numerator and a denominator group of one element each and the expression that divides them; the groups and elements are changed in the class. The class is saved and compiled. A name or class the namespace already holds and a class name that is malformed or begins with % or OcuPilot are refused.";

Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter WRITETYPE = "ADD";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter READBACKFIELDS = "Class,Caption,Description,SubjectArea";

/// <p>The read-back re-reads the created measure through the update's read, because the add's own read is composed for an add.</p>
Parameter READBACKTOOL = "OcuPilot.Screen.Tool.AnalyticsQualityMeasureUpdate";

Parameter PRECONDITIONCODES = "ANALYTICS.QUALITYMEASURE.TAKEN,ANALYTICS.QUALITYMEASURE.READONLY,ANALYTICS.NAMESPACE";

Parameter FIELDS = "Name,Class,Caption,Description,SubjectArea";

ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

/// <p>The fields as the rows the input schema is derived from (AD-3).</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 5
    Set pRows(1) = $ListBuild("Name", "string", 0)
    Set pRows(2) = $ListBuild("Class", "string", 0)
    Set pRows(3) = $ListBuild("Caption", "string", 0)
    Set pRows(4) = $ListBuild("Description", "string", 0)
    Set pRows(5) = $ListBuild("SubjectArea", "string", 0)
    Quit $$$OK
}

ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Get("Name").%Set("description", "The new quality measure's full name, catalog/set/id: three parts, each 1 to 250 characters with no dot, slash or control character. A name the namespace already holds is refused, compared without regard to case, so check the Quality measures list first.", "string")
    Do tProperties.%Get("Class").%Set("description", "The new class that holds the measure: dotted letters and digits with a package, beginning with neither % nor OcuPilot. A class the namespace already holds is refused.", "string")
    Do tProperties.%Get("SubjectArea").%Set("description", "The name of the cube or subject area the measure applies to.", "string")
    Quit tSchema
}

/// <p>The composed payload and diff of the create (AD-54), and the namespace the request is scoped to. The namespace adds no diff row.</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") || '$IsObject(pPayload) Quit tSC
    Do pPayload.%Set(..#NAMESPACEFIELD, ##class(OcuPilot.Kernel.Scope).Current(), "string")
    Quit tSC
}

/// <p>The name of the measure the confirmed add <var>pWritten</var> created, or <code>""</code>.</p>
ClassMethod CreatedId(pWritten) As %String
{
    If '$IsObject(pWritten) || 'pWritten.%IsA("%Library.DynamicObject") || (pWritten.%GetTypeOf("Name") '= "string") Quit ""
    Quit pWritten.%Get("Name")
}

}
