/// <p>Role members' Add member (AD-55, AD-54, Story 24.17 Batch 3b): <code>POST /interop/workflow-members</code> adds one workflow user to a workflow role of the request's namespace through
/// <class>OcuPilot.Screen.Tool.InteropWorkflowMemberAdd</class>, the tool the agent's mint and confirm read. It is <class>OcuPilot.Area.Interop.ItemSave</class>'s Save with the role as the parent and
/// the user as the member: the order of the Save, its hold on the membership's composite id, its absence read, the prohibited set, the port's add and the read-back are the superclass's.</p>
/// <p>A role is judged by the port's add, after the gate, so the parent check passes (<method>ParentHeld</method>), and the rules over the fields are
/// <method>OcuPilot.Port.InteropPort.WorkflowMemberViolations</method>'s (<method>Violations</method>), which read no vendor class. The body's members are <code>Role</code>, <code>User</code>
/// and, optionally, <code>Ranking</code> and <code>Title</code>.</p>
Class OcuPilot.Area.Interop.WorkflowMemberSave Extends OcuPilot.Area.Interop.ItemSave
{

/// <p>The tool class both callers resolve the add through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.InteropWorkflowMemberAdd";

/// <p>The screen whose declared pairs gate this route.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropWorkflowMemberList";

/// <p>The body members that identify the membership: its role and its user.</p>
Parameter PRODUCTIONMEMBER = "Role";

Parameter NAMEMEMBER = "User";

Parameter PARENTEMPTYCODE = "INTEROP.WORKFLOW.ROLENAME";

Parameter NAMEEMPTYCODE = "INTEROP.WORKFLOW.MEMBERUSER";

Parameter TAKENCODE = "INTEROP.WORKFLOW.MEMBERTAKEN";

Parameter TAKENREASON = "This workflow user is already a member of this role.";

/// <p>1: whether the role is held is the port's own judgment at the add, which answers it 404 after its gate.</p>
ClassMethod ParentHeld(pNamespace As %String, pParent As %String) As %Boolean
{
    Quit 1
}

/// <p>The rules over the membership's names and fields, which call no vendor class.</p>
ClassMethod Violations(pNamespace As %String, pParent As %String, pName As %String, pFields As %DynamicObject, Output pViolations) As %Status
{
    Quit $ClassMethod(..PortClass(), "WorkflowMemberViolations", pParent, pName, pFields, .pViolations, 1)
}

}
