/// <p>The base of the two wallet key create tools (AD-54, AD-55, Story 18.24): propose generating a new
/// RSA key pair or symmetric key as a secret in an existing wallet collection. The tool reads the intended
/// name fresh through <class>OcuPilot.Port.WalletPort</class> (AD-27, AD-52), requires that read to answer
/// <b>nothing</b>, composes the payload from its one argument, <code>Length</code>, and mints a proposal the
/// user confirms. It writes nothing.</p>
/// <p><b>The agent generates and never imports</b> (AD-53, Story 18.24's second decision): the length is
/// required, and no key material is ever the model's. Every material member is a declared secret of
/// <class>OcuPilot.Screen.Descriptor.WalletSecretList</class> and a <code>secret</code> row of this tool's
/// field list, so the mint refuses one from the model (AD-6), the schema omits it, and a confirm that
/// carries one is refused by the port (<code>WALLETKEY.SOURCE.BOTH</code>) with nothing sent. None is
/// <method>ComposedSecrets</method>, so the card shows no key row.</p>
/// <p><b>The body is the vendor's wrapper</b> <code>{Type, WalletSecretConfig}</code>, composed by the
/// port; this tool's payload is flat, and <method>DerivedFields</method> adds the type. The vendor's
/// <code>PUT</code> is an upsert, so the absence fingerprint is what stops a confirmed create rewriting a
/// secret stored since the mint.</p>
/// <p>A concrete tool declares <parameter>TOOLNAME</parameter>, <parameter>DESCRIPTION</parameter>,
/// <parameter>SECRETTYPE</parameter> and <parameter>LENGTHS</parameter>.</p>
Class OcuPilot.Screen.Tool.WalletKeyCreate Extends OcuPilot.Screen.Tool.Write [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.WalletSecretList";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter READTYPE = "GET";

Parameter WRITETYPE = "PUT";

/// <p>The port the read and the write go through (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.WalletPort";

/// <p>The one derived top-level field this tool admits.</p>
Parameter PERMITTEDFIELDS = "Length";

/// <p>The secret type this tool creates, which the prohibited set reads, and the lengths it generates
/// (bits for RSA, bytes for symmetric).</p>
Parameter SECRETTYPE;

Parameter LENGTHS;

/// <p>The body's type key.</p>
Parameter TYPEFIELD = "Type";

/// <p>The pair a write requires beyond the screen's own (AD-8): <code>%Admin_Wallet:USE</code>.</p>
Parameter WRITERESOURCE = "%Admin_Wallet";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Wallet.Secret"
}

/// <p>The field names the composed payload may set: the derived <code>Length</code>.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p><parameter>PERMITTEDFIELDS</parameter>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>None: the card shows no key row.</p>
ClassMethod ComposedSecrets() As %List
{
    Quit ""
}

/// <p>Set <parameter>TYPEFIELD</parameter> to <parameter>SECRETTYPE</parameter> on <var>pPayload</var>:
/// the only type this tool creates, which no caller sets.</p>
ClassMethod DerivedFields(pPayload As %DynamicObject)
{
    If '$IsObject(pPayload) Quit
    Do pPayload.%Set(..#TYPEFIELD, ..#SECRETTYPE, "string")
}

/// <p>The derived schema with <code>Length</code> required, closed to its set, and the name
/// described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    If '$IsObject(tSchema) || (tSchema.%GetTypeOf("properties") '= "object") Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf("Name") = "object" {
        Do tProperties.%Get("Name").%Set("description", "The full name the new secret will take: an existing collection's name, a dot, and the secret's own name of letters, digits, dots, hyphens and underscores, at most 128 characters in all and compared exactly, case included. A name the collection already holds is refused, so check the collection's Secrets list first.", "string")
    }
    Set tLength = {"type": "integer"}
    Set tEnum = []
    For tI = 1:1:$Length(..#LENGTHS, ",") Do tEnum.%Push(+$Piece(..#LENGTHS, ",", tI))
    Do tLength.%Set("enum", tEnum)
    Do tLength.%Set("description", ..LengthDescription(), "string")
    Do tProperties.%Set("Length", tLength)
    Do tSchema.%Get("required").%Push("Length")
    Quit tSchema
}

/// <p>The sentence that describes <code>Length</code> to the model, declared by the concrete tool.</p>
ClassMethod LengthDescription() As %String [ Abstract ]
{
    Quit ""
}

/// <p>The agent's arguments refused by the key rules in their <code>generate</code> mode: a length of
/// the type's closed set is required, and nothing else is a source (AD-55). The name look-up is the
/// mint's own absence read.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = ##class(OcuPilot.Area.Security.WalletKeyRules).Validate(..#SECRETTYPE, ##class(OcuPilot.Area.Security.WalletKeyRules).#MODEGENERATE, pArgs, .tViolations, 0)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tViolations) {
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ $List(tViolations(tI), 1) _ "': " _ ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
    }
    Quit $$$OK
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
