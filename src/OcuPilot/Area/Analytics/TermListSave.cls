/// <p>Term lists' New term list (AD-55, AD-54, Story 24.2): <code>POST /analytics/term-lists</code> creates one term list in the request's
/// namespace through <class>OcuPilot.Screen.Tool.AnalyticsTermListAdd</class>, the tool the agent's mint and confirm read. It is
/// <class>OcuPilot.Area.Interop.ItemSave</class>'s Save for a member with no parent: the order of the Save, its hold on the list's name,
/// its absence read, the prohibited set, the port's add and the read-back are the superclass's. The body's members are <code>Name</code> and,
/// optionally, <code>Caption</code>, <code>Description</code>, <code>Pattern</code>, <code>SubjectArea</code>, <code>Fields</code> and
/// <code>HideValue</code>; the rules over them are <method>OcuPilot.Port.AnalyticsPort.TermListViolations</method>'s.</p>
Class OcuPilot.Area.Analytics.TermListSave Extends OcuPilot.Area.Interop.ItemSave
{

Parameter CREATETOOL = "OcuPilot.Screen.Tool.AnalyticsTermListAdd";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.AnalyticsTermListList";

/// <p>No parent: the list is namespace-scoped.</p>
Parameter PRODUCTIONMEMBER;

Parameter NAMEMEMBER = "Name";

Parameter NAMEEMPTYCODE = "ANALYTICS.TERMLIST.NAME";

Parameter TAKENCODE = "ANALYTICS.TERMLIST.TAKEN";

Parameter TAKENREASON = "This namespace already holds a term list with that name. Names are compared without regard to case.";

ClassMethod Violations(pNamespace As %String, pParent As %String, pName As %String, pFields As %DynamicObject, Output pViolations) As %Status
{
    Quit $ClassMethod(..PortClass(), "TermListViolations", $ClassMethod(..#CREATETOOL, "WriteType"), pName, "", pFields, .pViolations)
}

}
