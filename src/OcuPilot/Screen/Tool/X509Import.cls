/// <p>The X.509 credentials list's import tool (AD-54, AD-55): propose importing one X.509
/// credential. It reads the intended alias fresh through the vendor's own
/// <code>Security.X509Credential</code> <code>GET</code>, requires that read to answer
/// <b>nothing</b>, composes the payload from its arguments and mints a proposal the user confirms.
/// It writes nothing.</p>
/// <p><b>The certificate, the private key and its password are secrets end to end</b> (AD-3, AD-6,
/// AD-35). They are the create's authored fields (<class>OcuPilot.Screen.Tool.Classification</class>),
/// declared in <class>OcuPilot.Screen.Descriptor.X509CredentialList</class>'s
/// <code>secretArguments</code>, so they are absent from this schema, refused from the model at the
/// mint, never stored, and supplied only at confirm on the card beside the masked rows
/// <method>ComposedSecrets</method> names. The certificate is required there; the key and its
/// password are optional (<method>OptionalSecrets</method>).</p>
/// <p><b>The port completes the import from content</b>
/// (<parameter>OcuPilot.Port.AdminPort.CONTENTCOMPLETEDTYPES</parameter>, AD-27): the vendor's
/// <code>POST</code> names the certificate and key only as server file paths, which no caller may
/// name (AD-21). The alias travels as the <code>alias</code> query parameter; the body is the two
/// lists plus the secrets.</p>
Class OcuPilot.Screen.Tool.X509Import Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.x509.import";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.X509CredentialList";

Parameter DESCRIPTION = "Propose importing an X.509 credential into this instance under a new alias. It imports nothing by itself: it answers a proposal the user reviews and confirms, and the user pastes the certificate, and optionally its private key and the key's password, on the card at that point -- never send any of them. Name the alias, and optionally the users authorized to use the credential and its intended peers.";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

/// <p>The vendor request type an import is issued with: <code>Security.X509Credential</code>'s
/// <code>POST</code>, which refuses a taken alias with 409 and is not an upsert. Its
/// <code>PUT</code> opens the alias and answers 404 for an absent one, so it cannot create.</p>
Parameter WRITETYPE = "POST";

/// <p>The derived top-level fields this tool admits, comma-separated
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedCreateFields</method> names the same two).
/// A test asserts the two agree.</p>
Parameter PERMITTEDFIELDS = "OwnerList,PeerNames";

/// <p>The secrets the confirm supplies and the payload never carries, in the order the card asks
/// for them, and the ones among them the card may leave empty.</p>
Parameter COMPOSEDSECRETS = "Certificate,PrivateKey,PrivateKeyPassword";

Parameter OPTIONALSECRETS = "PrivateKey,PrivateKeyPassword";

/// <p>The one declared secret the endpoint's template also names.</p>
Parameter PASSWORDFIELD = "PrivateKeyPassword";

/// <p>The pair an import requires: <code>%Admin_Secure:USE</code>, the vendor endpoint's own
/// <code>ResourcesOR()</code> resource and the pair the list already declares (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.X509Credential"
}

/// <p>The input property that names the target: a credential is keyed by its alias.</p>
ClassMethod IdArgument() As %String
{
    Quit "Alias"
}

/// <p>The vendor's own query parameter for the alias.</p>
ClassMethod IdParam() As %String
{
    Quit "alias"
}

/// <p>The field names the composed payload may set: the <code>ordinary</code> top-level fields this
/// tool admits, derived rather than transcribed (AD-3), and <parameter>PASSWORDFIELD</parameter>,
/// the one template field among the declared secrets. The schema never offers it and the mint
/// refuses it from the model's arguments before anything is composed, so it reaches a body only
/// from the confirm's card or the screen's Save (AD-6, AD-35);
/// <method>OcuPilot.Kernel.Proposal.Prohibited.PermittedCreateFields</method> names the same
/// three.</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields() _ $ListBuild(..#PASSWORDFIELD)
}

/// <p><parameter>PERMITTEDFIELDS</parameter>, so a field the prohibited set has not reviewed for a
/// create is absent from the schema and from <method>SettableFields</method>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>The declared secrets an import's body carries and its payload does not, for the mint's masked
/// diff rows (AD-6): <parameter>COMPOSEDSECRETS</parameter>.</p>
ClassMethod ComposedSecrets() As %List
{
    Quit $ListFromString(..#COMPOSEDSECRETS)
}

/// <p>The composed secrets the card may leave empty, each an explicit per-row declaration:
/// <parameter>OPTIONALSECRETS</parameter>. A certificate is required; a credential may be imported
/// without a key.</p>
ClassMethod OptionalSecrets() As %List
{
    Quit $ListFromString(..#OPTIONALSECRETS)
}

/// <p>The derived schema with the alias and the two lists described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    Quit ..Described(tSchema, 1)
}

/// <p><var>pSchema</var> with the alias and the two lists described, for an import when
/// <var>pCreates</var> is 1 and for an edit otherwise.</p>
ClassMethod Described(pSchema As %DynamicObject, pCreates As %Boolean) As %DynamicObject
{
    If '$IsObject(pSchema) Quit pSchema
    If pSchema.%GetTypeOf("properties") '= "object" Quit pSchema
    Set tProperties = pSchema.%Get("properties")
    If tProperties.%GetTypeOf("Alias") = "object" {
        If pCreates {
            Do tProperties.%Get("Alias").%Set("description", "The alias the new credential will take, compared exactly, case included: at most 150 characters, with no control character and no slash. An alias this instance already holds is refused, so check the list first.", "string")
        } Else {
            Do tProperties.%Get("Alias").%Set("description", "The credential to change, exactly as this instance's own X.509 credentials list reports its alias, case included.", "string")
        }
    }
    If tProperties.%GetTypeOf("OwnerList") = "object" {
        Do tProperties.%Get("OwnerList").%Set("description", "The users allowed to use this credential, each a user name, replacing the whole list. An empty list lets every user use it.", "string")
    }
    If tProperties.%GetTypeOf("PeerNames") = "object" {
        Do tProperties.%Get("PeerNames").%Set("description", "The peers this credential is intended for, each a host name or address, replacing the whole list.", "string")
    }
    Quit pSchema
}

/// <p>The form's own alias rules over the agent's arguments
/// (<method>OcuPilot.Area.Security.X509Rules.Validate</method>), each broken rule as its field and
/// published sentence (AD-55). The look-up is skipped, because the mint's absence read answers it,
/// and so are the secret checks, because the secrets are supplied at confirm and the port checks
/// them there.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ..RuleProblem(pIdValue, pArgs, 1, .pProblem)
}

/// <p><method>OcuPilot.Area.Security.X509Rules.Validate</method> over <var>pArgs</var> for
/// <var>pIdValue</var>, the alias's own rules applied only with <var>pCheckAlias</var>, the look-up
/// and the secret checks never, as one <var>pProblem</var> naming each field and its published
/// sentence.</p>
ClassMethod RuleProblem(pIdValue As %String, pArgs As %DynamicObject, pCheckAlias As %Boolean, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = ##class(OcuPilot.Area.Security.X509Rules).Validate(pIdValue, pArgs, .tViolations, pCheckAlias, 0, 0)
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
