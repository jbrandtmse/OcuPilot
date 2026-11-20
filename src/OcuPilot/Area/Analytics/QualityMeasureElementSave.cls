/// <p>Groups and elements' Add element (AD-55, AD-54, Story 24.12): <code>POST /analytics/quality-measure-elements</code> adds one element to a group of a quality measure of the request's namespace
/// through <class>OcuPilot.Screen.Tool.AnalyticsQualityMeasureElementAdd</class>, the tool the agent's mint and confirm read. It is <class>OcuPilot.Area.Analytics.ListingSave</class>'s Save with the
/// quality measure as the parent, the group as a part of the element's composite id and the element's name as the member: the order of the Save, its hold on the element's id, its absence read, the
/// prohibited set, the port's add and the read-back are the superclass's. The body's members are <code>QualityMeasure</code>, <code>Group</code>, <code>Name</code> and, optionally,
/// <code>Caption</code>, <code>MDX</code>, <code>Disabled</code>, <code>GroupCaption</code>, <code>GroupDescription</code> and <code>GroupDisabled</code>; a measure the namespace does not hold is 404
/// <code>ANALYTICS.QUALITYMEASURE.ABSENT</code>, and the rules over the fields are <method>OcuPilot.Port.AnalyticsPort.QualityMeasureElementViolations</method>'s and the port's own.</p>
Class OcuPilot.Area.Analytics.QualityMeasureElementSave Extends OcuPilot.Area.Analytics.ListingSave
{

Parameter CREATETOOL = "OcuPilot.Screen.Tool.AnalyticsQualityMeasureElementAdd";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsQualityMeasureElementList";

Parameter PRODUCTIONMEMBER = "QualityMeasure";

/// <p>The body member naming the group, which is a part of the element's id and no field of the add.</p>
Parameter GROUPMEMBER = "Group";

Parameter TAKENCODE = "ANALYTICS.QUALITYMEASURE.ELEMENTTAKEN";

Parameter TAKENREASON = "This group already holds an element with that name.";

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

/// <p>The composite id <code>[QualityMeasure, Group, Name]</code>, <code>""</code> when a part is empty or carries the separator character; the group is <var>pFields</var>' <code>Group</code>.</p>
ClassMethod IdOf(pProduction As %String, pName As %String, pFields As %DynamicObject = "") As %String
{
    Set tGroup = $Select($IsObject(pFields) && (pFields.%GetTypeOf(..#GROUPMEMBER) = "string"): pFields.%Get(..#GROUPMEMBER), 1: "")
    Set tSeparator = $Char(##class(OcuPilot.Kernel.EntityId).#COMPOSITESEPARATOR)
    If (pProduction = "") || (tGroup = "") || (pName = "") || (pProduction [ tSeparator) || (tGroup [ tSeparator) || (pName [ tSeparator) Quit ""
    Quit ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pProduction, tGroup, pName))
}

/// <p>The port's rules over the element <var>pName</var> of the group <var>pFields</var> names and its fields.</p>
ClassMethod Violations(pNamespace As %String, pParent As %String, pName As %String, pFields As %DynamicObject, Output pViolations) As %Status
{
    Set tGroup = $Select(pFields.%GetTypeOf(..#GROUPMEMBER) = "string": pFields.%Get(..#GROUPMEMBER), 1: "")
    Quit $ClassMethod(..PortClass(), "QualityMeasureElementViolations", $ClassMethod(..#CREATETOOL, "WriteType"), pParent, tGroup _ $Char(##class(OcuPilot.Kernel.EntityId).#COMPOSITESEPARATOR) _ pName, pFields, .pViolations)
}

/// <p>The superclass's refusal of a body key the tool does not settle, with the group, which the id carries, left out.</p>
ClassMethod Unexpected(pToolClass As %String, pArgs As %DynamicObject, Output pHttpStatus As %Integer, Output pFault As %DynamicObject) As %Status [ Private ]
{
    Set tArgs = ##class(%DynamicAbstractObject).%FromJSON(pArgs.%ToJSON())
    If tArgs.%GetTypeOf(..#GROUPMEMBER) '= "unassigned" Do tArgs.%Remove(..#GROUPMEMBER)
    Quit ##super(pToolClass, tArgs, .pHttpStatus, .pFault)
}

}
