/// <p>Production items' Copy (AD-55, AD-54, Story 20.40): <code>POST /interop/items/copy</code> copies one item of a production
/// of the request's namespace under a new name through <class>OcuPilot.Screen.Tool.InteropItemCopy</class>, the tool the agent's
/// mint and confirm read. It is <class>OcuPilot.Area.Interop.ItemSave</class>'s Save with the copy tool as the create: the order of
/// the Save, its hold on the new item's composite id, its absence read, the prohibited set, the port's copy and the read-back are
/// the superclass's. The body's members are <code>Production</code>, <code>Name</code> (the new item) and <code>CopyFrom</code>
/// (the source item's name).</p>
/// <p>The rules over the fields are <method>OcuPilot.Port.InteropPort.CopyViolations</method>'s (<method>Violations</method>).</p>
Class OcuPilot.Area.Interop.ItemCopy Extends OcuPilot.Area.Interop.ItemSave
{

/// <p>The tool class both callers resolve the copy through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.InteropItemCopy";

/// <p>The rules over the new name and <code>CopyFrom</code>: the port's
/// <method>OcuPilot.Port.InteropPort.CopyViolations</method>.</p>
ClassMethod Violations(pNamespace As %String, pParent As %String, pName As %String, pFields As %DynamicObject, Output pViolations) As %Status
{
    Quit $ClassMethod(..PortClass(), "CopyViolations", pNamespace, pParent, pName, pFields, .pViolations)
}

}
