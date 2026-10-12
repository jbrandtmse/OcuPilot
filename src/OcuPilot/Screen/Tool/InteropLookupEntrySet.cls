/// <p>Interoperability's lookup entry set (AD-4, AD-6, AD-51, AD-53, AD-56, AD-62, Story 20.5): store a new value for one entry
/// of a lookup table. The value is in effect at once. An entry that already holds the value is refused
/// (<code>INTEROP.LOOKUP.SAME</code>), and so is a key that matches the credential pattern.</p>
/// <p>Two callers reach it: the entries list's row action Set value through <class>OcuPilot.Api.ScreenAction</class>, whose
/// dialog may send an empty value, and the agent's proposal and confirmation. It is a merge over the entry's fresh read, so its
/// card shows one <code>Value</code> row and its read-back compares the value (<parameter>READBACKFIELDS</parameter>). Its state,
/// pairs and refusals are <class>OcuPilot.Screen.Tool.InteropLookupEntryAction</class>'s.</p>
Class OcuPilot.Screen.Tool.InteropLookupEntrySet Extends OcuPilot.Screen.Tool.InteropLookupEntryAction
{

Parameter TOOLNAME = "interop.lookupentries.set";

Parameter DESCRIPTION = "Propose changing the value of one entry of a lookup table of the namespace the user is working in. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the table and the entry's key as the Lookup tables and entries lists report them, and give the new value as text; an empty string is a valid value. Rules and transformations that call Lookup() see the new value on their next call. An entry that already holds the value, a key that holds a credential, a value over 32,000 characters and a namespace under source control are refused.";

Parameter WRITETYPE = "SETENTRY";

/// <p>The set sends a body: the entry's row with the new value (AD-4).</p>
Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

Parameter SCREENACTIONS = "set";

/// <p>The dialog sends the value as this tool's one value, which may be empty (AD-56 (ii)).</p>
Parameter SCREENVALUES = "set=Value";

Parameter SCREENEMPTY = "set=Value";

/// <p>What the read-back compares (AD-58).</p>
Parameter READBACKFIELDS = "Value";

Parameter PRECONDITIONCODES = "INTEROP.LOOKUP.SECRET,INTEROP.LOOKUP.SOURCECONTROL,INTEROP.NAMESPACE";

/// <p>The one argument: the new value.</p>
Parameter ARGUMENT = "Value";

ClassMethod SettableFields() As %List
{
    Quit $ListBuild(..#ARGUMENT)
}

/// <p>The one field a set sends, a string (AD-3).</p>
ClassMethod FieldRows(Output pRows) As %Status
{
    Kill pRows
    Set pRows = 1
    Set pRows(1) = $ListBuild(..#ARGUMENT, "string", 0)
    Quit $$$OK
}

/// <p>The derived schema with the value described and required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf(..#ARGUMENT) = "object" {
        Do tProperties.%Get(..#ARGUMENT).%Set("description", "The new value, as text, at most 32,000 characters. An empty string is a valid value. Check the entry's current value on the entries list first.", "string")
    }
    If tSchema.%GetTypeOf("required") = "array" Do tSchema.%Get("required").%Push(..#ARGUMENT)
    Quit tSchema
}

/// <p>No state rows: a merge's card shows the value it moves (<method>OcuPilot.Kernel.Proposal.Mint.Merge</method>), and an
/// entry nobody established is refused by the fresh read.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Quit $$$OK
}

/// <p>The dialog's value as this tool's argument; the port judges it.</p>
ClassMethod ScreenActionDelta(pActionId As %String, pValues As %DynamicObject, pFresh As %DynamicObject, Output pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pArgs = {}
    Set pProblem = ""
    If $IsObject(pValues) && (pValues.%GetTypeOf(..#ARGUMENT) = "string") Do pArgs.%Set(..#ARGUMENT, pValues.%Get(..#ARGUMENT), "string")
    Quit $$$OK
}

/// <p>The rules over the call: <code>SECRET</code> on the key, then <method>OcuPilot.Port.InteropPort.LookupViolations</method>
/// over the value, as one sentence naming each field and its published sentence, or <code>""</code>.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pIdValue, pArgs, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") Quit tSC
    Quit ..FieldProblem(pIdValue, pArgs, .pProblem)
}

}
