/// <p>PMML models' New PMML definition (AD-55, AD-54, Story 24.14 Batch 3): <code>POST /analytics/pmml-models</code> creates one class that defines PMML models, from PMML text, in the request's namespace
/// through <class>OcuPilot.Screen.Tool.AnalyticsPmmlModelAdd</class>, the tool the agent's mint and confirm read. It is <class>OcuPilot.Area.Analytics.ListingGroupSave</class>'s Save with the definition's
/// own tool, screen, name member and sentence: the order of the Save, its hold on the class's name, its absence read, the prohibited set, the port's add and the read-back are the superclass's. The body's
/// members are <code>Class</code> and <code>PMML</code>; the rules over them are <method>OcuPilot.Port.AnalyticsPort.PmmlDefinitionViolations</method>'s and the port's own.</p>
Class OcuPilot.Area.Analytics.PmmlDefinitionSave Extends OcuPilot.Area.Analytics.ListingGroupSave
{

Parameter CREATETOOL = "OcuPilot.Screen.Tool.AnalyticsPmmlModelAdd";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsPmmlModelList";

/// <p>The class is the definition's name, and the id.</p>
Parameter NAMEMEMBER = "Class";

Parameter TAKENCODE = "ANALYTICS.PMML.TAKEN";

Parameter TAKENREASON = "This namespace already holds this class, or classes in its package.";

Parameter VIOLATIONSMETHOD = "PmmlDefinitionViolations";

/// <p>The port's shape rules over the body with the class <var>pName</var> set as the body names it.</p>
ClassMethod Violations(pNamespace As %String, pParent As %String, pName As %String, pFields As %DynamicObject, Output pViolations) As %Status
{
    Set tBody = ##class(%DynamicAbstractObject).%FromJSON(pFields.%ToJSON())
    Do tBody.%Set("Class", pName, "string")
    Quit $ClassMethod(..PortClass(), ..#VIOLATIONSMETHOD, $ClassMethod(..#CREATETOOL, "WriteType"), pName, "", tBody, .pViolations)
}

}
