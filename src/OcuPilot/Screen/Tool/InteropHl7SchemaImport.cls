/// <p>Interoperability's HL7 schema import (AD-6, AD-10, AD-21, AD-51, AD-53, AD-62, Story 24.18 Batch 1): the one custom HL7 schema an export file holds replaces the schema of that name in
/// the namespace, or creates it; anything the file does not define is removed. It is <class>OcuPilot.Screen.Tool.InteropLookupTableImport</class>'s shape over the HL7 schemas endpoint: the
/// list's <code>import</code> reads a server file named by its <code>root</code> and <code>path</code> values, <code>import-local</code> a file on the person's computer sent as its
/// <code>fileName</code> and <code>content</code> values, and the agent's proposal and confirmation names a server file only.</p>
/// <p><b>The target is the schema the file holds.</b> The agent names the schema it expects the file to hold in <code>Name</code>, and the port refuses a file that holds another or is not
/// exactly one HL7 schema (<code>INTEROP.HL7.IMPORTSHAPE</code>). A file that marks its schema standard, or whose schema the namespace holds as standard, is refused
/// <code>INTEROP.HL7.IMPORTSTANDARD</code>; a name held only in another letter case, <code>INTEROP.HL7.CASE</code>. A local file's name and text are screen values alone: the input schema
/// never carries them, and nothing stores or logs them.</p>
/// <p><b>The reviewed state is the file's digest, whether the schema is held and its stamp</b>: the fresh read composes them, the fingerprint holds them, and the port refuses the write
/// <code>INTEROP.HL7.IMPORTCHANGED</code> unless the file and the schema read the same at the write.</p>
/// <p><b>It is destructive</b>: an import replaces the schema without asking, which cannot be undone from OcuPilot. It declares <code>%Ens_EDISchema:WRITE</code> and WRITE on the namespace's
/// globals database (AD-8), PathPort's pairs when it names a server file, and performs the classic HL7 Schema Structures page's Import (AD-44).</p>
Class OcuPilot.Screen.Tool.InteropHl7SchemaImport Extends OcuPilot.Screen.Tool.InteropLookupTableImport
{

Parameter TOOLNAME = "interop.hl7schemas.import";

Parameter DESCRIPTION = "Propose importing one custom HL7 schema from an export file on the server, which replaces the schema of that name in the namespace, or creates it, with the file's; anything the file does not define is removed, and that cannot be undone. Name the schema the file holds in `Name`, exactly as the HL7 schemas list reports it in its Name column. Name the file by `root`, an allowed directory exactly as the Allowed directories screen lists it, and `path`, a relative file name under it. The file must hold exactly one HL7 schema and nothing else, in the form the Export action writes: a file with a class, two schemas or a standard schema is refused, and so is a standard schema of the namespace. If the file or the schema changes before the proposal is confirmed, nothing is imported.";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropHl7SchemaList";

/// <p>The fresh read: the file's schema, composed from the file and the schema as it stands.</p>
Parameter READTYPE = "HL7IMPORTFILE";

Parameter READANSWERS = "Category,Digest,Present,Modified,Namespace,root,path,fileName,content";

Parameter WRITERESOURCE = "%Ens_EDISchema";

Parameter WRITETYPE = "IMPORTHL7SCHEMA";

/// <p>The file and the schema the user reviewed, and the namespace. A local file's <code>content</code> is in it so the screen's write carries the text it read; it is empty in an agent's
/// proposal, whose file is a server file.</p>
Parameter FINGERPRINTSUBJECT = "Namespace,root,path,fileName,content,Category,Digest,Present,Modified";

Parameter PRECONDITIONFIELD = "Digest";

Parameter PRECONDITIONCODES = "INTEROP.HL7.IMPORTSHAPE,INTEROP.HL7.TOOLARGE,INTEROP.HL7.IMPORTSTANDARD,INTEROP.HL7.CASE,INTEROP.HL7.SOURCECONTROL,INTEROP.NAMESPACE";

/// <p>The classic page whose Import this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "EnsPortal.HL7.SchemaMain";

Parameter CONSEQUENCECODE = "INTEROP.HL7.IMPORT";

/// <p>The reviewed values the write compares, as <code>&lt;field&gt;=&lt;query key&gt;</code>, comma-separated.</p>
Parameter REVIEWED = "Digest=digest,Present=present,Modified=modified";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTHL7SCHEMAS
}

/// <p>Every argument the port reads beyond the target: the server file, the local file and the reviewed values. They reach the port through <method>PortQuery</method>; only
/// <code>Name</code>, <code>root</code> and <code>path</code> are advertised.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListBuild(##class(OcuPilot.Port.InteropPort).#ROOTKEY, ##class(OcuPilot.Port.InteropPort).#PATHKEY, ##class(OcuPilot.Port.InteropPort).#FILENAMEKEY, ##class(OcuPilot.Port.InteropPort).#CONTENTKEY, "Digest", "Present", "Modified")
}

/// <p>The derived schema with the schema's name described: the schema the file holds.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", "The HL7 schema the file holds, named exactly as the HL7 schemas list reports it in its Name column, letter case included. A file that holds another schema is refused.", "string")
    }
    Quit tSchema
}

/// <p>The card's rows from the fresh read <var>pFresh</var>: <code>File</code> (the server file's relative name, or the local file's) and <code>Name</code> (the schema the file holds, and
/// the schema that stands now when there is one). A read that answered no schema is <var>pProblem</var>.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tSC = $$$OK
    Try {
        If '$IsObject(pFresh) || (pFresh.%GetTypeOf("Category") '= "string") || (pFresh.%Get("Category") = "") {
            Set pProblem = "this instance did not read the import file's schema, and a file whose schema is unknown is not one to import"
            Quit
        }
        Set tFile = $Select(pFresh.%Get("path") '= "": pFresh.%Get("path"), 1: pFresh.%Get("fileName"))
        Do ..PushRow(pRows, "File", "", tFile)
        Do ..PushRow(pRows, "Name", $Select(+pFresh.%Get("Present"): pFresh.%Get("Category"), 1: ""), pFresh.%Get("Category"))
    } Catch ex {
        Set pRows = []
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The schema's name, which the card titles it by: the fresh read's <code>Category</code>, else the agent's own <code>Name</code>.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Category") = "string") Quit pFresh.%Get("Category")
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("Name") = "string") Quit pArgs.%Get("Name")
    Quit ""
}

}
