/// <p>What Interoperability's three lookup entry writes share (AD-6, AD-35, AD-51, AD-52, AD-53, AD-62, Story 20.5): a write of
/// one entry of one lookup table of the request's namespace through <class>OcuPilot.Port.InteropPort</class>, reached by two
/// callers -- the entries list's Add and its row actions Set value and Remove, and the agent's proposal and confirmation. A
/// write takes effect at once: the vendor's <code>Lookup()</code> reads the table with no cache, so the next call of a rule or a
/// transformation sees it. The target is the composite <code>[Table, Key]</code>
/// (<class>OcuPilot.Screen.Tool.InteropLookupEntryMint</class>).</p>
/// <p><b>A key that matches the credential pattern is never shown and never set</b>: the port answers its value empty and
/// <code>Secret</code> true, and refuses an add or a set of it <code>INTEROP.LOOKUP.SECRET</code> before any vendor call, from
/// either caller. A value the agent sent for such a key is redacted from its ledger row and its step by
/// <method>CallSecretNames</method>, because the refusal alone would leave it in a row the dispatcher records.</p>
/// <p><b>It declares</b> <code>%Ens_LookupTables:WRITE</code> and WRITE on the namespace's globals database beyond the screen's
/// pairs (AD-8, AD-62), each refused by name before any port call. The vendor checks no privilege of its own (measured).
/// The write runs on the classic <code>EnsPortal.LookupSettings</code> page's own operation, whose resource the screen's
/// pairs already name (AD-44), so no tool declares <code>CLASSICPAGES</code>.</p>
Class OcuPilot.Screen.Tool.InteropLookupEntryAction Extends OcuPilot.Screen.Tool.InteropAction [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.InteropLookupEntryList";

/// <p>The fresh read: one entry, composed for the action.</p>
Parameter READTYPE = "LOOKUPENTRY";

/// <p>What <parameter>READTYPE</parameter> answers.</p>
Parameter READANSWERS = "Table,Key,Value,Secret,Namespace";

Parameter WRITERESOURCE = "%Ens_LookupTables";

/// <p>The entry read the confirm's stored payload carries and a call's arguments do not.</p>
Parameter STATEMARKER = "Secret";

/// <p>The argument naming the table the entry belongs to.</p>
Parameter TABLEARGUMENT = "Table";

/// <p>The refusal code of an add or a set of an entry whose key holds a credential.</p>
Parameter SECRETCODE = "INTEROP.LOOKUP.SECRET";

/// <p>Whether the key's secret rule is asked of this write's call: an add and a set, not a remove.</p>
Parameter REFUSESSECRET As BOOLEAN = 1;

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.InteropPort).#ENDPOINTLOOKUPENTRIES
}

/// <p><class>OcuPilot.Screen.Tool.InteropLookupEntryMint</class>, which builds the composite id.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.InteropLookupEntryMint"
}

/// <p>The entry's key, which the screen's rows carry it under.</p>
ClassMethod IdArgument() As %String
{
    Quit "Key"
}

/// <p>The entry's key, which the card titles it by: the fresh read's <code>Key</code>, else the agent's own.</p>
ClassMethod TargetName(pFresh, pId As %String, pArgs) As %String
{
    If $IsObject(pFresh) && (pFresh.%GetTypeOf("Key") = "string") Quit pFresh.%Get("Key")
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("Key") = "string") Quit pArgs.%Get("Key")
    Quit ""
}

/// <p>What the schema says of the entry's key. The write the tool makes states it.</p>
ClassMethod NameDescription() As %String
{
    Quit "The entry's key, named exactly as the table's entries list reports it in its Key column. An entry the list does not report is refused."
}

/// <p>The derived schema with the table added and required, and the key described: the target is one entry of one table.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    Do tProperties.%Set(..#TABLEARGUMENT, {"type": "string", "description": "The lookup table the entry belongs to, named exactly as this namespace's Lookup tables list reports it in its Name column, letter case included."})
    If tSchema.%GetTypeOf("required") = "array" Do tSchema.%Get("required").%Push(..#TABLEARGUMENT)
    If tProperties.%GetTypeOf(..IdArgument()) = "object" {
        Do tProperties.%Get(..IdArgument()).%Set("description", ..NameDescription(), "string")
    }
    Quit tSchema
}

/// <p><code>Value</code> when the call <var>pInput</var> names an entry whose key matches the credential pattern
/// (<method>OcuPilot.Kernel.Audit.Log.IsCredentialName</method>), else none: its ledger row and step show the redaction mark in
/// place of whatever the agent sent for it (AD-3 layer 1, AD-41).</p>
ClassMethod CallSecretNames(pInput As %DynamicAbstractObject) As %List
{
    If '$IsObject(pInput) || 'pInput.%IsA("%Library.DynamicObject") Quit ""
    If pInput.%GetTypeOf("Key") '= "string" Quit ""
    If ##class(OcuPilot.Kernel.Audit.Log).IsCredentialName(pInput.%Get("Key")) Quit $ListBuild("Value")
    Quit ""
}

/// <p>The key inside the composite id <var>pIdValue</var>, <code>""</code> for any other spelling.</p>
ClassMethod KeyOf(pIdValue As %String) As %String [ Private ]
{
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pIdValue)
    If $ListLength(tParts) '= 2 Quit ""
    Quit $List(tParts, 2)
}

/// <p>The refusal of a key that matches the credential pattern, as its published sentence, else <code>""</code>: the rule the
/// port applies, asked again here so the mint and the confirm refuse by it too.</p>
ClassMethod SecretProblem(pIdValue As %String) As %String
{
    Set tKey = ..KeyOf(pIdValue)
    If (tKey '= "") && ##class(OcuPilot.Kernel.Audit.Log).IsCredentialName(tKey) Quit $ClassMethod(..#PORTCLASS, "ReasonFor", ..#SECRETCODE)
    Quit ""
}

/// <p>The rule over the call: <code>SECRET</code> on the key, for the writes that carry a value
/// (<parameter>REFUSESSECRET</parameter>).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    If ..#REFUSESSECRET Set pProblem = ..SecretProblem(pIdValue)
    Quit $$$OK
}

/// <p>The same rules again at the write, so a confirm is refused what the mint would now refuse before the claim, leaving the
/// proposal live (AD-6, AD-40).</p>
ClassMethod ConfirmProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ..ArgumentProblem(pIdValue, pArgs, .pProblem)
}

/// <p>The rules over the call's fields, as one sentence naming each field and its published sentence, appended to
/// <var>pProblem</var>: <method>OcuPilot.Port.InteropPort.LookupViolations</method> over the id's table and key and the
/// arguments' <code>Value</code> (an absent one is empty).</p>
ClassMethod FieldProblem(pIdValue As %String, pArgs As %DynamicObject, ByRef pProblem As %String) As %Status [ Private ]
{
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pIdValue)
    If $ListLength(tParts) '= 2 Quit $$$OK
    Set tValue = ""
    If $IsObject(pArgs) && (pArgs.%GetTypeOf("Value") = "string") Set tValue = pArgs.%Get("Value")
    Set tSC = $ClassMethod(..#PORTCLASS, "LookupViolations", $List(tParts, 1), $List(tParts, 2), tValue, .tViolations)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tViolations) {
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ $List(tViolations(tI), 1) _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
    }
    Quit $$$OK
}

}
