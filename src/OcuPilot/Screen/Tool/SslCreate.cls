/// <p>The SSL/TLS configurations list's create tool (AD-54, AD-55): propose creating one client
/// SSL/TLS configuration. It reads the intended name fresh through the vendor's own
/// <code>Security.SSLConfig</code> <code>GET</code>, requires that read to answer <b>nothing</b>,
/// composes the payload from its arguments and mints a proposal the user confirms. It writes
/// nothing.</p>
/// <p><b>The vendor's <code>PUT</code> is an upsert</b>, so the absence fingerprint is what stops a
/// confirmed create overwriting a configuration somebody made since the mint (AD-54). It composes
/// only the settings it was given; the vendor's own defaults fill the rest, and it requires the
/// type, the peer verification and whether the configuration is enabled, as the vendor does.</p>
/// <p><b>A create is always a client</b>: a server needs a certificate file and a private key file,
/// and no caller names a file (AD-21). It carries no private key password for the same reason.</p>
Class OcuPilot.Screen.Tool.SslCreate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.ssl.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.SslConfigList";

Parameter DESCRIPTION = "Propose creating a client SSL/TLS configuration on this instance, for outbound connections such as HTTPS. It creates nothing by itself: it answers a proposal the user reviews and confirms. Name it, and give its type (0, client), its peer verification and whether it is enabled; any other setting you omit takes the instance's own default. Trusted certificates are none or the operating system's store; file locations are set on the classic portal.";

/// <p>This tool creates its target (AD-54).</p>
Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

/// <p>The vendor request type a create is issued with: <code>Security.SSLConfig</code>'s
/// <code>PUT</code>, which creates an absent configuration and answers 201.</p>
Parameter WRITETYPE = "PUT";

/// <p>The derived top-level fields this tool admits, comma-separated
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedCreateFields</method> names the same
/// thirteen). A test asserts the two agree.</p>
Parameter PERMITTEDFIELDS = "Description,Enabled,Type,VerifyPeer,VerifyDepth,CAFile,TLSMinVersion,TLSMaxVersion,CipherList,Ciphersuites,DiffieHellmanBits,OCSP,OCSPTimeout";

/// <p>The fields the vendor requires of a new configuration.</p>
Parameter REQUIREDFIELDS = "Type,VerifyPeer,Enabled";

/// <p>The pair a create requires: <code>%Admin_Secure:USE</code>, the vendor endpoint's own
/// <code>ResourcesOR()</code> resource and one the list already declares (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.SSLConfig"
}

/// <p>The field names the composed payload may set: the <code>ordinary</code> top-level fields this
/// tool admits, derived rather than transcribed (AD-3).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p><parameter>PERMITTEDFIELDS</parameter>, so a field the prohibited set has not reviewed for a
/// create is absent from the schema and from <method>SettableFields</method>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p>None: a create names no private key file, so it carries no password and the confirm channel
/// admits no secret for it (AD-6).</p>
ClassMethod SecretArguments(pDescriptor As %String = "", Output pDeclared As %Boolean) As %List
{
    Set pDeclared = 1
    Quit ""
}

/// <p>The derived schema, typed and described (<method>Described</method>), with the three fields
/// the vendor requires of a new configuration required.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ..Described(##super(pDescriptor), 1)
    If '$IsObject(tSchema) Quit tSchema
    Set tProperties = tSchema.%Get("properties")
    For tI = 1:1:$Length(..#REQUIREDFIELDS, ",") {
        Set tField = $Piece(..#REQUIREDFIELDS, ",", tI)
        If $IsObject(tProperties) && (tProperties.%GetTypeOf(tField) = "object") Do tSchema.%Get("required").%Push(tField)
    }
    Quit tSchema
}

/// <p><var>pSchema</var> with each settable field's JSON type, its vocabulary and its description,
/// for a create when <var>pCreates</var> is 1 and for a change otherwise. The vendor's template shows
/// each number as a string placeholder, and its own read answers numbers, so the types are authored
/// here (AD-3's semantic half).</p>
ClassMethod Described(pSchema As %DynamicObject, pCreates As %Boolean) As %DynamicObject
{
    If '$IsObject(pSchema) Quit pSchema
    If pSchema.%GetTypeOf("properties") '= "object" Quit pSchema
    Set tProperties = pSchema.%Get("properties")
    If tProperties.%GetTypeOf("Name") = "object" {
        Do tProperties.%Get("Name").%Set("description", $Select(pCreates: "The name the new configuration will take, compared exactly, case included: 1 to 64 characters, with no control character, slash or backslash. A name this instance already holds is refused, so check the list first.", 1: "The configuration to change, exactly as this instance's own SSL/TLS configurations list reports its name, case included."), "string")
    }
    Do ..Typed(tProperties, "Description", "string", "", "What the configuration is for, at most 256 characters.")
    Do ..Typed(tProperties, "Enabled", "boolean", "", "Whether the configuration may be used.")
    Do ..Typed(tProperties, "Type", "integer", $Select(pCreates: [0], 1: [0, 1]), $Select(pCreates: "0, a client: a create is always a client, because a server needs files only the classic portal sets.", 1: "0 for a client, 1 for a server. A server needs a certificate file and a private key file, which the classic portal sets."))
    Do ..Typed(tProperties, "VerifyPeer", "integer", [0, 1, 3], "Peer verification: 0 none, 1 require the peer's certificate (a server also offers 3, request it). Above 0 needs trusted certificates.")
    Do ..Typed(tProperties, "VerifyDepth", "integer", "", "How many certificates deep the peer's chain is verified, a whole number of 0 or more.")
    Do ..Typed(tProperties, "CAFile", "string", "", "The trusted certificates: an empty string for none, %OSCertificateStore for the operating system's store, or the file this configuration already names, unchanged. No other location is accepted.")
    Do ..Typed(tProperties, "TLSMinVersion", "integer", [4, 8, 16, 32], "The lowest TLS version: 4 is TLS 1.0, 8 TLS 1.1, 16 TLS 1.2, 32 TLS 1.3. At most the maximum.")
    Do ..Typed(tProperties, "TLSMaxVersion", "integer", [4, 8, 16, 32], "The highest TLS version: 4 is TLS 1.0, 8 TLS 1.1, 16 TLS 1.2, 32 TLS 1.3. At least the minimum.")
    Do ..Typed(tProperties, "DiffieHellmanBits", "integer", [0, 512, 1024, 2048, 4096], "The Diffie-Hellman key size in bits, or 0 for the instance's default.")
    Do ..Typed(tProperties, "OCSP", "integer", [0, 1], "OCSP: 0 off, 1 on.")
    Do ..Typed(tProperties, "OCSPTimeout", "integer", "", "The OCSP timeout in seconds, a whole number of 0 or more.")
    For tField = "CipherList", "Ciphersuites" {
        If tProperties.%GetTypeOf(tField) '= "object" Continue
        Do tProperties.%Get(tField).%Set("description", $Select(tField = "CipherList": "The TLS 1.2 cipher list, one OpenSSL cipher string per entry, replacing the whole list; at most 4096 characters once joined with colons.", 1: "The TLS 1.3 cipher suites, one name per entry, replacing the whole list; at most 128 characters once joined with colons."), "string")
    }
    Quit pSchema
}

/// <p>Set <var>pField</var>'s schema in <var>pProperties</var> to <var>pType</var>, with
/// <var>pEnum</var> when it is an array and <var>pDescription</var>. A field the schema does not
/// carry is left alone.</p>
ClassMethod Typed(pProperties As %DynamicObject, pField As %String, pType As %String, pEnum, pDescription As %String) [ Private ]
{
    If pProperties.%GetTypeOf(pField) '= "object" Quit
    Set tProperty = {}
    Do tProperty.%Set("type", pType, "string")
    If $IsObject(pEnum) Do tProperty.%Set("enum", pEnum)
    If (pType = "string") && (pField = "Description") Do tProperty.%Set("maxLength", 256, "number")
    Do tProperty.%Set("description", pDescription, "string")
    Do pProperties.%Set(pField, tProperty)
}

/// <p>The form's own rules over the agent's arguments (<method>OcuPilot.Area.Security.SslRules.Validate</method>,
/// create mode), each broken rule as its field and published sentence (AD-55). The name's look-up is
/// the mint's absence read, not this.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tSC = ##class(OcuPilot.Area.Security.SslRules).Validate("create", pIdValue, pArgs, "", .tViolations)
    If $$$ISERR(tSC) Quit tSC
    Set pProblem = ##class(OcuPilot.Area.Security.SslRules).Problem(.tViolations)
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
