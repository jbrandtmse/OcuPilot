/// <p>Interoperability's HL7 schema add (AD-3, AD-6, AD-54, AD-55, AD-62, Story 24.18 Batch 1): add one custom HL7 schema to the request's namespace, with an optional base schema and
/// description. Two callers reach it: the HL7 schemas list's New HL7 schema dialog through <class>OcuPilot.Area.Interop.Hl7SchemaSave</class>, and the agent's proposal and confirmation. The
/// schema is stored at once, with no message types of its own; it adds its own to the schema it is based on.</p>
/// <p><b>A create</b> (AD-54): its fresh read must find no schema of that name in any letter case, so a name added since the mint reads present at the confirm's re-read and closes the
/// proposal target-changed. A namespace under source control refuses it, and so does a base the namespace does not hold or a description over 2,000 characters.</p>
/// <p><b>Its payload</b> is the name and the fields the caller supplies and the namespace the add was composed in (<method>ComposeCreate</method>); its read-back compares the base and the
/// description (<parameter>READBACKFIELDS</parameter>, AD-58).</p>
Class OcuPilot.Screen.Tool.InteropHl7SchemaAdd Extends OcuPilot.Screen.Tool.InteropHl7SchemaAction
{

Parameter TOOLNAME = "interop.hl7schemas.add";

Parameter DESCRIPTION = "Propose adding one custom HL7 schema to the namespace the user is working in. A custom HL7 schema adds its own message types, structures and code tables to the schema it is based on; a new one has none of its own until some are added. It changes nothing by itself: it answers a proposal the user reviews and confirms. Give the schema's name, 1 to 64 letters, digits, periods, underscores and hyphens beginning with a letter or digit, which cannot be changed afterwards; optionally a base schema exactly as the HL7 schemas list reports it in its Name column, such as 2.5.1; and optionally a description of at most 2,000 characters. A name the namespace already holds in any letter case, a base the namespace does not hold and a namespace under source control are refused.";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter WRITETYPE = "ADDHL7SCHEMA";

/// <p>The add sends a body: the composed payload (AD-4 has no subject for a create).</p>
Parameter SENDSBODY As BOOLEAN = 1;

/// <p>What the read-back compares, the fields a create sends that a read answers (AD-58).</p>
Parameter READBACKFIELDS = "Base,Description";

/// <p>The read-back re-reads the created schema through the export's single-object read, because the add's own read asks for the add and answers a held name as <code>TAKEN</code> (AD-58).</p>
Parameter READBACKTOOL = "OcuPilot.Screen.Tool.InteropHl7SchemaExport";

Parameter PRECONDITIONCODES = "INTEROP.HL7.TAKEN,INTEROP.HL7.SOURCECONTROL,INTEROP.NAMESPACE";

/// <p>The classic page whose own resource an operator may have assigned beyond the screen's, and the dialog whose operation the add performs (AD-8, AD-44).</p>
Parameter CLASSICPAGES = "EnsPortal.HL7.SchemaMain,EnsPortal.HL7.Dialog.CustomSchema";

/// <p>The fields an add may set, in the order the card lists them.</p>
Parameter FIELDS = "Name,Base,Description";

/// <p>An add judges the name it is given.</p>
Parameter JUDGESNAME As BOOLEAN = 1;

/// <p>The name and the two fields an add sets.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

/// <p>The three fields as the field rows the input schema is derived from (AD-3).</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 0
    Set pRows($Increment(pRows)) = $ListBuild("Name", "string", 0)
    Set pRows($Increment(pRows)) = $ListBuild("Base", "string", 0)
    Set pRows($Increment(pRows)) = $ListBuild("Description", "string", 0)
    Quit $$$OK
}

/// <p>What the schema says of the new schema's name.</p>
ClassMethod NameDescription() As %String
{
    Quit "The new HL7 schema's name: 1 to 64 letters, digits, periods, underscores and hyphens, beginning with a letter or digit. It cannot be changed afterwards. A name the namespace already holds, in any letter case, is refused, so check the HL7 schemas list first."
}

/// <p>The derived schema with the base and the description described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf("Base") = "object" Do tProperties.%Get("Base").%Set("description", "The schema this one is based on, named exactly as the HL7 schemas list reports it in its Name column, such as 2.5.1. Omit it for none. A base the namespace does not hold is refused.", "string")
    If tProperties.%GetTypeOf("Description") = "object" Do tProperties.%Get("Description").%Set("description", "The schema's description, as text, at most 2,000 characters.", "string")
    Quit tSchema
}

/// <p>The rules over the name and the fields, as one sentence naming each field and its published sentence, or <code>""</code> (AD-55): the port's
/// <method>OcuPilot.Port.InteropPort.Hl7SchemaViolations</method>, which also judges the base held in the namespace the arguments carry or the request is scoped to.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = $ClassMethod(..#PORTCLASS, ..#VIOLATIONSMETHOD, pIdValue, pArgs, .tViolations, ..#JUDGESNAME, ..ArgumentNamespace(pArgs))
    If $$$ISERR(tSC) Quit tSC
    Set pProblem = ..ViolationsProblem(.tViolations)
    Quit $$$OK
}

/// <p>The composed payload and diff of the create (AD-54): the name and the fields the caller supplied, as the kernel's <method>OcuPilot.Kernel.Proposal.Mint.Compose</method> composes them,
/// and the namespace the request is scoped to, which the port query and the prohibited set read. The namespace adds no diff row.</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") || '$IsObject(pPayload) Quit tSC
    Do pPayload.%Set(..#NAMESPACEFIELD, ##class(OcuPilot.Kernel.Scope).Current(), "string")
    Quit tSC
}

/// <p>The name of the schema the confirmed add <var>pWritten</var> created, or <code>""</code>: the id its read-back re-reads it by.</p>
ClassMethod CreatedId(pWritten) As %String
{
    If '$IsObject(pWritten) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    If pWritten.%GetTypeOf("Category") '= "string" Quit ""
    Quit pWritten.%Get("Category")
}

/// <p>The add always asks its read for the add (<method>OcuPilot.Screen.Tool.InteropWorkflowAction.PortQuery</method>): a name held in any letter case is <code>TAKEN</code> and absent is the
/// 404 a create expects (AD-54), at the mint and at the confirm alike.</p>
Parameter READASKSACTION As BOOLEAN = 1;

}
