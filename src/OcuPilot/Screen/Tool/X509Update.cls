/// <p>The X.509 credentials list's edit tool (AD-4, AD-6, AD-10, AD-55): propose a change to one
/// credential's authorized users or intended peers. It reads the credential fresh through the
/// vendor's own <code>Security.X509Credential</code> <code>GET</code>, merges the arguments over that
/// object, and mints a proposal the user confirms. It writes nothing.</p>
/// <p><b>A merge write</b>: the body is the fresh read -- <code>{OwnerList, CAFile, PeerNames}</code>,
/// the vendor's whole <code>PUT</code> contract -- with the changed fields applied, so a field the
/// arguments omit keeps the instance's value and <code>CAFile</code> is always the instance's own
/// (AD-4, AD-21). The fingerprint covers every field the body sends. The certificate, key and
/// password are never part of an edit: they travel only in an import.</p>
Class OcuPilot.Screen.Tool.X509Update Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.x509.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.X509CredentialList";

Parameter DESCRIPTION = "Propose a change to one X.509 credential on this instance: the users authorized to use it, its intended peers, or both. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the credential by its alias exactly as the X.509 credentials list reports it, and send only the lists to change. Its certificate and key cannot be changed here.";

/// <p>The fresh read and the write: the vendor's single-object read, and its <code>PUT</code>, which
/// changes a present credential and answers 404 for an absent one.</p>
Parameter READTYPE = "GET";

Parameter WRITETYPE = "PUT";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The derived top-level fields this tool admits, comma-separated
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> names the same two).
/// A test asserts the two agree.</p>
Parameter PERMITTEDFIELDS = "OwnerList,PeerNames";

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

/// <p>The field names the merge may set: the <code>ordinary</code> top-level fields this tool
/// admits, derived rather than transcribed (AD-3).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p><parameter>PERMITTEDFIELDS</parameter>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>None: an edit carries no certificate, key or password, so the confirm channel admits no
/// secret for it (AD-6); they travel only in an import.</p>
ClassMethod SecretArguments(pDescriptor As %String = "", Output pDeclared As %Boolean) As %List
{
    Set pDeclared = 1
    Quit ""
}

/// <p>The derived schema with the alias and the two lists described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    Quit ##class(OcuPilot.Screen.Tool.X509Import).Described(tSchema, 0)
}

/// <p>The form's own field rules over the agent's arguments, the alias rules skipped (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ##class(OcuPilot.Screen.Tool.X509Import).RuleProblem(pIdValue, pArgs, 0, .pProblem)
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
