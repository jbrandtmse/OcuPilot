/// <p>Interoperability's HL7 schema delete (AD-6, AD-10, AD-51, AD-53, AD-62, Story 24.18 Batch 1): remove one custom HL7 schema and everything it defines. A schema based on it, and an item
/// or a rule that names it, can no longer find it, which the card says (<code>INTEROP.HL7.DELETE</code>). It is <class>OcuPilot.Screen.Tool.InteropLookupTableDelete</class>'s shape over the
/// HL7 schemas endpoint.</p>
/// <p><b>It is destructive</b>: a deleted schema cannot be restored from OcuPilot, so its card draws the destructive treatment, its row action types the schema's name, and its governance key
/// ships disabled (AD-22). The fingerprint covers the schema's base, description, standard mark and stamp, so a schema changed after the mint closes the proposal target-changed. A standard
/// schema is refused by the port, <code>INTEROP.HL7.STANDARD</code>, and a namespace under source control by <code>INTEROP.HL7.SOURCECONTROL</code>. Its read-back reads the schema gone on the port's 404.</p>
/// <p>Two callers reach it: the list's row action Delete through <class>OcuPilot.Api.ScreenAction</class> and the agent's proposal and confirmation. It declares
/// <code>%Ens_EDISchema:WRITE</code> and WRITE on the namespace's globals database beyond the screen's pairs (AD-8, AD-62), and the classic HL7 Schema Structures page's own resource.</p>
Class OcuPilot.Screen.Tool.InteropHl7SchemaDelete Extends OcuPilot.Screen.Tool.InteropLookupTableDelete
{

Parameter TOOLNAME = "interop.hl7schemas.delete";

Parameter DESCRIPTION = "Propose deleting one custom HL7 schema of the namespace the user is working in, with everything it defines, which cannot be restored. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the schema exactly as the HL7 schemas list reports it in its Name column, letter case included. Schemas based on it, and items and rules that name it, can no longer find it. A standard schema, which the instance provides, a schema the namespace does not hold and a namespace under source control are refused. If the schema changes before the proposal is confirmed, nothing is deleted.";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropHl7SchemaList";

/// <p>The fresh read: one schema.</p>
Parameter READTYPE = "HL7SCHEMA";

Parameter READANSWERS = "Category,Base,Description,Standard,Modified,Namespace";

Parameter WRITERESOURCE = "%Ens_EDISchema";

Parameter CLASSICPAGES = "EnsPortal.HL7.SchemaMain";

Parameter WRITETYPE = "DELETEHL7SCHEMA";

/// <p>The schema as reviewed and its namespace, which the stored payload keeps so the confirm and the script form act where the proposal read.</p>
Parameter FINGERPRINTSUBJECT = "Category,Base,Description,Standard,Modified,Namespace";

Parameter PRECONDITIONFIELD = "Category";

Parameter CONSEQUENCECODE = "INTEROP.HL7.DELETE";

Parameter PRECONDITIONCODES = "INTEROP.HL7.SOURCECONTROL,INTEROP.HL7.STANDARD,INTEROP.NAMESPACE";

/// <p>The removal rows the card shows: the schema, what it is based on and its description.</p>
Parameter REMOVALROWS = "Category,Base,Description";

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

/// <p>The derived schema with the schema's name described: the target is one schema, named as the HL7 schemas list reports it.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The HL7 schema, named exactly as this namespace's HL7 schemas list reports it in its Name column, letter case included. A schema the list does not report is refused.", "string")
    }
    Quit tSchema
}

/// <p>The removal rows this proposal's card shows, from the fresh read <var>pFresh</var>: one per <parameter>REMOVALROWS</parameter> name, carrying the value the instance holds and no
/// after-state. A read that answered no schema is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Category") '= "string") {
            Set pProblem = "this instance did not report the schema, and a schema whose state is unknown is not one to delete"
            Quit
        }
        Set pRows = ..RemovalRows(pFresh)
    } Catch ex {
        Set pRows = []
        Set pProblem = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

}
