/// <p>HL7 schemas' New HL7 schema (AD-55, AD-54, Story 24.18 Batch 1): <code>POST /interop/hl7-schemas</code> adds one custom HL7 schema to the request's namespace through
/// <class>OcuPilot.Screen.Tool.InteropHl7SchemaAdd</class>, the tool the agent's mint and confirm read. It is <class>OcuPilot.Area.Interop.ItemSave</class>'s Save with no parent: a schema
/// belongs to its namespace, so the member is the name alone (<parameter>PRODUCTIONMEMBER</parameter> is empty), and the order of the Save, its hold on the schema's name, its absence read,
/// the prohibited set, the port's add and the read-back are the superclass's. The body's members are <code>Name</code> and, optionally, <code>Base</code> and <code>Description</code>; any other
/// member is 400 <code>PORT.FIELD.UNEXPECTED</code>, so a name cannot be changed through this route.</p>
/// <p>The rules over the name and the fields are <method>OcuPilot.Port.InteropPort.Hl7SchemaViolations</method>'s, which also judge the base held in the namespace.</p>
Class OcuPilot.Area.Interop.Hl7SchemaSave Extends OcuPilot.Area.Interop.ItemSave
{

/// <p>The tool class both callers resolve the add through (AD-55).</p>
Parameter CREATETOOL = "OcuPilot.Screen.Tool.InteropHl7SchemaAdd";

/// <p>The screen whose declared pairs gate this route.</p>
Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropHl7SchemaList";

/// <p>Empty: an HL7 schema has no parent (<class>OcuPilot.Area.Interop.ItemSave</class>).</p>
Parameter PRODUCTIONMEMBER = "";

Parameter NAMEMEMBER = "Name";

Parameter NAMEEMPTYCODE = "INTEROP.HL7.NAME";

Parameter TAKENCODE = "INTEROP.HL7.TAKEN";

Parameter TAKENREASON = "This namespace already has an HL7 schema with that name, in some letter case.";

/// <p>The rules over the schema's name and fields, which call no vendor class and read the namespace for the base alone.</p>
ClassMethod Violations(pNamespace As %String, pParent As %String, pName As %String, pFields As %DynamicObject, Output pViolations) As %Status
{
    Quit $ClassMethod(..PortClass(), "Hl7SchemaViolations", pName, pFields, .pViolations, 1, pNamespace)
}

}
