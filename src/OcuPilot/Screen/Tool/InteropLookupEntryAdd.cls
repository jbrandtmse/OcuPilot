/// <p>Interoperability's lookup entry add (AD-3, AD-6, AD-54, AD-55, AD-62, Story 20.5): add one entry to a lookup table of the
/// request's namespace, creating the table when it is absent -- a table is made by adding its first entry. Two callers reach it:
/// the entries list's Add dialog and the tables list's New table dialog through
/// <class>OcuPilot.Area.Interop.LookupEntrySave</class>, and the agent's proposal and confirmation. The entry is in effect at once.</p>
/// <p><b>A create</b> (AD-54): its fresh read must find no entry of that key, and a key added since the mint reads present at the
/// confirm's re-read and closes the proposal target-changed. The vendor stores a table name that differs from another only in
/// letter case as a second table, and the classic page treats them as one, so the port refuses it by name
/// (<code>INTEROP.LOOKUP.TABLECASE</code>); a key that matches the credential pattern is refused <code>SECRET</code>.</p>
/// <p><b>Its payload</b> is the key and value the caller supplies and the namespace the add was composed in
/// (<method>ComposeCreate</method>); the table is the id's first part. The port has no body template to derive a field list
/// from, so the fields are declared here (<method>FieldRows</method>, AD-3) and its read-back compares the value
/// (<parameter>READBACKFIELDS</parameter>, AD-58).</p>
Class OcuPilot.Screen.Tool.InteropLookupEntryAdd Extends OcuPilot.Screen.Tool.InteropLookupEntryAction
{

Parameter TOOLNAME = "interop.lookupentries.add";

Parameter DESCRIPTION = "Propose adding one entry to a lookup table of the namespace the user is working in. A table that does not exist yet is created by its first entry. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the table as the Lookup tables list reports it (letter case matters), the new entry's key and its value; the value may be empty. Rules and transformations that call Lookup() see the entry on their next call. A key the table already holds, a table whose name differs from an existing one only in letter case, a key that holds a credential, a name or value over the vendor's limits and a namespace under source control are refused.";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter WRITETYPE = "ADDENTRY";

/// <p>The add sends a body: the composed payload (AD-4 has no subject for a create).</p>
Parameter SENDSBODY As BOOLEAN = 1;

/// <p>What the read-back compares, the field a create sends (AD-58).</p>
Parameter READBACKFIELDS = "Value";

/// <p>The read-back re-reads the created entry through the set's single-object read, because the add's own read asks for the add
/// and answers a held key as <code>TAKEN</code> (AD-58).</p>
Parameter READBACKTOOL = "OcuPilot.Screen.Tool.InteropLookupEntrySet";

Parameter PRECONDITIONCODES = "INTEROP.LOOKUP.TAKEN,INTEROP.LOOKUP.TABLECASE,INTEROP.LOOKUP.SECRET,INTEROP.LOOKUP.SOURCECONTROL,INTEROP.NAMESPACE";

/// <p>The fields an add may set, in the order the card lists them.</p>
Parameter FIELDS = "Key,Value";

/// <p>The two fields an add sets.</p>
ClassMethod SettableFields() As %List
{
    Quit $ListFromString(..#FIELDS)
}

/// <p>The two fields as the field rows the input schema is derived from: key and value strings (AD-3).</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 2
    Set pRows(1) = $ListBuild("Key", "string", 0)
    Set pRows(2) = $ListBuild("Value", "string", 0)
    Quit $$$OK
}

/// <p>The derived schema with the value described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf("Value") = "object" {
        Do tProperties.%Get("Value").%Set("description", "The entry's value, as text, at most 32,000 characters. Omit it or send an empty string for an empty value.", "string")
    }
    Quit tSchema
}

/// <p>What the schema says of the new entry's key.</p>
ClassMethod NameDescription() As %String
{
    Quit "The new entry's key: 1 to 255 characters with no control character. A key the table already holds is refused, so check its entries list first. A key that holds a credential is refused."
}

/// <p>The composed payload and diff of the create (AD-54): the key and value the caller supplied, as the kernel's
/// <method>OcuPilot.Kernel.Proposal.Mint.Compose</method> composes them, and the namespace the request is scoped to, which the port
/// query and the prohibited set read. The namespace adds no diff row.</p>
ClassMethod ComposeCreate(pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") || '$IsObject(pPayload) Quit tSC
    Do pPayload.%Set(..#NAMESPACEFIELD, ##class(OcuPilot.Kernel.Scope).Current(), "string")
    Quit tSC
}

/// <p>The composite id of the entry the confirmed add <var>pWritten</var> created, or <code>""</code>.</p>
ClassMethod CreatedId(pWritten) As %String
{
    If '$IsObject(pWritten) || 'pWritten.%IsA("%Library.DynamicObject") Quit ""
    If (pWritten.%GetTypeOf("Table") '= "string") || (pWritten.%GetTypeOf("Key") '= "string") Quit ""
    Quit ##class(OcuPilot.Kernel.EntityId).JoinComposite($ListBuild(pWritten.%Get("Table"), pWritten.%Get("Key")))
}

/// <p>The rules over the caller's fields, as one sentence naming each field and its published sentence, or <code>""</code>
/// (AD-55): the key's <code>SECRET</code> rule, then <method>OcuPilot.Port.InteropPort.LookupViolations</method>. The screen's
/// Save and the mint apply them alike.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pIdValue, pArgs, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") Quit tSC
    Quit ..FieldProblem(pIdValue, pArgs, .pProblem)
}

/// <p>The add always asks its read for the add (<parameter>OcuPilot.Port.InteropPort.ACTIONKEY</parameter>): present is
/// <code>TAKEN</code> and absent is the 404 a create expects (AD-54), at the mint and at the confirm alike. The namespace is the
/// payload's, else the request's scope.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    Set pQuery(##class(OcuPilot.Port.InteropPort).#ACTIONKEY) = ..#WRITETYPE
    If '$IsObject(pPayload) Quit
    If (pPayload.%GetTypeOf(..#NAMESPACEFIELD) = "string") && (pPayload.%Get(..#NAMESPACEFIELD) '= "") {
        Set pQuery(##class(OcuPilot.Port.InteropPort).#NAMESPACEKEY) = pPayload.%Get(..#NAMESPACEFIELD)
    }
}

}
