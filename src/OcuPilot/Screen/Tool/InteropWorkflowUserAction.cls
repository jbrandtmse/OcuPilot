/// <p>What Interoperability's three workflow user writes share (AD-6, AD-51, AD-52, AD-53, AD-62, Story 24.17 Batch 3a): a write of one workflow user of the request's namespace through
/// <class>OcuPilot.Port.InteropPort</class>, reached by two callers -- the Workflow users list's New workflow user and its row actions Edit and Remove, and the agent's proposal and
/// confirmation. A workflow user is a user of the instance whom workflow tasks reach through the workflow roles they belong to; the port writes it with the vendor's own <code>%Save</code>
/// and <code>%DeleteId</code>, as the classic Workflow Users page does. The target is the user's name, kept exactly (AD-13).</p>
/// <p><b>A rename cannot be expressed</b>: the name is the target, and the update's settable fields are the full name and the active state; a different name is a remove and an add.</p>
/// <p>Its privileges, read, refusals and mint are <class>OcuPilot.Screen.Tool.InteropWorkflowAction</class>'s.</p>
Class OcuPilot.Screen.Tool.InteropWorkflowUserAction Extends OcuPilot.Screen.Tool.InteropWorkflowAction [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropWorkflowUserList";

/// <p>The fresh read: one workflow user, composed for the action.</p>
Parameter READTYPE = "WORKFLOWUSER";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Name,FullName,IsActive,Roles,Namespace";

/// <p>The classic page whose own resource an operator may have assigned beyond the screen's (AD-8, AD-44).</p>
Parameter CLASSICPAGES = "EnsPortal.WFUsers";

/// <p>The port method that judges a workflow user's name and fields.</p>
Parameter VIOLATIONSMETHOD = "WorkflowViolations";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTWORKFLOWUSERS
}

/// <p>What the schema says of the workflow user's name.</p>
ClassMethod NameDescription() As %String
{
    Quit "The workflow user's name, exactly as the Workflow users list reports it in its Name column. A workflow user the list does not report is refused."
}

/// <p>The full name and the active state as field rows the input schema is derived from (AD-3), with the name first when <var>pWithName</var>. The port has no body template to derive them
/// from.</p>
ClassMethod WorkflowFieldRows(pWithName As %Boolean, Output pRows) As %Status
{
    Kill pRows
    Set pRows = 0
    If pWithName Set pRows($Increment(pRows)) = $ListBuild("Name", "string", 0)
    Set pRows($Increment(pRows)) = $ListBuild("FullName", "string", 0)
    Set pRows($Increment(pRows)) = $ListBuild("IsActive", "boolean", 0)
    Quit $$$OK
}

/// <p>The derived schema with the full name and the active state described.</p>
ClassMethod DescribeFields(pSchema As %DynamicObject) As %DynamicObject
{
    If '$IsObject(pSchema) || (pSchema.%GetTypeOf("properties") '= "object") Quit pSchema
    Set tProperties = pSchema.%Get("properties")
    If tProperties.%GetTypeOf("FullName") = "object" Do tProperties.%Get("FullName").%Set("description", "The user's full name, as text, at most 128 characters with no control character. An empty string clears it.", "string")
    If tProperties.%GetTypeOf("IsActive") = "object" Do tProperties.%Get("IsActive").%Set("description", "Whether the workflow user is active. An inactive user is sent no new tasks through their workflow roles.", "string")
    Quit pSchema
}

}
