/// <p>The Secrets list's edit tool (AD-4, AD-6, AD-10, AD-55): propose a change to one key-value
/// secret's uses, TLS requirement or allowed hosts, and optionally a new value. It reads the secret
/// fresh through <class>OcuPilot.Port.WalletPort</class> (AD-27, AD-52), merges the arguments over
/// that read, and mints a proposal the user confirms. It writes nothing.</p>
/// <p><b>A merge write</b>: the body is the fresh read -- <code>{Type, Usage, RequireTLS,
/// AllowedHosts}</code> -- with the changed fields applied, so a field the arguments omit keeps the
/// instance's value (AD-4). The fingerprint covers every field the body sends, <code>Type</code>
/// included; the stored value is never read, so a change to it since the mint is not detected
/// (AD-27). Only a <code>%Wallet.KeyValue</code> secret is changed: any other type is refused before
/// anything is stored.</p>
/// <p><b>A new value is optional and secret</b> (AD-3, AD-6, AD-35). The card offers one masked
/// <code>Secret</code> row, marked optional (<method>StateDiff</method>); left empty, the body
/// carries no value and the vendor keeps the stored one. The model never sends it.</p>
Class OcuPilot.Screen.Tool.WalletSecretUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.secrets.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.WalletSecretList";

Parameter DESCRIPTION = "Propose a change to one key-value secret on this instance: its uses, whether it requires TLS, its allowed hosts, or any of them. It changes nothing by itself: it answers a proposal the user reviews and confirms, and the user may type a new value on the card at that point -- never send it. Name the secret exactly as the collection's Secrets list reports it, and send only the settings to change.";

/// <p>The fresh read and the write: the port's completed read, and the vendor's <code>PUT</code>.</p>
Parameter READTYPE = "GET";

Parameter WRITETYPE = "PUT";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The port the read and the write go through (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.WalletPort";

/// <p>The derived top-level fields this tool admits, comma-separated
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> names these,
/// <parameter>HOSTSARGUMENT</parameter> and <parameter>COMPOSEDSECRETS</parameter>). A test asserts the
/// two agree.</p>
Parameter PERMITTEDFIELDS = "Usage,RequireTLS";

Parameter HOSTSARGUMENT = "AllowedHosts";

/// <p>The secret the confirm may supply and the payload never carries, and the ones among them the
/// card may leave empty.</p>
Parameter COMPOSEDSECRETS = "Secret";

Parameter OPTIONALSECRETS = "Secret";

/// <p>The read's type key and the one type this tool changes.</p>
Parameter TYPEFIELD = "Type";

Parameter KEYVALUETYPE = "%Wallet.KeyValue";

Parameter WRITERESOURCE = "%Admin_Wallet";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Wallet.Secret"
}

/// <p>The field names the merge may set: the <code>ordinary</code> top-level fields this tool
/// admits, derived rather than transcribed (AD-3), <parameter>HOSTSARGUMENT</parameter>, and the
/// declared secret <parameter>COMPOSEDSECRETS</parameter>, which the mint refuses from the model and
/// the confirm supplies (AD-6);
/// <method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> names the same
/// four.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields() _ $ListBuild(..#HOSTSARGUMENT) _ ..ComposedSecrets()
}

/// <p><parameter>PERMITTEDFIELDS</parameter>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p><parameter>COMPOSEDSECRETS</parameter>.</p>
ClassMethod ComposedSecrets() As %List
{
    Quit $ListFromString(..#COMPOSEDSECRETS)
}

/// <p><parameter>OPTIONALSECRETS</parameter>: a new value is never required on an edit.</p>
ClassMethod OptionalSecrets() As %List
{
    Quit $ListFromString(..#OPTIONALSECRETS)
}

/// <p>The card's masked rows: one <code>{field, before, after}</code> per
/// <parameter>COMPOSEDSECRETS</parameter> name, both sides empty, carrying <code>optional: true</code>
/// where <parameter>OPTIONALSECRETS</parameter> names it. They carry no value; the confirm supplies
/// one or none. <var>pFresh</var> is not read, and <var>pProblem</var> is always empty.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    Set tNames = ..ComposedSecrets()
    Set tOptional = ..OptionalSecrets()
    For tI = 1:1:$ListLength(tNames) {
        Set tRow = {}
        Do tRow.%Set("field", $List(tNames, tI), "string")
        Do tRow.%Set("before", "", "string")
        Do tRow.%Set("after", "", "string")
        If $ListFind(tOptional, $List(tNames, tI)) Do tRow.%Set("optional", 1, "boolean")
        Do pRows.%Push(tRow)
    }
    Quit $$$OK
}

/// <p>Drop an empty <code>Secret</code> from <var>pPayload</var>: the card sends every masked field,
/// an optional one left empty as <code>""</code>, and an edit adds a value only when one was entered,
/// as the screen's Save does. The vendor keeps the stored value either way; this keeps the two
/// callers' bodies one body.</p>
ClassMethod DerivedFields(pPayload As %DynamicObject)
{
    If '$IsObject(pPayload) Quit
    For tI = 1:1:$ListLength(..ComposedSecrets()) {
        Set tName = $List(..ComposedSecrets(), tI)
        If (pPayload.%GetTypeOf(tName) = "string") && (pPayload.%Get(tName) = "") Do pPayload.%Remove(tName)
    }
}

/// <p>The derived schema with the allowed hosts added and the name and settings described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    Quit ##class(OcuPilot.Screen.Tool.WalletSecretCreate).Described(tSchema, 0)
}

/// <p>A secret that is not <parameter>KEYVALUETYPE</parameter>, read fresh through this tool's own
/// port, is refused; otherwise the form's own field rules over the agent's arguments, the name's
/// rules skipped (AD-55). A read that fails is an error status, never a pass.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Kill tQuery
    Set tQuery(..IdParam()) = pIdValue
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..ReadType(), .tQuery, "", .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) Quit tSC
    If '$IsObject($Get(tFresh)) || (tFresh.%Get(..#TYPEFIELD) '= ..#KEYVALUETYPE) {
        Set pProblem = "'" _ ..#TYPEFIELD _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation(##class(OcuPilot.Api.Error).#WALLETTYPEUNSUPPORTED)
        Quit $$$OK
    }
    Quit ##class(OcuPilot.Screen.Tool.WalletSecretCreate).RuleProblem(pIdValue, pArgs, 0, .pProblem)
}

/// <p>What the caller must hold: the screen's own pairs together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, each pair once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

}
