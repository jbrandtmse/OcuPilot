/// <p>The Services list's change tool (AD-4, AD-6, AD-10, AD-55): propose a change to one service's
/// enablement, allowed incoming connections or authentication methods. It reads the service fresh
/// through the vendor's own <code>Security.Service</code> <code>GET</code>, merges the arguments over
/// that object, and mints a proposal the user confirms. It writes nothing.</p>
/// <p><b>A merge write</b>: the body is the fresh read -- <code>{AutheEnabled, ClientSystems,
/// Description, Enabled}</code> -- with the changed fields applied, so a field the arguments omit keeps
/// the instance's value. <code>Description</code> is sent back as read and never settable: the vendor
/// drops a changed one and answers 200 (measured).</p>
/// <p><b>The serving service</b> (<parameter>OcuPilot.Kernel.Proposal.Prohibited.SERVINGSERVICENAME</parameter>)
/// is never turned off: the mint refuses it with the published sentence and the kernel refuses the
/// write (AD-10). A change to its addresses or methods is permitted, minted destructive and named on
/// the card (<method>Consequence</method>).</p>
Class OcuPilot.Screen.Tool.ServiceUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "permissions.services.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.ServiceList";

Parameter DESCRIPTION = "Propose a change to one service on this instance: whether it is enabled, the addresses allowed to connect to it, or its authentication methods. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the service exactly as the Services list reports it, and send only the fields to change. The service OcuPilot is served through, %Service_WebGateway, cannot be turned off.";

/// <p>The fresh read and the write: the vendor's single-object read, and its <code>PUT</code>, which
/// answers 404 for an absent service.</p>
Parameter READTYPE = "GET";

Parameter WRITETYPE = "PUT";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The derived top-level fields this tool admits, comma-separated
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> names the same three).
/// A test asserts the two agree.</p>
Parameter PERMITTEDFIELDS = "AutheEnabled,ClientSystems,Enabled";

Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit "Security.Service"
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

/// <p>None: a service carries no secret, so the confirm channel admits nothing (AD-6).</p>
ClassMethod SecretArguments(pDescriptor As %String = "", Output pDeclared As %Boolean) As %List
{
    Set pDeclared = 1
    Quit ""
}

/// <p>The derived schema with the three fields typed as the vendor's read answers them and
/// described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Set tSchema = ##super(pDescriptor)
    Set tProperties = tSchema.%Get("properties")
    If tProperties.%GetTypeOf("Enabled") = "object" {
        Do tProperties.%Set("Enabled", {"type": "boolean", "description": "Whether the service is enabled. Omit it to leave it as the instance holds it."})
    }
    If tProperties.%GetTypeOf("AutheEnabled") = "object" {
        Do tProperties.%Set("AutheEnabled", {"type": "integer", "description": "The service's authentication methods as the vendor's bit mask: 16 operating system, 32 password, 64 unauthenticated, 2048 LDAP, 8192 delegated, among others. Only methods the service supports are accepted. Omit it to leave the methods as they are."})
    }
    If tProperties.%GetTypeOf("ClientSystems") = "object" {
        Do tProperties.%Set("ClientSystems", {"type": "array", "items": {"type": "string"}, "description": "The whole list of addresses allowed to connect, replacing the current one; an empty list means any address. Each entry is one address, optionally followed by | and a comma-separated list of roles its connections receive, with no spaces or semicolons."})
    }
    Quit tSchema
}

/// <p>The form's own rules over the fields the arguments change, read against this tool's own fresh
/// read of <var>pIdValue</var> (<method>OcuPilot.Area.Permissions.ServiceRules.Validate</method>),
/// each broken rule as its field and published sentence (AD-55). A change that turns the serving
/// service off is refused first, with the sentence the kernel refuses its write with
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.ServingServiceDisabled</method>, AD-10, AD-53).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tRules = "OcuPilot.Area.Permissions.ServiceRules"
    Kill tQuery
    Set tQuery(..IdParam()) = pIdValue
    Set tSC = $ClassMethod(..PortClass(), "Invoke", ..Endpoint(), ..ReadType(), .tQuery, "", .tFresh, .tHttp, .tFault)
    If $$$ISERR(tSC) && (+$Get(tHttp) '= 404) Quit tSC
    If '$IsObject($Get(tFresh)) || 'tFresh.%IsA("%Library.DynamicObject") Set tFresh = ""
    Set tChanged = $ClassMethod(tRules, "Changed", pArgs, tFresh)
    Kill tChangedNames
    Set tIterator = tChanged.%GetIterator()
    While tIterator.%GetNext(.tKey, .tValue) {
        Set tChangedNames(tKey) = ""
    }
    If ##class(OcuPilot.Kernel.Proposal.Prohibited).ServingServiceDisabled(pIdValue, tChanged, .tChangedNames) {
        Set pProblem = "'Enabled': " _ ##class(OcuPilot.Kernel.Proposal.Prohibited).ReasonFor(##class(OcuPilot.Kernel.Proposal.Prohibited).#SERVINGSERVICE)
        Quit $$$OK
    }
    Set tSC = $ClassMethod(tRules, "Validate", pIdValue, tChanged, tFresh, .tViolations)
    If $$$ISERR(tSC) Quit tSC
    Set pProblem = $ClassMethod(tRules, "Problem", .tViolations)
    Quit $$$OK
}

/// <p>The kernel-owned consequence code this change's payload carries: <var>pEffect</var> when it is
/// <parameter>OcuPilot.Kernel.Proposal.Prohibited.EFFECTSERVINGSERVICE</parameter> -- the change
/// moves the addresses or methods of the service OcuPilot is served through, which outranks a
/// privileged role on the card -- and <code>""</code> otherwise, which leaves the mint's own
/// fallback.</p>
ClassMethod Consequence(pPayload As %DynamicObject, pPrivileged As %Boolean = 0, pEffect As %String = "") As %String
{
    If pEffect = ##class(OcuPilot.Kernel.Proposal.Prohibited).#EFFECTSERVINGSERVICE Quit pEffect
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
