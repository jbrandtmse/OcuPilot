/// <p>What the quality measure editor's three group and element write tools share (AD-6, AD-13, AD-51, AD-52, AD-53, AD-61, AD-65, Story 24.12): a write of one element of one group of a
/// quality measure of the request's namespace, or of the group itself, through <class>OcuPilot.Port.AnalyticsPort</class>, reached by two callers, the Groups and elements screen's own
/// actions and the agent's proposal and confirmation. It is <class>OcuPilot.Screen.Tool.AnalyticsQualityMeasureAction</class> with the elements' own screen, read and port rules, declared as
/// parameters and class methods. Groups ride on the element writes: an empty <code>Name</code> names the group itself.</p>
/// <p><b>The target is the composite <code>[QualityMeasure, Group, Name]</code></b> (<class>OcuPilot.Screen.Tool.AnalyticsQualityMeasureElementMint</class>), each part kept exactly (AD-13).
/// <b>The fresh read is the port's <code>QUALITYMEASUREELEMENT</code></b>, composed for the action at the mint and at a screen action: an add reads absent, and the others are refused by the
/// port's own codes when the measure, group or element is not there or two classes declare the measure. The row carries the class's <code>Version</code>, so a class changed after the mint
/// closes the proposal through the fingerprint.</p>
Class OcuPilot.Screen.Tool.AnalyticsQualityMeasureElementAction Extends OcuPilot.Screen.Tool.AnalyticsQualityMeasureAction [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsQualityMeasureElementList";

/// <p>The fresh read: one element, or one group.</p>
Parameter READTYPE = "QUALITYMEASUREELEMENT";

Parameter READANSWERS = "QualityMeasure,Group,GroupCaption,GroupDescription,GroupDisabled,Name,Caption,MDX,Disabled,Version,Namespace";

Parameter VIOLATIONSMETHOD = "QualityMeasureElementViolations";

Parameter PROBLEMMETHOD = "QualityMeasureElementProblem";

/// <p>The arguments that name the measure and the group the element belongs to.</p>
Parameter MEASUREARGUMENT = "QualityMeasure";

Parameter GROUPARGUMENT = "Group";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).#ENDPOINTQUALITYMEASUREELEMENTS
}

/// <p><class>OcuPilot.Screen.Tool.AnalyticsQualityMeasureElementMint</class>, which builds the composite id.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.AnalyticsQualityMeasureElementMint"
}

/// <p>The element's name, which the screen's rows carry it under; empty for the group itself.</p>
ClassMethod IdArgument() As %String
{
    Quit "Name"
}

/// <p>What the schema says of the element's name.</p>
ClassMethod NameDescription() As %String
{
    Quit "The element's name, as the group's Groups and elements list reports it in its Name column; empty for the group itself. An element the group does not hold is refused."
}

/// <p>The derived schema with the measure and the group added and required, and the name described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set(..#MEASUREARGUMENT, {"type": "string", "description": "The quality measure, named exactly as the Quality measures list reports it in its Name column."})
    Do tProperties.%Set(..#GROUPARGUMENT, {"type": "string", "description": "The group, named exactly as the Groups and elements list reports it in its Group column."})
    If tSchema.%GetTypeOf("required") = "array" {
        Do tSchema.%Get("required").%Push(..#MEASUREARGUMENT)
        Do tSchema.%Get("required").%Push(..#GROUPARGUMENT)
    }
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", ..NameDescription(), "string")
    Quit tSchema
}

/// <p>The measure inside the composite id <var>pIdValue</var> in <var>pGroup</var>, and in <var>pListing</var> the group and the element joined by the composite separator
/// (<method>OcuPilot.Port.AnalyticsPort.QualityMeasureTarget</method>'s part): both <code>""</code> for any other spelling.</p>
ClassMethod TargetParts(pIdValue As %String, Output pGroup As %String, Output pListing As %String)
{
    If '##class(OcuPilot.Port.AnalyticsPort).QualityMeasureTarget(..Endpoint(), pIdValue, .pGroup, .pListing) {
        Set pGroup = ""
        Set pListing = ""
    }
}

/// <p>The element's members the dialogs send as text: each as sent, which may be empty; the flags as <code>true</code> or <code>false</code>.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    For tName = "Caption", "MDX", "GroupCaption", "GroupDescription" {
        Do ..CarryText(pValues, pArgs, tName)
    }
    Set pProblem = ..CarryBoolean(pValues, pArgs, "Disabled")
    If pProblem = "" Set pProblem = ..CarryBoolean(pValues, pArgs, "GroupDisabled")
    Quit $$$OK
}

}
