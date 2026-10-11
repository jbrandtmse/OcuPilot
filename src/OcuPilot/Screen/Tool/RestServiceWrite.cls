/// <p>What the spec-based REST services' create and delete share (AD-6, AD-8, AD-13, AD-52, AD-53, AD-54, AD-55,
/// Story 18.32): a write of one service of the request's namespace, reached by two callers -- the agent's proposal and
/// confirmation, and the explorer's own row action or dialog -- through
/// <class>OcuPilot.Port.MgmntPort</class>'s <code>Service</code> endpoint.</p>
/// <p><b>The target is the service's package name</b>, entity type <code>rest-service</code>, which keeps no id rule:
/// the instance resolves a name in any letter case, and the port's own reads compare as the write needs
/// (<parameter>OcuPilot.Port.MgmntPort.TYPESTATE</parameter> without regard to case,
/// <parameter>OcuPilot.Port.MgmntPort.TYPESERVICE</parameter> exactly). The namespace the fresh read answered travels
/// in the port query (<method>PortQuery</method>), so a confirm writes where the proposal read.</p>
/// <p><b>It declares <code>%Development:USE</code> beside the screen's pairs, and WRITE on the namespace's routines
/// database as an argument pair</b> (AD-8, <method>OcuPilot.Screen.Tool.ExplorerSave.CodeWritePairs</method>): the
/// services are compiled classes, so the code editors' resource and write access to the code database are what a write
/// needs. The port checks the same two before any vendor call. A service whose package begins with
/// <code>OcuPilot</code> is refused by the kernel
/// (<parameter>OcuPilot.Kernel.Proposal.Prohibited.OCUPILOTCODE</parameter>) on both tools and both callers.</p>
Class OcuPilot.Screen.Tool.RestServiceWrite Extends OcuPilot.Screen.Tool.Write [ Abstract ]
{

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.RestApiList";

/// <p>The port that reads, builds and removes a service (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.MgmntPort";

/// <p>The payload field naming the namespace the write runs in.</p>
Parameter NAMESPACEFIELD = "Namespace";

/// <p>The resource a write requires beside the screen's own.</p>
Parameter WRITERESOURCE = "%Development";

Parameter WRITEPERMISSION = "USE";

ClassMethod Endpoint() As %String
{
    Quit ##class(OcuPilot.Port.MgmntPort).#ENDPOINTSERVICE
}

/// <p>The service's package name.</p>
ClassMethod IdArgument() As %String
{
    Quit "Name"
}

/// <p>The query key the port reads the package name from.</p>
ClassMethod IdParam() As %String
{
    Quit ##class(OcuPilot.Port.MgmntPort).#APPLICATIONKEY
}

/// <p>The screen's own pairs, then <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, each
/// pair once (AD-8). WRITE on the routines database is an argument pair (<method>ArgumentPairs</method>).</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If $ListFind(tPairs, tOwn) Quit tPairs
    Quit tPairs _ $ListBuild(tOwn)
}

/// <p>WRITE on the routines database of the namespace the proposal stored in its <code>Namespace</code> argument, else
/// of the request's scope, so a confirm writes where the proposal read (DW-2242, AD-8).</p>
ClassMethod ArgumentPairs(pDescriptor As %String = "", pArgs As %DynamicObject, Output pResolved As %Boolean) As %List
{
    Quit ##class(OcuPilot.Screen.Tool.ExplorerSave).CodeWritePairs(pArgs, .pResolved)
}

/// <p>The namespace the stored payload <var>pPayload</var> was read or composed in, under the port's own query key, so
/// the confirm's re-read and write and every read-back reach the namespace the proposal named (AD-52). A fresh read,
/// whose payload is empty, is scoped by the port.</p>
ClassMethod PortQuery(pPayload As %DynamicObject, ByRef pQuery)
{
    If '$IsObject(pPayload) Quit
    If (pPayload.%GetTypeOf(..#NAMESPACEFIELD) = "string") && (pPayload.%Get(..#NAMESPACEFIELD) '= "") {
        Set pQuery(##class(OcuPilot.Port.MgmntPort).#NAMESPACEKEY) = pPayload.%Get(..#NAMESPACEFIELD)
    }
}

}
