/// <p>Documentation's Add documentation item (AD-55, AD-54, Story 24.12): <code>POST /analytics/quality-measure-metas</code> adds one documentation item to a quality measure of the request's namespace
/// through <class>OcuPilot.Screen.Tool.AnalyticsQualityMeasureMetaAdd</class>, the tool the agent's mint and confirm read. It is <class>OcuPilot.Area.Analytics.ListingSave</class>'s Save with the
/// quality measure as the parent and the item's name as the member: the order of the Save, its hold on the item's id, its absence read, the prohibited set, the port's add and the read-back are the
/// superclass's. The body's members are <code>QualityMeasure</code>, <code>Name</code> and, optionally, <code>Caption</code>, <code>Content</code> and <code>Disabled</code>; a measure the namespace does
/// not hold is 404 <code>ANALYTICS.QUALITYMEASURE.ABSENT</code>, and the rules over the fields are <method>OcuPilot.Port.AnalyticsPort.QualityMeasureMetaViolations</method>'s and the port's own.</p>
Class OcuPilot.Area.Analytics.QualityMeasureMetaSave Extends OcuPilot.Area.Analytics.ListingSave
{

Parameter CREATETOOL = "OcuPilot.Screen.Tool.AnalyticsQualityMeasureMetaAdd";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsQualityMeasureMetaList";

Parameter PRODUCTIONMEMBER = "QualityMeasure";

Parameter TAKENCODE = "ANALYTICS.QUALITYMEASURE.METATAKEN";

Parameter TAKENREASON = "This quality measure already holds a documentation item with that name.";

ClassMethod ParentEndpoint() As %String
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).#ENDPOINTQUALITYMEASURES
}

ClassMethod ParentReadType() As %String
{
    Quit ##class(OcuPilot.Port.AnalyticsPort).#TYPEQUALITYMEASURE
}

ClassMethod ParentAbsentCode() As %String
{
    Quit ##class(OcuPilot.Api.AnalyticsError).#QUALITYMEASUREABSENT
}

/// <p>The port's rules over the item <var>pName</var> and its fields.</p>
ClassMethod Violations(pNamespace As %String, pParent As %String, pName As %String, pFields As %DynamicObject, Output pViolations) As %Status
{
    Quit $ClassMethod(..PortClass(), "QualityMeasureMetaViolations", $ClassMethod(..#CREATETOOL, "WriteType"), pParent, pName, pFields, .pViolations)
}

}
