/// <p>What Interoperability's three workflow role writes share (AD-6, AD-51, AD-52, AD-53, AD-62, Story 24.17 Batch 3b): a write of one workflow role of the request's namespace through
/// <class>OcuPilot.Port.InteropPort</class>, reached by two callers -- the Workflow roles list's New workflow role and its row actions Edit and Remove, and the agent's proposal and
/// confirmation. A workflow role is a group of workflow users who are sent the same tasks; the port writes it with the vendor's own <code>%Save</code> and <code>%DeleteId</code>, as the classic
/// Workflow Roles page does. The target is the role's name, kept exactly (AD-13).</p>
/// <p><b>A rename cannot be expressed</b>: the name is the target, and the update's settable fields are the description and the capacity; a different name is a remove and an add.</p>
/// <p>Its privileges, read, refusals and mint are <class>OcuPilot.Screen.Tool.InteropWorkflowAction</class>'s.</p>
Class OcuPilot.Screen.Tool.InteropWorkflowRoleAction Extends OcuPilot.Screen.Tool.InteropWorkflowAction [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropWorkflowRoleList";

/// <p>The fresh read: one workflow role, composed for the action.</p>
Parameter READTYPE = "WORKFLOWROLE";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Name,Description,Capacity,Members,Namespace";

/// <p>The classic page whose own resource an operator may have assigned beyond the screen's (AD-8, AD-44).</p>
Parameter CLASSICPAGES = "EnsPortal.WFRoles";

/// <p>The port method that judges a workflow role's name and fields.</p>
Parameter VIOLATIONSMETHOD = "WorkflowRoleViolations";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTWORKFLOWROLES
}

/// <p>What the schema says of the workflow role's name.</p>
ClassMethod NameDescription() As %String
{
    Quit "The workflow role's name, exactly as the Workflow roles list reports it in its Name column. A workflow role the list does not report is refused."
}

/// <p>The description and the capacity as field rows the input schema is derived from (AD-3), with the name first when <var>pWithName</var>. The port has no body template to derive them
/// from.</p>
ClassMethod WorkflowRoleFieldRows(pWithName As %Boolean, Output pRows) As %Status
{
    Kill pRows
    Set pRows = 0
    If pWithName Set pRows($Increment(pRows)) = $ListBuild("Name", "string", 0)
    Set pRows($Increment(pRows)) = $ListBuild("Description", "string", 0)
    Set pRows($Increment(pRows)) = $ListBuild("Capacity", "number", 0)
    Quit $$$OK
}

/// <p>The derived schema with the description and the capacity described.</p>
ClassMethod DescribeFields(pSchema As %DynamicObject) As %DynamicObject
{
    If '$IsObject(pSchema) || (pSchema.%GetTypeOf("properties") '= "object") Quit pSchema
    Set tProperties = pSchema.%Get("properties")
    If tProperties.%GetTypeOf("Description") = "object" Do tProperties.%Get("Description").%Set("description", "The role's description, as text, at most 2,000 characters. An empty string clears it.", "string")
    If tProperties.%GetTypeOf("Capacity") = "object" Do tProperties.%Get("Capacity").%Set("description", "The role's capacity, a whole number from 1 to 100, used to report the role's active tasks as a percentage. Omit it on an add to take 100.", "string")
    Quit pSchema
}

}
