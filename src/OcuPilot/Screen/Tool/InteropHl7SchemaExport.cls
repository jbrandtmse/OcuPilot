/// <p>Interoperability's HL7 schema export (AD-6, AD-21, AD-51, AD-53, AD-62, Story 24.18 Batch 1): the vendor's own export of one schema's <code>.HL7</code> document, either to a server file
/// or to this browser. It is <class>OcuPilot.Screen.Tool.InteropLookupTableExport</class>'s shape over the HL7 schemas endpoint: the list's row action <code>export</code> names a server file by
/// <code>root</code> and <code>path</code>, an allowed directory and a relative name under it (AD-21's sixth case, resolved by <class>OcuPilot.Port.PathPort</class> as an overwriting file),
/// <code>export-browser</code> names none and answers the lines for the page to save, and the agent's proposal and confirmation always names a server file. A file already at the name is replaced.</p>
/// <p><b>An export only reads the namespace</b>: it declares the screen's own pairs, READ on the namespace's globals database and PathPort's pairs when it names a server file. A standard
/// schema may be exported. The lines answered to the screen are its output alone (AD-39's fifth exception); they are never stored or logged.</p>
Class OcuPilot.Screen.Tool.InteropHl7SchemaExport Extends OcuPilot.Screen.Tool.InteropLookupTableExport
{

Parameter TOOLNAME = "interop.hl7schemas.export";

Parameter DESCRIPTION = "Propose writing one HL7 schema to a file on the server, in the instance's own HL7 schema export format, so another instance can import it. Name the schema exactly as the HL7 schemas list reports it in its Name column, letter case included. Name the file by `root`, an allowed directory exactly as the Allowed directories screen lists it, and `path`, a relative file name under it whose directory exists; an existing file at that name is replaced, so say so in the rationale. A schema the namespace does not hold is refused. A standard schema may be exported.";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropHl7SchemaList";

/// <p>The fresh read: one schema, echoing the file the query names.</p>
Parameter READTYPE = "HL7SCHEMA";

Parameter READANSWERS = "Category,Base,Description,Standard,Modified,Namespace,root,path";

/// <p>The export's own pair is the classic page's READ, which the screen's pairs already hold; the file's pairs are the arguments' (<method>ArgumentPairs</method>).</p>
Parameter WRITERESOURCE = "%Ens_EDISchema";

Parameter WRITEPERMISSION = "READ";

Parameter CLASSICPAGES = "EnsPortal.HL7.SchemaMain";

Parameter WRITETYPE = "EXPORTHL7SCHEMA";

/// <p>The schema as reviewed, the namespace and the file. The file is in the subject because the stored payload is narrowed to it, and <method>PortQuery</method> reads it from that payload.</p>
Parameter FINGERPRINTSUBJECT = "Category,Base,Description,Standard,Modified,Namespace,root,path";

Parameter PRECONDITIONFIELD = "Category";

Parameter PRECONDITIONCODES = "INTEROP.NAMESPACE";

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

/// <p>The derived schema with the schema's name described and <code>root</code> and <code>path</code> added, both required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The HL7 schema to export, named exactly as this namespace's HL7 schemas list reports it in its Name column, letter case included. A schema the list does not report is refused.", "string")
    }
    Quit tSchema
}

/// <p>The card has no state row of its own beside the file's rows. A read that answered no schema is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Category") '= "string") Set pProblem = "this instance did not report the schema"
    Quit $$$OK
}

}
