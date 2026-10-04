/// <p>ECP data servers' edit tool (AD-4, AD-6, AD-55, Story 18.20): propose a change to one data
/// server's address, port, mirror connection, SSL/TLS or batch mode. It reads the server fresh through
/// the vendor's own <code>ECP.DataServer</code> <code>GET</code>, merges the arguments over it, and
/// mints a proposal the user confirms. It writes nothing.</p>
/// <p><b>A merge write</b>: the body is the complete set the <code>GET</code> answered, with the changed
/// fields applied. A stored non-zero mirror connection is kept and never changed, as the classic dialog
/// disables it (<method>ArgumentProblem</method>). The name is the server's id and never changes;
/// neither the admin API nor the classic dialog renames one.</p>
Class OcuPilot.Screen.Tool.EcpDataServerUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "osmgmt.ecpdataservers.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.EcpDataServerList";

Parameter DESCRIPTION = "Propose a change to one ECP data server on this instance. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the server as the ECP data servers list reports it and send only what changes: its host name or IP address, its port, mirror connection, SSL/TLS or batch mode. Its name cannot be changed, and a mirror connection already set cannot be turned off.";

/// <p>The port that answers the vendor's SSL/TLS refusal on its field (AD-52).</p>
Parameter PORTCLASS = "OcuPilot.Port.EcpPort";

Parameter READTYPE = "GET";

/// <p>An upsert, so the confirm's fingerprint re-read is what refuses a server deleted since the read
/// (AD-4, AD-6).</p>
Parameter WRITETYPE = "PUT";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The derived top-level fields this tool admits
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> names the same five).</p>
Parameter PERMITTEDFIELDS = "Address,Port,MirrorConnection,SSLConfig,BatchMode";

/// <p>The fresh read's mirror connection, which an edit keeps when it is non-zero.</p>
Parameter MIRRORFIELD = "MirrorConnection";

/// <p>The pair the write needs beyond the list's own
/// (<parameter>OcuPilot.Screen.Tool.EcpDataServerCreate.WRITERESOURCE</parameter>).</p>
Parameter WRITERESOURCE = "%DB_IRISSYS";

Parameter WRITEPERMISSION = "WRITE";

/// <p>The classic dialog whose operation this tool performs beyond the list's own (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.Dialog.ECPDataServer";

ClassMethod Endpoint() As %String
{
    Quit "ECP.DataServer"
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

/// <p>The derived schema with each field described.</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit ##class(OcuPilot.Screen.Tool.EcpDataServerCreate).Described(##super(pDescriptor), 0)
}

/// <p>The update rules of <method>OcuPilot.Area.OsMgmt.EcpRules.Problem</method> over the agent's
/// arguments (AD-55), holding a mirror connection to the one the instance holds now, read as the caller
/// through this tool's own port: a stored non-zero one that would change is
/// <parameter>OcuPilot.Api.EcpError.MIRROR</parameter>.</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Set pProblem = ""
    Set tStored = ""
    If $IsObject(pArgs) && (pArgs.%GetTypeOf(..#MIRRORFIELD) '= "unassigned") {
        Set tSC = ##class(OcuPilot.Area.OsMgmt.EcpRules).Present(pIdValue, .tFresh, .tHttp, .tFault)
        If $$$ISERR(tSC) Quit tSC
        Set tStored = ##class(OcuPilot.Area.OsMgmt.LicenseRules).Text(tFresh, ..#MIRRORFIELD)
    }
    Quit ##class(OcuPilot.Area.OsMgmt.EcpRules).Problem(pIdValue, pArgs, "update", .pProblem, tStored)
}

/// <p>The port as a number, as the vendor's own read answers it.</p>
ClassMethod DerivedFields(pPayload As %DynamicObject)
{
    Do ##class(OcuPilot.Area.OsMgmt.EcpRules).Shape(pPayload)
}

/// <p>What the caller must hold: the screen's own pairs together with
/// <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>, then the custom
/// resource of the <parameter>CLASSICPAGES</parameter> dialog, each pair once.</p>
ClassMethod PrivilegePairs(pDescriptor As %String = "", Output pResolved As %Boolean) As %List
{
    Set tPairs = ##class(OcuPilot.Screen.Gate).RequiredPairs(..#DESCRIPTORCLASS, .pResolved)
    If 'pResolved Quit ""
    Set tOwn = $ListBuild(..#WRITERESOURCE, ..#WRITEPERMISSION)
    If '$ListFind(tPairs, tOwn) Set tPairs = tPairs _ $ListBuild(tOwn)
    Quit ##class(OcuPilot.Screen.Gate).WithClassicPages(tPairs, ..#CLASSICPAGES)
}

}
