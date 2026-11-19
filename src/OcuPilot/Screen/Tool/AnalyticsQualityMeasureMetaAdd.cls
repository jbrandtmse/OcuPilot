/// <p>Analytics' quality measure documentation add (AD-3, AD-6, AD-54, AD-55, AD-61, AD-65, Story 24.12): add one documentation item to a quality measure of the request's namespace. Two
/// callers reach it: the Documentation screen's Add documentation item dialog through <class>OcuPilot.Area.Analytics.QualityMeasureMetaSave</class>, and the agent's proposal and
/// confirmation.</p>
/// <p><b>A create</b> (AD-54): its fresh read must find no item of that name in the measure, and a name added since the mint closes the proposal target-changed. A measure that is not there is
/// <code>ANALYTICS.QUALITYMEASURE.ABSENT</code>. Its <code>Content</code> is sent in the model's own form (<method>OcuPilot.Screen.Tool.AnalyticsQualityMeasureMetaAction.ContentNormalized</method>).
/// The measure's class is saved and compiled. Its fields are declared here (<method>FieldRows</method>, AD-3), and its read-back compares each (<parameter>READBACKFIELDS</parameter>, AD-58).</p>
Class OcuPilot.Screen.Tool.AnalyticsQualityMeasureMetaAdd Extends OcuPilot.Screen.Tool.AnalyticsQualityMeasureMetaAction
{

Parameter TOOLNAME = "analytics.qualitymeasuremetas.add";

Parameter DESCRIPTION = "Propose adding one documentation item to a quality measure of the namespace the user is working in: a named note the Quality Measures Manager shows for the measure. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the measure as the Quality measures list reports it, the new item's name, and optionally its caption, content (markup: plain text, or text with tags; a literal ampersand or less-than sign is written as an entity) and disabled flag. The measure's class is saved and compiled, and a failed compile puts the class back. A name the measure already holds (without regard to case), content that is not well-formed markup, a measure that does not exist, that two classes define or that is linked to another measure, and a class of OcuPilot's own are refused.";

Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter WRITETYPE = "ENTRYADD";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter READBACKFIELDS = "Caption,Content,Disabled";

/// <p>The read-back re-reads the created item through the change's read, because the add's own read is composed for an add.</p>
Parameter READBACKTOOL = "OcuPilot.Screen.Tool.AnalyticsQualityMeasureMetaSet";

Parameter PRECONDITIONCODES = "ANALYTICS.QUALITYMEASURE.METATAKEN,ANALYTICS.QUALITYMEASURE.ABSENT,ANALYTICS.QUALITYMEASURE.AMBIGUOUS,ANALYTICS.QUALITYMEASURE.READONLY,ANALYTICS.NAMESPACE";

Parameter FIELDS = "Name,Caption,Content,Disabled";

ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 4
    Set pRows(1) = $ListBuild("Name", "string", 0)
    Set pRows(2) = $ListBuild("Caption", "string", 0)
    Set pRows(3) = $ListBuild("Content", "string", 0)
    Set pRows(4) = $ListBuild("Disabled", "boolean", 0)
    Quit $$$OK
}

ClassMethod NameDescription() As %String
{
    Quit "The new documentation item's name: 1 to 250 characters with no control character. A name the measure already holds is refused, compared without regard to case, so check the Documentation list first."
}

/// <p>The composed payload and diff of the create (AD-54) from the arguments with <code>Content</code> in the model's form, and the namespace the request is scoped to. The namespace adds no
/// diff row.</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(..ContentNormalized(pArgs), pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") || '$IsObject(pPayload) Quit tSC
    Do pPayload.%Set(..#NAMESPACEFIELD, ##class(OcuPilot.Kernel.Scope).Current(), "string")
    Quit tSC
}

/// <p>The composite id of the item the confirmed add <var>pWritten</var> created, or <code>""</code>.</p>
ClassMethod CreatedId(pWritten) As %String
{
    If '$IsObject(pWritten) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    If (pWritten.%GetTypeOf("QualityMeasure") '= "string") || (pWritten.%GetTypeOf("Name") '= "string") Quit ""
    Quit ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pWritten.%Get("QualityMeasure"), pWritten.%Get("Name")))
}

}
