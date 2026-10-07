/// <p>The managed file transfer connections' edit tool (AD-4, AD-6, AD-55, Story 18.26): propose a change to one
/// connection's URL, SSL/TLS configuration, email address or OAuth 2.0 client configuration name. It reads the
/// connection fresh through the vendor's own <code>Security.MFT</code> <code>GET</code>, merges the arguments over
/// that object and mints a proposal the user confirms. It writes nothing.</p>
/// <p><b>A merge write</b>: the body is the fresh read's complete set of five fields with the changed settings
/// applied (AD-4). <code>Service</code> is sent as read and never changes: a <code>PUT</code> changing it
/// relabels the stored object, so no caller may set it (measured at Story 18.26's plan). The name is the id and
/// never changes. The vendor's <code>PUT</code> is an upsert, so the confirm's fingerprint re-read is what
/// refuses a connection deleted since the mint.</p>
/// <p><b>Every rule is decided before the write</b> (<class>OcuPilot.Area.Security.MftConnectionRules</class>), on
/// both callers, and judges only the fields the change moves.</p>
Class OcuPilot.Screen.Tool.MftConnectionUpdate Extends OcuPilot.Screen.Tool.Write
{

Parameter TOOLNAME = "security.mftconnections.update";

Parameter DESCRIPTORCLASS = "OcuPilot.Screen.Descriptor.MftConnectionList";

Parameter DESCRIPTION = "Propose a change to one managed file transfer connection. It changes nothing by itself: it answers a proposal the user reviews and confirms. Name the connection exactly as the Managed file transfer connections list reports it and send only the settings to change: the URL, the SSL/TLS client configuration, the email address or the OAuth 2.0 client configuration name. Its name and its service cannot be changed.";

Parameter PORTCLASS = "OcuPilot.Port.MftPort";

Parameter READTYPE = "GET";

Parameter WRITETYPE = "PUT";

Parameter SENDSBODY As BOOLEAN = 1;

Parameter CHANGEACTION = "updated";

/// <p>The four settings this tool admits
/// (<method>OcuPilot.Kernel.Proposal.Prohibited.PermittedChangeFields</method> names the same): not
/// <code>Service</code>.</p>
Parameter PERMITTEDFIELDS = "URL,SSLConfiguration,Username,ApplicationName";

/// <p>The pair this tool requires beyond the list's own: none (AD-8).</p>
Parameter WRITERESOURCE = "%Admin_Secure";

Parameter WRITEPERMISSION = "USE";

/// <p>The classic editor whose operation this tool performs (AD-44).</p>
Parameter CLASSICPAGES = "%CSP.UI.Portal.MFT.Connection";

/// <p>The rules this tool applies.</p>
Parameter RULES = "OcuPilot.Area.Security.MftConnectionRules";

ClassMethod Endpoint() As %String
{
    Quit "Security.MFT"
}

/// <p><class>OcuPilot.Screen.Tool.MftConnectionMint</class>, which refuses an empty name in the published
/// sentence.</p>
ClassMethod MintClass() As %String
{
    Quit "OcuPilot.Screen.Tool.MftConnectionMint"
}

ClassMethod IdParam() As %String
{
    Quit "connection"
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

/// <p>The derived schema with the name and the settings described
/// (<method>OcuPilot.Screen.Tool.MftConnectionCreate.Described</method>).</p>
ClassMethod InputSchema(pDescriptor As %String = "") As %DynamicObject
{
    Quit ##class(OcuPilot.Screen.Tool.MftConnectionCreate).Described(##super(pDescriptor), 0)
}

/// <p>The kernel's merge over the fresh read, then every rule over the payload it would send, against the fresh
/// read, whose first refusal is <var>pProblem</var>: so the mint, the confirm's fingerprint re-merge and the Save
/// take one payload and one refusal, before the port is written to.</p>
ClassMethod MergeUpdate(pFresh As %DynamicObject, pArgs As %DynamicObject, pIdArgument As %String, pSettable As %List, Output pPayload As %DynamicObject, Output pDiff As %DynamicArray, Output pUnchanged As %Integer, Output pProblem As %String) As %Status
{
    Set tSC = ##super(pFresh, pArgs, pIdArgument, pSettable, .pPayload, .pDiff, .pUnchanged, .pProblem)
    If $$$ISERR(tSC) || (pProblem '= "") Quit tSC
    Set tSC = $ClassMethod(..#RULES, "Problem", "", pPayload, pFresh, "update", ..PortClass(), .pProblem, 1)
    If $$$ISERR(tSC) || (pProblem '= "") {
        Set pPayload = ""
        Set pDiff = []
        Set pUnchanged = 0
    }
    Quit tSC
}

/// <p>The rules that need no fresh read, over the agent's arguments, so a refusal costs no port call
/// (AD-55).</p>
ClassMethod ArgumentProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit $ClassMethod(..#RULES, "Problem", "", pArgs, "", "update", ..PortClass(), .pProblem, 0)
}

/// <p>The same rules asked again at the confirm (AD-6, AD-40).</p>
ClassMethod ConfirmProblem(pIdValue As %String, pArgs As %DynamicObject, Output pProblem As %String) As %Status
{
    Quit ..ArgumentProblem(pIdValue, pArgs, .pProblem)
}

/// <p>What the caller must hold: the list's own pairs, then <parameter>WRITERESOURCE</parameter>:<parameter>WRITEPERMISSION</parameter>
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
