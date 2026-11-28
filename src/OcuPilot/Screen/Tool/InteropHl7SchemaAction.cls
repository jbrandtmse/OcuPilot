/// <p>What Interoperability's HL7 schema add shares with the family's other tools (AD-6, AD-51, AD-52, AD-53, AD-62, Story 24.18 Batch 1): a write of one HL7 schema of the request's
/// namespace through <class>OcuPilot.Port.InteropPort</class>, reached by two callers, a control of the HL7 schemas list and the agent's proposal and confirmation. The target is the
/// schema's name, kept exactly (AD-13). It names the screen, the fresh read, the endpoint, the classic page whose resource an operator may have assigned beyond the screen's, and the port
/// method that judges a new schema's fields; its privileges, read and mint are <class>OcuPilot.Screen.Tool.InteropWorkflowAction</class>'s.</p>
Class OcuPilot.Screen.Tool.InteropHl7SchemaAction Extends OcuPilot.Screen.Tool.InteropWorkflowAction [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropHl7SchemaList";

/// <p>The fresh read: one schema.</p>
Parameter READTYPE = "HL7SCHEMA";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Category,Base,Description,Standard,Modified,Namespace";

/// <p>The vendor's own resource of the classic HL7 Schema Structures page and its dialog.</p>
Parameter WRITERESOURCE = "%Ens_EDISchema";

Parameter CLASSICPAGES = "EnsPortal.HL7.SchemaMain";

Parameter VIOLATIONSMETHOD = "Hl7SchemaViolations";

/// <p>The read field the card titles the schema by.</p>
Parameter TARGETFIELD = "Category";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTHL7SCHEMAS
}

/// <p>The schema's name, which the card titles it by: the fresh read's <code>Category</code>, else the agent's own <code>Name</code>.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Category") = "string") Quit pFresh.%Get("Category")
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("Name") = "string") Quit pArgs.%Get("Name")
    Quit ""
}

}
