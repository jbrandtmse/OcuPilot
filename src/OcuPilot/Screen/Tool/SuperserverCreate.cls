/// <p>The superservers' create tool (AD-54, AD-55, Story 18.25): propose a new superserver. It reads the
/// intended one fresh through the vendor's own <code>Security.Superserver</code> <code>GET</code>, requires that
/// read to answer <b>nothing</b>, composes the body from the settings the arguments supply and mints a proposal
/// the user confirms. It writes nothing.</p>
/// <p>The vendor's <code>PUT</code> is an upsert (201 on create, measured), so the absence fingerprint is what
/// stops a confirmed create rewriting a superserver somebody else created since the mint (AD-54). The rules of
/// <method>OcuPilot.Area.Security.SuperserverRules.Check</method> refuse the arguments at the mint, the same rules
/// the screen's Save applies, and <class>OcuPilot.Port.SuperserverPort</class> answers a taken port on its field
/// at the write. <code>SystemDefault</code> is never a field: it is shown and never set.</p>
Class OcuPilot.Screen.Tool.SuperserverCreate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.superservers.create";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.SuperserverList";

Parameter DESCRIPTION = "Propose a new superserver this instance listens on. It creates nothing by itself: it answers a proposal the user reviews and confirms. Name the port, a whole number from 100 to 65535, and optionally the address it binds to (empty for every interface); a new superserver listens at once, with the instance's own defaults for any setting you leave out. ECP, mirroring and sharding are the system default superserver's alone. A port another process holds, or a superserver already on that port and address, is refused.";

/// <p>The port that splits the composite id and answers a taken port (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.SuperserverPort";

Parameter CREATES As BOOLEAN = 1;

Parameter CHANGEACTION = "created";

Parameter READTYPE = "GET";

/// <p>The vendor's one write that takes a body, an upsert.</p>
Parameter WRITETYPE = "PUT";

/// <p>The fifteen settings this tool admits, comma-separated
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedCreateFields</method> names the same). Not
/// <code>SystemDefault</code>.</p>
Parameter PERMITTEDFIELDS = "Description,EnableCacheDirect,EnableClients,EnableCSP,EnableDataCheck,EnableECP,EnableMirror,EnableNodeJS,EnableShadows,EnableSharding,EnableSNMP,EnableWebLink,Enabled,SSLConfig,SSLSupportLevel";

/// <p>The pair this tool requires beyond Superservers' own: none, and the declaration keeps the idiom of every
/// tool of the area (AD-8). Security's set is what the write needs, measured at Story 18.25's plan.</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

/// <p>The classic editor whose operation this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Server";

/// <p>The rules this tool applies.</p>
Parameter RULES = "OcuPilot.Area.Security.SuperserverRules";

ClassMethod Endpoint() As %String
{
    Quit "Security.Superserver"
}

/// <p>The port is the target's id argument (AD-13).</p>
ClassMethod IdArgument() As %String
{
    Quit "Port"
}

/// <p>The vendor's <code>port</code> query parameter, which carries the composite id the port splits.</p>
ClassMethod IdParam() As %String
{
    Quit "port"
}

/// <p>The <code>ordinary</code> derived fields this tool admits (AD-3).</p>
ClassMethod SettableFields() As %List
{
    Quit ..AdmittedFields()
}

/// <p><parameter>PERMITTEDFIELDS</parameter>.</p>
ClassMethod PermittedFields() As %List
{
    Quit $ListFromString(..#PERMITTEDFIELDS)
}

/// <p><class>OcuPilot.Screen.Tool.SuperserverMint</class>, which builds the composite id.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.SuperserverMint"
}

/// <p>The derived schema with the port and the bind address and every setting described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit ..Described(##super(pDescriptor), 1)
}

/// <p><var>pSchema</var> with <code>BindAddress</code> added and the port, the bind address and each setting
/// described, for a create when <var>pCreates</var> is 1 and for an edit or a delete otherwise. Every
/// superserver tool's schema is described here.</p>
ClassMethod Described(pSchema As %DynamicObject, pCreates As %Boolean) As %DynamicObject
{
    If '$IsObject(pSchema) || (pSchema.%GetTypeOf("properties") '= "object") Quit pSchema
    Set tProperties = pSchema.%Get("properties")
    Do tProperties.%Set(##class(OcuPilot.Screen.Tool.SuperserverMint).#BINDARGUMENT, {"type": "string", "description": "The address the superserver binds to, as the Superservers list shows it; empty or 0.0.0.0 for every interface."})
    If pCreates {
        Set tDescriptions("Port") = "The port the new superserver listens on, a whole number from 100 to 65535, as text. A port another process holds is refused, and so is a superserver that already exists on that port and address."
    } Else {
        Set tDescriptions("Port") = "The port of the superserver, as text, exactly as the Superservers list reports it."
    }
    Set tDescriptions("Description") = "A description, at most 256 characters."
    Set tDescriptions("Enabled") = "Whether the superserver listens."
    Set tDescriptions("EnableCSP") = "Whether web (CSP/REST) connections are allowed through this superserver."
    Set tDescriptions("EnableECP") = "ECP connections; the system default superserver only."
    Set tDescriptions("EnableMirror") = "Mirroring connections; the system default superserver only."
    Set tDescriptions("EnableSharding") = "Sharding connections; the system default superserver only."
    Set tDescriptions("EnableSNMP") = "SNMP; available on Windows only."
    Set tDescriptions("SSLSupportLevel") = "0 for no SSL/TLS, 1 for optional, 2 for required. 1 and 2 need SSLConfig."
    Set tDescriptions("SSLConfig") = "The name of an SSL/TLS configuration of the server type, which must exist; empty for none."
    Set tField = ""
    For {
        Set tField = $Order(tDescriptions(tField))
        Quit:tField=""
        If tProperties.%GetTypeOf(tField) = "object" Do tProperties.%Get(tField).%Set("description", tDescriptions(tField), "string")
    }
    Quit pSchema
}

/// <p>The rules over the agent's arguments, create mode, each broken one as its field and published sentence
/// (AD-55). <var>pIdValue</var> is the composite id, whose port and bind address the rules judge; the name
/// look-up is skipped, the mint's absence read having answered it.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set tParts = ##class(OcuPilot.Kernel.EntityId).SplitComposite(pIdValue)
    Quit $ClassMethod(..#RULES, "Problem", $ListGet(tParts, 1), pArgs, "", "create", ..PortClass(), .pProblem, 1, $ListGet(tParts, 2))
}

/// <p>What the caller must hold: Superservers' own pairs, then <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>
/// and the custom resource of the <parameter>CLASSICPAGES</parameter> editor, each pair once (AD-8, AD-44).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

}
