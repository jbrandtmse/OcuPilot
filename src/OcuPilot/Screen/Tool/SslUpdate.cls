/// <p>The SSL/TLS configurations list's change tool (AD-4, AD-6, AD-10, AD-55): propose a change to
/// one SSL/TLS configuration's settings, and optionally its private key password. It reads the
/// configuration fresh through the vendor's own <code>Security.SSLConfig</code> <code>GET</code>,
/// merges the arguments over that object, and mints a proposal the user confirms. It writes
/// nothing.</p>
/// <p><b>A merge write</b>: the body is the fresh read's twenty-one fields with the changed ones
/// applied, so a field the arguments omit keeps the instance's value (AD-4). The file locations are
/// sent back as the instance holds them and no caller changes them (AD-21).</p>
/// <p><b>The private key password is a declared secret</b> (AD-3, AD-6, AD-35). The vendor's read
/// never answers it. Where the configuration names a private key file, the card offers one masked,
/// optional row for it (<method>StateDiff</method>); left empty, the body carries none and the
/// vendor keeps the stored one. The model never sends it.</p>
/// <p><b>Turning peer verification off is permitted and marked</b>: the kernel names the effect
/// (<method>Consequence</method>) and the proposal is destructive (AD-10). On OcuPilot's own provider
/// configuration a change to its type, peer verification, trusted certificates or enablement is
/// refused here at the mint, with the published sentence, and at the write by the kernel.</p>
Class OcuPilot.Screen.Tool.SslUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.ssl.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.SslConfigList";

Parameter DESCRIPTION = "Propose a change to one SSL/TLS configuration on this instance: its description, whether it is enabled, its type, peer verification and trusted certificates, its TLS versions, ciphers and Diffie-Hellman key size, or its OCSP settings. It changes nothing by itself: it answers a proposal the user reviews and confirms, and the user may type a new private key password on the card at that point -- never send it. Name the configuration exactly as the SSL/TLS configurations list reports it, and send only the settings to change. File locations are set on the classic portal.";

/// <p>The fresh read and the write: the vendor's single-object read, and its <code>PUT</code>, sent
/// the complete property set (AD-4).</p>
Parameter READTYPE = "GET";

Parameter WRITETYPE = "PUT";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The derived top-level fields this tool admits, comma-separated
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> names these and
/// <parameter>COMPOSEDSECRETS</parameter>). A test asserts the two agree.</p>
Parameter PERMITTEDFIELDS = "Description,Enabled,Type,VerifyPeer,VerifyDepth,CAFile,TLSMinVersion,TLSMaxVersion,CipherList,Ciphersuites,DiffieHellmanBits,OCSP,OCSPTimeout";

/// <p>The secret the confirm may supply and the payload never carries, and the ones among them the
/// card may leave empty.</p>
Parameter COMPOSEDSECRETS = "PrivateKeyPassword";

Parameter OPTIONALSECRETS = "PrivateKeyPassword";

/// <p>The read's private key file, whose presence is what makes a password settable (vendor error
/// 985).</p>
Parameter KEYFILEFIELD = "PrivateKeyFile";

Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.SSLConfig"
}

/// <p>The field names the merge may set: the <code>ordinary</code> top-level fields this tool
/// admits, derived rather than transcribed (AD-3), and the declared secret
/// <parameter>COMPOSEDSECRETS</parameter>, which the mint refuses from the model and the confirm
/// supplies (AD-6).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields() _ ..ComposedSecrets()
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

/// <p><parameter>OPTIONALSECRETS</parameter>: a new password is never required.</p>
ClassMethod OptionalSecrets() As %List
{
    Quit $ListFromString(..#OPTIONALSECRETS)
}

/// <p>The card's masked rows: one <code>{field, before, after, optional}</code> per
/// <parameter>COMPOSEDSECRETS</parameter> name, both sides empty, when the fresh read
/// <var>pFresh</var> names a private key file, and none otherwise, since a password without one is
/// refused by the vendor. They carry no value; the confirm supplies one or none.
/// <var>pProblem</var> is always empty.</p>
ClassMethod StateDiff(pFresh As %DynamicObject, Output pRows As %DynamicArray, Output pProblem As %String) As %Status
{
    Set pRows = []
    Set pProblem = ""
    If '$IsObject(pFresh) || ($ZStrip(pFresh.%Get(..#KEYFILEFIELD), "<>W") = "") Quit $$$OK
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

/// <p>Drop an empty private key password from <var>pPayload</var>: the card sends every masked field,
/// an optional one left empty as <code>""</code>, and the vendor would clear the stored password for
/// an empty one. The screen's Save adds one only when one was entered, so the two callers send one
/// body.</p>
ClassMethod DerivedFields(pPayload As %DynamicObject)
{
    If '$IsObject(pPayload) Quit
    For tI = 1:1:$ListLength(..ComposedSecrets()) {
        Set tName = $List(..ComposedSecrets(), tI)
        If (pPayload.%GetTypeOf(tName) = "string") && (pPayload.%Get(tName) = "") Do pPayload.%Remove(tName)
    }
}

/// <p>The derived schema with the settings typed and described
/// (<method>OcuPilot.Screen.Tool.SslCreate.Described</method>).</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit ##class(OcuPilot.Screen.Tool.SslCreate).Described(##super(pDescriptor), 0)
}

/// <p>The editor's own rules over the fields the agent's arguments change, read against this tool's
/// own fresh read of <var>pIdValue</var> (<method>OcuPilot.Area.Security.SslRules.Validate</method>,
/// update mode), each broken rule as its field and published sentence (AD-55). Two refusals come
/// first: arguments that change nothing (AD-4: every merge tool refuses a no-op), and, on OcuPilot's
/// own provider configuration, a change to any of
/// <method>OcuPilot.Kernel.Proposal.Prohibited.OcuPilotSslFields</method>, refused with
/// <parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTSSLREASON</parameter>, the sentence the
/// kernel refuses the write with (AD-10, AD-53).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tRules = "OcuPilot.Area.Security.SslRules"
    Kill tQuery
    Set tQuery(..IdParam()) = pIdValue
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..ReadType(), .tQuery, "", .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) && (+$Get(tHttp) '= 404) Quit tSC
    If '$IsObject($Get(tFresh)) || 'tFresh.%IsA("%Library.DynamicObject") Set tFresh = ""
    Set tChanged = $ClassMethod(tRules, "Changed", pArgs, tFresh)
    If $IsObject(tFresh) && (tChanged.%Size() = 0) {
        Set pProblem = "nothing would change: every value named is the one the target already holds"
        Quit $$$OK
    }
    If pIdValue = ##class(OcuPilot.Kernel.State.Base).#SSLCONFIG {
        Set tOwn = ##class(OcuPilot.Kernel.Proposal.Prohibited).OcuPilotSslFields()
        For tI = 1:1:$ListLength(tOwn) {
            If tChanged.%GetTypeOf($List(tOwn, tI)) = "unassigned" Continue
            Set pProblem = "'" _ $List(tOwn, tI) _ "': " _ ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(##class(OcuPilot.Kernel.Proposal.Prohibited).#OCUPILOTSSL)
            Quit
        }
        If pProblem '= "" Quit $$$OK
    }
    Set tSC = $ClassMethod(tRules, "Validate", "update", pIdValue, tChanged, tFresh, .tViolations)
    If $$$ISERR(tSC) Quit tSC
    Set pProblem = $ClassMethod(tRules, "Problem", .tViolations)
    Quit $$$OK
}

/// <p>The kernel-owned consequence code this change's payload carries: <var>pEffect</var> when it is
/// <parameter>OcuPilot.Kernel.Proposal.Prohibited.EFFECTNOPEERCHECK</parameter> -- the change turns
/// peer verification off -- and <code>""</code> otherwise, which leaves the mint's own fallback.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    If pEffect = ##class(OcuPilot.Kernel.Proposal.Prohibited).#EFFECTNOPEERCHECK Quit pEffect
    Quit ""
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
