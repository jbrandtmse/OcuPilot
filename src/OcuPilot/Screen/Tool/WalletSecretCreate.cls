/// <p>The Secrets list's create tool (AD-54, AD-55): propose storing one key-value secret in a wallet
/// collection. It reads the intended name fresh through <class>OcuPilot.Port.WalletPort</class>
/// (AD-27, AD-52), requires that read to answer <b>nothing</b>, composes the payload from its
/// arguments and mints a proposal the user confirms. It writes nothing.</p>
/// <p><b>The value is a secret end to end</b> (AD-3, AD-6, AD-35). It is the endpoint's
/// <code>Secret</code>, declared in <class>OcuPilot.Screen.Descriptor.WalletSecretList</class>'s
/// <code>secretArguments</code>, so it is absent from this schema, refused from the model at the
/// mint, never stored, and supplied only at confirm on the card beside the masked row
/// <method>ComposedSecrets</method> names, where it is required.</p>
/// <p><b>The body is the vendor's wrapper</b> <code>{Type, WalletSecretConfig}</code>, composed by
/// the port (<parameter>OcuPilot.Port.AdminPort.WRAPPEDTYPES</parameter>): this tool's payload is
/// flat, and <method>DerivedFields</method> adds <code>Type</code>, always
/// <parameter>KEYVALUETYPE</parameter>. The vendor's <code>PUT</code> is an upsert, so the absence
/// fingerprint is what stops a confirmed create rewriting a secret stored since the mint.</p>
Class OcuPilot.Screen.Tool.WalletSecretCreate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.secrets.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.WalletSecretList";

Parameter DESCRIPTION = "Propose storing a new key-value secret in an existing wallet collection on this instance. It stores nothing by itself: it answers a proposal the user reviews and confirms, and the user types the value on the card at that point -- never send it. Name the secret, and optionally its uses, whether it requires TLS and the hosts it may be sent to.";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

/// <p>The fresh read and the write: the port's completed read, and the vendor's <code>PUT</code>,
/// which creates an absent secret and modifies a present one.</p>
Parameter READTYPE = "GET";

Parameter WRITETYPE = "PUT";

/// <p>The port the read and the write go through (AD-52): the admin port with the vendor's missing
/// <code>GET</code> completed (AD-27).</p>
Parameter PORTCLASS = "OcuPilot.Port.WalletPort";

/// <p>The derived top-level fields this tool admits, comma-separated
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedCreateFields</method> names these,
/// <parameter>HOSTSARGUMENT</parameter> and <parameter>COMPOSEDSECRETS</parameter>). A test asserts the
/// two agree.</p>
Parameter PERMITTEDFIELDS = "Usage,RequireTLS";

/// <p>The one list argument: the hosts the secret may be sent to. The field list derives it as a
/// member-less array, which the schema's flat rows do not admit, so the tool adds it.</p>
Parameter HOSTSARGUMENT = "AllowedHosts";

/// <p>The secret the confirm supplies and the payload never carries.</p>
Parameter COMPOSEDSECRETS = "Secret";

/// <p>The body's type key and the one type this tool writes.</p>
Parameter TYPEFIELD = "Type";

Parameter KEYVALUETYPE = "%Wallet.KeyValue";

/// <p>The pair a write requires: <code>%Admin_Wallet:USE</code>, the vendor endpoint's own
/// <code>ResourcesOR()</code> resource and the pair the list already declares (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_Wallet";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Wallet.Secret"
}

/// <p>The field names the composed payload may set: the <code>ordinary</code> top-level fields this
/// tool admits, derived rather than transcribed (AD-3), <parameter>HOSTSARGUMENT</parameter>, and
/// <parameter>COMPOSEDSECRETS</parameter>, the one template field among the declared secrets. The
/// schema never offers it and the mint refuses it from the model's arguments before anything is
/// composed, so it reaches a body only from the confirm's card or the screen's Save (AD-6, AD-35);
/// <method>OcuPilot.Kernel.Proposal.Prohibited.PermittedCreateFields</method> names the same
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

/// <p>The declared secret the body carries and the payload does not, for the mint's masked diff row
/// (AD-6): <parameter>COMPOSEDSECRETS</parameter>.</p>
ClassMethod ComposedSecrets() As %List
{
    Quit $ListFromString(..#COMPOSEDSECRETS)
}

/// <p>Set <parameter>TYPEFIELD</parameter> to <parameter>KEYVALUETYPE</parameter> on
/// <var>pPayload</var>: the only type this tool creates, which no caller sets.</p>
ClassMethod DerivedFields(pPayload As %DynamicObject)
{
    If '$IsObject(pPayload) Quit
    Do pPayload.%Set(..#TYPEFIELD, ..#KEYVALUETYPE, "string")
}

/// <p>The derived schema with <parameter>HOSTSARGUMENT</parameter> added as an array of strings and
/// the name and settings described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    Quit ..Described(tSchema, 1)
}

/// <p><var>pSchema</var> with <parameter>HOSTSARGUMENT</parameter> added and the name, the uses and
/// the TLS flag described, for a create when <var>pCreates</var> is 1 and for an edit otherwise.</p>
ClassMethod Described(pSchema As %DynamicObject, pCreates As %Boolean) As %DynamicObject
{
    If '$IsObject(pSchema) Quit pSchema
    If pSchema.%GetTypeOf("properties") '= "object" Quit pSchema
    Set tProperties = pSchema.%Get("properties")
    If tProperties.%GetTypeOf("Name") = "object" {
        If pCreates {
            Do tProperties.%Get("Name").%Set("description", "The full name the new secret will take: an existing collection's name, a dot, and the secret's own name of letters, digits, dots, hyphens and underscores, at most 128 characters in all and compared exactly, case included. A name the collection already holds is refused, so check the collection's Secrets list first.", "string")
        } Else {
            Do tProperties.%Get("Name").%Set("description", "The secret to change, exactly as the collection's Secrets list reports its name, case included. Only a key-value secret can be changed.", "string")
        }
    }
    If tProperties.%GetTypeOf("Usage") = "object" {
        Do tProperties.%Get("Usage").%Set("description", "What the secret may be used for, as a whole number from 0 to 15: add HTTP 1, SQL gateway 2, SOAP 4 and Custom 8. The instance's own default is all four.", "string")
    }
    If tProperties.%GetTypeOf("RequireTLS") = "object" {
        Do tProperties.%Get("RequireTLS").%Set("description", "Whether the secret may only be sent over TLS. The instance's own default is true.", "string")
    }
    Set tHosts = {"type": "array", "description": "The hosts the secret may be sent to when it requires TLS, each a host name or address with no space or comma, replacing the whole list. An empty list sends it to any host."}
    Do tHosts.%Set("items", {"type": "string"})
    Do tProperties.%Set(..#HOSTSARGUMENT, tHosts)
    Quit pSchema
}

/// <p>The form's own rules over the agent's arguments
/// (<method>OcuPilot.Area.Security.WalletRules.Validate</method>), each broken rule as its field and
/// published sentence (AD-55). The name look-up is skipped, because the mint's absence read answers
/// it, and so is the value, which is supplied at confirm.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ..RuleProblem(pIdValue, pArgs, 1, .pProblem)
}

/// <p><method>OcuPilot.Area.Security.WalletRules.Validate</method> over <var>pArgs</var> for
/// <var>pIdValue</var>, the name's own rules applied only with <var>pCheckName</var>, the look-up and
/// the value's requirement never, as one <var>pProblem</var> naming each field and its published
/// sentence.</p>
ClassMethod RuleProblem(pIdValue As %String, pArgs As %DynamicObject, pCheckName As %Boolean, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = ##class(OcuPilot.Area.Security.WalletRules).Validate(pIdValue, pArgs, .tViolations, pCheckName, 0, 0)
    If $$$ISERR(tSC) Quit tSC
    For tI = 1:1:$Get(tViolations) {
        Set tField = $List(tViolations(tI), 1)
        Set tReason = ##class(OcuPilot.Api.Error).ReasonForViolation($List(tViolations(tI), 2))
        Set pProblem = pProblem _ $Select(pProblem = "": "", 1: " ") _ "'" _ tField _ "': " _ tReason
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
