/// <p>Schedule specs' New schedule spec (AD-55, AD-54, Story 24.15): <code>POST /interop/schedules</code> adds one schedule spec to the request's
/// namespace through <class>OcuPilot.Screen.Tool.InteropScheduleAdd</class>, the tool the agent's mint and confirm read. It is
/// <class>OcuPilot.Area.Interop.ItemSave</class>'s Save with no parent: a schedule spec belongs to its namespace, so the member is the name alone
/// (<parameter>PRODUCTIONMEMBER</parameter> is empty), and the order of the Save, its hold on the schedule spec's name, its absence read, the
/// prohibited set, the port's add and the read-back are the superclass's. The body's members are <code>Name</code>, <code>ScheduleSpec</code> and,
/// optionally, <code>Description</code> and <code>Deployable</code>; any other member is 400 <code>PORT.FIELD.UNEXPECTED</code>, so a name cannot be
/// changed through this route.</p>
/// <p>The rules over the name and the fields are <method>OcuPilot.Port.InteropPort.ScheduleViolations</method>'s, without the call that reaches the
/// vendor's validator, which the port's add makes after its gate (<method>Violations</method>).</p>
Class OcuPilot.Area.Interop.ScheduleSave Extends OcuPilot.Area.Interop.ItemSave
{

/// <p>The tool class both callers resolve the add through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.InteropScheduleAdd";

/// <p>The screen whose declared pairs gate this route.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropScheduleList";

/// <p>Empty: a schedule spec has no parent (<class>OcuPilot.Area.Interop.ItemSave</class>).</p>
Parameter PRODUCTIONMEMBER = "";

Parameter NAMEMEMBER = "Name";

Parameter NAMEEMPTYCODE = "INTEROP.SCHEDULE.NAME";

Parameter TAKENCODE = "INTEROP.SCHEDULE.TAKEN";

Parameter TAKENREASON = "This namespace already has a schedule spec with that name, in some letter case.";

/// <p>The rules over the schedule spec's name and fields, which call no vendor class: whether the vendor accepts the spec is judged by the port's
/// add, after its gate.</p>
ClassMethod Violations(pNamespace As %String, pParent As %String, pName As %String, pFields As %DynamicObject, Output pViolations) As %Status
{
    Quit $ClassMethod(..PortClass(), "ScheduleViolations", pName, pFields, .pViolations, 1, 0)
}

}
