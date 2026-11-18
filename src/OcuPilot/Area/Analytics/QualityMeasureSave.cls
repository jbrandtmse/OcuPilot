/// <p>Quality measures' New quality measure (AD-55, AD-54, Story 24.12): <code>POST /analytics/quality-measures</code> creates one quality measure, with its class, in the request's
/// namespace through <class>OcuPilot.Screen.Tool.AnalyticsQualityMeasureAdd</class>, the tool the agent's mint and confirm read. It is
/// <class>OcuPilot.Area.Analytics.ListingGroupSave</class>'s Save with the measure's own tool, screen, name sentence and shape rules: the order of the Save, its hold on the measure's name, its
/// absence read, the prohibited set, the port's add and the read-back are the superclass's. The body's members are <code>Name</code> (<code>catalog/set/id</code>) and, optionally,
/// <code>Class</code>, <code>Caption</code>, <code>Description</code> and <code>SubjectArea</code>; the rules over them are <method>OcuPilot.Port.AnalyticsPort.QualityMeasureViolations</method>'s
/// and the port's own.</p>
Class OcuPilot.Area.Analytics.QualityMeasureSave Extends OcuPilot.Area.Analytics.ListingGroupSave
{

Parameter CREATETOOL = "OcuPilot.Screen.Tool.AnalyticsQualityMeasureAdd";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsQualityMeasureList";

Parameter TAKENCODE = "ANALYTICS.QUALITYMEASURE.TAKEN";

Parameter TAKENREASON = "This namespace already holds a quality measure or class with that name.";

Parameter VIOLATIONSMETHOD = "QualityMeasureViolations";

}
