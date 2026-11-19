/// <p>What the quality measure editor's three documentation write tools share (AD-6, AD-13, AD-51, AD-52, AD-53, AD-61, AD-65, Story 24.12): a write of one documentation item of a quality
/// measure of the request's namespace through <class>OcuPilot.Port.AnalyticsPort</class>, reached by two callers, the Documentation screen's own actions and the agent's proposal and
/// confirmation. It is <class>OcuPilot.Screen.Tool.AnalyticsQualityMeasureAction</class> with the items' own screen, read and port rules, declared as parameters and class methods.</p>
/// <p><b>The target is the composite <code>[QualityMeasure, Name]</code></b> (<class>OcuPilot.Screen.Tool.AnalyticsQualityMeasureMetaMint</class>), each part kept exactly (AD-13).
/// <b>The fresh read is the port's <code>QUALITYMEASUREMETA</code></b>, composed for the action at the mint and at a screen action, and carrying the class's <code>Version</code> as the
/// measure tools' reads do.</p>
/// <p><b>An item's content is the markup the model holds</b> (<method>OcuPilot.Port.AnalyticsPort.NormalizedContent</method>): a caller's <code>Content</code> is sent in that form, so the
/// item reads back as sent (AD-58), and a content the model cannot hold is refused by the port before anything is saved.</p>
Class OcuPilot.Screen.Tool.AnalyticsQualityMeasureMetaAction Extends OcuPilot.Screen.Tool.AnalyticsQualityMeasureAction [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsQualityMeasureMetaList";

/// <p>The fresh read: one documentation item.</p>
Parameter READTYPE = "QUALITYMEASUREMETA";

Parameter READANSWERS = "QualityMeasure,Name,Caption,Section,Content,Disabled,Version,Namespace";

Parameter VIOLATIONSMETHOD = "QualityMeasureMetaViolations";

Parameter PROBLEMMETHOD = "QualityMeasureMetaProblem";

/// <p>The argument naming the quality measure the item belongs to.</p>
Parameter MEASUREARGUMENT = "QualityMeasure";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).#ENDPOINTQUALITYMEASUREMETAS
}

/// <p><class>OcuPilot.Screen.Tool.AnalyticsQualityMeasureMetaMint</class>, which builds the composite id.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.AnalyticsQualityMeasureMetaMint"
}

/// <p>The item's name, which the screen's rows carry it under.</p>
ClassMethod IdArgument() As %String
{
    Quit "Name"
}

/// <p>What the schema says of the item's name.</p>
ClassMethod NameDescription() As %String
{
    Quit "The documentation item's name, as the measure's Documentation list reports it in its Name column. An item the measure does not hold is refused."
}

/// <p>The derived schema with the measure added and required, and the name described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set(..#MEASUREARGUMENT, {"type": "string", "description": "The quality measure, named exactly as the Quality measures list reports it in its Name column."})
    If tSchema.%GetTypeOf("required") = "array" Do tSchema.%Get("required").%Push(..#MEASUREARGUMENT)
    If tProperties.%GetTypeOf(..IdArgument()) = "object" Do tProperties.%Get(..IdArgument()).%Set("description", ..NameDescription(), "string")
    If tProperties.%GetTypeOf("Content") = "object" Do tProperties.%Get("Content").%Set("description", "The item's text as markup: plain text, or text with tags such as <b>x</b>. A literal ampersand or less-than sign is written &amp; or &lt;. Line breaks are not kept. Text that is not well-formed markup is refused.", "string")
    Quit tSchema
}

/// <p>The measure inside the composite id <var>pIdValue</var> in <var>pGroup</var>, and the item in <var>pListing</var>: both <code>""</code> for any other spelling.</p>
ClassMethod TargetParts(pIdValue As %String, Output pGroup As %String, Output pListing As %String)
{
    If '##class(OcuPilot.Port.AnalyticsPort).QualityMeasureTarget(..Endpoint(), pIdValue, .pGroup, .pListing) {
        Set pGroup = ""
        Set pListing = ""
    }
}

/// <p>A copy of <var>pArgs</var> whose <code>Content</code>, when a string, is the form the model holds (<method>OcuPilot.Port.AnalyticsPort.NormalizedContent</method>), so the payload
/// both callers send reads back as sent (AD-58). A content that cannot be held is left as sent, and the port refuses it.</p>
ClassMethod ContentNormalized(pArgs As %DynamicObject) As %DynamicObject
{
    If '$IsObject(pArgs) || 'pArgs.%IsA("%Library.DynamicObject") Quit pArgs
    Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
    If tArgs.%GetTypeOf("Content") = "string" Do tArgs.%Set("Content", ##class(OcuPilot.Port.AnalyticsPort).NormalizedContent(tArgs.%Get("Content")), "string")
    Quit tArgs
}

/// <p>The item's members the dialogs send as text: each as sent, which may be empty, <code>Content</code> in the model's form; <code>Disabled</code> as <code>true</code> or <code>false</code>.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    For tName = "Caption", "Content" {
        Do ..CarryText(pValues, pArgs, tName)
    }
    Set pArgs = ..ContentNormalized(pArgs)
    Set pProblem = ..CarryDisabled(pValues, pArgs)
    Quit $$$OK
}

}
