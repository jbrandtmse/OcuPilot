/// <p>Workflow roles' New workflow role (AD-55, AD-54, Story 24.17 Batch 3b): <code>POST /interop/workflow-roles</code> adds one workflow role to the request's namespace through
/// <class>OcuPilot.Screen.Tool.InteropWorkflowRoleAdd</class>, the tool the agent's mint and confirm read. It is <class>OcuPilot.Area.Interop.ItemSave</class>'s Save with no parent: a workflow
/// role belongs to its namespace, so the member is the name alone (<parameter>PRODUCTIONMEMBER</parameter> is empty), and the order of the Save, its hold on the role's name, its absence read,
/// the prohibited set, the port's add and the read-back are the superclass's. The body's members are <code>Name</code> and, optionally, <code>Description</code> and <code>Capacity</code>; any
/// other member is 400 <code>PORT.FIELD.UNEXPECTED</code>, so a name cannot be changed through this route.</p>
/// <p>The rules over the name's shape and the fields are <method>OcuPilot.Port.InteropPort.WorkflowRoleViolations</method>'s, which reads no vendor class.</p>
Class OcuPilot.Area.Interop.WorkflowRoleSave Extends OcuPilot.Area.Interop.ItemSave
{

/// <p>The tool class both callers resolve the add through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.InteropWorkflowRoleAdd";

/// <p>The screen whose declared pairs gate this route.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropWorkflowRoleList";

/// <p>Empty: a workflow role has no parent (<class>OcuPilot.Area.Interop.ItemSave</class>).</p>
Parameter PRODUCTIONMEMBER = "";

Parameter NAMEMEMBER = "Name";

Parameter NAMEEMPTYCODE = "INTEROP.WORKFLOW.ROLENAME";

Parameter TAKENCODE = "INTEROP.WORKFLOW.ROLETAKEN";

Parameter TAKENREASON = "This namespace already has a workflow role with that name, in some letter case.";

/// <p>The rules over the workflow role's name and fields, which call no vendor class.</p>
ClassMethod Violations(pNamespace As %String, pParent As %String, pName As %String, pFields As %DynamicObject, Output pViolations) As %Status
{
    Quit $ClassMethod(..PortClass(), "WorkflowRoleViolations", pName, pFields, .pViolations, 1)
}

}
