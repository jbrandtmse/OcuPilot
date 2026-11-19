/// <p>Analytics' quality measure documentation change (AD-4, AD-6, AD-51, AD-53, AD-56, AD-61, AD-65, Story 24.12): change one documentation item of a quality measure of the request's
/// namespace: its caption, content or disabled flag. A merge over the item's fresh read: the card shows the rows it moves. The write replaces only the class's <code>QualityMeasure</code>
/// XData, composed from the model read at the write, so every other part, the item's section and every other line of the class are kept as stored. An item's name is never changed here.</p>
/// <p>Two callers reach it: the Documentation screen's row action Change documentation item through <class>OcuPilot.Api.ScreenAction</class>, whose values are strings (the disabled flag
/// travels as <code>true</code> or <code>false</code>), and the agent's proposal and confirmation. <code>Content</code> is sent in the model's own form
/// (<method>OcuPilot.Screen.Tool.AnalyticsQualityMeasureMetaAction.ContentNormalized</method>).</p>
Class OcuPilot.Screen.Tool.AnalyticsQualityMeasureMetaSet Extends OcuPilot.Screen.Tool.AnalyticsQualityMeasureMetaAction
{

Parameter TOOLNAME = "analytics.qualitymeasuremetas.set";

Parameter DESCRIPTION = "Propose changing one documentation item of a quality measure in the namespace the user is working in: its caption, content (markup: plain text, or text with tags; a literal ampersand or less-than sign is written as an entity) or disabled flag. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the measure and the item as the Quality measures and Documentation lists report them, and give only what changes. The measure's class is saved and compiled, and a failed compile puts the class back. An item the measure does not hold, content that is not well-formed markup, and a measure that two classes define or that is linked to another measure are refused.";

Parameter WRITETYPE = "ENTRYSET";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

Parameter SCREENACTIONS = "set";

Parameter SCREENVALUES = "set=Caption:Content:Disabled";

Parameter SCREENOPTIONAL = "set=Caption:Content:Disabled";

Parameter SCREENEMPTY = "set=Caption:Content";

Parameter READBACKFIELDS = "Caption,Content,Disabled";

Parameter PRECONDITIONCODES = "ANALYTICS.QUALITYMEASURE.PARTABSENT,ANALYTICS.QUALITYMEASURE.ABSENT,ANALYTICS.QUALITYMEASURE.AMBIGUOUS,ANALYTICS.QUALITYMEASURE.READONLY,ANALYTICS.NAMESPACE";

Parameter FIELDS = "Caption,Content,Disabled";

ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 3
    Set pRows(1) = $ListBuild("Caption", "string", 0)
    Set pRows(2) = $ListBuild("Content", "string", 0)
    Set pRows(3) = $ListBuild("Disabled", "boolean", 0)
    Quit $$$OK
}

/// <p>The merge of the fresh read and the arguments with <code>Content</code> in the model's form, so the payload both callers send reads back as sent (AD-58).</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Quit ##super(pFresh, ..ContentNormalized(pArgs), pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
}

}
